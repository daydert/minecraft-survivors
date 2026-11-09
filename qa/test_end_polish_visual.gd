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
	if not name.is_empty():result.save_png("res://qa/end_polish_"+name+".png")
	return result
func key(code: int):
	var event=InputEventKey.new();event.pressed=true;event.keycode=code;event.physical_keycode=code;game._input(event)
func advance(seconds: float):
	for i in range(ceili(seconds*60)):game.world.step(1.0/60)
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.settings.shake=false;game.qa_mode="review"
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360)
	check(not game.end_assets_loaded and not game.textures.has("end_dragon_atlas"),"Menu and cooperative entry do not load the large End atlas")
	game.action("chapter_3");var w=game.world;w.stage="survival";w.db.data.events=[];w.db.data.waves=[{"at":0,"rate":0,"weights":{"endermite":1}}];w.invulnerable=60
	w.build={"mace":8};w.items={};w.facing=Vector2.RIGHT;w.spawn("endermite_brood",w.player+Vector2(35,0));w.rebuild_hit_grid();w.update_attacks(.01)
	advance(.3);var windup=await render("mace_windup");advance(.35);var impact=await render("mace_attack")
	check(windup.get_data()!=impact.get_data(),"Mace windup and descending strike use different complete held poses")
	w.build={"spear":8,"shield":8};w.items={"elytra":5,"ender_pearl":5};w.evolved={"spear":true};w.jump_age=-1;w.jump_height=0;w.facing=Vector2.RIGHT;w.shield_charges=7
	key(KEY_SPACE);await render("elytra")
	check(w.flight>0,"Physical Space activates the real elytra ability")
	key(KEY_SHIFT);var rocket=await render("rocket")
	check(w.rocket and w.dash_left>0,"Physical Shift activates the evolved spear flight")
	key(KEY_E);check(w.effects.any(func(e):return e.kind=="end_pearl"),"Physical E creates a visible pearl throw")
	w.state="PAUSED";var age=w.clock;var left=w.dash_left;w.step(3);w.state="RUNNING";var exact=await render()
	check(w.clock==age and w.dash_left==left,"Paused flight preserves its movement and animation clocks")
	w.prepare_arena();w.stage="last_duel";w.mobs.clear();w.crystals.clear();w.build={};w.player=Vector2(1024,1110);w.scene_camera=Vector2(1024,1060);w.spawn("endersteve_final",Vector2(1024,1020));var m=w.mobs[0]
	m.phase="windup";m.charge=Vector2.DOWN;w.animation.set_pose(m.visual,"windup",.15);m.visual_dir=Vector2.DOWN
	var raised=await render("endersteve_windup")
	w.animation.set_pose(m.visual,"slash",.22);m.phase="rush";var slash=await render("endersteve_slash")
	check(raised.get_data()!=slash.get_data(),"EnderSteve has a genuine articulated sword windup and slash")
	w.animation.set_pose(m.visual,"cast",.35);m.phase="cast";await render("endersteve_cast")
	w.end_boss.shot(w,m.p,Vector2.DOWN,100,2,0,true)
	check(w.projectiles.any(func(b):return b.kind=="end_blade"),"EnderSteve casts actual flying enchanted blades")
	game.qa_mode="end_scale";game.prepare_end_capture();await render("same_scale")
	check(game.world.db.data.mobs.endersteve_final.radius==6,"EnderSteve has the player's body and collision size")
	game.qa_mode="end_betrayal";game.prepare_end_capture();var ritual=await render("rift")
	age=game.world.clock;key(KEY_L);game.world.step(5);check(game.world.clock==age and game.screen=="stats","L freezes the final scene and Compatibility shader clock")
	key(KEY_L);var restored=await render()
	check(restored.get_data()==ritual.get_data(),"Closing L restores the exact final distortion frame")
	game.action("menu");check(not game.end_assets_loaded and not game.textures.has("end_dragon_atlas"),"Leaving the End releases its large textures")
	game.audio.shutdown();game.coop.diagnostics.close();game.quitting=true
	FileAccess.open("res://qa/end_polish_visual_results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("END_POLISH_VISUAL_RESULT ",checks," checks; ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
