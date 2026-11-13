extends SceneTree
var game
func _initialize():run.call_deferred()
func shot(n: String):
	game.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://qa/ch1_assault/"+n+".png")
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="review";game.settings.shake=false;root.size=Vector2i(640,360)
	game.action("chapter_1");var w=game.world;w.skip_intro();w.build={"sword":6,"bow":4};var f=w.finale;f.begin(w);f.skip_to_fight(w);w.invulnerable=999;w.player=f.CENTER+Vector2(60,140)
	var t=0
	for i in range(60*14):
		w.step(1.0/60,Vector2.from_angle(i*.02)*.6);w.invulnerable=999
		if i%35==0 and i>120:await shot("a_%03d"%(i/35))
	quit()
