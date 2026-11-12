extends SceneTree
## Snapshots of the reworked portal shove: hit-stop, punch-in, flash, blood.
var game
func _initialize():run.call_deferred()
func render(name: String):
	if game.world.state=="PAUSED":game.world.state="RUNNING"
	game.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://qa/ch5_lines/"+name+".png")
func advance(seconds: float):
	for i in range(ceili(seconds*60)):
		var w=game.world
		if w.state=="PAUSED":w.state="RUNNING"
		if w.state=="LEVEL_UP":w.skip_reward()
		else:w.step(1.0/60,Vector2.ZERO)
func run():
	DirAccess.make_dir_recursive_absolute("res://qa/ch5_lines")
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="review";game.settings.numbers=false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360)
	game.action("chapter_5");var w=game.world;var n=w.notch
	w.db.data.waves=[{"at":0,"rate":0,"weights":{"token":1}}]
	for id in w.next_event:w.next_event[id]=99999.0
	w.bosses.terminal_done=true;w.bosses.loop_done=true
	w.time=719.5;w.spawn("token",w.player+Vector2(50,0));advance(.6)
	w.invulnerable=999
	var f=n.finale;n.change("chair");f.change("chair")
	for at in [30.2,31.5,32.8,33.1,34.5,36.5,38.6,41.5]:
		while f.age<at:w.step(1.0/60,Vector2.ZERO)
		await render("chair_%03d"%int(at*10))
	game.audio.shutdown();game.quitting=true
	print("CH5_CHAIR_DONE");quit()
