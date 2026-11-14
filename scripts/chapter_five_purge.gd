extends RefCounted
## The end of chapter V survival (tester Rodch, 13.11.2026). At 10:00 the purge
## terminal starts deleting Steve.dat. Run out of time and Steve turns to dust;
## break it and Steve tears out the game's core: a shockwave wipes the map, two
## minutes of overload follow (time races, levels pour in, gear goes past its
## limits, everything swarms him), then he transcends - invulnerable aura, white
## out, the world stops - and walks through the frozen game into a crack to Notch.
## 15.11: the run clock stops at 10:00 for the terminal's own 90 s; after the core
## the clock runs again from 10:00, slots stop having a limit, and a pulsing aura
## fights for him through the overload.
const AT := 600.0
const COUNTDOWN := 90.0
const SNAP := 4.2
const CORE := 5.6
const SURGE := 120.0
const ASCEND := 6.0
const WHITE := 1.6
const LEVEL_EVERY := 7.0
const CRACK_OPEN := 3.2
const ENTER := 1.6
var phase := ""
var age := 0.0
var id := -1
var left := COUNTDOWN
var term_p := Vector2.ZERO
var core_from := Vector2.ZERO
var wave := -1.0
var wave_from := Vector2.ZERO
var level_tick := 0.0
var spawn_tick := 0.0
var ring_tick := 0.0
var shown := 0.0
var crack := Vector2.ZERO
var step_tick := 0.0
var echoes: Array = []
var flash := 0.0
var cues := 0
## Overload aura: a pulse ring every few seconds and arcs to the nearest code.
var pulse := -1.0
var pulse_tick := 0.0
var arc_tick := 0.0
var arcs: Array = []
var hitstop := 0.0

func reset():
	phase = "";age = 0.0;id = -1;left = COUNTDOWN;wave = -1.0;level_tick = 0.0;spawn_tick = 0.0;ring_tick = 0.0
	shown = 0.0;step_tick = 0.0;echoes.clear();flash = 0.0;cues = 0
	pulse = -1.0;pulse_tick = 0.0;arc_tick = 0.0;arcs.clear();hitstop = 0.0

func active() -> bool:return phase != ""
## The world itself does not run (mobs, spawns, attacks) in these phases.
func frozen() -> bool:return phase in ["snap", "core", "stop", "enter"]
func cue(bit: int, at: float) -> bool:
	if age >= at and not (cues & (1 << bit)):
		cues |= 1 << bit;return true
	return false
func change(next: String):phase = next;age = 0.0;cues = 0

## Overload clock: 1x at the start, racing near the end of the two minutes.
func rate() -> float:
	if phase == "surge":return 1.0 + 6.0 * pow(age / SURGE, 2.0)
	if phase == "ascend":return 7.0 + 40.0 * age / ASCEND
	return 1.0
func progress() -> float:return clampf(1.0 - left / COUNTDOWN, 0, 1)

## The run clock does not move while the terminal counts (it shows 10:00).
func clock_frozen() -> bool:return phase in ["countdown", "snap", "core"]

func begin(w):
	w.bosses.abort(w)
	var side: float = -1.0 if w.player.x > w.SIZE / 2.0 else 1.0
	var at: Vector2 = (w.player + Vector2(150 * side, 70)).clamp(Vector2(140, 200), Vector2(w.SIZE - 140, w.SIZE - 140))
	var m = w.bosses.place(w, "terminal", at)
	if m == null:return
	w.time = AT
	m.purge = true;m.locked = false
	m.hp = 360.0 + 22.0 * w.level;m.max_hp = m.hp
	id = m.id;term_p = m.p;left = COUNTDOWN
	change("countdown")
	w.message = "rm -rf ./players/Steve.dat";w.message_timer = 3.5
	w.sound("ch4_hb_glitch", .1);w.sound("ch5_purge_alarm", .1)

## Returns true when the world must not run its normal step this frame.
func step(w, dt: float, movement: Vector2) -> bool:
	age += dt;flash = maxf(0, flash - dt)
	for i in range(echoes.size() - 1, -1, -1):
		echoes[i].t -= dt
		if echoes[i].t <= 0:w.sound(echoes[i].id, 0.0);echoes.remove_at(i)
	match phase:
		"":
			# a clock already past the window (debug jumps to 12:00) goes straight to Notch
			if w.time >= AT and w.time < AT + 60.0:begin(w)
			return false
		"countdown":
			left -= dt
			var t = w.mob_by_id(id)
			if t != null:
				term_p = t.p
				ring_tick -= dt
				if ring_tick <= 0:
					ring_tick = maxf(1.6, 4.0 - progress() * 2.4)
					for k in range(12):w.shoot(t.p + Vector2(0, -40), Vector2.from_angle(k * TAU / 12 + age) * 85.0, 2.0, "rm")
					w.sound("ch4_hb_tick", .1)
			if int(left) != int(left + dt) and left < 10.0 and left > 0:w.sound("select", 0.0)
			if left <= 0:
				change("snap");w.invulnerable = 99.0
				w.sound("ch5_snap", .1)
			return false
		"snap":
			if age >= SNAP:
				w.state = "RESULT";w.victory = false;w.hp = 0
			return true
		"core":
			core_step(w, dt)
			return true
		"surge":
			surge_step(w, dt)
			return false
		"ascend":
			ascend_step(w, dt)
			return false
		"stop":
			stop_step(w, dt, movement)
			return true
		"enter":
			# the rift swallows him: pulled into the middle, then darkness
			w.player = w.player.lerp(crack, minf(1.0, dt * 6.0))
			w.animation.advance(w, dt)
			if age >= ENTER:w.notch.begin(w)
			return true
	return false

## Called from the world when the purge terminal dies.
func terminal_died(w, m: Dictionary):
	core_from = m.p;term_p = m.p
	change("core")
	w.run_progress.award("terminal_original")
	w.invulnerable = 99.0
	w.shake = .9;flash = .35
	for o in w.mobs:
		if o.hp > 0 and not o.get("boss", false):o.stun = maxf(o.get("stun", 0.0), CORE + .5)
	w.shots.clear();w.zones.clear()
	w.message = "";w.message_timer = 0
	w.sound("ch4_hb_shatter", .1);w.sound("explosion", .1)

## Core beats (s): shatter 0, rise .7-1.9, streams 1.9-3.0, flight 3.0-3.9,
## absorbed 3.9, charge to 5.2, release at CORE.
func core_step(w, dt: float):
	if cue(0, .7):w.sound("ch5_core_rise", .1)
	if cue(1, 1.9):w.sound("ch4_hb_glitch", .1)
	if cue(2, 3.0):w.sound("ch5_portal_pass", .1)
	if cue(3, 3.9):w.sound("ch5_core_absorb", .1);w.shake = .6;flash = .4
	if cue(4, 4.6):w.sound("ch5_ascend", .1)
	if age > 3.9:w.shake = maxf(w.shake, .12 * smoothstep(3.9, CORE, age))
	if age >= CORE:
		change("surge");w.overcap = true
		wave = 0.0;wave_from = w.player;flash = .9;w.shake = 1.0;hitstop = .12
		w.invulnerable = 3.0
		pulse_tick = 1.2
		w.message = "ЯДРО ИГРЫ ПОГЛОЩЕНО";w.message_timer = 3.0
		w.sound("ch5_shockwave", .1)
		shown = w.time

## Where the core is during the cutscene.
func core_at(w) -> Vector2:
	var head: Vector2 = w.player + Vector2(0, -44)
	var high: Vector2 = core_from + Vector2(0, -92)
	if age < 1.9:return core_from + Vector2(0, -40).lerp(Vector2(0, -92), smoothstep(.5, 1.9, age)) + Vector2(0, sin(age * 3) * 2)
	if age < 3.0:return high + Vector2(sin(age * 9) * 1.5, sin(age * 4) * 3)
	if age < 3.9:
		var k: float = smoothstep(3.0, 3.9, age);k = k * k
		var arc: Vector2 = Vector2(0, -sin(k * PI) * 70)
		return high.lerp(head, k) + arc
	return head + Vector2(0, -sin(age * 6) * 2)

func surge_step(w, dt: float):
	hitstop = maxf(0, hitstop - dt)
	aura_step(w, dt)
	if wave >= 0:
		var before: float = wave
		wave += dt * 900.0
		for m in w.mobs:
			if m.hp <= 0 or m.get("boss", false):continue
			var d: float = m.p.distance_to(wave_from)
			if d >= before and d < wave:m.hp = 0;m.xp = 0;w.add_effect("ch5_spawn", m.p, .3)
		for pool in [w.shots]:
			for i in range(pool.size() - 1, -1, -1):
				if pool[i].p.distance_to(wave_from) < wave:pool.remove_at(i)
		if wave > 1400:wave = -1.0;w.zones.clear();w.deleted.clear();w.pending.clear();w.hint = {}
	# Levels pour in from the core.
	level_tick += dt
	if level_tick >= LEVEL_EVERY and w.state == "RUNNING":
		level_tick = 0.0
		w.xp = maxi(w.xp, w.db.required_xp(w.level))
		w.add_effect("ch5_breakpoint", w.player, .5)
	# Everything spawns around him, ever thicker.
	spawn_tick -= dt
	if spawn_tick <= 0:
		var k: float = age / SURGE
		spawn_tick = lerpf(.9, .35, k)
		var kinds := ["token","token","for_loop","if_else","recursion","try_catch","array","function","glitch_zombie","glitch_skeleton","null_ref"]
		var n: int = 3 + int(k * 6)
		for i in range(n):
			var a: float = w.rng.randf() * TAU
			var at: Vector2 = (w.player + Vector2.from_angle(a) * w.rng.randf_range(250, 330)).clamp(Vector2(60, 60), Vector2(w.SIZE - 60, w.SIZE - 60))
			w.spawn(kinds[w.rng.randi_range(0, kinds.size() - 1)], at)
	if age >= SURGE:
		change("ascend");w.message = "";w.sound("ch5_ascend", .1)

func ascend_step(w, dt: float):
	w.invulnerable = 1.0
	var r: float = aura(w)
	for m in w.mobs:
		if m.hp <= 0 or m.get("boss", false):continue
		var d: float = m.p.distance_to(w.player)
		if d < r:
			var out: Vector2 = w.player.direction_to(m.p) if d > .1 else Vector2.RIGHT
			m.p = w.move_actor(m.p, out * (r - d) * minf(1.0, dt * 8.0), m.radius)
	for i in range(w.shots.size() - 1, -1, -1):
		if w.shots[i].p.distance_to(w.player) < r:
			w.add_effect("ch5_spawn", w.shots[i].p, .2);w.shots.remove_at(i)
	if age >= ASCEND:
		change("stop");flash = WHITE
		# The crack opens toward the middle of the world, a short walk away.
		var to_mid: Vector2 = w.player.direction_to(Vector2(w.SIZE, w.SIZE) / 2.0)
		if to_mid == Vector2.ZERO:to_mid = Vector2.UP
		crack = (w.player + to_mid * 230.0).clamp(Vector2(160, 200), Vector2(w.SIZE - 160, w.SIZE - 120))
		w.message = "";w.sound("ch5_time_stop", .1)

## The overload fights for him: a ring of force every few seconds and lightning
## from the core into the nearest code. Bosses are never in this phase.
func aura_step(w, dt: float):
	var k: float = clampf(age / SURGE, 0, 1)
	for i in range(arcs.size() - 1, -1, -1):
		arcs[i].t -= dt
		if arcs[i].t <= 0:arcs.remove_at(i)
	if pulse >= 0:
		var before: float = pulse
		pulse += dt * 520.0
		var reach: float = pulse_reach(k)
		for m in w.mobs:
			if m.hp <= 0 or m.get("boss", false):continue
			var d: float = m.p.distance_to(w.player)
			if d >= before and d < minf(pulse, reach):
				w.hurt(m, 18.0 + 3.0 * w.level, w.player.direction_to(m.p) * 260.0)
		if pulse > reach:pulse = -1.0
	pulse_tick -= dt
	if pulse_tick <= 0:
		pulse_tick = lerpf(3.2, 1.4, k);pulse = 0.0
		w.sound("ch4_hb_tick", .1)
	arc_tick -= dt
	if arc_tick <= 0:
		arc_tick = lerpf(.7, .22, k)
		var best = null;var bd: float = 170.0 + 60.0 * k
		for m in w.in_radius(w.player, bd):
			if m.hp <= 0 or m.get("boss", false):continue
			var d: float = m.p.distance_to(w.player)
			if d < bd:best = m;bd = d
		if best != null:
			arcs.append({"from":w.player + Vector2(0, -20), "to":best.p + Vector2(0, -8), "t":.22, "seed":int(age * 997)})
			w.hurt(best, 10.0 + 2.0 * w.level)

func pulse_reach(k: float) -> float:return 110.0 + 90.0 * k

func aura(w) -> float:
	if phase == "surge":return 26.0 + 16.0 * clampf(age / SURGE, 0, 1)
	if phase == "ascend":return 40.0 + 110.0 * smoothstep(0, ASCEND * .8, age)
	if phase == "stop":return 150.0
	return 0.0

## Time has stopped: nothing moves but Steve, at his own plain walking speed.
func stop_step(w, dt: float, movement: Vector2):
	w.invulnerable = 1.0
	if cue(0, WHITE):w.sound("ch5_crack", .1)
	if age < WHITE * .5:return
	if movement.length_squared() > 0:
		w.facing = movement.normalized()
		var before: Vector2 = w.player
		w.player = w.move_actor(w.player, movement.limit_length() * float(w.db.data.player_speed) * .85 * dt, 6)
		w.player_visual.travel = before.distance_to(w.player);w.player_moving = true
		step_tick -= dt
		if step_tick <= 0:
			step_tick = .52
			w.sound("ch5_echo_step", 0.0)
			echoes.append({"t":.34, "id":"ch5_echo_step_far"})
	else:
		w.player_moving = false;w.player_visual.travel = 0.0
	w.animation.advance(w, dt)
	if age > WHITE + CRACK_OPEN * .6 and w.player.distance_to(crack) < 24:
		change("enter");w.sound("ch5_portal_pass", .1);w.shake = .5

## The HUD clock while the core burns: runs away and leaves the screen.
func clock_text(w) -> String:
	if phase in ["ascend", "stop", "enter"]:
		var t: float = w.time
		return "%d:%02d" % [int(t / 60), int(fposmod(t, 60))] if phase == "ascend" else "--:--"
	return ""
