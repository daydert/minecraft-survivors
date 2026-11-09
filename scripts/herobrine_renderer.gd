extends RefCounted
var legacy=preload("res://scripts/legacy_finale_renderer.gd").new()
var remains_view

func stage(g, offset: Vector2):
	var w=g.world;var f=w.finale;var p: Vector2=f.CENTER+offset
	var alpha=smoothstep(.3,1.5,f.elapsed)
	var darkness=1-smoothstep(.3,1.8,f.phase_age) if f.phase=="vanish" else 0.0 if f.phase in ["portal","fall","end"] else 1.0
	g.oval(p+Vector2(0,5),Vector2(86,19),Color(0,0,0,.55*alpha))
	g.sprite("duel_throne",p-Vector2(96,150),Vector2.ZERO,Color(1,1,1,alpha))
	for socket in g.chapter_assets.throne.fire_sockets:
		var q: Vector2=p-Vector2(96,150)+Vector2(socket[0],socket[1])
		g.draw_clip("fire_animation",q-Vector2(9,25),Vector2(18,29),w.clock,Color(1,1,1,alpha*(.2+.8*darkness)))
	var name="duel_seated";var t=w.clock;var looping=true;var forward=0.0
	if f.phase=="rising":name="duel_rise";t=f.phase_age/3.2*2.6;looping=false;forward=smoothstep(0,3.2,f.phase_age)*13
	elif (f.cinematic_player() and f.first_stage_won) or f.phase=="end":
		name="duel_stand";forward=13
		if f.phase in ["summon","kneel","rift"]:name="duel_command";t=1.15 if f.phase!="summon" else f.phase_age;looping=false
	var tint=Color(1.8,1.8,1.8,alpha*darkness) if g.settings.flashes and f.boss.get("flash",0)>.01 else Color(1,1,1,alpha*darkness)
	g.draw_clip(name,p+Vector2(0,forward)-Vector2(40,104),Vector2(80,112),t,tint,looping)

func floor_effects(g, offset: Vector2):
	var f=g.world.finale
	for s in f.strikes:
		var p: Vector2=s.p+offset
		if not g.world.visible(s.p,60):continue
		if s.age<.85:
			g.draw_arc(p,20,0,TAU,24,Color(1,.4,.2,.65),1)
		else:g.oval(p,Vector2(18,6),Color(.04,.025,.02,.7))
	for wave in f.waves:
		var count=maxi(20,int(TAU*wave.radius/12))
		for i in range(count):
			var angle=i*TAU/count
			if not f.wave_active(angle,wave):continue
			var p: Vector2=f.CENTER+Vector2.from_angle(angle)*wave.radius+offset
			if not Rect2(-30,-35,700,430).has_point(p):continue
			g.draw_clip("fire_animation",p-Vector2(9,25),Vector2(18,29),g.world.clock+i*.021,Color(1,1,1,.92))
	if f.phase in ["portal","fall"]:
		var p: Vector2=g.world.player+offset
		var opening=smoothstep(0,1.6,f.phase_age) if f.phase=="portal" else 1.0
		g.draw_texture_rect(g.textures.portal_frame,Rect2(p-Vector2(42,18)*opening,Vector2(84,36)*opening),true)
		g.draw_clip("nether_portal",p-Vector2(35,12)*opening,Vector2(70,24)*opening,g.world.clock)

func player(g, p: Vector2):
	var f=g.world.finale
	match f.phase:
		"rising","summon":
			var alpha=1.0
			if f.phase=="summon":alpha=smoothstep(.45,.85,f.phase_age) if f.teleported else 1-smoothstep(.05,.4,f.phase_age)
			g.draw_actor("steve",p,g.world.facing,0,false,Color(1,1,1,alpha),"idle",1,{"state":"idle","time":0.0})
		"kneel":g.draw_clip("duel_kneel",p-Vector2(20,43),Vector2(40,48),f.phase_age,Color.WHITE,false)
		"rift":
			var strength=smoothstep(.1,2.8,f.phase_age)
			var compression=1-.68*smoothstep(1.1,3.8,f.phase_age)
			var frame=g.clip_frame("duel_kneel",2,false)
			for i in range(20):
				var shift=sin(g.world.clock*6+i*.7)*strength*7
				var q=p+Vector2((i*2-20)*compression+shift,-43*(.35+.65*compression))
				g.draw_texture_rect_region(g.textures.duel_kneel,Rect2(q,Vector2(2*compression,48*(.35+.65*compression))),Rect2(frame*40+i*2,0,2,48),Color(1,1-strength*.45,1-strength*.4))
		"vanish":pass

func fallen_player(g, p: Vector2):
	var f=g.world.finale
	if f.first_stage_won:return
	var fall=f.fall_progress();var frame=g.world.animation.frame("steve","hurt",.04)
	g.draw_set_transform(p+Vector2(0,-6+fall*30),PI/2+fall*1.5,Vector2.ONE*maxf(.02,1-fall))
	g.draw_texture_rect_region(g.textures.steve_atlas,Rect2(-16,-16,32,32),Rect2(frame*32,0,32,32),Color(1,.72,.72,1-fall*.8))
	g.draw_set_transform(Vector2.ZERO)

func foreground(g, offset: Vector2):
	var w=g.world;var f=w.finale
	if f.first_stage_won and f.phase in ["vanish","portal","fall"]:
		if not is_instance_valid(remains_view):
			remains_view=preload("res://scripts/herobrine_remains_view.gd").new()
			remains_view.game=g
			g.add_child(remains_view)
		remains_view.refresh()
	for s in f.strikes:
		if s.age<.85 or s.age>1.15:continue
		var p: Vector2=s.p+offset
		if not w.visible(s.p,60):continue
		var alpha=clampf((1.15-s.age)/.2,0,1)*(.9 if g.settings.flashes else .35)
		g.draw_polyline(PackedVector2Array([p-Vector2(0,320),p+Vector2(-9,-200),p+Vector2(7,-110),p+Vector2(-5,-40),p]),Color(.8,.8,1,alpha),2)
	if f.phase in ["storm","inferno"]:
		g.centered("Херобрин",41,8,Color.WHITE,true)
		g.draw_rect(Rect2(211,46,218,5),Color("33151b"))
		g.draw_rect(Rect2(212,47,216*clampf(f.boss.hp/f.boss.max_hp,0,1),3),Color("a94550"))
	if f.phase=="summon":
		var alpha=sin(clampf(f.phase_age/1.2,0,1)*PI)
		for i in range(38):
			var t=fposmod(i*.173+f.phase_age*1.3,1)
			var p: Vector2=f.teleport_from.lerp(f.KNEEL_AT,t)+offset+Vector2(sin(i*2.4)*13,-sin(t*PI)*30-i%4*2)
			g.draw_rect(Rect2(p.floor(),Vector2(2,2)),Color(.6,.35,.8,alpha*.8))
	if f.phase in ["rift","vanish"]:
		var p: Vector2=w.player+offset-Vector2(0,8)
		var progress=f.blood_progress() if f.phase=="rift" else 1-smoothstep(0,1.7,f.phase_age)
		g.oval(p,Vector2(48,22)*progress,Color(.035,0,.009,.92))
		for i in range(100):
			var t=fposmod(w.clock*.8+i*.113,1)
			var angle=i*2.399+t*6
			var radius=(1-t)*82*progress
			var q=p+Vector2(cos(angle)*radius,sin(angle)*radius*.55)
			g.draw_rect(Rect2(q.floor(),Vector2(1+i%3,1+i%2)),Color(.35+i%4*.08,.005,.025,(1-t)*progress))
	if f.cinematic_player() or f.phase=="arrival":
		g.draw_rect(Rect2(0,0,640,16),Color.BLACK);g.draw_rect(Rect2(0,344,640,16),Color.BLACK)
	if f.phase=="arrival":g.draw_rect(Rect2(0,0,640,360),Color(0,0,0,1-smoothstep(0,.7,f.phase_age)))
	if f.phase=="defeated":
		g.draw_rect(Rect2(0,0,640,360),Color(0,0,0,smoothstep(0,1.2,f.phase_age)*.94))
		fallen_player(g,w.player+offset)
	if f.phase in ["portal","fall"]:
		g.draw_rect(Rect2(0,0,640,360),Color(0,0,0,.94))
		# Keep the portal readable after the room has disappeared into darkness.
		var p: Vector2=w.player+offset
		var opening=smoothstep(0,1.6,f.phase_age) if f.phase=="portal" else 1.0
		g.draw_clip("nether_portal",p-Vector2(35,12)*opening,Vector2(70,24)*opening,w.clock)
		# Darken the room, then draw Steve above it until the Nether fades in.
		fallen_player(g,p)
		if f.phase=="fall":legacy.nether(g,smoothstep(1.2,3.8,f.phase_age))

func ending(g):legacy.ending(g)
