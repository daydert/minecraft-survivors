extends RefCounted
## A single world offset for ground, blood, silhouettes and actors. Visual
## hashes and the simulation clock keep pause/camera movement deterministic.
const EnemyView=preload("res://scripts/chapter_four_enemy_view.gd")
const ArsenalView=preload("res://scripts/chapter_four_arsenal_view.gd")
const Lighting = preload("res://scripts/ui/lighting.gd")
const Atmosphere = preload("res://scripts/ui/atmosphere.gd")
const ANCHORS = {"house": Vector2(56,66), "crucifix": Vector2(32,88), "growth": Vector2(24,40), "growth_big": Vector2(64,96), "torch": Vector2(8,21), "pyramid": Vector2(144,150)}

func world(g):
	var w = g.world
	var offset: Vector2 = Vector2(320,180) - w.camera().floor()
	if w.stage == "survival":offset -= g.cam_lead.round()
	if w.shake > 0 and g.settings.shake and w.state == "RUNNING":offset += Vector2(sin(w.clock*75), cos(w.clock*87)).round()
	g.draw_texture_rect_region(g.textures.ch4_ground, Rect2(0,0,640,360), Rect2(-offset,Vector2(640,360)))
	blood(g, offset)
	EnemyView.floor_layer(g,offset)
	ArsenalView.floor_layer(g,offset)
	for mark in w.landmarks:
		if mark.kind == "crucifix":pillar_floor(g, mark, offset)
		if mark.get("attack", "") == "windup" and mark.kind == "torch":
			var other = w.linked_torch(mark)
			if other != null:
				g.draw_line((mark.p+offset).floor(), (other.p+offset).floor(), Color(.8,.24,.18,.24), float(w.db.data.chapter_four.cursed_torch.width)*2)
				g.draw_dashed_line((mark.p+offset).floor(), (other.p+offset).floor(), Color(1,.65,.46,.8), 1, 5)
	var actors: Array = []
	for obj in w.props:
		if obj.type == "pumpkin" and obj.hp <= 0:continue
		if Rect2(-80,-100,800,560).has_point(obj.p+offset):actors.append({"sort":obj.p.y,"kind":"prop","obj":obj})
	for mark in w.landmarks:
		if Rect2(-180,-50,1000,600).has_point(mark.p+offset):actors.append({"sort":mark.p.y,"kind":"landmark","obj":mark})
	for m in w.mobs:
		if Rect2(-100,-100,840,560).has_point(m.p+offset):actors.append({"sort":m.p.y,"kind":"mob","obj":m})
	for o in w.loot:
		if Rect2(-24,-24,688,408).has_point(o.p+offset):actors.append({"sort":o.p.y,"kind":"loot","obj":o})
	actors.append({"sort":w.player.y,"kind":"player"})
	if w.build.has("embryo"):actors.append({"sort":w.arsenal.pet.p.y,"kind":"pet"})
	if not w.blood_hand.is_empty():actors.append({"sort":w.blood_hand.p.y+2,"kind":"hand"})
	actors.sort_custom(func(a,b):return a.sort < b.sort)
	for actor in actors:
		match actor.kind:
			"landmark":landmark(g, actor.obj, offset)
			"prop":
				var o = actor.obj
				var p: Vector2 = o.p+offset
				if o.type == "tree":
					g.oval(p,Vector2(16,4),Color(0,0,0,.35))
					var alpha := .42 if absf(w.player.x-o.p.x)<22 and w.player.y<o.p.y and w.player.y>o.p.y-60 else 1.0
					g.sprite("tree_dead_"+str(o.variant),p-Vector2(32,67),Vector2.ZERO,Color(.68,.58,.58,alpha))
				else:g.sprite("pumpkin",p-Vector2(12,19),Vector2.ZERO,Color(.8,.68,.65))
			"player":
				ArsenalView.player(g,offset)
			"pet":ArsenalView.pet(g,offset)
			"mob":
				var m = actor.obj
				if m.has("form"):EnemyView.actor(g,m,offset)
				else:g.draw_actor(m.kind,m.p+offset,m.visual_dir,m.animation,m.moving,Color.WHITE,m.phase,1,m.visual)
			"loot":
				var o = actor.obj
				g.item_icon(o.kind, o.p+offset-Vector2(8,16+sin(w.clock*3)*2))
			"hand":hand(g,offset)
	for o in w.orbs:
		var p: Vector2 = (o.p+offset).floor()
		g.draw_texture_rect_region(g.textures.experience_orb,Rect2(p-Vector2(4,5),Vector2(8,8)),Rect2(0,0,16,16),Color(.6,1,.4))
	for b in w.projectiles:g.draw_projectile(b,offset)
	EnemyView.projectiles(g,offset)
	ArsenalView.air_layer(g,offset)
	for e in w.effects:
		if ArsenalView.effect(g,e,offset):pass
		elif EnemyView.effect(g,e,offset):pass
		elif e.kind == "ch4_arc":arc(g,e,offset)
		else:g.draw_effect(e,offset)
	for b in w.blood_shots:
		var p: Vector2 = (b.p+offset).floor()
		g.draw_line(p-b.dir*8,p,Color(.45,.025,.035,.8),3)
		g.draw_rect(Rect2(p-Vector2(2,2),Vector2(4,4)),Color(.9,.2,.17))
		g.draw_rect(Rect2(p-Vector2.ONE,Vector2.ONE),Color(1,.65,.45))
	for pool in [w.particles,w.pixels]:
		for particle in pool:
			g.draw_rect(Rect2((particle.p+offset).floor(),Vector2.ONE*ceilf(particle.get("size",2))),Color(particle.color,clampf(particle.life/.1,0,1)))
	Atmosphere.collect(g,offset)
	Lighting.draw(g,offset)
	Atmosphere.after_lighting(g,offset)
	if w.stage == "arrival":arrival(g)

func blood(g, offset: Vector2):
	var w = g.world
	var start := Vector2i((-offset/16).floor())
	var end := start+Vector2i(42,25)
	for y in range(start.y,end.y):
		for x in range(start.x,end.x):
			var cell := Vector2i(x,y)
			if not w.pools.has(cell):continue
			var p := Vector2(cell*16)+offset
			g.draw_rect(Rect2(p-Vector2.ONE,Vector2(18,18)),Color(.09,.018,.022))
	for y in range(start.y,end.y):
		for x in range(start.x,end.x):
			var cell := Vector2i(x,y)
			if not w.pools.has(cell):continue
			var p := Vector2(cell*16)+offset
			g.draw_clip("ch4_blood_animation",p,Vector2(16,16),w.clock)
			if not w.pools.has(cell+Vector2i.UP):g.draw_line(p,p+Vector2(16,0),Color(.43,.11,.1),1)
			if not w.pools.has(cell+Vector2i.DOWN):g.draw_line(p+Vector2(0,15),p+Vector2(16,15),Color(.18,.015,.025),1)
			if Atmosphere.hash01(x,y,81)<.2:
				var shine := .12+.10*sin(w.clock*1.1+x*.5+y*.8)
				var q := p+Vector2(3+int(x+y)%4,7)
				g.draw_line(q,q+Vector2(5,0),Color(.9,.4,.34,shine),1)

func pillar_floor(g, mark: Dictionary, offset: Vector2):
	var w = g.world
	var rage: bool = w.note_read
	var p: Vector2 = mark.p+offset
	for j in range(9):
		var angle: float = j*2.39996+mark.phase
		var phase := fposmod(w.clock*.21+j*.173,1)
		var q := p+Vector2.from_angle(angle)*Vector2(45,17)*(1-phase*.35)
		q.y += -phase*18 if rage else phase*9
		g.draw_rect(Rect2(q.floor(),Vector2(1,2)),Color(.95,.22,.12,sin(phase*PI)*.48) if rage else Color(.42,.4,.45,sin(phase*PI)*.32))

func landmark(g, mark: Dictionary, offset: Vector2):
	var w = g.world
	var p: Vector2 = (mark.p+offset).floor()
	if mark.kind == "note":
		g.oval(p,Vector2(9,3),Color(0,0,0,.45))
		g.sprite("icon_ch4_note",p-Vector2(8,12),Vector2(16,16),Color(.6,.54,.5) if w.note_read else Color.WHITE)
		return
	var name: String = "ch4_"+mark.kind
	if mark.kind in ["house","crucifix","growth"]:name += "_"+str(mark.variant)
	if mark.kind == "torch":name = "ch4_cursed_torch" if mark.hostile else "ch4_red_torch"
	var anchor: Vector2 = Vector2(16,34) if name == "ch4_cursed_torch" else ANCHORS[mark.kind]
	if mark.get("dead",false):
		g.oval(p,Vector2(10,3),Color(.17,.025,.03))
		g.sprite(name,p-anchor,Vector2.ZERO,Color(.2,.16,.16,.25))
		return
	g.oval(p+Vector2(0,2),Vector2(100,15) if mark.kind=="pyramid" else Vector2(30,7) if mark.kind=="house" else Vector2(12,4),Color(0,0,0,.4))
	var pulse: float = 1+.025*sin(w.clock*2.2+mark.phase) if mark.kind.begins_with("growth") else 1.0
	if mark.get("attack","") == "windup":pulse += .12*(1-float(mark.timer)/float(w.db.data.chapter_four.growth.windup)) if mark.kind != "torch" else 0
	var color := Color(1.4,1.1,1.1) if mark.get("flash",0)>0 and g.settings.flashes else Color.WHITE
	# Fade an occluding ruin rather than hiding the hero behind the wall.
	if mark.kind in ["house","pyramid"] and absf(w.player.x-mark.p.x)<(105 if mark.kind=="pyramid" else 40) and w.player.y<mark.p.y and w.player.y>mark.p.y-80:color.a=.42
	g.draw_set_transform(p,0,Vector2.ONE*pulse)
	g.sprite(name,-anchor,Vector2.ZERO,color)
	g.draw_set_transform(Vector2.ZERO)
	if mark.kind == "torch":
		var charged: bool = mark.get("attack","") == "windup"
		g.draw_rect(Rect2(p-Vector2(1,25 if mark.hostile else 13),Vector2(2,2)),Color(1,.8,.55) if charged else Color(.9,.18,.09,.8))
	if mark.get("attack","") == "windup" and mark.kind != "torch":
		var d: Vector2 = mark.aim
		for j in range(3):
			var q := p+d.rotated((j-1)*.36)*(20+5*sin(w.clock*5))
			g.draw_line(q-d*5,q,Color(1,.4,.28,.8),2)

func hand(g, offset: Vector2):
	var h: Dictionary = g.world.blood_hand
	var wait: float = g.world.db.data.chapter_four.blood_hand.windup
	var p: Vector2 = h.p+offset
	if h.age < wait:
		var k: float = h.age/wait
		g.oval(p,Vector2(8+10*k,4+5*k),Color(.015,0,.01,.4+.35*k))
		for j in range(3):
			var q := p+Vector2(j*6-6,-2+sin(k*5+j)*2)
			g.draw_line(q,q+Vector2(2,-3-4*k),Color(.045,.005,.01,.8),2)
	else:
		var age: float = h.age-wait
		var rise := minf(1,age/.16)*(1-smoothstep(.5,.8,age))
		g.draw_clip("ch4_hand",p-Vector2(32,35+rise*13),Vector2(64,72),age,Color(1,1,1,rise),false)

func arc(g, e: Dictionary, offset: Vector2):
	var a: Vector2 = e.p+offset
	var b: Vector2 = e.end+offset
	var d := (b-a).orthogonal().normalized()
	var last := a
	for j in range(1,9):
		var q := a.lerp(b,j/8.0)+d*sin(j*7+e.seed)*3*sin(j*PI/8)
		g.draw_line(last,q,Color(.95,.27,.17,.8),3)
		g.draw_line(last,q,Color(1,.9,.72),1)
		last=q

func arrival(g):
	var t: float = g.world.stage_age
	var total: float = g.world.db.data.chapter_four.arrival_duration
	var fade := smoothstep(.3,1.1,t)*(1-smoothstep(total-1.3,total-.2,t))
	var bars := 18*(1-smoothstep(total-1,total,t))
	g.draw_rect(Rect2(0,0,640,bars),Color.BLACK)
	g.draw_rect(Rect2(0,360-bars,640,bars),Color.BLACK)
	g.centered("Глава IV",75,16,Color(.7,.7,.7,fade),true)
	g.centered("«Обычный мир»",104,24,Color(1,1,1,fade),true)
	if g.settings.flashes and int(t*60)%137 in [67,68]:
		g.draw_line(Vector2(211,96),Vector2(254,96),Color(.65,.08,.12,fade*.7),1)
	g.draw_rect(Rect2(0,0,640,360),Color(0,0,0,1-smoothstep(0,1,t)))

func note(g):
	g.dim(.88)
	g.panel(Rect2(123,63,394,228))
	g.sprite("icon_ch4_note",Vector2(151,84),Vector2(24,24))
	g.text_at(g.world.db.data.chapter_four.note.title,Vector2(189,102),16,g.INK,true)
	var lines: Array = g.world.db.data.chapter_four.note.lines
	for i in range(lines.size()):g.text_at(lines[i],Vector2(154,137+i*18),8,Color("dddddd"))
	g.button(Rect2(226,251,188,25),"Прочитано","ch4_note_close")
