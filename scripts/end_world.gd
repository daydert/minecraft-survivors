extends "res://scripts/arsenal_world.gd"
## Chapter III shares solo equipment with chapter II through arsenal_world.gd,
## not chapter II itself. No network classes or data are used.
const END_WEAPONS=["spear","mace","end_crystal","knockback_stick","dragon_breath","shield"]
const END_ARENA=Rect2(656,704,736,640)
## The echo's slash: a short dash that hits anything within REACH of him.
const ECHO_SLASH_SPEED:=200.0
const ECHO_SLASH_TIME:=.28
const ECHO_SLASH_REACH:=44.0
const ECHO_WINDUP:=.65
var land=PackedByteArray()
var flight=0.0
var flight_cooldown=0.0
var pearl_cooldown=0.0
var rocket_cooldown=0.0
var shell_cooldown=0.0
var dash_left=0.0
var dash_direction=Vector2.UP
var dash_hits={}
var rocket=false
var jump_age=-1.0
var jump_height=0.0
var jump_stats={}
var fall_age=-1.0
var last_safe=Vector2(1024,1024)
var player_push=Vector2.ZERO
var shield_charges=0
var shield_timer=0.0
var shield_guard=0.0
var slow_time=0.0
var poison_time=0.0
var status_tick=0.0
var levitation=0.0
var levitation_height=0.0
var levitation_velocity=0.0
var choice_age=0.0
var choice_tick=0
var rerolls=0
var last_choices=[]
var chosen_item=""
var chosen_level=0
var chosen_index=-1
var choice_hold=0.0
var end_boss=preload("res://scripts/end_encounter.gd").new()
var crystals: Array=[]
var dragon_history: Array=[]
var scene_camera=Vector2(1024,1024)
var endsteve_corpse={}
## Presentation-only impact layer shared with chapter IV (purple palette here).
var fx=preload("res://scripts/chapter_four_fx.gd").new()
var heal_drop_cd:=0.0
## Traces of earlier loops on the island: a ghost fight, ruined portals, gateways.
var echo: Dictionary={}
var echo_done:=false
var relics: Array=[]
var gateways: Array=[]
var gateway_cd:=0.0
## EnderSteve's Eye of the End, given on the rim; chapter IV starts with it.
var keepsake:=false
## Spoken lines on screen: {text, age, life}. Presentation and story only.
var lines: Array=[]
## EnderSteve after the duel: kneels, sits with the hero, restores the portal.
var npc: Dictionary={}
## Short impact freeze for the portal break.
var hitstop:=0.0
var echo_count:=0
var broken_gear: Array=[]
const ECHO_LINES=["Даже не думай туда возвращаться","ТЫ ОПЯТЬ МЕНЯ НЕ СЛУШАЕШЬ","Я уже это проходил, ещё не поздно остановиться","Снова и снова, эта грёбаная петля меня никогда не отпустит","Ладно...\nУ меня нет другого выбора...\nТы ничем не отличаешься от остальных...\nНАЧНЁМ!"]
var hand_taken=false
var heal_rng=RandomNumberGenerator.new()
var reward_rng=RandomNumberGenerator.new()
var end_complete=false
var damage_source="melee"
## Version 2: an End city guarded by shulkers and periodic void gusts.
var landmarks: Array=[]
var city: Dictionary={}
var gust: Dictionary={}
var gust_rng=RandomNumberGenerator.new()
var falls=0

func chapter_number() -> int:return 3

## Multi-part lines are queued one phrase at a time. A line in capitals is a scream.
func say(text: String, life: float=3.0, who: String="ender"):
	var parts: PackedStringArray=text.split("\n");var delay:=0.0
	for part in parts:
		var span: float=maxf(life if parts.size()==1 else 0.0,clampf(1.0+part.length()/22.0,1.7,7.5))
		var scream: bool=part.length()>=4 and part==part.to_upper() and part!=part.to_lower()
		lines.append({"text":part,"age":-delay,"life":span,"who":who,"scream":scream})
		delay+=span+.25

## Where he stands between the hero and the portal.
func betrayer_position() -> Vector2:
	return portal_position+Vector2(0,30)

## Two places on the south rim of the island, facing the camera and the void.
func seats() -> Array:
	var result: Array=[]
	for x in [portal_position.x-14,portal_position.x+14]:
		var y: float=portal_position.y+40
		while y<portal_position.y+400 and on_land(Vector2(x,y+4)):y+=2
		result.append(Vector2(x,y-1))
	return result

func hand_position() -> Vector2:
	return (endsteve_corpse.get("p",portal_position)+Vector2(12,3)).clamp(END_ARENA.position+Vector2(12,12),END_ARENA.end-Vector2(12,12))

func reset(seed_value: int=0):
	fx.reset(self);fx.ender=true;heal_drop_cd=0.0;echo={};echo_done=false;relics.clear();gateways.clear();gateway_cd=0.0;keepsake=false
	flight=0;flight_cooldown=0;pearl_cooldown=0;rocket_cooldown=0;shell_cooldown=0
	dash_left=0;dash_hits.clear();rocket=false;jump_age=-1;jump_height=0;fall_age=-1
	player_push=Vector2.ZERO;shield_charges=0;shield_timer=0;shield_guard=0
	slow_time=0;poison_time=0;status_tick=0;levitation=0;levitation_height=0;levitation_velocity=0
	choice_age=0;choice_tick=0;rerolls=0;last_choices.clear();crystals.clear();dragon_history.clear()
	chosen_item="";chosen_index=-1;choice_hold=0
	endsteve_corpse={};hand_taken=false;end_complete=false;damage_source="melee"
	lines.clear();npc={};hitstop=0.0;echo_count=0
	landmarks.clear();city={};gust={};falls=0
	super.reset(seed_value)
	var extra: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/end_animations.json"))
	animation.data.actors.merge(extra.actors,true);animation.data.weapons.merge(extra.weapons,true)
	heal_rng.seed=int(rng.seed)^0x64fc92;reward_rng.seed=int(rng.seed)^0x7b128
	gust_rng.seed=int(rng.seed)^0x3c96e1
	var rules: Dictionary=db.data.void_gust
	gust={"phase":"idle","timer":float(rules.first),"age":0.0,"dir":Vector2.RIGHT,"count":0}
	last_safe=player;scene_camera=player
	stage="end_arrival";stage_age=0

func make_map():
	var terrain: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/end_terrain.json"))
	land.resize(128*128);land.fill(0)
	for cell in terrain.solid_cells:land[int(cell)]=1
	for y in range(1,63):
		for x in range(1,63):
			if not on_land(Vector2(x*32+16,y*32+16)):blocked[Vector2i(x,y)]=true
	var decor=RandomNumberGenerator.new();decor.seed=int(rng.seed)^0x449cab
	for i in range(96):
		var p=Vector2.ZERO
		for attempt in range(100):
			p=Vector2(decor.randf_range(160,1888),decor.randf_range(160,1888))
			if on_land(p) and p.distance_to(player)>100:break
		if not on_land(p):continue
		props.append({"type":"pumpkin","p":p,"hp":10.0,"id":next_id(),"radius":8.0})
	for i in range(48):
		var p=Vector2(240+(i%8)*224+decor.randf_range(-50,50),240+(i/8)*250+decor.randf_range(-45,45))
		if supported_at(p,28) and p.distance_to(player)>130:
			props.append({"type":"end_ruin","p":p,"hp":-1.0,"id":next_id(),"radius":9.0})
			var cell=Vector2i(p/64)
			if not solid_grid.has(cell):solid_grid[cell]=[]
			solid_grid[cell].append({"p":p,"r":9.0})
			blocked[Vector2i(p/CELL)]=true
	place_city(decor)
	place_relics(decor)
	assign_healing()

## Ruined portals from loops that ended badly, and two pairs of gateways.
func place_relics(decor: RandomNumberGenerator):
	var spots: Array=[]
	for attempt in range(400):
		if spots.size()>=7:break
		var p=Vector2(decor.randf_range(200,1848),decor.randf_range(200,1848))
		if not supported_at(p,34) or p.distance_to(player)<220:continue
		if not city.is_empty() and p.distance_to(city.p)<160:continue
		if spots.any(func(q):return q.distance_to(p)<260):continue
		spots.append(p)
	for i in range(spots.size()):
		if i<3:relics.append({"p":spots[i],"id":i})
		else:gateways.append({"p":spots[i],"to":(i-3)^1})
	if gateways.size()%2==1:gateways.pop_back()

func update_loop_world(dt: float):
	gateway_cd=maxf(0,gateway_cd-dt)
	if stage!="survival":return
	if gateway_cd<=0 and fall_age<0:
		for gw in gateways:
			if player.distance_to(gw.p)<12 and gw.to<gateways.size():
				teleport_to(gateways[gw.to].p+Vector2(0,20));gateway_cd=2.5;sound("portal_travel",.3);break
	if not echo_done and time>=360:
		echo_done=true
		for i in range(12):
			var p=player+Vector2.from_angle(-PI/2+i*2.39996)*130
			if supported_at(p,40):echo={"p":p,"age":0.0,"foe":p+Vector2(60,-14)};break
	if not echo.is_empty():
		var before: float=echo.age;echo.age+=dt
		for cue in [[1.0,"swing"],[1.8,"swing"],[2.6,"hurt"],[3.4,"swing"],[4.2,"ch4_hb_fire"],[5.4,"ch4_body_fall"],[7.0,"end_teleport"]]:
			if echo.age>=cue[0] and before<cue[0]:sound(cue[1],.05)
		if echo.age>=6.2 and before<6.2:say("Опять…",2.0)
		if echo.age>=9.5:echo={}

func place_city(decor: RandomNumberGenerator):
	var rules: Dictionary=db.data.end_city
	var best=Vector2.ZERO
	for attempt in range(200):
		var p=player+Vector2.from_angle(decor.randf()*TAU)*decor.randf_range(float(rules.min_distance),float(rules.max_distance))
		if supported_at(p,58) and supported_at(p+Vector2(0,30),40):best=p;break
	if best==Vector2.ZERO:return
	for i in range(props.size()-1,-1,-1):
		if props[i].type=="end_ruin" and props[i].p.distance_to(best)<90:
			var c=Vector2i(props[i].p/64)
			if solid_grid.has(c):solid_grid[c]=solid_grid[c].filter(func(s):return s.p!=props[i].p)
			if props[i].type=="end_ruin":blocked.erase(Vector2i(props[i].p/CELL))
			props.remove_at(i)
	for x in [-44,-30,30,44]:
		var q=best+Vector2(x,-10)
		var c=Vector2i(q/64)
		if not solid_grid.has(c):solid_grid[c]=[]
		solid_grid[c].append({"p":q,"r":9.0});blocked[Vector2i(q/CELL)]=true
	city={"p":best,"guarded":false}
	landmarks=[{"kind":"end_city","p":best,"id":next_id()}]
	loot.append({"kind":"chest","p":best+Vector2(0,12),"born":0.0})

func update_city():
	if city.is_empty() or city.guarded or player.distance_to(city.p)>float(db.data.end_city.wake):return
	city.guarded=true;message="Город Края";message_timer=2.5;sound("warning")
	for offset in db.data.end_city.shulkers:
		var q=city.p+Vector2(offset[0],offset[1])
		if on_land(q) and spawn("shulker",q):mobs.back().timer=1.0+mobs.size()%3*.4

func update_gust(dt: float):
	var rules: Dictionary=db.data.void_gust
	if gust.is_empty() or time<float(rules.from):return
	gust.timer-=dt;gust.age+=dt
	match gust.phase:
		"idle":
			if gust.timer<=0:
				gust.phase="warn";gust.timer=float(rules.warn);gust.age=0.0
				gust.dir=Vector2.from_angle(gust_rng.randf()*TAU)
				sound("gust",.3)
		"warn":
			if gust.timer<=0:
				gust.phase="blow";gust.timer=float(rules.blow);gust.age=0.0;gust.count+=1
				for m in mobs:
					if m.hp<=0 or m.get("boss",false) or m.kind in ["shulker","arena_crystal"]:continue
					m.knock=gust.dir*float(rules.mob_push);m.launch=.45;m.collision_hits={}
					run_progress.mark_launch(m.id,false)
		"blow":
			if not flying() and dash_left<=0:player_push=player_push.lerp(gust.dir*float(rules.push),minf(1,dt*8))
			if gust.timer<=0:
				if gust.count>=5 and falls==0:run_progress.award("windswept")
				gust.phase="idle";gust.age=0.0
				gust.timer=float(rules.every)+gust_rng.randf_range(-float(rules.jitter),float(rules.jitter))

func on_land(p: Vector2) -> bool:
	if stage not in ["survival","end_arrival","departure"]:return END_ARENA.has_point(p)
	var c=Vector2i((p/16).floor())
	return c.x>=0 and c.y>=0 and c.x<128 and c.y<128 and not land.is_empty() and land[c.y*128+c.x]!=0

func free_at(p: Vector2, radius: float=6) -> bool:
	return super.free_at(p,radius) and supported_at(p,radius)

func supported_at(p: Vector2, radius: float=10) -> bool:
	if not on_land(p):return false
	for i in range(8):
		if not on_land(p+Vector2.from_angle(i*TAU/8)*radius):return false
	return true

func move_actor(p: Vector2, velocity: Vector2, radius: float) -> Vector2:
	# Do not inherit the smaller Wither arena clamp.
	var q=p
	var steps=maxi(1,ceili(velocity.length()/6.0))
	for i in range(steps):
		q=(q+velocity/steps).clamp(Vector2.ONE*(25+radius),Vector2.ONE*(SIZE-25-radius))
		for s in nearby_solids(q):
			var off: Vector2=q-s.p
			var reach: float=radius+s.r
			if off.length_squared()<reach*reach:q=s.p+(off.normalized() if off.length_squared()>.001 else Vector2.RIGHT)*reach
	if stage not in ["survival","end_arrival","departure"]:q=q.clamp(END_ARENA.position+Vector2.ONE*radius,END_ARENA.end-Vector2.ONE*radius)
	return q

func movement_speed() -> float:
	return db.data.player_speed*(1+.08*items.get("sugar",0))*(rule("slow_arrow_factor") if slow_time>0 else 1.0)*(1.75 if flight>0 and not rocket else 1.0)

func elytra_landing():
	var lv: int=int(items.get("elytra",1));var r: float=46.0+6.0*lv;var dmg: float=8.0+4.0*lv
	damage_owner="elytra"
	for m in in_radius(player,r):hurt(m,dmg,player.direction_to(m.p)*160.0)
	fx.quake(self,player,1.2);fx.ring(player,r,.45,"toll");fx.dust(player,10,r*.6);shake=maxf(shake,.25);sound("mace_smash",.1)

func flying() -> bool:return flight>0 or rocket or jump_age>=0 or levitation>0 or levitation_height>0

func elevation() -> float:
	return jump_height+(12+sin(clock*5)*2 if flight>0 or rocket else 0)+levitation_height

func active_item(id: String) -> bool:
	if state!="RUNNING" or stage not in ["survival","dragon","last_duel"] or fall_age>=0:return false
	match id:
		"elytra":
			if not items.has(id) or flight_cooldown>0:return false
			# Elytra v2 (13.11): a longer, faster glide, untouchable in the air, a crash-landing shockwave.
			flight=2.4+.6*items[id];flight_cooldown=9.5-.7*items[id];sound("wind_burst");fx.dust(player,6,14)
		"ender_pearl":
			if not items.has(id) or pearl_cooldown>0:return false
			pearl_cooldown=13-items[id]
			add_effect("end_pearl",player,.65,{"end":player+facing*(125+items[id]*15),"start":player})
			sound("pearl_throw")
		"rocket":
			if not evolved.has("spear") or not items.has("elytra") or rocket_cooldown>0:return false
			rocket_cooldown=7;flight=maxf(flight,1.25);start_dash(1.05,true);sound("rocket_launch")
		_:return false
	return true

func safe_destination(center: Vector2, radius: float, randomize: bool=false):
	for i in range(80):
		var a=heal_rng.randf()*TAU if randomize else i*2.39996
		var d=heal_rng.randf_range(12,radius) if randomize else sqrt(float(i)/79)*radius
		var p=center+Vector2.from_angle(a)*d
		if not free_at(p,8):continue
		var clear=true
		for m in mobs:
			if m.hp>0 and m.p.distance_to(p)<m.radius+24:clear=false;break
		if clear:return p
	for y in range(-int(radius/12),int(radius/12)+1):
		for x in range(-int(radius/12),int(radius/12)+1):
			var p=center+Vector2(x,y)*12
			if p.distance_to(center)>radius or not free_at(p,8):continue
			if mobs.all(func(m):return m.hp<=0 or m.p.distance_to(p)>=m.radius+24):return p
	return null

func teleport_to(p: Vector2):
	add_effect("end_teleport",player,.55)
	player=p;last_safe=p;player_push=Vector2.ZERO
	add_effect("end_teleport",player,.55);invulnerable=maxf(invulnerable,.3);sound("end_teleport")

func step(dt: float, movement: Vector2=Vector2.ZERO):
	if sword_step(dt, movement):return
	if state!="RUNNING":return
	if hitstop>0:hitstop=maxf(0,hitstop-dt);return
	track_progress(dt)
	clock+=dt;stage_age+=dt
	if stage=="survival":time=minf(db.data.duration,time+dt)
	var was_gliding: bool=flight>0
	for key in ["invulnerable","shake","message_timer","flight","flight_cooldown","pearl_cooldown","rocket_cooldown","shell_cooldown","shield_guard","slow_time","poison_time","levitation"]:set(key,maxf(0,float(get(key))-dt))
	if flight>0:invulnerable=maxf(invulnerable,.12)
	if was_gliding and flight<=0 and items.has("elytra"):elytra_landing()
	var before=player
	var combat=stage in ["survival","dragon","last_duel"]
	if fall_age>=0:
		fall_age+=dt
		if fall_age>.85:
			fall_age=-1;player=last_safe;invulnerable=0
			if items.has("shulker_shell") and shell_cooldown<=0:
				shell_cooldown=rule("fall_shell_cooldown")-rule("fall_shell_cooldown_per_level")*items.shulker_shell
				run_progress.award("shell_rescue")
			else:damage_player(rule("fall_damage")*(1-rule("fall_shell_reduction")*items.get("shulker_shell",0)))
			invulnerable=1
	elif stage in ["survival","dragon","last_duel","exit_portal","approach","portal_ready"]:
		if dash_left>0:
			dash_left=maxf(0,dash_left-dt);invulnerable=maxf(invulnerable,.08)
			player=move_actor(player,dash_direction*movement_speed()*(5.8 if rocket else db.stats("spear",build.get("spear",1),false,items).speed)*dt,6)
			for m in in_radius((before+player)/2,before.distance_to(player)/2+15):
				if dash_hits.has(m.id):continue
				dash_hits[m.id]=true;damage_owner="spear";var s=db.stats("spear",build.get("spear",1),evolved.has("spear"),items)
				hurt(m,s.damage*(3 if rocket else 1)*(rule("slow_arrow_factor") if slow_time>0 else 1.0),dash_direction*2)
			break_props(player,16,25)
			if dash_left<=0:rocket=false
		else:
			if movement.length_squared()>0:
				facing=movement.normalized();player=move_actor(player,(movement.limit_length()*movement_speed()+player_push)*dt,6);moved+=dt
			else:player=move_actor(player,player_push*dt,6)
		player_push=player_push.move_toward(Vector2.ZERO,dt*180)
		# A blow may stagger the hero but never throws him off the island by itself.
		if player_push.length_squared()>1 and not on_land(player+player_push.normalized()*16):player_push=Vector2.ZERO
		update_elevation(dt)
		if on_land(player):
			if not flying() and supported_at(player):last_safe=player
		elif not flying() and dash_left<=0:fall_age=0;falls+=1;sound("hurt");add_effect("end_fall",player,.85)
	player_visual.travel=before.distance_to(player);player_moving=player_visual.travel>.0001
	tracked_velocity=tracked_velocity.lerp((player-before)/maxf(dt,.0001),minf(1,dt*8))
	if combat and fall_age<0:
		flow_timer-=dt
		if flow_timer<=0 and flow_cell!=Vector2i(player/CELL):update_flow();flow_timer=.3
		if stage=="survival":spawn_wave(dt);update_city();update_gust(dt)
		move_mobs(dt);rebuild_hit_grid();update_attacks(dt);update_projectiles(dt);update_explosives(dt);update_hazards(dt);resolve_deaths()
	update_effects(dt);fx.update(self,dt);update_loop_world(dt);heal_drop_cd=maxf(0,heal_drop_cd-dt)
	if fall_age<0:pickup(dt)
	update_particles(dt);animation.advance(self,dt)
	update_end_poses(dt)
	update_shield(dt)
	update_regeneration(dt)
	status_tick-=dt
	if status_tick<=0:
		status_tick+=1
		if poison_time>0 and hp>1:damage_player(minf(1,hp-1))
	if hp<=0:state="RESULT";victory=false;sound("death");return
	end_boss.story(self,dt)
	if stage in ["survival","dragon","last_duel"]:
		if xp>=db.required_xp(level):next_level()
		elif not pending_chest.is_empty():open_chest(pending_chest)
	if stage not in ["survival","end_arrival","departure"]:
		var target=player+Vector2(0,-30)
		if stage in ["dragon","last_duel"]:
			for boss in mobs:
				if boss.kind in ["end_dragon","endersteve_final"]:
					var focus: Vector2=boss.p-Vector2(0,boss.get("altitude",0)+30)
					target=player.lerp(focus,.46)+Vector2(0,-8);break
			target=target.clamp(player-Vector2(260,120),player+Vector2(260,100))
		if stage in ["dragon_death","betrayal","last_arrival","endsteve_death","rekindle","exit_jump"]:target=player.lerp(portal_position,.5)+Vector2(0,-25)
		if stage=="endsteve_death":target=player.lerp(endsteve_corpse.p,.6)-Vector2(0,30)
		if stage in ["yield","approach","clash","down"] and not npc.is_empty():target=player.lerp(npc.p,.5)-Vector2(0,24)
		if stage in ["to_edge","sit"]:target=(seats()[0]+seats()[1])/2-Vector2(0,34)
		if stage=="restore":target=player.lerp(portal_position,.6)-Vector2(0,24)
		scene_camera=scene_camera.lerp(target,1-exp(-dt*2.5))

func camera() -> Vector2:
	if stage in ["survival","end_arrival","departure"]:return player.clamp(VIEW/2,Vector2.ONE*SIZE-VIEW/2)
	if stage in ["to_edge","sit","restore"]:return scene_camera.clamp(Vector2(900,860),Vector2(1148,1460))
	return scene_camera.clamp(Vector2(940,860),Vector2(1108,1188))

func update_elevation(dt: float):
	if levitation>0:levitation_height=minf(64,levitation_height+dt*8);levitation_velocity=0
	elif levitation_height>0:
		levitation_velocity-=dt*100
		levitation_height=maxf(0,levitation_height+levitation_velocity*dt)
	if jump_age>=0:
		jump_age+=dt
		jump_height=sin(clampf(jump_age/.95,0,1)*PI)*jump_stats.height
		invulnerable=maxf(invulnerable,.06)
		if jump_age>=.95:
			jump_age=-1;jump_height=0
			var damage=jump_stats.damage*(1+jump_stats.height/24)
			damage_owner="mace";end_blast(player,jump_stats.radius,damage,"mace_impact")
			for m in in_radius(player,jump_stats.radius):
				if m.kind not in ["arena_crystal"]:m.stun=maxf(m.get("stun",0.0),.2 if m.get("boss",false) else .6)
			fx.quake(self,player,1.2);fx.erupt(self,player,"stone",8)
			if evolved.has("mace"):add_effect("end_aftershock",player,.8,{"radius":jump_stats.radius*1.4,"damage":damage*.5,"triggered":false})
			sound("mace_smash");shake=.2

func start_dash(seconds: float, boosted: bool=false):
	dash_left=seconds;dash_direction=facing;dash_hits.clear();rocket=boosted
	invulnerable=maxf(invulnerable,seconds)
	animation.strike(self,"spear",facing)

func update_shield(dt: float):
	if not build.has("shield"):shield_charges=0;return
	if shield_timer>0:
		shield_timer=maxf(0,shield_timer-dt)
		if shield_timer<=0:shield_charges=int(db.stats("shield",build.shield,evolved.has("shield"),items).count)
	cooldowns.shield=shield_timer

func block_hit(source: Vector2, projectile: Dictionary={}) -> bool:
	if not build.has("shield") or shield_charges<=0 or shield_timer>0 or source==player:return false
	if facing.dot(player.direction_to(source))<.35:return false
	if shield_guard>0:return true
	shield_guard=.18;shield_charges-=1;sound("shield_block");add_effect("shield_impact",player+facing*12,.3)
	if evolved.has("shield"):
		if not projectile.is_empty():
			var target=nearest(player,300)
			fire_projectile("bolt",player,player.direction_to(target.p) if target!=null else -projectile.dir,{"speed":240,"damage":projectile.damage*3+15,"range":340,"radius":3,"pierce":2},true)
		else:
			for m in in_radius(source,18):hurt(m,db.stats("shield",build.shield,true,items).damage,player.direction_to(m.p)*2)
	if shield_charges<=0:shield_timer=db.stats("shield",build.shield,evolved.has("shield"),items).interval;sound("shield_break")
	return true

func contact_hit(source: Vector2, damage: float, projectile: Dictionary={}) -> bool:
	if fall_age>=0 or dash_left>0 or invulnerable>0:return false
	if block_hit(source,projectile):return false
	var old=hp;damage_player(damage)
	if hp<old:fx.burst(player-Vector2(0,12),false,false);fx.shove(self,source.direction_to(player),4.0,.15)
	return hp<old

func spawn(kind: String, at=null) -> bool:
	if kind=="endersteve":
		for m in mobs:
			if m.kind==kind and m.hp>0:return false
	if kind in ["shulker","dispenser_enderman","endermite_brood"]:
		var cap={"shulker":9,"dispenser_enderman":12,"endermite_brood":5}[kind]
		if mobs.filter(func(m):return m.kind==kind and m.hp>0).size()>=cap:return false
	if not super.spawn(kind,at):return false
	var m=mobs.back();m.teleport_cd=0.0;m.combo=0;m.pose_age=0.0;m.pose_phase="";m.collision_hits={};m.launch=0.0;m.altitude=0.0;m.attack_serial=0
	if kind in ["endersteve","end_dragon","endersteve_final"]:
		m.boss=true;m.hp=db.data.mobs[kind].hp;m.max_hp=m.hp;m.timer=2.0
	if kind=="arena_crystal":m.hp=180;m.max_hp=180;m.boss=false
	if kind=="end_dragon":m.altitude=45.0;m.phase="circle";m.orbit=0.0;m.fire_tick=2.2;m.rush_tick=8.0;m.phase_two=false;m.burst_tick=0.0;m.dir=Vector2.RIGHT;m.pattern=0;m.volley=0
	if kind=="endersteve_final":m.phase="walk";m.pattern=-1;m.burst_tick=0.0;m.rage=false
	if kind=="endersteve":say(ECHO_LINES[echo_count%ECHO_LINES.size()],3.0);echo_count+=1;sound("warning")
	return true

func hurt(m: Dictionary, amount: float, push: Vector2=Vector2.ZERO):
	if m.kind=="end_dragon" and m.get("phase","")=="slump":amount*=1.5
	# He guards while attacking: real damage lands in the openings he leaves.
	# The most mobile boss (tester pack 13.11): outside his openings he slips most blows with a blink.
	if m.kind=="endersteve_final" and m.hp>0 and m.phase not in ["pose","rage","rush","leap","skyfall","blink_chain"] and clock>=float(m.get("dodge_cd",0.0)):
		m.dodge_cd=clock+(1.15 if m.get("rage",false) else 1.7)
		var side: Vector2=player.direction_to(m.p).orthogonal()*(1.0 if int(clock*7.0)%2==0 else -1.0)
		teleport_mob(m,(m.p+side*72.0+m.p.direction_to(player)*-20.0).clamp(END_ARENA.position+Vector2(40,40),END_ARENA.end-Vector2(40,40)))
		fx.flash(m.p,60.0,Color(.8,.5,1),.12)
		return
	if m.kind=="endersteve_final" and m.phase not in ["pose","recover","walk","rage"]:
		amount*=.35
		if m.hp>0 and clock>=m.get("guard_fx",0.0):m.guard_fx=clock+.15;fx.ring(m.p-Vector2(0,10),12.0,.18,"thorns");sound("shield_block",.1)
	if m.hp>0 and (m.kind!="end_dragon" or stage=="dragon"):fx.hit(self,m,amount,push,damage_owner)
	if m.kind=="end_dragon":
		if stage!="dragon":return
		if damage_source=="melee" and not rocket and elevation()+14<m.altitude:return
		if not m.phase_two:amount=minf(amount,maxf(0,m.hp-m.max_hp*.5))
		push*=.06
	if m.kind=="endersteve_final":push*=.18
	if m.kind=="shulker" and fposmod(clock+float(m.id),3.5)>1.8:amount*=.35
	super.hurt(m,amount,push)

func move_mobs(dt: float):
	damage_owner="knockback_stick"
	var spawnlings=[]
	for m in mobs:
		if m.hp<=0:
			run_progress.mark_launch(m.id,false)
			continue
		m.animation+=dt;m.flash=maxf(0,m.flash-dt);m.timer-=dt;m.teleport_cd=maxf(0,m.teleport_cd-dt);m.slow=maxf(0,m.slow-dt);m.control_resist=maxf(0,m.control_resist-dt)
		if m.burn>0:
			m.burn-=dt;m.burn_tick-=dt
			if m.burn_tick<=0:m.burn_tick+=.5;damage_source="status";hurt(m,burn_damage(m));damage_source="melee"
		var old: Vector2=m.p
		var from_stick: bool=run_progress.stick_launches.has(m.id)
		if m.kind=="arena_crystal":continue
		if m.kind in ["end_dragon","endersteve_final"]:
			if m.pull_left>0 or m.stun>0:
				m.timer+=dt
				if m.pull_left>0:
					var travel=minf(m.pull_left,220*dt);m.p=move_actor(m.p,m.pull_dir*travel,m.radius);m.pull_left-=travel
					if m.pull_left<=0:m.stun=m.pull_stun
				else:m.stun=maxf(0,m.stun-dt)
			else:end_boss.step(self,m,dt)
		elif m.pull_left>0 or m.stun>0:
			if m.pull_left>0:
				var d=minf(m.pull_left,360*dt);var dest=move_actor(m.p,m.pull_dir*d,m.radius)
				if on_land(dest):m.p=dest
				m.pull_left-=d
				if m.pull_left<=0:m.stun=m.pull_stun
			else:m.stun=maxf(0,m.stun-dt)
		else:
			var direction=navigation(m.p);var speed=m.speed*(.45 if m.slow>0 else 1.0);var distance=m.p.distance_to(player)
			match m.kind:
				"shulker":
					speed=0
					if m.timer<=0 and distance<265:
						fire_projectile("shulker_bullet",m.p,Vector2.UP,{"speed":72,"damage":m.damage,"range":1000,"radius":4,"life":14},false);m.timer=3.0+float(m.id%4)*.45;sound("shulker_shoot")
				"dispenser_enderman":
					if distance<105:direction=-m.p.direction_to(player)
					elif distance<210:speed=0
					if m.timer<=0 and distance>=105 and distance<300:
						fire_projectile(["enemy_arrow","slow_arrow","poison_arrow"][m.id%3],m.p,m.p.direction_to(player),{"speed":142,"damage":m.damage,"range":350,"radius":3},false);m.timer=2.5;m.visual.shot_age=0;sound("arrow")
				"endermite_brood":
					if m.timer<=0:
						for j in range(3):spawnlings.append(m.p+Vector2.from_angle(j*TAU/3+float(m.id))*24)
						m.timer=6;add_effect("brood_spawn",m.p,.65)
				"endersteve":
					if m.phase=="walk" and m.timer<=0:
						teleport_mob(m,player-facing*60);m.phase="windup";m.timer=ECHO_WINDUP;m.charge=m.p.direction_to(player)
					elif m.phase=="windup":
						speed=0
						if m.timer<=0:m.phase="slash";m.timer=ECHO_SLASH_TIME;add_effect("ender_slash",m.p,.38,{"direction":m.charge,"radius":ECHO_SLASH_REACH})
					elif m.phase=="slash":
						direction=m.charge;speed=ECHO_SLASH_SPEED
						if distance<ECHO_SLASH_REACH:contact_hit(m.p,m.damage)
						if m.timer<=0:m.phase="recover";m.timer=.8
					elif m.phase=="recover":
						speed=0
						if m.timer<=0:m.phase="walk";m.timer=2.8
				"endermite":speed*=1.5 if fposmod(m.animation,1.3)<.3 else .8
			m.dir=direction
			var q=move_actor(m.p,(direction*speed+m.knock)*dt,m.radius)
			if on_land(q):m.p=q
			elif m.launch>0:
				if m.hp>0:run_progress.enemy_fell(m.id)
				m.hp=0;add_effect("end_enemy_fall",m.p,.65,{"kind_actor":m.kind});kills+=0
			elif m.kind in ["enderman","dispenser_enderman"] and m.teleport_cd<=0:teleport_mob(m,player+direction*85)
			m.launch=maxf(0,m.launch-dt)
			if m.launch<=0:run_progress.mark_launch(m.id,false)
			if m.launch>0 and m.knock.length()>60:
				for other in in_radius(m.p,m.radius+8):
					if other==m or m.collision_hits.has(other.id):continue
					m.collision_hits[other.id]=true;hurt(other,18+m.knock.length()*.08,m.knock.normalized()*1.8)
					if evolved.has("knockback_stick") and other.kind not in ["end_dragon","arena_crystal"]:
						other.launch=.5;other.knock=m.knock*.7
						run_progress.mark_launch(other.id,from_stick)
			m.knock=m.knock.move_toward(Vector2.ZERO,dt*240)
			if m.p.distance_to(player)<m.radius+6 and jump_height+levitation_height<16 and m.phase!="windup":contact_hit(m.p,m.damage)
		m.moving=m.p.distance_squared_to(old)>.001;m.visual.travel=m.p.distance_to(old)
	for p in spawnlings:
		if on_land(p):spawn("endermite",p)

func teleport_mob(m: Dictionary, target: Vector2):
	for i in range(24):
		var p=target+Vector2.from_angle(i*2.39996)*(20+i*4)
		if not free_at(p,10) or p.distance_to(player)<26:continue
		add_effect("end_afterimage",m.p,.4,{"actor":m.kind,"direction":m.visual_dir,"pose":m.visual.duplicate()});add_effect("end_teleport",m.p,.5);m.p=p;add_effect("end_teleport",p,.5);m.teleport_cd=.7;sound("end_teleport",.12);return

func hook_target(m: Dictionary, evolved_hook: bool):
	var allowed=m.control_resist<=0
	super.hook_target(m,evolved_hook)
	if not allowed:return
	if m.kind=="endersteve_final" and m.phase in ["windup","rush","cast","pursuit","cleave_windup"]:m.phase="recover";m.timer=.7;m.combo=0
	elif m.kind=="end_dragon" and m.phase in ["windup","rush"]:m.phase="circle";m.timer=3

func update_end_poses(dt: float=0):
	var newest=-100.0
	for id in END_WEAPONS:
		if id=="shield" or not weapon_visuals.has(id):continue
		var at=attack_visuals.get(id,{}).get("at",-100.0)
		if at>newest and clock-at<.5:newest=at;player_visual.weapon=id
	for m in mobs:
		if m.kind in ["endersteve","endersteve_final"]:
			if m.pull_left>0 or m.stun>0:animation.set_pose(m.visual,"hurt",.08);continue
			if m.pose_phase!=m.phase:m.pose_phase=m.phase;m.pose_age=0.0
			else:m.pose_age+=dt
			if m.teleport_cd>.48:animation.set_pose(m.visual,"teleport",maxf(0,.6*(m.teleport_cd-.48)/.22))
			elif m.phase in ["windup","cleave_windup"]:animation.set_pose(m.visual,"windup",m.pose_age/m.get("windup_total",.8)*.16)
			elif m.phase=="cast":
				if m.get("pattern",0)==1:animation.set_pose(m.visual,"slash",fposmod(m.pose_age,.6 if m.get("rage",false) else .8)/(.6 if m.get("rage",false) else .8)*.52)
				elif m.get("pattern",0)==2:animation.set_pose(m.visual,"roar",m.pose_age)
				else:animation.set_pose(m.visual,"cast",m.pose_age)
			elif m.phase in ["slash","rush","cleave"]:animation.set_pose(m.visual,"slash",m.pose_age/(.28 if m.phase=="slash" else .46 if m.phase=="cleave" else .6)*.52)
			elif m.phase=="leap":animation.set_pose(m.visual,"leap",m.pose_age)
			elif m.phase=="pursuit":animation.set_pose(m.visual,"walk",m.visual.gait)
			elif m.phase=="recover":
				if m.moving and m.pose_age>.35:animation.set_pose(m.visual,"walk",m.visual.gait)
				else:animation.set_pose(m.visual,"recover",m.pose_age/.35*.24)
			elif m.phase=="rage":animation.set_pose(m.visual,"roar",m.pose_age/1.6*.9)
			elif m.phase=="pose":animation.set_pose(m.visual,"idle",0.0)
			elif m.phase in ["blink_chain","echoes"]:animation.set_pose(m.visual,"cast",fposmod(m.pose_age,1.0))
			elif m.phase=="skyfall":animation.set_pose(m.visual,"slash",.2)
			m.visual_dir=m.charge if m.phase in ["windup","slash","rush","cleave_windup","cleave","leap"] else m.dir

func update_attacks(dt: float):
	var all=build;build={}
	for id in all:
		if id not in END_WEAPONS:build[id]=all[id]
	super.update_attacks(dt);build=all
	for id in build:
		if id not in END_WEAPONS or id=="shield":continue
		cooldowns[id]=cooldowns.get(id,0.0)-dt
		if cooldowns[id]>0:continue
		damage_owner=id
		var target=nearest(player,240)
		if target==null:continue
		var s=db.stats(id,build[id],evolved.has(id),items)
		cooldowns[id]=s.interval;animation.strike(self,id,facing)
		match id:
			"spear":
				var aim: Vector2=player.direction_to(target.p)
				if dash_left<=0 and fall_age<0 and on_land(player+aim*28) and on_land(player+aim*s.range):
					facing=aim;start_dash(s.range/(movement_speed()*s.speed));sound("swing")
				else:
					# No safe ground ahead: the spear is thrust instead of charging.
					for m in in_radius(player+aim*s.range*.5,s.range*.5+12):
						if Geometry2D.get_closest_point_to_segment(m.p,player,player+aim*s.range).distance_to(m.p)<m.radius+10:hurt(m,s.damage*.8,aim*2)
					add_effect("spear_thrust",player,.25,{"direction":aim,"range":s.range});sound("swing")
			"mace":
				if jump_age<0 and not rocket:jump_age=0;jump_stats=s;jump_height=0;sound("wind_burst")
			"end_crystal":
				var p=player+facing*34
				if on_land(p):add_effect("placed_end_crystal",p,.85,{"stats":s,"triggered":false})
			"knockback_stick":
				for m in in_radius(player,s.radius):
					if facing.dot(player.direction_to(m.p))<-.1:continue
					hurt(m,s.damage,player.direction_to(m.p));m.knock=player.direction_to(m.p)*s.force*(1+rule("feather_knock")*items.get("feather",0));m.launch=1.2;m.collision_hits={}
					run_progress.mark_launch(m.id,true)
				add_effect("stick_swing",player,.3,{"direction":facing,"radius":s.radius});sound("swing")
			"dragon_breath":
				for j in range(int(s.count)):add_effect("friendly_breath",target.p+Vector2(j*32,0),s.duration,{"radius":s.radius,"damage":s.damage,"tick":0.0})
				sound("potion")
	# Melee swings can destroy the same homing bullets that arrows intercept.
	if build.has("sword") and clock-attack_visuals.get("sword",{}).get("at",-10)<.13:
		var r=db.stats("sword",build.sword,false,items).radius
		for b in projectiles:
			if b.kind=="shulker_bullet" and player.distance_to(b.p)<r and facing.dot(player.direction_to(b.p))>.25:b.life=0

func end_blast(at: Vector2, radius: float, damage: float, effect: String):
	damage_source="explosion" if effect=="crystal_blast" else "melee"
	for m in in_radius(at,radius):
		if m.kind=="end_dragon" and m.altitude>radius:continue
		hurt(m,damage,at.direction_to(m.p)*1.5)
	damage_source="melee"
	for b in projectiles:
		if b.kind=="shulker_bullet" and at.distance_to(b.p)<radius:b.life=0
	break_props(at,radius,damage);add_effect(effect,at,.65,{"radius":radius});sound("explosion",.12)

func fire_projectile(kind: String, p: Vector2, direction: Vector2, s: Dictionary, evolution: bool):
	var hostile=kind in ["shulker_bullet","slow_arrow","poison_arrow","dragon_fireball","end_bullet","end_blade","enemy_arrow"]
	var count=0
	for b in projectiles:
		if (b.kind in ["shulker_bullet","slow_arrow","poison_arrow","dragon_fireball","end_bullet","end_blade","enemy_arrow"])==hostile:count+=1
	if count>=(430 if hostile else int(db.data.projectile_cap)):return
	projectiles.append({"kind":kind,"p":p,"origin":p,"dir":direction,"speed":s.speed,"damage":s.damage,"range":s.range,"radius":s.radius,"pierce":s.get("pierce",0),"distance":0.0,"hit":{},"returning":false,"evolved":evolution,"lightning":false,"life":s.get("life",6.0),"age":0.0,"turn_age":0.0,"duration":s.get("duration",2.5),"turn":s.get("turn",0.0),"acceleration":0.0,"orbit_owner":-1,"orbit_angle":0.0,"orbit_speed":0.0,"path_tick":0.0,"axis_timer":.3,"axis":Vector2.UP,"velocity":Vector2.UP*22,"trail":[]})

func enemy_arrow_hit(a: Vector2, b: Vector2, amount: float) -> bool:
	if Geometry2D.get_closest_point_to_segment(player,a,b).distance_to(player)>=9:return false
	contact_hit(a,amount,{"dir":a.direction_to(b),"damage":amount});return true

func update_projectiles(dt: float):
	var custom=[];var ordinary=[]
	for b in projectiles:
		if b.kind in ["shulker_bullet","slow_arrow","poison_arrow","dragon_fireball","end_bullet","end_blade"]:custom.append(b)
		else:ordinary.append(b)
	# Endermen dodge before the old arrow collision loop can apply any damage.
	for b in ordinary:
		if b.kind not in ["arrow","bolt"]:continue
		for m in in_radius(b.p,35):
			if m.kind not in ["enderman","dispenser_enderman"]:continue
			if Geometry2D.get_closest_point_to_segment(m.p,b.p,b.p+b.dir*b.speed*dt).distance_to(m.p)<m.radius+5:teleport_mob(m,m.p+b.dir.orthogonal()*75);b.hit[m.id]=true
		for target in custom:
			if target.kind=="shulker_bullet" and target.p.distance_to(b.p)<12:target.life=0;b.life=0
	projectiles=ordinary.filter(func(b):return b.life>0)
	damage_source="projectile"
	super.update_projectiles(dt)
	damage_source="melee"
	for b in custom:
		if b.life<=0:continue
		var old: Vector2=b.p;b.age+=dt;b.life-=dt
		if b.kind=="shulker_bullet":
			b.path_tick+=dt
			while b.path_tick>=.05:
				b.path_tick-=.05;b.axis_timer-=.05
				if b.axis_timer<=0 or (b.p-player).length()<14:
					var delta: Vector2=player-b.p
					var axes=[Vector2(signf(delta.x),0),Vector2(0,signf(delta.y))]
					var next=axes[1] if absf(b.axis.x)>.1 else axes[0]
					if next==Vector2.ZERO:next=axes[0] if axes[0]!=Vector2.ZERO else axes[1]
					# Detour around solid landmarks, choosing a different axis at each corner.
					if blocked.has(Vector2i((b.p+next*20)/CELL)):next=-next
					b.axis=next;b.axis_timer=.5+float(int(b.age*20)%5)*.5
				b.velocity=b.velocity.lerp(b.axis*72,.2);b.p+=b.velocity*.05
			b.dir=b.velocity.normalized();b.trail.append(b.p)
			if b.trail.size()>16:b.trail.pop_front()
		else:
			b.dir=b.dir.rotated(b.get("turn",0.0)*dt);b.p+=b.dir*b.speed*dt
		b.distance+=old.distance_to(b.p)
		var dead=b.life<=0 or b.distance>b.range
		if Geometry2D.get_closest_point_to_segment(player,old,b.p).distance_to(player)<9 and fall_age<0:
			var landed=contact_hit(old,b.damage,b)
			if landed:
				if b.kind=="shulker_bullet":levitation=6
				if b.kind=="slow_arrow":slow_time=3.5
				if b.kind=="poison_arrow":poison_time=4
				if b.kind=="dragon_fireball":hazards.append({"p":b.p,"wait":0.0,"radius":36.0,"damage":2.0,"remaining":4.5,"fire":false,"end_cloud":true})
			dead=true
		if dead and b.kind=="dragon_fireball" and not b.get("impact",false):
			hazards.append({"p":b.p,"wait":.7,"total":.7,"radius":34.0,"damage":2.0,"remaining":4.0,"end_cloud":true});add_effect("dragon_impact",b.p,.6,{"radius":36.0});fx.blast(self,b.p,30.0)
		if not dead:projectiles.append(b)

func update_hazards(dt: float):
	for i in range(hazards.size()-1,-1,-1):
		var h=hazards[i];h.wait-=dt
		if h.wait>0:continue
		if h.get("kind","")=="end_cut":
			if not h.get("triggered",false):
				h.triggered=true;h.tick=0.0
				add_effect("end_cut",h.p,.38,{"end":h.end,"radius":h.radius,"echo":h.get("echo",false)})
				sound("swing",.12)
			h.remaining-=dt;h.tick-=dt
			if h.tick<=0:
				h.tick=.45
				if Geometry2D.get_closest_point_to_segment(player,h.p,h.end).distance_to(player)<h.radius+6 and jump_height+levitation_height<20:contact_hit(h.p,h.damage)
			if h.remaining<=0:hazards.remove_at(i)
			continue
		if not h.get("triggered",false):
			h.triggered=true;h.remaining=h.get("remaining",.2);h.tick=0.0
			if h.get("kind","")=="end_bolt":add_effect("end_bolt",h.p,.45,{"radius":h.radius});fx.quake(self,h.p,.8);fx.flash(h.p,120.0,Color(.8,.5,1),.2);fx.stain(h.p,h.radius*.5,"scorch",clock);sound("ch4_hb_lightning",.08)
			else:add_effect("dragon_cloud",h.p,h.remaining,{"radius":h.radius})
		h.remaining-=dt;h.tick-=dt
		if h.tick<=0:
			h.tick+=.45
			if player.distance_to(h.p)<h.radius and jump_height+levitation_height<20:contact_hit(h.p,h.damage)
		if h.remaining<=0:hazards.remove_at(i)

func update_effects(dt: float):
	for e in effects:
		if e.kind=="end_pearl" and e.age+dt>=e.total:
			var destination=safe_destination(e.end,56)
			if destination!=null:teleport_to(destination)
		elif e.kind=="placed_end_crystal" and e.age+dt>.65 and not e.triggered:
			e.triggered=true;damage_owner="end_crystal";end_blast(e.p,e.stats.radius,e.stats.damage,"crystal_blast")
			if evolved.has("end_crystal"):
				for j in range(4):add_effect("end_aftershock",e.p+Vector2.from_angle(j*PI/2)*e.stats.radius*.7,.85+j*.1,{"radius":e.stats.radius*.6,"damage":e.stats.damage*.4,"triggered":false})
		elif e.kind=="end_aftershock" and not e.triggered and e.age+dt>=e.total-.15:e.triggered=true;damage_owner="end_crystal";end_blast(e.p,e.radius,e.damage,"crystal_blast")
		elif e.kind=="friendly_breath":
			e.tick-=dt
			if e.tick<=0:
				e.tick+=.4;damage_owner="dragon_breath"
				for m in in_radius(e.p,e.radius):hurt(m,e.damage)
	super.update_effects(dt)

func break_pumpkin(p: Dictionary):
	if p.get("has_heal",false):loot.append({"kind":"chorus_fruit","p":p.p,"source":p.p})
	add_effect("break",p.p,.4);sound("break")

func pickup(dt: float):
	var radius: float=pickup_radius()
	for i in range(orbs.size()-1,-1,-1):
		var o=orbs[i]
		if o.p.distance_to(player)<=radius:o.attracted=true
		if o.attracted:o.p=o.p.move_toward(player,dt*orb_pull_speed())
		if o.p.distance_to(player)<7:xp+=o.value;orbs.remove_at(i);sound("xp",.09)
	for i in range(loot.size()-1,-1,-1):
		var o=loot[i]
		pull_healing_loot(o,dt)
		if o.p.distance_to(player)>10:continue
		if o.kind=="chorus_fruit":
			if clock<o.get("retry",-1):continue
			var destination=safe_destination(o.get("source",o.p),160,true)
			if destination==null:o.retry=clock+.35;continue
			run_progress.healing();hp=minf(20,hp+4);loot.remove_at(i);teleport_to(destination);sound("chorus_eat");continue
		if o.kind=="end_hand":
			hand_taken=true;stage="hand_pickup";stage_age=0;facing=player.direction_to(o.p);sound("pickup");loot.remove_at(i);continue
		if o.kind=="chest":
			if not city.is_empty() and o.p.distance_to(city.p)<40:
				run_progress.award("end_city")
				# Scratched into the lid by someone who has opened it many times.
				if not city.get("note_read",false):city.note_read=true;say("На крышке выцарапано: «Пожалуйста, не ходи к порталу»",4.5)
			if not pending_chest.is_empty():continue
			pending_chest=o.duplicate()
		else:apply_upgrade(o.kind)
		loot.remove_at(i)

func apply_upgrade(id: String):
	if id=="ender_eye":return
	super.apply_upgrade(id)
	if id=="shield" and shield_timer<=0:shield_charges=int(db.stats(id,build[id],evolved.has(id),items).count)

func resolve_deaths():
	var dragon_dead=false;var steve_dead=false
	for m in mobs:
		if m.hp>0:continue
		if m.kind=="arena_crystal":
			for t in crystals:
				if t.id==m.id:t.alive=false
			add_effect("crystal_blast",m.p,.8,{"radius":55.0});sound("explosion");fx.blast(self,m.p,40.0);fx.erupt(self,m.p,"stone",10)
		elif m.kind=="end_dragon":dragon_dead=true;defeated_boss=m.duplicate(true)
		elif m.kind=="endersteve_final":steve_dead=true;endsteve_corpse=m.duplicate(true)
		elif m.kind=="endersteve":loot.append({"kind":"chest","p":m.p,"born":time});add_effect("end_teleport",m.p,.7,{"radius":30.0});sound("end_teleport")
		if m.kind not in ["arena_crystal","end_dragon","endersteve_final"]:fx.death(self,m)
		# The foot was a free full heal every few kills; now rarer, with a pause between drops.
		if m.kind not in ["arena_crystal","end_dragon","endersteve_final"] and heal_drop_cd<=0 and heal_rng.randf()<.012*items.get("rabbit_foot",0):
			heal_drop_cd=3.0;loot.append({"kind":"golden_carrot" if items.get("rabbit_foot",0)>=5 and heal_rng.randf()<.35 else "apple","p":m.p})
	super.resolve_deaths()
	if dragon_dead or steve_dead:
		for pool in [mobs,projectiles,hazards,explosives,tnt_groups,effects,tasks,orbs,loot]:pool.clear()
		rebuild_hit_grid();invulnerable=2;player_push=Vector2.ZERO;dash_left=0;rocket=false;jump_age=-1;jump_height=0
		slow_time=0;poison_time=0;player_burn=0;player_wither=0;flight=0;levitation=0;levitation_height=0;levitation_velocity=0
		stage="dragon_death" if dragon_dead else "clash";stage_age=0
		if dragon_dead:
			sound("dragon_death");fx.quake(self,defeated_boss.p,3.0);fx.flash(defeated_boss.p,320.0,Color(.9,.6,1),.9);fx.ring(defeated_boss.p,200.0,1.2,"evolve")
		else:
			# Defeat is not death: he goes down on his knees and stays.
			npc={"p":endsteve_corpse.p,"dir":endsteve_corpse.visual_dir,"from":endsteve_corpse.p}
			boss_victory_serial+=1
			if hp>0:run_progress.finish(self)
			sound("ch4_body_fall");sound("end_teleport")

func begin_arena():
	time=db.data.duration;stage="departure";stage_age=0;invulnerable=3;message_timer=0

func prepare_arena():
	time=db.data.duration;slow_time=0;poison_time=0;levitation=0;levitation_height=0;levitation_velocity=0;player_burn=0;player_wither=0
	stage="dragon_arrival";stage_age=0;player=Vector2(1024,1175);last_safe=player;scene_camera=Vector2(1024,1080);facing=Vector2.UP;hp=minf(20,hp+8)
	for pool in [mobs,projectiles,effects,particles,pixels,loot,orbs,tasks,props,explosives,tnt_groups,hazards,magma,pending_events,crystals,dragon_history,landmarks]:pool.clear()
	city={};gust={}
	blocked.clear();solid_grid.clear();pending_chest={};invulnerable=4;flight=0;dash_left=0;rocket=false;jump_age=-1;fall_age=-1;player_push=Vector2.ZERO
	portal_position=Vector2(1024,1056);portal_lit=false
	for i in range(6):
		var p=Vector2(1024,1008)+Vector2.from_angle(-PI/2+i*TAU/6)*Vector2(265,195)
		spawn("arena_crystal",p);crystals.append({"p":p,"id":mobs.back().id,"alive":true})
	spawn("end_dragon",Vector2(1024,1010));update_flow();rebuild_hit_grid()

func next_level():
	super.next_level();choice_age=0;choice_tick=0;rerolls=1 if items.get("end_eye",0)>=2 else 0
	chosen_item="";chosen_index=-1;choice_hold=0

func make_choices() -> Array:
	var result=super.make_choices();var count=5 if items.get("end_eye",0)>=3 else 4 if items.get("end_eye",0)>=1 else 3
	var pool=reward_pool()
	for id in result:pool.erase(id)
	while result.size()<count and not pool.is_empty():
		var i=rng.randi_range(0,pool.size()-1);result.append(pool[i]);pool.remove_at(i)
	while result.size()<count:result.append(["apple","experience","golden_carrot"][result.size()%3])
	return result

func reward_pool() -> Array:
	var pool=eligible()
	pool.append_array(["apple","golden_carrot","experience"])
	return pool

func tick_choices(dt: float):
	if state!="LEVEL_UP":return
	if not chosen_item.is_empty():
		choice_hold-=dt
		if choice_hold<=0:
			var index=chosen_index
			chosen_item="";chosen_index=-1
			super.choose(index)
		return
	choice_age+=dt
	var tick=int(choice_age/.21)
	if tick==choice_tick:return
	choice_tick=tick
	# Eye IV/V no longer swap cards mid-choice: see world.eye_extras().
	var count=0
	for i in range(maxi(0,choices.size()-count),choices.size()):
		if count==0:break
		var pool=reward_pool()
		for id in choices:pool.erase(id)
		if pool.is_empty():pool=["apple","experience","golden_carrot"];pool.erase(choices[i])
		if not pool.is_empty():choices[i]=pool[reward_rng.randi_range(0,pool.size()-1)]

func reroll_choices() -> bool:
	if state!="LEVEL_UP" or rerolls<=0 or not chosen_item.is_empty():return false
	rerolls-=1;choices=make_choices();choice_age=0;choice_tick=0;sound("select");return true

func choose(index: int):
	if state!="LEVEL_UP" or index<0 or index>=choices.size() or not chosen_item.is_empty():return
	chosen_item=choices[index];chosen_index=index;chosen_level=build.get(chosen_item,items.get(chosen_item,0))+1;choice_hold=.55
	if evolved_offer.has(chosen_item):evolved[chosen_item]=true
	side_choices=[]
	sound("select")

func skip_reward() -> bool:
	if not chosen_item.is_empty():return false
	return super.skip_reward()

func discard(id: String) -> bool:
	if not super.discard(id):return false
	if id=="spear":dash_left=0;rocket=false
	if id=="mace":jump_age=-1;jump_height=0
	if id=="elytra":flight=0;rocket=false
	if id=="shield":shield_charges=0;shield_timer=0
	var kinds={"end_crystal":["placed_end_crystal","end_aftershock"],"dragon_breath":["friendly_breath"],"ender_pearl":["end_pearl"]}.get(id,[])
	for i in range(effects.size()-1,-1,-1):
		if effects[i].kind in kinds:effects.remove_at(i)
	return true

## The final clash destroys every carried weapon/passive. EnderSteve's later
## gifts are separate story events; no old weapon queues can revive afterward.
func shatter_clash_gear():
	if not broken_gear.is_empty():return
	for id in build:broken_gear.append({"id":id,"level":int(build[id]),"evolved":evolved.has(id)})
	for id in items:broken_gear.append({"id":id,"level":int(items[id]),"evolved":evolved.has(id)})
	build.clear();items.clear();evolved.clear();cooldowns.clear();weapon_visuals.clear();attack_visuals.clear();tasks.clear()
	player_visual.weapon=""
	for list in [projectiles,explosives,tnt_groups,hazards,magma]:list.clear()
	shield_charges=0;shield_timer=0;flight=0;dash_left=0;rocket=false
