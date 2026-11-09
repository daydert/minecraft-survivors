extends RefCounted
## Chapter III draws vanilla sampled parts, paused simulation effects and restrained UI.
const PURPLE=Color("bf82e6")
const Lighting=preload("res://scripts/ui/lighting.gd")
const Atmosphere=preload("res://scripts/ui/atmosphere.gd")
var dragon_meta: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/end_dragon.json"))

func world(g):
	if not g.end_assets_loaded:g.ensure_end_assets()
	if g.qa_mode=="end_scale":scale_review(g);return
	var w=g.world
	var offset=Vector2(320,180)-w.camera().floor()
	if w.shake>0 and g.settings.shake and w.state=="RUNNING":offset+=Vector2(sin(w.clock*75),cos(w.clock*87)).round()*2
	ground(g,offset)
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
	var actors=[]
	for p in w.props:
		if p.type=="pumpkin" and p.hp<=0:continue
		if w.visible(p.p,90):actors.append({"y":p.p.y,"type":"prop","obj":p})
	for m in w.mobs:
		if m.kind in ["end_dragon","arena_crystal"]:continue
		if w.visible(m.p,90):actors.append({"y":m.p.y,"type":"mob","obj":m})
	actors.append({"y":w.player.y,"type":"player"})
	for o in w.loot:actors.append({"y":o.p.y,"type":"loot","obj":o})
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
				if m.kind=="endersteve_final" and m.phase=="leap":
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
	for e in w.effects:
		if e.kind in ["friendly_breath","dragon_cloud"]:continue
		if not effect(g,e,offset) and not g.nether_renderer.effect(g,e,offset):g.draw_effect(e,offset)
	for pool in [w.particles,w.pixels]:
		for p in pool:g.draw_rect(Rect2((p.p+offset).floor(),Vector2.ONE*p.get("size",2)),Color(p.color,clampf(p.life/.2,0,1)))
	Atmosphere.collect(g,offset)
	Lighting.draw(g,offset)
	Atmosphere.after_lighting(g,offset)
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
		var cam: Vector2=w.camera()
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
	var state="perch" if m.phase=="perch" else "roar" if m.phase=="rage" else "flight"
	var clip: Dictionary=dragon_meta.states[state]
	var frame=int(clip.start)+int(w.clock*clip.fps*(1.35 if m.phase in ["rush","takeoff"] else 1.0))%int(clip.count)
	var size=Vector2(dragon_meta.frame_size[0],dragon_meta.frame_size[1]);var anchor=Vector2(dragon_meta.anchor[0],dragon_meta.anchor[1])
	g.oval(m.p+offset,Vector2(74,17),Color(0,0,0,.28))
	var tint=Color(1.6,1.4,1.6,1-death) if g.settings.flashes and m.flash>0 else Color(1,1,1,1-death)
	g.draw_texture_rect_region(g.textures.end_dragon_atlas,Rect2((p-anchor*.9).floor(),size*.9),Rect2(Vector2(frame*size.x,row*size.y),size),tint)

func player(g, offset: Vector2):
	var w=g.world;var p: Vector2=w.player+offset
	if w.stage=="hand_pickup":
		pose(g,"end_player_pickup",p,w.facing,clampf(w.stage_age/.6,0,1));return
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
	var broken=w.stage in ["last_arrival","last_duel","endsteve_death","hand","hand_pickup","return_portal"] or (w.stage=="betrayal" and w.stage_age>=w.end_boss.BETRAYAL_IMPACT)
	for y in range(-2,3):
		for x in range(-2,3):
			if x*x+y*y>6:continue
			var home=Vector2(x*12-8,y*7-5)
			var rubble=home*1.8+Vector2(sin(x*13+y)*16,cos(x+y*3)*11)
			if broken:home=rubble
			elif w.stage=="rekindle":home=rubble.lerp(home,smoothstep(.5,1.8,w.stage_age))
			g.sprite("end_bedrock",p+home,Vector2(12,7) if broken else Vector2(16,12),Color(.55,.5,.6) if broken else Color(.7,.7,.75))
	if not broken:
		if w.portal_lit:g.draw_texture_rect(g.textures.end_portal,Rect2(p-Vector2(19,10),Vector2(38,20)),true)
		for y in range(3):g.sprite("end_bedrock",p-Vector2(6,15+y*9),Vector2(12,12))
		if w.stage in ["dragon_death","exit_portal","betrayal"]:g.sprite("end_egg_model",p-Vector2(14,61))
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
	if w.stage=="betrayal":
		var p: Vector2=w.portal_position+offset+Vector2(0,-22)
		var arrival=smoothstep(0,.8,a)
		var impact=w.end_boss.BETRAYAL_IMPACT
		var pose_name="teleport" if a<.8 else "cast" if a<1.8 else "windup" if a<2.8 else "slash" if a<3.5 else "recover"
		var pose_time=(1-arrival)*.6 if a<.8 else a-1 if a<1.8 else clampf((a-1.8),0,1)*.16 if a<2.8 else clampf((a-2.8)/.45,0,1)*.52 if a<3.5 else .24
		end_particles(g,p,w.clock,6,36,30+smoothstep(1.4,2.9,a)*25)
		g.draw_actor("endersteve_final",p-Vector2(0,(1-arrival)*32),Vector2.DOWN,a,false,Color(1,1,1,arrival),pose_name,1,{"state":pose_name,"time":pose_time})
		if a>1.8 and a<impact:
			var strength=smoothstep(1.8,3,a)
			for j in range(9):
				var q=p+Vector2.from_angle(j*2.39996+w.clock*.2)*(58*(1-strength)+13)
				g.draw_line(q,q.move_toward(p-Vector2(0,23),7),Color(.85,.5,1,strength*.6),1)
			g.draw_line(p+Vector2(-5,-42),p+Vector2(-5,-24),Color(.9,.65,1,strength),2)
		if a>impact and a<impact+.36:
			var t=(a-impact)/.36
			g.draw_line(p-Vector2(0,54),p+Vector2(0,30),Color(.95,.8,1,1-t),3)
			if g.settings.flashes:g.draw_rect(Rect2(0,0,640,360),Color(.8,.6,1,(1-t)*.2))
	if w.stage=="endsteve_death" and not w.endsteve_corpse.is_empty():
		var p: Vector2=w.endsteve_corpse.p+offset
		var progress=clampf(a/w.end_boss.DEATH_DURATION,0,1)
		var frame=mini(47,int(progress*48))
		var row=w.animation.direction_row(w.endsteve_corpse.visual_dir)
		g.oval(p,Vector2(8,3),Color(0,0,0,.35*(1-smoothstep(4,6,a))))
		var tint=Color(1,1,1,1-smoothstep(6.6,7.2,a))
		if row==2 and w.endsteve_corpse.visual_dir.x<0:
			g.draw_set_transform(p,0,Vector2(-1,1))
			g.draw_texture_rect_region(g.textures.end_finale_death,Rect2(-64,-100,128,128),Rect2(frame*128,row*128,128,128),tint);g.draw_set_transform(Vector2.ZERO)
		else:g.draw_texture_rect_region(g.textures.end_finale_death,Rect2(p-Vector2(64,100),Vector2(128,128)),Rect2(frame*128,row*128,128,128),tint)
		if a>2:
			end_particles(g,p,w.clock,6,45,20+smoothstep(2,5,a)*26)
		if a>3.6 and a<6.6:
			var center=p-Vector2(0,22)
			var glow=sin(clampf((a-3.6)/3,0,1)*PI)
			for j in range(7):
				var dir=Vector2.from_angle(j*2.39996+w.clock*.08)
				var length=(38+j%3*14)*glow
				g.draw_colored_polygon(PackedVector2Array([center,center+dir*length+dir.orthogonal()*2,center+dir*length-dir.orthogonal()*2]),Color(.7,.35,.95,glow*.25))
		if a>6.25:
			var land=smoothstep(6.25,7.25,a)
			var hand=p.lerp(w.hand_position()+offset,land)-Vector2(0,(1-land)*18+sin(land*PI)*16)
			g.draw_set_transform(hand,(1-land)*1.4)
			g.sprite("icon_end_hand",Vector2(-8,-16),Vector2(16,16),Color(1,1,1,smoothstep(6.25,6.6,a)));g.draw_set_transform(Vector2.ZERO)
	if w.stage in ["end_arrival","departure","dragon_arrival","dragon_death","betrayal","last_arrival","endsteve_death","rekindle","exit_jump"]:
		var bars=18.0
		if w.stage in ["dragon_arrival","last_arrival","end_arrival"]:bars*=1-smoothstep(1,3.9 if w.stage=="dragon_arrival" else 2.2,a)
		if w.stage=="endsteve_death":bars*=1-smoothstep(6.6,7.6,a)
		g.draw_rect(Rect2(0,0,640,bars),Color.BLACK);g.draw_rect(Rect2(0,360-bars,640,bars),Color.BLACK)
	if w.stage=="departure":g.draw_rect(Rect2(0,0,640,360),Color(0,0,0,smoothstep(.2,1.55,a)))
	elif w.stage in ["end_arrival","dragon_arrival"]:
		g.draw_rect(Rect2(0,0,640,360),Color(0,0,0,1-smoothstep(0,1.2,a)))
		if w.stage=="end_arrival" and a>.6:g.centered("Глава III · Край",95,16,Color(1,1,1,1-smoothstep(1.7,2.5,a)),true)
	elif w.stage=="exit_jump":g.draw_rect(Rect2(0,0,640,360),Color(0,0,0,smoothstep(2.2,3.4,a)))

func hud(g):
	var w=g.world
	for m in w.mobs:
		if m.kind not in ["end_dragon","endersteve_final"]:continue
		g.centered("Эндер-дракон" if m.kind=="end_dragon" else "ЭндерСтив",41,8,Color.WHITE,true)
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
	g.centered("Продолжение следует",151,8,Color("aaaaaa"))
	g.button(Rect2(199,304,242,27),"В меню","menu")
