extends "res://scripts/campaign_world.gd"
## Solo equipment and combat systems shared by chapter II and later chapters:
## the chapter II weapons, explosives, fire and wither status, mob control
## (hook pull / stun) and the chapter stage machine fields. Chapter specifics
## (terrain, mobs, bosses, arenas) live in nether_world.gd / end_world.gd.
const NEW_WEAPONS=["axe","hoe","bed","tnt","crossbow","fishing"]
var stage="survival"
var stage_age=0.0
var magma: Array=[]
var explosives: Array=[]
var tnt_groups: Array=[]
var hazards: Array=[]
var player_burn=0.0
var player_wither=0.0
var wither_tick=0.0
var burn_tick=0.0
var regen_tick=5.0
var pearl=false
var portal_lit=false
var portal_position=Vector2(1024,1024)
var tracked_velocity=Vector2.ZERO
var jump_start=Vector2.ZERO
var defeated_boss: Dictionary={}

func reset(seed_value: int = 0):
	stage="survival"
	stage_age=0
	magma.clear()
	explosives.clear()
	tnt_groups.clear()
	hazards.clear()
	player_burn=0
	player_wither=0;wither_tick=0
	burn_tick=0
	regen_tick=5
	pearl=false
	portal_lit=false
	tracked_velocity=Vector2.ZERO
	jump_start=Vector2.ZERO
	defeated_boss={}
	super.reset(seed_value)
	var extra: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/nether_animations.json"))
	animation=preload("res://scripts/animation.gd").new()
	animation.data.actors.merge(extra.actors,true)
	animation.data.weapons.merge(extra.weapons,true)

func spawn(kind: String, at = null) -> bool:
	if not super.spawn(kind,at):return false
	var m: Dictionary=mobs.back()
	m.aggro=0.0
	m.fire_aspect=kind=="piglin_sword" and (m.id%4==0)
	m.slow=0.0
	m.boss=false
	m.attack_tick=1.6
	m.slam_tick=6.0
	m.mark=Vector2.ZERO
	m.rage=false
	m.pattern=0
	m.windup=1.0
	m.burst_left=0
	m.burst_tick=0.0
	m.orbit_tick=4.0
	m.stun=0.0;m.pull_left=0.0;m.pull_dir=Vector2.ZERO;m.pull_stun=0.0;m.control_resist=0.0
	return true

## Chapter rule from the "rules" section of nether_balance.json / end_balance.json.
func rule(id: String) -> float:
	return float(db.data.rules[id])

## Hero regeneration from ghast tears, shared by chapters II and III.
func update_regeneration(dt: float):
	regen_tick-=dt
	if regen_tick<=0:
		regen_tick+=rule("regen_interval")
		if hp>0:hp=minf(20,hp+rule("ghast_tear_regen")*items.get("ghast_tear",0))

## Mobs that currently ignore the player (chapter II piglins with gold boots).
func neutral(_m: Dictionary) -> bool:
	return false

## Knockback multiplier applied to every weapon hit.
func knock_factor(_m: Dictionary) -> float:
	return 1+rule("feather_knock")*items.get("feather",0)

func hurt(m: Dictionary, amount: float, push: Vector2 = Vector2.ZERO):
	if m.hp<=0:return
	super.hurt(m,amount,push*knock_factor(m))

func nearest(p: Vector2, radius: float = 260):
	var best=radius*radius
	var result=null
	for m in in_radius(p,radius):
		if neutral(m):continue
		var distance=p.distance_squared_to(m.p)
		if distance<best:best=distance;result=m
	return result

func ignite(seconds: float):
	if hp>0:player_burn=maxf(player_burn,seconds)

func fire_damage(amount: float):
	if invulnerable>0 or hp<=0:return
	var before=hp
	hp-=maxf(.1,amount*(1-rule("fire_resist_per_level")*items.get("fire_resist",0)))
	run_progress.damage(before-hp)
	invulnerable=rule("status_hit_invulnerability")
	player_visual.hurt=.12
	sound("hurt",.2)

func update_fire(dt: float):
	for patch in magma:
		if player.distance_to(patch.p)<patch.radius:ignite(rule("magma_burn"));break
	if player_burn>0:
		player_burn=maxf(0,player_burn-dt)
		burn_tick-=dt
		if burn_tick<=0:burn_tick+=rule("burn_interval");fire_damage(rule("burn_damage"))
	else:burn_tick=0
	if player_wither>0:
		player_wither=maxf(0,player_wither-dt);wither_tick-=dt
		if wither_tick<=0:wither_tick+=rule("wither_interval");fire_damage(rule("wither_damage"))

func hook_target(m: Dictionary, evolved_hook: bool):
	if m.control_resist>0:return
	var distance=maxf(0,m.p.distance_to(player)-m.radius-16)
	m.pull_left=minf((70 if m.boss else 150)*(1+rule("feather_knock")*items.get("feather",0)),distance)
	m.pull_dir=m.p.direction_to(player)
	m.pull_stun=(.4 if evolved_hook else .25) if m.boss else (.95 if evolved_hook else .6)
	m.control_resist=1.8 if m.boss else .8
	m.knock=Vector2.ZERO
	if m.kind=="wither" and m.phase not in ["walk","recover","roar"]:
		m.phase="recover";m.timer=.45;m.burst_left=0
	elif m.kind in ["brute","hoglin","zoglin"] and m.phase in ["windup","charge"]:
		m.phase="rest";m.timer=.6
	if m.pull_left<=.01:m.stun=m.pull_stun
	add_effect("fishing_line",m.p,.3,{"end":player})

func update_attacks(dt: float):
	var all=build
	build={}
	for id in all:
		if id not in NEW_WEAPONS:build[id]=all[id]
	super.update_attacks(dt)
	build=all
	for id in build:
		if id not in NEW_WEAPONS:continue
		cooldowns[id]=cooldowns.get(id,0.0)-dt
		if cooldowns[id]>0:continue
		var target=nearest(player,320)
		if target==null and id not in ["axe","bed","tnt"]:continue
		var s=db.stats(id,build[id],evolved.has(id),items)
		var direction=player.direction_to(target.p) if target!=null else facing
		cooldowns[id]=s.interval
		animation.strike(self,id,direction)
		match id:
			"axe":
				for m in in_radius(player,s.radius):hurt(m,s.damage,player.direction_to(m.p))
				break_props(player,s.radius,s.damage)
				add_effect("axe_spin",player,.62 if evolved.has(id) else .34,{"radius":s.radius,"direction":direction,"return_damage":s.damage*.65 if evolved.has(id) else 0.0,"returned":false})
				sound("swing")
			"hoe":
				for j in range(int(s.count)):fire_projectile("hoe",player,direction.rotated(j*.18),s,evolved.has(id))
				sound("trident")
			"crossbow":
				for j in range(int(s.count)):fire_projectile("rocket" if evolved.has(id) else "bolt",player,direction.rotated((j-(s.count-1)/2)*.12),s,evolved.has(id))
				sound("arrow")
			"fishing":
				var targets=in_radius(player,s.range)
				targets.sort_custom(func(a,b):return player.distance_squared_to(a.p)<player.distance_squared_to(b.p))
				var caught=0
				for m in targets:
					if neutral(m):continue
					fire_projectile("hook",player,player.direction_to(m.p),s,evolved.has(id))
					caught+=1
					if caught>=s.count:break
				sound("trident")
			"bed","tnt":place_explosive(id,s)

func place_explosive(kind: String, s: Dictionary):
	var count=0
	for b in explosives:
		if b.kind==kind:count+=1
	if count>=rule("bed_limit" if kind=="bed" else "explosive_limit"):return
	var center=move_actor(player,facing*(42 if kind=="bed" else 12),7)
	var group=next_id()
	if kind=="bed":
		explosives.append({"kind":"bed","p":center,"v":Vector2.ZERO,"age":0.0,"fuse":-1.0,"stats":s.duplicate(),"group":group,"first":true,"launched":false})
	else:
		explosives.append(tnt_charge(center,s,group,true,1.5))
		if int(s.count)>1:tnt_groups.append({"anchor":center,"stats":s.duplicate(),"group":group,"age":0.0,"next":.32,"index":1,"remaining":int(s.count)-1})
		sound("hiss",.2)

func tnt_charge(at: Vector2, s: Dictionary, group: int, first: bool, fuse: float, child: bool=false) -> Dictionary:
	return {"kind":"tnt","p":at,"v":Vector2.ZERO,"age":0.0,"fuse":fuse,"stats":s.duplicate(),"group":group,"first":first,"launched":false,"child":child,"height":0.0,"lift":0.0}

func split_tnt(b: Dictionary):
	var aim: Vector2=b.v.normalized() if b.v.length()>5 else b.get("launch_dir",facing)
	var stats: Dictionary=b.stats.duplicate();stats.cluster=false;stats.damage*=.4;stats.radius*=.6
	for j in range(3):
		if explosives.size()>=rule("explosive_limit"):break
		var dir=aim.rotated((j-1)*.65)
		var child=tnt_charge(b.p,stats,b.group,false,.45+j*.05,true)
		child.v=dir*125;child.height=b.height;child.lift=75;child.launched=true
		explosives.append(child)
	add_effect("tnt_split",b.p,.3,{"height":b.height})

func update_explosives(dt: float):
	for i in range(tnt_groups.size()-1,-1,-1):
		var g=tnt_groups[i];g.age+=dt
		while g.remaining>0 and g.age>=g.next:
			var spread=[-.12,.12,-.24,.24][(g.index-1)%4]
			var dir=facing.rotated(spread)
			var at=move_actor(g.anchor,dir*(19+g.index*3),4)
			if explosives.size()<rule("explosive_limit"):
				var charge=tnt_charge(at,g.stats,g.group,false,maxf(.1,1.5-g.age+.8+g.index*.06))
				charge.launch_dir=dir
				explosives.append(charge);sound("hiss",.15)
			g.remaining-=1;g.index+=1;g.next+=.32
		if g.remaining<=0:tnt_groups.remove_at(i)
	for i in range(explosives.size()-1,-1,-1):
		var b=explosives[i]
		b.age+=dt
		b.p=move_actor(b.p,b.v*dt,4)
		b.v=b.v.move_toward(Vector2.ZERO,dt*45)
		if b.kind=="bed":
			if b.age>.65 and player.distance_to(b.p)<19:
				add_effect("foot_block",player,.85,{"direction":player.direction_to(b.p)})
				explode(b.p,b.stats.radius,b.stats.damage)
				explosives.remove_at(i)
			elif b.age>25:explosives.remove_at(i)
			continue
		if b.launched:
			b.height=maxf(0,b.height+b.lift*dt);b.lift-=300*dt
			if b.height<=0:b.lift=0
		b.fuse-=dt
		if b.fuse<=0:
			if b.first:
				for other in explosives:
					if other==b or other.kind!="tnt" or other.p.distance_to(b.p)>b.stats.radius:continue
					other.v=b.p.direction_to(other.p)*145
					if other.v.length_squared()<1:other.v=Vector2.RIGHT*145
					other.launch_dir=other.v.normalized()
					other.height=0;other.lift=120
					other.fuse=maxf(other.fuse,.72)
					other.launched=true
			if not b.first and not b.child and b.stats.get("cluster",false):split_tnt(b)
			explode(b.p,b.stats.radius,b.stats.damage)
			explosives.remove_at(i)

func fire_projectile(kind: String, p: Vector2, direction: Vector2, s: Dictionary, evolution: bool):
	var enemy_count=0
	for b in projectiles:
		if b.kind=="wither_skull":enemy_count+=1
	if kind=="wither_skull":
		if enemy_count>=430:return
	elif projectiles.size()-enemy_count>=int(db.data.projectile_cap):return
	projectiles.append({"kind":kind,"p":p,"origin":p,"dir":direction,"speed":s.speed,"damage":s.damage,"range":s.range,"radius":s.radius,"pierce":s.get("pierce",0),"distance":0.0,"hit":{},"returning":false,"evolved":evolution,"lightning":false,"life":s.get("life",6.5 if kind=="wither_skull" else 6.0),"age":0.0,"turn_age":0.0,"duration":s.get("duration",2.5),"turn":s.get("turn",0.0),"acceleration":s.get("acceleration",0.0),"orbit_owner":s.get("orbit_owner",-1),"orbit_angle":direction.angle(),"orbit_speed":s.get("orbit_speed",0.0)})

func update_projectiles(dt: float):
	var ordinary: Array=[]
	var custom: Array=[]
	for b in projectiles:
		if b.kind in ["hoe","bolt","rocket","hook","enemy_flame","wither_skull"]:custom.append(b)
		else:ordinary.append(b)
	projectiles=ordinary
	super.update_projectiles(dt)
	for b in custom:
		var old: Vector2=b.p
		b.age+=dt;b.life-=dt
		b.dir=b.dir.rotated(b.get("turn",0.0)*dt)
		b.speed=minf(165,b.speed+b.get("acceleration",0.0)*dt) if b.kind=="wither_skull" else b.speed
		if b.get("orbit_owner",-1)>=0:
			var owner=null
			for m in mobs:
				if m.id==b.orbit_owner and m.hp>0:owner=m;break
			if owner==null:continue
			b.orbit_angle+=b.orbit_speed*dt
			b.dir=Vector2.from_angle(b.orbit_angle)
			b.p=owner.p+b.dir*(42+minf(110,b.age*32))
		else:b.p+=b.dir*b.speed*dt
		b.distance+=b.speed*dt
		var dead=b.life<=0 or b.distance>=b.range
		if b.kind in ["enemy_flame","wither_skull"]:
			if Geometry2D.get_closest_point_to_segment(player,old,b.p).distance_to(player)<10:
				if b.kind=="enemy_flame":ignite(3);fire_damage(b.damage)
				else:damage_player(b.damage)
				dead=true
			if dead and b.kind=="wither_skull":
				add_effect("wither_impact",b.p,.6,{"radius":22.0})
		else:
			for m in in_radius((old+b.p)/2,old.distance_to(b.p)/2+6):
				if b.hit.has(m.id) or Geometry2D.get_closest_point_to_segment(m.p,old,b.p).distance_to(m.p)>m.radius+4:continue
				b.hit[m.id]=true
				match b.kind:
					"hoe":
						add_effect("hoe_spin",m.p,b.duration,{"radius":b.radius,"damage":b.damage,"tick":0.0,"evolved":b.evolved})
						dead=true
					"rocket":explode(m.p,b.radius,b.damage);dead=true
					"hook":
						hurt(m,b.damage)
						hook_target(m,b.evolved)
						dead=true
					"bolt":hurt(m,b.damage,b.dir);dead=b.hit.size()>b.pierce
				if dead:break
			if not dead:
				for obj in props:
					if obj.type=="pumpkin" and obj.hp>0 and not b.hit.has(obj.id) and Geometry2D.get_closest_point_to_segment(obj.p,old,b.p).distance_to(obj.p)<10:
						b.hit[obj.id]=true;obj.hp-=b.damage
						if obj.hp<=0:break_pumpkin(obj)
			if dead and b.kind=="rocket" and b.hit.is_empty():explode(b.p,b.radius,b.damage)
		if not dead:projectiles.append(b)

func update_effects(dt: float):
	for e in effects:
		if e.kind=="axe_spin" and e.get("return_damage",0)>0 and not e.returned and e.age+dt>=.3:
			e.returned=true
			for m in in_radius(player,e.radius):hurt(m,e.return_damage,player.direction_to(m.p))
			break_props(player,e.radius,e.return_damage);sound("swing")
	super.update_effects(dt)
	for e in effects:
		if e.kind!="hoe_spin":continue
		e.tick-=dt
		if e.tick<=0:
			e.tick+=.3
			for m in in_radius(e.p,e.radius):hurt(m,e.damage)
			break_props(e.p,e.radius,e.damage)

func break_props(at: Vector2, radius: float, damage: float):
	for p in props:
		if p.type=="pumpkin" and p.hp>0 and at.distance_to(p.p)<radius+7:
			p.hp-=damage
			if p.hp<=0:break_pumpkin(p)

func update_hazards(dt: float):
	for i in range(hazards.size()-1,-1,-1):
		var h=hazards[i]
		h.wait-=dt
		if h.wait>0:continue
		if not h.get("triggered",false):
			h.triggered=true
			h.remaining=h.get("remaining",.1)
			h.tick=0.0
			add_effect("soul_eruption",h.p,.85,{"radius":h.radius})
			sound("wither_shoot",.08)
		h.remaining-=dt;h.tick-=dt
		if h.tick<=0:
			h.tick+=.2
			if player.distance_to(h.p)<h.radius:
				if h.get("fire",false):ignite(1.5);fire_damage(h.damage)
				else:damage_player(h.damage)
		if h.remaining<=0:hazards.remove_at(i)

func discard(id: String) -> bool:
	if not super.discard(id):return false
	if id in ["bed","tnt"]:
		if id=="tnt":tnt_groups.clear()
		for i in range(explosives.size()-1,-1,-1):
			if explosives[i].kind==id:explosives.remove_at(i)
	if id in ["hoe","axe"]:
		for i in range(effects.size()-1,-1,-1):
			if effects[i].kind==id+"_spin":effects.remove_at(i)
	return true
