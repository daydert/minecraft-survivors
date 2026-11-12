extends SceneTree
var game
func _initialize():run.call_deferred()
func render(name: String):
	game.queue_redraw();await process_frame;await process_frame;await process_frame;RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://qa/chapter_five/s_"+name+".png")
func adv(w,t):
	for i in range(int(t*60)):w.step(1.0/60)
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="review"
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360)
	game.action("chapter_5");var w=game.world;var n=w.notch;var f=n.finale
	n.begin(w);f.begin_erase();n.change("erase");adv(w,2.0)
	for k in range(14):n.press(w,"accept")
	adv(w,.25);await render("throw");adv(w,.5);await render("impact");adv(w,1.5);await render("stuck")
	f.change("chair");n.change("chair");adv(w,f.CHAIR_STAB-.2);await render("before")
	adv(w,.8);await render("stab");adv(w,1.6);await render("back");adv(w,2.0);await render("face");adv(w,3.0);await render("pull");adv(w,1.6);await render("wide")
	f.change("flight");n.change("flight");adv(w,2.0);await render("door");adv(w,1.6);await render("door_open")
	f.change("credits");n.change("credits");adv(w,6.8);await render("credits")
	n.start_lanes(w);n.redstone=999
	var layout=[[0,0,1],[0,1,0],[4,2,0],[5,3,0],[1,4,0],[2,0,4],[6,1,3],[7,2,5],[5,4,3],[3,3,6]]
	for l in layout:
		n.card=l[0];n.card_ready[l[0]]=0;n.cursor=Vector2i(l[2],l[1]);n.press(w,"accept")
	var kinds=["baby","spider","slime","vindicator","skeleton","ravager","zombie","elite"]
	for i in range(kinds.size()):n.spawn_walker(w,kinds[i],i%5,330.0+i*34)
	n.schedule.clear()
	adv(w,1.5);n.blasts.append({"p":Vector2(380,200),"age":0.0});adv(w,.12);await render("lanes")
	adv(w,2.0);await render("lanes2")
	quit()
