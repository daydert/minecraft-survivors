extends RefCounted
## Drawing for the reworked EnderSteve duel (2026-11-14): his rebirth, the fallen card,
## and the effects of his new moves. State comes from end_world / end_steve_boss.
const Tells=preload("res://scripts/chapter_four_tells.gd")
const Atmosphere=preload("res://scripts/ui/atmosphere.gd")

## Killed once: down on his knees, torn into pixels, pulled back and rebuilt where he began.
static func rebirth(g, r, offset: Vector2):
	var w=g.world;var e=w.end_boss;var a: float=w.stage_age
	var gone: float=e.REBIRTH_GONE;var form: float=e.REBIRTH_FORM
	g.draw_rect(Rect2(0,0,640,360),Color(.03,0,.05,.35*smoothstep(0,.8,a)*(1-smoothstep(form+.8,e.REBIRTH_END,a))))
	if not w.endsteve_corpse.is_empty() and a<gone+.4:
		var p: Vector2=w.endsteve_corpse.p+offset
		g.oval(p,Vector2(8,3),Color(0,0,0,.35))
		var k: float=clampf(a/1.2,0,1)
		if a<1.6:r.death_frame(g,p,w.endsteve_corpse.get("visual_dir",Vector2.DOWN),int(k*11))
		else:r.death_frame(g,p,w.endsteve_corpse.get("visual_dir",Vector2.DOWN),26+int(clampf((a-1.6)/(gone-1.6),0,1)*20),Color(1,1,1,1-smoothstep(gone-.2,gone+.4,a)))
		r.glitch_over(g,p-Vector2(0,14),Vector2(10,16),smoothstep(.6,gone,a),91)
	# The hands of his clock run backwards over the whole scene.
	var hub:=Vector2(320,120)
	var spin: float=-a*a*1.6
	var alpha: float=smoothstep(.2,1.0,a)*(1-smoothstep(form,form+1.0,a))
	if alpha>0:
		g.draw_arc(hub,46,0,TAU,48,Color(.95,.75,.3,.35*alpha),2)
		g.draw_arc(hub,40,0,TAU,48,Color(.7,.4,1,.25*alpha),1)
		for j in range(12):
			var d:=Vector2.from_angle(j*TAU/12)
			g.draw_line(hub+d*36,hub+d*(40 if j%3 else 33),Color(1,.85,.45,.55*alpha),1)
		g.draw_line(hub,hub+Vector2.from_angle(spin-PI/2)*30,Color(1,.9,.6,.85*alpha),2)
		g.draw_line(hub,hub+Vector2.from_angle(spin*12-PI/2)*38,Color(.85,.6,1,.8*alpha),1)
	# Pixels stream from where he fell to where he began.
	if not w.endsteve_corpse.is_empty() and a>1.2 and a<form+.6:
		var from: Vector2=w.endsteve_corpse.p+offset-Vector2(0,14);var to: Vector2=w.betrayer_position()+offset-Vector2(0,14)
		for j in range(46):
			var t: float=fposmod((a-1.2)*.7+j*.0217,1.0)
			var q: Vector2=from.lerp(to,t*t)+Vector2(sin(j*2.1+a*4)*8*(1-t),-sin(t*PI)*30)
			g.draw_rect(Rect2(q.floor(),Vector2.ONE*(1+j%2)),Color(.75,.4,1,.8*(1-absf(t-.5)*1.2)))
	if a>=form:
		var p: Vector2=w.betrayer_position()+offset;var k: float=clampf((a-form)/.9,0,1)
		g.oval(p,Vector2(8,3),Color(0,0,0,.35*k))
		r.death_frame(g,p,Vector2.DOWN,clampi(46-int(k*20),26,46),Color(1,1,1,k))
		if k>=1.0:g.draw_actor("endersteve_final",p,Vector2.DOWN,a,false,Color.WHITE,"idle",1,{"state":"idle","time":0.0})
		r.glitch_over(g,p-Vector2(0,14),Vector2(10,16),(1-k)*.9,93)
		r.end_particles(g,p,w.clock,5,16,20)

## Death in the duel: the loop takes the hero back to the last checkpoint.
static func fallen(g):
	var w=g.world;var a: float=w.stage_age
	var k: float=smoothstep(0,.8,a)
	g.draw_rect(Rect2(0,0,640,360),Color(.02,0,.03,.82*k))
	if a<.8:return
	var t: float=smoothstep(.8,1.4,a)
	g.centered("Вы погибли",118,24,Color(1,.28,.3,t),true)
	g.centered("Он запомнит этот бой" if int(w.duel.get("fight",1))==2 else "Петля начинается снова",150,10,Color(.85,.75,1,t*.85))
	if a>1.2:
		g.button(Rect2(181,214,278,30),"Повторить бой с ЭндерСтивом","end_retry")
		g.button(Rect2(249,254,142,24),"В меню","menu")

## ---------------------------------------------------------------- the fight
## His moves in the world: the frames of the next lap, the intercept mark, the clock,
## the frame around a caught hero, the reflections of the Loop, a kicked crystal.
static func fight_world(g, r, offset: Vector2):
	var w=g.world
	for m in w.mobs:
		if m.kind!="endersteve_final" or m.hp<=0:continue
		var p: Vector2=m.p+offset
		match m.phase:
			"projection_stance":
				var k: float=1.0-m.timer/maxf(.01,m.get("windup_total",.9))
				# Twenty-four frames gather around him: a reel being loaded.
				for j in range(12):
					var q: Vector2=p-Vector2(0,12)+Vector2.from_angle(j*TAU/12+w.clock*2)*(46-30*k)
					film_frame(g,q,.35+.5*k,0.0)
			"projection_preview","projection":
				var path: Array=m.get("path",[])
				var from: int=int(m.get("seg",1))
				var k: float=1.0-m.timer/maxf(.01,float(m.get("preview",.4))) if m.phase=="projection_preview" else 1.0
				var start: Vector2=m.p
				for i in range(from,path.size()):
					var a: Vector2=start+offset;var b: Vector2=path[i]+offset
					var length: float=a.distance_to(b)
					var n: int=int(length/16)
					for j in range(n):
						film_frame(g,a.lerp(b,(j+.5)/n)-Vector2(0,12),(.55+.4*k) if m.phase=="projection_preview" else .35,a.direction_to(b).angle())
					start=path[i]
				if m.phase=="projection" and int(m.lap)>0:
					var ring: float=fposmod(w.clock*6,1.0)
					g.draw_arc(p-Vector2(0,10),10+ring*14,0,TAU,20,Color(1,1,1,.5*(1-ring)),1)
			"framed_strike":
				dots_arc(g,p,m.charge,40.0,1.0-m.timer/maxf(.01,m.get("windup_total",.9)),w.clock)
			"intercept":
				var k: float=1.0-m.timer/maxf(.01,m.get("windup_total",.5))
				var q: Vector2=m.mark+offset
				Tells.ring(g,q.floor(),24.0,k,w.clock)
				g.draw_line(q-Vector2(0,4),q-Vector2(0,4+60*k),Color(.9,.65,1,.35+.5*k),1)
		clock(g,m,p)
	if w.framed>0:frame_around(g,w.player+offset,w.clock)
	for e in w.effects:
		if e.kind=="steve_loop_ghost":
			var k: float=clampf(e.age/maxf(.01,float(e.get("wait",.9))),0,1)
			var q: Vector2=e.p+offset;var d: Vector2=e.p.direction_to(e.target)
			g.draw_actor("endersteve_final",q,d,e.age,false,Color(.7,.45,1,.25+.35*k),"windup",1,{"state":"windup","time":.16*k})
			r.end_particles(g,q,w.clock,e.p.x,6,10)
		elif e.kind=="placed_end_crystal" and e.get("kicked",false) and not e.triggered:
			Tells.ring(g,(e.p+offset).floor(),float(e.stats.radius),clampf(e.age/.65,0,1),w.clock)
		elif e.kind=="frame_shatter":
			var t: float=e.age/e.total
			for j in range(14):
				var dir: Vector2=Vector2.from_angle(j*2.4)
				var q: Vector2=e.p+offset-Vector2(0,14)+dir*t*(30+j%4*10)+Vector2(0,t*t*40)
				g.draw_set_transform(q.floor(),t*(j%5-2)*3)
				g.draw_rect(Rect2(-3,-1,5+j%3,2),Color(1,1,1,1-t))
				g.draw_set_transform(Vector2.ZERO)

## His cut, warned without the chapter IV cracks: a row of dots that light up from
## start to end, edged in dark for the pale stone, flashing white just before it lands.
static func dots_line(g, a: Vector2, b: Vector2, k: float, clock: float, width: float=10.0):
	var length: float=a.distance_to(b)
	if length<1:return
	var n: int=maxi(2,int(length/9))
	var side: Vector2=a.direction_to(b).orthogonal()
	var hot: bool=k>.8 and int(clock*20)%2==0
	for j in range(n+1):
		var t: float=float(j)/n
		var lit: bool=t<=k*1.15
		var q: Vector2=a.lerp(b,t).floor()
		var size: float=2.0 if lit else 1.0
		g.draw_rect(Rect2(q-Vector2.ONE*(size+1),Vector2.ONE*(size*2+2)),Color(.06,0,.1,.55 if lit else .3))
		g.draw_rect(Rect2(q-Vector2.ONE*size,Vector2.ONE*size*2),Color(1,1,1) if hot else Color(.85,.5,1,.95) if lit else Color(.75,.55,.9,.5))
	# The edges of the cut: two faint rows of single dots at its width.
	if k>.35:
		for j in range(0,n+1,2):
			for s in [-1.0,1.0]:
				var q: Vector2=(a.lerp(b,float(j)/n)+side*s*width).floor()
				g.draw_rect(Rect2(q,Vector2.ONE),Color(.85,.6,1,.6*k))

## His swing, warned as an arc of dots in front of him (no chapter IV claws).
static func dots_arc(g, p: Vector2, dir: Vector2, reach: float, k: float, clock: float):
	var hot: bool=k>.8 and int(clock*20)%2==0
	var base: float=dir.angle()
	for ring in [reach,reach*.62]:
		var n: int=maxi(5,int(ring*1.6/7))
		for j in range(n+1):
			var t: float=float(j)/n
			var a: float=base-.8+1.6*t
			var lit: bool=absf(t-.5)*2<=k*1.1
			var q: Vector2=(p-Vector2(0,6)+Vector2.from_angle(a)*Vector2(ring,ring*.7)).floor()
			var size: float=2.0 if lit and ring==reach else 1.0
			g.draw_rect(Rect2(q-Vector2.ONE*(size+1),Vector2.ONE*(size*2+2)),Color(.06,0,.1,.5 if lit else .25))
			g.draw_rect(Rect2(q-Vector2.ONE*size,Vector2.ONE*size*2),Color(1,1,1) if hot else Color(.85,.5,1,.95) if lit else Color(.75,.55,.9,.45))

## One frame of film: a pale outline with sprocket holes along both edges.
static func film_frame(g, q: Vector2, alpha: float, angle: float):
	g.draw_set_transform(q.floor(),angle)
	# Dark backing first: the pale end stone would swallow a white outline alone.
	g.draw_rect(Rect2(-7,-9,14,18),Color(.08,0,.12,alpha*.75),false,2)
	g.draw_rect(Rect2(-6,-8,12,16),Color(1,1,1,alpha),false,1)
	for y in [-6,-2,2,6]:
		g.draw_rect(Rect2(-5,y-1,2,2),Color(.08,0,.12,alpha*.8))
		g.draw_rect(Rect2(3,y-1,2,2),Color(.08,0,.12,alpha*.8))
	g.draw_set_transform(Vector2.ZERO)

## The hero caught in his frame: a still of film around him, everything inside pale.
static func frame_around(g, p: Vector2, clock: float):
	var box:=Rect2(p-Vector2(15,40),Vector2(30,44))
	g.draw_rect(box,Color(.85,.85,.9,.22))
	g.draw_rect(box.grow(3),Color(.06,0,.1,.85),false,2)
	g.draw_rect(box.grow(1),Color(1,1,1,1),false,2)
	for j in range(5):
		g.draw_rect(Rect2(box.position+Vector2(3+j*5.5,2),Vector2(3,3)),Color(1,1,1,.85))
		g.draw_rect(Rect2(box.position+Vector2(3+j*5.5,box.size.y-5),Vector2(3,3)),Color(1,1,1,.85))
	if int(clock*20)%6==0:g.draw_line(box.position+Vector2(0,box.size.y*.4),box.position+Vector2(box.size.x,box.size.y*.4),Color(1,1,1,.4),1)

## His clock above and behind him: ticking, rewinding, or cracked.
static func clock(g, m: Dictionary, p: Vector2):
	var c: Dictionary=m.get("clock",{});var state: String=c.get("state","")
	var w=g.world
	var appear: float=1.0
	if m.phase=="clock_wind":appear=1.0-m.timer/maxf(.01,m.get("windup_total",1.0))
	if state=="" or state=="spent":
		if m.phase!="clock_wind":return
	if state=="broken":appear=1.0-smoothstep(.0,2.5,2.5-m.timer)
	var face: Texture2D=g.textures.get("ch3_clock_face");var gear: Texture2D=g.textures.get("ch3_clock_gear")
	if face==null:return
	var hub: Vector2=(p-Vector2(0,70)).floor();var s: float=.74*smoothstep(0,1,appear)
	var shake:=Vector2.ZERO
	if state=="broken":shake=Vector2(sin(w.clock*60),cos(w.clock*47))*2*(1-appear)
	var alpha: float=clampf(appear,0,1)
	if gear:
		for side in [-1.0,1.0]:
			var turn: float=w.clock*1.4*side*(-3.0 if state=="rewind" else 1.0)
			g.draw_set_transform(hub+shake+Vector2(side*30,-18)*s,turn,Vector2.ONE*s)
			g.draw_texture_rect(gear,Rect2(-20,-20,40,40),false,Color(1,1,1,alpha*.95))
			g.draw_set_transform(Vector2.ZERO)
	g.draw_set_transform(hub+shake,0,Vector2.ONE*s)
	g.draw_texture_rect(face,Rect2(-48,-48,96,96),false,Color(1,1,1,alpha))
	g.draw_set_transform(Vector2.ZERO)
	var age: float=float(c.get("age",0.0))
	var minute: float=age/9.0*TAU
	if state=="rewind":minute=(1.0-age/1.4)*TAU*3
	var hour: float=minute/12.0
	var mh: Vector2=Vector2.from_angle(minute-PI/2)*34*s;var hh: Vector2=Vector2.from_angle(hour-PI/2)*22*s
	g.draw_line(hub+shake,hub+shake+hh,Color(1,.86,.4,alpha),2)
	g.draw_line(hub+shake,hub+shake+mh,Color(1,.95,.7,alpha),1)
	# How close the hero is to forcing a rewind: the rim burns red as damage piles up.
	if state=="running":
		var dealt:=0.0
		for id in c.get("dealt",{}):dealt+=float(c.dealt[id])
		var k: float=clampf(dealt/(.12*m.max_hp),0,1)
		if k>0:g.draw_arc(hub,46*s+2,-PI/2,-PI/2+TAU*k,40,Color(1,.25+.4*(1-k),.2,.85),2)
	if state=="broken":
		for j in range(5):
			var a: float=j*1.3+.4
			g.draw_line(hub+Vector2.from_angle(a)*6*s,hub+Vector2.from_angle(a)*44*s+Vector2(j%2,0),Color(.08,0,.12,alpha),1)

## Over the whole screen: the pale world of the frame, the gold of the rewind.
static func fight_screen(g):
	var w=g.world
	if w.framed>0:g.draw_rect(Rect2(0,0,640,360),Color(.75,.75,.8,.12))
	for m in w.mobs:
		if m.kind!="endersteve_final":continue
		var c: Dictionary=m.get("clock",{})
		if c.get("state","")=="rewind":
			var k: float=sin(clampf(float(c.age)/1.4,0,1)*PI)
			g.draw_rect(Rect2(0,0,640,360),Color(.9,.65,.25,.16*k))
			g.draw_rect(Rect2(0,0,640,360),Color(.4,.15,.6,.12*k))
			for j in range(6):
				var y: float=fposmod(j*61.0-w.clock*240,360)
				g.draw_rect(Rect2(0,y,640,1),Color(1,.9,.6,.18*k))

## Under his bar: the second loop, and the weapons he has learned to blunt.
static func hud(g, m: Dictionary):
	var w=g.world
	var y:=58.0
	if int(w.duel.get("fight",1))==2:g.centered("вторая итерация",y,8,Color(.85,.7,1));y+=11
	var adapt: Dictionary=w.duel.get("adapt",{})
	if adapt.is_empty():return
	var ids: Array=adapt.keys()
	var x0: float=320-ids.size()*24
	for i in range(ids.size()):
		var at:=Vector2(x0+i*48,y)
		g.item_icon(ids[i],at,.75,w.evolved.has(ids[i]))
		g.text_at(str(int(round(float(adapt[ids[i]])*100)))+"%",at+Vector2(15,10),8,Color(1,.6,.6))

## ---------------------------------------------------------------- the race
## The race in close-up, like the rest of the ending: both of them and the sword between.
static func race_close(g, r):
	var w=g.world
	if w.race.is_empty():return
	var S:=2.2
	var mid: Vector2=(w.player+w.npc.p+w.race.sword)/3
	var c:=Vector2(320,220)
	r.close_floor(g,mid,S,c)
	var spot: Vector2=c+(w.race.sword-mid)*S
	if not g.textures.has("icon_sword_iron"):g.load_texture("icon_sword_iron")
	var tex=g.textures.get("icon_sword_iron")
	g.oval(spot+Vector2(0,3),Vector2(16,4),Color(0,0,0,.35))
	if tex:
		g.draw_set_transform(spot.floor(),.6,Vector2.ONE*S)
		g.draw_texture_rect(tex,Rect2(-8,-8,16,16),false)
		g.draw_set_transform(Vector2.ZERO)
	var glint: float=fposmod(w.clock*1.3,1.0)
	g.draw_line(spot+Vector2(-12+glint*24,-10),spot+Vector2(-8+glint*24,-14),Color(1,1,1,.8*(1-glint)),2)
	var intro: bool=w.stage_age<w.end_boss.RACE_INTRO
	for who in [["ch3_brawl_steve",w.player,w.facing],["ch3_brawl_ender",w.npc.p,w.npc.dir]]:
		var p: Vector2=c+(who[1]-mid)*S
		g.oval(p+Vector2(0,2),Vector2(16,4),Color(0,0,0,.3))
		var pose: Array=["getup",w.stage_age*1.6,false] if intro else ["run",w.clock*1.4,true]
		r.brawl_fig(g,who[0],pose,p,who[2].x<0,S*.75)
	var black: float=1-smoothstep(0,.35,w.stage_age)
	if black>0:g.draw_rect(Rect2(0,0,640,360),Color(0,0,0,black))

static func race_ui(g):
	var w=g.world;var q=w.sword_race
	if w.stage_age<w.end_boss.RACE_INTRO:return
	var top:=70.0
	match q.beat:
		0:
			g.centered("Пробел — бежать",top,10,Color.WHITE,true)
			g.draw_rect(Rect2(220,top+10,200,5),Color(0,0,0,.6));g.draw_rect(Rect2(220,top+10,200*q.bar(),5),Color(.85,.95,.85))
			g.draw_rect(Rect2(220,top+18,200,3),Color(0,0,0,.6));g.draw_rect(Rect2(220,top+18,200*q.foe_bar(),3),Color(.75,.4,1))
		1:
			if q.age>=q.DODGE_LEAD or q.resolved:
				var left: bool=q.dir=="left"
				g.centered(("A — влево" if left else "D — вправо"),top,10,Color.WHITE,true)
				var k: float=clampf((q.age-q.DODGE_LEAD)/q.DODGE_WINDOW,0,1) if not q.resolved else 1.0
				var c:=Vector2(320,top+28)
				var d: float=-1.0 if left else 1.0
				g.draw_colored_polygon(PackedVector2Array([c+Vector2(d*16,0),c+Vector2(-d*4,-10),c+Vector2(-d*4,10)]),Color(1,1,1,.9))
				g.draw_rect(Rect2(260,top+44,120*(1-k),2),Color(1,.5,.5))
		2:
			g.centered("Пробел — схватить",top,10,Color.WHITE,true)
			var spot: Vector2=Vector2(320,top+34)
			var k: float=q.ring()
			g.draw_arc(spot,8,0,TAU,20,Color(1,.9,.6,.9),1)
			g.draw_arc(spot,8+40*(1-k),0,TAU,32,Color(1,1,1,.85),2)
	if q.resolved and not q.outcomes.is_empty():
		var ok: bool=q.outcomes.back()
		g.centered("Успел" if ok else "Не успел",top+62,10,Color(.7,1,.7) if ok else Color(1,.4,.4),true)

## ---------------------------------------------------------------- the bad end
static func bad_card(g):
	var w=g.world;var a: float=w.stage_age
	g.draw_rect(Rect2(0,0,640,360),Color.BLACK)
	var t: float=smoothstep(.4,1.4,a)
	g.centered("Плохая концовка",120,24,Color(.85,.15,.2,t),true)
	g.centered("Петля замкнулась. Он победил в этой итерации",152,10,Color(.8,.75,.9,t*.85))
	if a>1.4:
		g.button(Rect2(181,214,278,30),"Повторить бой с ЭндерСтивом","end_retry")
		g.button(Rect2(249,254,142,24),"В меню","menu")
