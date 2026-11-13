extends RefCounted
## IV equipment shares the body hierarchy; effects read only simulation queues.
const Materials=preload("res://scripts/chapter_four_equipment.gd")
const FxView=preload("res://scripts/chapter_four_fx_view.gd")

static func gear(w,id: String) -> String:
	if id=="sword" and w.evolved.has(id):return "bedrock"
	if id in ["sword","axe","hoe"]:
		return id+"_"+("iron" if w.build.get(id,1)<=3 else "diamond" if w.build.get(id,1)<=7 else "netherite")
	return id if id in ["bow","trident","bed","tnt","fishing","shotgun","sky_tnt","blood_pool","embryo","bell","bone_saw","red_torch","potion"] else "idle"

static func body(g,p: Vector2,dir: Vector2,id: String,state: String,progress: float,tint: Color,shadow: bool=true):
	var w=g.world
	var wing: int=mini(3,(int(w.items.get("bat_wings",0))+1)/2)
	var maiden: int=1 if w.evolved.has("armor") and w.items.has("armor") else 0
	var name: String="ch4_held_%s_w%d_a%d"%[gear(w,id),wing,maiden]
	var texture=g.four_held_texture(name)
	if texture==null:return
	var meta: Dictionary=g.four_equipment.held[name]
	var clip: Dictionary=meta.states.get(state,meta.states.idle)
	var frame: int=int(clip.start)+clampi(int(progress*clip.durations.size()),0,clip.durations.size()-1)
	var row: int=w.animation.direction_row(dir)
	var size:=Vector2(meta.frame_size[0],meta.frame_size[1]);var anchor:=Vector2(meta.anchor[0],meta.anchor[1])
	if shadow:g.oval(p+Vector2(0,1),Vector2(7,2),Color(0,0,0,.45))
	if row==2 and dir.x<0:
		g.draw_set_transform(p.floor(),0,Vector2(-1,1))
		g.draw_texture_rect_region(texture,Rect2(-anchor,size),Rect2(Vector2(frame*size.x,row*size.y),size),tint)
		g.draw_set_transform(Vector2.ZERO)
	else:g.draw_texture_rect_region(texture,Rect2((p-anchor).floor(),size),Rect2(Vector2(frame*size.x,row*size.y),size),tint)

static func player(g,offset: Vector2):
	var w=g.world;var a=w.arsenal
	var id: String=w.player_visual.get("weapon","")
	if id.is_empty():id=w.build.keys()[0] if not w.build.is_empty() else "idle"
	var state: String="walk" if w.player_moving else "idle"
	var progress: float=fposmod(w.player_visual.gait,.4)/.4 if w.player_moving else 0
	var dir: Vector2=w.facing
	# Select an actual cast so the held pose follows the gameplay windup.
	for candidate in a.actions:
		if candidate in ["embryo","blood_pool","potion","red_torch"] and not id in [candidate,"idle"]:continue
		id=candidate;break
	if a.actions.has(id):
		var cast: Dictionary=a.actions[id];dir=cast.dir
		if cast.age<cast.wind:state="windup";progress=cast.age/maxf(.001,cast.wind)
		elif cast.age<cast.wind+.18*cast.duration:state="attack";progress=(cast.age-cast.wind)/maxf(.001,.18*cast.duration)
		else:state="recover";progress=(cast.age-cast.wind-.18*cast.duration)/maxf(.001,cast.duration*.82-cast.wind)
	elif w.weapon_visuals.has(id):
		var pose: Dictionary=w.weapon_visuals[id];state=pose.state;progress=pose.progress if state!="attack" else pose.age/.12;dir=pose.dir
	if w.player_visual.hurt>0:state="hurt";progress=(.12-w.player_visual.hurt)/.12
	var p: Vector2=w.player+offset
	if a.bat_left>0:
		FxView.flock(g,p,a.bat_direction,w.clock,a.bat_left,float(a.rules(w).bat_duration))
		return
	if a.cart_left>0:
		cart(g,p,a.cart_dir,w.clock,true)
		body(g,p-Vector2(0,7),a.cart_dir,"idle","idle",0,g.invulnerable_tint())
		cart(g,p,a.cart_dir,w.clock,false)
		return
	var recoil:=Vector2.ZERO
	if a.heart_buff>0 and g.settings.shake:recoil=Vector2(sin(w.clock*65),cos(w.clock*41))*.7
	if a.actions.has("shotgun"):
		var cast: Dictionary=a.actions.shotgun
		if cast.hit:recoil=-cast.dir*3*maxf(0,1-(cast.age-cast.wind)/.15)
	body(g,p+recoil,dir,id,state,clampf(progress,0,.999),g.invulnerable_tint())
	if w.items.has("black_candle"):
		var q: Vector2=p+Vector2(6,-15);var heat: float=a.candle
		g.draw_rect(Rect2(q,Vector2(2,5)),Color(.08,.07,.1))
		g.draw_colored_polygon(PackedVector2Array([q+Vector2(-1,0),q+Vector2(1,-3-heat*5),q+Vector2(3,0)]),Color(.55+.4*heat,.16+heat*.2,.08,.7))
	if a.mirror_ready:
		for j in range(3):
			var q: Vector2=p+Vector2.from_angle(w.clock*.8+j*TAU/3)*15-Vector2(0,14)
			g.draw_colored_polygon(PackedVector2Array([q+Vector2(0,-3),q+Vector2(2,0),q+Vector2(0,3),q+Vector2(-1,0)]),Color(.7,.8,.8,.8))

## The minecart: a pixel iron tub, back half behind the rider, front half over him.
static func cart(g,p: Vector2,dir: Vector2,clock: float,back: bool):
	var w2: float=13.0 if absf(dir.x)>absf(dir.y) else 10.0
	var bob: float=round(sin(clock*30)*.6)
	if back:
		g.oval(p+Vector2(0,1),Vector2(w2+2,4),Color(0,0,0,.45))
		g.draw_rect(Rect2(p+Vector2(-w2,-13+bob),Vector2(w2*2,5)),Color(.26,.27,.3))
		return
	g.draw_rect(Rect2(p+Vector2(-w2,-9+bob),Vector2(w2*2,8)),Color(.47,.48,.52))
	g.draw_rect(Rect2(p+Vector2(-w2,-9+bob),Vector2(w2*2,1)),Color(.72,.73,.78))
	g.draw_rect(Rect2(p+Vector2(-w2,-2+bob),Vector2(w2*2,1)),Color(.2,.2,.23))
	for x in [-w2+3,w2-5]:g.draw_rect(Rect2(p+Vector2(x,-2),Vector2(3,3)),Color(.12,.12,.13))
	for k in range(3):
		var t: float=fposmod(clock*9+k*.33,1.0)
		g.draw_rect(Rect2((p-dir*(w2+t*10)+Vector2((k-1)*3,-1-t*3)).floor(),Vector2(1,1)),Color(1,.8,.4,1-t))

static func floor_layer(g,offset: Vector2):
	var w=g.world;var a=w.arsenal
	for rl in a.rails:
		var al: float=1.0-smoothstep(4.5,6.0,rl.age)
		var d: Vector2=Vector2(rl.b-rl.a);if d.length()<.1:continue
		var side: Vector2=d.normalized().orthogonal()*4.0;var pa: Vector2=rl.a+offset;var pb: Vector2=rl.b+offset
		g.draw_line(pa-side*1.6,pb-side*1.6,Color(.36,.24,.14,al),3)
		g.draw_line((pa+pb)/2-side*2.2,(pa+pb)/2+side*2.2,Color(.42,.29,.17,al),3)
		g.draw_line(pa-side,pb-side,Color(.62,.62,.66,al),1);g.draw_line(pa+side,pb+side,Color(.62,.62,.66,al),1)
	for pool in a.pools:
		var p: Vector2=pool.p+offset;var points:=PackedVector2Array()
		for j in range(24):
			var angle: float=j*TAU/24;var reach: float=pool.radius*(.9+.08*sin(j*4.7+pool.p.x))
			points.append(p+Vector2.from_angle(angle)*Vector2(reach,reach*.7))
		g.draw_colored_polygon(points,Color(.24,.018,.03,.9))
		for j in range(12):
			var angle: float=j*2.39996;var q: Vector2=p+Vector2.from_angle(angle)*Vector2(pool.radius*.7,pool.radius*.45)
			g.draw_line(q,q+Vector2(3+pool.power*.5,0),Color(.62,.075,.07,.5+.1*sin(w.clock*3+j)),1)
	for c in a.clouds:
		for j in range(9):
			var p: Vector2=c.p+offset+Vector2(sin(j*2.4+w.clock*.5)*27,cos(j*1.8+w.clock*.7)*18-4)
			g.oval(p,Vector2(9,5),Color(.2,.46,.12,.18) if c.poison else Color(.8,.2,.28,.14))
	for link in a.links:
		var p: Vector2=link.a+offset;var end: Vector2=link.b+offset
		g.draw_line(p,end,Color(.2,.02,.025,.6),3)
		if link.live:
			g.draw_line(p,end,Color(.8,.055,.035,.75),1)
			for j in range(5):
				var k: float=fposmod(w.clock*1.7+j*.2,1);var q: Vector2=p.lerp(end,k)
				g.draw_rect(Rect2(q.floor(),Vector2(2,1)),Color(1,.45,.24))
	for t in a.torches:
		g.sprite("ch4_red_torch",t.p+offset-Vector2(8,21))
	for e in a.events:
		if e.kind!="ghost_bell":continue
		for mark in e.marks:
			var p: Vector2=mark+offset
			g.draw_line(p+Vector2(-10,-4),p+Vector2(10,4),Color(.75,.55,.35,.6),2)
			g.draw_line(p+Vector2(-10,4),p+Vector2(10,-4),Color(.75,.55,.35,.6),2)

static func pet(g,offset: Vector2):
	var w=g.world;var p: Dictionary=w.arsenal.pet
	if not w.build.has("embryo") or p.is_empty():return
	var row: int=w.animation.direction_row(p.dir);var frame: int=(4+int((.4-p.attack)*10)%4) if p.attack>0 else int(p.age*5)%4
	var dest:=Rect2((p.p+offset-Vector2(32,49)).floor(),Vector2(64,64))
	g.oval(p.p+offset,Vector2(5+p.stage*2,3),Color(0,0,0,.4))
	var tex=g.textures.get("ch4_pet_"+str(p.stage))
	if tex!=null:g.draw_texture_rect_region(tex,dest,Rect2(frame*64,row*64,64,64))

static func air_layer(g,offset: Vector2):
	var w=g.world;var a=w.arsenal
	for b in a.shots:
		var p: Vector2=b.p+offset-Vector2(0,10)
		var tail: float=minf(b.distance,22.0)
		var heat: float=1.0-clampf(b.distance/b.range,0,1)
		g.draw_line(p-b.dir*tail,p,Color(1,.55,.2,.35*heat),3)
		g.draw_line(p-b.dir*tail*.7,p,Color(1,.9,.6,.9),1)
		g.draw_rect(Rect2(p.floor()-Vector2.ONE,Vector2(2,2)),Color(1,1,.85))
	for e in a.events:
		if e.kind=="ghost_bell":
			var p: Vector2=e.p+offset-Vector2(0,20+sin(clampf(e.age/.85,0,1)*PI)*18)
			g.sprite("ch4_ghost_bell",p-Vector2(48,68),Vector2.ZERO,Color(.75,.7,.7,.32+.4*clampf(e.age/.85,0,1)))
		elif e.kind=="potion_land":
			var k: float=clampf(e.age/(.45 if e.poison else .2),0,1)
			var p: Vector2=e.from.lerp(e.p,k)+offset-Vector2(0,10+sin(k*PI)*24)
			g.item_icon("potion",p-Vector2(8,8))
	for b in a.drops:
		if b.wait>0:continue
		var p: Vector2=b.p+offset
		if b.get("big",false):
			g.oval(p,Vector2(10+14*(1-b.height/170),4),Color(0,0,0,.5))
			g.draw_set_transform(p-Vector2(0,b.height),0,Vector2(2.2,2.2))
			g.sprite("ch4_sky_charge",Vector2(-16,-25))
			g.draw_set_transform(Vector2.ZERO)
			for j in range(6):g.draw_line(p-Vector2(-8+j*3,b.height+40+j*6),p-Vector2(-8+j*3,b.height+70+j*9),Color(1,.6,.3,.35),1)
			continue
		g.oval(p,Vector2(4+6*(1-b.height/105),2),Color(0,0,0,.4))
		g.sprite("ch4_sky_charge",p-Vector2(16,25+b.height))
		g.draw_line(p-Vector2(0,b.height+22),p-Vector2(0,b.height+34),Color(.7,.2,.1,.45),1)
	for e in a.echoes:
		body(g,e.p+offset-e.dir*5,e.dir,e.owner,"attack" if e.hit else "windup",clampf(e.age/.6,0,.99),Color(.6,.7,.8,.28*(1-e.age/.6)),false)

static func effect(g,e: Dictionary,offset: Vector2) -> bool:
	var p: Vector2=e.p+offset;var k: float=clampf(e.age/e.total,0,1)
	match e.kind:
		"ch4_bedrock_cut":
			var end: Vector2=e.end+offset
			g.draw_line(p-Vector2(0,12),end-Vector2(0,12),Color(.8,.76,.7,1-k),3*(1-k)+1)
			for j in range(7):
				var q: Vector2=p.lerp(end,float(j)/7);var d: Vector2=e.dir.orthogonal()
				g.draw_line(q,q+d*(4+j%3)*(1+k),Color(.025,.02,.025,1-k),2)
		"ch4_muzzle":
			var dir: Vector2=e.dir;var side: Vector2=dir.orthogonal()
			p-=Vector2(0,10)
			if k<.5:
				var f: float=1-k*2
				g.draw_colored_polygon(PackedVector2Array([p+side*6*f,p+dir*28*f+side*5*f,p+dir*38*f,p+dir*28*f-side*5*f,p-side*6*f]),Color(1,.55,.15,.85*f))
				g.draw_colored_polygon(PackedVector2Array([p-side*3*f,p+dir*24*f,p+side*3*f]),Color(1,.95,.7,f))
				for s in [-1,1]:g.draw_line(p,p+(dir+side*s*.9).normalized()*14*f,Color(1,.8,.4,f),1)
			g.oval(p+dir*4,Vector2(6,4)*(1-k),Color(1,1,.9,1-k))
		"ch4_blood_spike","ch4_pet_bite":
			for j in range(3):
				var q: Vector2=p+Vector2((j-1)*5,0)
				g.draw_colored_polygon(PackedVector2Array([q-Vector2(2,0),q-Vector2(0,sin(k*PI)*15),q+Vector2(2,0)]),Color(.7,.14,.12,1-k))
		"ch4_friendly_bell","ch4_ghost_impact":
			for j in range(12):
				var d:=Vector2.from_angle(j*TAU/12);var q: Vector2=p+d*Vector2(30+k*65,12+k*28)
				g.draw_line(q,q+d*Vector2(9,3),Color(.8,.7,.45,1-k),1)
		"ch4_sky_blast":
			# Vanilla explosion particles, Minecraft-style: a cluster of grey-white puffs
			# popping at staggered moments, a hot core for two frames, smoke drifting up.
			var r: float=float(e.get("radius",26));var big: bool=e.get("big",false)
			var n: int=18 if big else 7
			if e.age<.07:g.draw_circle(p-Vector2(0,8),r*(.55 if big else .4),Color(1,1,.92,.85*(1-e.age/.07)))
			for j in range(n):
				var delay: float=hh(j,int(e.p.x)%97)*(.22 if big else .12)
				var t: float=e.age-delay
				if t<0 or t>=.4:continue
				var off:=Vector2(hh(j,3+int(e.p.y)%53)-.5,(hh(j,5)-.5)*.6)*r*1.5
				var sz: float=(30.0+hh(j,7)*22.0)*(1.5 if big else 1.0)
				g.draw_clip("explosion_animation",(p+off-Vector2(sz/2,sz*.75)).floor(),Vector2(sz,sz),t,Color.WHITE,false)
			for j in range(6 if big else 3):
				var t: float=e.age-.12-j*.03
				if t<0:continue
				var q: Vector2=p+Vector2((hh(j,11)-.5)*r,-10-t*40)
				g.draw_circle(q,(6+t*18)*(1.4 if big else 1.0),Color(.22,.21,.21,.35*(1-t/.6)))
		"ch4_heal_splash","ch4_poison_splash":
			for j in range(12):
				var d:=Vector2.from_angle(j*2.39996);var q: Vector2=p+d*(6+k*(e.get("radius",26)))+Vector2(0,-sin(k*PI)*(8+j%5))
				g.draw_rect(Rect2(q.floor(),Vector2(2,2)),Color(.4,.7,.14,1-k) if e.kind=="ch4_poison_splash" else Color(1,.5,.2,1-k) if e.kind=="ch4_sky_blast" else Color(.9,.24,.25,1-k))
		"ch4_thorns":g.draw_line(p-Vector2(0,10),e.end+offset-Vector2(0,10),Color(.8,.8,.85,1-k),2)
		"ch4_revive":
			for j in range(24):
				var q: Vector2=p+Vector2(sin(j*2.4)*30*(1-k),-k*50+j%8)
				g.draw_rect(Rect2(q.floor(),Vector2(2,3)),Color(.6,.8,.34,1-k))
		"ch4_overload":pass
		_:return false
	return true

static func hud(g):
	var w=g.world;var a=w.arsenal
	if a.heart_buff>0:
		var beat: float=pow(maxf(0,sin(w.clock*19)),5)*.12
		if g.settings.flashes:
			g.draw_rect(Rect2(0,0,640,3),Color(.7,.03,.04,beat));g.draw_rect(Rect2(0,357,640,3),Color(.7,.03,.04,beat))
	var y:=286
	if w.items.has("heart_booster"):
		g.text_at("E  %d HP · %d"%[int(a.heart_price),a.heart_charges],Vector2(12,y),8,g.MUTED if w.hp>a.heart_price else Color(.9,.3,.25));y-=12
	if w.evolved.has("bat_wings") and w.items.has("bat_wings"):
		g.text_at("Пробел  "+("%d с"%ceili(a.bat_recharge) if a.bat_recharge>0 else "Рой"),Vector2(12,y),8,g.MUTED)

## IV uses exactly the same reveal as every solo chapter.
static func evolution(g):
	preload("res://scripts/ui/evolution_view.gd").draw(g,body)

static func hh(i: int, salt: int) -> float:
	return fposmod(sin(float(i) * 12.9898 + float(salt) * 78.233) * 43758.5453, 1.0)
