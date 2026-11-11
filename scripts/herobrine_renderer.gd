extends RefCounted
var legacy=preload("res://scripts/legacy_finale_renderer.gd").new()
const ChapterOne=preload("res://scripts/chapter_one_view.gd")
var remains_view

func stage(g, offset: Vector2):
	var w=g.world;var f=w.finale;var p: Vector2=f.CENTER+offset
	var built: float=f.throne_built()
	if built<=0.0:return
	var origin: Vector2=p-Vector2(96,150)
	g.oval(p+Vector2(0,5),Vector2(86,19)*minf(1,built*1.3),Color(0,0,0,.55*minf(1,built*2)))
	var tex: Texture2D=g.textures.get("duel_throne")
	if tex!=null:
		var size: Vector2=tex.get_size()
		# Rebuilt from the ground up, a few rows of blocks at a time.
		var shown: float=floorf(size.y*built/6.0)*6.0 if built<1.0 else size.y
		g.draw_texture_rect_region(tex,Rect2(origin+Vector2(0,size.y-shown),Vector2(size.x,shown)),Rect2(0,size.y-shown,size.x,shown))
		if built<1.0:build_blocks(g,origin,size,built,w.clock)
	var lit: float=1.0 if f.phase!="throne" else smoothstep(f.THRONE_BUILD[1],f.THRONE_BUILD[1]+.4,f.phase_age)
	var darkness=1-smoothstep(.3,1.8,f.phase_age) if f.phase=="vanish" else 0.0 if f.phase in ["portal","fall","end"] else 1.0
	for socket in g.chapter_assets.throne.fire_sockets:
		var q: Vector2=origin+Vector2(socket[0],socket[1])
		if lit>0:g.draw_clip("fire_animation",q-Vector2(9,25),Vector2(18,29),w.clock,Color(1,1,1,lit*(.2+.8*darkness)))
	if not f.giant_visible():return
	var name="duel_seated";var t=w.clock;var looping=true;var forward=0.0
	var alpha: float=1.0
	if f.phase=="throne":alpha=smoothstep(f.THRONE_SEAT,f.THRONE_SEAT+.35,f.phase_age)
	if f.phase=="showtime":alpha=1-smoothstep(.15,.45,f.phase_age)
	if f.phase=="descend" and f.phase_age<.4:alpha=1-smoothstep(.1,.4,f.phase_age);name="duel_stand";forward=13
	elif f.phase=="descend":alpha=smoothstep(f.WHISPER[1]+.25,f.WHISPER[1]+.6,f.phase_age);name="duel_stand";forward=13
	elif f.phase=="rising":name="duel_rise";t=f.phase_age/3.2*2.6;looping=false;forward=smoothstep(0,3.2,f.phase_age)*13
	elif (f.cinematic_player() and f.first_stage_won) or f.phase=="end":
		name="duel_stand";forward=13
		if f.phase in ["summon","kneel","rift"]:name="duel_command";t=1.15 if f.phase!="summon" else f.phase_age;looping=false
	elif not f.villager.is_empty() and f.villager.age<3.6:
		name="duel_command";t=minf(f.villager.age,1.15);looping=false
	var tint=Color(1.8,1.8,1.8,alpha*darkness) if g.settings.flashes and f.boss.get("flash",0)>.01 else Color(1,1,1,alpha*darkness)
	g.draw_clip(name,p+Vector2(0,forward)-Vector2(40,104),Vector2(80,112),t,tint,looping)

## Blocks fly in from the field and settle on the rising throne.
func build_blocks(g, origin: Vector2, size: Vector2, built: float, clock: float):
	var top: float=origin.y+size.y*(1-built)
	for i in range(28):
		var t: float=fposmod(ChapterOne.h(i,11)+clock*1.6,1.0)
		var from: Vector2=origin+size*Vector2(.5,.9)+Vector2.from_angle(ChapterOne.h(i,12)*TAU)*(150+ChapterOne.h(i,13)*90)
		var to: Vector2=Vector2(origin.x+20+ChapterOne.h(i,14)*(size.x-40),top+4)
		var q: Vector2=from.lerp(to,t*t)-Vector2(0,sin(t*PI)*40)
		var c: Color=Color(.42,.42,.44) if i%3 else Color(.28,.22,.24)
		g.draw_rect(Rect2(q.floor(),Vector2(4,4)),Color(c,.9*(1-t*.3)))
		g.draw_rect(Rect2(q.floor(),Vector2(4,4)),Color(0,0,0,.35),false,1)

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

## Herobrine at his own size: greeting, playing, and the punch.
func small_herobrine(g, offset: Vector2):
	var f=g.world.finale
	var p: Vector2=f.hb_p+offset
	var sheet: String="ch1_hb_"+f.hb_face
	for ghost in f.ghosts:
		ChapterOne.figure(g,sheet,"herobrine",ghost.pose,0.0,ghost.p+offset,ghost.dir,1.0,Color(.05,.05,.08,.45*(1-ghost.age/.35)))
	var alpha: float=1.0
	if f.phase=="arrival":alpha=smoothstep(1.6,2.0,f.phase_age)
	g.oval(p+Vector2(0,1),Vector2(9,3),Color(0,0,0,.45*alpha))
	var loop: bool=f.hb_pose in ["idle","walk","stroll","wave","laugh","shrug","twist","lift","donut_hold","aura","invite"]
	var tint=Color(1.7,1.7,1.7,alpha) if f.boss.get("flash",0)>.01 and g.settings.flashes else Color(1,1,1,alpha)
	ChapterOne.figure(g,sheet,"herobrine",f.hb_pose,f.hb_pose_age,p,f.hb_dir,1.0,tint,loop)

## A villager hauled out of the ground and wrung until he is a creeper.
func villager(g, offset: Vector2):
	var f=g.world.finale;var v: Dictionary=f.villager
	if v.is_empty():return
	var a: float=v.age;var p: Vector2=v.p+offset
	var data: Dictionary=ChapterOne.assets(g).twist
	var frame: int
	var lift: float
	if a<1.0:frame=int(a*8)%4;lift=14.0*smoothstep(0,1.0,a)
	elif a<3.2:frame=4+mini(8,int((a-1.0)/2.2*9));lift=14.0+sin(a*9)*1.5
	else:frame=13+mini(4,int((a-3.2)/.8*5));lift=14.0*(1-smoothstep(3.6,4.1,a))
	var hand: Vector2=f.BOSS_AT+offset+Vector2(-10 if v.p.x<f.CENTER.x else 10,-62)
	var tether: float=1-smoothstep(3.2,3.6,a)
	if tether>0:
		for i in range(14):
			var t: float=i/13.0
			var q: Vector2=hand.lerp(p-Vector2(0,lift+36),t)+Vector2(sin(g.world.clock*9+i)*2*(1-absf(t-.5)*2),0)
			g.draw_rect(Rect2(q.floor(),Vector2(2,2)),Color(.75,.75,.85,.5*tether))
	if a<1.0:
		for i in range(10):
			var d: Vector2=Vector2.from_angle(i*.63)*(6+a*16)
			g.draw_rect(Rect2((p+d*Vector2(1,.4)-Vector2(0,a*10*ChapterOne.h(i,20))).floor(),Vector2(2,2)),Color(.35,.25,.15,1-a))
	g.oval(p+Vector2(0,1),Vector2(10,3)*(1-lift/40),Color(0,0,0,.4))
	var size=Vector2(data.frame[0],data.frame[1]);var anchor=Vector2(data.anchor[0],data.anchor[1])
	if g.textures.has("ch1_villager_twist"):
		var shake: Vector2=Vector2(sin(g.world.clock*40),0).round() if a>1.0 and a<3.2 else Vector2.ZERO
		# Shown larger: he holds it up for Steve to see.
		g.draw_texture_rect_region(g.textures.ch1_villager_twist,Rect2((p-anchor*1.5-Vector2(0,lift)+shake).floor(),size*1.5),Rect2(frame*size.x,0,size.x,size.y))
	if a>2.2 and a<3.4:
		for i in range(6):
			var t: float=fposmod(g.world.clock*2+i*.17,1.0)
			g.draw_rect(Rect2((p+Vector2(-6+i*2,-lift-20+t*26)).floor(),Vector2(1,2)),Color(.55,.02,.04,1-t))

func crawler(g, m: Dictionary, offset: Vector2):
	var data: Dictionary=ChapterOne.assets(g).crawler
	if not g.textures.has("ch1_crawler"):return
	var p: Vector2=m.p+offset
	var size=Vector2(data.frame[0],data.frame[1]);var anchor=Vector2(data.anchor[0],data.anchor[1])
	var row: int=ChapterOne.row_of(m.visual_dir)
	var frame: int=int(m.animation*8)%int(data.count) if m.moving else 0
	var flip: bool=m.visual_dir.x<0 and row==2
	g.oval(p+Vector2(0,1),Vector2(12,3),Color(0,0,0,.4))
	var tint=Color(1.8,1.8,1.8) if m.flash>0 and g.settings.flashes else Color.WHITE
	g.draw_set_transform(p.floor(),0,Vector2(-1 if flip else 1,1))
	g.draw_texture_rect_region(g.textures.ch1_crawler,Rect2(-anchor,size),Rect2(frame*size.x,row*size.y,size.x,size.y),tint)
	g.draw_set_transform(Vector2.ZERO)
	if m.moving and int(m.animation*3)%2==0:g.draw_rect(Rect2((p+Vector2(-1,2)).floor(),Vector2(2,1)),Color(.45,.02,.04,.7))

func player(g, p: Vector2):
	var f=g.world.finale
	match f.phase:
		"greet","throne":
			g.draw_actor("steve",p,Vector2.UP,0,false,Color.WHITE,"idle",1,{"state":"idle","time":0.0})
		"showtime":
			var a: float=f.phase_age
			if a<f.SHOW_PUNCH:
				ChapterOne.figure(g,"ch1_steve","steve","sag",minf(a,.2),p,Vector2.DOWN,1.0,Color.WHITE,false)
			elif a<6.3:
				ChapterOne.figure(g,"ch1_steve_holed","steve","pierced",a-f.SHOW_PUNCH,p,Vector2.DOWN,1.0,Color.WHITE,false)
				fist(g,p+Vector2(-1,-17),a-f.SHOW_PUNCH)
			else:
				ChapterOne.figure(g,"ch1_steve_holed","steve","pierced",1.0,p+Vector2(0,round(sin(a*20)*.4)),Vector2.DOWN,1.0,Color(1,.85,.85),false)
				hole_drip(g,p+Vector2(-1,-17),a-6.3)
		"descend":
			var a: float=f.phase_age
			var turn: float=f.DESCEND_PARRY-.35
			if a<turn:ChapterOne.figure(g,"ch1_steve","steve","idle",a,p,Vector2.DOWN)
			elif a<turn+1.4:ChapterOne.figure(g,"ch1_steve","steve","parry",a-turn,p,Vector2.UP,1.0,Color.WHITE,false)
			else:ChapterOne.figure(g,"ch1_steve","steve","guard",0.0,p,Vector2.UP)
		"rising":
			g.draw_actor("steve",p,Vector2.UP,0,false,Color.WHITE,"idle",1,{"state":"idle","time":0.0})
		"summon":
			var alpha=smoothstep(.45,.85,f.phase_age) if f.teleported else 1-smoothstep(.05,.4,f.phase_age)
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

## Herobrine's fist, out through the front of Steve's chest.
func fist(g, at: Vector2, t: float):
	var out: float=minf(1.0,t/.08)*5.0
	var q: Vector2=at+Vector2(0,out*.4)
	g.draw_rect(Rect2((q-Vector2(2.5,2.5)).floor(),Vector2(5,5)),Color(.48,.33,.25))
	g.draw_rect(Rect2((q-Vector2(2.5,2.5)).floor(),Vector2(5,5)),Color(.2,.12,.08),false,1)
	g.draw_rect(Rect2((q+Vector2(-2,-1)).floor(),Vector2(4,1)),Color(.62,.45,.34))
	g.draw_rect(Rect2((q+Vector2(-2,1)).floor(),Vector2(5,2)),Color(.5,.03,.05,.9))
	hole_drip(g,at,t)

func hole_drip(g, at: Vector2, t: float):
	for i in range(4):
		var k: float=fposmod(t*1.2+i*.27,1.0)
		g.draw_rect(Rect2((at+Vector2(-2+i*1.4,2+k*14)).floor(),Vector2(1,2)),Color(.5,.02,.04,1-k))

func fallen_player(g, p: Vector2):
	var f=g.world.finale
	if f.first_stage_won:return
	var fall=f.fall_progress();var frame=g.world.animation.frame("steve","hurt",.04)
	g.draw_set_transform(p+Vector2(0,-6+fall*30),PI/2+fall*1.5,Vector2.ONE*maxf(.02,1-fall))
	g.draw_texture_rect_region(g.textures.steve_atlas,Rect2(-16,-16,32,32),Rect2(frame*32,0,32,32),Color(1,.72,.72,1-fall*.8))
	g.draw_set_transform(Vector2.ZERO)

func warp(g, offset: Vector2, from: Vector2, to: Vector2, k: float):
	var alpha=sin(clampf(k,0,1)*PI)
	if alpha<=0:return
	for i in range(30):
		var t=fposmod(i*.173+k*1.3,1)
		var p: Vector2=from.lerp(to,t)+offset+Vector2(sin(i*2.4)*11,-sin(t*PI)*26-i%4*2-12)
		g.draw_rect(Rect2(p.floor(),Vector2(2,2)),Color(.6,.35,.8,alpha*.8))

## Close on the two of them for the punch and for the deflection.
const CLOSE:=3.0
func close_weight(f) -> float:
	var a: float=f.phase_age
	if f.phase=="showtime":return smoothstep(.7,1.0,a)*(1-smoothstep(f.SHOW_LENGTH-.5,f.SHOW_LENGTH-.1,a))
	if f.phase=="descend":return smoothstep(.5,.8,a)*(1-smoothstep(f.WHISPER[0]+.2,f.WHISPER[0]+.6,a))
	return 0.0

func closeup(g, f):
	var k: float=close_weight(f)
	if k<=0:return
	var w=g.world
	var c:=Vector2(312,262)
	var src:=Rect2(w.player-Vector2(312,262)/CLOSE,Vector2(640,360)/CLOSE)
	if g.textures.has("ground"):g.draw_texture_rect_region(g.textures.ground,Rect2(0,0,640,360),src)
	if g.textures.has("ground_scorched"):g.draw_texture_rect_region(g.textures.ground_scorched,Rect2(0,0,640,360),src,Color(1,1,1,f.scorch()))
	g.draw_rect(Rect2(0,0,640,360),Color(.02,.0,.03,.5))
	var hb: Vector2=c+(f.hb_p-w.player)*CLOSE
	if f.small_visible():
		g.oval(hb+Vector2(0,3),Vector2(27,8),Color(0,0,0,.45))
		var loop: bool=f.hb_pose in ["idle","laugh","shrug","donut_hold"]
		ChapterOne.figure(g,"ch1_hb_"+f.hb_face,"herobrine",f.hb_pose,f.hb_pose_age,hb,f.hb_dir,CLOSE,Color(.82,.8,.86),loop)
	g.oval(c+Vector2(0,3),Vector2(27,8),Color(0,0,0,.45))
	var a: float=f.phase_age
	if f.phase=="showtime":
		if a<f.SHOW_PUNCH:ChapterOne.figure(g,"ch1_steve","steve","sag",minf(a,.2),c,Vector2.DOWN,CLOSE,Color.WHITE,false)
		else:
			var shake: Vector2=Vector2(round(sin(a*30)),0) if a<6.3 else Vector2.ZERO
			ChapterOne.figure(g,"ch1_steve_holed","steve","pierced",minf(a-f.SHOW_PUNCH,1.0),c+shake,Vector2.DOWN,CLOSE,Color.WHITE,false)
			g.draw_set_transform(c+shake,0,Vector2.ONE*CLOSE)
			if a<6.3:fist(g,Vector2(-1,-17),a-f.SHOW_PUNCH)
			else:hole_drip(g,Vector2(-1,-17),a-6.3)
			g.draw_set_transform(Vector2.ZERO)
	else:
		var turn: float=f.DESCEND_PARRY-.35
		if a<turn:ChapterOne.figure(g,"ch1_steve","steve","idle",a,c,Vector2.DOWN,CLOSE)
		elif a<turn+1.4:ChapterOne.figure(g,"ch1_steve","steve","parry",a-turn,c,Vector2.UP,CLOSE,Color.WHITE,false)
		else:ChapterOne.figure(g,"ch1_steve","steve","guard",0.0,c,Vector2.UP,CLOSE)
	for p in w.particles:
		var q: Vector2=c+(p.p-w.player)*CLOSE
		g.draw_rect(Rect2(q.floor(),Vector2.ONE*ceilf(p.get("size",2.0)*2)),Color(p.color,clampf(p.life/.1,0,1)))
	lost_items(g,f,c-w.player*CLOSE,CLOSE*.7,w.player)
	for s in f.sparks:
		var q: Vector2=c+(s.p-w.player)*CLOSE
		g.draw_rect(Rect2(q.floor(),Vector2(5,2)),Color(1,.92,.6,1-s.age/.5))
	if f.phase=="showtime" and a>=f.SHOW_PUNCH and a<f.SHOW_PUNCH+.12:g.draw_rect(Rect2(0,0,640,360),Color(.6,0,.02,.35 if g.settings.flashes else .12))
	if f.phase=="descend" and a>=f.DESCEND_PARRY and a<f.DESCEND_PARRY+.1:g.draw_rect(Rect2(0,0,640,360),Color(1,1,.9,.4 if g.settings.flashes else .12))
	var black: float=1-k
	if black>0:g.draw_rect(Rect2(0,0,640,360),Color(0,0,0,black))

## Items flying out of Steve, bouncing once and fading away.
func lost_items(g, f, offset: Vector2, scale: float, around: Vector2):
	for o in f.lost:
		var alpha: float=1-smoothstep(2.2,3.2,o.age)
		if alpha<=0:continue
		var p: Vector2=o.p+offset if scale==1.0 else offset+o.p*CLOSE
		var size: float=16.0*(1.0 if scale==1.0 else 2.0)
		g.oval(p,Vector2(size*.3,size*.1),Color(0,0,0,.3*alpha))
		var turn: float=cos(o.age*5+o.p.x)
		g.draw_set_transform((p-Vector2(0,o.h*(1.0 if scale==1.0 else CLOSE)+size*.5)).floor(),0,Vector2(signf(turn)*maxf(.2,absf(turn)),1)*(size/16.0))
		g.item_icon(o.id,Vector2(-8,-8),1.0,o.evolved)
		g.draw_set_transform(Vector2.ZERO)

func subtitles(g, f):
	if f.line.is_empty():return
	var alpha: float=minf(1,f.line_age/.15)*minf(1,(f.line_length-f.line_age)/.2)
	var width: float=g.font.get_string_size(f.line,HORIZONTAL_ALIGNMENT_LEFT,-1,8).x
	# Above the hearts and hotbar while the HUD is up.
	var y: float=278.0 if f.phase in ["tease","storm","inferno"] else 318.0
	g.draw_rect(Rect2((640-width)/2-8,y,width+16,16),Color(0,0,0,.6*alpha))
	g.centered(f.line,y+11,8,Color(.92,.9,.95,alpha))

## The question, in the way he really talks.
func whisper_text(g, f):
	var k: float=f.whisper()
	if k<=0:return
	g.draw_rect(Rect2(0,0,640,360),Color(0,0,0,.9*k))
	var text: String=f.WHISPER_TEXT
	var a: float=f.phase_age-f.WHISPER[0]
	var shown: int=mini(text.length(),int(a*20))
	var size:=16
	var total: float=g.bold.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	var lines: Array=[text] if total<560 else [text.substr(0,text.find(" ",text.length()/2)),text.substr(text.find(" ",text.length()/2)+1)]
	var index:=0
	for row in range(lines.size()):
		var s: String=lines[row]
		var x: float=(640-g.bold.get_string_size(s,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x)/2
		var y: float=176+row*24-(lines.size()-1)*12
		for c in range(s.length()):
			var ch: String=s[c]
			var cw: float=g.bold.get_string_size(ch,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
			if index<shown:
				var tick: int=int(g.world.clock*14)
				var j: Vector2=Vector2(ChapterOne.h(index*31+tick,40)-.5,ChapterOne.h(index*17+tick,41)-.5)*2.4
				var red: Color=Color(.62,.04,.06,k)
				g.draw_string(g.bold,(Vector2(x,y)+j*1.8+Vector2(2,1)).round(),ch,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color(.25,0,.02,k*.6))
				g.draw_string(g.bold,(Vector2(x,y)+j).round(),ch,HORIZONTAL_ALIGNMENT_LEFT,-1,size,red)
			x+=cw;index+=1
		index+=1

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
	for s in f.sparks:
		g.draw_rect(Rect2((s.p+offset).floor(),Vector2(2,1)),Color(1,.92,.6,1-s.age/.5))
	if f.phase in ["storm","inferno"]:
		g.centered("Херобрин",41,8,Color.WHITE,true)
		g.draw_rect(Rect2(211,46,218,5),Color("33151b"))
		g.draw_rect(Rect2(212,47,216*clampf(f.boss.hp/f.boss.max_hp,0,1),3),Color("a94550"))
	elif f.phase=="tease":
		g.centered("Херобрин",41,8,Color.WHITE,true)
		g.centered("не даётся",52,8,Color(1,1,1,.45))
	if f.phase=="arrival":warp(g,offset,f.teleport_from,f.GREET_AT,(f.phase_age-1.6)/.8)
	if f.phase=="throne":warp(g,offset,f.teleport_from,f.BOSS_AT,(f.phase_age-(f.THRONE_SEAT-.25))/.7)
	if f.phase=="showtime":warp(g,offset,f.BOSS_AT,w.player+Vector2(6,-6),(f.phase_age-.25)/.6)
	if f.phase=="descend":
		warp(g,offset,f.BOSS_AT,w.player+Vector2(6,-6),(f.phase_age-.2)/.6)
		warp(g,offset,f.teleport_from,f.BOSS_AT,(f.phase_age-f.WHISPER[1])/.7)
	if f.phase=="showtime" and f.phase_age>=f.SHOW_PUNCH and f.phase_age<f.SHOW_PUNCH+.12:
		g.draw_rect(Rect2(0,0,640,360),Color(.6,0,.02,.35 if g.settings.flashes else .12))
	if f.phase=="descend" and f.phase_age>=f.DESCEND_PARRY and f.phase_age<f.DESCEND_PARRY+.1:
		g.draw_rect(Rect2(0,0,640,360),Color(1,1,.9,.4 if g.settings.flashes else .12))
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
	if close_weight(f)<=0:lost_items(g,f,offset,1.0,Vector2.ZERO)
	closeup(g,f)
	whisper_text(g,f)
	if f.cinematic_player() or f.phase=="arrival":
		g.draw_rect(Rect2(0,0,640,16),Color.BLACK);g.draw_rect(Rect2(0,344,640,16),Color.BLACK)
	subtitles(g,f)
	if f.phase=="arrival":g.draw_rect(Rect2(0,0,640,360),Color(0,0,0,1-smoothstep(0,.7,f.phase_age)))
	if f.phase=="defeated":
		g.draw_rect(Rect2(0,0,640,360),Color(0,0,0,smoothstep(0,1.2,f.phase_age)*.94))
		fallen_player(g,w.player+offset)
	if f.phase in ["portal","fall"]:
		g.draw_rect(Rect2(0,0,640,360),Color(0,0,0,.94))
		var p: Vector2=w.player+offset
		var opening=smoothstep(0,1.6,f.phase_age) if f.phase=="portal" else 1.0
		g.draw_clip("nether_portal",p-Vector2(35,12)*opening,Vector2(70,24)*opening,w.clock)
		fallen_player(g,p)
		if f.phase=="fall":legacy.nether(g,smoothstep(1.2,3.8,f.phase_age))

func ending(g):legacy.ending(g)
