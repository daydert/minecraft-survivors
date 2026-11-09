extends SceneTree
var game
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if ok:print("PASS: "+label)
	else:failures.append(label);push_error(label)
func advance(seconds: float):
	for i in range(ceili(seconds*60)):game.world.step(1.0/60)
func render(name: String="") -> Image:
	game.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(false)
	var image=root.get_texture().get_image()
	if not name.is_empty():image.save_png("res://qa/ghast_"+name+".png")
	return image
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process_input(false);game.set_process(false);game.set_physics_process(false);game.qa_mode="review"
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360);game.settings.shake=false
	game.action("chapter_2");game.world.reset(724);game.world.build={}
	game.world.prepare_arena();advance(1.7);var hover=await render("hover")
	check(game.world.stage=="arrival" and not game.world.ghast.ruptured,"The opening shows the large Ghast before the Wither")
	advance(1.7);var charge=await render("charge")
	check(hover.get_data()!=charge.get_data(),"Native attacking eyes and mouth change the pose")
	advance(1.65);await render("pressure")
	advance(.25);var burst=await render("burst")
	check(game.world.ghast.pieces.size()==17,"The visible rupture contains separate pieces, not a disappearing whole sprite")
	advance(.6);var emergence=await render("emergence")
	check(burst.get_data()!=emergence.get_data(),"Fragments travel while the Wither emerges from inside")
	game.world.state="PAUSED";var age=game.world.stage_age;var a=await render("paused")
	game.ui_time+=8;game.world.step(3);var b=await render()
	check(age==game.world.stage_age and a.get_data()==b.get_data(),"Pause freezes Ghast debris and every emergence pose")
	game.world.state="RUNNING";var resumed=await render()
	check(resumed.get_data()==emergence.get_data(),"Closing pause restores the exact reveal frame")
	advance(1.4);await render("wither_reveal")
	advance(3);await render("fight")
	check(game.world.stage=="wither","The intro hands off to the existing Wither battle")
	game.action("chapter_2");game.world.build={"tnt":8};game.world.evolved={"tnt":true};game.world.mobs.clear();game.world.magma.clear()
	game.world.place_explosive("tnt",game.world.db.stats("tnt",8,true))
	game.world.facing=Vector2.UP
	for i in range(85):game.world.update_explosives(1.0/60)
	await render("tnt_delayed")
	for i in range(30):game.world.update_explosives(1.0/60)
	await render("tnt_flight")
	var children=false
	for i in range(80):
		game.world.update_explosives(1.0/60)
		if game.world.explosives.any(func(e):return e.get("child",false)):
			children=true;break
	await render("tnt_cluster")
	check(children,"Evolved TNT visibly branches into smaller flying charges")
	game.world.prepare_arena();game.world.stage="portal";game.world.mobs.clear();game.world.ghast.reset();game.world.explosives.clear();game.world.tnt_groups.clear()
	game.world.player=Vector2(800,900);game.world.defeated_boss={"p":game.world.player};game.world.arena_camera=game.world.player+Vector2(0,-28)
	await render("before_eye")
	game.world.apply_upgrade("ender_eye");advance(1.3);await render("portal_pan")
	var portal_screen: Vector2=game.world.portal_position-game.world.camera()+Vector2(320,180)
	check(portal_screen.x<450 and portal_screen.y<290,"After pickup the portal is brought into view")
	FileAccess.open("res://qa/ghast_visual_results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	game.audio.shutdown();await create_timer(.2).timeout;game.free();game=null
	print("GHAST_VISUAL_RESULT ",checks," checks; ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
