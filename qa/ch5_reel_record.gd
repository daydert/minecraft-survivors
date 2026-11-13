extends SceneTree
## Real-time reel of chapter V for review, recorded with Movie Maker
## (--write-movie, --fixed-fps 30): picture, films and the game's own mix.
## Bot plays: stage one, the battle box, the QTE; hard cuts skip the other games.
var game
var w
var n
var marks: Array = []
var frame := 0
class Bot:
	var n
	var t := 0.0
	func choose(_w):return 0
	func movement(w) -> Vector2:
		t += 1.0 / 60
		if w.stage != "notch":
			if w.purge.phase in ["stop", "enter"]:return w.player.direction_to(w.purge.crack)
			return Vector2.from_angle(t * .7)
		if n.phase == "fight":return fight(w)
		if n.phase == "ut" and n.ut_state == "wave":return soul(w)
		return Vector2.ZERO
	func fight(w) -> Vector2:
		var c: Vector2 = n.CENTER;var p: Vector2 = w.player
		var v: Vector2 = (p - c).orthogonal().normalized() * (1.0 if int(t / 6.0) % 2 == 0 else -1.0)
		v += (c - p).normalized() * clampf(((p - c).length() - 120.0) / 80.0, -1, 1)
		for h in n.hz:
			var at: Vector2 = h.get("p", h.get("rect", Rect2()).get_center() if h.has("rect") else p)
			if h.kind == "select" and h.rect.grow(10).has_point(p):v += (p - h.rect.get_center()).normalized() * 2.0
			elif h.kind in ["block", "bolt", "clone"] and at.distance_to(p) < 40:v += (p - at).normalized() * 1.5
		return v.limit_length(1.0)
	func soul(_w) -> Vector2:
		var s: Vector2 = n.soul;var bx: Rect2 = n.ut_box
		if n.ut_mode == "blue":
			var jump: bool = fmod(t, .9) < .25
			return -n.ut_grav * (1.0 if jump else 0.0) + Vector2(sin(t * 1.3), 0) * (1 if n.ut_grav.y != 0 else 0) + Vector2(0, sin(t * 1.3)) * (1 if n.ut_grav.x != 0 else 0)
		var v: Vector2 = (bx.get_center() + Vector2(sin(t * .9) * bx.size.x * .25, cos(t * .7) * bx.size.y * .2) - s) / 40.0
		for b in n.ut_bullets:
			var d: Vector2 = s - b.p
			if d.length() < 30:v += d.normalized() * (30 - d.length()) / 12.0
		for sel in n.ut_selects:
			if sel.rect.grow(8).has_point(s):v += (s - sel.rect.get_center()).normalized() * 2.0
		for bl in n.ut_blasters:
			var dir := Vector2.from_angle(bl.angle);var rel: Vector2 = s - bl.p
			if absf(rel.cross(dir)) < 22:v += dir.orthogonal() * signf(rel.cross(dir) + .01) * 2.0
		return v.limit_length(1.0)
func _initialize():run.call_deferred()
func mark(name: String):marks.append([name, frame / 30.0]);print("REEL ", name, " ", frame / 30.0)
func frames(k: int):
	for i in range(k):
		await process_frame;frame += 1
		if w != null and w.stage == "notch" and n.phase in ["fight", "ut"] and w.hp < 7:w.hp = 20.0
		if w != null and w.stage != "notch" and OS.get_environment("REEL") == "purge" and w.hp < 8:w.hp = 20.0
func secs(s: float):await frames(roundi(s * 30))
func until(cond: Callable, limit: float):
	var k := 0
	while not cond.call() and k < limit * 30:await frames(1);k += 1
func run():
	game = load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.qa_mode = "";game.settings.fullscreen = false;game.settings.shake = true
	game.settings.music = .45;game.settings.effects = .6;game.audio.update_volumes(.45, .6)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size = Vector2i(1280, 720)
	await frames(10)
	var bot := Bot.new()
	game.action("chapter_5");game.set_process_input(false)
	w = game.world;n = w.notch;bot.n = n;game.qa_controller = bot
	await frames(5)
	if w.state == "INTRO":w.skip_intro()
	await frames(5);print("REEL state ", w.state)
	var only: String = OS.get_environment("REEL")
	var f = n.finale
	if only == "purge":
		# Tester pack: 10:00 terminal, the core, the overload, stopped time, the crack.
		w.sword_drop = {};w.build = {"sword":8, "bow":8, "debug_stick":7, "command_block":6};w.items = {"sugar":3, "knowledge_book":2}
		w.bosses.terminal_done = true;w.bosses.loop_done = true;w.time = 594.0;mark("before_purge")
		await until(func():return w.purge.phase == "countdown", 10);mark("countdown")
		await secs(14)
		var t = w.mob_by_id(w.purge.id)
		if t != null:w.hurt(t, t.hp + 1)
		mark("core");await until(func():return w.purge.phase == "surge", 6);mark("surge")
		await secs(26);w.purge.age = 104.0;mark("surge_late")
		await until(func():return w.purge.phase == "ascend", 20);mark("ascend")
		await until(func():return w.purge.phase == "stop", 10);mark("stop")
		await until(func():return w.stage == "notch", 20);mark("notch");await secs(10)
		print("REEL_MARKS ", JSON.stringify(marks));game.quitting = true;quit();return
	if only in ["", "fight"]:
		# The last seconds of survival lead straight into him.
		w.sword_drop = {};w.build = {"sword":6, "bow":5};w.time = float(w.db.data.duration) - 5.0;mark("survival_end")
		await until(func():return w.stage == "notch", 10)
		mark("notch_intro");await until(func():return n.phase == "fight", 90)
		mark("stage_one");w.build = {"sword":6, "bow":5}
		await secs(26);n.hp = minf(n.hp, n.FIGHT_HP * .49);mark("stage_one_hardcore")
		await secs(24);n.hp = 0.0
		await until(func():return n.phase == "to_ut", 5);mark("portal_to_ut")
	if only != "":w.sword_drop = {}
	if only == "ut":n.begin(w);n.change("to_ut");mark("portal_to_ut")
	if only in ["", "fight", "ut"]:
		await until(func():return n.phase == "ut", 8);mark("undertale")
		var turns := 0
		while n.phase == "ut":
			match n.ut_state:
				"menu":
					await secs(.7)
					if n.ut_state != "menu":continue
					if turns == 1:n.ut_choice = 3;n.press(w, "accept")
					else:n.ut_choice = 0;n.press(w, "accept")
				"bar":
					await until(func():return n.bar >= .47 or n.ut_state != "bar", 3);n.press(w, "accept")
				"text":
					await secs(1.2);n.press(w, "accept");await secs(.2);n.press(w, "accept");turns += 1
					if turns == 8:n.ut_hp = minf(n.ut_hp, 20.0)
				_:await frames(1)
		mark("portal_to_lanes");await secs(4.6)
		mark("cut_portal_to_fighter");n.change("lanes_won");await secs(4.6)
		mark("cut_portal_to_quake");n.change("to_quake");await secs(4.6)
		mark("cut_quake_won");n.change("quake_won");await until(func():return n.phase == "code", 12)
		await secs(3)
	if only in ["", "fight", "ut", "final"]:
		if only == "final":n.begin(w)
		mark("cut_deletion");n.change("erase");f.begin_erase();await secs(4)
		for k in range(14):n.press(w, "accept");await secs(.2)
		await until(func():return n.phase == "qte", 20);mark("qte")
		var missed := false
		while n.phase == "qte":
			var q = n.qte
			if not q.finishing and not q.resolved and q.age >= .45:
				# One honest mistake so the failed exchange is on the reel too.
				if q.beat == 3 and not missed:missed = true;n.press(w, "down")
				else:n.press(w, q.expected())
			await frames(1)
		mark("chair");await until(func():return n.phase != "chair", 80)
		mark("flight");await until(func():return n.phase != "flight", 60)
		mark("credits");await until(func():return n.phase != "credits", 80)
		await secs(1)
	if only in ["", "fight", "ut", "final", "bad"]:
		if only == "bad":n.begin(w);await secs(1)
		mark("cut_bad_qte");w.state = "RUNNING";n.change("erase");f.begin_erase();await secs(2)
		for k in range(14):n.press(w, "accept");await secs(.2)
		await until(func():return n.phase == "qte", 20);mark("qte_lost")
		await until(func():return n.phase != "qte", 30);mark("bad_end_film")
		await until(func():return n.phase == "bad_credits", 20);mark("bad_credits")
		await until(func():return w.state == "RESULT", 40);await secs(2)
	FileAccess.open("res://qa/cinematics/reels/ch5_%s_marks.json" % (only if only != "" else "all"), FileAccess.WRITE).store_string(JSON.stringify(marks, "  "))
	game.quitting = true;quit()
