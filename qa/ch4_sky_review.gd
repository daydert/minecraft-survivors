extends SceneTree
var game
func _initialize():run.call_deferred()
func shot(name: String):
	game.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://qa/ch4_sky/"+name+".png")
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="review";game.settings.shake=false;root.size=Vector2i(640,360)
	game.action("chapter_4");var w=game.world;w.state="RUNNING";w.stage="survival";w.sword_drop={};w.note_presented=true;w.invulnerable=999;w.time=300
	w.build={"sky_tnt":8};w.items={}
	for i in range(30):w.spawn("flayed_zombie",w.player+Vector2.from_angle(i)*90)
	w.cooldowns["sky_tnt"]=0
	for i in range(160):
		w.step(1.0/60)
		if i in [50,62,70,80,95,110,125,140]:await shot("sky_%03d"%i)
	quit()
