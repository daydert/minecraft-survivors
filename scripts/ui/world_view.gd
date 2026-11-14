extends RefCounted
const Tells=preload("res://scripts/chapter_four_tells.gd")
const SwordView = preload("res://scripts/spawn_sword_view.gd")
## World layer of chapter I / II and coop: terrain, actors, projectiles and effects.
const Lighting = preload("res://scripts/ui/lighting.gd")
const Atmosphere = preload("res://scripts/ui/atmosphere.gd")
const ChapterOne = preload("res://scripts/chapter_one_view.gd")

static func draw_world(g):
	if g.is_four():g.four_renderer.world(g);return
	if g.is_five():g.five_renderer.world(g);return
	if g.is_end():g.end_renderer.world(g);return
	var saved_actor = 0
	if g.coop.active and g.coop.running:
		saved_actor = g.world.active_id
		g.world.use_actor(g.network_view_id())
	var cam = g.world.camera()
	if g.world.state == "MENU": cam = Vector2(1024+sin(g.ui_time*0.06)*32,1024+cos(g.ui_time*0.08)*24)
	var offset = Vector2(320,180)-cam.floor()
	if g.settings.get("camera_lead",false) and g.world.state!="MENU" and not g.coop.active and not g.world.finale.active and (not g.is_nether() or g.world.stage=="survival"):offset-=g.cam_lead.round()
	if g.world.shake > 0 and g.settings.shake and g.world.state in ["RUNNING","FINALE"]: offset += (Vector2(sin(g.world.clock*75),cos(g.world.clock*87)).round()*1.5).round()
	offset=offset.round()
	if g.is_nether():g.nether_renderer.ground(g,offset)
	elif g.textures.has("ground"):
		g.draw_texture_rect_region(g.textures.ground,Rect2(Vector2.ZERO,Vector2(640,360)),Rect2(-offset,Vector2(640,360)))
	else: g.draw_rect(Rect2(0,0,640,360),Color("40563a"))
	if not g.is_nether():ChapterOne.ground(g,offset)
	preload("res://scripts/ui/cloud_shadows.gd").draw(g,offset)
	if g.world.finale.active:
		g.draw_texture_rect_region(g.textures.ground_scorched,Rect2(0,0,640,360),Rect2(-offset,Vector2(640,360)),Color(1,1,1,g.world.finale.scorch()))
	if not g.is_nether():Atmosphere.overworld_grass(g,offset)
	if "water" in g.world and not g.world.water.is_empty():draw_water(g,offset)
	# Oak fence around the field; the Nether keeps its pillars.
	if g.is_nether():
		for side in range(4):
			for j in range(64):
				var p = Vector2(24+j*32,22) if side == 0 else (Vector2(24+j*32,2026) if side == 1 else (Vector2(22,24+j*32) if side == 2 else Vector2(2026,24+j*32)))
				var s = p + offset
				if Rect2(-40,-60,720,480).has_point(s):g.sprite("nether_pillar_"+str(j%3),s-Vector2(32,50))
	else:ChapterOne.border(g,offset)
	if g.is_nether():g.nether_renderer.floor_effects(g,offset)
	SwordView.draw(g,offset)
	for o in g.world.orbs:
		var p: Vector2 = o.p+offset
		if not Rect2(-8,-8,656,376).has_point(p): continue
		var frame = 0 if o.value<5 else (3 if o.value<30 else 6)
		var pulse = 0.78+0.22*sin(g.world.clock*5+o.p.x)
		g.oval(p,Vector2(4,2),Color(0.3,0.8,0.2,0.12*pulse))
		g.draw_texture_rect_region(g.textures.experience_orb,Rect2((p-Vector2(4,5)).floor(),Vector2(8,8)),Rect2((frame%4)*16,(frame/4)*16,16,16),Color(0.45+0.25*pulse,1,0.2,1))
	for e in g.world.effects:
		if e.kind in ["cloud","fangs","player_hit","potion_splash"]: draw_effect(g,e,offset)
		if e.kind=="witch_potion":
			var k: float=clampf(e.age/e.total,0,1)
			Tells.splash(g,(e.end+offset).floor(),e.radius,k,int(e.get("owner",0))*5,g.world.clock)
	if g.world.finale.active:g.finale_renderer.floor_effects(g,offset)
	var actors: Array = []
	if g.world.finale.active:actors.append({"sort":g.world.finale.CENTER.y+18,"kind":"throne"})
	if not g.is_nether() and offset.y+ChapterOne.FENCE_S<460:actors.append({"sort":ChapterOne.FENCE_S,"kind":"south_fence"})
	if g.world.finale.active and g.world.finale.has_method("small_visible") and g.world.finale.small_visible():actors.append({"sort":g.world.finale.hb_p.y,"kind":"small_hb"})
	if g.world.finale.active and g.world.finale.has_method("small_visible") and not g.world.finale.villager.is_empty():actors.append({"sort":g.world.finale.villager.p.y,"kind":"villager"})
	for obj in g.world.props:
		if obj.type == "pumpkin" and obj.hp <= 0: continue
		if g.world.finale.active and g.world.finale.scorch()>.65 and obj.type in ["flowers","pumpkin","stump"]:continue
		if Rect2(-80,-80,800,540).has_point(obj.p+offset): actors.append({"sort":obj.p.y,"kind":"prop","obj":obj})
	for m in g.world.mobs:
		if Rect2(-140,-140,920,640).has_point(m.p+offset): actors.append({"sort":m.p.y,"kind":"mob","obj":m})
	if "landmarks" in g.world:
		for mark in g.world.landmarks:
			if mark.kind!="pond" and Rect2(-120,-120,880,600).has_point(mark.p+offset):actors.append({"sort":mark.p.y,"kind":"landmark","obj":mark})
	if g.coop.active and (g.coop.running or g.coop.loading):
		g.world.save_actor()
		for a in g.world.players.values():
			if a.alive or a.in_finale: actors.append({"sort":a.player.y,"kind":"coop_player","id":a.id})
	elif g.world.state!="MENU":actors.append({"sort":g.world.player.y,"kind":"player"})
	for o in g.world.loot:
		if Rect2(-20,-20,680,400).has_point(o.p+offset): actors.append({"sort":o.p.y,"kind":"loot","obj":o})
	actors.sort_custom(func(a,b): return a.sort < b.sort)
	for actor in actors:
		if actor.kind=="throne":
			g.finale_renderer.stage(g,offset)
		elif actor.kind=="south_fence":ChapterOne.south(g,offset)
		elif actor.kind=="small_hb":g.finale_renderer.duel.small_herobrine(g,offset)
		elif actor.kind=="villager":g.finale_renderer.duel.villager(g,offset)
		elif actor.kind=="landmark":
			var mark=actor.obj
			var anchor: Vector2={"ruin_0":Vector2(52,60),"ruin_1":Vector2(52,60),"well":Vector2(32,52),"mine_entrance":Vector2(48,60),"bastion":Vector2(96,104)}[mark.kind]
			g.oval(mark.p+offset+Vector2(0,2),Vector2(80,14) if mark.kind=="bastion" else Vector2(34,8) if mark.kind!="well" else Vector2(20,6),Color(0.05,0.1,0.05,0.3))
			g.sprite(mark.kind,(mark.p+offset-anchor).floor())
		elif actor.kind == "prop":
			var obj = actor.obj
			var p: Vector2 = obj.p+offset
			var name = obj.type
			var size = Vector2(24,24)
			if obj.type == "tree":
				name = ("tree_dead_" if g.world.finale.active and g.world.finale.scorch()>float(obj.id%8)/12 else "tree_")+str(obj.id%3)
				size = Vector2(64,72)
			elif obj.type == "rock": size = Vector2(32,32)
			elif obj.type == "flowers": size = Vector2(16,16)
			if g.is_nether():
				if obj.type=="tree":name="nether_pillar_"+str(obj.id%3)
				elif obj.type=="rock":name="nether_rock"
				elif obj.type=="pumpkin":name="nether_pot";size=Vector2(24,28)
			g.oval(p,Vector2(18,5) if obj.type == "tree" else Vector2(10,3),Color(0.08,0.16,0.12,0.3))
			var alpha = 0.42 if obj.type == "tree" and abs(g.world.player.x-obj.p.x)<30 and g.world.player.y<obj.p.y and g.world.player.y>obj.p.y-60 else 1.0
			g.sprite(name,p-Vector2(size.x/2,size.y-5),size,Color(1,1,1,alpha))
		elif actor.kind == "coop_player":
			var previous = g.world.active_id
			g.world.use_actor(actor.id)
			if g.world.finale.active and g.world.finale.elapsed >= 24: g.finale_renderer.player(g,g.world.player+offset)
			else:
				draw_actor(g,"steve",g.world.player+offset,g.world.facing,g.world.clock,g.world.player_moving,g.invulnerable_tint(),"walk",1.0,g.world.player_visual)
				draw_held_weapons(g,g.world.player+offset)
			if not g.world.finale.active or g.world.finale.elapsed < 24:
				draw_nickname(g,g.world.players[actor.id].nick,g.world.player+offset)
			g.world.use_actor(previous)
		elif actor.kind == "player":
			if g.is_nether() and g.nether_renderer.player(g,offset):pass
			elif g.world.finale.active and (g.world.finale.cinematic_player() if g.world.finale.has_method("cinematic_player") else g.world.finale.elapsed>=24):
				g.finale_renderer.player(g,g.world.player+offset)
			else:
				draw_actor(g,"steve",g.world.player+offset,g.world.facing,g.world.clock,g.world.player_moving,g.invulnerable_tint(),"walk",1.0,g.world.player_visual)
				draw_held_weapons(g,g.world.player+offset)
		elif actor.kind == "mob":
			var m = actor.obj
			if m.kind=="herobrine":continue
			if m.kind=="ch1_crawler":g.finale_renderer.duel.crawler(g,m,offset);continue
			var tint = Color.WHITE
			if g.settings.flashes and (m.flash>0 or (m.kind=="creeper" and m.fuse>=0 and fmod(g.world.clock,0.16)<0.08)): tint = Color(1.8,1.8,1.8)
			if g.is_nether() and m.kind=="wither":g.nether_renderer.boss(g,m,offset)
			elif m.kind=="phantom":
				var lift: float=m.get("altitude",0.0)
				if m.phase=="dive":
					for j in range(3):
						var back: Vector2=m.p-m.charge*(10.0+j*10.0)
						draw_actor(g,m.kind,back+offset-Vector2(0,lift+j*3),m.visual_dir,m.animation,true,Color(.4,.5,1,.32-j*.09),m.phase,1.0,m.visual)
				g.oval(m.p+offset+Vector2(0,1),Vector2(12,3)*(1.0-lift/120.0),Color(0.02,0.04,0.12,0.45-lift/200.0))
				draw_actor(g,m.kind,m.p+offset-Vector2(0,lift),m.visual_dir,m.animation,m.moving,tint,m.phase,1.0,m.visual)
			else:draw_actor(g,m.kind,m.p+offset,m.visual_dir,m.animation,m.moving,tint,m.phase,1.0,m.visual)
			if m.get("blood_moon",false):
				g.draw_rect(Rect2((m.p+offset+Vector2(-1,-30)).floor(),Vector2(2,2)),Color(0.9,0.1,0.1,0.8))
			if m.kind=="skeleton" and m.visual.state in ["windup","attack","recover"]:
				var aim:Vector2=m.visual_dir
				draw_bow(g,m.p+offset+aim*8+Vector2(0,-10),aim,clampf(m.visual.time/0.5,0,1) if m.visual.state=="windup" else 0)

			if m.burn>0:
				g.draw_clip("fire_animation",(m.p+offset-Vector2(9,19)).floor(),Vector2(18,21),g.world.clock+m.id*0.03,Color(1,1,1,0.85))
			if m.kind in ["elite","ravager"]:
				var p: Vector2=m.p+offset+Vector2(-15,-40 if m.kind=="ravager" else -35)
				g.draw_rect(Rect2(p,Vector2(30,3)),Color("26342b"))
				g.draw_rect(Rect2(p,Vector2(30*maxf(0,m.hp)/m.max_hp,2)),g.GOLD)
		else:
			var o = actor.obj
			var p: Vector2=o.p+offset
			if o.kind == "chest":
				g.oval(p,Vector2(12,4),Color(0.84,0.69,0.3,0.18))
				g.draw_line(p+Vector2(0,-22),p+Vector2(0,-30),g.GOLD,1)
			var bob = sin(g.world.clock*3+o.p.x*0.1)*2
			g.oval(p,Vector2(6,2),Color(0.04,0.1,0.05,0.3))
			# The vanilla ground-item turn is a transform of the original pixels.
			var turn = cos(g.world.clock*1.6+o.p.x*0.1)
			g.draw_set_transform((p-Vector2(0,8+bob)).floor(),0,Vector2(signf(turn)*maxf(0.18,absf(turn)),1))
			g.item_icon(o.kind,Vector2(-8,-8))
			g.draw_set_transform(Vector2.ZERO)
	for b in g.world.projectiles: draw_projectile(g,b,offset)
	for e in g.world.effects:
		if e.kind not in ["cloud","fangs","player_hit","potion_splash"]: draw_effect(g,e,offset)
	for pool in [g.world.particles,g.world.pixels]:
		for particle in pool:
			var size: float = particle.get("size",2.0)*clampf(particle.life/0.1,0.3,1)
			g.draw_rect(Rect2((particle.p+offset).floor(),Vector2.ONE*ceilf(size)),Color(particle.color,clampf(particle.life/0.1,0,1)))
	Atmosphere.collect(g,offset)
	Lighting.draw(g,offset)
	Atmosphere.after_lighting(g,offset)
	if g.world.state=="INTRO":ChapterOne.intro_overlay(g)
	if "bastion" in g.world and g.world.bastion.get("state","") in ["open","assault"] and not g.world.visible(g.world.bastion.p,0):
		var dir: Vector2 = g.world.camera().direction_to(g.world.bastion.p)
		var q: Vector2 = Vector2(320,180)+dir*Vector2(292,134)
		g.draw_colored_polygon(PackedVector2Array([q+dir*8,q-dir*5+dir.orthogonal()*6,q-dir*5-dir.orthogonal()*6]),Color(1,0.75,0.25))
	for m in g.world.mobs:
		if m.kind not in ["elite","ravager"] or g.world.visible(m.p,0): continue
		var dir = g.world.camera().direction_to(m.p)
		var p = Vector2(320,180)+dir*Vector2(292,134)
		g.draw_colored_polygon(PackedVector2Array([p+dir*7,p-dir*4+dir.orthogonal()*5,p-dir*4-dir.orthogonal()*5]),g.GOLD)
	if g.is_nether():g.nether_renderer.foreground(g,offset)
	if g.world.finale.active:g.finale_renderer.foreground(g,offset)
	if saved_actor: g.world.use_actor(saved_actor)

static func draw_water(g, offset: Vector2):
	var cam: Vector2=-offset+Vector2(320,180)
	var t0:=Vector2i(((cam-Vector2(330,190))/16).floor())
	var t1:=Vector2i(((cam+Vector2(330,190))/16).ceil())
	var time: float=g.world.clock if g.world.state!="MENU" else g.ui_time
	for ty in range(t0.y,t1.y):
		for tx in range(t0.x,t1.x):
			if not g.world.water.has(Vector2i(tx,ty)):continue
			var q: Vector2=Vector2(tx,ty)*16+offset
			g.draw_rect(Rect2(q-Vector2(2,2),Vector2(20,20)),Color(0.22,0.18,0.1,0.55))
	for ty in range(t0.y,t1.y):
		for tx in range(t0.x,t1.x):
			if not g.world.water.has(Vector2i(tx,ty)):continue
			g.draw_clip("water_animation",Vector2(tx,ty)*16+offset,Vector2(16,16),time+float((tx*7+ty*3)%5)*0.05)

static func draw_nickname(g, value: String, at: Vector2):
	var width = g.font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,8).x
	var p = (at+Vector2(-width/2,-36)).floor()
	g.draw_rect(Rect2(p+Vector2(-2,-8),Vector2(width+4,11)),Color(0,0,0,.55))
	g.text_at(value,p,8,g.INK)

static func draw_actor(g, kind: String, p: Vector2, dir: Vector2, anim: float, moving: bool, tint: Color, phase: String = "walk", actor_scale: float = 1.0, visual: Dictionary = {}):
	var small = kind == "small_slime"
	if kind == "small_slime": kind = "slime"
	var size = Vector2(32,32)
	if kind == "spider": size = Vector2(48,32)
	if kind == "ravager": size = Vector2(64,64)
	if kind in ["hoglin","zoglin"]:size=Vector2(48,48)
	if g.world.animation.data.actors.has(kind):
		var meta=g.world.animation.data.actors[kind]
		size=Vector2(meta.frame_size[0],meta.frame_size[1])
	var name=kind+"_atlas"
	var frame = g.world.animation.frame(kind,visual.get("state","walk" if moving else "idle"),visual.get("time",anim)) if g.world.animation.data.actors.has(kind) else (2+int(anim*7)%4)
	var row = g.world.animation.direction_row(dir)
	var flip = dir.x<0 and row==2
	var shadow_size=Vector2(size.x*0.24,3 if kind!="ravager" else 6)
	if g.world.animation.data.actors.get(kind,{}).has("shadow_size"):
		var shadow=g.world.animation.data.actors[kind].shadow_size
		shadow_size=Vector2(shadow[0],shadow[1])
	if not visual.get("airborne",false):g.oval(p+Vector2(0,1),shadow_size,Color(0.06,0.12,0.1,0.4))
	var actor_anchor=Vector2(size.x/2,size.y-3)
	if g.world.animation.data.actors.has(kind) and g.world.animation.data.actors[kind].has("anchor"):
		var anchor=g.world.animation.data.actors[kind].anchor;actor_anchor=Vector2(anchor[0],anchor[1])
	var display_size = size * actor_scale * (0.5 if small else (1.25 if kind=="elite" else 1.0))
	var display_anchor=Vector2(display_size.x/2,display_size.y-3)
	if g.world.animation.data.actors.has(kind) and g.world.animation.data.actors[kind].has("anchor"):display_anchor=actor_anchor*actor_scale
	var dest = Rect2(p-display_anchor,display_size)
	if g.textures.has(name):
		if flip:
			g.draw_set_transform(p,0,Vector2(-1,1))
			dest.position = -display_anchor
		if moving and kind in ["steve","zombie","elite","skeleton"] and visual.get("state","") in ["windup","attack","recover","hurt"]:
			# Keep the eight-step legs underneath the acting upper body while moving.
			var gait_frame=g.world.animation.frame(kind,"walk",visual.get("gait",0.0))
			var upper=Rect2(dest.position,Vector2(dest.size.x,dest.size.y*0.75))
			var lower=Rect2(dest.position+Vector2(0,dest.size.y*0.75),Vector2(dest.size.x,dest.size.y*0.25))
			g.draw_texture_rect_region(g.textures[name],upper,Rect2(frame*32,row*32,32,24),tint)
			g.draw_texture_rect_region(g.textures[name],lower,Rect2(gait_frame*32,row*32+24,32,8),tint)
		else:g.draw_texture_rect_region(g.textures[name],dest,Rect2(Vector2(frame*size.x,row*size.y),size),tint)
		if flip: g.draw_set_transform(Vector2.ZERO)
	else:
		# Import failures remain visibly diagnosable rather than crashing a run.
		g.draw_rect(Rect2(p-Vector2(7,22),Vector2(14,21)),Color("59a899") if kind=="steve" else Color("7da256"))

static func draw_bow(g, p: Vector2, aim: Vector2, draw_amount: float, flame: bool = false):
	var frame = 0 if draw_amount<=0 else mini(3,1+int(draw_amount*3))
	g.draw_set_transform(p.floor(),aim.angle()+PI/4)
	if flame:
		var glint_frame = g.clip_frame("flamebow_enchanted",g.item_time())
		g.draw_texture_rect_region(g.textures.flamebow_draw,Rect2(-8,-8,16,16),Rect2(glint_frame*16,frame*16,16,16))
	else:
		g.draw_texture_rect_region(g.textures.bow_draw,Rect2(-8,-8,16,16),Rect2(frame*16,0,16,16))
	g.draw_set_transform(Vector2.ZERO)

static func draw_held_weapons(g, p: Vector2):
	for id in g.world.weapon_visuals:
		if id=="axe" and g.is_nether() and g.world.effects.any(func(e):return e.kind=="axe_spin"):continue
		var pose: Dictionary = g.world.weapon_visuals[id]
		if id!="fangs" and id!=g.world.player_visual.get("weapon",""):continue
		if id=="sword" and pose.state!="windup": continue
		var aim: Vector2 = pose.dir
		var hand_side=-1 if g.world.facing.x<0 else 1
		var q = p+Vector2(hand_side*5,-8)+Vector2(aim.x,aim.y*0.4)*7
		var progress: float = pose.progress
		if id=="bow":
			draw_bow(g,q,aim,progress if pose.state=="windup" else 0,g.world.evolved.has(id))
			continue
		if id=="fangs":
			if pose.state=="windup":
				var stats = g.world.db.stats(id,g.world.build[id],false,g.world.items)
				for j in range(int(stats.count)):
					var point = p+aim*(20+j*20)
					g.draw_line(point-aim.orthogonal()*4,point+aim.orthogonal()*4,Color(0.73,0.64,0.39,0.35),1)
					if progress>0.6: g.draw_rect(Rect2(point-Vector2(1,2),Vector2(2,2)),Color("b6b494"))
			continue
		var rotation = aim.angle()+PI/4
		if id=="sword":
			rotation -= 1.4+progress*0.5
			q -= aim*3
		elif id=="trident": q -= aim*progress*6
		elif id=="potion":
			q -= aim*progress*5
			q.y -= progress*4
			rotation = -progress*0.6
		elif id=="fire":
			g.draw_clip("fire_animation",q-Vector2(8,13),Vector2(16,16),g.world.clock,Color(1,1,1,0.7))
			rotation = -progress*0.4
		g.draw_set_transform(q,rotation)
		g.item_icon(id,Vector2(-8,-8),1,g.world.evolved.has(id))
		g.draw_set_transform(Vector2.ZERO)

static func draw_projectile(g, b: Dictionary, offset: Vector2):
	var p: Vector2=b.p+offset+Vector2(0,-9)
	if not Rect2(-30,-30,700,420).has_point(p):return
	if g.is_nether() and g.nether_renderer.projectile(g,b,offset):return
	var tick = int(b.age*24)
	if b.kind=="fire":
		for j in range(5):
			var q=p-b.dir*(5+j*3)+b.dir.orthogonal()*sin(tick+j*2)*2
			var sz=12-j*1.5
			g.draw_clip("fire_animation",(q-Vector2.ONE*sz/2).floor(),Vector2.ONE*sz,b.age+j*0.06,Color(1,1,1,1-j*0.15))
		g.item_icon("fire",p-Vector2(8,8))
	elif b.kind=="trident":
		var col=Color("c7b878") if b.returning else Color("6caca8")
		for j in range(3):
			var q=p-b.dir*(6+j*5)
			g.draw_rect(Rect2(q.floor(),Vector2(2,2)),Color(col,0.6-j*0.15))
		if b.returning and b.turn_age<0.13: g.draw_arc(p,7,0,TAU,12,Color(col,0.7),1)
		g.draw_set_transform(p,b.dir.angle()+PI/4)
		g.item_icon("trident",Vector2(-8,-8),1,b.evolved)
		g.draw_set_transform(Vector2.ZERO)
	else:
		if b.evolved:
			for j in range(4):
				var q=p-b.dir*(4+j*3)+b.dir.orthogonal()*((tick+j)%3-1)
				g.draw_clip("fire_animation",(q-Vector2(4,5)).floor(),Vector2(8,10),b.age+j*0.04,Color(1,1,1,1-j*0.2))
		g.draw_set_transform(p.floor(),b.dir.angle()+PI/4)
		g.sprite("icon_arrow",Vector2(-8,-8),Vector2(16,16))
		g.draw_set_transform(Vector2.ZERO)

static func draw_effect(g, e: Dictionary, offset: Vector2):
	var p: Vector2=e.p+offset
	if not Rect2(-150,-150,940,660).has_point(p):return
	if g.is_nether() and g.nether_renderer.effect(g,e,offset):return
	var progress=clampf(e.age/e.total,0,1)
	match e.kind:
		"vindicator_slash":
			g.draw_set_transform(p+Vector2(0,-9)+e.direction*16,e.direction.angle()+PI/2)
			g.draw_clip("sweep_animation",Vector2(-20,-14),Vector2(40,28),e.age,Color.WHITE,false)
			g.draw_set_transform(Vector2.ZERO)
		"swing":
			p.y-=9
			var angle: float=e.direction.angle()
			var color=Color("d9dcc2") if not e.evolved else Color("b09abc")
			# The complete contact sector is visible on the damage tick. A 70ms trail
			# follows; the remaining lifetime is the hand/blade settling back.
			if e.age<0.2:
				g.draw_set_transform(p+e.direction*e.radius*0.5,angle+PI/2)
				g.draw_clip("sweep_animation",Vector2(-e.radius*0.65,-e.radius*0.45),Vector2(e.radius*1.3,e.radius*0.9),e.age,Color(1,1,1,0.8 if g.settings.flashes else 0.4),false)
				g.draw_set_transform(Vector2.ZERO)
			var a=angle+PI/3+progress*0.25
			var hand_origin=p.lerp(g.world.player+offset+Vector2(0,-9),smoothstep(0.25,1.0,progress))
			var blade_pos=hand_origin+Vector2.from_angle(a)*lerpf(e.radius*0.65,13,progress)
			g.draw_set_transform(blade_pos,a+PI/4+progress*0.4)
			g.item_icon("sword",Vector2(-8,-8),1,e.evolved)
			g.draw_set_transform(Vector2.ZERO)
		"cloud":
			var fade=clampf(e.life/0.4,0,1)
			for i in range(5):
				var q=p+Vector2.from_angle(i*TAU/5+0.1*sin(e.age))*e.radius*0.46
				g.draw_circle(q,e.radius*0.49,Color(0.5,0.66,0.31,0.075*fade))
			for i in range(10):
				var phase=fposmod(e.age*0.6+i*0.17,1)
				var q=p+Vector2.from_angle(i*2.399)*e.radius*(0.3+phase*0.5)-Vector2(0,phase*5)
				g.draw_clip("poison_animation",q.floor()-Vector2(4,4),Vector2(8,8),e.age+i*0.08,Color(0.53,0.64,0.39,(1-phase)*0.7*fade))
		"explosion","enemy_explosion":
			if e.kind=="enemy_explosion" and e.age<0.065:
				draw_actor(g,"creeper",p,e.get("direction",Vector2.DOWN),0,false,Color(1.3,1.3,1.3) if g.settings.flashes else Color.WHITE,"attack",1.0,{"state":"attack","time":e.age})
			g.draw_clip("explosion_animation",p-Vector2.ONE*e.radius,Vector2.ONE*e.radius*2,progress*0.399,Color(1,1,1,0.9 if g.settings.flashes else 0.45),false)
		"bottle":
			var ground:Vector2=p.lerp(e.end+offset,progress)
			g.oval(ground,Vector2(4,2),Color(0.05,0.13,0.1,0.3))
			var q=ground-Vector2(0,sin(progress*PI)*28)
			q.y-=9*(1-progress)
			g.draw_set_transform(q,progress*TAU)
			g.sprite("icon_splash_potion",Vector2(-8,-8),Vector2(16,16))
			g.draw_set_transform(Vector2.ZERO)
		"fangs":
			var age:float=e.age-e.delay
			if age<0:
				g.oval(p,Vector2(e.radius,3),Color(0.7,0.64,0.42,0.23))
				if age< -0.08:return
			var height=12.0
			if age<0:height=12*(1+age/0.08)
			elif age>0.1:
				# The old hit window lasts 0.65s: teeth must remain visible to late
				# entrants, then sink during its final 0.1s without moving damage.
				height=lerpf(12,6,clampf((age-0.1)/0.45,0,1))
				if age>0.55:height=6*(1-clampf((age-0.55)/0.1,0,1))
			g.oval(p,Vector2(e.radius,3),Color("2c342b"))
			var display_height = maxf(1,height*2)
			g.draw_clip("fangs_animation",(p-Vector2(16,display_height-2)).floor(),Vector2(32,display_height),maxf(0,age),Color.WHITE,false)
		"lightning":
			var alpha=(1-progress)*(0.95 if g.settings.flashes else 0.4)
			var points=PackedVector2Array([p-Vector2(0,90),p-Vector2(9,58),p+Vector2(5,-32),p])
			g.draw_polyline(points,Color(0.3,0.62,0.66,alpha*0.6),5)
			g.draw_polyline(points,Color(0.86,0.9,0.73,alpha),2)
			for j in range(6):
				var dir=Vector2.from_angle(j*TAU/6)
				g.draw_line(p+dir*5,p+dir*e.radius*progress,Color(0.66,0.79,0.73,alpha),1)
		"damage":
			if g.settings.numbers:g.text_at(str(e.amount),p+Vector2(-4,-progress*13),8,Color("eddda9"),true)
		"player_hit":pass
		"witch_potion":
			var k: float=clampf(e.age/e.total,0,1)
			var target: Vector2=e.end+offset
			var start: Vector2=e.start+offset
			var q: Vector2=start.lerp(target,k)-Vector2(0,sin(k*PI)*34+10*(1-k))
			g.draw_set_transform(q,k*TAU*1.5)
			g.sprite("icon_potion",Vector2(-8,-8),Vector2(16,16),Color(0.85,0.5,1.0))
			g.draw_set_transform(Vector2.ZERO)
		"potion_splash":
			var k: float=clampf(e.age/e.total,0,1)
			for j in range(10):
				var dir=Vector2.from_angle(j*TAU/10+0.2)
				g.draw_rect(Rect2((p+dir*Vector2(1,0.5)*e.radius*k-Vector2(0,4)).floor(),Vector2(2,2)),Color(0.75,0.35,0.85,1-k))
			preload("res://scripts/ui/witch_puddle_view.gd").draw(g,p,e.radius*(.8+.2*k),.7*(1-k))
		"witch_heal":
			var k: float=clampf(e.age/e.total,0,1)
			for j in range(12):
				var dir=Vector2.from_angle(j*2.4)
				var q=p+dir*e.radius*0.6*sqrt(float(j)/12)-Vector2(0,k*24+j%3*3)
				g.draw_rect(Rect2(q.floor(),Vector2(2,2)),Color(1.0,0.4,0.55,(1-k)*0.9))
		"break":
			for j in range(5):g.draw_rect(Rect2(p+Vector2.from_angle(j*TAU/5)*progress*15,Vector2(3,3)),Color("c89850"))
