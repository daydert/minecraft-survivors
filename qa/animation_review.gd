extends SceneTree
## Identical fixed input/seed for both before and after projects. Rendered gameplay.
var game
var frame_number = 0
var core_only = false
var finished = false
var screenshot = "res://qa/animation_scene.png"
var report_path = "res://qa/comparison_after.json"

func _initialize():
	start.call_deferred()

func start():
	for arg in OS.get_cmdline_user_args():
		if arg=="--core-only": core_only=true
		if arg.begins_with("--shot="): screenshot=arg.trim_prefix("--shot=")
		if arg.begins_with("--report="): report_path=arg.trim_prefix("--report=")
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.qa_mode="comparison"
	game.set_process_input(false);game.set_process(false)
	game.set_physics_process(false)
	game.settings.fullscreen=false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size=Vector2i(640,360)
	game.settings.shake=false
	game.settings.numbers=false
	game.settings.music=0.15
	game.audio.update_volumes(0.15,0.65)
	game.world.reset(724)
	var w=game.world
	w.spawn("zombie",w.player+Vector2(-84,18))
	w.spawn("zombie",w.player+Vector2(58,-72))
	w.spawn("creeper",w.player+Vector2(90,40))
	w.spawn("creeper",w.player+Vector2(-30,90))
	w.rebuild_hit_grid()
	game.queue_redraw()
	var driver=Node.new()
	driver.set_script(load("res://qa/animation_review_driver.gd"))
	driver.review=self
	root.add_child(driver)

func tick():
	if game==null or finished:return false
	var w=game.world
	if not core_only:
		if frame_number==150:
			for id in w.db.weapons:w.build[id]=8
			for id in w.db.passives:w.items[id]=3
			for i in range(18):w.spawn(["skeleton","spider","slime","elite","ravager","zombie"][i%6],w.player+Vector2.from_angle(i*2.39)*160)
		if frame_number==300:w.evolved={"sword":true,"bow":true,"trident":true}
		if frame_number==390:w.state="PAUSED"
		if frame_number==420:w.state="RUNNING"
	var movement=[Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP][(frame_number/45)%4]
	if frame_number>=75 and frame_number<135:movement=Vector2.ZERO
	for _i in range(2):
		if w.state in ["LEVEL_UP","CHEST"]:
			w.state="RUNNING"
			w.pending_chest.clear()
		w.xp=0
		w.step(1.0/60,movement)
		# Preserve natural hurt reactions/blinking; protect demo health afterwards.
		w.hp=20
	game.ui_time+=1.0/30
	for id in w.sounds:game.audio.play(id)
	w.sounds.clear()
	game.queue_redraw()
	frame_number+=1
	if frame_number==(96 if core_only else 330): take_screenshot.call_deferred()
	if frame_number==(120 if core_only else 480): finish.call_deferred()
	return false

func take_screenshot():
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(screenshot)

func finish():
	finished=true
	var w=game.world
	var summary={"time":w.time,"kills":w.kills,"hp":w.hp,"player":[w.player.x,w.player.y],"mobs":[]}
	for m in w.mobs: summary.mobs.append({"id":m.id,"kind":m.kind,"hp":m.hp,"p":[m.p.x,m.p.y]})
	FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify(summary,"  "))
	game.audio.shutdown()
	await create_timer(0.1).timeout
	game.free()
	game=null
	await process_frame
	quit()
