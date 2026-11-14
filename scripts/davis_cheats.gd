extends RefCounted
## DAVIS lab cheats around one solo world step. Every hook is neutral when nothing is on.
const VW = preload("res://scripts/chapter_five_world.gd")
const CHAIN_RADIUS := 40.0
const CHAIN_DAMAGE := 22.0
const CHAIN_PER_FRAME := 10

var saved_alive: Dictionary = {}
var saved_quake := -1.0
var saved_fighter := -1.0
var god_active := false

static func allowed(g) -> bool:
	return not g.coop.active and "run_progress" in g.world and g.qa_mode.is_empty() and g.autoplay_style.is_empty() and not g.stress_mode

## Writes the lab switches into the world and returns the time scale for this step.
func before(g) -> float:
	var lab = g.lab
	var w = g.world
	if not allowed(g):return 1.0
	var on: bool = lab.any_cheat()
	w.cheat_speed = float(lab.SPEED_STEPS[int(lab.cheats.speed)])
	w.cheat_magnet = 25.0 if lab.cheats.magnet else 1.0
	w.cheat_peace = bool(lab.cheats.peace)
	w.db.data["cheat_damage"] = lab.damage_scale()
	w.db.data["cheat_interval"] = .33 if lab.cheats.rapid else 1.0
	if lab.cheats.overcap and not w.overcap:w.overcap = true;w.set_meta("davis_overcap", true)
	elif not lab.cheats.overcap and w.has_meta("davis_overcap"):w.overcap = false;w.remove_meta("davis_overcap")
	if on:w.run_progress.enabled = false
	saved_alive.clear()
	if lab.cheats.chain:
		for m in w.mobs:
			if m.hp > 0 and not m.get("boss", false) and not m.get("allied", false):saved_alive[m.id] = m.p
	god_active = bool(lab.cheats.god) and w.hp > 0
	saved_quake = -1.0;saved_fighter = -1.0
	if god_active:
		# A huge pool for the step: nothing inside it can reach zero; refilled right after.
		w.hp = 1000000.0
		if w is VW and w.stage == "notch":
			if w.notch.phase == "quake" and not w.notch.quake.players.is_empty():saved_quake = float(w.notch.quake.players[0].hp)
			if w.notch.phase == "fighter" and not w.notch.fighter.fighters.is_empty():saved_fighter = float(w.notch.fighter.fighters[0].hp)
	return lab.game_scale() if on else 1.0

func after(g):
	var w = g.world
	if not allowed(g):return
	var full := float(w.db.data.player_hp)
	if god_active:
		w.hp = full
		if w is VW and w.stage == "notch":
			if saved_quake >= 0 and w.notch.phase == "quake" and not w.notch.quake.players.is_empty():
				w.notch.quake.players[0].hp = maxf(float(w.notch.quake.players[0].hp), saved_quake)
			if saved_fighter >= 0 and w.notch.phase == "fighter" and not w.notch.fighter.fighters.is_empty():
				w.notch.fighter.fighters[0].hp = maxf(float(w.notch.fighter.fighters[0].hp), saved_fighter)
	elif w.hp > full * 100:
		w.hp = full
	god_active = false
	if saved_alive.is_empty():return
	var alive: Dictionary = {}
	for m in w.mobs:
		if m.hp > 0:alive[m.id] = true
	var booms := 0
	for id in saved_alive:
		if alive.has(id):continue
		w.explode(saved_alive[id], CHAIN_RADIUS, CHAIN_DAMAGE * g.lab.damage_scale())
		booms += 1
		if booms >= CHAIN_PER_FRAME:break
	saved_alive.clear()

# ------------------------------------------------------------------ actions right now

static func now(g, id: String) -> bool:
	var w = g.world
	match id:
		"kill":
			var boss_kinds: Array = VW.BOSS_KINDS if w is VW else []
			for m in w.mobs.duplicate():
				if m.hp <= 0 or m.get("boss", false) or m.get("allied", false) or m.kind in boss_kinds:continue
				if w.has_method("neutral") and w.neutral(m):continue
				w.add_effect("explosion", m.p, .35, {"radius":14.0})
				w.hurt(m, m.hp + 100000.0)
			w.resolve_deaths()
			w.sound("explosion", .1);w.shake = .3
		"horde":
			var kinds: Array = w.db.wave(w.time).weights.keys()
			if kinds.is_empty():return false
			for i in range(40):w.spawn(kinds[i % kinds.size()])
			w.message = "ОРДА";w.message_timer = 2.0
		"level":
			w.xp = maxi(w.xp, w.db.required_xp(w.level))
		"heal":
			w.hp = float(w.db.data.player_hp);w.sound("pickup")
		"time":
			w.time = minf(float(w.time) + 60.0, float(w.db.data.duration) - .5)
		"gear":
			g.lab.apply_loadout(w, g.lab.loadout(w.chapter_number()), g.lab.hero_level)
		"target":
			g.lab.begin_target(w, g.lab.selected_target(w.chapter_number()))
	return true

# ------------------------------------------------------------------ presentation

static func draw(g):
	if not allowed(g) or g.world.state == "MENU" or not g.lab.any_cheat():return
	if g.lab.cheats.disco and g.screen.is_empty():
		var hue: float = fmod(g.ui_time * .45, 1.0)
		var beat: float = .5 + .5 * sin(g.ui_time * TAU * 2.0)
		g.draw_rect(Rect2(0, 0, 640, 360), Color.from_hsv(hue, .85, 1.0, .14 + .1 * beat))
		for i in range(6):
			var a: float = g.ui_time * (.7 + i * .13) + i * 1.7
			var c := Vector2(320, 180) + Vector2(cos(a) * 260, sin(a * 1.3) * 150)
			g.draw_circle(c, 26 + 10 * beat, Color.from_hsv(fmod(hue + i / 6.0, 1.0), .9, 1.0, .13))
	g.text_at("DAVIS · " + " · ".join(g.lab.active_names()), Vector2(6, 354), 6, Color(1, 1, 1, .55))
