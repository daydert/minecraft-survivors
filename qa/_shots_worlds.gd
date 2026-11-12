extends SceneTree
var game
func _initialize():run.call_deferred()
func render(name: String):
	game.queue_redraw();await process_frame;await process_frame;await process_frame;RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://qa/chapter_five/w_"+name+".png")
func adv(w,t):
	for i in range(int(t*60)):w.step(1.0/60)
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="review"
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360)
	game.action("chapter_5");var w=game.world;var n=w.notch;var f=n.finale
	n.begin(w);f.change("flight");n.change("flight");adv(w,8.0)
	await render("start")
	var v=game.get_meta("ch5_view3d")
	var ws: Array=[]
	for x in v.nodes.worlds:
		if not (x is Sprite3D):ws.append(x)
	for i in range(ws.size()):
		var d: Node3D=ws[i];var side: float=signf(d.position.x)
		v.nodes.cam_override=[d.position+Vector3(-side*17,11,22),d.position+Vector3(0,7.5,0)]
		adv(w,1.0/60);await render("d%d"%i)
	v.nodes.erase("cam_override")
	f.change("flight");n.change("flight");adv(w,f.FLIGHT_OTHER+1.0);await render("other");adv(w,2.0);await render("other2");adv(w,1.8);await render("other3")
	v.nodes.cam_override=[v.nodes.other.position+Vector3(6,3,2),v.nodes.other.position+Vector3(-2,3,-16)];adv(w,1.0/60);await render("other4")
	quit()
