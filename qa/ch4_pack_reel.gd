extends SceneTree
## Movie Maker reel of the tester pack in chapter IV: the minecart and the sky
## TNT in survival, the fat mass boss, then Herobrine's lure and his new stage II.
var game
var w
var frame := 0
class Bot:
	var t := 0.0
	var w
	func choose(_w):return 0
	func movement(world) -> Vector2:
		t += 1.0 / 60
		if world.stage == "finale" and world.ending.phase == "two":
			var c: Vector2 = world.ending.hb.p
			var v: Vector2 = (world.player - c).orthogonal().normalized()
			v += (c - world.player).normalized() * clampf(((world.player - c).length() - 110.0) / 60.0, -1, 1)
			return v.limit_length(1.0)
		return Vector2.from_angle(t * .55)
func _initialize():run.call_deferred()
func frames(k: int):
	for i in range(k):
		await process_frame;frame += 1
		if w != null and w.hp < 8:w.hp = 20.0
func secs(s: float):await frames(roundi(s * 30))
func run():
	game = load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.qa_mode = "";game.settings.fullscreen = false;game.settings.shake = true
	game.audio.update_volumes(.45, .6)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size = Vector2i(1280, 720)
	await frames(10)
	var bot := Bot.new()
	game.action("chapter_4");game.set_process_input(false)
	w = game.world;bot.w = w;game.qa_controller = bot
	await frames(5)
	if w.state == "INTRO":w.skip_intro()
	w.sword_drop = {};w.stage = "survival";w.note_presented = true;w.note_read = true
	w.build = {"sword":8, "shotgun":6, "sky_tnt":6, "tnt":5};w.items = {"minecart":3, "sugar":2};w.time = 340.0
	print("REEL survival");await secs(4)
	for k in range(3):
		w.active_item("cart");await secs(6)
	await secs(14)
	print("REEL finale")
	w.time = 719.5;await secs(2)
	w.player = w.ending.center + Vector2(0, 150)
	await secs(26)
	var e = w.ending
	e.clear_hazards();e.phase = "two";e.hb.perched = false;e.tower_h = 0;e.hb.p = e.center;e.hb.hp = float(e.data.two.hp);e.hb.max_hp = e.hb.hp;e.hb.scale = float(e.data.giant)
	e.hb.disguise = false;w.player = e.center + Vector2(110, 60);e.camera_at = e.center;e.music = "boss_two";e.queue = ["fault_smash", "zombies", "magma", "fault_smash", "hole", "zombies", "magma"];e.begin_move(w, "rest", .6)
	print("REEL two");await secs(42)
	game.quitting = true;quit()
