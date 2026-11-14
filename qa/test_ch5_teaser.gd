extends SceneTree
## Chapter IV ends on the "new location" card: Steve falls into the white source code.
var game
var checks=0
var failures=[]
var out="res://qa/ch5_teaser/"
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if ok:print("PASS: ",label)
	else:failures.append(label);push_error(label)
func render(name: String):
	game.queue_redraw();await process_frame;await process_frame;await process_frame;RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(out+name+".png")
func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="review";game.settings.shake=false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(1280,720)
	game.start_chapter(4);var w=game.world
	w.stage="finale";w.ending.phase="door";w.ending.age=float(w.ending.data.door.duration);w.ending.step_door(w,.01)
	check(w.state=="RESULT" and w.victory and game.FiveTeaser.shown(game),"The IV door ending shows the chapter V card")
	for t in [0.5,1.5,2.0,2.3,3.2,4.0,6.0,10.0]:
		game.five_teaser_age=t;await render("t%04.1f" % t)
	check(game.buttons.any(func(b):return b.id=="chapter_5") and game.buttons.any(func(b):return b.id=="menu"),"Continue into V and back to the menu")
	check(game.has_meta("ch5_view3d"),"The card is a 3D scene")
	game.action("menu");game.queue_redraw();await process_frame;await process_frame
	check(not game.has_meta("ch5_view3d"),"Leaving the card frees the 3D scene")
	print("CH5_TEASER_RESULT %d checks; %d failures" % [checks, failures.size()])
	quit()
