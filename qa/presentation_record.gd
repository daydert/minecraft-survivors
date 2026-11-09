extends SceneTree
## Fixed-input native gameplay recording with the production audio and L screen.
var game
var frame_number=0
var finished=false

func _initialize():start.call_deferred()

func start():
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.qa_mode="presentation_recording"
	game.set_process_input(false);game.set_process(false)
	game.set_physics_process(false)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size=Vector2i(640,360)
	game.settings.shake=false
	game.audio.update_volumes(0.4,0.65)
	game.world.reset(724)
	var w=game.world
	for id in w.db.weapons:w.build[id]=8
	for id in w.db.passives:w.items[id]=3
	w.evolved={"sword":true,"bow":true,"trident":true}
	for i in range(22):w.spawn(["zombie","skeleton","creeper","spider","slime","ravager"][i%6],w.player+Vector2.from_angle(i*2.399)*(100+i%4*35))
	w.rebuild_hit_grid()
	var driver=Node.new()
	driver.set_script(load("res://qa/animation_review_driver.gd"))
	driver.review=self
	root.add_child(driver)

func tick():
	if finished:return
	var w=game.world
	if frame_number==180:game.toggle_stats()
	if frame_number==300:game.toggle_stats()
	if game.screen.is_empty():
		for i in range(2):
			if w.state in ["LEVEL_UP","CHEST"]:
				w.state="RUNNING"
				w.pending_chest.clear()
			w.xp=0
			w.step(1.0/60,[Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP][(frame_number/45)%4])
			w.hp=20
	for id in w.sounds:game.audio.play(id)
	w.sounds.clear()
	game.ui_time+=1.0/30
	game.queue_redraw()
	frame_number+=1
	if frame_number==480:finish.call_deferred()

func finish():
	finished=true
	game.audio.shutdown()
	await create_timer(0.1).timeout
	game.free()
	game=null
	await process_frame
	quit()
