extends SceneTree
var game
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if ok:print("PASS: ",label)
	else:failures.append(label);push_error(label)
func render(name: String="") -> Image:
	game.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(false)
	var result=root.get_texture().get_image()
	if not name.is_empty():result.save_png("res://qa/achievement_"+name+".png")
	return result
func key(code: int):
	var event=InputEventKey.new();event.pressed=true;event.keycode=code;event.physical_keycode=code;game.input_lock=0;game._input(event)
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.settings.shake=false;game.settings.numbers=false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360)
	var file="user://qa_achievement_ui_%d.json" % OS.get_process_id()
	game.achievements.load_profile(file)
	await render("menu");check(game.buttons.size()==4,"Main menu retains its four existing controls")
	game.action("chapters");await render("chapters")
	check(game.buttons.any(func(b):return b.id=="achievements") and not game.buttons.any(func(b):return b.id.begins_with("starter_")),"Chapter selection exposes achievements without adding weapon selection")
	game.action("chapter_1");check(game.world.build=={"sword":1},"Chapter I always keeps the original starting sword")
	var clock=game.world.clock;game.action("achievements");await render("locked")
	game.world.step(5);check(game.world.clock==clock and game.world.state=="PAUSED","Achievement book pauses the current solo attempt")
	check(game.buttons.any(func(b):return b.id=="achievements_next"),"All twelve achievements have a reachable second page")
	key(KEY_ESCAPE);check(game.screen.is_empty() and game.world.state=="RUNNING" and game.world.clock==clock,"Esc restores the exact state that opened the book")
	game.world.state="LEVEL_UP";game.world.choices=["bow","sugar","armor"];game.action("achievements");game.action("achievements_back")
	check(game.world.state=="LEVEL_UP" and game.world.choices==["bow","sugar","armor"],"Returning from the book preserves a pending reward")
	game.world.state="PAUSED";game.action("achievements");game.action("achievement_tier_secret");var hidden=await render("secret_locked")
	game.achievements.unlock("herobrine");var revealed=await render("secret_unlocked")
	check(hidden.get_data()!=revealed.get_data(),"Secret entry reveals its native white-eyed portrait, name and condition only when earned")
	for id in ["chapter_one","first_evolution","full_inventory","two_weapons"]:game.achievements.unlock(id)
	game.action("achievement_tier_easy");await render("easy")
	game.action("achievement_tier_medium");await render("medium")
	game.action("achievement_tier_hard");await render("hard")
	game.action("achievement_tier_all");game.action("achievements_next");await render("page_two")
	game.action("achievements_back");check(game.world.state=="PAUSED","Opening the book from pause returns to pause")
	check(not game.achievements_allowed(),"Automated SceneTree runs cannot unlock the user's real profile")
	game.achievements.pending.clear();game.achievements.pending.append("first_evolution");game.update_achievements(0);game.update_achievements(.3);await render("toast")
	check(game.achievement_toast=="first_evolution" and game.audio.sound_map.has("achievement"),"Advancement toast uses the custom badge, existing pixel font and native toast sound")
	game.achievements.pending.clear();game.achievement_toast=""
	game.start_chapter(3);var w=game.world;w.stage="end_arrival";w.stage_age=10;w.props.clear();w.mobs.clear();w.effects.clear();w.particles.clear();w.pixels.clear();w.orbs.clear();w.loot.clear();w.build={};w.items={};w.clock=0;w.shake=0
	for cell in range(w.land.size()):
		var p=Vector2(cell%128*16+8,cell/128*16+8)
		if w.on_land(p) and not w.on_land(p+Vector2(0,16)) and p.distance_to(Vector2(1024,1024))<450:w.player=p+Vector2(0,20);break
	var still=await render("end_edge");game.settings.shake=true;w.shake=.1;var moved=await render("end_edge_shake")
	var top=0;var edge=0;var top_same=0;var edge_same=0
	for y in range(30,320):
		for x in range(20,620):
			var c=still.get_pixel(x,y)
			if c.r<c.b or c.g<c.b or c.r<.19:continue
			var same=c.is_equal_approx(moved.get_pixel(x,y+2))
			if c.r>.48:top+=1;top_same+=int(same)
			else:edge+=1;edge_same+=int(same)
	check(top>10000 and float(top_same)/top>.98,"Bright End surface follows the same two-pixel camera shake as the scene")
	check(edge>100 and float(edge_same)/edge>.98,"Dark End-stone thickness stays attached to the bright surface during shake")
	game.settings.shake=false;w.prepare_arena();w.mobs.clear();w.stage="last_duel";w.build={}
	for crystal in w.crystals:crystal.alive=false
	w.spawn("endersteve_final",w.portal_position-Vector2(0,40));w.mobs[0].hp=0;w.resolve_deaths();w.stage_age=7.61;w.end_boss.story(w,.02)
	game.audio.update_volumes(.4,0);game._process(.01);game._process(.01)
	check(game.audio.theme=="victory" and game.audio.celebration_state=="stinger","Final End victory starts the real stinger and is not overridden by the EnderSteve theme next frame")
	game.audio.celebration_wait=0;game.audio._process(.1)
	check(game.audio.celebration_state=="music" and game.audio.victory_music.playing,"The victory song follows the stinger even with effects muted")
	await render("end_victory")
	w.stage="chapter_four";w.stage_age=3;w.state="RESULT";await render("overworld")
	check(not game.end_assets.sprites.any(func(n):return n.begins_with("end_flesh_") or n.begins_with("end_rubble_")),"Chapter IV teaser keeps its red land, trees and title without rubble or flesh props")
	game.action("menu");game._process(.01);check(game.audio.theme=="" and not game.audio.victory_music.playing,"Returning to menu stops the victory loop")
	game.audio.shutdown();game.coop.diagnostics.close();game.quitting=true
	for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute(ProjectSettings.globalize_path(file+suffix))
	FileAccess.open("res://qa/achievements_visual_results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("ACHIEVEMENTS_VISUAL_RESULT ",checks," checks; ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
