extends RefCounted
## IV director and three encounters. Geometry, warnings and hits share world
## time and coordinates; no renderer drives combat or consumes combat RNG.
var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_four_encounters.json"))
var mass: Dictionary={}
var golem: Dictionary={}
var guardian: Dictionary={}
var parts: Array=[]
var loose: Array=[]
var nodes: Array=[]
var shots: Array=[]
var blocks: Array=[]
var proposal: Array=[]
var beams: Array=[]
var debris: Array=[]
var current:=""
var mass_done:=false
var guardian_done:=false
var rescued:=false
var cast_index:=0
var geometry_revision:=0

func reset(w):
	mass={};golem={};guardian={};current="";mass_done=false;guardian_done=false;rescued=false;cast_index=0;geometry_revision=0
	for list in [parts,loose,nodes,shots,blocks,proposal,beams,debris]:list.clear()
	golem=actor(w,"golem",point(data.golem.anchor),99999,data.golem.radius)
	golem.skin="ch4d_golem";golem.phase="dormant";golem.started=false;golem.home=golem.p;golem.visible=false;golem.allied=false

func point(a: Array) -> Vector2:return Vector2(a[0],a[1])
func busy() -> bool:return current in ["mass","guardian"]
func reserve(p: Vector2) -> bool:
	return p.distance_to(point(data.golem.anchor))<100 or arena().grow(22).has_point(p)
func arena() -> Rect2:return Rect2(point(data.guardian.origin),Vector2(data.guardian.cols,data.guardian.rows)*data.guardian.cell)

func actor(w,kind: String,p: Vector2,health: float,radius: float) -> Dictionary:
	return {"encounter_actor":kind,"id":w.next_id(),"kind":"ch4d_"+kind,"p":p,"hp":health,"max_hp":health,"radius":radius,"boss":kind in ["mass","guardian","golem"],"undead":true,"allied":false,"phase":"idle","timer":0.0,"phase_duration":1.0,"phase_age":0.0,"cast":"","dir":Vector2.DOWN,"visual_dir":Vector2.DOWN,"visual":w.animation.actor(),"animation":0.0,"moving":false,"flash":0.0,"burn":0.0,"burn_tick":.5,"stun":0.0,"slow":0.0,"pull_left":0.0,"pull_dir":Vector2.ZERO,"pull_stun":0.0,"control_resist":0.0,"knock":Vector2.ZERO,"charge":Vector2.DOWN,"wall_points":[],"xp":0,"scale":1.0,"skin":"ch4d_"+kind,"hurt_sound":"ch4_flesh_hit"}

func enter(m: Dictionary,phase: String,duration: float,cast: String=""):
	m.phase=phase;m.timer=duration;m.phase_duration=duration;m.phase_age=0.0
	if not cast.is_empty():m.cast=cast

func candidates() -> Array:
	var result: Array=[]
	if not mass.is_empty() and mass.hp>0 and mass.phase not in ["intro","death"]:
		result.append(mass)
		for part in parts:
			if part.hp>0:result.append(part)
	for part in loose:
		if part.hp>0 and part.life>0:result.append(part)
	for node in nodes:
		if node.hp>0 and not node.get("disabled",false):result.append(node)
	if not guardian.is_empty() and guardian.hp>0 and current=="guardian" and guardian.phase not in ["intro","death"]:result.append(guardian)
	return result

func launch_mass(w,at=null):
	if mass_done or not mass.is_empty() or current=="guardian":return
	var p: Vector2=w.player+Vector2(0,-140) if at==null else at
	if at==null:
		for i in range(20):
			var candidate: Vector2=w.player+Vector2.from_angle(-PI/2+i*2.39996)*(142+i%3*15)
			if w.free_at(candidate,54) and candidate.x>100 and candidate.y>100 and candidate.x<1948 and candidate.y<1948:p=candidate;break
	mass=actor(w,"mass",p,data.mass.hp,float(data.mass.radius)*1.3);mass.scale=1.3;mass.mask=15;mass.small=false;mass.skin="ch4d_mass_15";mass.damage=data.mass.damage;mass.pattern=0;mass.burst=0;mass.burst_timer=0.0
	mass.aim=w.player;mass.sweep_a=Vector2.ZERO;mass.sweep_b=Vector2.ZERO;mass.attack_hits={}
	for j in range(4):
		var part=actor(w,"mass_part",p,data.mass.part_hp,9);part.boss=true;part.attack="attached";part.component=j+1;part.owner=mass.id;part.offset=[Vector2(-18,-15),Vector2(18,-15),Vector2(0,8),Vector2(0,24)][j];parts.append(part)
	enter(mass,"intro",data.mass.intro);current="mass";w.sound("ch4_mass_birth");sync_parts()

func launch_golem(w):
	if golem.started or rescued:return
	golem.started=true;golem.visible=true;enter(golem,"intro",data.golem.intro)
	for j in range(3):
		var offset: Vector2=[Vector2(-33,7),Vector2(32,9),Vector2(0,30)][j]
		var node=actor(w,"golem_node",golem.p+offset,data.golem.nodes_hp,10);node.attack="anchored";node.offset=offset;node.owner=golem.id;node.boss=false;nodes.append(node)
	w.sound("ch4_golem_strain")

func launch_guardian(w):
	if guardian_done or current=="mass":return
	if guardian.is_empty():
		guardian=actor(w,"guardian",point(data.guardian.anchor),data.guardian.hp,data.guardian.radius);guardian.damage=data.guardian.beam_damage;guardian.pattern=0;guardian.guard=data.guardian.guard
	current="guardian";enter(guardian,"intro",data.guardian.intro)
	# No permanent arena wall. Retreat remains possible and removes moving blocks.
	nodes=nodes.filter(func(n):return n.encounter_actor!="guardian_torch")
	var rect: Rect2=arena()
	for j in range(4):
		var p: Vector2=rect.position+Vector2(20 if j%2==0 else rect.size.x-20,40+(j/2)*(rect.size.y-72))
		var node=actor(w,"guardian_torch",p,data.guardian.torch_hp,7);node.attack="anchored";node.disabled=false;node.boss=false;node.slot=j;node.owner=guardian.id;nodes.append(node)
	w.sound("ch4_guardian_awake")

func tick(w,dt: float):
	if not w.db.data.chapter_four.exploration_only:
		if w.time>=data.golem.at:golem.visible=true
		if golem.visible and not golem.started and w.player.distance_to(golem.p)<data.golem.trigger and not busy():launch_golem(w)
		if w.time>=data.mass.at and mass.is_empty() and not mass_done and current!="guardian":launch_mass(w)
		if w.time>=data.guardian.at and not guardian_done and not busy() and w.player.distance_to(arena().get_center())<data.guardian.trigger:launch_guardian(w)
	for m in bodies()+parts+nodes+loose:
		if m.is_empty():continue
		m.animation+=dt;m.flash=maxf(0,m.flash-dt);m.visual.hurt=maxf(0,m.visual.hurt-dt);m.control_resist=maxf(0,m.control_resist-dt);m.slow=maxf(0,m.slow-dt)
		if m.burn>0 and m.hp>0:
			m.burn-=dt;m.burn_tick-=dt
			if m.burn_tick<=0:m.burn_tick+=.5;var previous: String=w.damage_owner;w.damage_owner="fire";w.hurt(m,w.burn_damage(m));w.damage_owner=previous
		m.stun=maxf(0,m.stun-dt)
	for m in bodies():
		if m.is_empty() or m.stun>0:continue
		if m.pull_left>0:
			var step: float=minf(m.pull_left,380*dt);m.p=w.move_actor(m.p,m.pull_dir*step,m.radius);m.pull_left-=step
			if m.pull_left<=.1:m.stun=m.pull_stun
			continue
		m.phase_age+=dt;m.timer-=dt
	if not mass.is_empty():update_mass(w,dt)
	update_golem(w,dt)
	if not guardian.is_empty():update_guardian(w,dt)
	sync_parts();update_loose(w,dt);update_shots(w,dt);update_beams(w,dt)
	for i in range(debris.size()-1,-1,-1):
		var d=debris[i];d.age+=dt;d.p+=d.v*dt;d.v.y+=40*dt
		if d.age>d.life:debris.remove_at(i)

func bodies() -> Array:
	var result: Array=[golem]
	if not mass.is_empty():result.append(mass)
	if not guardian.is_empty():result.append(guardian)
	return result

func sync_parts():
	if not mass.is_empty():
		for part in parts:part.p=mass.p+part.offset*mass.scale;part.flash=maxf(part.flash,mass.flash*.3)
	for node in nodes:
		if node.encounter_actor=="golem_node":node.p=golem.p+node.offset

func controlled(m: Dictionary) -> bool:return m.stun>0 or m.pull_left>0

func update_mass(w,dt: float):
	if mass.phase=="death":
		if mass.timer<=0:
			mass_done=true;current="";mass.phase="gone";w.loot.append({"kind":"chest","p":mass.p,"born":w.time});w.drop_xp(mass.p,data.mass.reward_xp);w.kills+=1
		return
	if mass.phase=="gone" or controlled(mass):return
	if mass.phase=="intro":
		if mass.timer<=0:enter(mass,"walk",.7)
		return
	if mass.hp<=0:die_mass(w);return
	if mass.hp<mass.max_hp*.33 and not mass.small:
		mass.small=true;mass.scale=.96;mass.radius=21
		for part in parts:
			if part.hp>0:detach(w,part)
		enter(mass,"recover",1.2);w.sound("ch4_mass_shed")
	mass.skin="ch4d_mass_"+str(mass.mask)
	if mass.phase=="recover":
		if mass.timer<=0:enter(mass,"walk",.5)
		return
	if mass.phase=="walk":
		var before: Vector2=mass.p;mass.dir=w.navigation(mass.p)
		mass.p=w.move_actor(mass.p,mass.dir*(data.mass.small_speed if mass.small else data.mass.speed)*(.7 if mass.slow>0 else 1)*dt,mass.radius)
		mass.moving=before.distance_to(mass.p)>.01
		if mass.timer<=0:
			var available: Array=["sweep"]
			if mass.mask&4:available.append("haul")
			if mass.mask&3:available.append("fan")
			var cast: String=available[int(mass.pattern)%available.size()];mass.pattern+=1;mass.charge=mass.p.direction_to(w.player);mass.aim=w.player+w.tracked_velocity*.2;mass.attack_hits={}
			enter(mass,"windup",float(data.mass.windup)*(.65 if mass.small else 1),cast);w.sound("ch4_mass_warn",.4)
		return
	if mass.phase=="windup" and mass.timer<=0:
		enter(mass,"attack",data.mass.haul_time if mass.cast=="haul" else data.mass.fan_count*data.mass.fan_interval if mass.cast=="fan" else .8)
		mass.burst=0;mass.burst_timer=0
		if mass.cast=="sweep":mass.sweep_origin=mass.p;mass.sweep_dir=mass.charge
	if mass.phase=="attack":
		if mass.cast=="haul":
			var before: Vector2=mass.p;mass.p=w.move_actor(mass.p,mass.charge*data.mass.haul_speed*dt,mass.radius)
			if Geometry2D.get_closest_point_to_segment(w.player,before,mass.p).distance_to(w.player)<mass.radius+6:w.receive_hit(mass.damage,mass)
		elif mass.cast=="fan":
			mass.burst_timer-=dt
			if mass.burst_timer<=0 and mass.burst<int(data.mass.fan_count):
				mass.burst_timer+=data.mass.fan_interval
				var head: int=1+(int(mass.burst)%2)
				if not mass.mask&(1<<(head-1)):head=3-head
				if mass.mask&(1<<(head-1)):
					var from: Vector2=mass.p+Vector2(-18 if head==1 else 18,-12)
					var aim: Vector2=from.direction_to(mass.aim);var gap: int=int(mass.burst)%5
					for j in range(5):
						if j!=gap:shoot(w,from,aim.rotated((j-2)*.25),data.mass.fan_speed+mass.burst%2*12,mass.damage)
				mass.burst+=1
		elif mass.cast=="sweep":
			var segment: Array=sweep_segment()
			if Geometry2D.get_closest_point_to_segment(w.player,segment[0],segment[1]).distance_to(w.player)<data.mass.sweep_width and not mass.attack_hits.has("player"):
				mass.attack_hits.player=true;w.receive_hit(mass.damage,mass)
		if mass.timer<=0:enter(mass,"recover",data.mass.recover*(.7 if mass.small else 1))

func sweep_segment(progress: float=-1) -> Array:
	var k: float=clampf(mass.phase_age/maxf(.01,mass.phase_duration),0,1) if progress<0 else progress
	var origin: Vector2=mass.get("sweep_origin",mass.p)
	var direction: Vector2=mass.get("sweep_dir",mass.charge).rotated(-1.05+2.1*k)
	return [origin+direction*18,origin+direction*float(data.mass.sweep_reach)]

func detach(w,part: Dictionary):
	if part.get("detached",false):return
	part.detached=true;part.hp=0;mass.mask=int(mass.mask)&~(1<<(int(part.component)-1));mass.skin="ch4d_mass_"+str(mass.mask)
	if loose.size()<int(data.rules.loose_limit):
		var m=actor(w,"loose",part.p,data.mass.loose_hp,9);m.component=part.component;m.skin="ch4d_loose_"+str(part.component);m.life=float(data.mass.loose_life);m.lift=16.0;m.damage=2.0;enter(m,"recover",.6);loose.append(m)
	w.add_effect("ch4d_detach",part.p,.55);w.sound("ch4_mass_shed",.25)

func update_loose(w,dt: float):
	for i in range(loose.size()-1,-1,-1):
		var m=loose[i];m.life-=dt;m.lift=maxf(0,m.lift-35*dt)
		if m.hp<=0 or m.life<=0:
			if m.hp<=0:w.drop_xp(m.p,2);w.kills+=1;w.arsenal.after_kill(w,m)
			loose.remove_at(i);continue
		if m.pull_left>0:
			var distance: float=minf(m.pull_left,380*dt);m.p=w.move_actor(m.p,m.pull_dir*distance,m.radius);m.pull_left-=distance
			if m.pull_left<=.1:m.stun=m.pull_stun
			continue
		if m.stun>0:continue
		m.timer-=dt;m.phase_age+=dt;m.p=w.move_actor(m.p,m.knock*dt,m.radius);m.knock=m.knock.move_toward(Vector2.ZERO,dt*300)
		if m.phase=="recover" and m.timer<=0:enter(m,"windup",.6)
		elif m.phase=="windup" and m.timer<=0:
			if m.component<=2:
				for angle in [-.2,0.0,.2]:shoot(w,m.p,m.p.direction_to(w.player).rotated(angle),65,m.damage)
			elif w.player.distance_to(m.p)<26:w.damage_player(m.damage)
			w.add_effect("ch4d_limb_hit",m.p,.3,{"radius":26.0});enter(m,"recover",1.8)

func shoot(w,p: Vector2,dir: Vector2,speed: float,damage: float):
	if shots.size()>=int(data.rules.shots_limit):return
	shots.append({"p":p,"dir":dir,"speed":speed,"damage":damage,"life":3.5,"age":0.0});w.sound("ch4_flesh_shot",.1)
func update_shots(w,dt: float):
	for i in range(shots.size()-1,-1,-1):
		var b=shots[i];var before: Vector2=b.p;b.p+=b.dir*b.speed*dt;b.life-=dt;b.age+=dt
		if Geometry2D.get_closest_point_to_segment(w.player,before,b.p).distance_to(w.player)<9:w.damage_player(b.damage);b.life=0
		if b.life<=0 or not w.free_at(b.p,2):shots.remove_at(i)

func update_golem(w,dt: float):
	if not golem.started:return
	if golem.phase=="intro":
		if golem.timer<=0:enter(golem,"walk",1.2)
		return
	if golem.phase=="release":
		if golem.timer<=0:golem.skin="ch4d_golem_saved";golem.allied=true;golem.undead=false;golem.help_until=w.clock+data.golem.help_duration;enter(golem,"walk",.8);w.loot.append({"kind":"chest","p":golem.p+Vector2(0,20),"born":w.time})
		return
	if not rescued and nodes.filter(func(n):return n.encounter_actor=="golem_node" and n.hp>0).is_empty():
		rescued=true;golem.allied=true;golem.undead=false;enter(golem,"release",data.golem.release);w.drop_xp(golem.p,data.golem.reward_xp);w.sound("ch4_golem_free");w.add_effect("ch4d_release",golem.p,1.4);return
	# The director keeps only one hostile encounter preparing attacks at a time.
	if busy() and not rescued:return
	if controlled(golem):return
	var target=w.player
	var target_enemy=null;var best: float=155*155
	for m in w.mobs:
		if m.hp<=0 or m.get("allied",false):continue
		if rescued and m.p.distance_to(golem.home)>float(data.golem.guard_radius):continue
		var distance: float=m.p.distance_squared_to(golem.p)
		if distance<best:best=distance;target_enemy=m;target=m.p
	if rescued and target_enemy==null:
		var follow: bool=w.clock<golem.get("help_until",0.0) and w.player.distance_to(golem.home)<data.golem.guard_radius
		target=w.player-w.facing*32 if follow else golem.home
		if target.distance_to(golem.home)>float(data.golem.guard_radius)-20:target=golem.home+(target-golem.home).limit_length(float(data.golem.guard_radius)-20)
	if golem.phase=="recover":
		if golem.timer<=0:enter(golem,"walk",.6)
		return
	if golem.phase=="windup":
		if golem.timer<=0:
			var end: Vector2=golem.p+golem.charge*float(data.golem.reach)
			if not rescued and Geometry2D.get_closest_point_to_segment(w.player,golem.p,end).distance_to(w.player)<data.golem.width:w.receive_hit(data.golem.damage,golem)
			for m in w.in_radius((golem.p+end)/2,data.golem.reach*.65):
				if not m.get("encounter_actor","").is_empty() or m.get("allied",false):continue
				if Geometry2D.get_closest_point_to_segment(m.p,golem.p,end).distance_to(m.p)<data.golem.width+m.radius:
					w.arsenal.hit(w,m,data.golem.mob_damage,"golem_ally" if rescued else "golem",golem.charge,true)
			w.add_effect("ch4d_golem_slam",golem.p,.4,{"end":end,"width":float(data.golem.width)});w.sound("ch4_golem_slam");enter(golem,"attack",.35)
		return
	if golem.phase=="attack":
		if golem.timer<=0:enter(golem,"recover",data.golem.recover)
		return
	if golem.phase=="walk":
		var before: Vector2=golem.p;golem.dir=golem.p.direction_to(target)
		if rescued and golem.p.distance_to(target)>30:golem.p=w.move_actor(golem.p,golem.dir*data.golem.speed*dt,golem.radius)
		golem.moving=before.distance_to(golem.p)>.01
		if golem.timer<=0 and (target_enemy!=null or not rescued) and golem.p.distance_to(target)<data.golem.reach+15:
			golem.charge=golem.p.direction_to(target);enter(golem,"windup",data.golem.windup);w.sound("ch4_golem_warn",.7)

func grid_point(cell: Vector2i) -> Vector2:return point(data.guardian.origin)+(Vector2(cell)+Vector2(.5,.5))*float(data.guardian.cell)
func grid_cell(p: Vector2) -> Vector2i:return Vector2i((p-point(data.guardian.origin))/float(data.guardian.cell)).clamp(Vector2i.ZERO,Vector2i(int(data.guardian.cols)-1,int(data.guardian.rows)-1))
func all_cells() -> Array:
	var result: Array=[]
	for y in range(int(data.guardian.rows)):
		for x in range(int(data.guardian.cols)):result.append(Vector2i(x,y))
	return result

func connected(cells: Array,from: Vector2i) -> bool:
	if cells.has(from):return false
	var queue: Array=[from];var visited: Dictionary={from:true};var total: int=int(data.guardian.cols)*int(data.guardian.rows)-cells.size()
	while not queue.is_empty():
		var c: Vector2i=queue.pop_front()
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i=c+direction
			if next.x<0 or next.y<0 or next.x>=int(data.guardian.cols) or next.y>=int(data.guardian.rows) or cells.has(next) or visited.has(next):continue
			visited[next]=true;queue.append(next)
	return visited.size()==total and visited.has(Vector2i(4,0)) and visited.has(Vector2i(4,6))

func plan_geometry(w,pattern: int) -> Array:
	var candidates: Array=[]
	if pattern%2==0:
		for x in [2,6]:
			for y in range(1,6):
				if y not in [2+(pattern/2)%2,3+(pattern/2)%2]:candidates.append(Vector2i(x,y))
	else:
		for y in [2,4]:
			for x in range(1,8):
				if x not in [3+pattern%2,4+pattern%2]:candidates.append(Vector2i(x,y))
	var safe: Array=[];var player_cell: Vector2i=grid_cell(w.player)
	for cell in candidates:
		if grid_point(cell).distance_to(w.player)<float(data.guardian.cell)*1.15:continue
		if not w.free_at(grid_point(cell),data.guardian.block_radius) and not blocks.has(cell):continue
		var trial: Array=safe+[cell]
		if connected(trial,player_cell):safe=trial
	return safe

func commit_geometry(w):
	# The hero may have stepped into a warned cell; never raise through a body.
	var actual: Array=proposal.filter(func(c):return grid_point(c).distance_to(w.player)>float(data.guardian.block_radius)+9)
	while not connected(actual,grid_cell(w.player)) and not actual.is_empty():actual.pop_back()
	blocks=actual;proposal=[];geometry_revision+=1
	w.replace_special_solids("guardian",blocks.map(func(c):return grid_point(c)),data.guardian.block_radius)
	for m in w.mobs:
		if m.hp<=0:continue
		for cell in blocks:
			var p: Vector2=grid_point(cell);var delta: Vector2=m.p-p;var limit: float=float(data.guardian.block_radius)+m.radius
			if delta.length()<limit:m.p=p+(delta.normalized() if delta.length_squared()>.01 else Vector2.RIGHT)*(limit+1)
	w.sound("ch4_stone_rise")

func update_guardian(w,dt: float):
	if guardian.phase!="windup":proposal=[]
	if guardian.phase=="death":
		if guardian.timer<=0:guardian.phase="gone";guardian_done=true;current="";w.loot.append({"kind":"chest","p":guardian.p+Vector2(0,24),"born":w.time});w.drop_xp(guardian.p,data.guardian.reward_xp);w.kills+=1
		return
	if guardian.phase in ["gone","dormant"] or current!="guardian":return
	if guardian.hp<=0:die_guardian(w);return
	if w.player.distance_to(arena().get_center())>float(data.rules.engagement_range):
		clear_geometry(w);guardian.phase="dormant";current="";return
	if controlled(guardian):return
	if guardian.phase=="intro":
		if guardian.timer<=0:enter(guardian,"walk",.4)
		return
	guardian.guard=0.0 if guardian.phase=="recover" else float(data.guardian.guard)
	if guardian.phase=="walk" and guardian.timer<=0:
		guardian.pattern+=1;proposal=plan_geometry(w,int(guardian.pattern));enter(guardian,"windup",data.guardian.windup,"blocks");w.sound("ch4_guardian_warn");return
	if guardian.phase=="windup" and guardian.timer<=0:
		commit_geometry(w);enter(guardian,"attack",data.guardian.hold,"geometry")
		for node in nodes:
			if node.encounter_actor=="guardian_torch":node.disabled=false;node.hp=node.max_hp
		if guardian.pattern%2==0:plan_beams(w)
	elif guardian.phase=="attack" and guardian.timer<=0:
		clear_geometry(w);enter(guardian,"recover",data.guardian.recover);w.sound("ch4_guardian_open")
	elif guardian.phase=="recover" and guardian.timer<=0:enter(guardian,"walk",.35)

func plan_beams(w):
	beams=[]
	var torches: Array=nodes.filter(func(n):return n.encounter_actor=="guardian_torch")
	if torches.size()!=4:return
	# Short edge-to-edge pulses never cross the central approach/exit spine.
	for index in range(4):
		var a: Dictionary=torches[index];var b: Dictionary=torches[(index+2)%4]
		beams.append({"a":a.p,"b":b.p,"from":a.id,"to":b.id,"wait":float(data.guardian.beam_warn)+index*float(data.guardian.beam_step),"life":float(data.guardian.beam_life),"age":0.0,"live":false,"hit":false})

func update_beams(w,dt: float):
	for i in range(beams.size()-1,-1,-1):
		var beam=beams[i];beam.wait-=dt;beam.age+=dt
		var endpoints: Array=nodes.filter(func(n):return n.id in [beam.from,beam.to] and n.hp>0 and not n.get("disabled",false))
		if endpoints.size()!=2:beams.remove_at(i);continue
		if beam.wait<=0:
			beam.live=true;beam.life-=dt
			if not beam.hit and Geometry2D.get_closest_point_to_segment(w.player,beam.a,beam.b).distance_to(w.player)<float(data.guardian.beam_width):beam.hit=true;w.damage_player(data.guardian.beam_damage)
			if beam.life<=0:beams.remove_at(i)

func clear_geometry(w):
	blocks=[];proposal=[];beams=[];w.replace_special_solids("guardian",[],data.guardian.block_radius)

func hurt(w,m: Dictionary,amount: float,push: Vector2):
	if m.hp<=0 or m.get("allied",false):return
	if m.encounter_actor=="golem" or m.phase in ["intro","death","gone"]:return
	var damage: float=minf(m.hp,maxf(0,amount));m.hp-=amount;m.flash=.12;m.visual.hurt=.12
	if m.encounter_actor=="loose":m.knock=push*40
	w.damage_by[w.damage_owner]=w.damage_by.get(w.damage_owner,0.0)+damage
	w.add_effect("damage",m.p-Vector2(0,20),.5,{"amount":ceili(damage)})
	w.emit_pixels("impact",m.p-Vector2(0,12),3,push);w.sound("ch4_stone_hit" if m.encounter_actor in ["guardian","guardian_torch"] else "ch4_flesh_hit",.1)
	if m.encounter_actor in ["mass","mass_part","loose","guardian"]:w.arsenal.melee_hit(w,m,damage)
	match m.encounter_actor:
		"mass_part":
			var transfer: float=minf(mass.hp,damage*float(data.mass.core_transfer));mass.hp-=transfer;w.damage_by[w.damage_owner]+=transfer
			if m.hp<=0:detach(w,m)
			if mass.hp<=0:die_mass(w)
		"mass":
			if m.hp<=0:die_mass(w)
		"guardian":
			if m.hp<=0:die_guardian(w)
		"guardian_torch":
			if m.hp<=0:m.disabled=true;w.add_effect("ch4d_torch_break",m.p,.4)
		"golem_node":
			if m.hp<=0:w.add_effect("ch4d_detach",m.p,.6);w.sound("ch4_growth_rip",.2)

func die_mass(w):
	if mass.phase in ["death","gone"]:return
	enter(mass,"death",data.mass.death);shots=[];loose=[]
	w.arsenal.after_kill(w,mass)
	for part in parts:part.hp=0
	burst(w,mass.p,"flesh",20);w.sound("ch4_mass_death")
func die_guardian(w):
	if guardian.phase in ["death","gone"]:return
	enter(guardian,"death",data.guardian.death);clear_geometry(w)
	w.arsenal.after_kill(w,guardian)
	for node in nodes:
		if node.encounter_actor=="guardian_torch":node.disabled=true
	burst(w,guardian.p,"stone",24);w.sound("ch4_guardian_death")
func burst(w,p: Vector2,kind: String,count: int):
	for j in range(count):
		if debris.size()>=int(data.rules.debris_limit):break
		debris.append({"p":p+Vector2(0,-15),"v":Vector2(sin(j*2.39996)*48,-20-j%5*12),"age":0.0,"life":2.0+float(j%3)*.2,"kind":kind,"seed":j})

func poses(w):
	for m in bodies():
		if m.is_empty():continue
		m.visual_dir=m.charge if m.phase in ["windup","attack"] else m.dir
		var state: String="idle";var k: float=clampf(m.phase_age/maxf(.001,m.phase_duration),0,.999)
		match m.phase:
			"intro","release","death":state=m.phase
			"walk":state="walk" if m.moving else "idle";k=fposmod(m.animation,.6)/.6
			"windup":state="windup"
			"attack":state=m.cast if m.cast in ["haul","fan","sweep"] else "sweep" if m.encounter_actor=="golem" else "fan"
			"recover":state="recover"
		if m.visual.hurt>0 and m.phase not in ["intro","release","death","attack"]:state="hurt";k=(.12-m.visual.hurt)/.12
		var spec: Dictionary=w.animation.data.actors.get(m.skin,{})
		if not spec.is_empty():
			var total:=0.0
			for duration in spec.states[state].durations:total+=duration
			w.animation.set_pose(m.visual,state,k*total)

func visual_camera(w,base: Vector2) -> Vector2:
	if current=="guardian" and guardian.phase not in ["death","dormant"]:
		var k: float=smoothstep(0,1.1,guardian.phase_age) if guardian.phase=="intro" else 1.0
		return base.lerp(arena().get_center(),k*.85)
	if current=="mass" and mass.phase=="intro":
		var k: float=smoothstep(0,.8,mass.phase_age)*(1-smoothstep(data.mass.intro-.9,data.mass.intro,mass.phase_age))
		return base+(mass.p-w.player).limit_length(160)*.35*k
	# During the fight the camera keeps the boss in the frame with the hero.
	if not mass.is_empty() and mass.phase not in ["gone","intro"]:
		return base+(mass.p-w.player).limit_length(240)*.4
	if golem.get("started",false) and golem.phase in ["intro","release"]:
		return base+(golem.p-w.player).limit_length(200)*.45
	return base

func title() -> String:
	if current=="mass":return "Сросшиеся"
	if current=="guardian":return "Хранитель пирамиды"
	return ""
