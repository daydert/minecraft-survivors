extends RefCounted
## The end of chapter V survival (tester Rodch, 13.11.2026). At 10:00 the purge
## terminal starts deleting Steve.dat. Run out of time and Steve turns to dust;
## break it and Steve tears out the game's core: a shockwave wipes the map, two
## minutes of overload follow (time races, levels pour in, gear goes past its
## limits, everything swarms him), then he transcends - invulnerable aura, white
## out, the world stops - and walks through the frozen game into a crack to Notch.
const AT := 600.0
const COUNTDOWN := 80.0
const SNAP := 4.2
const CORE := 3.6
const SURGE := 120.0
const ASCEND := 6.0
const WHITE := 1.6
const LEVEL_EVERY := 7.0
const CRACK_OPEN := 2.4
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

func reset():
	phase = "";age = 0.0;id = -1;left = COUNTDOWN;wave = -1.0;level_tick = 0.0;spawn_tick = 0.0;ring_tick = 0.0
	shown = 0.0;step_tick = 0.0;echoes.clear();flash = 0.0;cues = 0

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

func begin(w):
	var side: float = -1.0 if w.player.x > w.SIZE / 2.0 else 1.0
	var at: Vector2 = (w.player + Vector2(150 * side, 70)).clamp(Vector2(140, 200), Vector2(w.SIZE - 140, w.SIZE - 140))
	var m = w.bosses.place(w, "terminal", at)
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
			if w.time >= AT and w.time < AT + 60.0 and not w.bosses.active():begin(w)
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
			if age >= .9:w.notch.begin(w)
			return true
	return false

## Called from the world when the purge terminal dies.
func terminal_died(w, m: Dictionary):
	core_from = m.p;term_p = m.p
	change("core")
	w.invulnerable = 99.0
	w.shake = .5
	w.message = "";w.message_timer = 0
	w.sound("ch4_hb_shatter", .1);w.sound("explosion", .1)

func core_step(w, dt: float):
	if cue(0, 1.0):w.sound("ch5_core_rise", .1)
	if cue(1, 2.35):w.sound("ch5_core_absorb", .1)
	if age >= CORE:
		change("surge");w.overcap = true
		wave = 0.0;wave_from = w.player;flash = .6;w.shake = .8
		w.invulnerable = 2.0
		w.message = "ЯДРО ИГРЫ ПОГЛОЩЕНО";w.message_timer = 3.0
		w.sound("ch5_shockwave", .1)
		shown = w.time

## Where the core is during the cutscene.
func core_at(w) -> Vector2:
	var head: Vector2 = w.player + Vector2(0, -44)
	if age < .9:return core_from + Vector2(0, -40 - 26 * smoothstep(0, .9, age))
	if age < 1.9:
		var k: float = smoothstep(.9, 1.9, age)
		var arc: Vector2 = Vector2(0, -sin(k * PI) * 60)
		return (core_from + Vector2(0, -66)).lerp(head, k) + arc
	return head + Vector2(0, -sin(age * 6) * 2)

func surge_step(w, dt: float):
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
		crack = (w.player + to_mid * 230.0).clamp(Vector2(120, 120), Vector2(w.SIZE - 120, w.SIZE - 120))
		w.message = "";w.sound("ch5_time_stop", .1)

func aura(w) -> float:
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
	if age > WHITE + CRACK_OPEN * .6 and w.player.distance_to(crack) < 20:
		change("enter");w.sound("ch5_portal_pass", .1)

## The HUD clock while the core burns: runs away and leaves the screen.
func clock_text(w) -> String:
	if phase in ["ascend", "stop", "enter"]:
		var t: float = w.time
		return "%d:%02d" % [int(t / 60), int(fposmod(t, 60))] if phase == "ascend" else "--:--"
	return ""
