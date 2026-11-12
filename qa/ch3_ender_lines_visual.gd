extends SceneTree
## Snapshots of the reworked Ender Steve lines: screams, the chains, the deletion.
var game
func _initialize():run.call_deferred()
func render(name: String):
	game.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://qa/ch3_ender/"+name+".png")
func advance(seconds: float):
	for i in range(ceili(seconds*60)):game.world.step(1.0/60,Vector2.ZERO)
func run():
	DirAccess.make_dir_recursive_absolute("res://qa/ch3_ender")
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.settings.shake=false;game.settings.numbers=false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360)
	game.action("chapter_3");var w=game.world;w.stage="survival";w.invulnerable=999;w.db.data.events=[];w.db.data.waves=[{"at":0,"rate":0,"weights":{"endermite":1}}]
	w.echo_count=1;w.spawn("endersteve",w.player+Vector2(60,0));advance(.15);await render("scream_a");advance(.9);await render("scream_b")
	w.lines.clear();w.mobs.clear();w.echo_count=4;w.spawn("endersteve",w.player+Vector2(60,-20));advance(1.2);await render("echo5_a")
	var e=w.end_boss
	for t in range(60):
		advance(.5)
		if w.lines.size()>0 and w.lines.back().age>=0 and w.lines.back().text=="НАЧНЁМ!":break
	advance(.2);await render("echo5_scream")
	w.lines.clear();w.mobs.clear();w.prepare_arena();w.portal_lit=false;w.stage="last_duel";w.spawn("endersteve_final",w.portal_position+Vector2(70,55));w.player=w.portal_position+Vector2(-55,80);w.scene_camera=w.portal_position+Vector2(0,15)
	var m=w.mobs.back();m.hp=0;w.resolve_deaths();advance(e.CLASH_LENGTH+.1)
	advance(e.DOWN_MARKS.free-.2);await render("down_chains");advance(.3);await render("down_burst");advance(1.6);await render("down_talk")
	advance(e.DOWN_LENGTH);advance(7.5)
	var marks=e.SIT_MARKS
	for spec in [["sit_look",marks.look+2.0],["sit_long",26.7+3.5],["sit_delete",marks.delete+.12],["sit_delete2",marks.delete+4.0],["sit_gift",marks.gift+1.5]]:
		advance(spec[1]-w.stage_age);await render(spec[0])
	advance(e.SIT_LENGTH-w.stage_age+.05)
	for spec in [["restore_run",1.2],["restore_cast",5.5],["restore_tear",8.3],["restore_tear2",9.6]]:
		advance(spec[1]-w.stage_age);await render(spec[0])
	game.audio.shutdown();game.coop.diagnostics.close();game.quitting=true
	print("CH3_ENDER_VISUAL_DONE ",w.stage);quit()
