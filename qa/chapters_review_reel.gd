extends SceneTree
## Review reel of chapters I-III (13.11): the opening minute, a mid-run minute
## and the run into each finale, played by the survivor bot, recorded with Movie Maker.
var game
var w
var frame := 0
func _initialize():run.call_deferred()
func frames(k: int):
	for i in range(k):
		await process_frame;frame += 1
		if w != null and w.hp < 8:w.hp = 20.0
		if w != null:w.invulnerable = maxf(w.invulnerable, 1.0)
		if w != null and w.state == "RESULT":return
func secs(s: float):await frames(roundi(s * 30))
func run():
	game = load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.qa_mode = "";game.settings.fullscreen = false;game.settings.shake = true
	game.audio.update_volumes(.45, .6)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size = Vector2i(1280, 720)
	await frames(10)
	var only: String = OS.get_environment("REEL")
	for ch in [1, 2, 3]:
		if only != "" and only != str(ch):continue
		game.action("chapter_%d" % ch);game.set_process_input(false)
		w = game.world;game.qa_controller = load("res://scripts/autoplay_bot.gd").new("sword")
		print("REEL chapter_%d start %.1f" % [ch, frame / 30.0])
		await secs(12)
		if w.state == "INTRO":w.skip_intro()
		if w.has_method("sword_waiting"):w.sword_drop = {}
		await secs(58)
		w.time = 330.0;print("REEL chapter_%d mid %.1f" % [ch, frame / 30.0])
		await secs(40)
		w.time = float(w.db.data.duration) - 8.0;w.invulnerable = 9999.0;print("REEL chapter_%d finale %.1f" % [ch, frame / 30.0])
		await secs(110)
	game.quitting = true;quit()
