extends RefCounted
## Chapter IV finale: Herobrine in three stages, the fistfight, his death, the
## coordinates, the road and the black door. One state machine on world time;
## every warning, hit and pose reads the same geometry. Its own RNG (seeded from
## the run) never touches the combat RNG of the rest of the chapter.
##
## He fights at twice a man's height. When stage II breaks him he spends all of
## it on one last attack that erases the world and the hero's gear, and shrinks
## to a man's size: the fistfight happens on what is left.
var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_four_finale.json"))
var rng := RandomNumberGenerator.new()
var phase := ""            # summit intro tower vortex one kneel two last erase three death coords road door done retry
var age := 0.0
var started := false
var hb: Dictionary = {}
var center := Vector2.ZERO
var arena := Rect2()
var move := ""             # current Herobrine action in a fight stage
var move_age := 0.0
var move_time := 0.0
var queue: Array = []
var shots: Array = []
var marks: Array = []      # lightning marks
var rings: Array = []
var lanes: Array = []
var hole: Dictionary = {}
var path: Array = []       # blitz points
var strips: Array = []     # rift strips
var seam: Dictionary = {}
var drops: Array = []      # heavy rain drops aimed at the hero
var waves: Array = []      # tower: fire waves rolling out from its foot
var tower_h := 0.0
var tower_queue: Array = []
var vortex_from := Vector2.ZERO
var vortex_cut := false
var beams: Array = []      # last attack: angles of the sweeping beams
var beam_turn := 0.0
var void_r := 0.0
var strip_index := 0
var sky := 0.0             # 0 night .. 1 day (stage II day acceleration)
var sun := 0.0             # day acceleration: cumulative cycles (sun and moon positions)
var split := 0.0           # time stopped: sun and moon in one sky
var shadow_on := false
var shadow_angle := 0.0
var knife_center := Vector2.ZERO
var knife_gaps: Array = []
var looked := false
var face := "calm"
var pose := "idle"
var pose_age := 0.0
var day_done: Array = []
var stored: Dictionary = {}
var checkpoint: Dictionary = {}
var qte_index := 0
var qte: Dictionary = {}
var presses: Array = []
var hold := false
var steve_pose := "idle"
var steve_pose_age := 0.0
var steve_at := Vector2.ZERO
var text_events: Array = []
var silence := false
var music := ""
var camera_at := Vector2.ZERO
var retry_from := ""
var flash := 0.0
var glitch := 0.0
var hitstop := 0.0
var impact_frame := 0.0
var impacts: Array = []    # fistfight contacts: {at, on, big}
var road_index := 0
var door_state := ""
var spoken: Dictionary = {}
var head_at := -1.0
var punch_at := -10.0

func reset(w):
	rng.seed = int(w.rng.seed) ^ 0x4e7b19
	phase = ""; age = 0.0; started = false; hb = {}; move = ""; queue.clear(); shots.clear(); marks.clear(); rings.clear()
	lanes.clear(); hole = {}; path.clear(); strips.clear(); seam = {}; drops.clear(); beams.clear(); sky = 0.0; sun = 0.0; split = 0.0
	looked = false; face = "calm"; shadow_on = false; knife_gaps.clear(); void_r = 0.0; strip_index = 0
	pose = "idle"; pose_age = 0.0; day_done.clear(); stored = {}; checkpoint = {}; qte_index = 0; qte = {}; presses.clear()
	hold = false; steve_pose = "idle"; text_events.clear(); silence = false; music = ""; retry_from = ""; flash = 0.0; glitch = 0.0
	hitstop = 0.0; impact_frame = 0.0; impacts.clear(); waves.clear(); tower_h = 0.0; tower_queue.clear(); vortex_cut = false
	road_index = 0; door_state = ""; spoken.clear(); head_at = -1.0; punch_at = -10.0
	var pyramid := Vector2(w.terrain.pyramid[0], w.terrain.pyramid[1])
	center = pyramid + Vector2(data.arena.offset[0], data.arena.offset[1])
	var size := Vector2(data.arena.size[0], data.arena.size[1])
	arena = Rect2(center - size / 2, size)

func active() -> bool:
	return phase != "" and phase != "done"

## Phases in which the world stands still: no spawns, weapons or free movement.
func locked() -> bool:
	return phase in ["intro", "vortex", "kneel", "erase", "three", "death", "coords", "road", "door", "retry"]

func fighting() -> bool:
	return phase in ["one", "two"]

## Phases in which his attacks can hurt the hero.
func dangerous() -> bool:
	return phase in ["tower", "one", "two", "last"]

func scale() -> float:
	return float(hb.get("scale", 1.0)) if not hb.is_empty() else 1.0

# ------------------------------------------------------------------ entry

func begin_summit(w):
	phase = "summit"; age = 0.0
	for m in w.mobs:
		if m.has("form") and m.hp > 0:
			m.expired = true; m.hp = 0
			w.add_effect("ch4_remains", m.p, .6, {"skin": m.skin, "dir": m.visual_dir})
	w.message = "Пирамида"; w.message_timer = 3; w.sound("ch4_guardian_awake")

func start_intro(w):
	phase = "intro"; age = 0.0; started = true
	w.mobs = w.mobs.filter(func(m): return not m.has("form"))
	clear_arena(w)
	hb = {"finale_actor": "herobrine", "id": w.next_id(), "kind": "herobrine4", "p": center + Vector2(0, -120), "hp": float(data.one.hp),
		"max_hp": float(data.one.hp), "radius": float(data.one.radius), "boss": true, "undead": true, "allied": false, "flash": 0.0,
		"burn": 0.0, "burn_tick": .5, "stun": 0.0, "pull_left": 0.0, "control_resist": 99.0, "slow": 0.0, "visual": w.animation.actor(),
		"dir": Vector2.UP, "visual_dir": Vector2.UP, "animation": 0.0, "moving": false, "knock": Vector2.ZERO, "xp": 0, "speed": 0.0,
		"damage": 3.0, "timer": 0.0, "phase": "idle", "deflect": -10.0, "ch4_cracks": 0, "scale": float(data.giant), "aura": 0.6}
	w.player = center + Vector2(0, 120); w.facing = Vector2.UP
	set_pose("cast"); face = "calm"; music = ""
	camera_at = w.player

func clear_arena(w):
	var grow := arena.grow(30)
	w.props = w.props.filter(func(o): return not grow.has_point(o.p))
	for key in w.solid_grid.keys():
		w.solid_grid[key] = w.solid_grid[key].filter(func(s): return not grow.has_point(s.p))
	for cell in w.blocked.keys():
		if grow.has_point(Vector2(cell) * w.CELL):w.blocked.erase(cell)
	for mark in w.landmarks:
		if mark.kind != "pyramid" and grow.has_point(mark.p):mark.dead = true
	w.update_flow()

func set_pose(name: String):
	if pose != name:
		pose = name; pose_age = 0.0

func set_steve(name: String):
	if steve_pose != name:
		steve_pose = name; steve_pose_age = 0.0

func say(text: String, style: String, duration: float, cut: float = -1.0):
	text_events.append({"text": text, "style": style, "at": age, "life": duration, "cut": cut, "phase": phase})

func cast_fx(w, big: bool = false):
	w.add_effect("ch4_hb_cast", hb.p, .9 if big else .6, {"scale": scale(), "big": big})
	hb.aura = 1.6 if big else 1.2

# ------------------------------------------------------------------ world hooks

func candidates() -> Array:
	return [hb] if fighting() and not hb.is_empty() and hb.hp > 0 else []

func hurt(w, m: Dictionary, amount: float, push: Vector2):
	if not fighting() or m.hp <= 0:
		return
	var mult := 1.0
	if move == "day" and move_age < move_time - float(data.two.day.stun):mult = float(data.two.day.float_guard)
	if move in ["stunned", "landed"]:mult = float(data.two.day.stun_bonus) if move == "stunned" else 1.5
	if move == "look":mult = 1.25
	# Stage II cannot be burst past its day acceleration: each one is a floor
	# until it has been played. A strong build shortens the fight, not the show.
	var floor_hp := 0.0
	if phase == "two":
		for i in range(data.two.day.at.size()):
			if not day_done.has(i):
				floor_hp = m.max_hp * (float(data.two.day.at[i]) - 0.06); break
	var dealt := minf(maxf(0.0, m.hp - floor_hp), amount * mult)
	m.hp -= dealt; m.flash = .1; m.visual.hurt = .12
	w.damage_by[w.damage_owner] = w.damage_by.get(w.damage_owner, 0.0) + dealt
	w.add_effect("damage", m.p - Vector2(0, 26 * scale()), .5, {"amount": ceili(dealt)})
	w.emit_pixels("impact", m.p - Vector2(0, 14 * scale()), 3, push)
	if phase == "one":
		m.deflect = w.clock
		if not looked and m.hp < m.max_hp * float(data.one.look_threshold) and move != "blink":
			looked = true; begin_move(w, "look", float(data.one.look_time))
	if m.hp <= 0:
		m.hp = 0
		if phase == "one":begin_kneel(w)
		elif phase == "two":begin_last(w)

func hooked(_w, _m: Dictionary):
	pass

func camera(w) -> Vector2:
	match phase:
		"intro":
			var focus: Vector2 = hb.p + Vector2(0, 10)
			return w.player.lerp(focus, smoothstep(0.4, 2.2, age) * (1.0 - smoothstep(7.2, 8.2, age) * 0.6))
		"tower":
			var feet: Vector2 = tower_base() - Vector2(0, tower_h)
			var want: Vector2 = w.player.lerp(feet, 0.35)
			want.y = clampf(want.y, feet.y + 40, feet.y + 75)
			camera_at = camera_at.lerp(want, .08)
			return camera_at
		"vortex":
			camera_at = camera_at.lerp(vortex_at().lerp(tower_base() - Vector2(0, tower_h + 30), 0.3), .06)
			return camera_at
		"one", "two":
			var mid: Vector2 = (w.player + hb.p - Vector2(0, 30 * scale())) / 2 + Vector2(0, -10)
			mid.x = clampf(mid.x, w.player.x - 230, w.player.x + 230); mid.y = clampf(mid.y, w.player.y - 120, w.player.y + 100)
			camera_at = camera_at.lerp(mid, .08)
			return camera_at
		"last":
			camera_at = camera_at.lerp(center.lerp(w.player, 0.35) + Vector2(0, -14), .06)
			return camera_at
		"kneel":
			return hb.p.lerp(w.player, 0.25) + Vector2(0, -20)
		"erase":
			return (w.player + hb.p) / 2 + Vector2(0, -22 * scale())
		"three", "death", "retry":
			return center + Vector2(0, -6)
		"coords":
			return w.player + Vector2(0, -10)
		"road", "door":
			return camera_at
	return w.player

# ------------------------------------------------------------------ step

func step(w, dt: float, movement: Vector2):
	age += dt
	var anim := 1.0
	if hitstop > 0:hitstop = maxf(0.0, hitstop - dt); anim = 0.0
	elif phase == "three" and not qte.is_empty() and qte.result == "" and qte.age >= qte.windup:anim = 0.45
	pose_age += dt * anim; steve_pose_age += dt * anim
	flash = maxf(0.0, flash - dt); glitch = maxf(0.0, glitch - dt); impact_frame = maxf(0.0, impact_frame - dt)
	for i in range(text_events.size() - 1, -1, -1):
		if age - text_events[i].at > text_events[i].life:text_events.remove_at(i)
	for i in range(impacts.size() - 1, -1, -1):
		if age - impacts[i].at > 0.8:impacts.remove_at(i)
	if not hb.is_empty():
		hb.animation += dt; hb.flash = maxf(0, hb.flash - dt)
		hb.aura = move_toward(float(hb.get("aura", 1.0)), 1.0, dt * 0.8)
		if hb.visual.has("hurt"):hb.visual.hurt = maxf(0, hb.visual.hurt - dt)
	match phase:
		"summit":
			if w.player.distance_to(center) < float(data.summit_trigger):start_intro(w)
		"intro":step_intro(w)
		"tower":step_tower(w, dt)
		"vortex":step_vortex(w, dt)
		"one", "two":step_fight(w, dt)
		"kneel":step_kneel(w)
		"last":step_last(w, dt)
		"erase":step_erase(w)
		"three":
			if anim > 0.0:step_three(w, dt)
		"retry":
			if age > 2.2:restore_checkpoint(w)
		"death":step_death(w, dt)
		"coords":step_coords(w)
		"road":step_road(w, dt)
		"door":step_door(w, dt)
	update_shots(w, dt)
	if phase in ["one", "two"] and tower_h > 0:
		tower_h = maxf(0.0, tower_h - dt * 70.0)
		if tower_h == 0.0:tower_solid(w, false)
	if w.hp <= 0 and phase in ["tower", "one", "two", "last", "three"]:
		begin_retry(w)

func step_intro(w):
	var turn: Array = data.intro.turn
	if age < turn[0]:
		set_pose("cast"); hb.visual_dir = Vector2.UP
		if age >= 1.9 and not spoken.has("ignite"):
			spoken["ignite"] = true
			w.add_effect("ch4_hb_ignite", hb.p + Vector2(0, -36), 2.2)
			w.sound("ch4_rage", .1); flash = .06
	elif age < turn[1]:
		set_pose("aura")
		var k: float = (age - float(turn[0])) / (float(turn[1]) - float(turn[0]))
		hb.visual_dir = Vector2.UP if k < 0.35 else (Vector2.RIGHT if k < 0.7 else Vector2.DOWN)
		if pose_age < .02 or abs(k - 0.35) < .01 or abs(k - 0.7) < .01:w.sound("ch4_hb_twitch", .3)
	else:
		hb.visual_dir = Vector2.DOWN
	if age >= float(data.intro.line_at) and not spoken.has("intro"):
		spoken["intro"] = true; say("Ты опять здесь.", "calm", 2.6)
	if age >= float(data.intro.rise_at):
		set_pose("invite"); face = "smile"
		if not spoken.has("rise"):
			spoken["rise"] = true; cast_fx(w, true); w.shake = .35; w.sound("ch4_hb_roar", .1); flash = .1
	if age >= float(data.intro.duration):
		begin_tower(w)

# ------------------------------------------------------------------ the tower (a callback to chapter I)

func tower_base() -> Vector2:
	return center + Vector2(data.tower.at[0], data.tower.at[1])

func vortex_at() -> Vector2:
	return center + Vector2(data.vortex.at[0], data.vortex.at[1])

func tower_solid(w, on: bool):
	var base := tower_base()
	var cell := Vector2i(base / 64.0)
	if on:
		if not w.solid_grid.has(cell):w.solid_grid[cell] = []
		w.solid_grid[cell].append({"p": base, "r": 20.0, "rift": true, "tower": true})
	elif w.solid_grid.has(cell):
		w.solid_grid[cell] = w.solid_grid[cell].filter(func(o): return not o.get("tower", false))

## He raises a tower out of the ground and rains chapter I down from it:
## lightning that walks to the hero and fire waves rolling out from its foot.
func begin_tower(w):
	phase = "tower"; age = 0.0; face = "smile"; set_pose("cast"); music = "boss_one"; text_events.clear()
	tower_queue = data.tower.queue.duplicate(); move = ""; move_age = 0.0; move_time = 0.0
	hb.perched = false
	w.sound("ch4_stone_rise", .1); w.sound("ch4_hb_roar", .1)
	save_checkpoint(w, "tower")

func step_tower(w, dt: float):
	var t: Dictionary = data.tower
	var rise: float = float(t.rise)
	if age < rise:
		tower_h = float(t.height) * smoothstep(0.0, rise, age); w.shake = maxf(w.shake, .12)
		if age > rise * 0.75 and not hb.perched:
			w.add_effect("ch4_hb_blink", hb.p, .45, {"dir": hb.visual_dir, "scale": scale()})
			hb.p = tower_base(); hb.perched = true; hb.visual_dir = Vector2.DOWN
			w.sound("ch4_hb_teleport", .1); tower_solid(w, true)
		return
	tower_h = float(t.height)
	# The fight below the tower stays in sight of it.
	w.player.y = minf(w.player.y, tower_base().y + float(t.reach) + 140.0)
	hb.visual_dir = Vector2.DOWN if absf(hb.p.direction_to(w.player).x) < 0.7 else hb.p.direction_to(w.player)
	move_age += dt
	if move in ["storm", "inferno"]:step_storm(w)
	if move in ["waves", "inferno"]:step_waves(w, dt)
	if move == "rest":set_pose("aura")
	elif move_age > 0.5 and pose in ["point", "snap"]:set_pose("aura")
	if move_age >= move_time:
		if move != "rest" and move != "":
			begin_move(w, "rest", float(t.rest))
		elif tower_queue.is_empty():
			begin_vortex(w)
		else:
			start_tower(w, tower_queue.pop_front())

func start_tower(w, name: String):
	var t: Dictionary = data.tower
	var duration := 0.0
	cast_fx(w, name == "inferno"); set_pose("point" if name == "storm" else ("snap" if name == "waves" else "cast"))
	if name == "waves":w.sound("ch4_hb_tick", .05)
	if name == "storm":
		var s: Dictionary = t.storm
		marks.clear()
		var from := tower_base()
		var dir: Vector2 = from.direction_to(w.player)
		var n := int(s.chain)
		for i in range(n):
			var at: Vector2 = w.player + dir * (i - n * 0.6) * 26.0 + dir.orthogonal() * rng.randf_range(-10, 10)
			marks.append({"p": at.clamp(arena.position, arena.end), "age": 0.0, "hit": false, "delay": i * float(s.every), "r": float(s.radius), "windup": float(s.windup)})
		for i in range(int(s.big)):
			var at: Vector2 = w.player + w.tracked_velocity * 0.5 + Vector2.from_angle(i * TAU / int(s.big) + rng.randf() * TAU) * 40.0
			marks.append({"p": at.clamp(arena.position, arena.end), "age": 0.0, "hit": false, "delay": float(s.big_delay), "r": float(s.big_radius), "windup": float(s.windup)})
		duration = float(s.big_delay) + float(s.windup) + 0.4
		w.sound("ch4_hb_charge", .2)
	if name in ["waves", "inferno"]:
		var wv: Dictionary = t.waves
		var base := tower_base()
		var aim: float = Vector2(w.player.x - base.x, (w.player.y - base.y) * 2.0).angle()
		for j in range(int(wv.count)):
			var shift: float = 0.0 if j == 0 else float(wv.shift) * (1.0 if j % 2 == 1 else -1.0)
			waves.append({"p": base, "r": 0.0, "age": -j * float(wv.every), "gap": aim + shift})
		duration = maxf(duration, float(wv.time))
		if name == "inferno":
			# Lightning only where the gaps do not lead: standing still is punished, the way through is not.
			marks.clear()
			var dist: float = base.distance_to(w.player)
			for i in range(int(t.inferno_marks)):
				var side: float = 1.0 if i % 2 == 0 else -1.0
				var a: float = aim + side * (0.55 + rng.randf() * 1.6)
				var at: Vector2 = base + Vector2(cos(a), sin(a) * 0.5) * (dist + rng.randf_range(-40, 40))
				marks.append({"p": at.clamp(arena.position, arena.end), "age": 0.0, "hit": false, "delay": 0.4 + i * 0.5, "r": float(t.storm.big_radius), "windup": 0.9})
			duration = maxf(duration, 0.4 + int(t.inferno_marks) * 0.5 + 1.3)
		w.sound("ch4_hb_fire", .2)
	begin_move(w, name, duration)

func step_storm(w):
	for m in marks:
		m.age = move_age - float(m.get("delay", 0.0))
		if not m.hit and m.age >= float(m.windup):
			m.hit = true
			w.add_effect("ch4_hb_bolt", m.p, .55, {"radius": float(m.r)})
			w.add_effect("ch4_hb_scorch", m.p, 2.4, {"radius": float(m.r)})
			if w.player.distance_to(m.p) < float(m.r):w.receive_hit(float(data.tower.storm.damage), hb)
			flash = maxf(flash, .08); w.shake = maxf(w.shake, .14); w.sound("ch4_hb_lightning", .08)

func step_waves(w, dt: float):
	var wv: Dictionary = data.tower.waves
	for i in range(waves.size() - 1, -1, -1):
		var f: Dictionary = waves[i]
		f.age += dt
		if f.age < 0:continue
		f.r = f.age * float(wv.speed)
		var off: Vector2 = w.player - f.p
		var flat := Vector2(off.x, off.y * 2.0)
		var in_gap: bool = absf(angle_difference(flat.angle(), f.gap)) < float(wv.gap) * 0.5
		if absf(flat.length() - f.r) < float(wv.band) and not in_gap:w.receive_hit(float(wv.damage), hb)
		if f.r > 760:waves.remove_at(i)

## The vortex from chapter I's secret ending. This time it does not close:
## the hero cuts it open from the inside.
func begin_vortex(w):
	phase = "vortex"; age = 0.0; marks.clear(); waves.clear(); move = ""; music = ""
	vortex_from = w.player; vortex_cut = false; set_pose("point"); face = "smile"
	w.sound("herobrine_warp")

func step_vortex(w, dt: float):
	var v: Dictionary = data.vortex
	if age >= float(v.warp) and w.player != vortex_at():
		w.player = vortex_at(); w.facing = Vector2.UP
	if age >= float(v.grow[0]) and not spoken.has("vortex"):spoken["vortex"] = true; w.sound("blood_rift")
	if age < float(v.cut):set_steve("guard")
	if age >= float(v.cut) and not vortex_cut:
		vortex_cut = true; hitstop = .22; flash = .45; w.shake = .55; impact_frame = .1
		w.sound("ch4_impact"); w.sound("ch4_hb_shatter", .05); set_steve("throw")
	if age >= float(v.react) and age < float(v.down):set_pose("look_hand"); face = "calm"
	if age >= float(v.down) and hb.get("perched", false):
		w.add_effect("ch4_hb_blink", hb.p - Vector2(0, tower_h), .45, {"dir": hb.visual_dir, "scale": scale()})
		hb.perched = false; hb.p = center + Vector2(0, -90); set_pose("aura")
		w.add_effect("ch4_hb_blink", hb.p, .45, {"dir": hb.visual_dir, "scale": scale()})
		w.sound("ch4_hb_teleport", .1); w.shake = .3
	if age >= float(v.duration):
		phase = "one"; age = 0.0; face = "smile"; set_pose("aura"); music = "boss_one"; text_events.clear()
		begin_move(w, "rest", 1.0); save_checkpoint(w, "one")

func step_kneel(w):
	var k: Dictionary = data.kneel
	if age < float(k.rise_at):set_pose("kneel"); silence = true
	elif age < float(k.rise_at) + 1.3:set_pose("rise"); face = "smile"
	else:set_pose("invite")
	if age >= float(k.rise_at) + 1.0 and not spoken.has("kneel_burst"):
		spoken["kneel_burst"] = true; cast_fx(w, true); w.shake = .45; flash = .14; w.sound("ch4_hb_roar", .1)
	if age >= float(k.line_at) and not spoken.has("kneel"):
		spoken["kneel"] = true; say("Хорошо. Давай всерьёз.", "calm", 2.4)
	if age >= float(k.duration):
		phase = "two"; age = 0.0; silence = false; music = "boss_two"; text_events.clear()
		hb.hp = float(data.two.hp); hb.max_hp = hb.hp; face = "smile"
		begin_move(w, "invite", 1.4); save_checkpoint(w, "two")

func begin_kneel(w):
	phase = "kneel"; age = 0.0; clear_hazards(); face = "calm"; music = ""; text_events.clear()
	w.sound("ch4_hb_freeze")

# ------------------------------------------------------------------ the last attack

## Stage II breaks him. He does not fall: he spends everything he has left.
func begin_last(w):
	phase = "last"; age = 0.0; clear_hazards(); face = "rage"; music = "boss_two"; text_events.clear()
	set_pose("cast"); flash = .3; w.shake = .6; glitch = .4
	w.sound("ch4_hb_roar"); w.sound("ch4_impact", .1)
	say("ХВАТИТ.", "roar", 2.4)
	save_checkpoint(w, "last")
	stored = {"build": w.build.duplicate(), "items": w.items.duplicate(), "evolved": w.evolved.duplicate()}
	strip_index = 0; beam_turn = rng.randf() * TAU; void_r = float(data.last.void_from); hb.pulse_n = 0
	camera_at = (w.player + hb.p) / 2
	cast_fx(w, true)

func step_last(w, dt: float):
	var l: Dictionary = data.last
	var rise: float = float(l.rise)
	var d: float = float(l.duration)
	hb.p = hb.p.lerp(center + Vector2(0, -6), minf(1.0, dt * 2.0))
	hb.visual_dir = Vector2.DOWN
	set_pose("cast" if age < rise or age > d - 1.2 else "float")
	hb.aura = 1.8
	void_r = lerpf(float(l.void_from), float(l.void_to), smoothstep(rise, d - 1.0, age))
	# Outside the shrinking circle the world is already gone.
	var off: Vector2 = w.player - center
	if Vector2(off.x, off.y / 0.62).length() > void_r:
		w.player = w.player.move_toward(center, 90 * dt)
		w.receive_hit(float(l.damage), hb)
	if age >= rise:
		var k := smoothstep(rise, d, age)
		var speeds: Array = l.beam_speed
		beam_turn += lerpf(float(speeds[0]), float(speeds[1]), k) * dt
		beams.clear()
		var cycle: float = float(l.beam_on) + float(l.beam_off)
		var hot: bool = age >= rise + float(l.beam_warn) and fposmod(age - rise - float(l.beam_warn), cycle) < float(l.beam_on)
		for i in range(int(l.beams)):
			beams.append({"a": beam_turn + i * TAU / int(l.beams), "hot": hot})
			if hot:
				var dir := Vector2.from_angle(beam_turn + i * TAU / int(l.beams))
				var rel: Vector2 = w.player - hb.p
				if rel.dot(dir) > 0 and absf(rel.dot(dir.orthogonal())) < float(l.beam_width) * 0.5:w.receive_hit(float(l.damage), hb)
		var n := int((age - rise) / float(l.pulse_every))
		if n >= int(hb.pulse_n):
			hb.pulse_n = n + 1
			radial(w, int(l.pulse_count), float(l.pulse_speed), n * 0.41, float(l.damage), "void", 3)
			w.sound("ch4_hb_pulse", .05)
		if not spoken.has("beam"):spoken["beam"] = true; w.sound("ch4_hb_beam", .1)
	# The gear is torn off piece by piece and pulled into him.
	if age >= float(l.strip_from) + strip_index * float(l.strip_every):
		var id := ""
		for key in w.build.keys():id = key; w.build.erase(key); break
		if id == "":
			for key in w.items.keys():id = key; w.items.erase(key); break
		if id != "":
			w.add_effect("ch4_hb_strip", w.player - Vector2(0, 14), .7, {"to": hb.p - Vector2(0, 30 * scale()), "id": id})
			w.sound("ch4_hb_strip", .05)
		strip_index += 1
	if age >= d:
		w.build = {}; w.items = {}; w.evolved = {}
		flash = 1.0; w.shake = .7; w.sound("ch4_impact"); w.sound("ch4_hb_shatter", .1)
		begin_erase(w)

## The world is gone. So is his power: he shrinks to a man's size.
func begin_erase(w):
	phase = "erase"; age = 0.0; clear_hazards(); face = "rage"; music = ""; sky = 0.0; split = 0.0; text_events.clear()
	set_pose("exhausted"); glitch = .6; set_steve("idle")
	if stored.is_empty():
		stored = {"build": w.build.duplicate(), "items": w.items.duplicate(), "evolved": w.evolved.duplicate()}
	w.build = {}; w.items = {}; w.evolved = {}
	hb.p = center + Vector2(24, -2); w.player = center + Vector2(-24, 4); w.facing = Vector2.RIGHT; hb.visual_dir = Vector2.LEFT
	hb.scale = float(data.giant)

func step_erase(w):
	var d: float = float(data.erase.duration)
	var sh: Array = data.erase.shrink
	var k := clampf((age - float(sh[0])) / (float(sh[1]) - float(sh[0])), 0, 1)
	var stepped := floorf(k * 5.0) / 5.0
	var before: float = hb.scale
	hb.scale = lerpf(float(data.giant), 1.0, stepped)
	if hb.scale != before:
		glitch = maxf(glitch, .18); w.sound("ch4_hb_glitch", .05)
		w.add_effect("ch4_hb_drain", hb.p, .9, {"scale": before})
	if age >= float(sh[0]) and not spoken.has("shrink"):spoken["shrink"] = true; w.sound("ch4_hb_shrink")
	hb.aura = lerpf(1.4, 0.0, k)
	if age < float(sh[0]):set_pose("exhausted"); face = "rage"
	elif age < float(sh[1]):set_pose("stagger" if int(age * 6) % 2 == 0 else "exhausted"); face = "dim"
	elif age < float(sh[1]) + 1.2:set_pose("look_hand"); face = "dim"
	elif age < d - 0.6:set_pose("exhausted"); face = "smile"
	else:set_pose("guard"); set_steve("guard")
	if age > float(sh[1]) + 1.0 and not spoken.has("breath"):spoken["breath"] = true; w.sound("ch4_breath")
	if age >= d:
		phase = "three"; age = 0.0; qte_index = 0; qte = {}
		hb.scale = 1.0; hb.radius = 8.0
		w.hp = maxf(w.hp, float(data.three.steve_hp))
		hb.p = center + Vector2(13, 0); w.player = center + Vector2(-13, 0); w.facing = Vector2.RIGHT
		save_checkpoint(w, "three"); next_qte(w)

# ------------------------------------------------------------------ stages I / II

func begin_move(_w, name: String, duration: float):
	move = name; move_age = 0.0; move_time = duration

func step_fight(w, dt: float):
	move_age += dt
	var two := phase == "two"
	var angry: bool = two and hb.hp < hb.max_hp * float(data.two.angry_below)
	var speed: float = float(data.two.angry_speed) if angry else 1.0
	if two:face = "smile" if hb.hp > hb.max_hp * .7 else ("rage" if angry else "calm")
	hb.visual_dir = hb.p.direction_to(w.player) if move not in ["blitz_dash"] else hb.visual_dir
	# Stage I: a close hero gets a short contemptuous blink away.
	if phase == "one" and move == "rest" and w.player.distance_to(hb.p) < float(data.one.blink_range) and w.clock - hb.get("blinked", -10.0) > float(data.one.blink_cooldown):
		blink(w, hb.p + w.player.direction_to(hb.p).rotated(rng.randf_range(-1, 1)) * float(data.one.blink_distance))
	match move:
		"rest":
			# He walks at the hero between attacks: unhurried, never running.
			var walk: float = float(data.two.walk if two else data.one.walk)
			if w.player.distance_to(hb.p) > float(data.one.keep) and w.clock - hb.deflect > .35:
				hb.p += hb.p.direction_to(w.player) * walk * dt; set_pose("stroll")
			else:
				set_pose("deflect" if w.clock - hb.deflect < .35 and phase == "one" else "aura")
			if move_age >= move_time:next_attack(w)
		"look":
			set_pose("look_hand")
			if move_age >= move_time:begin_move(w, "rest", .6); face = "smile"
		"invite":
			set_pose("invite")
			if move_age >= move_time:begin_move(w, "rest", .4)
		"lightning":
			step_lightning(w)
			if move_age > 0.6:set_pose("aura")
		"ring":
			step_ring(w, dt)
			if move_age > 0.5:set_pose("aura")
		"strike":step_strike(w)
		"hole":step_hole(w, dt)
		"blitz_mark", "blitz_dash", "landed":step_blitz(w, dt)
		"rain":step_rain(w, dt)
		"rift":step_rift(w)
		"tear":step_tear(w)
		"day":step_day(w)
		"stunned":
			set_pose("kneel" if move_age < move_time - .8 else "rise")
			if move_age >= move_time:begin_move(w, "rest", .8)
	if move_age > 0 and speed > 1.0 and move in ["rest"]:move_age += dt * (speed - 1.0)
	hb.p = hb.p.clamp(arena.position + Vector2(24, 34), arena.end - Vector2(24, 20))

func next_attack(w):
	if queue.is_empty():
		if phase == "one":
			queue = ["lightning", "ring", "strike", "lightning", "strike", "ring"]
		else:
			queue = ["hole", "blitz", "rain", "rift", "tear", "blitz", "hole", "rain"]
	if phase == "two":
		for i in range(data.two.day.at.size()):
			if not day_done.has(i) and hb.hp < hb.max_hp * float(data.two.day.at[i]):
				day_done.append(i); start(w, "day"); return
	start(w, queue.pop_front())

func rest(w, extra: float = 0.0):
	var r = data.one.rest if phase == "one" else [data.two.rest, data.two.rest]
	begin_move(w, "rest", rng.randf_range(float(r[0]), float(r[1])) + extra)

func start(w, name: String):
	match name:
		"lightning":
			var l: Dictionary = data.one.lightning
			marks.clear()
			var count := int(l.get("count", 3))
			for i in range(count):
				var off := Vector2.from_angle(i * TAU / count + rng.randf() * TAU) * float(l.spread) * (0.3 if i == 0 else 1.0)
				marks.append({"p": w.player + w.tracked_velocity * 0.35 + off, "age": 0.0, "hit": false})
			begin_move(w, "lightning", float(l.windup) + .5); set_pose("point"); w.sound("ch4_hb_charge", .2); cast_fx(w)
		"ring":
			var r: Dictionary = data.one.ring
			var facing: Vector2 = w.facing if w.facing.length_squared() > 0 else Vector2.DOWN
			rings = [{"p": w.player, "gap": Vector2(facing.x, facing.y * 2.0).angle() + rng.randf_range(-float(r.gap_near), float(r.gap_near)), "age": 0.0}]
			begin_move(w, "ring", float(r.windup) + float(r.time)); set_pose("snap"); w.sound("ch4_hb_fire", .2); w.sound("ch4_hb_tick", .05); cast_fx(w)
		"strike":
			blink(w, w.player - w.facing.normalized() * 70 if w.facing.length_squared() > 0 else w.player + Vector2(0, 70))
			var s: Dictionary = data.one.strike
			lanes = [{"a": hb.p, "b": hb.p + hb.p.direction_to(w.player) * float(s.length), "age": 0.0, "hit": false}]
			begin_move(w, "strike", float(s.windup) + .35); set_pose("slam")
		"hole":
			var at: Vector2 = (w.player + Vector2.from_angle(rng.randf() * TAU) * 100.0).clamp(arena.position + Vector2(60, 60), arena.end - Vector2(60, 60))
			hole = {"p": at, "age": 0.0, "burst": false}
			begin_move(w, "hole", float(data.two.hole.grow) + 1.4); set_pose("cast"); w.sound("ch4_hb_blackhole", .2); w.sound("ch4_hb_suck", .2); cast_fx(w, true)
		"blitz":
			path.clear()
			var b: Dictionary = data.two.blitz
			var last: Vector2 = hb.p
			for i in range(int(b.points)):
				var target: Vector2 = w.player + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(40.0, 120.0)
				target = target.clamp(arena.position + Vector2(24, 34), arena.end - Vector2(24, 20))
				path.append({"a": last, "b": target, "t": 0.0})
				last = target
			begin_move(w, "blitz_mark", float(b.mark) * path.size() + float(b.delay)); set_pose("guard")
		"rain":
			var r: Dictionary = data.two.rain
			drops.clear(); hb.rain_tick = -1; hb.heavy_n = 0; hb.rain_from = rng.randi_range(4, int(r.lanes) - 5)
			blink(w, Vector2(center.x, arena.position.y + 46))
			begin_move(w, "rain", float(r.wave) * int(r.waves)); set_pose("cast"); w.sound("ch4_hb_rain", .2); cast_fx(w, true)
		"rift":
			strips.clear()
			var rr: Dictionary = data.two.rift
			for i in range(int(rr.strips)):
				var y: float = arena.position.y + arena.size.y * (0.33 + 0.34 * i) + rng.randf_range(-20, 20)
				var gaps: Array = [rng.randf_range(arena.position.x + 40, arena.end.x - 140)]
				gaps.append(gaps[0] + rng.randf_range(120, 200))
				strips.append({"y": y, "gaps": gaps, "raised": false})
			begin_move(w, "rift", float(rr.windup) + float(rr.hold)); set_pose("cast"); w.sound("ch4_hb_rift", .2); cast_fx(w)
		"tear":
			var t: Dictionary = data.two.tear
			var x: float = clampf(w.player.x + rng.randf_range(-60, 60), arena.position.x + 60, arena.end.x - 60)
			var bridges: Array = []
			for i in range(int(t.bridges)):bridges.append(arena.position.y + arena.size.y * (0.25 + 0.5 * i) + rng.randf_range(-24, 24))
			seam = {"x": x, "bridges": bridges, "pulses": []}
			begin_move(w, "tear", float(t.windup) + float(t.time)); set_pose("cast"); w.sound("ch4_hb_rift", .2); cast_fx(w)
		"day":
			hb.p = center + Vector2(0, -30)
			var d: Dictionary = data.two.day
			var total := 0.0
			for c in d.cycles:total += float(c)
			begin_move(w, "day", 1.0 + total + float(d.freeze) + float(d.release) + float(d.stun)); set_pose("float"); w.sound("ch4_hb_day", .2)
			hb.ring_fired = []; hb.tick = -1; knife_gaps.clear(); sun = 0.0
			cast_fx(w, true); w.add_effect("ch4_hb_blink", hb.p, .45, {"dir": hb.visual_dir, "scale": scale()})

func blink(w, to: Vector2):
	w.add_effect("ch4_hb_blink", hb.p, .45, {"dir": hb.visual_dir, "scale": scale()})
	hb.p = to.clamp(arena.position + Vector2(24, 34), arena.end - Vector2(24, 20))
	hb.blinked = w.clock
	w.add_effect("ch4_hb_blink", hb.p, .45, {"dir": hb.visual_dir, "scale": scale()})
	w.sound("ch4_hb_teleport", .2)

func step_lightning(w):
	var l: Dictionary = data.one.lightning
	for m in marks:
		m.age = move_age
		if not m.hit and move_age >= float(l.windup):
			m.hit = true
			w.add_effect("ch4_hb_bolt", m.p, .55, {"radius": float(l.radius)})
			w.add_effect("ch4_hb_scorch", m.p, 2.4, {"radius": float(l.radius)})
			if w.player.distance_to(m.p) < float(l.radius):w.receive_hit(float(l.damage), hb)
			flash = .12; w.shake = .18; w.sound("ch4_hb_lightning", .1)
	if move_age >= move_time:marks.clear(); rest(w)

func step_ring(w, dt: float):
	var r: Dictionary = data.one.ring
	for ring in rings:
		ring.age = move_age
		if move_age < float(r.windup):continue
		var k := clampf((move_age - float(r.windup)) / float(r.time), 0, 1)
		ring.r = lerpf(float(r.start), float(r.end), k)
		var off: Vector2 = w.player - ring.p
		var flat := Vector2(off.x, off.y * 2.0)
		var in_gap := absf(angle_difference(flat.angle(), ring.gap)) < float(r.gap) * 0.5
		if absf(flat.length() - ring.r) < float(r.band) and not in_gap:w.receive_hit(float(r.damage), hb)
	if move_age >= move_time:rings.clear(); rest(w)

func step_strike(w):
	var s: Dictionary = data.one.strike
	for lane in lanes:
		lane.age = move_age
		if not lane.hit and move_age >= float(s.windup):
			lane.hit = true
			hb.p = lane.b
			w.add_effect("ch4_hb_slash", lane.a, .45, {"end": lane.b, "width": float(s.width), "dir": hb.visual_dir, "scale": scale()})
			if Geometry2D.get_closest_point_to_segment(w.player, lane.a, lane.b).distance_to(w.player) < float(s.width):w.receive_hit(float(s.damage), hb)
			w.sound("ch4_heavy", .1); w.shake = .2
	if move_age >= move_time:lanes.clear(); rest(w)

func step_hole(w, dt: float):
	var h: Dictionary = data.two.hole
	hole.age = move_age
	var grow: float = float(h.grow)
	set_pose("cast" if move_age < grow else "slam")
	if move_age < grow:
		var pull: float = float(h.pull) * smoothstep(0.0, grow, move_age)
		w.player = w.move_actor(w.player, w.player.direction_to(hole.p) * pull * dt, 6)
		for b in shots:b.v = b.v.lerp(b.p.direction_to(hole.p) * b.v.length(), dt * 0.8)
		if w.player.distance_to(hole.p) < float(h.radius) * 0.7:w.receive_hit(2.0, hb)
	elif not hole.burst:
		hole.burst = true
		if w.player.distance_to(hole.p) < float(h.radius):w.receive_hit(float(h.damage), hb)
		var count := int(h.debris)
		var gap_every := count / int(h.gaps)
		var turn := rng.randf() * TAU
		for i in range(count):
			if i % gap_every < 2:continue
			var dir := Vector2.from_angle(turn + i * TAU / count)
			shots.append({"p": hole.p, "v": dir * float(h.speed) * (0.85 + 0.3 * float(i % 3) / 2.0), "r": 4.5, "damage": 3.0, "kind": "debris", "life": 3.0, "spin": float(i)})
		flash = .35; w.shake = .5; w.sound("ch4_hb_collapse", .1); w.sound("ch4_impact", .1)
	if move_age >= move_time:hole = {}; rest(w)

func step_blitz(w, dt: float):
	var b: Dictionary = data.two.blitz
	var mark_time: float = float(b.mark)
	if move == "blitz_mark":
		var shown := int(move_age / mark_time)
		for i in range(path.size()):
			if i < shown and not path[i].get("marked", false):
				path[i].marked = true; hb.p = path[i].b; w.sound("ch4_hb_teleport", .1)
				w.add_effect("ch4_hb_blink", hb.p, .3, {"dir": hb.visual_dir, "scale": scale()})
		if move_age >= move_time:
			hb.p = path[0].a; begin_move(w, "blitz_dash", 9.0); set_pose("lunge"); hb.leg = 0; hb.leg_t = 0.0
			w.sound("ch4_hb_blitz", .1)
	elif move == "blitz_dash":
		var leg: Dictionary = path[hb.leg]
		var length: float = maxf(1.0, leg.a.distance_to(leg.b))
		hb.leg_t += float(b.speed) * dt / length
		var before: Vector2 = hb.p
		hb.p = leg.a.lerp(leg.b, minf(1.0, hb.leg_t))
		hb.visual_dir = leg.a.direction_to(leg.b)
		leg.t = hb.leg_t
		if Geometry2D.get_closest_point_to_segment(w.player, before, hb.p).distance_to(w.player) < float(b.width):w.receive_hit(float(b.damage), hb)
		if hb.leg_t >= 1.0:
			w.add_effect("ch4_hb_slash", leg.a, .4, {"end": leg.b, "width": float(b.width), "dir": hb.visual_dir, "scale": scale()})
			hb.leg += 1; hb.leg_t = 0.0
			if hb.leg >= path.size():
				begin_move(w, "landed", float(b.stagger)); set_pose("slam"); w.shake = .35; w.sound("ch4_ground_slam", .1)
				w.add_effect("ch4_hb_cast", hb.p, .6, {"scale": scale(), "big": false})
				path.clear()
	elif move == "landed":
		set_pose("kneel" if move_age < move_time * 0.7 else "rise")
		if move_age >= move_time:rest(w)

## White rain from a sky he tore open: straight, then slanted, then aimed.
func step_rain(w, dt: float):
	var r: Dictionary = data.two.rain
	var lanes_n := int(r.lanes)
	var wave := mini(int(move_age / float(r.wave)), int(r.waves) - 1)
	var every: float = float(r.every)
	var tick := int(move_age / every)
	set_pose("cast")
	var vx := 0.0
	if wave == 1:vx = float(r.slant) * (1.0 if int(move_age / (float(r.wave) * 0.5)) % 2 == 0 else -1.0)
	hb.rain_vx = vx; hb.rain_wave = wave
	if tick != int(hb.get("rain_tick", -1)):
		hb.rain_tick = tick
		# The safe lanes drift slower than the hero can walk.
		var safe := int(round(pingpong(move_age * float(r.drift) + float(hb.get("rain_from", 0)), lanes_n - 1)))
		var top: float = arena.position.y - 10
		for i in range(lanes_n):
			if absi(i - safe) <= int(r.safe) - 1:continue
			if (i + tick) % 2 == 1:continue
			var x: float = arena.position.x + (i + 0.5) * arena.size.x / lanes_n
			x -= vx * (arena.size.y * 0.5) / float(r.speed)
			shots.append({"p": Vector2(x, top), "v": Vector2(vx, float(r.speed)), "r": 3.5, "damage": float(r.damage), "kind": "rain", "life": 2.6})
		hb.rain_safe = safe
	if wave == 2:
		var n := int((move_age - 2.0 * float(r.wave)) / float(r.heavy_every))
		if n >= int(hb.get("heavy_n", 0)):
			hb.heavy_n = n + 1
			drops.append({"p": (w.player + w.tracked_velocity * 0.45).clamp(arena.position, arena.end), "age": 0.0, "hit": false})
	for d in drops:
		d.age += dt
		if not d.hit and d.age >= float(r.heavy_windup):
			d.hit = true
			w.add_effect("ch4_hb_splash", d.p, .6, {"radius": float(r.heavy_radius)})
			if w.player.distance_to(d.p) < float(r.heavy_radius):w.receive_hit(float(r.heavy_damage), hb)
			w.shake = maxf(w.shake, .08)
	drops = drops.filter(func(d): return d.age < float(r.heavy_windup) + 0.3)
	if move_age >= move_time:drops.clear(); rest(w)

func step_rift(w):
	var rr: Dictionary = data.two.rift
	var windup: float = float(rr.windup)
	for s in strips:
		if move_age >= windup and not s.raised:
			s.raised = true
			raise_strip(w, s, true); w.shake = .25; w.sound("ch4_stone_rise", .1)
	if move_age >= move_time:
		for s in strips:raise_strip(w, s, false)
		strips.clear(); rest(w)

func raise_strip(w, s: Dictionary, up: bool):
	var height: float = float(data.two.rift.height)
	var gap: float = float(data.two.rift.gap)
	var x := arena.position.x
	while x < arena.end.x:
		var open := false
		for g in s.gaps:
			if x > g and x < g + gap:open = true
		if not open:
			for dy in [-height / 3, 0.0, height / 3]:
				var p := Vector2(x, s.y + dy)
				var cell := Vector2i(p / 64.0)
				if up:
					if not w.solid_grid.has(cell):w.solid_grid[cell] = []
					w.solid_grid[cell].append({"p": p, "r": 7.0, "rift": true})
				elif w.solid_grid.has(cell):
					w.solid_grid[cell] = w.solid_grid[cell].filter(func(o): return not o.get("rift", false))
		x += 12.0
	# The hero is never sealed inside a raised strip.
	if up and absf(w.player.y - s.y) < height * 0.7:
		w.player.y = s.y + (height * 0.8 if w.player.y >= s.y else -height * 0.8)

func step_tear(w):
	var t: Dictionary = data.two.tear
	if move_age >= float(t.windup):
		var run := move_age - float(t.windup)
		seam.pulses = []
		for i in range(int(t.pulses)):
			var y := fposmod(run * float(t.pulse_speed) + i * arena.size.y / float(t.pulses), arena.size.y) + arena.position.y
			seam.pulses.append(y)
			var on_bridge := false
			for b in seam.bridges:
				if absf(y - b) < 18:on_bridge = true
			if not on_bridge and absf(w.player.x - seam.x) < float(t.width) and absf(w.player.y - y) < 12:w.receive_hit(float(t.damage), hb)
	if move_age >= move_time:seam = {}; rest(w)

## Day acceleration: days pass in seconds. His shadow is the hand of the
## clock and it cuts while the sun is up; then time stops with the sun and the
## moon in one sky, three rings of frozen shards close the hero in, and time
## starts again.
func step_day(w):
	var d: Dictionary = data.two.day
	var t := move_age - 1.0
	var cycles: Array = d.cycles
	var elapsed := 0.0
	split = 0.0; shadow_on = false
	if t < 0:
		sky = 0.0; set_pose("float"); return
	for i in range(cycles.size()):
		var c: float = float(cycles[i])
		if t < elapsed + c:
			var k := (t - elapsed) / c
			sky = 0.5 - 0.5 * cos(k * TAU)
			sun = i + k
			# A sundial: by day the shadow sweeps the upper half, right to left. Below him is always safe.
			var day_k := clampf((k - 0.25) / 0.5, 0, 1)
			shadow_angle = lerpf(0.0, -PI, day_k)
			var sh: Dictionary = d.shadow
			shadow_on = k > 0.27 and k < 0.73
			if shadow_on and in_shadow(w.player):w.receive_hit(float(sh.damage), hb)
			var quarter := int(sun * 4.0)
			if quarter != int(hb.tick):hb.tick = quarter; w.sound("ch4_hb_tick", .02)
			if k >= 0.5 and not hb.ring_fired.has(i):
				hb.ring_fired.append(i)
				radial(w, int(d.ring), float(d.speed) * (1.0 + i * 0.18), i * 0.37, float(d.damage), "day", 4)
				w.sound("ch4_hb_pulse", .05)
			set_pose("float"); return
		elapsed += c
	t -= elapsed
	sun = cycles.size() + 0.5
	var kn: Dictionary = d.knives
	if t < float(d.freeze):
		sky = 0.5; split = 1.0; set_pose("cast")
		if knife_gaps.is_empty():
			knife_center = w.player; w.sound("ch4_hb_freeze"); w.sound("ch4_impact", .1); flash = .25
			var g0 := rng.randf() * TAU
			for j in range(int(kn.rings)):knife_gaps.append(g0 + j * rng.randf_range(0.35, 0.55) * (1 if rng.randf() < 0.5 else -1))
		var placed := mini(int(kn.rings), int(t / float(kn.every)) + 1)
		while hb.ring_fired.count(-1) < placed:
			var j: int = hb.ring_fired.count(-1)
			hb.ring_fired.append(-1)
			var radius: float = float(kn.radius[j])
			var count := int(kn.count) + j * 6
			for n in range(count):
				var a := n * TAU / count
				if absf(angle_difference(a, knife_gaps[j])) < float(kn.gap) * 0.5:continue
				var dir := Vector2.from_angle(a)
				shots.append({"p": knife_center + dir * radius, "v": Vector2.ZERO, "r": 3.0, "damage": float(d.damage), "kind": "knife",
					"life": 9.0, "frozen": true, "release": -dir * float(kn.speed), "dir": -dir})
			w.sound("ch4_hb_tick", .02)
		return
	t -= float(d.freeze)
	var release: float = float(d.release)
	if t < release:
		if not hb.ring_fired.has(-2):
			hb.ring_fired.append(-2); flash = .3; w.shake = .4; w.sound("ch4_impact"); w.sound("ch4_hb_shatter", .1)
			for b in shots:
				if b.get("frozen", false):b.frozen = false; b.v = b.release; b.life = 1.6
		split = 1.0 - t / release
		var n := int(t / (release / float(d.finale_rings)))
		if not hb.ring_fired.has(10 + n) and n < int(d.finale_rings):
			hb.ring_fired.append(10 + n); radial(w, int(d.ring) + 6, float(d.speed) * 1.5, n * 0.5, float(d.damage), "day", 4); flash = maxf(flash, .1)
		set_pose("slam"); return
	sky = 0.0; split = 0.0
	if move != "stunned":
		begin_move(w, "stunned", float(d.stun)); w.sound("ch4_hb_freeze")

func in_shadow(p: Vector2) -> bool:
	var sh: Dictionary = data.two.day.shadow
	var dir := Vector2(cos(shadow_angle), sin(shadow_angle) * 0.62).normalized()
	var rel: Vector2 = p - hb.p
	var along := rel.dot(dir)
	if along < 0 or along > float(sh.length):return false
	return absf(rel.dot(dir.orthogonal())) < float(sh.width) * 0.5 * (0.5 + along / float(sh.length))

func radial(_w, count: int, speed: float, turn: float, damage: float = -1.0, kind: String = "day", gaps: int = 0):
	if damage < 0:damage = float(data.two.day.damage)
	for i in range(count):
		if gaps > 0 and i % (count / gaps) < 2:continue
		var dir := Vector2.from_angle(turn + i * TAU / count)
		shots.append({"p": hb.p, "v": dir * speed, "r": 3.0, "damage": damage, "kind": kind, "life": 3.2})

func update_shots(w, dt: float):
	for i in range(shots.size() - 1, -1, -1):
		var b: Dictionary = shots[i]
		var before: Vector2 = b.p
		b.p += b.v * dt
		if not b.get("frozen", false):b.life -= dt
		var dead: bool = b.life <= 0 or not arena.grow(60).has_point(b.p)
		if dangerous() and Geometry2D.get_closest_point_to_segment(w.player, before, b.p).distance_to(w.player) < b.r + 5:
			w.receive_hit(b.damage, hb); dead = true
		if dead:shots.remove_at(i)

func clear_hazards():
	shots.clear(); marks.clear(); rings.clear(); lanes.clear(); hole = {}; path.clear(); seam = {}; drops.clear(); beams.clear(); waves.clear()
	move = ""; sky = 0.0; split = 0.0; shadow_on = false; knife_gaps.clear()

# ------------------------------------------------------------------ stage III: the fistfight

func press(action: String):
	if phase == "three":presses.append(action)

func next_qte(w):
	var events: Array = data.three.events
	if qte_index >= events.size():
		begin_death(w); return
	qte = events[qte_index].duplicate(true)
	qte.age = 0.0; qte.windup = 0.6; qte.progress = 0; qte.held = 0.0; qte.result = ""
	presses.clear()
	match qte.kind:
		"attack", "mash":set_pose("guard")
		"hold":set_pose("grab")
		_:set_pose(qte.hb)
	pose_age = 0.0
	set_steve("guard")

func step_three(w, dt: float):
	if qte.is_empty():return
	qte.age += dt
	var open: bool = qte.age >= qte.windup and qte.result == ""
	var close: float = qte.windup + float(qte.window)
	if qte.result == "":
		if open:
			match qte.kind:
				"dodge":
					for p in presses:
						if p == qte.dir:qte.result = "ok"
						elif p != "attack":qte.result = "fail"
				"attack":
					for p in presses:
						if p == "attack":qte.result = "ok"
				"hold":
					qte.held = qte.held + dt if hold else maxf(0.0, qte.held - dt * 0.5)
					if int(qte.held * 8) != int((qte.held - dt) * 8) and hold:impact(w, "hb", false, false, false)
					if qte.held >= float(qte.window) * 0.75:qte.result = "ok"
				"seq":
					for p in presses:
						if qte.progress < qte.dirs.size() and p == qte.dirs[qte.progress]:
							qte.progress += 1; set_steve("jab" if qte.progress % 2 == 1 else "hook"); steve_pose_age = 0.0; impact(w, "hb", false, true, false); set_pose("knocked"); pose_age = 0.0
						elif p != "attack":qte.result = "fail"
					if qte.progress >= qte.dirs.size():qte.result = "ok"
				"mash":
					for p in presses:
						if p == "attack" and qte.progress < int(qte.count):
							qte.progress += 1; set_steve("jab" if qte.progress % 2 == 1 else "hook"); steve_pose_age = 0.0
							set_pose("knocked"); pose_age = 0.0; impact(w, "hb", false)
					if qte.progress >= int(qte.count):qte.result = "ok"
			presses.clear()
			if qte.result == "" and qte.age >= close:qte.result = "fail"
		else:
			presses.clear()
		if qte.result != "":
			qte.resolved = qte.age
			resolve_qte(w, qte.result == "ok")
	elif qte.age - qte.resolved > (1.0 if qte.result == "ok" else 1.35):
		qte_index += 1
		if qte.result == "fail" and qte.kind in ["hold", "seq", "mash"]:qte_index -= 1
		next_qte(w)
	music = "" if qte_index > 6 else "boss_fade"

func impact(w, on: String, big: bool, sound: bool = true, stop: bool = true):
	impacts.append({"at": age, "on": on, "big": big, "seed": impacts.size() + qte_index * 7})
	if stop:hitstop = .16 if big else .07
	w.shake = maxf(w.shake, .35 if big else .14)
	if sound:w.sound("ch4_punch_heavy" if big else "ch4_punch", .03)

func resolve_qte(w, ok: bool):
	var kind: String = qte.kind
	if ok:
		match kind:
			"dodge":set_steve("dodge_l" if qte.dir in ["left", "up"] else "dodge_r"); set_pose(qte.hb); pose_age = 0.0; w.sound("ch4_punch_miss", .05)
			"attack":
				set_steve("lunge"); set_pose(qte.hb); pose_age = 0.0
				if qte.hb == "fall":
					impact(w, "hb", true); impact_frame = .2; hitstop = .3; flash = .2; w.sound("ch4_impact", .02)
				else:impact(w, "hb", false); flash = .05
			"hold":set_steve("throw"); set_pose("stagger"); impact(w, "hb", true)
			"seq":set_steve("throw"); set_pose("fall" if qte_index > 8 else "stagger"); impact(w, "hb", true)
			"mash":set_steve("lunge"); set_pose("stagger"); impact(w, "hb", true); impact_frame = .12; w.sound("ch4_impact", .05)
	else:
		set_steve("knocked"); set_pose("lunge" if kind != "hold" else "throw"); pose_age = 0.0
		w.hp = maxf(0.0, w.hp - float(data.three.hit)); w.player_visual.hurt = .12
		impact(w, "steve", true, false)
		w.sound("ch4_hurt", .05); w.sound("ch4_punch_heavy", .05); flash = .05
	w.sound("ch4_breath", .4)

# ------------------------------------------------------------------ death

const MOUNT := Vector2(-1, -3)

func begin_death(w):
	phase = "death"; age = 0.0; set_pose("lying"); face = "smile"; set_steve("grab"); music = ""; silence = true
	hb.p = center + Vector2(28, 0); hb.visual_dir = Vector2.LEFT; hb.scale = 1.0
	w.player = hb.p - Vector2(20, 0); w.facing = Vector2.RIGHT
	w.sound("ch4_body_fall")

func step_death(w, dt: float):
	var d: Dictionary = data.death
	var mount_at: float = float(d.drag)
	# He is dragged by the feet back onto the ground, laughing.
	if age < mount_at:
		hb.p = (center + Vector2(28, 0)).lerp(center, smoothstep(0.3, mount_at - 0.2, age))
		w.player = hb.p - Vector2(20, 0); w.facing = Vector2.RIGHT; set_steve("grab")
	steve_at = hb.p + MOUNT
	for line in d.lines:
		if age >= float(line.at) and not spoken.has(line.text) and age < float(d.final):
			spoken[line.text] = true
			say(line.text, line.style, float(line.cut) - float(line.at) + 0.5, float(line.cut) - float(line.at))
	var final_t: float = float(d.final)
	if age >= mount_at and age < float(d.stand):
		w.player = steve_at
		var want := "mount_still"
		for t in d.punches:
			if age >= float(t) - 0.3 and age < float(t):want = "mount_raise"
			elif age >= float(t) and age < float(t) + 0.4:want = "mount_slam"
		if age >= final_t - 0.8 and age < final_t:want = "mount_raise"
		elif age >= final_t:want = "mount_slam" if age < final_t + 2.4 else "mount_still"
		set_steve(want)
	for t in d.punches:
		if age >= float(t) and age - dt < float(t):
			set_pose("lying_hit"); pose_age = 0.0; w.sound("ch4_punch_heavy", .02); punch_at = age
			w.shake = .16; hitstop = .05
	if age >= final_t and age - dt < final_t:
		set_pose("headless"); flash = .5; w.shake = .6; hitstop = .2; impact_frame = .14
		w.sound("ch4_head_break", .02); w.sound("ch4_bone_crack", .02); w.sound("ch4_impact", .02)
		head_at = age
		text_events.clear()
	if pose == "lying_hit" and pose_age > .35:set_pose("lying")
	if age >= float(d.stand):
		set_steve("lower_arm"); w.player = hb.p + Vector2(22, 3)
	if age >= float(d.duration):
		phase = "coords"; age = 0.0; w.player = hb.p + Vector2(-26, 8); set_steve("idle"); music = ""; silence = true

func step_coords(w):
	if age > 1.2 and age < 2.6:set_steve("walk"); w.player = w.player.move_toward(hb.p + Vector2(-12, 10), 0.4)
	else:set_steve("idle")
	if age >= 3.4 and age < 3.7:glitch = maxf(glitch, .1)
	if age >= float(data.coords.duration):
		phase = "road"; age = 0.0; road_index = 0

func step_road(w, dt: float):
	var scenes: Array = data.road.scenes
	var each: float = float(data.road.each)
	road_index = int(age / each)
	if road_index >= scenes.size():
		phase = "door"; age = 0.0; door_state = "approach"
		var door := Vector2(data.door.p[0], data.door.p[1])
		w.player = door + Vector2(-120, 30); camera_at = door + Vector2(-50, 0); w.facing = Vector2.RIGHT
		return
	var base := Vector2(scenes[road_index][0], scenes[road_index][1])
	var k := fposmod(age, each) / each
	w.player = base + Vector2(-60 + 120 * k, 40); w.facing = Vector2.RIGHT; w.player_moving = true
	camera_at = base + Vector2(0, 10)
	set_steve("walk")

func step_door(w, dt: float):
	var door := Vector2(data.door.p[0], data.door.p[1])
	var target := door + Vector2(0, 22)
	if age < 4.0:
		w.player = w.player.move_toward(target + Vector2(-26, 0), 34 * dt); w.facing = Vector2.RIGHT; set_steve("walk")
	elif age < 5.6:
		door_state = "open"; set_steve("idle")
		if age - dt < 4.0:w.sound("ch4_door_open")
	elif age < 7.6:
		door_state = "look"; w.facing = Vector2.LEFT; set_steve("idle")
	elif age < 9.8:
		door_state = "enter"; w.facing = Vector2.UP; set_steve("walk")
		w.player = w.player.move_toward(door + Vector2(0, -4), 20 * dt)
	elif age < 10.4:
		door_state = "gone"
	else:
		if door_state != "closed":door_state = "closed"; w.sound("ch4_door_close")
	camera_at = camera_at.lerp(door + Vector2(-10, 0), minf(1, dt * 1.5))
	if age >= float(data.door.duration):
		phase = "done"; w.state = "RESULT"; w.victory = true
		if not stored.is_empty():w.build = stored.build; w.items = stored.items; w.evolved = stored.evolved
		w.run_progress.finish(w)

# ------------------------------------------------------------------ checkpoints

func save_checkpoint(w, from: String):
	checkpoint = {"from": from, "hp": maxf(w.hp, 12.0), "hb_hp": hb.hp, "player": w.player, "build": w.build.duplicate(), "items": w.items.duplicate(), "evolved": w.evolved.duplicate()}

func begin_retry(w):
	retry_from = checkpoint.get("from", "one")
	phase = "retry"; age = 0.0; clear_hazards(); text_events.clear(); qte = {}; impacts.clear()
	for key in w.solid_grid.keys():w.solid_grid[key] = w.solid_grid[key].filter(func(o): return not o.get("rift", false))
	w.hp = 1.0

func restore_checkpoint(w):
	w.hp = float(checkpoint.hp); w.invulnerable = 1.5
	w.build = checkpoint.build.duplicate(); w.items = checkpoint.items.duplicate(); w.evolved = checkpoint.evolved.duplicate()
	hb.hp = float(checkpoint.hb_hp); hb.max_hp = float(data.one.hp if retry_from == "one" else data.two.hp)
	w.player = checkpoint.player
	phase = retry_from; age = 0.0
	if phase == "tower":
		hb.scale = float(data.giant); begin_tower(w); age = float(data.tower.rise); hb.p = tower_base(); hb.perched = true
		tower_h = float(data.tower.height); tower_solid(w, false); tower_solid(w, true)
	elif phase == "one" or phase == "two":
		hb.p = center + Vector2(0, -90); begin_move(w, "rest", 1.2); hb.scale = float(data.giant); hb.perched = false
		if phase == "two":day_done.clear()
		music = "boss_one" if phase == "one" else "boss_two"
	elif phase == "last":
		hb.p = center; hb.scale = float(data.giant); stored = {}; spoken.erase("beam")
		phase = "two"; begin_last(w)
	else:
		hb.scale = 1.0
		hb.p = center + Vector2(13, 0); w.player = center + Vector2(-13, 0); qte_index = 0; next_qte(w)
