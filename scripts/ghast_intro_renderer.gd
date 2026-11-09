extends RefCounted

func debris(g, offset: Vector2):
	var pieces=g.world.ghast.pieces.duplicate()
	pieces.sort_custom(func(a,b):return a.p.y<b.p.y)
	for piece in pieces:
		var alpha=1-smoothstep(piece.life-1.5,piece.life,piece.age)
		var p: Vector2=piece.p+offset
		g.oval(p,Vector2(13 if not piece.leg else 6,4),Color(0,0,0,.22*alpha/(1+piece.height*.01)))
		p.y-=piece.height
		if piece.leg:
			g.draw_set_transform(p,piece.spin*piece.age)
			g.sprite(piece.sprite,-piece.size/2,Vector2.ZERO,Color(1,1,1,alpha))
			g.draw_set_transform(Vector2.ZERO)
		else:g.draw_clip(piece.sprite,p-piece.size/2,piece.size,piece.age,Color(1,1,1,alpha))

func body(g, offset: Vector2):
	var w=g.world;var age: float=w.stage_age
	var burst: float=w.ghast.BURST
	var p: Vector2=w.ghast.ORIGIN+offset
	var float_y=sin(age*1.7)*5
	var pressure=smoothstep(3.5,burst,age)
	if age<burst:
		g.oval(p+Vector2(0,3),Vector2(62,15),Color(0,0,0,.4*smoothstep(.2,1.3,age)))
		var shake=Vector2(sin(age*62),cos(age*53))*pressure*3
		var alpha=smoothstep(.2,1.35,age)
		g.draw_clip("ghast_charge" if age>=3 else "ghast_hover",p-Vector2(96,196)+Vector2(0,float_y)+shake,Vector2(192,216),age,Color(1,1,1,alpha))
		for j in range(6):
			var q=p+Vector2(sin(j*2.4)*35,-120+cos(j*2.4)*32)+shake
			g.draw_clip("soul_fire_animation",q-Vector2(5,18),Vector2(10,28),w.clock+j*.1,Color(.7,1,1,pressure*(.35+.2*sin(age*19+j))))
	var since=age-burst
	if since>=0 and since<1.8:
		for j in range(36):
			var dir=Vector2.from_angle(j*2.399)
			var q=p-Vector2(0,125)+dir*(20+since*(95+j%5*19))
			g.draw_rect(Rect2(q.floor(),Vector2.ONE*(2+j%3)),Color(.55,.72,.74,(1-since/1.8)*.75))
	if g.settings.flashes and absf(since)<.14:
		g.draw_rect(Rect2(0,0,640,360),Color(.65,.9,1,.2*(1-absf(since)/.14)))

func title(g):
	var age: float=g.world.stage_age
	var burst: float=g.world.ghast.BURST
	var ghast_alpha=smoothstep(.7,1.5,age)*(1-smoothstep(burst,burst+.25,age))
	var wither_alpha=smoothstep(7.0,8.2,age)
	var alpha=ghast_alpha if age<burst+.25 else wither_alpha
	if alpha<=0:return
	var name="Гаст" if age<burst+.25 else "Иссушитель"
	g.centered(name,41,8,Color(1,1,1,alpha),true)
	g.draw_rect(Rect2(191,46,258,5),Color(.2,.16,.2,alpha))
	var fill=1-smoothstep(burst,burst+.2,age) if age<burst+.25 else 1.0
	g.draw_rect(Rect2(192,47,256*fill,3),Color(.65,.48,.67,alpha))
