extends SceneTree
var game
var folder := "res://qa/ch5_throw/"
func _initialize():run.call_deferred()
func render(name: String):
	game.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(folder+name+".png")
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="review";game.settings.shake=false;root.size=Vector2i(640,360)
	game.action("chapter_5");var w=game.world;var n=w.notch;var f=n.finale;n.begin(w)
	n.change("erase");f.begin_erase();f.presses=14
	for t in [0.0,.2,.4,.5,.66,.85,.98,1.05,1.2,1.5,2.0,2.8,3.4,4.2]:
		f.thrown=t;f.age=9+t;f.erase=.7;w.clock=109+t;await render("throw_%04.2f"%t)
	if game.has_meta("ch5_view3d"):game.get_meta("ch5_view3d").release()
	await process_frame
	game.audio.shutdown();game.quitting=true;quit()
