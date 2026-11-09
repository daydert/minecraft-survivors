extends RefCounted
## Own native atlas cache and world-space choreography; reads the exact combat
## segments, tile proposal and phase clock, with no simulation writes.
static func floor_layer(g,offset: Vector2):
	var w=g.world;var e=w.encounters
	if not e.mass.is_empty() and e.mass.phase!="gone":
		var m: Dictionary=e.mass;var p: Vector2=m.p+offset
		if m.phase=="intro":
			var k: float=clampf(m.phase_age/m.phase_duration,0,1)
			for j in range(13):
				var d:=Vector2.from_angle(j*2.39996);var q: Vector2=p+d*Vector2(58,26)*(1-k*.5)
				g.draw_line(q,q-d*Vector2(10+k*12,6),Color(.07,.005,.01,.8),2)
			g.oval(p,Vector2(40,16),Color(.22,.02,.025,k*.7))
		if m.phase=="windup":
			if m.cast=="haul":
				var end: Vector2=p+m.charge*float(e.data.mass.haul_speed)*float(e.data.mass.haul_time)
				g.draw_line(p,end,Color(.7,.18,.12,.16),float(m.radius)*2)
				for side in [-1,1]:
					var a: Vector2=p+m.charge.orthogonal()*side*m.radius;var b: Vector2=end+m.charge.orthogonal()*side*m.radius
					g.draw_dashed_line(a,b,Color(.9,.45,.3,.7),1,6)
			elif m.cast=="sweep":
				for j in range(11):
					var d: Vector2=m.charge.rotated(-1.05+j*.21)
					g.draw_line(p+d*22,p+d*float(e.data.mass.sweep_reach),Color(.75,.22,.17,.15),5)
				arc(g,p,m.charge.angle()-1.05,m.charge.angle()+1.05,e.data.mass.sweep_reach,Color(.95,.45,.3,.7))
			elif m.cast=="fan":
				for j in [-1,1]:
					var q: Vector2=p+Vector2(j*18,-14)
					g.draw_line(q,q+m.p.direction_to(m.aim)*35,Color(.9,.4,.25,.5),1)
		elif m.phase=="attack" and m.cast=="sweep":
			var s: Array=e.sweep_segment();g.draw_line(s[0]+offset,s[1]+offset,Color(.52,.06,.07,.65),float(e.data.mass.sweep_width)*2)
			g.draw_line(s[0]+offset,s[1]+offset,Color(.95,.5,.35,.65),2)
	for limb in e.loose:
		if limb.phase=="windup":
			var p: Vector2=limb.p+offset
			g.oval(p,Vector2(26,15),Color(.55,.1,.08,.18))
			for j in range(5):g.draw_line(p+Vector2.from_angle(j*TAU/5)*20,p+Vector2.from_angle(j*TAU/5)*25,Color(.9,.35,.22,.7),1)
	if e.golem.visible and e.golem.started:
		var m: Dictionary=e.golem
		if m.phase=="windup":
			var p: Vector2=m.p+offset;var end: Vector2=p+m.charge*float(e.data.golem.reach);var side: Vector2=m.charge.orthogonal()*float(e.data.golem.width)
			g.draw_colored_polygon(PackedVector2Array([p-side,p+side,end+side,end-side]),Color(.85,.55,.25,.14))
			g.draw_line(end-side,end+side,Color(1,.75,.35,.8),2)
		if not e.rescued:
			for node in e.nodes:
				if node.encounter_actor!="golem_node" or node.hp<=0:continue
				var a: Vector2=m.p+offset-Vector2(0,22);var b: Vector2=node.p+offset
				g.draw_line(a,b,Color(.27,.035,.04,.9),4)
				g.draw_line(a+Vector2(1,0),b+Vector2(1,0),Color(.7,.16,.13,.8),1)
	for cell in e.proposal:
		var p: Vector2=e.grid_point(cell)+offset
		g.draw_rect(Rect2(p-Vector2(16,16),Vector2(32,32)),Color(.66,.49,.36,.16))
		g.draw_rect(Rect2(p-Vector2(15,15),Vector2(30,30)),Color(.9,.76,.56,.7),false,1)
		for j in [-1,1]:g.draw_line(p+Vector2(j*6,7),p+Vector2(j*6,-7),Color(.85,.75,.55,.7),1)
	for beam in e.beams:
		var a: Vector2=beam.a+offset;var b: Vector2=beam.b+offset
		if beam.live:
			g.draw_line(a,b,Color(.65,.04,.02,.7),float(e.data.guardian.beam_width)*2)
			g.draw_line(a,b,Color(1,.68,.35,.85),2)
		else:g.draw_dashed_line(a,b,Color(.85,.28,.13,.4),1,7)

static func append_actors(g,list: Array):
	var e=g.world.encounters
	if not e.mass.is_empty() and e.mass.phase!="gone":list.append({"sort":e.mass.p.y,"kind":"encounter","obj":e.mass})
	if e.golem.visible:list.append({"sort":e.golem.p.y,"kind":"encounter","obj":e.golem})
	if not e.guardian.is_empty() and e.guardian.phase!="gone":list.append({"sort":e.guardian.p.y,"kind":"encounter","obj":e.guardian})
	for limb in e.loose:list.append({"sort":limb.p.y,"kind":"encounter","obj":limb})
	for node in e.nodes:
		if node.hp>0 or node.encounter_actor=="guardian_torch":list.append({"sort":node.p.y+1,"kind":"enc_node","obj":node})
	for cell in e.blocks:list.append({"sort":e.grid_point(cell).y,"kind":"enc_block","obj":cell})

static func actor(g,m: Dictionary,offset: Vector2):
	var w=g.world;var e=w.encounters
	g.four_actor_texture(m.skin)
	var tint:=Color.WHITE
	if m.flash>0 and g.settings.flashes:tint=Color(1.5,1.2,1.1)
	if m.phase=="death":tint=Color(1,1,1,1-smoothstep(.45,1,m.phase_age/m.phase_duration))
	if m.encounter_actor=="loose":
		tint.a=minf(1,m.life/.6)
		g.draw_actor(m.skin,m.p+offset-Vector2(0,m.lift),m.dir,m.animation,true,tint,"walk",1,{"state":"walk","time":m.phase_age})
	else:g.draw_actor(m.skin,m.p+offset,m.visual_dir,m.animation,m.moving,tint,m.phase,m.scale,m.visual)
	if m.encounter_actor=="mass" and m.phase not in ["death","intro"]:
		for part in e.parts:
			if part.hp<=0 or part.flash<=0:continue
			var p: Vector2=part.p+offset-Vector2(0,14)
			g.draw_line(p-Vector2(3,0),p+Vector2(3,0),Color(.95,.55,.4,.7),1)
	if m.encounter_actor=="golem" and e.rescued:
		var p: Vector2=m.p+offset
		if m.phase=="release":
			for j in range(10):
				var k: float=fposmod(m.phase_age*.4+j*.1,1);var q: Vector2=p+Vector2(sin(j*2.4)*22,-k*38)
				g.draw_rect(Rect2(q.floor(),Vector2(1,2)),Color(.8,.85,.5,(1-k)*.7))

static func node(g,n: Dictionary,offset: Vector2):
	var p: Vector2=n.p+offset;var w=g.world
	if n.encounter_actor=="guardian_torch":
		g.sprite("ch4_red_torch",p-Vector2(8,21),Vector2.ZERO,Color(.35,.35,.35) if n.disabled else Color.WHITE)
		if not n.disabled:
			var live: bool=w.encounters.beams.any(func(b):return b.live and n.id in [b.from,b.to])
			g.oval(p-Vector2(0,18),Vector2(4,3),Color(1,.55,.2,.25 if live else .08))
		return
	g.oval(p,Vector2(10,3),Color(0,0,0,.4))
	var scale: float=1+.04*sin(w.clock*4+n.id)
	g.draw_set_transform(p.floor(),0,Vector2.ONE*scale)
	g.sprite("ch4d_node",Vector2(-16,-23),Vector2.ZERO,Color(1.5,1.1,1.1) if n.flash>0 and g.settings.flashes else Color.WHITE)
	g.draw_set_transform(Vector2.ZERO)
	g.draw_rect(Rect2(p-Vector2(10,29),Vector2(20,2)),Color(.12,.04,.04))
	g.draw_rect(Rect2(p-Vector2(10,29),Vector2(20*maxf(0,n.hp)/n.max_hp,1)),Color(.8,.23,.16))

static func block_actor(g,cell: Vector2i,offset: Vector2):
	var e=g.world.encounters;var p: Vector2=e.grid_point(cell)+offset
	var rise: float=.35+.65*minf(1,e.guardian.phase_age/.22)
	g.draw_set_transform(p.floor(),0,Vector2(1,rise));g.sprite("ch4d_block",Vector2(-24,-32));g.draw_set_transform(Vector2.ZERO)
	g.draw_line(p+Vector2(-14,-8*rise),p+Vector2(10,-12*rise),Color(.75,.65,.5,.25),1)

static func air_layer(g,offset: Vector2):
	var w=g.world;var e=w.encounters
	for b in e.shots:
		var p: Vector2=b.p+offset-Vector2(0,7)
		g.draw_line(p-b.dir*9,p,Color(.3,.02,.035,.8),4)
		g.draw_rect(Rect2(p-Vector2(2,2),Vector2(4,4)),Color(.86,.2,.15))
		g.draw_rect(Rect2(p-Vector2(1,1),Vector2(2,1)),Color(1,.7,.45))
	for d in e.debris:
		var p: Vector2=d.p+offset;var k: float=clampf(d.age/d.life,0,1)
		if d.kind=="stone":
			g.draw_set_transform(p,d.seed*.7+k*2,Vector2.ONE*.28)
			g.sprite("ch4d_shard",Vector2(-24,-32),Vector2.ZERO,Color(1,1,1,1-k));g.draw_set_transform(Vector2.ZERO)
		else:
			g.draw_rect(Rect2(p.floor(),Vector2(3+d.seed%3,2+d.seed%2)),Color(.55,.08,.07,1-k))
			g.draw_line(p,p-Vector2(2,3),Color(.8,.32,.26,1-k),1)

static func effect(g,e: Dictionary,offset: Vector2) -> bool:
	var p: Vector2=e.p+offset;var k: float=clampf(e.age/e.total,0,1)
	match e.kind:
		"ch4d_detach","ch4d_release","ch4d_torch_break":
			for j in range(9):
				var q: Vector2=p+Vector2.from_angle(j*2.39996)*k*22-Vector2(0,sin(k*PI)*(6+j%4*2))
				g.draw_rect(Rect2(q.floor(),Vector2(2,2)),Color(.8,.7,.4,1-k) if e.kind=="ch4d_release" else Color(.7,.15,.1,1-k))
		"ch4d_golem_slam":
			var end: Vector2=e.end+offset
			g.draw_line(p,end,Color(.75,.6,.4,.15*(1-k)),float(e.width)*2)
			for j in range(10):
				var q: Vector2=p.lerp(end,j/10.0)+Vector2(sin(j*7)*e.width,cos(j*7)*6-k*12)
				g.draw_line(q,q+Vector2(3,-2),Color(.7,.57,.43,1-k),2)
		"ch4d_limb_hit":
			for j in range(7):
				var q: Vector2=p+Vector2.from_angle(j*TAU/7)*k*e.radius
				g.draw_rect(Rect2(q.floor(),Vector2(2,2)),Color(.8,.18,.1,1-k))
		_:return false
	return true

static func arc(g,p: Vector2,a: float,b: float,r: float,color: Color):
	var points:=PackedVector2Array()
	for j in range(24):points.append(p+Vector2.from_angle(lerpf(a,b,float(j)/23))*r)
	g.draw_polyline(points,color,1)

static func hud(g):
	var w=g.world;var e=w.encounters
	var title: String=e.title()
	if not title.is_empty():
		var m: Dictionary=e.mass if e.current=="mass" else e.guardian
		if m.phase!="gone":
			g.centered(title,43,8,g.INK,true)
			g.draw_rect(Rect2(228,48,184,4),Color(.12,.08,.08))
			g.draw_rect(Rect2(229,49,182*maxf(0,m.hp)/m.max_hp,2),Color(.63,.12,.13) if e.current=="mass" else Color(.7,.62,.5))
	elif e.golem.started and not e.rescued and w.player.distance_to(e.golem.p)<180:
		g.centered("Железный голем",43,8,g.INK)
		var living: int=e.nodes.filter(func(n):return n.encounter_actor=="golem_node" and n.hp>0).size()
		for j in range(3):g.draw_rect(Rect2(298+j*16,48,12,3),Color(.75,.15,.12) if j<living else Color(.35,.5,.25))
	if not e.busy() and w.time>=e.data.guardian.at and not e.guardian_done:marker(g,e.arena().get_center(),"pyramid")
	if not e.busy() and e.golem.visible and not e.rescued:marker(g,e.golem.p,"golem")

static func marker(g,p: Vector2,kind: String):
	var delta: Vector2=p-g.world.player
	if delta.length()<180:return
	var direction: Vector2=delta.normalized();var q: Vector2=Vector2(320,170)+direction*Vector2(285,115)
	var side: Vector2=direction.orthogonal()
	g.draw_colored_polygon(PackedVector2Array([q+direction*5,q-direction*3+side*3,q-direction*3-side*3]),Color(.75,.62,.42,.8))
	if kind=="pyramid":g.draw_colored_polygon(PackedVector2Array([q-Vector2(5,6),q-Vector2(0,13),q+Vector2(5,-6)]),Color(.5,.48,.45,.8))
	else:g.draw_rect(Rect2(q-Vector2(4,12),Vector2(8,6)),Color(.6,.64,.48,.8))

static func cinematic(g):
	var e=g.world.encounters
	if not e.busy():return
	var m: Dictionary=e.mass if e.current=="mass" else e.guardian
	if m.phase!="intro":return
	var fade: float=sin(clampf(m.phase_age/m.phase_duration,0,1)*PI)
	g.draw_rect(Rect2(0,0,640,13),Color(0,0,0,fade*.7));g.draw_rect(Rect2(0,292,640,10),Color(0,0,0,fade*.7))

static func lights(g):
	var w=g.world;var e=w.encounters
	if e.golem.visible:
		g.ambient_lights.append({"p":e.golem.p-Vector2(0,22),"r":84.0 if e.rescued else 48.0,"c":Color(.95,.8,.44) if e.rescued else Color(.75,.1,.08),"power":.6 if e.rescued else .3,"glow":.05})
	for node in e.nodes:
		if node.hp<=0 or node.get("disabled",false):continue
		var charged: bool=e.beams.any(func(b):return b.live and node.id in [b.from,b.to])
		g.ambient_lights.append({"p":node.p-Vector2(0,14),"r":48.0 if charged else 30.0,"c":Color(1,.35,.12),"power":.65 if charged else .35,"glow":.12 if charged else .04})
	if not e.guardian.is_empty() and e.current=="guardian":
		g.ambient_lights.append({"p":e.guardian.p-Vector2(0,38),"r":44.0,"c":Color(.85,.87,.8),"power":.4,"glow":.03})
