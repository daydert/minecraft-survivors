extends RefCounted
var intro=preload("res://scripts/ghast_intro_renderer.gd").new()
## Native Minecraft sprites, attack cues and chapter cinematics.

func ground(g, offset: Vector2):
	var w=g.world
	if w.stage in ["survival","departure"]:
		g.draw_texture_rect_region(g.textures.nether_ground,Rect2(0,0,640,360),Rect2(w.camera()-Vector2(320,180),Vector2(640,360)))
	else:
		g.draw_rect(Rect2(0,0,640,360),Color("150e11"))
		var p: Vector2=(w.ARENA.position+offset).floor()
		var size: Vector2=w.ARENA.size
		g.draw_texture_rect(g.textures.arena_tile,Rect2(p,size),true)
		# Native 16px tiles on one shared grid, with four complete straight walls.
		for rect in [Rect2(p-Vector2(32,32),Vector2(size.x+64,32)),Rect2(p+Vector2(-32,size.y),Vector2(size.x+64,32)),Rect2(p-Vector2(32,0),Vector2(32,size.y)),Rect2(p+Vector2(size.x,0),Vector2(32,size.y))]:
			g.draw_texture_rect(g.textures.nether_wall,rect,true)
		g.draw_rect(Rect2(p,Vector2(size.x,3)),Color(0,0,0,.5))
		g.draw_rect(Rect2(p,Vector2(3,size.y)),Color(0,0,0,.35))

func portal_cells() -> Array:
	var cells=[]
	for x in range(-1,2):cells.append(Vector2(x,-2))
	for y in range(-1,2):cells.append(Vector2(2,y))
	for x in range(1,-2,-1):cells.append(Vector2(x,2))
	for y in range(1,-2,-1):cells.append(Vector2(-2,y))
	return cells

func floor_effects(g, offset: Vector2):
	var w=g.world
	intro.debris(g,offset)
	for patch in w.magma:
		var p: Vector2=patch.p+offset
		if not Rect2(-60,-60,760,480).has_point(p):continue
		for y in range(-2,3):
			for x in range(-2,3):
				var q=Vector2(x*16,y*16)
				if q.length()<patch.radius:g.draw_clip("magma_animation",(p+q-Vector2(8,8)).floor(),Vector2(16,16),w.clock)
	for b in w.explosives:
		var p: Vector2=b.p+offset
		if b.kind=="bed":g.sprite("bed_ground",p-Vector2(20,23))
		else:
			var scale=.75 if b.get("child",false) else 1.0
			g.oval(p,Vector2(10,3)*scale,Color(0,0,0,.4))
			g.sprite("tnt_ground",p-Vector2(12*scale,24*scale+b.get("height",0.0)),Vector2(24,28)*scale,Color(1.7,1.7,1.7) if g.settings.flashes and fmod(b.age,.22)<.08 else Color.WHITE)
	for h in w.hazards:
		if h.wait<=0:continue
		var p: Vector2=h.p+offset
		var progress=1-h.wait/h.get("total",1.5)
		g.oval(p,Vector2(h.radius,h.radius*.65),Color(.12,.35,.4,.1+progress*.12))
		g.draw_arc(p,h.radius,0,TAU,32,Color(.42,.8,.86,.65),1)
		for j in range(4):
			var dir=Vector2.from_angle(j*PI/2+w.clock*.7)
			g.draw_line(p+dir*(h.radius-3),p+dir*(h.radius+3),Color("b1d9dd"),2)
	for m in w.mobs:
		var p: Vector2=m.p+offset
		if m.kind=="brute" and m.phase=="windup":
			var edge: Vector2=m.charge.orthogonal()*14
			g.draw_colored_polygon(PackedVector2Array([p-edge,p+edge,p+m.charge*112+edge,p+m.charge*112-edge]),Color(1,.55,.3,.15))
		if m.kind!="wither":continue
		if m.phase=="volley":
			for j in range(3):
				var start: Vector2=p+Vector2((j-1)*25,-28 if j!=1 else -40)
				g.draw_line(start,m.mark+offset,Color(.55,.72,.75,.28),1)
	if w.stage in ["portal","lighting","jump"]:draw_portal(g,offset)

func draw_portal(g, offset: Vector2):
	var w=g.world
	var p: Vector2=w.portal_position+offset
	var lit=w.portal_lit
	var lighting=w.stage=="lighting"
	var count=clampi(int((w.stage_age-.45)*12/.85),0,12) if lighting else 12 if lit else 0
	var cells=portal_cells()
	for i in range(cells.size()):
		var pos: Vector2=p+cells[i]*Vector2(15,9)-Vector2(8,6)
		g.sprite("portal_rim",pos.floor(),Vector2(16,12))
		if i<count:g.sprite("portal_rim_eye",pos.floor(),Vector2(16,12))
	if lighting and w.stage_age>.4 and w.stage_age<1.5:
		var active=clampi(count,0,11)
		var cell: Vector2=cells[active]*Vector2(15,9)
		g.draw_line(p+cell,p,Color(.5,.8,.7,.45),1)
		g.draw_clip("soul_fire_animation",p+cell-Vector2(4,11),Vector2(8,14),w.clock,Color(1,1,1,.7))
	var opening=smoothstep(1.0,1.65,w.stage_age) if lighting else 1.0 if lit else 0.0
	if opening>0:
		g.draw_texture_rect(g.textures.end_portal,Rect2(p-Vector2(23,13)*opening,Vector2(46,26)*opening),true)
		for j in range(24):
			var q=p+Vector2(fposmod(j*13.17+w.clock*3,44)-22,fposmod(j*7.31+w.clock,24)-12)*opening
			var light=.3+.7*absf(sin(w.clock*2+j))
			g.draw_rect(Rect2(q.floor(),Vector2.ONE),Color(.55,.72,.7,light*opening))
		for i in range(16):
			var phase=fposmod(w.clock*.5+i*.127,1)
			var q=p+Vector2(cos(i*2.4)*23,-23*phase+sin(i)*10)
			g.draw_rect(Rect2(q.floor(),Vector2.ONE*(1+i%2)),Color(.65,.8,.8,(1-phase)*opening))

func boss(g, m: Dictionary, offset: Vector2):
	var w=g.world
	if w.stage=="arrival":
		intro.body(g,offset)
		if w.stage_age<w.ghast.BURST+.25:return
	var p: Vector2=m.p+offset
	var alpha=smoothstep(w.ghast.BURST+.25,w.ghast.BURST+2.1,w.stage_age) if w.stage=="arrival" else 1.0
	if w.stage=="arrival":p.y+=(1-alpha)*24
	g.oval(p+Vector2(0,2),Vector2(40,11),Color(0,0,0,.42*alpha))
	if m.phase in ["volley","bombard","spiral","roar","channel"] or w.stage=="arrival":
		for j in range(3):
			var point=p+Vector2((j-1)*25,-28 if j!=1 else -40)
			var charge=smoothstep(w.ghast.BURST,w.ghast.BURST+2,w.stage_age) if w.stage=="arrival" else 1-clampf(m.timer/maxf(.01,m.windup),0,1)
			g.draw_clip("soul_fire_animation",point-Vector2(6+charge*3,17),Vector2(12+charge*6,20+charge*6),w.clock+j*.1,Color(1,1,1,(.5+.3*charge)*alpha))
	var tint=Color.WHITE
	if g.settings.flashes and m.flash>0:tint=Color(1.8,1.8,1.8)
	tint.a=alpha
	g.draw_actor("wither",p,m.visual_dir,m.animation,m.moving,tint,m.phase,1,m.visual)
	if w.stage=="arrival":
		for j in range(18):
			var phase=fposmod(w.stage_age*.8+j*.13,1)
			var q=p+Vector2(sin(j*2.4)*48,-phase*86)
			g.draw_rect(Rect2(q.floor(),Vector2(2,3)),Color(.28,.4,.42,(1-phase)*alpha*.6))

func player(g, offset: Vector2) -> bool:
	var w=g.world
	if w.stage not in ["lighting","jump"]:return false
	var ground: Vector2=w.player+offset
	if w.stage=="lighting":
		g.draw_actor("steve",ground,w.facing,w.clock,false,Color.WHITE,"attack",1,{"state":"attack" if w.stage_age<.55 else "recover" if w.stage_age<.9 else "idle","time":minf(.2,w.stage_age*.2)})
		if w.stage_age<.55:
			var progress=clampf(w.stage_age/.5,0,1)
			var target: Vector2=w.portal_position+offset+Vector2(-15,-18)
			var start=ground+Vector2(0,-13)+w.facing*7
			var p=start.lerp(target,progress)-Vector2(0,sin(progress*PI)*23)
			g.sprite("icon_ender_eye",p-Vector2(4,4),Vector2(8,8))
	else:
		var age: float=w.stage_age
		var progress=smoothstep(0,.8,age)
		ground=w.jump_start.lerp(w.portal_position,progress)+offset
		var height=sin(clampf(age/.95,0,1)*PI)*25
		var fall=smoothstep(.85,2.1,age)
		var frame=g.world.animation.frame("steve","attack",age*.2)
		g.oval(ground,Vector2(7*(1-fall),2),Color(0,0,0,.3))
		var row=g.world.animation.direction_row(w.facing)
		var flip=-1 if row==2 and w.facing.x<0 else 1
		g.draw_set_transform(ground+Vector2(0,-height+fall*12),fall*.5,Vector2((1-fall*.96)*flip,1-fall*.97))
		g.draw_texture_rect_region(g.textures.steve_atlas,Rect2(-16,-29,32,32),Rect2(frame*32,row*32,32,32),Color(1,1,1,1-fall))
		g.draw_set_transform(Vector2.ZERO)
	return true

func foreground(g, offset: Vector2):
	var w=g.world
	if w.player_wither>0:
		for j in range(5):
			var t=fposmod(w.clock*.7+j*.217,1)
			var p: Vector2=w.player+offset+Vector2(sin(j*2.4+w.clock)*8,-5-t*20)
			g.draw_rect(Rect2(p.floor(),Vector2(2,2)),Color(.14,.12,.15,(1-t)*.7))
	if w.player_burn>0:g.draw_clip("fire_animation",w.player+offset-Vector2(10,21),Vector2(20,24),w.clock,Color(1,1,1,.6))
	for m in w.mobs:
		var p: Vector2=m.p+offset
		if w.neutral(m):g.sprite("icon_gold_boots",p-Vector2(4,37),Vector2(8,8))
		if m.fire_aspect:g.draw_clip("fire_animation",p+Vector2(-11,-19),Vector2(8,10),w.clock,Color(1,1,1,.8))
		if m.kind=="brute":
			g.draw_rect(Rect2(p+Vector2(-17,-36),Vector2(34,3)),Color("333333"))
			g.draw_rect(Rect2(p+Vector2(-17,-36),Vector2(34*maxf(0,m.hp)/m.max_hp,3)),Color("aaaaaa"))
	if w.stage=="defeat" and not w.defeated_boss.is_empty():
		var p: Vector2=w.defeated_boss.p+offset
		g.draw_actor("wither",p,w.defeated_boss.visual_dir,0,false,Color(1,1,1,1-smoothstep(1.6,2.7,w.stage_age)),"death",1,{"state":"death","time":w.stage_age/2.8*1.6})
		for j in range(15):
			var phase=fposmod(w.stage_age*.7+j*.11,1)
			var q=p+Vector2.from_angle(j*2.4)*phase*60-Vector2(0,phase*45)
			g.draw_clip("soul_fire_animation",q-Vector2(4,12),Vector2(8,16),w.clock+j*.1,Color(1,1,1,(1-phase)*.8))
	if w.stage in ["departure","arrival","lighting","jump","defeat"]:
		var bars=16.0
		if w.stage=="arrival":bars*=1-smoothstep(w.INTRO_DURATION-1,w.INTRO_DURATION,w.stage_age)
		g.draw_rect(Rect2(0,0,640,bars),Color.BLACK)
		g.draw_rect(Rect2(0,360-bars,640,bars),Color.BLACK)
	if w.stage=="departure":g.draw_rect(Rect2(0,0,640,360),Color(0,0,0,smoothstep(.3,1.55,w.stage_age)))
	elif w.stage=="arrival":g.draw_rect(Rect2(0,0,640,360),Color(0,0,0,1-smoothstep(0,1,w.stage_age)))
	elif w.stage=="jump":g.draw_rect(Rect2(0,0,640,360),Color(0,0,0,smoothstep(2,3,w.stage_age)))
	if w.stage=="arrival":intro.title(g)

func projectile(g, b: Dictionary, offset: Vector2) -> bool:
	if b.kind not in ["hoe","hook","rocket","bolt","enemy_flame","wither_skull"]:return false
	var p: Vector2=b.p+offset-Vector2(0,9)
	if b.kind=="enemy_flame":g.draw_clip("fire_animation",p-Vector2(7,9),Vector2(14,18),b.age)
	elif b.kind=="wither_skull":
		for j in range(5):
			var q=p-b.dir*(6+j*5)+b.dir.orthogonal()*sin(b.age*12+j)*2
			g.draw_rect(Rect2(q.floor(),Vector2.ONE*(4-j*.5)),Color(.12,.26 if b.evolved else .12,.3 if b.evolved else .16,.7-j*.12))
		g.sprite("wither_skull",p-Vector2(9,9),Vector2(18,18),Color(.65,1.2,1.4) if b.evolved else Color.WHITE)
	elif b.kind=="hook":
		g.draw_line(g.world.player+offset-Vector2(0,10),p,Color("dedede"),1)
		g.draw_arc(p,3,0,PI*1.6,8,Color("cccccc"),1)
	else:
		g.draw_set_transform(p,b.age*15 if b.kind=="hoe" else b.dir.angle()+PI/4)
		if b.kind=="hoe":g.item_icon("hoe",Vector2(-8,-8))
		else:g.sprite("icon_firework" if b.kind=="rocket" else "icon_arrow",Vector2(-8,-8),Vector2(16,16))
		g.draw_set_transform(Vector2.ZERO)
		if b.kind=="rocket":g.draw_clip("fire_animation",p-b.dir*10-Vector2(4,4),Vector2(8,8),b.age)
	return true

func effect(g, e: Dictionary, offset: Vector2) -> bool:
	var p: Vector2=e.p+offset
	match e.kind:
		"tnt_split":
			for j in range(9):
				var q=p-Vector2(0,e.height)+Vector2.from_angle(j*TAU/9)*e.age*55
				g.draw_rect(Rect2(q.floor(),Vector2(2,2)),Color(1,.65,.25,1-e.age/e.total))
		"axe_spin":
			var returning=e.age>=.3
			var t=clampf((e.age-(.3 if returning else 0))/.3,0,1)
			var angle: float=e.direction.angle()+lerpf(2.1,-2.1,t) if returning else e.direction.angle()+lerpf(-2.1,2.1,t)
			# Grip stays in Steve's palm, including when he moves during the sweep.
			var hand: Vector2=g.world.player+offset+Vector2(-5 if g.world.facing.x<0 else 5,-14)
			if g.is_end():hand.y-=g.world.elevation()
			for j in range(3,0,-1):
				g.draw_set_transform(hand,angle-j*.19*( -1 if returning else 1)+PI/4)
				g.sprite("icon_"+g.world.db.equipment_icon("axe",g.world.build.get("axe",1)),Vector2(-4.5,-12),Vector2(16,16),Color(1,1,1,.12-j*.025))
			g.draw_set_transform(hand,angle+PI/4)
			g.item_icon("axe",Vector2(-4.5,-12),1,g.world.evolved.has("axe"));g.draw_set_transform(Vector2.ZERO)
		"hoe_spin":
			for j in range(4):
				var angle: float=e.age*18-j*.25
				var pos=p-Vector2(0,8)+Vector2.from_angle(angle)*e.radius*.65
				g.draw_set_transform(pos,angle+PI/4)
				var id="hoe"
				if j==0:g.item_icon(id,Vector2(-8,-8),1,g.world.evolved.has(id))
				else:g.sprite("icon_"+g.world.db.equipment_icon(id,g.world.build.get(id,1)),Vector2(-8,-8),Vector2(16,16),Color(1,1,1,.14-j*.025))
				g.draw_set_transform(Vector2.ZERO)
		"foot_block":g.sprite("foot_block",p+e.direction*9-Vector2(8,7),Vector2(16,16))
		"fishing_line":g.draw_line(p+Vector2(0,-9),e.end+offset+Vector2(0,-9),Color(1,1,1,e.life/e.total),1)
		"wither_impact","soul_eruption","wither_roar":
			var progress=clampf(e.age/e.total,0,1)
			var eruption=e.kind=="soul_eruption"
			var radius: float=e.get("radius",35.0)
			for j in range(8 if eruption else 6):
				var dir=Vector2.from_angle(j*2.399)
				var q=p+dir*radius*progress-Vector2(0,sin(progress*PI)*(35 if eruption else 12))
				g.draw_clip("soul_fire_animation",q-Vector2(6,18),Vector2(16 if eruption else 12,45 if eruption else 20),e.age+j*.06,Color(1,1,1,1-progress))
			if eruption:g.draw_clip("soul_fire_animation",p-Vector2(22,88*(1-progress*.35)),Vector2(44,94*(1-progress*.35)),e.age,Color(1,1,1,1-progress))
		_:return false
	return true

func hud(g):
	for m in g.world.mobs:
		if m.kind!="wither" or m.hp<=0:continue
		g.centered("Иссушитель",41,8,Color.WHITE,true)
		g.draw_rect(Rect2(191,46,258,6),Color("333333"))
		g.draw_rect(Rect2(192,47,256*clampf(m.hp/m.max_hp,0,1),4),Color("9b739a"))

func ending(g, controls: bool = true):
	g.draw_rect(Rect2(0,0,640,360),Color("0c0910"))
	g.draw_texture_rect(g.textures.end_ground,Rect2(0,188,640,172),true,Color(.7,.7,.6))
	for x in [55,140,487,575]:g.draw_texture_rect(g.textures.portal_frame,Rect2(x,96+(x%7)*5,23,96),true,Color(.35,.35,.4))
	var landing=0.0 if controls else 1-smoothstep(0,.85,g.world.stage_age)
	g.draw_actor("steve",Vector2(320,234-landing*80),Vector2.UP,0,false,Color.WHITE,"idle",1.5,{"state":"idle","time":0.0})
	if not controls:
		g.draw_rect(Rect2(0,0,640,360),Color(0,0,0,1-smoothstep(0,.8,g.world.stage_age)))
		return
	g.centered("Край",105,32,Color.WHITE,true)
	g.centered("Глава II завершена",145,8,Color("aaaaaa"))
	g.button(Rect2(199,239,242,27),"Глава III · Край","chapter_3")
	g.button(Rect2(199,271,242,27),"Ещё раз","retry")
	g.button(Rect2(199,310,242,27),"В меню","menu")
