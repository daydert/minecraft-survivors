extends SceneTree
var game
var folder := "res://qa/ch5_cinema/"
func _initialize():run.call_deferred()
func render(name: String):
	game.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(folder+name+".png")
func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="review";game.settings.shake=false;root.size=Vector2i(640,360)
	game.action("chapter_5");var w=game.world;var n=w.notch;var f=n.finale;n.begin(w)
	for phase in ["chair","flight"]:
		n.change(phase);f.change(phase)
		var times: Array=[1.0,5.0,14.0,18.0,22.2,30.2,31.6,32.55,32.95,33.1,34.8,38.0,39.0,42.5] if phase=="chair" else [1.0,3.0,3.7,4.3,7.0,12.0,17.0,22.0,26.0,27.9,29.2,30.4]
		for t in times:
			f.age=t;w.clock=100+t;await render("%s_%05.2f"%[phase,t])
	for phase in ["to_ut","to_lanes","lanes_won","to_quake","to_code"]:
		n.change(phase)
		for t in [.8,1.65,2.1,2.6,3.3]:
			n.age=t;w.clock=50+t;await render("%s_%05.2f"%[phase,t])
	n.change("erase");f.begin_erase()
	for t in [0.0,.14,.18,.4,.6,1.6]:
		f.thrown=t;f.age=9+t;f.erase=.6;w.clock=109+t;await render("throw_%04.2f"%t)
	n.start_fists(w);n.fighter.state="wire"
	for t in [.0,.2,1.0,2.6]:
		n.fighter.age=t;w.clock=120+t;await render("wire_%04.2f"%t)
	if game.has_meta("ch5_view3d"):game.get_meta("ch5_view3d").release()
	await process_frame
	game.audio.shutdown();game.quitting=true;quit()
