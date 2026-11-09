extends RefCounted
## Drawing is performed on the production CanvasItem during its _draw callback.

func stage(g,offset:Vector2):
	var w=g.world
	var f=w.finale
	var meta:Dictionary=g.chapter_assets.throne
	var p:Vector2=f.CENTER+offset
	var origin=p-Vector2(meta.pivot[0],meta.pivot[1])
	var alpha=clampf((f.elapsed-.4)/1.2,0,1)
	g.oval(p+Vector2(0,5),Vector2(86,19),Color(0,0,0,.55*alpha))
	g.sprite("herobrine_throne",origin.floor(),Vector2.ZERO,Color(1,1,1,alpha))
	for socket in meta.fire_sockets:
		var q=origin+Vector2(socket[0],socket[1])
		g.draw_clip("fire_animation",q-Vector2(9,25),Vector2(18,29),w.clock,Color(1,1,1,alpha))
		g.oval(q+Vector2(0,1),Vector2(13,4),Color(1,.3,.04,.16*alpha))

func floor_effects(g,offset:Vector2):
	var f=g.world.finale
	for s in f.strikes:
		var p:Vector2=s.p+offset
		if not Rect2(-50,-50,740,460).has_point(p):continue
		if s.age<.7:
			var size=25*(.4+.6*s.age/.7)
			g.draw_arc(p,size,0,TAU,28,Color(1,.4,.18,.8),1)
			g.draw_line(p-Vector2(5,0),p+Vector2(5,0),Color(1,.8,.6,.6),1)
			g.draw_line(p-Vector2(0,5),p+Vector2(0,5),Color(1,.8,.6,.6),1)
		else:
			g.oval(p,Vector2(23,7),Color(.04,.025,.02,.85))
	for wave in f.waves:
		var count=maxi(20,int(TAU*wave.radius/13))
		for i in range(count):
			var angle=i*TAU/count
			var p:Vector2=f.CENTER+Vector2.from_angle(angle)*wave.radius+offset
			if not Rect2(-30,-35,700,430).has_point(p):continue
			g.oval(p,Vector2(12,5),Color(.9,.18,.02,.3))
			g.draw_clip("fire_animation",p-Vector2(10,29),Vector2(20,34),g.world.clock+i*.021,Color(1,1,1,.92))
	if f.elapsed>=26 and f.elapsed<34:
		var p:Vector2=g.world.player+offset
		var opening=smoothstep(26,28,f.elapsed)
		var size=Vector2(70,24)*opening
		g.oval(p+Vector2(0,2),Vector2(42,16)*opening,Color("12051d"))
		g.draw_texture_rect(g.textures.portal_frame,Rect2(p-Vector2(42,18)*opening,Vector2(84,36)*opening),true)
		g.draw_clip("nether_portal",p-size/2,size,g.world.clock)
		for i in range(12):
			var phase=fposmod(f.elapsed*.9+i*.13,1)
			var q=p+Vector2(cos(i*2.4)*35*phase,-sin(i*2.4)*10-22*phase)
			g.draw_rect(Rect2(q.floor(),Vector2(2,2)),Color(.7,.3,1,1-phase))

func player(g,p:Vector2):
	var f=g.world.finale
	var fall=f.fall_progress()
	var angle=PI/2 if f.elapsed<29 else PI/2+fall*1.6
	var origin=p+Vector2(0,fall*36-7)
	g.draw_set_transform(origin,angle,Vector2.ONE*maxf(.02,1-fall))
	var frame=g.world.animation.frame("steve","hurt",.04)
	g.draw_texture_rect_region(g.textures.steve_atlas,Rect2(-16,-16,32,32),Rect2(frame*32,0,32,32),Color(1,1,1,1-fall*.8))
	g.draw_set_transform(Vector2.ZERO)

func foreground(g,offset:Vector2):
	var f=g.world.finale
	for s in f.strikes:
		if s.age<.7 or s.age>1:continue
		var p:Vector2=s.p+offset
		if not Rect2(-50,-50,740,460).has_point(p):continue
		var alpha=clampf((1-s.age)/.18,0,1)*(1 if g.settings.flashes else .4)
		var points=PackedVector2Array([p-Vector2(0,320),p+Vector2(-15,-250),p+Vector2(9,-190),p+Vector2(-12,-125),p+Vector2(7,-62),p])
		g.draw_polyline(points,Color(.45,.35,.9,.35*alpha),9)
		g.draw_polyline(points,Color(.85,.8,1,alpha),3)
		g.draw_polyline(points,Color(1,1,1,alpha),1)
		g.draw_arc(p,26,0,TAU,24,Color(1,.7,.45,alpha),2)
	if f.elapsed>=4 and f.elapsed<29:
		g.draw_rect(Rect2(0,0,640,360),Color(.03,0,.04,f.scorch()*.23))
		for i in range(56):
			var x=fposmod(i*83.71+f.elapsed*(9+i%9),660)-10
			var y=fposmod(i*47.33-f.elapsed*(12+i%13),390)-15
			g.draw_rect(Rect2(Vector2(x,y).floor(),Vector2.ONE*(1+i%2)),Color(.7,.66,.64,.3*f.scorch()))
	if f.elapsed<4:
		g.draw_rect(Rect2(0,0,640,16),Color.BLACK)
		g.draw_rect(Rect2(0,344,640,16),Color.BLACK)
		if f.elapsed>1.5:g.centered("Херобрин",330,16,Color.WHITE,true)
		var fade=1-smoothstep(0,.5,f.elapsed)
		if fade>0:g.draw_rect(Rect2(0,0,640,360),Color(0,0,0,fade))
	elif f.elapsed<24:
		g.centered("Херобрин",54,8,Color.WHITE,true)
		g.draw_rect(Rect2(229,59,182,4),Color("77141b"))
	if f.elapsed>=24 and f.elapsed<26:
		for i in range(17):
			var height=90+sin(i*2.4+g.world.clock*2)*22
			g.draw_clip("fire_animation",Vector2(i*40,360-height),Vector2(45,height+12),g.world.clock+i*.04,Color(1,1,1,.8))
	if f.elapsed>=29:
		var fade=smoothstep(30.3,33,f.elapsed)
		nether(g,fade)

func nether(g,alpha:float=1):
	g.draw_rect(Rect2(0,0,640,360),Color(0,0,0,alpha))
	g.draw_texture_rect(g.textures.nether_backdrop,Rect2(0,0,640,360),true,Color(.35,.17,.16,.7*alpha))
	g.draw_rect(Rect2(0,0,640,360),Color(.08,0,0,.45*alpha))
	for i in range(17):
		g.draw_clip("fire_animation",Vector2(i*40,300+sin(i)*10),Vector2(45,74),g.item_time()+i*.04,Color(1,.65,.4,.35*alpha))

func ending(g):
	nether(g)
	g.centered("Глава I завершена",114,16,Color.WHITE,true)
	g.centered("Незер",172,32,Color.WHITE,true)
	if g.coop.active:g.centered("Продолжение следует",201,8,Color("aaaaaa"))
	if not g.coop.active:g.button(Rect2(199,244,242,27),"Продолжить","chapter_2")
	elif g.coop.hosting:g.button(Rect2(199,244,242,27),"Начать заново","retry")
	g.button(Rect2(199,281,242,27),"В меню","menu")
