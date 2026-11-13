extends RefCounted
const BossBar=preload("res://scripts/ui/boss_bar.gd")
## Own native atlas cache and world-space choreography; reads the exact combat
## segments, tile proposal and phase clock, with no simulation writes.
const FinaleView=preload("res://scripts/chapter_four_finale_view.gd")
const Tells=preload("res://scripts/chapter_four_tells.gd")
const Atmosphere=preload("res://scripts/ui/atmosphere.gd")

static func hh(i: int,salt: int) -> float:return Atmosphere.hash01(i,salt,57)

## Presentation memory (never read by combat): the trail the mass drags and
## where the bosses fell, so the blood they leave stays on the ground.
static func memory(g) -> Dictionary:
	if not g.has_meta("ch4_enc_memory"):g.set_meta("ch4_enc_memory",{"trail":[],"falls":[],"mass_id":-1,"last":Vector2.INF})
	return g.get_meta("ch4_enc_memory")

static func remember(g):
	var e=g.world.encounters;var mem: Dictionary=memory(g)
	if e.mass.is_empty():return
	if mem.mass_id!=e.mass.id:mem.mass_id=e.mass.id;mem.trail=[];mem.last=Vector2.INF
	if e.mass.phase in ["walk","attack","recover","windup"] and e.mass.p.distance_to(mem.last)>9:
		mem.last=e.mass.p;mem.trail.append({"p":e.mass.p+Vector2(hh(mem.trail.size(),1)*10-5,hh(mem.trail.size(),2)*6),"r":3.0+hh(mem.trail.size(),3)*4.0,"seed":mem.trail.size()})
		if mem.trail.size()>160:mem.trail.pop_front()
	if e.mass.phase=="death" and not mem.falls.any(func(f):return f.id==e.mass.id):mem.falls.append({"id":e.mass.id,"p":e.mass.p,"kind":"mass","clock":g.world.clock})
	if not e.guardian.is_empty() and e.guardian.phase=="death" and not mem.falls.any(func(f):return f.id==e.guardian.id):mem.falls.append({"id":e.guardian.id,"p":e.guardian.p,"kind":"guardian","clock":g.world.clock})

static func floor_layer(g,offset: Vector2):
	var w=g.world;var e=w.encounters
	remember(g)
	var mem: Dictionary=memory(g)
	for t in mem.trail:FinaleView.splat(g,t.p+offset,t.r,int(t.seed),1.0)
	for f in mem.falls:
		var age: float=w.clock-f.clock
		if f.kind=="mass":FinaleView.blood_pool(g,f.p+offset+Vector2(0,4),minf(46.0,8.0+age*30.0),w.clock)
		else:
			for j in range(14):
				var q: Vector2=f.p+offset+Vector2(hh(j,4)*70-35,hh(j,5)*26-10)
				g.draw_rect(Rect2(q.floor(),Vector2(3+j%3,2+j%2)),Color(.32,.29,.27))
	if not e.mass.is_empty() and e.mass.phase!="gone":
		var m: Dictionary=e.mass;var p: Vector2=m.p+offset
		if m.phase=="intro":
			var k: float=clampf(m.phase_age/m.phase_duration,0,1)
			for j in range(13):
				var d:=Vector2.from_angle(j*2.39996);var q: Vector2=p+d*Vector2(58,26)*(1-k*.5)
				g.draw_line(q,q-d*Vector2(10+k*12,6),Color(.07,.005,.01,.8),2)
			g.oval(p,Vector2(40,16),Color(.22,.02,.025,k*.7))
		if m.phase=="windup":
			var wk: float=clampf(m.phase_age/maxf(.01,m.phase_duration),0,1)
			if m.cast=="haul":
				var end: Vector2=p+m.charge*float(e.data.mass.haul_speed)*float(e.data.mass.haul_time)
				Tells.lane(g,p,end,float(m.radius),wk,int(m.id),w.clock)
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
			# The swing leaves a pale arc behind it.
			for j in range(6):
				var k0: float=clampf(m.phase_age/maxf(.01,m.phase_duration)-j*.05,0,1)
				var sj: Array=e.sweep_segment(k0)
				g.draw_line(sj[0]+offset,sj[1]+offset,Color(1,.85,.8,.5*(1-j/6.0)),3-j*.4)
			var s: Array=e.sweep_segment();g.draw_line(s[0]+offset,s[1]+offset,Color(.52,.06,.07,.65),float(e.data.mass.sweep_width)*2)
			g.draw_line(s[0]+offset,s[1]+offset,Color(1,.95,.9,.9),2)
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
				var pulse: float=.5+.5*sin(w.clock*4.0+node.id)
				var pts:=PackedVector2Array()
				for j in range(9):pts.append(a.lerp(b,j/8.0)+Vector2(0,sin(j*1.3+w.clock*3.0+node.id)*2.5*(1-absf(j/4.0-1))))
				g.draw_polyline(pts,Color(.2,.02,.03,.95),6)
				g.draw_polyline(pts,Color(.55,.08,.08,.9),3)
				g.draw_polyline(pts,Color(.95,.35,.3,.35+.4*pulse),1)
				var drip: float=fposmod(w.clock*.7+node.id*.3,1.0)
				var dq: Vector2=a.lerp(b,.5)+Vector2(0,drip*14)
				g.draw_rect(Rect2(dq.floor(),Vector2(1,2)),Color(.5,.02,.04,1-drip))
	for cell in e.proposal:
		var p: Vector2=e.grid_point(cell)+offset
		g.draw_rect(Rect2(p-Vector2(16,16),Vector2(32,32)),Color(.66,.49,.36,.16))
		g.draw_rect(Rect2(p-Vector2(15,15),Vector2(30,30)),Color(.9,.76,.56,.7),false,1)
		for j in [-1,1]:g.draw_line(p+Vector2(j*6,7),p+Vector2(j*6,-7),Color(.85,.75,.55,.7),1)
	for beam in e.beams:
		var a: Vector2=beam.a+offset;var b: Vector2=beam.b+offset
		if beam.live:
			var wd: float=float(e.data.guardian.beam_width)
			g.draw_line(a,b,Color(1,.4,.12,.18),wd*3.4)
			g.draw_line(a,b,Color(.75,.1,.03,.75),wd*2)
			var core:=PackedVector2Array()
			for j in range(13):core.append(a.lerp(b,j/12.0)+(b-a).normalized().orthogonal()*(hh(j+int(w.clock*30),6)-.5)*2.5)
			g.draw_polyline(core,Color(1,.9,.7,1),2)
			for j in range(6):
				var q: Vector2=a.lerp(b,fposmod(w.clock*2.0+j/6.0,1.0))
				g.draw_rect(Rect2(q.floor()-Vector2(1,1),Vector2(3,3)),Color(1,.95,.8,.9))
		else:
			var k: float=clampf(1.0-beam.wait/float(e.data.guardian.beam_warn),0,1)
			g.draw_dashed_line(a,b,Color(1,.4,.18,.25+.5*k),1,7)
			for q in [a,b]:g.draw_circle(q,2+3*k,Color(1,.5,.2,.4*k))

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
	else:
		if m.encounter_actor=="mass" and m.phase!="death":
			g.oval(m.p+offset+Vector2(0,2),Vector2(34,10)*m.scale,Color(.2,0,.02,.55+.15*sin(w.clock*3.0)))
		if m.encounter_actor=="guardian" and m.phase=="intro":
			for j in range(12):
				var fall: float=fposmod(w.clock*40.0+j*13.0,50.0)
				g.draw_rect(Rect2((m.p+offset+Vector2(hh(j,7)*60-30,-70+fall)).floor(),Vector2(2,2)),Color(.45,.42,.38,1-fall/50.0))
		var lift: float=float(m.get("lift",0.0)) if m.encounter_actor=="mass" else 0.0
		if m.encounter_actor=="mass" and m.get("cast","")=="slam" and m.phase in ["windup","attack"]:
			var k: float=clampf(m.phase_age/maxf(.01,m.phase_duration),0,1)
			var at: Vector2=m.aim+offset
			if m.phase=="windup" or not m.get("slam_landed",false):
				g.oval(at,Vector2(40,14)*m.scale,Color(.35,0,.03,.25+.3*(k if m.phase=="windup" else 1.0)))
				g.draw_arc(at,40*m.scale,0,TAU,40,Color(.9,.15,.12,.5+.4*sin(w.clock*14)),1)
			if m.get("slam_landed",false) and float(m.get("ring_r",0))<float(w.encounters.data.mass.slam_radius):
				var r: float=float(m.ring_r)
				g.draw_arc(m.p+offset,r,0,TAU,64,Color(.75,.05,.08,.85),5)
				g.draw_arc(m.p+offset,maxf(1,r-7),0,TAU,64,Color(1,.5,.4,.5),2)
		if lift>0:g.oval(m.p+offset,Vector2(34,10)*m.scale*(1-lift/140.0),Color(0,0,0,.45))
		g.draw_actor(m.skin,m.p+offset-Vector2(0,lift),m.visual_dir,m.animation,m.moving,tint,m.phase,m.scale,m.visual)
		if m.encounter_actor=="mass" and m.phase not in ["death","gone"]:
			for j in range(7):
				var fall: float=fposmod(w.clock*(.9+hh(j,8)*.6)+hh(j,9),1.0)
				var q: Vector2=m.p+offset+Vector2((hh(j,10)-.5)*44*m.scale,-30*m.scale+fall*30*m.scale)
				g.draw_rect(Rect2(q.floor(),Vector2(1,2+fall*2)),Color(.55,.02,.05,1-fall*.6))
			if m.phase=="attack" and m.cast=="haul":
				for j in range(4):
					g.draw_actor(m.skin,m.p+offset-m.charge*(10+j*12),m.visual_dir,m.animation,true,Color(.6,.1,.1,.35-j*.08),m.phase,m.scale,m.visual)
		if m.encounter_actor=="mass" and m.phase=="death":
			g.draw_set_transform(m.p+offset-Vector2(0,10.4),0,Vector2(2.6,2.6))
			FinaleView.head_burst(g,Vector2.ZERO,m.phase_age)
			g.draw_set_transform(Vector2.ZERO)
		if m.encounter_actor=="guardian" and m.phase=="death":
			var t: float=m.phase_age
			for j in range(10):
				var a: float=-PI*.5+(hh(j,11)-.5)*2.4
				var l: float=40+t*120
				g.draw_line(m.p+offset-Vector2(0,30),m.p+offset-Vector2(0,30)+Vector2.from_angle(a)*l,Color(1,.95,.8,maxf(0,.6-t*.25)),2)
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
		"ch4d_release":
			# The living threads snap; light comes up through the iron.
			g.draw_rect(Rect2(p.x-6-k*10,p.y-260,12+k*20,260),Color(1,.9,.6,.35*(1-k)))
			g.draw_rect(Rect2(p.x-1,p.y-260,2,260),Color(1,1,.9,.9*(1-k)))
			g.draw_arc(p,10+k*120,0,TAU,48,Color(1,.9,.6,1-k),2)
			for j in range(24):
				var a: float=hh(j,12)*TAU
				var q: Vector2=p-Vector2(0,20)+Vector2.from_angle(a)*k*(50+hh(j,13)*70)+Vector2(0,k*k*40)
				g.draw_rect(Rect2(q.floor(),Vector2(3,2)),Color(.55,.06,.06,1-k) if j%2 else Color(1,.85,.5,1-k))
		"ch4d_detach","ch4d_torch_break":
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
	if w.stage!="survival":return
	var title: String=e.title()
	if not title.is_empty():
		var m: Dictionary=e.mass if e.current=="mass" else e.guardian
		if m.phase not in ["gone","intro"]:
			var k: float=maxf(0,m.hp)/m.max_hp
			BossBar.draw(g,title,k,Color("a3121c") if e.current=="mass" else Color("b5a690"))
			if e.current=="mass":
				for part in e.parts:
					var x: float=169+302*(.2+.2*(int(part.component)-1))
					g.draw_rect(Rect2(x-2,53,4,3),Color(.8,.15,.12) if part.hp>0 else Color(.25,.1,.1))
	elif e.golem.started and not e.rescued and w.player.distance_to(e.golem.p)<200 and e.golem.phase!="intro":
		g.centered("Железный голем",40,8,g.INK)
		var living: int=e.nodes.filter(func(n):return n.encounter_actor=="golem_node" and n.hp>0).size()
		for j in range(3):
			g.draw_rect(Rect2(266+j*38,46,34,6),Color("1a1416"))
			g.draw_rect(Rect2(266+j*38,46,34,6),Color(.75,.15,.12) if j<living else Color(.45,.6,.32))
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

## A title card when a boss shows itself: the name large and still, a line
## under it, a few words. Thick bars while it lasts.
static func cinematic(g):
	var e=g.world.encounters
	var m: Dictionary={}
	var name:="";var sub:=""
	if e.busy():
		m=e.mass if e.current=="mass" else e.guardian
		name="СРОСШИЕСЯ" if e.current=="mass" else "ХРАНИТЕЛЬ ПИРАМИДЫ"
		sub="те, кого никто не похоронил" if e.current=="mass" else "камень помнит, кого впускать"
	elif e.golem.started and e.golem.phase=="intro":
		m=e.golem;name="ЖЕЛЕЗНЫЙ ГОЛЕМ";sub="его держат живые нити"
	elif e.golem.started and e.golem.phase=="release":
		m=e.golem;name="СВОБОДЕН";sub="он помнит, кто его освободил"
	if m.is_empty() or m.phase not in ["intro","release"]:
		if not e.mass.is_empty() and e.mass.phase=="death":
			Atmosphere.draw_edges(g,Color(.5,0,.03,.5*maxf(0,1-e.mass.phase_age)))
		if not e.guardian.is_empty() and e.guardian.phase=="death":
			Atmosphere.draw_edges(g,Color(.85,.75,.55,.14*maxf(0,1-e.guardian.phase_age*.8)))
		return
	var k: float=clampf(m.phase_age/maxf(.01,m.phase_duration),0,1)
	var fade: float=smoothstep(0,.25,k)*(1-smoothstep(.8,1,k))
	g.draw_rect(Rect2(0,0,640,26),Color(0,0,0,fade*.9));g.draw_rect(Rect2(0,334,640,26),Color(0,0,0,fade*.9))
	var reveal: float=smoothstep(.15,.45,k)*(1-smoothstep(.85,1,k))
	var size: int=24
	var width: float=g.font.get_string_size(name,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	var y: float=250
	g.text_at(name,Vector2(320-width/2+1,y+1).floor(),size,Color(0,0,0,reveal))
	g.text_at(name,Vector2(320-width/2,y).floor(),size,Color(.93,.9,.88,reveal))
	var line: float=width*smoothstep(.2,.55,k)
	g.draw_rect(Rect2(320-line/2,y+8,line,1),Color(.8,.2,.15,reveal))
	var sw: float=g.font.get_string_size(sub,HORIZONTAL_ALIGNMENT_LEFT,-1,8).x
	g.text_at(sub,Vector2(320-sw/2,y+22).floor(),8,Color(.75,.7,.68,reveal*smoothstep(.35,.6,k)))

static func lights(g):
	var w=g.world;var e=w.encounters
	if e.golem.visible and e.golem.phase=="release":
		g.ambient_lights.append({"p":e.golem.p-Vector2(0,30),"r":160.0,"c":Color(1,.9,.6),"power":.9,"glow":.25})
	if not e.mass.is_empty() and e.mass.phase not in ["gone"]:
		g.ambient_lights.append({"p":e.mass.p,"r":70.0,"c":Color(.9,.1,.08),"power":.35,"glow":.08})
	if e.golem.visible:
		g.ambient_lights.append({"p":e.golem.p-Vector2(0,22),"r":84.0 if e.rescued else 48.0,"c":Color(.95,.8,.44) if e.rescued else Color(.75,.1,.08),"power":.6 if e.rescued else .3,"glow":.05})
	for node in e.nodes:
		if node.hp<=0 or node.get("disabled",false):continue
		var charged: bool=e.beams.any(func(b):return b.live and node.id in [b.from,b.to])
		g.ambient_lights.append({"p":node.p-Vector2(0,14),"r":48.0 if charged else 30.0,"c":Color(1,.35,.12),"power":.65 if charged else .35,"glow":.12 if charged else .04})
	if not e.guardian.is_empty() and e.current=="guardian":
		g.ambient_lights.append({"p":e.guardian.p-Vector2(0,38),"r":44.0,"c":Color(.85,.87,.8),"power":.4,"glow":.03})
