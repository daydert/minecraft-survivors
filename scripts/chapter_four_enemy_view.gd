extends RefCounted
## IV-specific enemy tells and residues; all marks use the actual hit geometry.
const Atmosphere=preload("res://scripts/ui/atmosphere.gd")
const Tells=preload("res://scripts/chapter_four_tells.gd")

static func floor_layer(g,offset: Vector2):
	var w=g.world
	for f in w.enemy_fields:
		var p: Vector2=f.p+offset
		var fade: float=minf(1,f.life/.6)
		if f.kind=="web":
			for j in range(7):
				var d=Vector2.from_angle(j*TAU/7)*Vector2(f.radius,f.radius*.55)
				g.draw_line(p-d*.7,p+d,Color(.8,.75,.7,.3*fade),1)
			g.oval(p,Vector2(f.radius,f.radius*.5),Color(.6,.5,.5,.07*fade))
		elif f.kind=="rot":
			g.oval(p,Vector2(f.radius,f.radius*.6),Color(.34,.025,.04,.4*fade))
			for j in range(4):g.draw_rect(Rect2((p+Vector2(sin(j*2.4)*8,cos(j*2.4)*4)).floor(),Vector2(2,1)),Color(.8,.15,.13,.35*fade))
		else:
			g.oval(p,Vector2(f.radius,f.radius*.6),Color(.2,.04,.25,.22*fade))
			for j in range(8):
				var phase=fposmod(w.clock*.6+j*.127,1)
				g.oval(p+Vector2(sin(j*2.4)*f.radius*.7,-phase*16+cos(j*2.4)*6),Vector2(4,2),Color(.6,.3,.68,(1-phase)*.2*fade))
	for m in w.mobs:
		if not m.has("form") or m.hp<=0:continue
		var p: Vector2=m.p+offset
		var k: float=clampf(m.get("phase_age",0.0)/maxf(.01,m.get("phase_duration",1.0)),0,1)
		var seed: int=int(m.id)*7
		if m.phase=="windup":
			var ai: Dictionary=m.get("ai",{})
			match m.kind:
				"flayed_zombie":Tells.claws(g,p,m.charge,float(ai.get("reach",24)),k,seed,w.clock)
				"growth_skeleton":Tells.aim(g,p-Vector2(0,8),m.charge,120,k,w.clock)
				"open_cow","bone_rider","torn_spider","hungry_wolf":
					var end: Vector2=p+m.charge*float(ai.get("dash_speed",120))*float(ai.get("attack",.3))
					Tells.lane(g,p,end,float(m.radius)+6,k,seed,w.clock)
				"bloated_creeper":Tells.ring(g,p,float(ai.get("radius",36)),k,w.clock)
				"infected_witch":
					var heal: bool=m.get("cast","")=="heal"
					Tells.ring(g,m.mark+offset,float(ai.get("heal_radius",60))*.65 if heal else float(ai.get("cloud_radius",30)),k,w.clock,Color(.45,.95,.4) if heal else Tells.HOT)
				"fused_villagers":
					for angle in [-.2,0.0,.2]:Tells.aim(g,p-Vector2(0,14),m.charge.rotated(angle),90,k,w.clock)
				"gravedigger":
					for i in range(m.wall_points.size()):Tells.bulge(g,m.wall_points[i]+offset,k,seed+i*5,w.clock)
				"bellringer":Tells.ring(g,p,float(ai.get("buff_radius",90)),k,w.clock,Color(1,.8,.35))
		if m.phase=="smash_wait":
			var end: Vector2=p+m.charge*m.ai.slam_length
			Tells.lane(g,p,end,float(m.ai.slam_width),k,seed+90,w.clock)
		if m.lift>0:g.oval(p,Vector2(12,3),Color(0,0,0,.4))
	for wall in w.mob_walls:
		var p: Vector2=wall.p+offset
		var rise: float=minf(1,wall.age/.18)
		g.draw_set_transform(p,0,Vector2(1,rise))
		g.sprite("ch4_earth_wall",Vector2(-12,-22))
		g.draw_set_transform(Vector2.ZERO)
	for c in w.chickens:
		if c.state=="flee" and c.age>3:continue
		g.draw_actor("ch4_chicken",c.p+offset,c.dir,c.age,c.state=="flee",Color(.75,.7,.7),"walk",1,{"state":"walk" if c.state=="flee" else "idle","time":c.age})

static func actor(g,m: Dictionary,offset: Vector2):
	var tint=Color(1.5,1.3,1.3) if m.flash>0 and g.settings.flashes else Color.WHITE
	g.draw_actor(m.skin,m.p+offset-Vector2(0,m.lift),m.visual_dir,m.animation,m.moving,tint,m.phase,1,m.visual)
	if m.get("ch4_cracks",0)>0:
		var chest: Vector2=m.p+offset-Vector2(0,15+m.lift)
		for j in range(int(m.ch4_cracks)):
			var q: Vector2=chest+Vector2((j%2)*5-2,(j/2)*4-3)
			g.draw_polyline(PackedVector2Array([q+Vector2(-2,-3),q,q+Vector2(-1,3),q+Vector2(2,5)]),Color(.08,.015,.02,.8),1)
	if m.get("bat_mark",0.0)>g.world.clock:
		g.draw_line(m.p+offset-Vector2(3,31),m.p+offset-Vector2(0,28),Color(.8,.1,.12,.8),1)
		g.draw_line(m.p+offset-Vector2(0,28),m.p+offset-Vector2(-3,31),Color(.8,.1,.12,.8),1)
	if m.stun>0:
		for j in range(3):
			var a=g.world.clock*5+j*TAU/3
			g.draw_rect(Rect2((m.p+offset+Vector2(cos(a)*7,-35+sin(a)*2)).floor(),Vector2(2,2)),Color(.85,.75,.4,.8))
	if m.haste>0:
		var q: Vector2=m.p+offset
		g.draw_line(q-Vector2(6,2),q-Vector2(2,4),Color(.85,.6,.25,.5),1)
		g.draw_line(q+Vector2(3,1),q+Vector2(7,-1),Color(.85,.6,.25,.5),1)
	if m.burn>0:g.draw_clip("fire_animation",m.p+offset-Vector2(9,20),Vector2(18,21),g.world.clock)
	if m.boss:
		var q: Vector2=m.p+offset-Vector2(15,48 if m.kind in ["gravedigger","bone_rider"] else 40)
		g.draw_rect(Rect2(q,Vector2(30,3)),Color(.15,.1,.1))
		g.draw_rect(Rect2(q,Vector2(30*maxf(0,m.hp)/m.max_hp,2)),Color(.72,.22,.18))

static func projectiles(g,offset: Vector2):
	for b in g.world.enemy_shots:
		var p: Vector2=(b.p+offset-Vector2(0,8)).floor()
		if b.kind=="bone":
			g.draw_set_transform(p,b.dir.angle()+PI/4)
			g.sprite("icon_arrow",Vector2(-8,-8));g.draw_set_transform(Vector2.ZERO)
		else:
			g.draw_line(p-b.dir*7,p,Color(.55,.04,.08,.7),3)
			g.draw_rect(Rect2(p-Vector2(2,2),Vector2(4,4)),Color(.85,.25,.2))
	for b in g.world.enemy_bottles:
		var k: float=clampf(b.age/b.total,0,1)
		var p: Vector2=b.p.lerp(b.end,k)+offset-Vector2(0,sin(k*PI)*28+8)
		g.sprite("icon_potion",p-Vector2(8,8),Vector2.ZERO,Color(.8,.45,.9))

static func effect(g,e: Dictionary,offset: Vector2) -> bool:
	var p: Vector2=e.p+offset
	var k: float=clampf(e.age/e.total,0,1)
	match e.kind:
		"ch4_remains":g.draw_actor(e.skin,p,e.dir,e.age,false,Color(.6,.45,.45,1-k),"death",1,{"state":"death","time":e.age})
		"ch4_slam":
			var end: Vector2=e.end+offset
			g.draw_line(p,end,Color(.6,.35,.2,(1-k)*.6),e.width*2)
			for j in range(8):
				var q: Vector2=p.lerp(end,j/8.0)+Vector2(sin(j*7)*e.width,cos(j*7)*5-k*15)
				g.draw_rect(Rect2(q.floor(),Vector2(3,3)),Color(.65,.44,.28,1-k))
		"ch4_burst":
			for j in range(12):
				var d=Vector2.from_angle(j*2.4)
				g.draw_rect(Rect2((p+d*e.radius*k).floor(),Vector2(4,3)*(1-k)),Color(.8,.22,.15,1-k))
		"ch4_heal":
			for j in range(8):g.draw_line(p+Vector2(sin(j*2.4)*18,-k*22+cos(j*2.4)*6),p+Vector2(sin(j*2.4)*18,-k*22+cos(j*2.4)*6-3),Color(.5,.9,.4,1-k),2)
		"ch4_bell_wave":
			for j in range(3):g.oval(p-Vector2(0,25),Vector2(9+k*24+j*4,4+k*8+j*2),Color(.9,.75,.3,(1-k)*.12))
		"ch4_shed":
			for j in range(8):
				var d=Vector2.from_angle(j*2.4)
				g.draw_rect(Rect2((p+d*(4+k*20)-Vector2(0,8+sin(k*PI)*8)).floor(),Vector2(3,3)),Color(.55,.4,.37,1-k))
		"ch4_stun":pass
		_:return false
	return true
