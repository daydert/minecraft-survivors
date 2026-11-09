extends RefCounted
## Crossing streams require local weaving; no permanent safe angular sectors.
const ORDER=["volley","bombard","dash","spiral"]

func predicted(w, lead: float) -> Vector2:
	return (w.player+w.tracked_velocity.limit_length(120)*lead).clamp(w.ARENA.position+Vector2(40,40),w.ARENA.end-Vector2(40,40))

func begin(w, m: Dictionary, attack: String):
	m.phase=attack
	m.timer={"volley":.85,"bombard":1.2,"dash":.65 if m.rage else .85,"spiral":.7}[attack]
	m.windup=m.timer
	m.mark=predicted(w,.6)
	m.charge=m.p.direction_to(m.mark)
	m.burst_left=0
	m.visual.shot_age=100
	if attack=="bombard":
		m.fire_index=0
		m.fire_tick=.16
		m.fire_direction=w.tracked_velocity.normalized() if w.tracked_velocity.length()>8 else m.p.direction_to(w.player)
	w.sound("wither_charge",.4)

func skull(w, p: Vector2, direction: Vector2, speed: float, blue: bool=false, turn: float=0):
	w.fire_projectile("wither_skull",p,direction,{"speed":speed,"damage":4,"range":760,"radius":18,"turn":turn,"acceleration":7 if blue else 0},blue)

func recover(m: Dictionary):
	m.phase="recover"
	m.timer=.3 if m.rage else .55
	m.visual.shot_age=0

func fire_mark(w, point: Vector2, rage: bool):
	var warning=.45 if rage else .51
	w.hazards.append({"kind":"soul","p":point.clamp(w.ARENA.position+Vector2(30,30),w.ARENA.end-Vector2(30,30)),"radius":49.0 if rage else 43.0,"wait":warning,"total":warning,"damage":3.0,"fire":true,"triggered":false,"remaining":.65,"tick":0.0})

func bombard_step(w, m: Dictionary, dt: float):
	m.fire_tick-=dt
	while m.fire_index<4 and m.fire_tick<=0:
		var n: int=m.fire_index
		if n<3:
			var side: Vector2=m.fire_direction.orthogonal()
			var offset=side*[-40.0,40.0,0.0][n]+m.fire_direction*float(n)*11
			fire_mark(w,predicted(w,.62)+offset,m.rage)
			m.fire_tick+=.1
		else:
			var center=predicted(w,.65)
			var side: Vector2=m.fire_direction.orthogonal()
			for j in range(3):fire_mark(w,center+side*(j-1)*82,m.rage)
			m.fire_tick+=.2
		m.fire_index+=1

func passive(w, m: Dictionary, dt: float):
	if w.stage!="wither":return
	m.orbit_tick-=dt
	while m.orbit_tick<=0:
		m.orbit_tick+=4.0
		for j in range(4):
			var direction=Vector2.from_angle(j*PI/2)
			w.fire_projectile("wither_skull",m.p+direction*42,direction,{"speed":0.0,"damage":3.0,"range":10000,"radius":18,"orbit_owner":m.id,"orbit_speed":1.1 if m.rage else .85,"life":4.6 if m.rage else 4.2},m.rage)
		w.sound("wither_shoot",.15)

func step(w, m: Dictionary, dt: float):
	m.dir=m.p.direction_to(w.player)
	if not m.rage and m.hp<m.max_hp*.5:
		m.rage=true
		m.phase="roar"
		m.timer=1.1
		w.add_effect("wither_roar",m.p,1.1)
		w.sound("wither_charge",.3)
		return
	match m.phase:
		"walk":
			var target=w.player+Vector2(sin(w.clock*.9)*105,-96)
			m.p=w.move_actor(m.p,m.p.direction_to(target)*(72 if m.rage else 42)*dt,m.radius)
			m.attack_tick-=dt
			if m.attack_tick<=0:
				var attack=ORDER[m.pattern%ORDER.size()]
				m.pattern+=1
				begin(w,m,attack)
		"volley":
			if m.timer>.22:
				m.mark=predicted(w,clampf(m.p.distance_to(w.player)/145,.35,.9))
				m.charge=m.p.direction_to(m.mark)
			if m.timer<=0:
				for head in range(3):
					var p: Vector2=m.p+Vector2((head-1)*25,-28 if head!=1 else -40)
					var aim=p.direction_to(m.mark)
					var count=5 if m.rage else 3
					for j in range(count):skull(w,p,aim.rotated((j-(count-1)/2.0)*(.13 if m.rage else .16)),150 if m.rage else 118,j%2==0 and m.rage)
				w.sound("wither_shoot",.1)
				recover(m)
		"bombard":
			bombard_step(w,m,dt)
			if m.timer<=0:recover(m)
		"dash":
			if m.timer<=0:
				m.phase="rush";m.timer=.6
				w.sound("wither_shoot",.15)
		"rush":
			m.p=w.move_actor(m.p,m.charge*(350 if m.rage else 245)*dt,m.radius)
			m.dir=m.charge
			if w.player.distance_to(m.p)<m.radius+10:w.damage_player(6)
			if m.timer<=0:recover(m)
		"spiral":
			if m.timer<=0:
				m.phase="channel";m.timer=1.55 if m.rage else 1.3
				m.burst_left=6 if m.rage else 4;m.burst_tick=0
				m.spin_angle=w.clock*.4
		"channel":
			m.burst_tick-=dt
			if m.burst_left>0 and m.burst_tick<=0:
				var count=30 if m.rage else 18
				for j in range(count):
					var angle=m.spin_angle+j*TAU/count
					var direction=Vector2.from_angle(angle)
					var head=Vector2((j%3-1)*18,-18 if j%3==1 else -8)
					var turn=(.28 if j%2 else -.19) if m.rage else (.14 if j%3==0 else -.09 if j%3==1 else 0)
					skull(w,m.p+head+direction*32,direction,(110 if m.rage else 84)+j%4*9,m.rage and j%4==0,turn)
				if m.burst_left%2==0:
					var aim=m.p.direction_to(predicted(w,.35))
					for j in range(3):skull(w,m.p+Vector2((j-1)*22,-16),aim.rotated((j-1)*.2),140 if m.rage else 112)
				m.spin_angle+=.27 if m.burst_left%2 else -.43
				m.burst_tick=.22 if m.rage else .3;m.burst_left-=1
				w.sound("wither_shoot",.2)
			if m.timer<=0:recover(m)
		"roar","recover":
			if m.timer<=0:
				m.phase="walk";m.attack_tick=.28 if m.rage else .55
