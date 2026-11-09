extends SceneTree
var game
var checks=0
var failures=[]

func _initialize():run.call_deferred()

func check(ok:bool,label:String):
	checks+=1
	if ok:print("PASS: "+label)
	else:
		failures.append(label)
		push_error(label)

func render(path:String="") -> Image:
	game.queue_redraw()
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	var im=root.get_texture().get_image()
	if not path.is_empty():im.save_png("res://qa/"+path+".png")
	return im

func advance_to(target:float,movement:Vector2=Vector2.ZERO):
	while game.world.finale.elapsed+0.00001<target and game.world.state=="FINALE":game.world.step(1.0/60,movement)

func run():
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process_input(false);game.set_process(false)
	game.set_physics_process(false)
	game.qa_mode="chapter_review"
	game.settings.shake=false
	game.settings.flashes=false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size=Vector2i(640,360)
	game.world=load("res://scripts/world.gd").new(724)
	game.world.state="MENU"
	await render("chapter_menu")
	check(game.buttons.size()==4 and game.buttons[1].id == "multiplayer","Menu retains the title and four functional controls including multiplayer")
	game.world.reset(724)
	for i in range(8):game.world.spawn(["zombie","skeleton","creeper","spider","slime","ravager","vindicator","elite"][i],game.world.player+Vector2(-190+i%4*125,-65+i/4*100))
	await render("chapter_mobs")
	game.world.finale.begin(game.world)
	advance_to(2.6)
	await render("chapter_arrival")
	root.size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var large=await render("chapter_arrival_2x")
	check(large.get_size()==Vector2i(1280,720),"Throne/body are captured at actual 2x framebuffer resolution")
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	root.size=Vector2i(640,360)
	advance_to(8.8)
	var visible_bolt=false
	while game.world.finale.elapsed<12:
		visible_bolt=game.world.finale.strikes.any(func(s):return s.age>=.73 and s.age<.9 and game.world.visible(s.p))
		if visible_bolt:break
		game.world.step(1.0/60)
	check(visible_bolt,"Storm capture contains a real visible lightning strike")
	await render("chapter_storm")
	game.toggle_stats()
	var before=game.world.finale.elapsed
	game.world.step(3)
	check(game.screen=="stats" and game.world.finale.elapsed==before,"L stats pause the finale without skipping its scene")
	game.close_stats()
	check(game.world.state=="FINALE","Closing stats returns to the finale")
	advance_to(16.6)
	await render("chapter_inferno")
	game.pause_from="FINALE"
	game.world.state="PAUSED"
	var a=await render("chapter_pause")
	game.ui_time+=100
	var b=await render()
	check(a.get_data()==b.get_data(),"Paused lightning, flames, portal clocks and vanilla models stay pixel-identical")
	game.world.state="FINALE"
	advance_to(24.6)
	await render("chapter_defeat")
	advance_to(27.5)
	await render("chapter_portal")
	advance_to(30.0)
	await render("chapter_fall")
	advance_to(34.1)
	await render("chapter_end")
	check(game.world.finale.complete and not game.world.victory,"Final native rendering reaches the canonical chapter-end screen")
	game.action("retry")
	check(game.world.state=="RUNNING" and not game.world.finale.active and game.world.hp==20,"Chapter-end retry starts a clean playable run")
	game.world.finale.begin(game.world)
	game.action("menu")
	check(game.world.state=="MENU" and not game.world.finale.active,"Returning to menu clears the catastrophe")
	FileAccess.open("res://qa/chapter_visual_results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	game.audio.shutdown()
	await create_timer(.15).timeout
	game.free()
	game=null
	quit(0 if failures.is_empty() else 1)
