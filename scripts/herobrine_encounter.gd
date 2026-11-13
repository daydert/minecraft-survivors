extends RefCounted
## Solo chapter I duel. Herobrine first plays with Steve at his own size,
## rebuilds his throne, fights from it, and ends the run with a "fun" punch.
## The secret ending (his health emptied) has Steve deflect that punch.
const CENTER=Vector2(1024,1024)
const BOSS_AT=CENTER+Vector2(0,-24)
const KNEEL_AT=CENTER+Vector2(0,44)
const GREET_AT=CENTER+Vector2(0,58)
const TEASE_DODGES=6
const TEASE_LENGTH=14.0
const THRONE_LENGTH=5.2
const THRONE_BUILD=[1.3,3.6]
const THRONE_SEAT=3.9
const VILLAGER_LENGTH=4.2
const VILLAGER_FIRST=5.0
const VILLAGER_EVERY=24.0
const SHOW_LENGTH=7.6
const SHOW_PUNCH=4.1
const DESCEND_LENGTH=12.2
const DESCEND_PARRY=3.7
const WHISPER=[5.4,10.6]
const WHISPER_TEXT="Почему ты не хочешь попасть к ней побыстрее?"
var active=false
var complete=false
var elapsed=0.0
var phase=""
var phase_age=0.0
var fight_age=0.0
var ritual_elapsed=0.0
var strikes: Array=[]
var waves: Array=[]
var boss: Dictionary={}
var next_strike=1.4
var next_wave=5.0
var strike_index=0
var wave_index=0
var start_camera=Vector2.ZERO
var ritual_camera=Vector2.ZERO
var teleport_from=Vector2.ZERO
var teleported=false
var destroyed=false
var first_stage_won=false
var rng=RandomNumberGenerator.new()
## Presentation state read by the renderer; it never feeds back into combat.
var hb_p=GREET_AT
var hb_dir=Vector2.DOWN
var hb_pose="idle"
var hb_pose_age=0.0
var hb_face="smile"
var hb_visible=false
var on_throne=false
var dodges=0
var dodge_from=Vector2.ZERO
var dodge_to=Vector2.ZERO
var dodge_age=-1.0
var ghosts: Array=[]
var line=""
var line_age=0.0
var line_length=0.0
var villager: Dictionary={}
var next_villager=VILLAGER_FIRST
var villager_count=0
var cues=0
var freeze=0.0
var sparks: Array=[]
## Steve's gear spilling out when he dies, as on any death in the game.
var lost: Array=[]
## The throne fight v2 (13.11): he does not sit it out. Between storms he leaves the
## throne, blinks to Steve, lunges, slams, laughs (the opening), and returns.
var assault: Dictionary={}
var next_assault=2.5

func reset():
	active=false;complete=false;elapsed=0;phase="";phase_age=0;fight_age=0;ritual_elapsed=0
	strikes.clear();waves.clear();boss={}
	next_strike=1.4;next_wave=5;strike_index=0;wave_index=0
	teleported=false;destroyed=false;first_stage_won=false
	hb_p=GREET_AT;hb_dir=Vector2.DOWN;hb_pose="idle";hb_pose_age=0;hb_face="smile";hb_visible=false;on_throne=false
	dodges=0;dodge_age=-1;ghosts.clear();line="";line_age=0;line_length=0
	villager={};next_villager=VILLAGER_FIRST;villager_count=0;;cues=0;freeze=0;sparks.clear();lost.clear()

func duel_phase() -> bool:return true

func begin(w):
	reset();start_camera=w.camera();rng.seed=int(w.rng.seed)^0x48e12
	active=true;phase="arrival";w.state="FINALE";w.time=720
	w.player=CENTER+Vector2(0,116);w.facing=Vector2.UP;w.player_moving=false
	w.win_music=false;w.victory=false;w.invulnerable=0
	for pool in [w.mobs,w.projectiles,w.orbs,w.loot,w.tasks,w.effects,w.particles,w.pixels,w.choices,w.pending_events]:pool.clear()
	w.hit_grid.clear();w.pending_chest.clear();w.attack_visuals.clear();w.weapon_visuals.clear()
	w.message="";w.message_timer=0
	boss={"id":w.next_id(),"kind":"herobrine","p":GREET_AT,"dir":Vector2.DOWN,"hp":5200.0,"max_hp":5200.0,"speed":0.0,"damage":0.0,"xp":0,"radius":10.0,"timer":0.0,"fuse":-1.0,"flash":0.0,"burn":0.0,"burn_tick":.5,"phase":"idle","charge":Vector2.ZERO,"animation":0.0,"knock":Vector2.ZERO,"visual":w.animation.actor(),"moving":false,"visual_dir":Vector2.DOWN,"dodge_all":true}
	w.mobs.append(boss);w.rebuild_hit_grid();w.sound("herobrine",1)

# ------------------------------------------------------------------ presentation helpers

func say(text: String, length: float):line=text;line_age=0;line_length=length
func pose(name: String):
	if hb_pose!=name:hb_pose=name;hb_pose_age=0
func cue(bit: int, at: float, id: String, w, gap: float=.05) -> bool:
	if phase_age>=at and not (cues&(1<<bit)):
		cues|=1<<bit
		if not id.is_empty():w.sound(id,gap)
		return true
	return false
func throne_built() -> float:
	if phase in ["arrival","greet","tease"]:return 0.0
	if phase=="throne":return smoothstep(THRONE_BUILD[0],THRONE_BUILD[1],phase_age)
	return 1.0
func giant_visible() -> bool:
	if phase=="throne":return phase_age>=THRONE_SEAT
	if phase in ["storm","inferno"]:return assault.is_empty()
	if phase=="showtime":return phase_age<.45
	if phase=="descend":return phase_age<.4 or phase_age>=WHISPER[1]+.25
	return phase not in ["arrival","greet","tease"]
func small_visible() -> bool:return hb_visible and not giant_visible()
func whisper() -> float:
	if phase!="descend":return 0.0
	return smoothstep(WHISPER[0],WHISPER[0]+.6,phase_age)*(1-smoothstep(WHISPER[1]-.5,WHISPER[1],phase_age))

func camera(w) -> Vector2:
	if phase=="arrival":return start_camera.lerp(CENTER+Vector2(0,38),smoothstep(0,2.6,phase_age))
	if phase in ["greet","throne"]:return CENTER+Vector2(0,38)
	if phase in ["tease","storm","inferno"]:
		# Throne v2 is taller: frame it whole, with room above for the HUD.
		var desired=(w.player.lerp(CENTER+Vector2(0,-62),.62)).clamp(w.player-Vector2(245,140),w.player+Vector2(245,125))
		var settle: float=phase_age if phase=="tease" else fight_age
		return (CENTER+Vector2(0,38)).lerp(desired,smoothstep(0,1.2,settle)) if settle<1.2 else desired
	if phase in ["showtime","descend"]:return ritual_camera.lerp(w.player+Vector2(0,-14),smoothstep(0,1.0,ritual_elapsed))
	if not first_stage_won and phase in ["defeated","portal","fall"]:
		return ritual_camera.lerp(w.player+Vector2(0,-12),smoothstep(0,1.2,ritual_elapsed))
	var target=CENTER+Vector2(0,30)
	if phase=="fall":target=target.lerp(w.player,smoothstep(0,2,phase_age))
	return ritual_camera.lerp(target,smoothstep(0,2.8,ritual_elapsed))

func scorch() -> float:return clampf(fight_age/15,0,.95)
func fall_progress() -> float:return clampf(phase_age/4,0,1) if phase=="fall" else 0.0
func cinematic_player() -> bool:return phase in ["greet","throne","showtime","descend","rising","summon","kneel","rift","vanish","defeated","portal","fall"]
func blood_progress() -> float:return smoothstep(.1,4.9,phase_age) if phase=="rift" else 1.0 if phase=="vanish" else 0.0
func blood_wipe() -> float:return smoothstep(0,3,phase_age) if phase=="vanish" else 0.0

func wave_active(angle: float, wave: Dictionary) -> bool:
	for hole in [wave.gap,wave.gap+PI]:
		if absf(angle_difference(angle,hole))<.38:return false
	return true

func hit(w, amount: float):w.damage_player(amount)

func change(next: String):phase=next;phase_age=0;cues=0

func clear_combat(w):
	strikes.clear();waves.clear();villager={};assault={};hb_visible=false;on_throne=true
	for pool in [w.mobs,w.projectiles,w.effects,w.tasks,w.weapon_visuals,w.attack_visuals]:pool.clear()
	w.hit_grid.clear();w.player_moving=false

## Called by the world instead of damage while he is only playing.
func dodge(w, m: Dictionary):
	if dodge_age>=0 and dodge_age<.22:return
	var away: Vector2=w.player.direction_to(hb_p) if w.player.distance_to(hb_p)>1 else Vector2.UP
	var side: Vector2=away.orthogonal()*(1 if dodges%2==0 else -1)
	dodge_from=hb_p
	dodge_to=(hb_p+side*34+away*10).clamp(CENTER-Vector2(260,160),CENTER+Vector2(260,200))
	dodge_age=0;dodges+=1
	ghosts.append({"p":hb_p,"pose":hb_pose,"age":0.0,"dir":hb_dir})
	pose("sway" if dodges%3==0 else ("dodge_l" if side.x<0 else "dodge_r"))
	w.sound("ch1_whoosh",.05)
	m.flash=0
	var taunts={1:["Мимо",1.4],3:["Ты вообще целишься?",1.8],5:["Скукотень",1.5]}
	if taunts.has(dodges):say(taunts[dodges][0],taunts[dodges][1])

## QA and harness entry: straight to the throne fight, as the old duel began.
func skip_to_fight(w):
	change("storm");fight_age=0;hb_visible=false;on_throne=true;hb_p=BOSS_AT;line=""
	boss.p=BOSS_AT;boss.radius=26.0;boss.dodge_all=false

func begin_throne(w):
	change("throne");pose("shrug")
	say("Что ж, думаю, разминки хватит",2.2)
	w.projectiles.clear();w.tasks.clear();w.weapon_visuals.clear();w.attack_visuals.clear()
	boss.dodge_all=false

func begin_second(w):
	first_stage_won=true
	w.run_progress.award("herobrine")
	ritual_camera=camera(w);ritual_elapsed=0;change("rising")
	clear_combat(w)

## Steve has lost: Herobrine comes down to finish him with his favourite trick.
## The close scenes need room behind Steve, clear of the throne.
func stage_player(w):
	var room: float=BOSS_AT.y+118
	if w.player.y<room:w.player=Vector2(clampf(w.player.x,CENTER.x-200,CENTER.x+200),room)

func begin_show(w):
	stage_player(w)
	ritual_camera=camera(w);ritual_elapsed=0
	change("showtime");w.hp=maxf(w.hp,.01);w.invulnerable=99
	clear_combat(w);w.facing=Vector2.DOWN

func begin_fall(w):
	ritual_camera=camera(w);ritual_elapsed=0
	change("defeated");w.hp=0;destroyed=true;w.player_moving=false;w.invulnerable=0
	clear_combat(w)

# ------------------------------------------------------------------ the playful first stage

func tease(w, dt: float, movement: Vector2):
	if movement.length_squared()>0:
		w.facing=movement.normalized()
		w.player=w.move_actor(w.player,movement.limit_length()*w.movement_speed()*dt,6)
	if dodge_age>=0:
		dodge_age+=dt
		var k: float=smoothstep(0,.2,dodge_age)
		hb_p=dodge_from.lerp(dodge_to,k)
		if dodge_age>.55:dodge_age=-1;pose("laugh" if dodges%2==1 else "idle")
	else:
		# He keeps a lazy distance and circles, never quite in reach.
		var off: Vector2=hb_p-w.player
		var want: float=82.0
		var radial: Vector2=off.normalized()*(want-off.length())*1.6
		var orbit: Vector2=off.normalized().orthogonal()*14.0
		var v: Vector2=(radial+orbit).limit_length(48.0)
		hb_p=(hb_p+v*dt).clamp(CENTER-Vector2(260,160),CENTER+Vector2(260,200))
		if hb_pose in ["idle","stroll","laugh","shrug"] and hb_pose_age>1.6:
			pose("stroll" if v.length()>12 else ("shrug" if int(phase_age)%5==0 else "idle"))
	hb_dir=hb_p.direction_to(w.player)
	boss.p=hb_p
	w.rebuild_hit_grid();w.update_attacks(dt);w.update_projectiles(dt);w.update_effects(dt);w.pickup(dt)
	boss.hp=boss.max_hp;boss.burn=0
	if dodges>=TEASE_DODGES or phase_age>=TEASE_LENGTH:begin_throne(w)

func throne_scene(w, dt: float):
	if phase_age>=.9 and phase_age<THRONE_BUILD[1]:pose("cast")
	cue(0,THRONE_BUILD[0],"ch4_stone_rise",w)
	for i in range(6):cue(1+i,THRONE_BUILD[0]+.3+i*.36,"ch1_wood_place" if i%2 else "ch4_stone_hit",w,.02)
	cue(8,THRONE_BUILD[1],"fire",w)
	if cue(9,THRONE_SEAT-.25,"herobrine_warp",w):teleport_from=hb_p
	if phase_age>=THRONE_SEAT:hb_p=BOSS_AT;boss.p=BOSS_AT;on_throne=true
	if phase_age>=THRONE_LENGTH:
		change("storm");fight_age=0;boss.radius=26.0
		line=""

# ------------------------------------------------------------------ the throne fight

func villager_step(w, dt: float):
	if villager.is_empty():
		if fight_age>=next_villager:
			var side: float=-1.0 if villager_count%2==0 else 1.0
			villager={"p":CENTER+Vector2(side*46,62),"age":0.0}
			villager_count+=1;next_villager+=VILLAGER_EVERY
			w.sound("ch1_villager_hurt",.1)
		return
	villager.age+=dt
	var a: float=villager.age
	var schedule=[[.9,"ch1_villager_no"],[1.8,"ch1_villager_hurt"],[2.3,"ch4_bone_crack"],[2.7,"ch4_bone_crack"],[3.0,"ch4_flesh_hit"],[3.2,"ch4_bone_crack"],[3.6,"hurt_ch1_crawler"]]
	for i in range(schedule.size()):
		var bit: int=1<<i
		if a>=float(schedule[i][0]) and not (int(villager.get("cues",0))&bit):
			villager.cues=int(villager.get("cues",0))|bit;w.sound(schedule[i][1],.05)
	if a>=VILLAGER_LENGTH:
		var p: Vector2=villager.p
		villager={}
		w.mobs.append({"id":w.next_id(),"kind":"ch1_crawler","p":p,"dir":Vector2.DOWN,"hp":30.0,"max_hp":30.0,"speed":30.0,"damage":2.0,"xp":0,"radius":8.0,"timer":0.0,"fuse":-1.0,"flash":0.0,"burn":0.0,"burn_tick":.5,"phase":"walk","charge":Vector2.ZERO,"animation":0.0,"knock":Vector2.ZERO,"visual":w.animation.actor(),"moving":true,"visual_dir":Vector2.DOWN,"bite":0.0})
		w.rebuild_hit_grid()

## The legless villager drags himself toward Steve and bites when he reaches him.
func crawlers(w, dt: float):
	for i in range(w.mobs.size()-1,-1,-1):
		var m: Dictionary=w.mobs[i]
		if m.kind!="ch1_crawler":continue
		m.flash=maxf(0,m.flash-dt)
		if m.hp<=0:
			w.emit_pixels("smoke",m.p,8,Vector2.ZERO);w.sound("ch4_flesh_hit",.1);w.mobs.remove_at(i);continue
		var to: Vector2=m.p.direction_to(w.player)
		m.visual_dir=to;m.animation+=dt;m.bite=maxf(0,m.bite-dt)
		m.p+=m.knock*dt;m.knock=m.knock.move_toward(Vector2.ZERO,dt*260)
		if m.p.distance_to(w.player)>12:m.p=w.move_actor(m.p,to*m.speed*dt,6);m.moving=true
		else:
			m.moving=false
			if m.bite<=0:m.bite=.9;hit(w,2);w.sound("ch4_flesh_hit",.1)

func combat(w, dt: float, movement: Vector2):
	fight_age+=dt
	phase="storm" if fmod(fight_age,20)<11 else "inferno"
	if movement.length_squared()>0:
		w.facing=movement.normalized()
		w.player=w.move_actor(w.player,movement.limit_length()*w.movement_speed()*dt,6)
	if boss.burn>0:
		boss.burn-=dt;boss.burn_tick-=dt
		if boss.burn_tick<=0:boss.burn_tick+=.5;w.hurt(boss,w.burn_damage(boss))
	w.rebuild_hit_grid();w.update_attacks(dt);w.update_projectiles(dt);w.update_effects(dt);w.pickup(dt)
	if boss.hp<=0:begin_second(w);return
	villager_step(w,dt);crawlers(w,dt)
	assault_step(w,dt)
	# While he wrings a villager or fights in person, his storm holds its breath.
	var twisting: bool=(not villager.is_empty() and villager.age<3.2) or not assault.is_empty()
	if twisting:next_strike+=dt;next_wave+=dt
	while fight_age>=next_strike:
		var target=w.player if strike_index%3!=2 else CENTER+Vector2.from_angle(strike_index*2.399)*rng.randf_range(180,430)
		if strike_index%3==1:target+=Vector2.from_angle(strike_index*2.399)*60
		strikes.append({"p":target,"age":0.0,"hit":false,"seed":strike_index})
		strike_index+=1;next_strike+=1.1
	for i in range(strikes.size()-1,-1,-1):
		var s=strikes[i];s.age+=dt
		if s.age>=.85 and not s.hit:
			s.hit=true
			if s.p.distance_to(w.player)<20:hit(w,2.5)
			if w.visible(s.p,40):w.sound("lightning",.25);w.shake=.08
		if s.age>1.25:strikes.remove_at(i)
	while fight_age>=next_wave:
		waves.append({"age":0.0,"radius":0.0,"speed":115.0,"index":wave_index,"gap":CENTER.direction_to(w.player).angle()+wave_index*.25})
		wave_index+=1;next_wave+=3.6;w.sound("fire_wave",.4)
	for i in range(waves.size()-1,-1,-1):
		var wave=waves[i];wave.age+=dt;wave.radius=wave.age*wave.speed
		if absf(w.player.distance_to(CENTER)-wave.radius)<14 and wave_active(CENTER.direction_to(w.player).angle(),wave):hit(w,2.5)
		if wave.radius>1200:waves.remove_at(i)
	if w.hp<=0:begin_show(w)

## Off by the user's call (13.11): after the mockery he stays on the throne.
const ASSAULTS := false
func assault_step(w, dt: float):
	if not ASSAULTS:boss.p=BOSS_AT;boss.radius=26.0;return
	if assault.is_empty():
		boss.p=BOSS_AT;boss.radius=26.0;hb_visible=false;on_throne=true
		if fight_age<next_assault or not villager.is_empty():return
		assault={"state":"warp","age":0.0,"round":0,"rounds":2 if boss.hp>boss.max_hp*.5 else 3}
		teleport_from=BOSS_AT;w.sound("herobrine_warp",.1)
		hb_p=(w.player+Vector2.from_angle(rng.randf()*TAU)*90).clamp(CENTER-Vector2(300,170),CENTER+Vector2(300,220))
		hb_visible=true;on_throne=false;pose("aura");boss.radius=9.0
	var a: Dictionary=assault;a.age+=dt
	boss.p=hb_p;hb_dir=hb_p.direction_to(w.player) if a.state!="dash" else hb_dir
	match a.state:
		"warp":
			if a.age>=.35:a.state="dash_wind";a.age=0.0;a.from=hb_p;a.to=(w.player+hb_p.direction_to(w.player)*40).clamp(CENTER-Vector2(300,170),CENTER+Vector2(300,220));pose("donut_wind");w.sound("ch4_hb_charge",.1)
		"dash_wind":
			if a.age>=.62:a.state="dash";a.age=0.0;pose("donut");w.sound("ch1_whoosh",.05);hb_dir=Vector2(a.from).direction_to(a.to)
		"dash":
			var before: Vector2=hb_p
			hb_p=Vector2(a.from).lerp(a.to,smoothstep(0,.2,a.age))
			ghosts.append({"p":before,"pose":"donut","age":0.0,"dir":hb_dir})
			if not a.get("hit",false) and Geometry2D.get_closest_point_to_segment(w.player,before,hb_p).distance_to(w.player)<13:a.hit=true;hit(w,3.0)
			if a.age>=.24:
				a.state="slam_wind";a.age=0.0;pose("snap");a.hit=false
				a.marks=[]
				for j in range(6):a.marks.append((hb_p+Vector2.from_angle(j*TAU/6+rng.randf())*rng.randf_range(34,70)))
		"slam_wind":
			if a.age>=.7:
				a.state="slam";a.age=0.0;pose("cast");w.shake=.25;w.sound("lightning",.1);w.sound("ch4_ground_slam",.1)
				for q in a.marks:
					if q.distance_to(w.player)<18:hit(w,2.5);break
				if hb_p.distance_to(w.player)<32:hit(w,2.0)
		"slam":
			if a.age>=.35:a.state="taunt";a.age=0.0;pose("laugh");if rng.randf()<.5:say(["Медленно","Ну же","Ещё","Скучно"][rng.randi_range(0,3)],1.0)
		"taunt":
			# The opening: he stands and laughs; this is where Steve's blows land.
			if a.age>=1.0:
				a.round=int(a.round)+1
				if a.round>=int(a.rounds):
					a.state="return";a.age=0.0;teleport_from=hb_p;w.sound("herobrine_warp",.1)
				else:
					teleport_from=hb_p;w.sound("herobrine_warp",.1)
					hb_p=(w.player+Vector2.from_angle(rng.randf()*TAU)*95).clamp(CENTER-Vector2(300,170),CENTER+Vector2(300,220))
					a.state="warp";a.age=0.0;pose("aura")
		"return":
			if a.age>=.3:assault={};next_assault=fight_age+rng.randf_range(5.5,7.5);hb_visible=false;on_throne=true;hb_p=BOSS_AT;boss.p=BOSS_AT;boss.radius=26.0

# ------------------------------------------------------------------ the endings

func burst(w, at: Vector2, toward: Vector2, count: int, colour: Color):
	for i in range(count):
		var spread: Vector2=Vector2.from_angle(toward.angle()+rng.randf_range(-.9,.9))
		w.particles.append({"p":at,"v":spread*rng.randf_range(40,130)+Vector2(0,-rng.randf_range(10,60)),"life":rng.randf_range(.4,.9),"color":colour,"size":rng.randf_range(1.5,3.0)})

func drop_gear(w, at: Vector2):
	var ids: Array=[]
	for id in w.build:ids.append([id,w.evolved.has(id)])
	for id in w.items:ids.append([id,false])
	for i in range(ids.size()):
		var a: float=-PI/2+(i-(ids.size()-1)/2.0)*.55+rng.randf_range(-.15,.15)
		lost.append({"id":ids[i][0],"evolved":ids[i][1],"p":at,"v":Vector2(cos(a),.35)*rng.randf_range(38,70),"h":14.0,"vh":rng.randf_range(70,110),"age":0.0})
	w.sound("ch4_body_fall",.05)

func step_lost(dt: float):
	for o in lost:
		o.age+=dt;o.p+=o.v*dt;o.h+=o.vh*dt;o.vh-=260*dt
		if o.h<0:o.h=0;o.vh=-o.vh*.3;o.v*=.55
	lost=lost.filter(func(o):return o.age<3.2)

func showtime(w):
	var a: float=phase_age
	var behind: Vector2=w.player+Vector2(6,-6)
	if cue(0,.25,"herobrine_warp",w):teleport_from=BOSS_AT
	if a>=.45:hb_visible=true;on_throne=false;hb_p=behind;hb_dir=Vector2.DOWN;hb_face="smile"
	if a<1.0:pose("idle")
	elif a<2.7:pose("laugh")
	elif a<SHOW_PUNCH:pose("donut_wind")
	elif a<6.3:pose("donut" if a<SHOW_PUNCH+.25 else "donut_hold")
	else:pose("pull_out")
	if cue(1,.9,"",w):say("Хух, это было очень весело",2.0)
	if cue(2,2.9,"",w):say("Держи на память",1.6)
	cue(3,SHOW_PUNCH-.55,"ch1_whoosh",w)
	if cue(4,SHOW_PUNCH,"ch4_punch_heavy",w):
		w.sound("ch4_flesh_hit",.02);w.sound("ch4_bone_crack",.02)
		freeze=.16;w.shake=.4;w.hp=0;w.player_visual.hurt=.2
		burst(w,w.player+Vector2(0,-12),Vector2.DOWN,26,Color(.55,.02,.04))
		drop_gear(w,w.player)
	if cue(5,5.0,"ch4_heartbeat",w):say("Ха",1.0)
	if cue(6,6.3,"ch4_flesh_hit",w):burst(w,w.player+Vector2(0,-12),Vector2.UP,10,Color(.45,.02,.03))
	if a>=SHOW_LENGTH:
		hb_visible=false;begin_fall(w);w.sound("death",1)

func descend(w):
	var a: float=phase_age
	var behind: Vector2=w.player+Vector2(6,-6)
	if cue(0,.2,"herobrine_warp",w):teleport_from=BOSS_AT
	if a>=.4 and a<WHISPER[1]:hb_visible=true;on_throne=false
	if a<DESCEND_PARRY:
		hb_p=behind;hb_dir=Vector2.DOWN;hb_face="smile"
		pose("idle" if a<1.0 else ("shrug" if a<2.6 else "donut_wind"))
	if cue(1,.8,"",w):say("Ладно, ты меня развлёк",1.8)
	cue(2,DESCEND_PARRY-.5,"ch1_whoosh",w)
	if a>=DESCEND_PARRY-.35:w.facing=Vector2.UP
	if cue(3,DESCEND_PARRY,"ch1_parry",w):
		w.sound("shield_block",.02);freeze=.18;w.shake=.3
		for i in range(18):sparks.append({"p":w.player+Vector2(0,-16),"v":Vector2.from_angle(-PI/2+rng.randf_range(-1.3,1.3))*rng.randf_range(50,140),"age":0.0})
	if a>=DESCEND_PARRY and a<WHISPER[1]:
		var k: float=smoothstep(DESCEND_PARRY,DESCEND_PARRY+.35,a)
		hb_p=behind.lerp(behind+Vector2(0,-30),k);hb_dir=Vector2.DOWN
		hb_face="rage" if a>=DESCEND_PARRY+1.2 else "calm"
		pose("knocked" if a<DESCEND_PARRY+1.0 else ("stagger" if a<DESCEND_PARRY+1.6 else "idle"))
	cue(4,WHISPER[0],"ch4_hb_roar",w)
	cue(5,WHISPER[0]+.4,"ch4_heartbeat",w)
	if cue(6,WHISPER[1],"herobrine_warp",w):teleport_from=hb_p;hb_visible=false;on_throne=true
	if a>=DESCEND_LENGTH:change("summon");w.sound("herobrine_warp");teleport_from=w.player

func step(w, dt: float, movement: Vector2):
	if not active or complete:return
	if freeze>0:
		freeze=maxf(0,freeze-dt);w.shake=maxf(0,w.shake-dt)
		return
	elapsed+=dt;phase_age+=dt;hb_pose_age+=dt
	if line_length>0:
		line_age+=dt
		if line_age>=line_length:line="";line_length=0
	for g in ghosts:g.age+=dt
	ghosts=ghosts.filter(func(g):return g.age<.35)
	for s in sparks:s.age+=dt;s.p+=s.v*dt;s.v*=.9
	sparks=sparks.filter(func(s):return s.age<.5)
	step_lost(dt)
	if not boss.is_empty():boss.flash=maxf(0,boss.flash-dt)
	w.invulnerable=maxf(0,w.invulnerable-dt) if phase not in ["showtime"] else w.invulnerable
	w.shake=maxf(0,w.shake-dt)
	var old=w.player
	match phase:
		"arrival":
			if cue(0,1.6,"herobrine_warp",w):hb_visible=true;teleport_from=GREET_AT+Vector2(0,-40)
			hb_dir=Vector2.DOWN
			if phase_age>=3.0:change("greet");pose("wave");say("Йо",1.6)
		"greet":
			if phase_age>=1.8 and hb_pose=="wave":pose("idle")
			if cue(0,1.9,"",w):say("Ну давай, ударь меня",2.0)
			if phase_age>=4.0:change("tease");pose("idle")
		"tease":tease(w,dt,movement)
		"throne":throne_scene(w,dt)
		"storm","inferno":combat(w,dt,movement)
		"showtime":ritual_elapsed+=dt;showtime(w)
		"descend":ritual_elapsed+=dt;descend(w)
		_:
			ritual_elapsed+=dt
			match phase:
				"rising":
					if phase_age>=3.2:
						stage_player(w);ritual_camera=camera(w);ritual_elapsed=0;change("descend")
				"summon":
					if phase_age>=.45 and not teleported:w.player=KNEEL_AT;w.facing=Vector2.UP;teleported=true
					if phase_age>=1.2:change("kneel")
				"kneel":
					if phase_age>=1.2:change("rift");w.sound("blood_rift")
				"rift":
					if phase_age>=1.4 and not destroyed:
						w.hp=0;w.invulnerable=0;destroyed=true;w.sound("death");w.shake=.3;drop_gear(w,w.player)
					if phase_age>=5.2:change("vanish")
				"vanish":
					if phase_age>=3:change("portal");w.sound("portal_open")
				"defeated":
					if phase_age>=1.2:change("portal");w.sound("portal_open")
				"portal":
					if phase_age>=2:change("fall");w.sound("portal_travel")
				"fall":
					if phase_age>=4:change("end");complete=true;w.state="RESULT";w.victory=false;w.win_music=false
	w.player_visual.travel=w.player.distance_to(old) if phase in ["tease","storm","inferno"] else 0.0
	w.player_moving=w.player_visual.travel>.0001
	w.update_particles(dt);w.animation.advance(w,dt)
