extends SceneTree
## Render the real item functions, then compare live and paused framebuffers.
var game
var checks = 0
var failures = []
var ids = ["sword","bow","trident","fire","potion","fangs","blaze","redstone","amethyst","sugar","armor","hopper","apple","emerald","chest","netherite","flamebow","channeling"]

func _initialize(): run.call_deferred()

func check(ok: bool, label: String):
	checks += 1
	if ok: print("PASS: "+label)
	else:
		failures.append(label)
		push_error(label)

func render() -> Image:
	game.queue_redraw()
	await process_frame
	RenderingServer.force_draw(false)
	return root.get_texture().get_image()

func draw_catalog():
	game.draw_rect(Rect2(0,0,640,360),Color("18251e"))
	game.text_at("MINECRAFT JAVA 1.21.11",Vector2(22,24),16,game.INK,true)
	game.text_at("ПРЕДМЕТЫ ИЗ PRISM LAUNCHER",Vector2(22,41),9,game.LIME)
	for i in range(ids.size()):
		var id = ids[i]
		var p = Vector2(24+(i%6)*104,57+(i/6)*89)
		game.draw_rect(Rect2(p,Vector2(95,81)),Color("23382a"))
		var q = p+Vector2(23,3)
		match id:
			"bow","flamebow":
				var frame = mini(3,int(fposmod(game.world.clock,1)*4))
				if id=="bow":
					game.draw_texture_rect_region(game.textures.bow_draw,Rect2(q,Vector2(48,48)),Rect2(frame*16,0,16,16))
				else:
					game.draw_texture_rect_region(game.textures.flamebow_draw,Rect2(q,Vector2(48,48)),Rect2(game.clip_frame("flamebow_enchanted",game.world.clock)*16,frame*16,16,16))
			"chest": game.draw_clip("chest_open",q,Vector2(48,48),fposmod(game.world.clock,1),Color.WHITE,false)
			"fangs": game.draw_clip("fangs_animation",q,Vector2(48,48),game.world.clock)
			"fire":
				game.draw_clip("fire_animation",q,Vector2(48,48),game.world.clock,Color(1,1,1,0.55))
				game.item_icon(id,q,3)
			_: game.item_icon(id,q,3)
		var label: String = game.world.db.title(id)
		if id=="chest":label="Сундук"
		if id=="netherite":label="Незеритовый меч"
		if id=="flamebow":label="Зачарованный лук"
		if id=="channeling":label="Громовержец"
		game.wrapped(label,p+Vector2(5,62),90,8,game.INK)
	game.text_at("Оригинальные PNG · кадры лука · огонь · зачарование · сундук · клыки",Vector2(23,344),9,game.MUTED)

func run():
	game=load("res://qa/minecraft_catalog.gd").new()
	game.reviewer=self
	root.add_child(game)
	game.set_process_input(false);game.set_process(false)
	game.set_physics_process(false)
	game.qa_mode="minecraft_items"
	game.settings.shake=false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size=Vector2i(640,360)
	game.world.reset(724)
	check(game.clip_frame("fire_animation",0)==16,"Vanilla fire starts at source frame 16")
	check(game.clip_frame("fire_animation",0.8)==0,"Vanilla fire advances at 20 frames per second")
	check(game.clip_frame("fire_animation",1.6)==16,"Vanilla fire loops in its original order")
	check(game.clip_frame("chest_open",30,false)==7,"Open chest holds its final pose")
	game.world.clock=0.11
	var a=await render()
	a.save_png("res://qa/minecraft_items_live.png")
	game.world.clock=0.45
	var b=await render()
	check(a.get_data()!=b.get_data(),"Native bow, fire, glint, fangs and chest visibly animate")
	game.world.state="PAUSED"
	a=await render()
	game.ui_time+=500
	b=await render()
	check(a.get_data()==b.get_data(),"All item animations freeze on pause")
	game.world.state="LEVEL_UP"
	a=await render()
	game.ui_time+=500
	b=await render()
	check(a.get_data()==b.get_data(),"All item animations freeze during upgrade selection")
	# A short recording also makes the original texture animation reviewable.
	game.world.state="RUNNING"
	for i in range(90):
		game.world.clock=i/30.0
		await render()
	FileAccess.open("res://qa/minecraft_render_results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	game.audio.shutdown()
	await create_timer(0.1).timeout
	game.free()
	game=null
	await process_frame
	quit(0 if failures.is_empty() else 1)
