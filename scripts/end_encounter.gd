extends RefCounted
## Encounter clocks and all telegraphs advance only with the solo simulation.
const BETRAYAL_IMPACT=3.15
const DEATH_DURATION=7.6

func story(w, dt: float):
	match w.stage:
		"end_arrival":
			if w.stage_age>=2.5:w.stage="survival";w.stage_age=0
		"survival":
			if w.time>=w.db.data.duration:w.begin_arena()
		"departure":
			if w.stage_age>=1.6:w.prepare_arena()
		"dragon_arrival":
			if w.stage_age>=4:w.stage="dragon";w.stage_age=0;w.sound("dragon_growl")
		"dragon_death":
			if w.stage_age>=4.5:w.stage="exit_portal";w.stage_age=0;w.portal_lit=true;w.sound("portal_open")
		"exit_portal":
			if w.player.distance_to(w.portal_position)<94:
				w.stage="betrayal";w.stage_age=0;w.win_music=false;w.sound("end_teleport")
		"betrayal":
			if w.stage_age>=BETRAYAL_IMPACT and w.portal_lit:
				w.portal_lit=false;w.shake=.6;w.sound("explosion");w.sound("blood_rift")
				w.add_effect("portal_shatter",w.portal_position,3.8,{"radius":100.0})
			if w.stage_age>=6.4:
				w.stage="last_arrival";w.stage_age=0;w.spawn("endersteve_final",w.portal_position+Vector2(0,-35));w.hp=minf(20,w.hp+6);w.invulnerable=3.5
		"last_arrival":
			if w.stage_age>=2.2:w.stage="last_duel";w.stage_age=0;w.sound("warning")
		"endsteve_death":
			for cue in [2.6,4.5,6.1]:
				if w.stage_age>=cue and w.stage_age-dt<cue:
					w.sound("end_teleport" if cue<6 else "blood_rift");w.shake=.12 if cue<6 else .4
					if cue>6:w.add_effect("ender_death_burst",w.endsteve_corpse.p-Vector2(0,20),1.2)
			if w.stage_age>=DEATH_DURATION:
				w.stage="hand";w.stage_age=0;w.loot.append({"kind":"end_hand","p":w.hand_position()})
				w.boss_defeated("endersteve_final")
		"hand_pickup":
			if w.stage_age>=.6:w.stage="return_portal";w.stage_age=0
		"return_portal":
			if w.player_moving and w.player.distance_to(w.portal_position)<51:
				w.stage="rekindle";w.stage_age=0;w.facing=w.player.direction_to(w.portal_position);w.sound("portal_ignite")
		"rekindle":
			if w.stage_age>=1.8 and not w.portal_lit:w.portal_lit=true;w.sound("portal_open");w.shake=.15
			if w.stage_age>=2.8:w.stage="portal_ready";w.stage_age=0
		"portal_ready":
			if w.player_moving and w.player.distance_to(w.portal_position)<18:
				w.stage="exit_jump";w.stage_age=0;w.jump_start=w.player;w.facing=Vector2.UP;w.sound("portal_travel")
		"exit_jump":
			if w.stage_age>=3.4:w.stage="chapter_four";w.stage_age=0;w.end_complete=true;w.victory=true;w.state="RESULT"

func step(w, m: Dictionary, dt: float):
	if m.kind=="end_dragon":dragon(w,m,dt)
	else:endersteve(w,m,dt)

func cloud(w, p: Vector2, radius: float, wait: float=.9, life: float=2.8):
	w.hazards.append({"p":p,"wait":wait,"total":wait,"radius":radius,"damage":2.0,"remaining":life,"end_cloud":true})

func cut(w, start: Vector2, end: Vector2, wait: float, width: float=12, echo: bool=false):
	w.hazards.append({"kind":"end_cut","p":start,"end":end,"wait":wait,"total":wait,"radius":width,"damage":4.0,"remaining":.2,"echo":echo})

func dragon(w, m: Dictionary, dt: float):
	var alive=w.crystals.filter(func(t):return t.alive).size()
	if alive>0:m.hp=minf(m.max_hp,m.hp+float(alive)*7*dt)
	if not m.phase_two and alive==0 and m.hp<=m.max_hp*.5+1:
		m.phase_two=true;m.phase="rage";m.timer=1.8;w.sound("dragon_growl");w.add_effect("dragon_roar",m.p,1.8,{"radius":90.0})
	var old: Vector2=m.p;m.fire_tick-=dt;m.rush_tick-=dt
	var fast=1.45 if m.phase_two else 1.0
	match m.phase:
		"circle":
			m.orbit+=dt*.4*fast
			var target=Vector2(1024,1000)+Vector2.from_angle(m.orbit)*Vector2(250,175)
			m.dir=m.dir.lerp(m.p.direction_to(target),minf(1,dt*2)).normalized();m.p+=m.dir*m.speed*fast*dt;m.altitude=38+sin(w.clock*1.4)*9
			if m.phase_two and m.timer<=0:
				m.phase="descend";m.timer=1.7;m.mark=w.portal_position+Vector2(0,-25)
			elif m.rush_tick<=0:
				m.pattern=(m.pattern+1)%3;m.burst_tick=0
				if m.pattern==1:
					m.phase="sweep_windup";m.timer=1.15;m.charge=Vector2(1 if w.player.x>1024 else -1,0);m.mark=Vector2(w.player.x,clampf(w.player.y-100,790,1190))
				else:m.phase="windup";m.timer=.95;m.charge=m.p.direction_to(w.player+w.tracked_velocity*.45)
				w.sound("dragon_growl")
		"windup":
			m.dir=m.charge;m.altitude=lerpf(m.altitude,20,dt*3)
			if m.timer<=0:m.phase="rush";m.timer=1.25;m.rush_tick=7.5/fast;w.sound("dragon_flap")
		"rush":
			m.p+=m.charge*215*fast*dt;m.dir=m.charge;m.altitude=14
			if m.p.distance_to(w.player)<42:
				if w.contact_hit(m.p,6):w.player_push=m.charge*245
			if m.pattern==2:
				m.burst_tick-=dt
				if m.burst_tick<=0:
					m.burst_tick=.32
					for side in [-1,1]:shot(w,m.p,m.charge.orthogonal()*side,90,2)
			if m.timer<=0:m.phase="circle";m.timer=4.8;m.orbit=(m.p-Vector2(1024,1000)).angle()
		"sweep_windup":
			m.p=m.p.move_toward(m.mark-m.charge*170,130*dt);m.dir=m.charge;m.altitude=32
			if m.timer<=0:m.phase="sweep";m.timer=2.4;m.burst_tick=0;m.rush_tick=8/fast
		"sweep":
			m.p+=m.charge*145*dt;m.dir=m.charge;m.altitude=24;m.burst_tick-=dt
			if m.burst_tick<=0:
				m.burst_tick=.55;cloud(w,w.player+w.tracked_velocity*.3,27,1.1,2.2)
				for side in [-1,1]:
					for j in range(3):shot(w,m.p,m.charge.orthogonal().rotated((j-1)*.24)*side,80+j*18,2)
			if m.timer<=0:m.phase="circle";m.timer=4.8
		"rage":
			m.altitude=35+sin(w.clock*9)*3
			if m.timer<=0:m.phase="circle";m.timer=3
		"descend":
			m.dir=m.p.direction_to(m.mark);m.p=m.p.move_toward(m.mark,90*dt);m.altitude=maxf(0,m.altitude-dt*30)
			if m.timer<=0:m.phase="perch";m.timer=5.5;m.altitude=0;m.burst_tick=.55;m.volley=0
		"perch":
			m.altitude=0;m.dir=m.dir.lerp(m.p.direction_to(w.player),minf(1,dt*2)).normalized();m.burst_tick-=dt
			if m.burst_tick<=0:
				m.burst_tick=1.15;m.volley+=1
				var p=m.p+m.dir*90
				cloud(w,p,34,.95,2.5)
				# Alternating double fans retain a close melee opening behind the head.
				for side in [-1,1]:
					for j in range(5):shot(w,m.p,m.dir.rotated(side*(.4+j*.18)),88+j*10,2,.08*side)
			if m.timer<=0:m.phase="takeoff";m.timer=1.4;w.sound("dragon_flap")
		"takeoff":
			m.altitude=minf(45,m.altitude+dt*35);m.p+=Vector2.UP*45*dt
			if m.timer<=0:m.phase="circle";m.timer=6;m.rush_tick=1.8
	if m.fire_tick<=0 and m.phase in ["circle","takeoff"]:
		m.fire_tick=2.25 if m.phase_two else 3.1;m.volley+=1
		var direction: Vector2=m.p.direction_to(w.player+w.tracked_velocity*.4)
		for j in range(3 if m.phase_two else 1):
			w.fire_projectile("dragon_fireball",m.p,direction.rotated((j-1)*.23 if m.phase_two else 0),{"speed":110+j*9,"damage":3,"range":500,"radius":8,"life":5},false)
		var count=24 if m.phase_two else 16
		var gap=direction.angle()+PI/2
		for j in range(count):
			var a=j*TAU/count+m.volley*.17
			if absf(wrapf(a-gap,-PI,PI))<.3 or absf(wrapf(a-gap-PI,-PI,PI))<.3:continue
			shot(w,m.p,Vector2.from_angle(a),76+(j%3)*17,2,.1*sin(m.volley))
	m.p=m.p.clamp(w.END_ARENA.position+Vector2(30,25),w.END_ARENA.end-Vector2(30,50))
	w.dragon_history.push_front(m.p)
	if w.dragon_history.size()>90:w.dragon_history.pop_back()
	m.moving=old.distance_to(m.p)>.01

func shot(w, p: Vector2, dir: Vector2, speed: float, damage: float, turn: float=0, blade: bool=false):
	w.fire_projectile("end_blade" if blade else "end_bullet",p,dir,{"speed":speed,"damage":damage,"range":760,"radius":3,"life":8,"turn":turn},false)

func recover(m, seconds: float=1.0):
	m.phase="recover";m.timer=seconds;m.altitude=0

func endersteve(w, m: Dictionary, dt: float):
	if m.hp<m.max_hp*.5 and not m.rage:
		m.rage=true;m.phase="rage";m.timer=1.6;m.altitude=0;w.sound("dragon_growl");w.add_effect("ender_rage",m.p,1.6,{"radius":95.0})
	m.burst_tick-=dt
	match m.phase:
		"walk","recover":
			m.dir=m.p.direction_to(w.player)
			if m.phase=="walk":m.p=w.move_actor(m.p,m.dir*m.speed*(1.25 if m.rage else .8)*dt,m.radius)
			if m.timer<=0:
				m.pattern=(m.pattern+1)%7;m.combo=(2 if m.rage else 1) if m.pattern==3 else 0;m.charge=m.p.direction_to(w.player);m.mark=(w.player+w.tracked_velocity*.3).clamp(w.END_ARENA.position+Vector2(50,50),w.END_ARENA.end-Vector2(50,50))
				if m.pattern in [0,3]:w.teleport_mob(m,w.player-w.facing*90);m.charge=m.p.direction_to(w.player)
				m.phase="windup";m.timer=.85 if not m.rage else .7;m.windup_total=m.timer;m.burst_tick=0
				if m.pattern==5:
					cloud(w,m.mark,43,1.85,.35)
					m.leap_start=m.p
				w.sound("end_teleport",.1)
		"rage":
			if m.timer<=0:m.phase="walk";m.timer=.5
		"windup":
			if m.timer<=0:
				m.phase="rush" if m.pattern in [0,3] else "leap" if m.pattern==5 else "pursuit" if m.pattern==6 else "cast"
				m.timer=.6 if m.phase=="rush" else 1.0 if m.phase=="leap" else 2.0 if m.phase=="pursuit" else 3.1
				m.burst_tick=0;m.attack_serial=0
		"rush":
			m.p=w.move_actor(m.p,m.charge*(275 if m.rage else 240)*dt,m.radius);m.dir=m.charge
			if m.burst_tick<=0:
				m.burst_tick=.14;w.add_effect("ender_slash",m.p,.35,{"direction":m.charge,"radius":45.0})
			if m.p.distance_to(w.player)<36:
				if w.contact_hit(m.p,5):w.player_push=m.charge*100
			if m.timer<=0:
				if m.combo>0:
					m.combo-=1;w.teleport_mob(m,w.player-m.charge.rotated(PI/2)*90);m.charge=m.p.direction_to(w.player);m.phase="windup";m.timer=.58;m.windup_total=.58
				else:recover(m,1.1)
		"leap":
			var t=clampf(1-m.timer,0,1)
			m.p=m.leap_start.lerp(m.mark,smoothstep(0,1,t));m.altitude=sin(t*PI)*55;m.dir=m.charge
			if m.timer<=0:
				w.shake=.2;w.sound("mace_smash");w.add_effect("ender_slash",m.p,.5,{"direction":m.charge,"radius":65.0})
				for j in range(16):shot(w,m.p,Vector2.from_angle(j*TAU/16),96,2,0,true)
				recover(m,1.25)
		"pursuit":
			m.dir=m.p.direction_to(w.player);m.p=w.move_actor(m.p,m.dir*110*dt,m.radius)
			if m.p.distance_to(w.player)<65 or m.timer<=0:
				m.charge=m.p.direction_to(w.player);m.phase="cleave_windup";m.timer=.65;m.windup_total=.65
		"cleave_windup":
			if m.timer<=0:
				m.phase="cleave";m.timer=.46;w.add_effect("ender_slash",m.p,.46,{"direction":m.charge,"radius":75.0})
		"cleave":
			var delta: Vector2=w.player-m.p
			if delta.length()<75 and delta.normalized().dot(m.charge)>.1:w.contact_hit(m.p,5)
			if m.timer<=0:
				for j in range(5):shot(w,m.p,m.charge.rotated((j-2)*.24),125,2,0,true)
				recover(m,1.15)
		"cast":
			m.dir=m.p.direction_to(w.player)
			if m.burst_tick<=0:
				m.burst_tick=.6 if m.rage else .8
				match m.pattern:
					1:
						var a=m.charge.angle()+sin(m.attack_serial*.85-1)*.65
						for j in range(9):shot(w,m.p,Vector2.from_angle(a+(j-4)*.2),92+(j%2)*24,2,.1*sin(m.attack_serial),true)
					2:
						var gap=m.p.direction_to(w.player).angle()+PI/3
						for j in range(28):
							var a=j*TAU/28+m.attack_serial*.12
							if absf(wrapf(a-gap,-PI,PI))<.29 or absf(wrapf(a-gap-PI,-PI,PI))<.29:continue
							shot(w,m.p,Vector2.from_angle(a),75+(j%3)*17,2,.16 if m.attack_serial%2 else -.16,j%3==0)
					4:
						# Echo bodies preview exactly the segment that will be cut.
						var direction=Vector2.from_angle(m.attack_serial*PI/2+.35)
						cut(w,m.mark-direction*95,m.mark+direction*95,.95,11,true)
						if m.rage:cloud(w,m.mark+direction.orthogonal()*62,23,1.05,.4)
				m.attack_serial+=1;w.sound("shulker_shoot",.2)
			if m.timer<=0:recover(m,1.25)
