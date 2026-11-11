extends RefCounted
const SwordView = preload("res://scripts/spawn_sword_view.gd")
## Chapter III draws vanilla sampled parts, paused simulation effects and restrained UI.
const PURPLE=Color("bf82e6")
const Lighting=preload("res://scripts/ui/lighting.gd")
const Atmosphere=preload("res://scripts/ui/atmosphere.gd")
const FxView=preload("res://scripts/chapter_four_fx_view.gd")
var dragon_meta: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/end_dragon.json"))

func world(g):
	if not g.end_assets_loaded:g.ensure_end_assets()
	if g.qa_mode=="end_scale":scale_review(g);return
	var w=g.world
	var offset=Vector2(320,180)-w.camera().floor()
	if w.stage=="survival" and g.settings.get("camera_lead",false):offset-=g.cam_lead.round()
	if w.shake>0 and g.settings.shake and w.state=="RUNNING":offset+=Vector2(sin(w.clock*75),cos(w.clock*87)).round()*2
	if g.settings.shake:offset+=w.fx.kick.round()
	ground(g,offset)
	FxView.floor_layer(g,offset)
	loop_traces(g,offset)
	for h in w.hazards:
		if h.wait<=0:continue
		var p: Vector2=h.p+offset;var alpha=.4+.35*(1-h.wait/h.get("total",1))
		if h.get("kind","")=="end_cut":
			var end: Vector2=h.end+offset;var side=p.direction_to(end).orthogonal()*h.radius
			g.draw_colored_polygon(PackedVector2Array([p+side,end+side,end-side,p-side]),Color(.55,.25,.7,.13))
			g.draw_line(p+side,end+side,Color(.8,.5,.95,alpha),1);g.draw_line(p-side,end-side,Color(.8,.5,.95,alpha),1)
			if h.get("echo",false):
				g.draw_actor("endersteve_final",p,p.direction_to(end),0,false,Color(.7,.4,1,.4),"windup",1,{"state":"windup","time":.16*(1-h.wait/h.total)})
			continue
		if h.get("kind","")=="end_bolt":
			var k: float=1-h.wait/h.total
			for j in range(8):
				var a0: float=j*TAU/8+k*.6
				g.draw_line(p+Vector2.from_angle(a0)*Vector2(h.radius,h.radius*.55),p+Vector2.from_angle(a0)*Vector2(h.radius,h.radius*.55)*(1-.35*k),Color(.95,.7,1,alpha),2)
			g.oval(p,Vector2(h.radius,h.radius*.55)*k,Color(.7,.3,1,.2))
			g.draw_line(p-Vector2(0,200),p-Vector2(0,200-200*k*k),Color(.85,.6,1,.25*k),1)
			continue
		g.draw_arc(p,h.radius,0,TAU,32,Color(.8,.5,.95,alpha),1)
		g.oval(p,Vector2(h.radius,h.radius*.6),Color(.6,.25,.8,.12))
	for e in w.effects:
		if e.kind in ["friendly_breath","dragon_cloud"]:effect(g,e,offset)
	if w.stage not in ["survival","end_arrival","departure"]:
		portal(g,offset)
		for t in w.crystals:crystal_base(g,t,offset)
	for o in w.orbs:
		var p: Vector2=o.p+offset
		if not Rect2(-8,-8,656,376).has_point(p):continue
		var frame=0 if o.value<5 else (3 if o.value<30 else 6)
		var pulse=.78+.22*sin(w.clock*5+o.p.x)
		g.oval(p,Vector2(4,2),Color(.3,.8,.2,.12*pulse))
		g.draw_texture_rect_region(g.textures.experience_orb,Rect2((p-Vector2(4,5)).floor(),Vector2(8,8)),Rect2((frame%4)*16,(frame/4)*16,16,16),Color(.45+.25*pulse,1,.2,1))
	SwordView.draw(g,offset)
	var actors=[]
	for p in w.props:
		if p.type=="pumpkin" and p.hp<=0:continue
		if w.visible(p.p,90):actors.append({"y":p.p.y,"type":"prop","obj":p})
	for m in w.mobs:
		if m.kind in ["end_dragon","arena_crystal"]:continue
		if w.visible(m.p,90):actors.append({"y":m.p.y,"type":"mob","obj":m})
	actors.append({"y":w.player.y,"type":"player"})
	for o in w.loot:actors.append({"y":o.p.y,"type":"loot","obj":o})
	for mark in w.landmarks:
		if w.visible(mark.p,140):actors.append({"y":mark.p.y,"type":"landmark","obj":mark})
	actors.sort_custom(func(a,b):return a.y<b.y)
	for a in actors:
		match a.type:
			"prop":
				var p: Vector2=a.obj.p+offset
				if a.obj.type=="pumpkin":g.sprite("chorus_"+str(a.obj.id%3),p-Vector2(28,58),Vector2(56,64),Color(1,1,1,.48) if absf(w.player.x-a.obj.p.x)<20 and w.player.y<a.obj.p.y and w.player.y>a.obj.p.y-55 else Color.WHITE)
				else:
					g.sprite("end_ruin_"+str(a.obj.id%3),p-Vector2(28,80))
			"mob":
				var m=a.obj;var p: Vector2=m.p+offset
				if "steve" in m.kind:
					end_particles(g,p,w.clock,float(m.id),14 if m.kind=="endersteve_final" else 7,21 if m.kind=="endersteve_final" else 14)
				if m.kind=="endersteve_final":aura(g,m,p)
				if m.kind=="endersteve_final" and m.phase=="skyfall":
					skyfall(g,m,offset)
				elif m.kind=="endersteve_final" and m.phase=="leap":
					g.oval(p,Vector2(8,3),Color(0,0,0,.35))
					pose(g,"end_duel_leap",p-Vector2(0,m.altitude),m.charge,clampf(m.pose_age,0,1))
				else:g.draw_actor(m.kind,p,m.visual_dir,m.animation,m.moving,Color(1.8,1.8,1.8) if g.settings.flashes and m.flash>0 else Color.WHITE,m.phase,1,m.visual)
				if m.kind=="endersteve":
					g.draw_rect(Rect2(p-Vector2(19,35),Vector2(38,3)),Color("333333"));g.draw_rect(Rect2(p-Vector2(19,35),Vector2(38*maxf(0,m.hp)/m.max_hp,2)),Color("aaaaaa"))
				if m.kind=="endersteve_final" and m.phase=="cast":
					var hand=p+m.dir*8-Vector2(0,13)
					for j in range(4):
						var q=hand+Vector2.from_angle(j*PI/2+g.world.clock*2)*(9+sin(g.world.clock*5)*2)
						g.draw_line(q-m.dir.orthogonal()*2,q+m.dir.orthogonal()*2,Color(.8,.4,1,.6),1)
				if m.phase=="windup" and "steve" in m.kind and m.get("pattern",0) in [0,3]:
					var v: Vector2=m.charge;g.draw_line(p,p+v*160,Color(.8,.6,.9,.4),2)
				if m.phase=="cleave_windup":
					g.draw_arc(p,75,m.charge.angle()-1.45,m.charge.angle()+1.45,24,Color(.8,.6,.9,.6),1)
			"player":player(g,offset)
			"landmark":
				var q: Vector2=a.obj.p+offset
				g.oval(q+Vector2(0,4),Vector2(60,12),Color(0,0,0,.3))
				g.sprite("end_city",(q-Vector2(64,94)).floor())
			"loot":
				var o=a.obj;var p: Vector2=o.p+offset
				g.oval(p,Vector2(6,2),Color(0,0,0,.35));g.item_icon(o.kind,p-Vector2(8,16+sin(w.clock*3)*2))
	for b in w.explosives:
		var p: Vector2=b.p+offset
		g.sprite("bed_ground" if b.kind=="bed" else "tnt_ground",p-Vector2(20 if b.kind=="bed" else 12,23 if b.kind=="bed" else 24+b.get("height",0)))
	for m in w.mobs:
		if m.kind=="end_dragon":dragon(g,m,offset)
	for b in w.projectiles:
		if not projectile(g,b,offset):g.draw_projectile(b,offset)
	if not w.echo.is_empty():echo_scene(g,offset)
	FxView.air_layer(g,offset)
	for e in w.effects:
		if e.kind in ["friendly_breath","dragon_cloud"]:continue
		if not effect(g,e,offset) and not g.nether_renderer.effect(g,e,offset):g.draw_effect(e,offset)
	for pool in [w.particles,w.pixels]:
		for p in pool:g.draw_rect(Rect2((p.p+offset).floor(),Vector2.ONE*p.get("size",2)),Color(p.color,clampf(p.life/.2,0,1)))
	Atmosphere.collect(g,offset)
	FxView.lights(g)
	Lighting.draw(g,offset)
	Atmosphere.after_lighting(g,offset)
	gust_streaks(g)
	cinematic(g,offset)

func scale_review(g):
	g.draw_rect(Rect2(0,0,640,360),Color("242027"))
	g.centered("Стив и ЭндерСтив · одинаковый масштаб",24,8,Color.WHITE)
	for row in range(3):
		var state=["idle","walk","windup"][row]
		for col in range(3):
			var direction=[Vector2.DOWN,Vector2.UP,Vector2.RIGHT][col]
			var base=Vector2(116+col*205,113+row*105)
			g.draw_line(base-Vector2(70,0),base+Vector2(70,0),Color("555555"),1)
			g.draw_actor("steve",base-Vector2(35,0),direction,0,state=="walk",Color.WHITE,"walk",1,{"state":state,"time":.12})
			g.draw_actor("endersteve_final",base+Vector2(35,0),direction,0,state=="walk",Color.WHITE,"walk",1,{"state":state,"time":.12})
			g.text_at("Стив",base+Vector2(-49,17),8,Color("aaaaaa"))
			g.text_at("ЭндерСтив",base+Vector2(8,17),8,Color("aaaaaa"))

func ground(g, offset: Vector2):
	var w=g.world
	abyss(g,offset)
	if w.stage in ["survival","end_arrival","departure"]:
		var cam: Vector2=-offset+Vector2(320,180)
		# Exposed edges show the stone thickness above the void.
		var tile=Vector2i((cam-Vector2(336,196))/16)
		for y in range(tile.y,tile.y+26):
			for x in range(tile.x,tile.x+44):
				var p=Vector2(x*16+8,y*16+8)
				if w.on_land(p) and not w.on_land(p+Vector2(0,16)):
					# A tall cliff face that sinks into the void, darker with depth.
					for k in range(4):
						var shade=.46-k*.1
						g.sprite("end_stone_tile",p+offset+Vector2(-8,6+k*12),Vector2(16,16),Color(shade,shade*.93,shade*.9))
		# One pixel-aligned world transform for the surface, exposed edges and actors.
		g.sprite("end_island",offset)
	else:
		var r: Rect2=Rect2(w.END_ARENA.position+offset,w.END_ARENA.size)
		g.draw_texture_rect(g.textures.end_stone_tile,r,true)
		for side in [0,1]:
			var y=r.position.y+(r.size.y if side else 0)
			g.draw_texture_rect(g.textures.end_obsidian,Rect2(r.position.x,y,r.size.x,4),true)

## The abyss: deep violet sky, drifting nebulae and two parallax star layers.
## Void gust: faint streaks warn of the direction, then a dense rush of wind.
func gust_streaks(g):
	var w=g.world
	if w.gust.is_empty() or w.gust.phase=="idle" or w.stage!="survival":return
	var dir: Vector2=w.gust.dir
	var warn: bool=w.gust.phase=="warn"
	var strength: float=clampf(w.gust.age/1.4,0,1) if warn else 1.0-clampf(w.gust.age/1.1,0,1)*.6
	var count=18 if warn else 44
	for j in range(count):
		var lane=fposmod(j*97.3,700.0)-30.0
		var travel=fposmod(w.clock*(260.0 if warn else 620.0)+j*131.7,900.0)-130.0
		var base=Vector2(320,180)+dir*(travel-450.0)+dir.orthogonal()*(lane-350.0)
		var length=10.0 if warn else 26.0+j%3*6
		g.draw_line(base,base+dir*length,Color(.9,.82,1,(.25 if warn else .5)*strength),1)
	if warn:
		var tip=Vector2(320,180)+dir*120
		g.draw_colored_polygon(PackedVector2Array([tip+dir*10,tip-dir*6+dir.orthogonal()*7,tip-dir*6-dir.orthogonal()*7]),Color(.85,.6,1,.55*strength))

func abyss(g, offset: Vector2):
	var clock: float=g.world.clock
	g.draw_rect(Rect2(0,0,640,360),Color("0d0a16"))
	for j in range(7):
		var p=Vector2(fposmod(j*211.3+offset.x*.08,900)-130,fposmod(j*131.7+offset.y*.08,560)-100)
		for k in range(5):g.oval(p,Vector2(120,70)*(1-k*.17)*(.7+j%3*.2),Color(.32,.1,.45,.035))
	for j in range(140):
		var p=Vector2(fposmod(j*73.17+offset.x*.15,640),fposmod(j*37.73+offset.y*.15,360))
		g.draw_rect(Rect2(p.floor(),Vector2.ONE),Color(.5,.4,.62,.18+.12*sin(clock*.5+j)))
	for j in range(46):
		var p=Vector2(fposmod(j*151.9+offset.x*.4,660)-10,fposmod(j*89.3+offset.y*.4,380)-10).floor()
		var twinkle=.45+.4*sin(clock*(1.3+j%4*.4)+j*1.7)
		g.draw_rect(Rect2(p,Vector2.ONE),Color(.92,.85,1,twinkle))
		if j%9==0:
			g.draw_rect(Rect2(p+Vector2(-1,0),Vector2(3,1)),Color(.85,.7,1,twinkle*.45))
			g.draw_rect(Rect2(p+Vector2(0,-1),Vector2(1,3)),Color(.85,.7,1,twinkle*.45))

func crystal_base(g, t: Dictionary, offset: Vector2):
	var p: Vector2=t.p+offset
	g.oval(p+Vector2(0,4),Vector2(18,5),Color(0,0,0,.32))
	g.sprite("end_obsidian",p-Vector2(12,3),Vector2(24,16))
	g.sprite("end_obsidian",p-Vector2(12,7),Vector2(24,6),Color(1.2,1.2,1.2))
	# Tally marks scratched into the obsidian: someone has counted his days here.
	var groups: int=3+int(t.id)%3
	for j in range(groups):
		var q: Vector2=p+Vector2(-10+j*5,4)
		for k in range(4 if j<groups-1 else 2+int(t.id)%3):g.draw_line(q+Vector2(k,0),q+Vector2(k,3),Color(.75,.55,.9,.55),1)
		if j<groups-1:g.draw_line(q+Vector2(-1,3),q+Vector2(4,0),Color(.75,.55,.9,.55),1)
	if not t.alive:return
	var top=p-Vector2(0,16+sin(g.world.clock*3+float(t.id))*.9)
	g.draw_set_transform(top,sin(g.world.clock*.8)*.08)
	g.sprite("end_crystal_ground",-Vector2(20,25));g.draw_set_transform(Vector2.ZERO)
	for m in g.world.mobs:
		if m.kind=="end_dragon":
			var end: Vector2=m.p+offset-Vector2(0,m.altitude+35)
			# The healing link must read at a glance: glow, pulsing core and energy flowing to the dragon.
			var pulse=.5+.5*sin(g.world.clock*7+float(t.id))
			g.draw_line(top,end,Color(.7,.3,.95,.14+pulse*.08),7)
			g.draw_line(top,end,Color(.85,.55,1,.35+pulse*.15),3)
			g.draw_line(top,end,Color(1,.9,1,.75),1)
			for j in range(5):
				var k=fposmod(g.world.clock*.9+j*.2+float(t.id)*.13,1)
				var q: Vector2=top.lerp(end,k)
				g.draw_rect(Rect2(q.floor()-Vector2.ONE,Vector2(3,3)),Color(1,.8,1,.9*(1-k*.5)))
			break

func end_particles(g, p: Vector2, time: float, seed_value: float, count: int, radius: float):
	for j in range(count):
		var phase=fposmod(time*.6+j*.147+seed_value*.11,1)
		var q=p+Vector2(sin(j*2.4+time*.4)*radius*phase,-phase*(radius*2)+sin(j)*5)
		g.draw_rect(Rect2(q.floor(),Vector2.ONE*(1+j%2)),Color(.68,.25,.9,(1-phase)*.8))

func dragon(g, m: Dictionary, offset: Vector2, death: float=0):
	var w=g.world;var p: Vector2=m.p+offset-Vector2(0,m.altitude)
	var row=posmod(roundi(atan2(-m.dir.x,m.dir.y)/TAU*dragon_meta.directions),int(dragon_meta.directions))
	var state="perch" if m.phase in ["perch","slump"] else "roar" if m.phase=="rage" else "flight"
	var clip: Dictionary=dragon_meta.states[state]
	var frame=int(clip.start)+int(w.clock*clip.fps*(1.35 if m.phase in ["rush","takeoff"] else 1.0))%int(clip.count)
	var size=Vector2(dragon_meta.frame_size[0],dragon_meta.frame_size[1]);var anchor=Vector2(dragon_meta.anchor[0],dragon_meta.anchor[1])
	g.oval(m.p+offset,Vector2(74,17),Color(0,0,0,.28))
	var tint=Color(1.6,1.4,1.6,1-death) if g.settings.flashes and m.flash>0 else Color(1,1,1,1-death)
	g.draw_texture_rect_region(g.textures.end_dragon_atlas,Rect2((p-anchor*.9).floor(),size*.9),Rect2(Vector2(frame*size.x,row*size.y),size),tint)
	if m.get("phase","")=="slump":
		var head: Vector2=p+m.dir*58-Vector2(0,22)
		for j in range(5):
			var a0: float=w.clock*4+j*TAU/5
			g.draw_rect(Rect2((head+Vector2(cos(a0)*14,sin(a0)*5)).floor(),Vector2(2,2)),Color(1,.85,1,.9))

func player(g, offset: Vector2):
	var w=g.world;var p: Vector2=w.player+offset
	if w.stage=="hand_pickup":
		pose(g,"end_player_pickup",p,w.facing,clampf(w.stage_age/.6,0,1));return
	if w.stage=="sit" or (w.stage=="to_edge" and w.player==w.seats()[1]) or (w.stage=="restore" and w.stage_age<1.0):
		seated(g,"steve",p,w.clock);return
	if w.stage in ["clash","down"] and not w.npc.is_empty():
		brawler(g,"steve",p,w.facing,w.npc.get("side",Vector2.RIGHT).x,0.0);return
	if w.stage=="exit_jump":
		var a: float=w.stage_age;var progress=smoothstep(.18,1.15,a);var fall=smoothstep(1.1,2.4,a)
		p=w.jump_start.lerp(w.portal_position,progress)+offset-Vector2(0,sin(progress*PI)*34)
		g.oval(w.jump_start.lerp(w.portal_position,progress)+offset,Vector2(7*(1-fall),2),Color(0,0,0,.25*(1-fall)))
		g.draw_set_transform(p+Vector2(0,fall*18),fall*.25,Vector2.ONE*(1-fall*.96))
		pose(g,"end_player_jump",Vector2.ZERO,w.facing,clampf(a/1.4,0,1),Color(1,1,1,1-fall));g.draw_set_transform(Vector2.ZERO)
		end_particles(g,w.portal_position+offset,w.clock,4,18,18);return
	if w.fall_age>=0:
		var t=clampf(w.fall_age/.85,0,1)
		g.draw_set_transform(p+Vector2(0,t*22),t*.5,Vector2.ONE*(1-t*.95))
		g.draw_actor("steve",Vector2.ZERO,w.facing,w.clock,false,Color(1,1,1,1-t),"hurt",1,{"state":"hurt","time":.08});g.draw_set_transform(Vector2.ZERO);return
	var high: float=w.elevation()
	g.oval(p,Vector2(7,2),Color(0,0,0,.25))
	p-=Vector2(0,high)
	if w.dash_left>0:
		for j in range(9):
			var q=p-w.dash_direction*(12+j*4)+w.dash_direction.orthogonal()*sin(j*1.7+w.clock*25)*3
			g.draw_rect(Rect2(q.floor(),Vector2.ONE*(1+j%2)),Color(1,.65,.3,.75-j*.07) if w.rocket else Color(.75,.6,1,.3-j*.025))
	var gear="idle";var phase="idle";var progress=0.0
	var active=w.player_visual.get("weapon","")
	if w.stage=="rekindle":gear="hand";phase="windup";progress=clampf(w.stage_age/2,0,1)
	elif w.rocket:gear="rocket";progress=fposmod(w.clock,1)
	elif w.flight>0:gear="elytra";progress=fposmod(w.clock,1)
	elif w.dash_left>0:gear=w.db.equipment_icon("spear",w.build.get("spear",1),w.evolved.has("spear"));phase="attack";progress=.5
	elif w.jump_age>=0:gear="mace";phase="windup" if w.jump_age<.5 else "attack";progress=clampf(w.jump_age/.5,0,1) if w.jump_age<.5 else clampf((w.jump_age-.5)/.45,0,1)
	elif active in w.END_WEAPONS and active!="shield":
		gear=w.db.equipment_icon(active,w.build.get(active,1),w.evolved.has(active)) if active=="spear" else active
		var pose: Dictionary=w.weapon_visuals.get(active,{})
		phase=pose.get("state","idle");progress=pose.get("progress",0.0)
	var guard=w.build.has("shield") and w.shield_timer<=0
	if gear=="idle" and not guard:
		g.draw_actor("steve",p,w.facing,w.clock,w.player_moving,g.invulnerable_tint(),"walk",1,w.player_visual);g.draw_held_weapons(p)
	else:
		var frame=mini(3,int(progress*4))+(4 if phase=="attack" else 8 if phase=="recover" else 0)
		if gear in ["elytra","rocket","idle"]:frame=int(w.clock*12)%12
		if w.player_moving and gear not in ["elytra","rocket"]:frame+=12
		var row=w.animation.direction_row(w.facing);var flip=row==2 and w.facing.x<0
		var name="end_held_"+gear+("_guard" if guard else "")
		g.draw_set_transform(p,0,Vector2(-1,1) if flip else Vector2.ONE)
		g.draw_texture_rect_region(g.textures[name],Rect2(-32,-57,64,64),Rect2(frame*64,row*64,64,64),g.invulnerable_tint())
		g.draw_set_transform(Vector2.ZERO)
		if gear=="idle" and active not in w.END_WEAPONS:g.draw_held_weapons(p)
	if w.jump_age>=0:
		for j in range(5):
			var q=p+Vector2(sin(w.clock*7+j*2)*7,j*3)
			g.draw_rect(Rect2(q.floor(),Vector2(2,1)),Color(.8,.9,1,.45))
	if w.stage=="rekindle" and w.stage_age>.6:
		var strength=sin(clampf((w.stage_age-.6)/2.2,0,1)*PI)
		g.draw_line(p+Vector2(8,-20),w.portal_position+offset,Color(.8,.4,1,strength*.8),1);end_particles(g,w.portal_position+offset,w.clock,4,25,40)

func pose(g, name: String, p: Vector2, direction: Vector2, progress: float, tint: Color=Color.WHITE):
	var row=g.world.animation.direction_row(direction);var flip=row==2 and direction.x<0
	if flip:g.draw_set_transform(p,0,Vector2(-1,1));p=Vector2.ZERO
	g.draw_texture_rect_region(g.textures[name],Rect2((p-Vector2(32,57)).floor(),Vector2(64,64)),Rect2(mini(15,int(progress*16))*64,row*64,64,64),tint)
	if flip:g.draw_set_transform(Vector2.ZERO)

func portal(g, offset: Vector2):
	var w=g.world
	if w.stage in ["dragon_arrival","dragon","departure"]:return
	var p: Vector2=w.portal_position+offset
	var broken=w.stage in ["last_arrival","last_duel","endsteve_death","yield","approach","clash","down","to_edge","sit"] or (w.stage=="betrayal" and w.stage_age>=w.end_boss.BETRAYAL_IMPACT) or (w.stage=="restore" and w.stage_age<3.6)
	for y in range(-2,3):
		for x in range(-2,3):
			if x*x+y*y>6:continue
			var home=Vector2(x*12-8,y*7-5)
			var rubble=home*1.8+Vector2(sin(x*13+y)*16,cos(x+y*3)*11)
			if broken:home=rubble
			elif w.stage=="rekindle":home=rubble.lerp(home,smoothstep(.5,1.8,w.stage_age))
			elif w.stage=="restore":home=rubble.lerp(home,smoothstep(3.6,5.8,w.stage_age))
			g.sprite("end_bedrock",p+home,Vector2(12,7) if broken else Vector2(16,12),Color(.55,.5,.6) if broken else Color(.7,.7,.75))
	if not broken:
		if w.portal_lit:g.draw_texture_rect(g.textures.end_portal,Rect2(p-Vector2(19,10),Vector2(38,20)),true)
		for y in range(3):g.sprite("end_bedrock",p-Vector2(6,15+y*9),Vector2(12,12))
		if w.stage in ["dragon_death","exit_portal"] or (w.stage=="betrayal" and w.stage_age<w.end_boss.BETRAYAL_IMPACT):g.sprite("end_egg_model",p-Vector2(14,61))
	if w.portal_lit:end_particles(g,p,w.clock,9,18,24)

func projectile(g, b: Dictionary, offset: Vector2) -> bool:
	var p: Vector2=b.p+offset-Vector2(0,9)
	match b.kind:
		"shulker_bullet":
			# Pale bullets vanish on pale end stone: a ground shadow, a dark core,
			# a pulsing violet halo and a two-tone trail keep them readable.
			g.oval(b.p+offset+Vector2(0,2),Vector2(5,2),Color(.08,0,.12,.45))
			var count: int=b.trail.size()
			for i in range(count):
				var k=float(i+1)/count
				var q: Vector2=(b.trail[i]+offset-Vector2(0,9)).floor()
				g.draw_rect(Rect2(q-Vector2.ONE,Vector2(3,3)),Color(.3,.06,.42,k*.5))
				g.draw_rect(Rect2(q,Vector2.ONE),Color(1,.8,1,k*.85))
			var pulse=.5+.5*sin(b.age*12)
			g.draw_circle(p,9+pulse*2,Color(.62,.22,.85,.26+pulse*.16))
			g.draw_circle(p,6.5,Color(.2,.04,.28,.85))
			g.draw_set_transform(p,b.age*5);g.sprite("shulker_bullet",Vector2(-6,-6),Vector2(12,12));g.draw_set_transform(Vector2.ZERO)
		"dragon_fireball":
			end_particles(g,p,b.age,3,5,12);g.sprite("dragon_fireball",p-Vector2(8,8),Vector2(16,16))
		"end_blade":
			for j in range(4):
				var q=p-b.dir*(j+1)*5
				g.draw_line(q-b.dir*4,q,Color(.65,.25,.95,.3-j*.06),2)
			g.draw_set_transform(p,b.dir.angle()+PI/4)
			g.draw_clip("sword_netherite_enchanted",Vector2(-8,-8),Vector2(16,16),b.age)
			g.draw_set_transform(Vector2.ZERO)
		"end_bullet":
			g.draw_line(p-b.dir*9,p,Color(.55,.2,.8,.35),3);g.draw_rect(Rect2(p-Vector2(2,2),Vector2(4,4)),Color("dfafff"));g.draw_rect(Rect2(p-Vector2(1,1),Vector2(2,2)),Color.WHITE)
		"enemy_arrow","slow_arrow","poison_arrow":
			g.draw_set_transform(p,b.dir.angle()+PI/4);g.sprite("icon_arrow",Vector2(-8,-8),Vector2(16,16),Color(.65,.8,1) if b.kind=="slow_arrow" else Color(.5,1,.4) if b.kind=="poison_arrow" else Color.WHITE);g.draw_set_transform(Vector2.ZERO)
		_:return false
	return true

func cloud(g, p: Vector2, radius: float, age: float, alpha: float):
	for j in range(22):
		var phase=fposmod(age*.6+j*.17,1);var dir=Vector2.from_angle(j*2.399+age*.13)
		var q=p+dir*sqrt(float(j)/22)*radius-Vector2(0,phase*17)
		g.draw_rect(Rect2(q.floor(),Vector2(5+j%4,3+j%3)),Color(.48+.1*sin(j),.16,.65,alpha*(1-phase)*.4))
		if j%3==0:g.draw_rect(Rect2((q-Vector2(0,5)).floor(),Vector2.ONE*2),Color(.8,.45,1,alpha*(1-phase)*.5))

func effect(g, e: Dictionary, offset: Vector2) -> bool:
	var p: Vector2=e.p+offset;var t=clampf(e.age/e.total,0,1)
	match e.kind:
		"friendly_breath","dragon_cloud":cloud(g,p,e.radius,e.age,minf(1,e.life/.4))
		"end_teleport","brood_spawn","ender_rage","dragon_roar":end_particles(g,p,e.age*2,3,24,e.get("radius",36))
		"end_pearl":
			var q: Vector2=e.start.lerp(e.end,t)+offset-Vector2(0,sin(t*PI)*40+9)
			g.sprite("icon_ender_pearl",q-Vector2(4,4),Vector2(8,8));end_particles(g,q,e.age,2,4,9)
		"placed_end_crystal":
			g.sprite("end_obsidian",p-Vector2(12,5),Vector2(24,15));g.sprite("end_crystal_ground",p-Vector2(20,43),Vector2(40,48),Color(1.3,1,1.4) if e.age>.4 else Color.WHITE)
		"mace_impact","crystal_blast","dragon_impact":
			for j in range(16):
				var dir=Vector2.from_angle(j*2.39996);var q=p+dir*e.radius*t-Vector2(0,sin(t*PI)*float(10+j%4*8))
				g.sprite("end_obsidian" if e.kind=="crystal_blast" else "end_stone_tile",q-Vector2(2,2),Vector2.ONE*(5-t*3),Color(1,1,1,1-t))
				g.draw_line(q-dir*7,q,Color(.9,.7,1,1-t),1)
			if t<.4:g.draw_clip("explosion_animation",p-Vector2(18,30),Vector2(36,36),e.age,Color(1,.75,1,1-t))
		"ender_slash","stick_swing":
			var dir: Vector2=e.direction;var radius: float=e.radius;var angle=dir.angle()+lerpf(-1.5,1.3,t)
			for j in range(4):
				g.draw_arc(p-Vector2(0,12),radius*(.8+j*.04),angle-.5,angle+.3,12,Color(.85,.55,1,(1-t)*(.75-j*.15)),1)
			if e.kind=="ender_slash":
				g.draw_set_transform(p-Vector2(0,16),dir.angle())
				g.draw_clip("sweep_animation",Vector2(-radius*.55,-radius*.4),Vector2(radius*1.4,radius*.8),e.age,Color(.9,.55,1,(1-t)*.8),false)
				g.draw_set_transform(Vector2.ZERO)

		"end_bolt":
			# A purple bolt from above, branching where it lands.
			var last: Vector2=p-Vector2(0,220)
			for j in range(1,9):
				var q: Vector2=p-Vector2(0,220-j*27.5)+Vector2(sin(j*7.1+e.age*40)*7*(1-j/9.0),0)
				g.draw_line(last,q,Color(.6,.25,.9,1-t),5);g.draw_line(last,q,Color(1,.92,1,1-t),2);last=q
			for j in range(5):g.draw_line(p,p+Vector2.from_angle(j*TAU/5+.3)*Vector2(24,12)*(.5+t),Color(.9,.7,1,1-t),1)
		"spear_thrust":
			var dir: Vector2=e.direction;var reach: float=e.range*smoothstep(0,.35,t)
			g.draw_line(p-Vector2(0,10),p-Vector2(0,10)+dir*reach,Color(.85,.75,1,(1-t)*.5),5)
			g.draw_line(p-Vector2(0,10),p-Vector2(0,10)+dir*reach,Color(1,1,1,1-t),1)
		"shield_impact":
			for j in range(7):g.draw_line(p,p+Vector2.from_angle(j*TAU/7)*t*17,Color(1,1,1,1-t),1)
		"end_afterimage":
			g.draw_actor(e.actor,p,e.direction,0,false,Color(.7,.35,1,(1-t)*.35),"walk",1,e.pose)
		"end_aftershock","end_fall","end_enemy_fall":pass
		"end_cut":
			var end: Vector2=e.end+offset
			var tip=p.lerp(end,smoothstep(0,.18,e.age))
			g.draw_line(p,tip,Color(.5,.15,.85,(1-t)*.5),e.radius*1.7)
			g.draw_line(p,tip,Color(.9,.65,1,1-t),2)
			if e.get("echo",false):
				g.draw_actor("endersteve_final",tip,p.direction_to(end),0,false,Color(.8,.5,1,(1-t)*.65),"slash",1,{"state":"slash","time":t*.52})
		"ender_death_burst":
			for j in range(35):
				var dir=Vector2.from_angle(j*2.39996)
				var q=p+dir*sqrt(t)*(45+j%7*11)
				g.draw_line(q-dir*(2+(1-t)*11),q,Color(.8,.5,1,(1-t)*.65),1)
				g.draw_rect(Rect2(q.floor(),Vector2.ONE*(1+j%2)),Color(.85,.65,1,(1-t)*.8))
			if e.age<.22 and g.settings.flashes:g.draw_rect(Rect2(0,0,640,360),Color(.85,.7,1,(1-e.age/.22)*.22))
		"portal_shatter":
			var travel=pow(e.age,.8)
			for j in range(24):
				var dir=Vector2.from_angle(j*2.39996)
				var q=p+dir*travel*(22+j%5*12)-Vector2(0,maxf(0,e.age*(70+j%3*12)-e.age*e.age*48))
				var size=8 if j%3 else 5
				g.draw_set_transform(q,j+travel*(j%3-1)*2)
				g.sprite("end_bedrock" if j%4 else "end_egg",Vector2.ONE*(-size/2.0),Vector2.ONE*size,Color(1,1,1,1-smoothstep(.6,1,t)));g.draw_set_transform(Vector2.ZERO)
			if e.age<.7:
				g.oval(p,Vector2(120,50)*smoothstep(0,.7,e.age),Color(.7,.3,1,(1-e.age/.7)*.18))
			end_particles(g,p,e.age*2,11,42,65)
		_:return false
	return true

func cinematic(g, offset: Vector2):
	var w=g.world;var a: float=w.stage_age
	if w.stage=="betrayal":g.draw_rect(Rect2(0,0,640,360),Color(.04,0,.06,.18+sin(clampf(a/6.4,0,1)*PI)*.3))
	elif w.stage=="endsteve_death":g.draw_rect(Rect2(0,0,640,360),Color(.03,0,.05,sin(clampf(a/7.6,0,1)*PI)*.42))
	if w.stage=="dragon_death" and not w.defeated_boss.is_empty():
		var m=w.defeated_boss.duplicate(true);m.altitude=32+a*10
		dragon(g,m,offset,smoothstep(0,4.5,a))
		var p: Vector2=m.p+offset-Vector2(0,m.altitude+15)
		for j in range(18):
			var angle=j*2.39996+a*.13;var r=(35+j%5*13)*smoothstep(0,2.5,a);var dir=Vector2.from_angle(angle)
			g.draw_colored_polygon(PackedVector2Array([p,p+dir*r+dir.orthogonal()*5,p+dir*r-dir.orthogonal()*5]),Color(.8,.45,1,sin(clampf(a/4.5,0,1)*PI)*.35))
	if w.stage=="betrayal":betrayal(g,offset,a)
	if w.stage=="sit":closeup(g,a)
	if w.stage in ["clash","down"] and not w.npc.is_empty():brawl_close(g,a)
	if w.stage=="dragon_arrival":title_card(g,a,"ЭНДЕР-ДРАКОН","хозяин этого острова")
	var close_shot: bool=(w.stage=="sit" and a>=.6 and a<=w.end_boss.SIT_LENGTH-.6) or w.stage in ["clash","down"]
	if not w.npc.is_empty() and not close_shot:ender_npc(g,offset)
	if w.stage in ["end_arrival","departure","dragon_arrival","dragon_death","betrayal","last_arrival","endsteve_death","rekindle","exit_jump","yield","clash","down","to_edge","sit","restore"]:
		var bars=18.0
		if w.stage in ["dragon_arrival","last_arrival","end_arrival"]:bars*=1-smoothstep(1,3.9 if w.stage=="dragon_arrival" else 2.2,a)
		if w.stage=="endsteve_death":bars*=1-smoothstep(6.6,7.6,a)
		if w.stage in ["to_edge","sit"]:bars=26.0*smoothstep(0,1.5,a if w.stage=="to_edge" else 9.0)
		if w.stage=="restore":bars=26.0*(1-smoothstep(9.0,10.4,a))
		g.draw_rect(Rect2(0,0,640,bars),Color.BLACK);g.draw_rect(Rect2(0,360-bars,640,bars),Color.BLACK)
	if w.stage=="departure":g.draw_rect(Rect2(0,0,640,360),Color(0,0,0,smoothstep(.2,1.55,a)))
	elif w.stage in ["end_arrival","dragon_arrival"]:
		g.draw_rect(Rect2(0,0,640,360),Color(0,0,0,1-smoothstep(0,1.2,a)))
		if w.stage=="end_arrival" and a>.6:g.centered("Глава III · Край",95,16,Color(1,1,1,1-smoothstep(1.7,2.5,a)),true)
	elif w.stage=="exit_jump":g.draw_rect(Rect2(0,0,640,360),Color(0,0,0,smoothstep(2.2,3.4,a)))
	subtitles(g)

func hud(g):
	var w=g.world
	for m in w.mobs:
		if m.kind not in ["end_dragon","endersteve_final"]:continue
		var title: String="Эндер-дракон" if m.kind=="end_dragon" else "ЭндерСтив"
		# His name settles only after a moment: first he is just Steve.
		if m.kind=="endersteve_final" and w.stage=="last_duel" and w.stage_age<3.0:
			title="Стив" if w.stage_age<1.4 or int(w.clock*30)%5==0 else "ЭндерСтив"
		g.centered(title,41,8,Color.WHITE,true)
		g.draw_rect(Rect2(191,46,258,6),Color("333333"));g.draw_rect(Rect2(192,47,256*clampf(m.hp/m.max_hp,0,1),4),Color("9b739a"))
		if m.kind=="end_dragon":
			var count=w.crystals.filter(func(t):return t.alive).size()
			for i in range(6):g.sprite("icon_end_crystal",Vector2(294+i*9,58),Vector2(7,7),Color.WHITE if i<count else Color(.2,.2,.2))
	for i in range(3):
		var id=["elytra","ender_pearl","rocket"][i]
		if (id=="rocket" and not w.evolved.has("spear")) or (id!="rocket" and not w.items.has(id)):continue
		var cd=[w.flight_cooldown,w.pearl_cooldown,w.rocket_cooldown][i]
		var p=Vector2(12+i*48,300)
		g.sprite("icon_"+("firework" if id=="rocket" else id),p,Vector2(16,16),Color(.45,.45,.45) if cd>0 else Color.WHITE)
		g.text_at(str(ceili(cd)) if cd>0 else ["Пробел","E","Shift"][i],p+Vector2(-2,27),8,Color("aaaaaa"))
	if w.build.has("shield"):
		for i in range(int(w.db.stats("shield",w.build.shield,w.evolved.has("shield"),w.items).count)):
			g.draw_rect(Rect2(176+i*4,304,3,2),Color("dddddd") if i<w.shield_charges else Color("444444"))

func ending(g):
	var w=g.world;var t: float=w.stage_age
	g.sprite("end_teaser_ground",Vector2.ZERO)
	for j in range(11):
		var p=Vector2(j*67-20,141+(j%3)*27)
		g.sprite("tree_dead_"+str(j%3),p,Vector2(50,96),Color(.32,.22,.27))
	for j in range(24):
		var phase=fposmod(t*.08+j*.147,1)
		var p=Vector2(fposmod(j*79.7+sin(t+j)*4,640),320-phase*180)
		g.draw_rect(Rect2(p.floor(),Vector2.ONE),Color(.65,.15,.2,sin(phase*PI)*.35))
	g.draw_actor("steve",Vector2(320,266),Vector2.UP,t,false,Color(.7,.55,.6),"idle",1,{"state":"idle","time":t})
	# Dark edges retain visible red terrain under the hero and foreground.
	for i in range(10):
		g.draw_rect(Rect2(i*8,150,8,210),Color(0,0,0,.45*(1-i/10.0)))
		g.draw_rect(Rect2(632-i*8,150,8,210),Color(0,0,0,.45*(1-i/10.0)))
	g.centered("Глава IV",75,16,Color("aaaaaa"),true)
	var texture=g.textures.end_chapter_title
	var size: Vector2=texture.get_size();var origin=Vector2((640-size.x)/2,94)
	var tick=int(t*60);var glitch=posmod(tick,191) in [142,143,144,146,147,148]
	# Each horizontal slice is drawn once; short displaced bands keep the title readable.
	for y in range(0,int(size.y),3):
		var shift_value=0
		if glitch and y in [(posmod(tick,3)+1)*3,18]:shift_value=(3 if posmod(tick+y,2)==0 else -2)
		var rect=Rect2(origin+Vector2(shift_value,y),Vector2(size.x,3))
		var source=Rect2(0,y,size.x,3)
		if shift_value:
			g.draw_texture_rect_region(texture,Rect2(rect.position+Vector2(-2,0),rect.size),source,Color(.7,.15,.25,.55))
		g.draw_texture_rect_region(texture,rect,source,Color(.85,.75,.85) if shift_value else Color.WHITE)
	g.button(Rect2(199,263,242,27),"Продолжить","chapter_4")
	g.button(Rect2(199,304,242,27),"В меню","menu")

## Full body drawn lower so the legs hang over the rim of the island.
func seated(g, kind: String, p: Vector2, clock: float, tint: Color=Color.WHITE):
	var breath: float=round(sin(clock*1.6))*.5
	g.draw_actor(kind,p+Vector2(0,10+breath),Vector2.DOWN,0,false,tint,"idle",1,{"state":"idle","time":0.0})

func death_frame(g, p: Vector2, direction: Vector2, frame: int, tint: Color=Color.WHITE):
	var row=g.world.animation.direction_row(direction)
	var region:=Rect2(clampi(frame,0,47)*128,row*128,128,128)
	if row==2 and direction.x<0:
		g.draw_set_transform(p,0,Vector2(-1,1));g.draw_texture_rect_region(g.textures.end_finale_death,Rect2(-64,-100,128,128),region,tint);g.draw_set_transform(Vector2.ZERO)
	else:g.draw_texture_rect_region(g.textures.end_finale_death,Rect2(p-Vector2(64,100),Vector2(128,128)),region,tint)

const DISSOLVE_AT:=6.4

## The last exchange and lying side by side. `away` is the side each one falls to.
func brawler(g, kind: String, p: Vector2, dir: Vector2, away: float, phase_shift: float, S: float=1.0):
	var w=g.world;var a: float=w.stage_age;var e=w.end_boss
	var fall: float=0.0
	if w.stage=="clash":fall=smoothstep(e.CLASH_BREAK+.25,e.CLASH_BREAK+.8,a)
	else:fall=1.0-smoothstep(e.DOWN_RISE,e.DOWN_LENGTH-.2,a)
	var shadow: float=1.0+fall*.8
	g.oval(p+Vector2(away*fall*8,1)*S,Vector2(7*shadow,2+fall)*S,Color(0,0,0,.3))
	if fall<=0.0:
		var state:="idle";var t:=0.0
		for hit in e.CLASH_HITS:
			var d: float=a-hit+(.22 if phase_shift>0 else 0.0)
			if d>=-.18 and d<.25:state="attack" if d>=0 else "windup";t=maxf(0,d)
		if a>=e.CLASH_BREAK-.2:state="attack";t=a-e.CLASH_BREAK+.2
		var st: String="slash" if kind!="steve" and state=="attack" else state
		g.draw_actor(kind,p,dir,w.clock,false,Color.WHITE,st,S,{"state":st,"time":t})
		if kind=="steve" and S==1.0:g.draw_held_weapons(p)
		return
	# Down on the side, a breath that lifts the chest; rising with a wobble.
	var angle: float=away*PI/2*fall+(sin(w.clock*7)*.08*(1-fall) if w.stage=="down" and fall<1 else 0.0)
	var breath: float=round(sin(w.clock*1.8+phase_shift*3))*.5*fall*S
	g.draw_set_transform(p+Vector2(0,-breath),angle,Vector2.ONE)
	g.draw_actor(kind,Vector2.ZERO,Vector2.DOWN,0,false,Color(1,.95,.95) if kind=="steve" else Color.WHITE,"hurt",S,{"state":"hurt","time":.05,"airborne":true})
	g.draw_set_transform(Vector2.ZERO)
	if kind!="steve":end_particles(g,p-Vector2(0,4*S),w.clock,4,int(6*S),10*S)
	# The broken blade beside each of them.
	if not g.textures.has("icon_sword_iron"):g.load_texture("icon_sword_iron")
	if true:
		var q: Vector2=p+Vector2(-away*14,4)*S
		g.draw_set_transform(q,away*.9+phase_shift,Vector2.ONE*S)
		var tex=g.textures.get("icon_sword_iron")
		if tex:g.draw_texture_rect_region(tex,Rect2(-6,-6,10,10),Rect2(0,6,10,10),Color(.85,.85,.85))
		g.draw_set_transform(Vector2.ZERO)

## Close on the two of them for the exchange and while they lie there.
const BRAWL_CLOSE:=3.0
static var brawl_data: Dictionary={}

func brawl_assets(g) -> Dictionary:
	if brawl_data.is_empty():brawl_data=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_three_brawl.json"))
	for name in brawl_data.sprites:
		if not g.textures.has(name):g.load_texture(name)
	return brawl_data

## Which baked pose each of them is in at this moment of the scene.
func brawl_pose(w, ender: bool) -> Array:
	var e=w.end_boss;var a: float=w.stage_age
	if w.stage=="clash":
		var hits: Array=e.CLASH_HITS+[e.CLASH_BREAK]
		if a<hits[0]-.25:return ["guard",a,true]
		if a<e.CLASH_BREAK+.12:
			for h in hits:
				if a<h-.25:return ["clang",a,true]
				if a<h:return ["windup",(a-(h-.25))*1.2,false]
				if a<h+.18:return ["strike",(a-h)*1.6,false]
			return ["clang",a,true]
		if a<e.CLASH_BREAK+.55:return ["thrown",(a-e.CLASH_BREAK-.12)*1.4,false]
		var f: float=a-e.CLASH_BREAK-.55
		return ["fall",f*1.2,false] if f<.55 else ["lying",a,true]
	var rise: float=a-e.DOWN_RISE-(.45 if ender else 0.0)
	if rise<0:
		for l in e.DOWN_LINES:
			var mine: bool=(l[3]=="ender")==ender
			if mine and a>=l[0] and a<l[0]+l[2]:return ["lying_talk",a,true]
		return ["lying",a,true]
	if rise<1.9:return ["getup",rise*.85,false]
	return ["spent",a,true]

func brawl_fig(g, sheet: String, pose: Array, p: Vector2, flip: bool, S: float):
	var d: Dictionary=brawl_assets(g)
	var clip: Dictionary=d.poses[pose[0]]
	var fps: float=4.0 if pose[0] in ["lying","lying_talk","spent","guard","clang"] else 10.0
	var index: int=int(pose[1]*fps)
	index=index%int(clip.count) if pose[2] else clampi(index,0,int(clip.count)-1)
	var size:=Vector2(d.frame[0],d.frame[1]);var anchor:=Vector2(d.anchor[0],d.anchor[1])
	if not g.textures.has(sheet):return
	g.draw_set_transform(p.floor(),0,Vector2(-S if flip else S,S))
	g.draw_texture_rect_region(g.textures[sheet],Rect2(-anchor,size),Rect2((int(clip.start)+index)*size.x,0,size.x,size.y))
	g.draw_set_transform(Vector2.ZERO)

func brawl_close(g, a: float):
	var w=g.world;var e=w.end_boss;var S:=BRAWL_CLOSE
	var mid: Vector2=(w.player+w.npc.p)/2
	var c:=Vector2(320,250)
	var tile: Texture2D=g.textures.get("end_stone_tile")
	var origin: Vector2=c-mid*S
	if tile:
		var step: float=16*S
		var y: float=fposmod(origin.y,step)-step
		while y<360:
			var x: float=fposmod(origin.x,step)-step
			while x<640:
				g.draw_texture_rect(tile,Rect2(x,y,step,step),false,Color(.92,.9,.86))
				x+=step
			y+=step
	else:g.draw_rect(Rect2(0,0,640,360),Color(.86,.85,.62))
	g.draw_rect(Rect2(0,0,640,360),Color(.05,0,.08,.25))
	var side: float=w.npc.get("side",Vector2.RIGHT).x
	var steve: Vector2=c+(w.player-mid)*S;var ender: Vector2=c+(w.npc.p-mid)*S
	var sp: Array=brawl_pose(w,false);var ep: Array=brawl_pose(w,true)
	for who in [[steve,sp,side,"ch3_brawl_steve"],[ender,ep,-side,"ch3_brawl_ender"]]:
		var lying: bool=who[1][0] in ["lying","lying_talk","fall","getup"]
		g.oval(who[0]+Vector2(-who[2]*(14 if lying else 0),2)*S/3,Vector2(26 if lying else 16,5)*S/3,Color(0,0,0,.3))
	# The broken blades, where they landed.
	if w.stage=="down" or a>e.CLASH_BREAK+.6:
		if not g.textures.has("icon_sword_iron"):g.load_texture("icon_sword_iron")
		var tex=g.textures.get("icon_sword_iron")
		if tex:
			for k in [-1.0,1.0]:
				g.draw_set_transform((c+Vector2(k*20,10)*S/3*2.2).floor(),k*.7+.3,Vector2.ONE*S*.8)
				g.draw_texture_rect_region(tex,Rect2(-5,-5,9,9),Rect2(0,7,9,9),Color(.85,.85,.85))
				g.draw_set_transform(Vector2.ZERO)
	brawl_fig(g,"ch3_brawl_ender",ep,ender,side<0,S)
	brawl_fig(g,"ch3_brawl_steve",sp,steve,side>0,S)
	if not ep[0] in ["clang","guard","windup","strike"]:end_particles(g,ender-Vector2(0,30),w.clock,4,10,30)
	if w.stage=="clash":clash_sparks(g,(steve+ender)/2-Vector2(0,30*S/3*1.6),S/1.5)
	var black: float=0.0
	if w.stage=="clash":black=1-smoothstep(0,.3,a)
	else:black=smoothstep(e.DOWN_LENGTH-.5,e.DOWN_LENGTH-.05,a)
	if black>0:g.draw_rect(Rect2(0,0,640,360),Color(0,0,0,black))

## Sparks where the blades meet, then the iron flying apart.
func clash_sparks(g, mid: Vector2, S: float=1.0):
	var w=g.world;var a: float=w.stage_age;var e=w.end_boss
	for hit in e.CLASH_HITS:
		var d: float=a-hit
		if d<0 or d>.25:continue
		for i in range(10):
			var q: Vector2=mid+Vector2.from_angle(i*.63+hit)*d*90*S
			g.draw_rect(Rect2(q.floor(),Vector2(2,1)*S),Color(1,.9,.55,1-d/.25))
	var b: float=a-e.CLASH_BREAK
	if b>=0 and b<1.0:
		if b<.08:g.draw_rect(Rect2(0,0,640,360),Color(1,1,1,.5 if g.settings.flashes else .15))
		for i in range(22):
			var dir: Vector2=Vector2.from_angle(i*2.4)
			var q: Vector2=mid+(dir*b*(60+i%5*14)+Vector2(0,b*b*60))*S
			g.draw_set_transform(q.floor(),b*(i%5-2)*4,Vector2.ONE*S)
			g.draw_rect(Rect2(-2,-1,4+i%3,2),Color(.78,.78,.8,1-b))
			g.draw_rect(Rect2(-2,-1,4+i%3,1),Color(.95,.95,.97,1-b))
			g.draw_set_transform(Vector2.ZERO)

## EnderSteve after the duel, by stage: on his knees, walking, sitting, at the portal.
func ender_npc(g, offset: Vector2):
	var w=g.world;var n: Dictionary=w.npc;var a: float=w.stage_age;var p: Vector2=n.p+offset
	match w.stage:
		"clash","down":
			brawler(g,"endersteve_final",p,n.dir,-n.get("side",Vector2.RIGHT).x,.5)
			if w.stage=="clash":clash_sparks(g,(w.player+n.p)/2+offset-Vector2(0,14))
		"yield","approach":
			var k: float=clampf(a/1.4,0,1) if w.stage=="yield" else 1.0
			g.oval(p,Vector2(8,3),Color(0,0,0,.35))
			death_frame(g,p,n.dir,int(k*11))
			end_particles(g,p,w.clock,6,10,14)
		"to_edge":
			if n.p.distance_to(w.seats()[0])>.5:g.draw_actor("endersteve_final",p,n.dir,w.clock,true,Color.WHITE,"walk",1,{"state":"walk","time":w.clock})
			else:seated(g,"endersteve_final",p,w.clock)
		"sit":
			seated(g,"endersteve_final",p,w.clock+1.3)
			end_particles(g,p-Vector2(0,4),w.clock,6,5,10)
		"restore":
			if a<.6:seated(g,"endersteve_final",p,w.clock);return
			if a<2.6:
				g.draw_actor("endersteve_final",p,n.dir,w.clock,true,Color.WHITE,"walk",1,{"state":"walk","time":w.clock});return
			var portal: Vector2=w.portal_position+offset
			if a<DISSOLVE_AT:
				g.draw_actor("endersteve_final",p,Vector2.UP,a,false,Color.WHITE,"cast",1,{"state":"cast","time":a-2.6})
				var strength: float=smoothstep(2.8,4.2,a)
				for j in range(10):
					var q: Vector2=p-Vector2(0,16)+Vector2.from_angle(j*2.39996+w.clock*1.4)*(6+j%3*3)
					g.draw_line(q,q.lerp(portal,.25+.75*fposmod(w.clock*.8+j*.1,1)),Color(.85,.55,1,strength*.55),1)
				end_particles(g,p,w.clock,6,22,26)
				return
			# He comes apart into the light of the portal he gave back.
			var k: float=clampf((a-DISSOLVE_AT)/(w.end_boss.RESTORE_END-DISSOLVE_AT-.4),0,1)
			death_frame(g,p,Vector2.UP,26+int(k*20),Color(1,1,1,1-smoothstep(.85,1,k)))
			for j in range(40):
				var t: float=fposmod(k*1.6+j*.037,1.0)
				var start: Vector2=p-Vector2(0,10+j%20)
				var q: Vector2=start.lerp(portal-Vector2(0,4),t*t)+Vector2(sin(j*1.7+w.clock*3)*6*(1-t),0)
				g.draw_rect(Rect2(q.floor(),Vector2.ONE*(1+j%2)),Color(.75,.4,1,(1-t)*(1-k*.6)))
			# A few frames of unreadable symbols in the light: something is under the world.
			if g.settings.flashes and int(w.clock*60)%41 in [0,1] and k>.2 and k<.9:
				var glyphs:="§#ÆØ∆ΞЖ¥¤ÐΣ"
				for j in range(6):
					g.text_at(glyphs.substr(int(w.clock*31+j*3)%glyphs.length(),1),p+Vector2(-24+j*9,-30-int(w.clock*90+j*7)%20),8,Color(.95,.85,1,.9))

## The chapter looks finished; he breaks the way out and the end card with it.
func betrayal(g, offset: Vector2, a: float):
	var w=g.world;var impact: float=w.end_boss.BETRAYAL_IMPACT
	var p: Vector2=w.betrayer_position()+offset
	var card: float=smoothstep(.2,1.2,a)*(1-smoothstep(impact,impact+.02,a))
	if card>0:
		g.draw_rect(Rect2(0,0,640,360),Color(0,0,0,.25*card))
		g.centered("ГЛАВА III ПРОЙДЕНА",112,16,Color(1,.92,.7,card),true)
		var rect:=Rect2(234,246,172,26)
		var shake:=Vector2.ZERO
		if a>2.6:shake=Vector2(sin(w.clock*70),cos(w.clock*53))*smoothstep(2.6,impact,a)*2
		g.draw_style_box(g.button_styles[1 if int(w.clock*2)%2==0 else 0],Rect2(rect.position+shake,rect.size))
		var label:="Продолжить"
		var width: float=g.bold.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,8).x
		g.text_at(label,rect.position+shake+Vector2((rect.size.x-width)/2,17),8,Color(1,1,1,card),true)
	if a>=1.6:
		var arrival: float=smoothstep(1.6,2.1,a)
		var pose_name: String="teleport" if a<2.1 else "idle" if a<2.6 else "windup" if a<impact else "slash" if a<impact+.5 else "recover" if a<5.0 else "idle"
		var pose_time: float=(1-arrival)*.6 if a<2.1 else 0.0 if a<2.6 else clampf((a-2.6)/(impact-2.6),0,1)*.16 if a<impact else clampf((a-impact)/.5,0,1)*.52 if a<impact+.5 else .24
		var facing: Vector2=Vector2.DOWN if a<2.6 or a>5.0 else Vector2.UP
		end_particles(g,p,w.clock,6,30,26+smoothstep(2.6,impact,a)*30)
		g.draw_actor("endersteve_final",p-Vector2(0,(1-arrival)*30),facing,a,false,Color(1,1,1,arrival),pose_name,1,{"state":pose_name,"time":pose_time})
		if a>2.6 and a<impact:
			var strength: float=smoothstep(2.6,impact,a)
			for j in range(12):
				var q: Vector2=p-Vector2(0,20)+Vector2.from_angle(j*2.39996+w.clock*.3)*(70*(1-strength)+10)
				g.draw_line(q,q.move_toward(p-Vector2(0,22),8),Color(.85,.5,1,strength*.7),1)
	if a>=impact and a<impact+.12 and g.settings.flashes:
		g.draw_rect(Rect2(0,0,640,360),Color(1,1,1))
		g.draw_actor("endersteve_final",p,Vector2.UP,a,false,Color(0,0,0),"slash",1,{"state":"slash","time":.3})
		g.draw_actor("steve",w.player+offset,Vector2.UP,0,false,Color(0,0,0),"idle",1,{"state":"idle","time":0.0})
	if a>=impact:
		var t: float=a-impact
		if t<.5:g.draw_line(p-Vector2(0,60),p+Vector2(0,40),Color(.95,.8,1,1-t*2),3)
		# The end card and its button fall apart like glass.
		var alpha: float=1-smoothstep(1.2,2.6,t)
		if alpha>0:
			for j in range(46):
				var origin:=Vector2(234+(j%12)*14.5,246+(j/12)*7) if j<36 else Vector2(200+(j-36)*24,104+(j%2)*10)
				var dir: Vector2=(origin-Vector2(320,250)).normalized()+Vector2(sin(j*1.3)*.4,-.6)
				var q: Vector2=origin+dir*t*(90+j%5*30)+Vector2(0,t*t*260)
				g.draw_set_transform(q,t*(j%5-2)*3)
				g.draw_rect(Rect2(-3,-2,6+j%3*2,4),Color(.55,.55,.58,alpha) if j<36 else Color(1,.92,.7,alpha))
				g.draw_rect(Rect2(-3,-2,6+j%3*2,1),Color(.85,.85,.88,alpha) if j<36 else Color(1,1,.9,alpha))
				g.draw_set_transform(Vector2.ZERO)
		g.draw_rect(Rect2(0,0,640,360),Color(.18,0,.25,.35*(1-smoothstep(.3,4.0,t))))

## His words at the bottom of the screen, typed out at speaking pace.
func subtitles(g):
	var w=g.world
	if w.lines.is_empty():return
	var l: Dictionary=w.lines.back()
	var shown: int=mini(l.text.length(),int(l.age*28))
	var alpha: float=minf(1,l.age/.2)*(1-smoothstep(l.life-.35,l.life,l.age))
	var width: float=g.font.get_string_size(l.text,HORIZONTAL_ALIGNMENT_LEFT,-1,8).x
	# Above the hearts and hotbar while the HUD is up.
	var y: float=276.0 if w.stage in ["survival","dragon","last_duel","exit_portal","hand","return_portal","portal_ready"] else 316.0
	g.draw_rect(Rect2(320-width/2-10,y,width+20,18),Color(0,0,0,.55*alpha))
	var ink: Color=Color(.95,.95,.95,alpha) if l.get("who","ender")=="steve" else Color(.88,.78,1,alpha)
	g.text_at(l.text.substr(0,shown),Vector2(320-width/2,y+13),8,ink)


## His presence: a purple glow around the silhouette and flames rising off it,
## strongest when he stops to look at you and when he is angry.
func aura(g, m: Dictionary, p: Vector2):
	var w=g.world;var power: float=.35+(.35 if m.rage else 0.0)+(.45 if m.phase=="pose" else 0.0)
	if m.phase=="skyfall" and m.altitude>200:return
	var lift: float=m.altitude if m.phase=="skyfall" else 0.0
	var q: Vector2=p-Vector2(0,lift)
	g.oval(p,Vector2(14,4)*(1+power*.4),Color(.25,.05,.35,.25*power))
	g.draw_actor("endersteve_final",q+Vector2(0,1),m.visual_dir,m.animation,m.moving,Color(.75,.35,1,.22*power),m.phase,1.12,m.visual)
	for j in range(int(8+power*10)):
		var t: float=fposmod(w.clock*(.9+j%3*.25)+j*.137,1.0)
		var x: float=sin(j*2.4)*(7+j%3*2)+sin(w.clock*4+j)*1.5
		g.draw_rect(Rect2((q+Vector2(x,-4-t*(30+power*14))).floor(),Vector2(1,2+j%2)),Color(.8,.45,1,(1-t)*power))
	if m.phase=="pose":
		for j in range(6):
			var a0: float=w.clock*2+j*TAU/6
			g.draw_line(q+Vector2.from_angle(a0)*Vector2(16,6),q+Vector2.from_angle(a0)*Vector2(22,8),Color(.9,.65,1,.5),1)

## Sky fall: he is gone above the screen, his shadow hunts the hero, then he lands.
func skyfall(g, m: Dictionary, offset: Vector2):
	var w=g.world;var mark: Vector2=m.mark+offset;var age: float=3.4-m.timer
	var locked: bool=age>=2.7
	var k: float=1-clampf(m.altitude/240,0,1)
	g.oval(mark,Vector2(10+22*k,4+8*k),Color(.1,0,.15,.35+.35*k))
	g.draw_arc(mark,26+(1-k)*20,0,TAU,32,Color(1,.5,.9,.8) if locked else Color(.8,.5,1,.45),2 if locked else 1)
	if locked:
		for j in range(4):
			var d:=Vector2.from_angle(j*PI/2+w.clock*3)
			g.draw_line(mark+d*30,mark+d*40,Color(1,.6,1,.9),2)
	if m.altitude<230:
		var p: Vector2=m.p+offset-Vector2(0,m.altitude)
		for j in range(5):g.draw_line(p-Vector2(0,10+j*6),p-Vector2(0,30+j*14),Color(.85,.6,1,.4-j*.06),1)
		g.draw_actor("endersteve_final",p,Vector2.DOWN,m.animation,false,Color.WHITE,"slash",1,{"state":"slash","time":.2})


## Ruined portals from loops that ended here, and the gateways between them.
func loop_traces(g, offset: Vector2):
	var w=g.world
	if w.stage not in ["survival","end_arrival","departure"]:return
	for r in w.relics:
		var p: Vector2=r.p+offset
		if not Rect2(-80,-80,800,520).has_point(p):continue
		g.oval(p,Vector2(40,14),Color(.12,.05,.16,.35))
		for j in range(11):
			var a0: float=j*2.39996+r.id
			var q: Vector2=p+Vector2(cos(a0)*(14+j%4*7),sin(a0)*(6+j%3*3))
			g.sprite("end_bedrock",q-Vector2(6,4),Vector2(12,7),Color(.55,.5,.6))
		g.sprite("end_egg",p+Vector2(10,-6),Vector2(7,7),Color(.6,.5,.7,.9))
		for j in range(3+r.id):
			var q: Vector2=p+Vector2(-12+j*5,-2)
			for k in range(4):g.draw_line(q+Vector2(k,0),q+Vector2(k,3),Color(.75,.55,.9,.6),1)
	for gw in w.gateways:
		var p: Vector2=gw.p+offset
		if not Rect2(-60,-200,760,600).has_point(p):continue
		var pulse: float=.5+.5*sin(w.clock*3+gw.p.x)
		g.oval(p,Vector2(12,4),Color(0,0,0,.4))
		g.draw_rect(Rect2(p-Vector2(7,10),Vector2(14,10)),Color(.03,.02,.05))
		g.draw_rect(Rect2(p-Vector2(7,10),Vector2(14,1)),Color(.5,.4,.6))
		g.draw_line(p-Vector2(0,10),p-Vector2(0,130),Color(.75,.5,1,.18+.12*pulse),5)
		g.draw_line(p-Vector2(0,10),p-Vector2(0,130),Color(1,.9,1,.5+.3*pulse),1)
		end_particles(g,p-Vector2(0,6),w.clock,gw.p.x,10,10)
		if w.player.distance_to(gw.p)<60:g.draw_arc(p,12,0,TAU,20,Color(.85,.6,1,.5*pulse),1)

## At six minutes the island replays an older loop: a pale Steve fights someone
## who is not there, burns, kneels and is gone. Nothing here can be touched.
func echo_scene(g, offset: Vector2):
	var w=g.world;var e: Dictionary=w.echo;var a: float=e.age
	var p: Vector2=e.p+offset;var foe: Vector2=e.foe+offset
	var alpha: float=smoothstep(0,1,a)*(1-smoothstep(7.0,9.0,a))
	var ghost:=Color(.75,.55,1,.6*alpha)
	var dir: Vector2=p.direction_to(foe)
	if a>=5.0 and a<8.2:
		var ha: float=smoothstep(5.0,5.6,a)*(1-smoothstep(7.6,8.2,a))
		g.draw_actor("steve",foe,-dir,0,false,Color(.02,.02,.03,.85*ha),"idle",1,{"state":"idle","time":0.0})
		g.draw_rect(Rect2((foe+Vector2(-3,-20)).floor(),Vector2(2,1)),Color(1,1,1,ha))
		g.draw_rect(Rect2((foe+Vector2(1,-20)).floor(),Vector2(2,1)),Color(1,1,1,ha))
	if a>=4.2 and a<5.6:
		var r: float=lerpf(60,18,smoothstep(4.2,5.4,a))
		for j in range(28):
			var q: Vector2=p+Vector2.from_angle(j*TAU/28+a)*Vector2(r,r*.5)
			g.draw_rect(Rect2((q-Vector2(0,4+sin(a*20+j)*2)).floor(),Vector2(2,4)),Color(1,.8,1,.8*alpha))
	if a<5.4:
		var state: String="idle"
		var t: float=0.0
		if a>=1.0 and a<4.2:
			var c: float=fposmod(a-1.0,.8)
			state="windup" if c<.3 else "attack" if c<.45 else "recover";t=c/.8
			if a>=2.6 and a<2.9:state="hurt";p+= -dir*(a-2.6)*30
		g.draw_actor("steve",p,dir,a,false,ghost,state,1,{"state":state,"time":t})
		if state=="attack":
			for j in range(4):g.draw_line(foe+Vector2(-4,-14),foe+Vector2(-4,-14)+Vector2.from_angle(j*1.6+a*9)*8,Color(1,1,1,alpha),1)
	else:
		pose(g,"end_player_pickup",p,dir,.5,Color(ghost,ghost.a*(1-smoothstep(7.0,8.6,a))))
		for j in range(18):
			var t: float=fposmod(a*.7+j*.06,1.0)
			g.draw_rect(Rect2((p+Vector2(sin(j*2.4)*9,-6-t*40)).floor(),Vector2.ONE),Color(.8,.6,1,(1-t)*alpha))
	g.ambient_lights.append({"p":e.p,"r":70.0,"c":Color(.7,.5,1),"power":.5*alpha,"glow":.1})

## A boss name, still and large, a line under it.
func title_card(g, a: float, name: String, sub: String):
	var k: float=smoothstep(1.2,1.8,a)*(1-smoothstep(3.4,3.95,a))
	if k<=0:return
	var width: float=g.font.get_string_size(name,HORIZONTAL_ALIGNMENT_LEFT,-1,24).x
	g.text_at(name,Vector2(320-width/2,250).floor(),24,Color(.93,.88,.98,k))
	var line: float=width*smoothstep(1.4,2.2,a)
	g.draw_rect(Rect2(320-line/2,258,line,1),Color(.75,.4,1,k))
	var sw: float=g.font.get_string_size(sub,HORIZONTAL_ALIGNMENT_LEFT,-1,8).x
	g.text_at(sub,Vector2(320-sw/2,272).floor(),8,Color(.75,.7,.8,k*smoothstep(1.8,2.4,a)))

## The rim, close: both of them over the void, the island at their backs.
func closeup(g, a: float):
	var w=g.world;var total: float=w.end_boss.SIT_LENGTH
	if a>=.6 and a<=total-.6:
		g.draw_rect(Rect2(0,0,640,360),Color(.04,.015,.07))
		for j in range(70):
			var x: float=Atmosphere.hash01(j,1,77)*640;var y: float=Atmosphere.hash01(j,2,77)*215
			var tw: float=.4+.6*sin(w.clock*(1+Atmosphere.hash01(j,3,77)*2)+j)
			g.draw_rect(Rect2(Vector2(x,y).floor(),Vector2.ONE*(1+int(Atmosphere.hash01(j,4,77)*1.5))),Color(.85,.8,1,.25+.5*tw))
		for j in range(3):
			var x: float=fposmod(80+j*230-w.clock*(2+j),760)-60
			g.oval(Vector2(x,150+j*24),Vector2(46-j*8,8-j),Color(.12,.08,.16,.9))
			g.oval(Vector2(x,147+j*24),Vector2(44-j*8,5-j),Color(.2,.17,.22,.9))
		var top:=224
		for x in range(0,640,16):
			var depth: int=3+int(Atmosphere.hash01(x,5,77)*3)
			for r in range(2):g.sprite("end_stone_tile",Vector2(x,top-32+r*16),Vector2(16,16),Color(1,1,1))
			for r in range(depth):g.sprite("end_stone_tile",Vector2(x,top+r*16),Vector2(16,16),Color(.62-r*.08,.58-r*.08,.66-r*.08))
		g.draw_rect(Rect2(0,top-1,640,2),Color(.25,.22,.2,.6))
		var ender: Vector2=Vector2(282,top+30);var steve: Vector2=Vector2(358,top+30)
		g.oval(Vector2(320,top+2),Vector2(70,4),Color(0,0,0,.25))
		var ed: Vector2=Vector2.RIGHT if a>=17.8 and a<26.0 else Vector2.DOWN
		var sd: Vector2=Vector2.LEFT if (a>=23.0 and a<29.0) or (a>=30.4 and a<32.0) else Vector2.DOWN
		var breath: float=round(sin(w.clock*1.4))
		seated_close(g,"endersteve_final",ender-Vector2(0,30-breath),ed,3)
		seated_close(g,"steve",steve-Vector2(0,30-round(sin(w.clock*1.4+1.3))),sd,3)
		for j in range(14):
			var t: float=fposmod(w.clock*.25+j*.071,1.0)
			g.draw_rect(Rect2((ender+Vector2(-14+sin(j*2.4)*16,-60-t*90)).floor(),Vector2(2,2)),Color(.75,.45,1,(1-t)*.7))
		# The sword goes over to Steve after the eye.
		if a>=31.4 and a<33.6:
			var ks: float=smoothstep(31.4,32.4,a)
			var sat: Vector2=Vector2(300,top-44).lerp(Vector2(342,top-38),ks)-Vector2(0,sin(ks*PI)*16)
			if not g.textures.has("icon_sword_iron"):g.load_texture("icon_sword_iron")
			g.draw_set_transform(sat,-.4+ks*.6,Vector2.ONE*1.6)
			if g.textures.has("icon_sword_iron"):g.draw_texture_rect(g.textures.icon_sword_iron,Rect2(-8,-8,16,16),false,Color(1,1,1,1-smoothstep(33.0,33.6,a)))
			g.draw_set_transform(Vector2.ZERO)
		if a>=30.4 and a<32.6:
			var k: float=smoothstep(30.4,31.4,a)
			var at: Vector2=Vector2(300,top-50).lerp(Vector2(340,top-50),k)-Vector2(0,sin(k*PI)*14)
			g.sprite("icon_end_eye",at-Vector2(12,12),Vector2(24,24),Color(1,1,1,1-smoothstep(32.0,32.6,a)))
			g.draw_circle(at,10+sin(w.clock*6)*2,Color(.6,1,.8,.15))
		for j in range(18):
			var x: float=fposmod(j*61.0+w.clock*(30+j%4*8),700)-30
			g.draw_rect(Rect2(Vector2(x,100+j*13).floor(),Vector2(3,1)),Color(.8,.75,.85,.25))
	var black: float=maxf(1-absf(a-.6)/.6,1-absf(a-(total-.6))/.6)
	if black>0:g.draw_rect(Rect2(0,0,640,360),Color(0,0,0,clampf(black,0,1)))


## Seated on the rim, seen from the front: the body to the hips at the edge,
## the legs below it shortened as they hang over the side and swing a little.
func seated_close(g, kind: String, hip: Vector2, direction: Vector2, s: float):
	var w=g.world;var meta: Dictionary=w.animation.data.actors.get(kind,{})
	var size:=Vector2(meta.frame_size[0],meta.frame_size[1]) if meta.has("frame_size") else Vector2(32,32)
	var anchor:=Vector2(meta.anchor[0],meta.anchor[1]) if meta.has("anchor") else Vector2(size.x/2,size.y-3)
	var tex=g.textures.get(kind+"_atlas")
	if tex==null:return
	var frame: int=w.animation.frame(kind,"idle",0.0) if w.animation.data.actors.has(kind) else 0
	var row: int=w.animation.direction_row(direction);var flip: bool=row==2 and direction.x<0
	var cut: float=anchor.y-10.0
	var origin:=Vector2(frame*size.x,row*size.y)
	var swing: float=round(sin(w.clock*1.1+hip.x)*1.0)
	g.draw_set_transform(hip.floor(),0,Vector2(-1,1) if flip else Vector2.ONE)
	g.draw_texture_rect_region(tex,Rect2(Vector2(-anchor.x*s,swing),Vector2(size.x*s,(anchor.y-cut)*s*.62)),Rect2(origin+Vector2(0,cut),Vector2(size.x,anchor.y-cut)))
	g.draw_texture_rect_region(tex,Rect2(Vector2(-anchor.x*s,-cut*s),Vector2(size.x*s,cut*s)),Rect2(origin,Vector2(size.x,cut)))
	g.draw_set_transform(Vector2.ZERO)
