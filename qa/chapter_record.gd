extends SceneTree
## Native frame recording: title, vanilla enemies/vindicator, full chapter ending.
var game
var frame_number=0
var finished=false

func _initialize():start.call_deferred()

func start():
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.qa_mode="chapter_recording"
	game.set_process_input(false);game.set_process(false)
	game.set_physics_process(false)
	game.settings.shake=false
	game.settings.flashes=false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size=Vector2i(640,360)
	game.audio.update_volumes(.3,.6)
	game.world.state="MENU"
	var driver=Node.new()
	driver.set_script(load("res://qa/animation_review_driver.gd"))
	driver.review=self
	root.add_child(driver)

func tick():
	if finished:return
	var w=game.world
	if frame_number==45:
		w.reset(724)
		w.build={"sword":3,"bow":2}
		w.level=10
		for i in range(12):
			w.spawn(["zombie","skeleton","creeper","spider","slime","ravager","vindicator","elite"][i%8],w.player+Vector2.from_angle(i*2.399)*(54+i%4*32))
		w.rebuild_hit_grid()
	if frame_number==285:
		w.time=719.99
		w.hp=20
		w.invulnerable=1
	if w.state in ["LEVEL_UP","CHEST"]:
		w.state="RUNNING"
		w.xp=0
		w.pending_chest.clear()
	for i in range(2):
		if w.state=="RUNNING":
			if frame_number<285:
				w.xp=0
				w.hp=maxf(12,w.hp)
			w.step(1.0/60,Vector2.ZERO if frame_number>210 else Vector2.from_angle(frame_number*.015)*.65)
		elif w.state=="FINALE":
			var movement=Vector2.ZERO
			if w.finale.elapsed>5 and w.finale.elapsed<10:movement=Vector2.RIGHT*.6
			if w.finale.elapsed>=10 and w.finale.elapsed<15:movement=Vector2.LEFT*.6
			w.step(1.0/60,movement)
	for id in w.sounds:game.audio.play(id)
	game.audio.set_finale_music(w.finale.active)
	w.sounds.clear()
	game.ui_time+=1.0/30
	game.queue_redraw()
	frame_number+=1
	if frame_number>=1395:finish.call_deferred()

func finish():
	finished=true
	FileAccess.open("res://qa/chapter_recording_result.json",FileAccess.WRITE).store_string(JSON.stringify({"chapter_complete":game.world.finale.complete,"victory":game.world.victory,"phase":game.world.finale.phase,"frames":frame_number},"  "))
	game.audio.shutdown()
	await create_timer(.1).timeout
	game.free()
	game=null
	await process_frame
	quit()
