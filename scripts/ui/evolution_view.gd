extends RefCounted
## Shared IV reveal: identical beam, burn, lift, flash, typography and 1.7 s timing.
## Presentation reads chest delay only: no combat ticks, RNG, or reward rerolls.
const FxView=preload("res://scripts/chapter_four_fx_view.gd")

static func draw(g, fourth_body: Callable = Callable()):
	var w=g.world;var r: Dictionary=w.chest_reward
	var id: String=r.get("id","")
	var total: float=w.EVOLUTION_REVEAL
	var k: float=clampf(1.0-w.chest_delay/total,0,1)
	var t: float=total-w.chest_delay
	var turn: float=smoothstep(.42,.5,k)
	g.dim(.55+.35*smoothstep(0,.3,k))
	var beam: float=smoothstep(.05,.45,k)
	var cx:=320.0;var floor_y:=228.0
	g.draw_rect(Rect2(cx-30*beam,0,60*beam,floor_y),Color(1,.9,.65,.07*beam))
	g.draw_rect(Rect2(cx-14*beam,0,28*beam,floor_y),Color(1,.92,.7,.12*beam))
	g.draw_rect(Rect2(cx-2,0,4,floor_y),Color(1,1,.92,.55*beam))
	g.oval(Vector2(cx,floor_y),Vector2(70,14)*beam,Color(1,.85,.55,.18*beam))
	g.oval(Vector2(cx,floor_y),Vector2(36,7)*beam,Color(1,.95,.8,.35*beam))
	for j in range(34):
		var life: float=fposmod(t*(.35+FxView.hh(j,1)*.4)+FxView.hh(j,2),1.0)
		var q:=Vector2(cx+(FxView.hh(j,3)-.5)*130*(1-life*.4),floor_y-life*(150+FxView.hh(j,4)*60))
		g.draw_rect(Rect2(q.floor(),Vector2(1,2) if j%3 else Vector2(2,2)),Color(1,.86,.5,sin(life*PI)*beam))
	var held: String=id if w.db.weapons.has(id) else (w.build.keys()[0] if not w.build.is_empty() else "idle")
	# Choreography (13.11): he raises the item into the beam, it burns away, he brings
	# it down into the floor with a slam that rings out, then swings the new one.
	var state: String="windup";var progress: float=clampf(k/.44,0,1)
	if k>=.44 and k<.62:state="attack";progress=clampf((k-.44)/.18,0,.999)
	elif k>=.62:
		var loop: float=fposmod(t-total*.62,1.3)
		state="attack" if loop<.45 else "idle";progress=clampf(loop/.45,0,.999)
	var tint: Color=Color(.05,.04,.05).lerp(Color.WHITE,turn)
	g.draw_set_transform(Vector2(cx,floor_y),0,Vector2(3,3))
	if fourth_body.is_valid():fourth_body.call(g,Vector2.ZERO,Vector2.DOWN,held,state,progress,tint,false)
	else:g.draw_actor("steve",Vector2.ZERO,Vector2.DOWN,t,false,tint,state,1.0,{"state":state,"time":progress*(.16 if state=="windup" else .5),"weapon":held,"airborne":true})
	g.draw_set_transform(Vector2.ZERO)
	# The item itself in his hands: lifted overhead, burning, then driven down.
	var hand:=Vector2(cx+14,floor_y-58-34*smoothstep(0,.4,k))
	if k>=.44:hand=Vector2(cx+20,floor_y-92).lerp(Vector2(cx+26,floor_y-18),smoothstep(.44,.5,k))
	if k>=.62:hand=Vector2(cx+20,floor_y-44+sin(t*3)*2)
	g.item_icon(id,(hand-Vector2(16,16)).floor(),2,k>=.5)
	if k<.44:
		for j in range(8):
			var q:=hand+Vector2.from_angle(j*TAU/8+t*4)*(18-10*k)
			g.draw_rect(Rect2(q.floor(),Vector2(2,2)),Color(1,.75,.3,.4+.6*k))
	# The slam: a ring across the floor and splinters of light.
	if k>=.47 and k<.8:
		var sk: float=(k-.47)/.33
		g.draw_arc(Vector2(cx,floor_y),20+sk*170,0,TAU,64,Color(1,.9,.6,(1-sk)*.9),3)
		g.oval(Vector2(cx,floor_y),Vector2(40+sk*150,10+sk*36),Color(1,.85,.55,.18*(1-sk)))
		for j in range(14):
			var d:=Vector2.from_angle(-PI*(.1+.8*FxView.hh(j,21)))
			g.draw_line(Vector2(cx,floor_y)+d*sk*40,Vector2(cx,floor_y)+d*(sk*40+30*(1-sk)),Color(1,.95,.75,1-sk),2)
	var lift: float=sin(t*2.0)*3
	var icon_at:=Vector2(cx-24,64+lift)
	if k<.5:
		var burn: float=smoothstep(.2,.48,k)
		g.item_icon(id,icon_at,3,false)
		for j in range(14):
			var q:=icon_at+Vector2(FxView.hh(j,7)*48,48-FxView.hh(j,8)*48*burn)
			g.draw_rect(Rect2(q.floor(),Vector2(2,2)),Color(1,.6,.25,burn))
		g.draw_rect(Rect2(icon_at,Vector2(48,48*burn)),Color(0,0,0,.6*burn))
	else:
		var glow: float=1.0-smoothstep(.5,.75,k)
		for j in range(12):
			var d:=Vector2.from_angle(j*TAU/12+t*.4)
			g.draw_line(icon_at+Vector2(24,24)+d*28,icon_at+Vector2(24,24)+d*(34+6*sin(t*3+j)),Color(1,.9,.6,.55),1)
		g.oval(icon_at+Vector2(24,24),Vector2(30,30),Color(1,.88,.6,.12+.3*glow))
		g.item_icon(id,icon_at,3,true)
	if k>.42 and k<.6 and g.settings.flashes:
		g.draw_rect(Rect2(0,0,640,360),Color(1,.97,.9,(1-absf(k-.5)/.1)*.85))
	var reveal: float=smoothstep(.55,.8,k)
	g.centered("ЭВОЛЮЦИЯ",36,16,Color(1,.88,.6,.4+.6*reveal),true)
	g.centered(g.gear_title(id,true),258,15,Color(1,1,1,reveal),true)
	g.centered(r.get("text",""),280,8,Color(.9,.85,.75,reveal))
	g.button(Rect2(214,300,212,26),"Открыть" if w.chest_delay>0 else "Продолжить","chest")
	g.button(Rect2(263,332,114,18),"В меню","menu")
