extends RefCounted
## Notch, at 12:00. A talk, a fight in the code space, then his games:
## an Undertale-style battle box and a lane defence where he plays the
## zombies. Each phase restarts from its own checkpoint.
const CENTER := Vector2(1024, 1024)
## [text, pose]; phrases of one line follow each other at reading pace (see say()).
const BAD_FILM_LENGTH := 33.0
## After the bad ending: the card, then slow grey credits.
const BAD_CREDITS_LENGTH := 30.0
const BAD_CREDITS := [[5.5, "Создатель", "Daydert"], [10.0, "Композитор", "Kibi"], [14.5, "Музыка · тестирование", "RodinCity"], [19.0, "Тестирование", "SET553355"], [24.0, "Тестирование завершено.", "Стив не найден"]]
const INTRO_SCRIPT := [["Еуу, пипец ты силён, я смотрю\nДостиг 2 миллионов мощи", "invite"], ["Знаешь, я запускал тебе подобных столько раз, что уже и не знаю, какая это итерация", "look_hand"],
	["Интересно, понравилось ли оцифрованной душе моего брата впервые так жалко подохнуть?\nЭто ещё глупее, чем упасть в зерно и задохнуться", "point"], ["ЗДЕСЬ Я ХОЗЯИН\nЯ ТЕБЯ ПОРОДИЛ, Я ТЕБЯ И УНИЧТОЖУ", "snap"],
	["Спросишь, зачем это всё? Ну, мне было скучно, да и личный уголок для моего брата-садиста сам себя бы не создал", "aura"], ["Не знаю, что в моём спагетти настолько мутировало, что ты появился на свет", "point"],
	["Это даже мило, но, боюсь, мне ещё нужно откатить его тело после того, как ты буквально размозжил ему черепушку", "idle"], ["Покажешь, чему научился?", "invite"]]
static func part_life(text: String) -> float:return clampf(.9 + text.length() / 20.0, 1.5, 7.0)
static func line_life(text: String) -> float:
	var total := 0.0
	for part in text.split("\n"):total += part_life(part) + .2
	return total
static func intro_times() -> Array:
	var out: Array = [];var t := .6
	for row in INTRO_SCRIPT:out.append(t);t += line_life(row[0]) + .35
	out.append(t + .4)
	return out
var INTRO_AT: Array = intro_times()
var INTRO_LENGTH: float = INTRO_AT[INTRO_AT.size() - 1]
const FIGHT_HP := 1500.0
const UT_BOX := Rect2(220, 160, 200, 110)
const UT_HP := 100.0
const LANE_ORIGIN := Vector2(112, 96)
const CELL := Vector2(52, 46)
const COLS := 9
const ROWS := 5
const CARDS := [["dispenser", 100, 4.0], ["redstone_ore", 50, 4.0], ["obsidian", 50, 12.0], ["tnt", 150, 20.0], ["snow_golem", 125, 6.0], ["cactus", 100, 8.0], ["piston", 75, 10.0], ["magma", 75, 10.0]]
const PLANT_HP := {"dispenser": 6.0, "redstone_ore": 6.0, "obsidian": 40.0, "tnt": 99.0, "snow_golem": 6.0, "cactus": 10.0, "piston": 12.0, "magma": 99.0}
const ZOMBIES := {"zombie": [10.0, 9.0], "elite": [26.0, 8.0], "glitch": [7.0, 18.0], "creeper": [10.0, 10.0], "baby": [6.0, 21.0], "spider": [12.0, 14.0], "slime": [16.0, 7.0], "small_slime": [5.0, 11.0], "vindicator": [20.0, 12.0], "skeleton": [10.0, 8.0], "ravager": [150.0, 5.0]}
## Floor blocks the walkers step over instead of biting.
const FLAT := ["magma"]
var bad_from_qte := false
var bad_entry_track := "miss"
var bad_blood := 0.0
var phase := ""
var age := 0.0
var line := ""
var line_age := 0.0
var line_length := 0.0
var screamed := false
var id := -1
var hp := FIGHT_HP
var pose := "idle"
var pose_age := 0.0
var p := CENTER
var dir := Vector2.DOWN
var attack_timer := 3.0
var attack_index := 0
var walls: Array = []
var falls: Array = []
var popups: Array = []
var slow_left := 0.0
var retry_of := ""
var cues := 0
# battle box
var soul := Vector2.ZERO
var ut_hp := UT_HP
var ut_state := "menu"
var ut_choice := 0
var ut_text := ""
var ut_wave := 0
var ut_serial2 := 0
var ut_bullets: Array = []
var ut_timer := 0.0
var ut_items := 2
var mercy_gone := false
var bar := 0.0
var ut_hits := 0
var ut_clean := false
var ut_flash := 0.0
# lanes
var plants: Dictionary = {}
var zombies: Array = []
var arrows: Array = []
var bone_arrows: Array = []
var lane_total := 1
var blasts: Array = []
var redstone := 150
var card := 0
var cursor := Vector2i(2, 2)
var card_ready: Array = [0.0, 0.0, 0.0, 0.0]
var trickle := 6.0
## Lane defence extras: falling redstone to pick up, a minecart per row
## that saves it once (the lawnmower), and bodies that fade out.
var drops: Array = []
var carts: Array = []
var corpses: Array = []
var schedule: Array = []
var lane_age := 0.0
var cursor_dir := Vector2i.ZERO
var cursor_wait := 0.0
var serial := 0
var fighter = preload("res://scripts/chapter_five_fighter.gd").new()
var quake = preload("res://scripts/chapter_five_quake.gd").new()
## Quake input from main.gd: wish (strafe, forward), look delta, held buttons.
var quake_input: Dictionary = {"wish":Vector2.ZERO, "turn":Vector2.ZERO, "fire":false, "jump":false}
var shake3d := 0.0
var qte = preload("res://scripts/chapter_five_qte.gd").new()
var finale = preload("res://scripts/chapter_five_finale.gd").new()

func reset():
	qte.reset()
	phase = "";age = 0.0;line = "";id = -1;hp = FIGHT_HP;walls.clear();falls.clear();popups.clear();slow_left = 0.0;retry_of = ""
	ut_bullets.clear();ut_items = 2;mercy_gone = false;ut_hits = 0;plants.clear();zombies.clear();arrows.clear();blasts.clear()
	ut_clean = false

func active() -> bool:return not phase.is_empty()

## Multi-part lines are queued; each phrase gets reading time. Capitals are a scream.
var line_queue: Array = []
var scream := false
var mirrored := ""
func say(text: String, length: float):
	var parts: PackedStringArray = text.split("\n")
	line_queue.clear()
	for i in range(parts.size()):
		var life: float = maxf(length if parts.size() == 1 else 0.0, part_life(parts[i]))
		line_queue.append([parts[i], life])
	next_line()
func next_line():
	if line_queue.is_empty():line = "";line_length = 0;scream = false;return
	var row: Array = line_queue.pop_front();line = row[0];line_age = 0.0;line_length = row[1]
	scream = line.length() >= 4 and line == line.to_upper() and line != line.to_lower()
	if scream:shake3d = maxf(shake3d, .8);screamed = true
func set_pose(name: String):
	if pose != name:pose = name;pose_age = 0.0
func change(next: String):phase = next;age = 0.0;cues = 0

func cue(bit: int, at: float) -> bool:
	if age >= at and not (cues & (1 << bit)):
		cues |= 1 << bit;return true
	return false

# ------------------------------------------------------------------ arena

func begin(w):
	reset()
	w.stage = "notch"
	clear_arena(w)
	w.player = CENTER + Vector2(0, 90);w.facing = Vector2.UP
	p = CENTER + Vector2(0, -40);dir = Vector2.DOWN
	change("intro");set_pose("idle")
	w.sound("ch4_hb_glitch", .1)

func clear_arena(w):
	for pool in [w.mobs, w.projectiles, w.shots, w.zones, w.deleted, w.pending, w.effects, w.orbs, w.loot, w.tasks]:pool.clear()
	w.hint = {};w.invert = 0.0;w.hijack = {};w.lag = 0.0;w.bosses.terminal = {};w.bosses.loop = {};w.bosses.ghosts.clear()
	w.arsenal.commands.clear();w.arsenal.pastes.clear();w.arsenal.allies.clear()
	w.hit_grid.clear();w.invulnerable = 1.0

func skip():
	if phase == "intro" and age > 1.0:age = INTRO_LENGTH - .1
	elif phase in ["to_ut", "to_lanes", "lanes_won", "to_quake", "quake_won", "to_code"] and age > .8:age = 99.0
	elif phase == "chair":finale.skip_line()
	# Credits always play through (13.11): no skipping.

func step(w, dt: float, movement: Vector2):
	age += dt;pose_age += dt
	if line_length > 0:
		line_age += dt
		if line_age >= line_length:next_line()
	if screamed:screamed = false;w.sound("ch4_hb_glitch");w.sound("explosion", .1)
	for list in [popups]:
		for i in range(list.size() - 1, -1, -1):
			list[i].age += dt
			if list[i].age > 1.8:list.remove_at(i)
	w.shake = maxf(0, w.shake - dt);w.invulnerable = maxf(0, w.invulnerable - dt);w.message_timer = maxf(0, w.message_timer - dt)
	match phase:
		"intro":
			for i in range(INTRO_SCRIPT.size()):
				if cue(i, INTRO_AT[i]):say(INTRO_SCRIPT[i][0], 0.0);set_pose(INTRO_SCRIPT[i][1])
			dir = p.direction_to(w.player)
			idle_world(w, dt)
			if age >= INTRO_LENGTH:start_fight(w)
		"fight":fight(w, dt, movement)
		"to_ut":
			if cue(0, .1):say("Чувак, мне чертовски скучно, пошли туда, где интереснее", 2.6);set_pose("snap")
			idle_world(w, dt)
			portal_sounds(w, dt)
			if age >= 4.4:start_ut(w)
		"ut":battle(w, dt, movement)
		"to_lanes":
			if cue(0, .1):say("Всегда любил играть за атаку!", 2.8)
			portal_sounds(w, dt)
			if age >= 4.4:start_lanes(w)
		"lanes":lanes(w, dt, movement)
		"lanes_won":
			if cue(0, .1):say("Неплохо для разминки", 2.8)
			portal_sounds(w, dt)
			if age >= 4.4:start_fighter(w)
		"fighter":fight3d(w, dt, movement)
		"to_quake":
			if cue(0, .1):say("Хах, перейдём к моей любимой", 2.8)
			portal_sounds(w, dt)
			if age >= 4.4:start_quake(w)
		"quake":deathmatch(w, dt)
		"quake_won":
			if cue(0, .1):say("...\nНе могу поверить, что проиграл тебе в этом...", 2.8)
			if age >= 3.2:change("to_code")
		"to_code":
			if cue(0, .1):say("Чёрт, мне реально приходится сражаться с тобой здесь?", 2.8)
			portal_sounds(w, dt)
			if age >= 4.4:start_code(w)
		"code":code(w, dt)
		"erase":
			finale_sounds(w, finale.step(dt))
			if finale.phase == "erase_failed":begin_bad_end(w)
			elif finale.thrown >= 3.6:start_qte(w)
		"qte":
			qte.step(dt)
			for event in qte.events:
				match event:
					"dodge":w.sound("ch4_punch_miss",.05)
					"block":w.sound("shield_block",.05)
					"hit","counter","ko_punch":w.sound("ch4_punch_heavy",.05);w.sound("ch4_flesh_hit",.05)
					"hurt":w.sound("ch4_punch",.05);w.sound("ch4_flesh_hit",.05)
					"table_hit":w.sound("ch1_wood_place",.05);w.sound("ch4_bone_crack",.05)
			if qte.result=="lost":begin_bad_end(w)
			elif qte.result=="won":finale.change("chair");change("chair")
		"bad_end":
			# Pre-rendered film (scripts/cinematics/build_ch5_bad_end.py); its sound plays with it.
			if age>=BAD_FILM_LENGTH:change("bad_credits");w.run_progress.award("bad_ending");w.sound("ch5_bad_credits")
		"bad_credits":
			if age>=BAD_CREDITS_LENGTH:w.sound("ch5_credits_stop");w.state="RESULT";w.victory=false
		"fists":fists(w, dt, movement)
		"chair":
			var r: String = finale.step(dt);finale_sounds(w, r)
			if r == "done":finale.change("flight");change("flight")
		"flight":
			var r: String = finale.step(dt);finale_sounds(w, r)
			if r == "done":finale.change("credits");change("credits")
		"credits":
			var r: String = finale.step(dt);finale_sounds(w, r)
			if r == "done":finish(w)
		"retry":
			if age >= 2.4:
				w.hp = 20.0;w.invulnerable = 1.5
				match retry_of:
					"fight":start_fight(w)
					"ut":start_ut(w)
					"lanes":start_lanes(w)
					"fighter":start_fighter(w)
					"quake":start_quake(w)
					"code":start_code(w, true)
					"fists":start_fists(w)

func idle_world(w, dt: float):
	w.player_visual.travel = 0.0;w.player_moving = false
	w.update_particles(dt);w.animation.advance(w, dt)

func lose(w, which: String):
	retry_of = which;change("retry")
	w.sound("death", .2)
	say("Чекпоинт!\nЕщё раз", 2.0)

func finish(w):
	# The flight is over: Steve is somewhere else now.
	phase = "done"
	w.state = "RESULT";w.victory = true
	w.run_progress.finish(w)

# ------------------------------------------------------------------ the fight

## Stage one: every attack is a readable telegraph followed by a hard hit.
## Below half HP he stops pretending: the page goes black and attacks overlap.
const ARENA := Vector2(300, 170)
const PHASE_ONE := ["select", "blocks", "beam", "clones", "spiral", "slam"]
const PHASE_TWO := [["clones", "blocks"], ["beam"], ["select", "spiral"], ["slam"], ["blocks", "spiral"], ["clones", "select"]]
## How long each attack keeps him busy, then the breather after it.
const ATTACK_LENGTH := {"select":2.0, "blocks":2.1, "beam":3.4, "clones":2.3, "spiral":2.8, "slam":2.6}
var hz: Array = []
var enraged := false
var dark := 0.0
var flash := 0.0
var busy := 0.0
var slam_at := Vector2.ZERO
var slam_age := -1.0
var spiral_left := 0.0
var spiral_turn := 0.0
var hit_stop := 0.0

func start_fight(w):
	clear_arena(w)
	w.player = CENTER + Vector2(0, 90)
	p = CENTER + Vector2(0, -40)
	w.super_spawn("notch", p)
	var m: Dictionary = w.mobs.back()
	m.code = true;m.glitch = false;m.boss = true;m.owner = 0;m.depth = 0;m.shield = false;m.reveal = 0.0;m.broken = false
	m.hp = FIGHT_HP;m.max_hp = FIGHT_HP
	id = m.id;hp = FIGHT_HP;attack_timer = 2.0;attack_index = 0;walls.clear();falls.clear();slow_left = 0.0
	hz.clear();enraged = false;dark = 0.0;flash = 0.0;busy = 0.0;slam_age = -1.0;spiral_left = 0.0;hit_stop = 0.0
	change("fight");set_pose("idle")

func notch_mob(w):
	for m in w.mobs:
		if m.id == id:return m
	return null

func hurt(w, m: Dictionary, amount: float):
	hp -= amount;m.hp = maxf(1.0, hp);m.flash = .07
	w.add_effect("damage", m.p + Vector2(0, -30), .5, {"amount":int(ceil(amount))})

func hit_player(w, amount: float):
	if w.invulnerable > 0 or w.hp <= 0:return
	w.damage_player(amount)
	w.shake = maxf(w.shake, .22);hit_stop = .06;flash = maxf(flash, .25)
	w.sound("ch4_flesh_hit", .05)

func fight(w, dt: float, movement: Vector2):
	var m = notch_mob(w)
	if m == null:start_fight(w);return
	flash = maxf(0, flash - dt)
	dark = move_toward(dark, 1.0 if enraged else 0.0, dt * .8)
	if hit_stop > 0:hit_stop -= dt;return
	var speed: float = w.movement_speed()
	var before: Vector2 = w.player
	if movement.length_squared() > 0:
		w.facing = movement.normalized()
		w.player = w.move_actor(w.player, movement.limit_length() * speed * dt, 6)
	w.player = w.player.clamp(CENTER - ARENA, CENTER + ARENA)
	w.tracked_velocity = (w.player - before) / maxf(.0001, dt)
	w.player_visual.travel = before.distance_to(w.player);w.player_moving = w.player_visual.travel > .0001
	if slam_age >= 0:
		slam_step(w, dt)
	else:
		# Between attacks he keeps a lazy distance and circles.
		var off: Vector2 = p - w.player
		var want: float = 150.0
		p += (off.normalized() * (want - off.length()) * 1.4 + off.normalized().orthogonal() * (26.0 if enraged else 16.0)).limit_length(80.0) * dt
		p = p.clamp(CENTER - Vector2(270, 150), CENTER + Vector2(270, 140))
	m.p = p;dir = p.direction_to(w.player);m.dir = dir
	m.stun = 0.0
	if spiral_left > 0:spiral_step(w, dt)
	busy -= dt
	attack_timer -= dt
	if attack_timer <= 0 and busy <= 0:attack(w)
	hazards_step(w, dt)
	w.rebuild_hit_grid()
	w.update_attacks(dt);w.update_projectiles(dt);w.update_shots(dt)
	w.move_mobs(dt)
	m.p = p
	w.arsenal.step(w, dt)
	w.resolve_deaths()
	w.update_effects(dt);w.pickup(dt);w.update_particles(dt);w.animation.advance(w, dt)
	if w.hp <= 0:lose(w, "fight");return
	if not enraged and hp <= FIGHT_HP * .5:
		enraged = true;flash = 1.0;w.shake = .5;busy = 1.6;attack_timer = 1.6;hz.clear();spiral_left = 0.0
		popups.append({"p":p, "text":"difficulty = HARDCORE;", "age":0.0})
		set_pose("aura");w.sound("ch4_hb_roar", .1);w.sound("ch4_hb_glitch", .1);shake3d = 1.0
	if hp <= 0:
		m.hp = 0;w.mobs.erase(m);id = -1
		walls.clear();falls.clear();hz.clear();spiral_left = 0.0;w.shots.clear();w.zones.clear()
		for o in w.mobs:o.hp = 0
		w.mobs.clear()
		change("to_ut")
	if w.xp >= w.db.required_xp(w.level):w.xp = 0

func attack(w):
	attack_index += 1
	var kinds: Array = [PHASE_ONE[(attack_index - 1) % PHASE_ONE.size()]] if not enraged else PHASE_TWO[(attack_index - 1) % PHASE_TWO.size()]
	var length := 0.0
	for kind in kinds:
		launch(w, kind)
		length = maxf(length, ATTACK_LENGTH[kind])
	busy = length * (.8 if enraged else 1.0)
	attack_timer = busy + (.55 if enraged else 1.0)

func launch(w, kind: String):
	var pl: Vector2 = w.player
	var n: int = attack_index
	match kind:
		"select":
			# Ctrl+A, Del: rectangles drag open on the floor, then the floor is deleted.
			set_pose("snap")
			popups.append({"p":p, "text":"select(); Del", "age":0.0})
			var count: int = 4 if enraged else 3
			for k in range(count):
				var size := Vector2(150 + (k % 2) * 60, 90 + ((k + n) % 3) * 24)
				var at: Vector2 = pl if k == 0 else CENTER + Vector2(fposmod(n * 173.0 + k * 241.0, ARENA.x * 2) - ARENA.x, fposmod(n * 97.0 + k * 131.0, ARENA.y * 2) - ARENA.y)
				var r := Rect2(at - size * Vector2(fposmod(k * .37 + n * .21, .6) + .2, fposmod(k * .53 + n * .3, .6) + .2), size)
				hz.append({"kind":"select", "rect":r, "corner":(k + n) % 4, "age":-k * .18, "drag":.6, "hold":.55, "hit":false})
			w.sound("select", .05)
		"blocks":
			# Blocks fall where he expects you to walk, with a TNT among them.
			set_pose("cast")
			popups.append({"p":p, "text":"world.setBlock(...)", "age":0.0})
			var lead: Vector2 = w.tracked_velocity.limit_length(140.0)
			var count: int = 14 if enraged else 10
			for k in range(count):
				var q: Vector2 = pl + lead * (k * .09) + Vector2.from_angle(k * 2.39996 + n) * (k * 7.0 if k > 0 else 0.0)
				q = q.clamp(CENTER - ARENA, CENTER + ARENA)
				var block: String = ["ch5q_cobblestone", "ch5q_deepslate_tiles", "end_obsidian", "ch5q_polished_blackstone_bricks"][k % 4]
				if k == 5 or (enraged and k == 11):block = "ch5q_tnt"
				hz.append({"kind":"block", "p":q, "age":-k * .07, "fall":.95, "block":block, "hit":false})
			w.sound("ch4_hb_rain", .1)
		"beam":
			# Two (three) beams sweep around him; the thin lines show where they start.
			set_pose("aura")
			popups.append({"p":p, "text":"while(true) render(beam);", "age":0.0})
			var count: int = 3 if enraged else 2
			var base: float = p.direction_to(pl).angle() + .9
			var spin: float = (1.0 if n % 2 == 0 else -1.0) * (1.05 if enraged else .85)
			for k in range(count):hz.append({"kind":"beam", "angle":base + k * TAU / count, "spin":spin, "age":0.0, "warn":.9, "life":2.4})
			w.sound("ch4_hb_charge", .1)
		"clones":
			# Ctrl+C, Ctrl+V: copies of him around you, each dashes through where you stand.
			set_pose("snap")
			popups.append({"p":p, "text":"Ctrl+C · Ctrl+V", "age":0.0})
			var count: int = 5 if enraged else 3
			for k in range(count):
				var from: Vector2 = pl + Vector2.from_angle(n * 1.3 + k * TAU / count) * 170.0
				hz.append({"kind":"clone", "from":from, "p":from, "target":pl, "age":-k * .22, "warn":.95, "dash":.42, "hit":false})
			w.sound("ch4_hb_strip", .1)
		"spiral":
			set_pose("cast")
			popups.append({"p":p, "text":"for(;;) emit();", "age":0.0})
			spiral_left = 2.4;spiral_turn = p.direction_to(pl).angle()
			w.sound("ch4_hb_pulse", .1)
		"slam":
			# He leaves the page; a reticle hunts you, locks, and he lands.
			set_pose("float")
			slam_age = 0.0;slam_at = pl
			w.add_effect("ch5_rewind", p, .4, {"to":p + Vector2(0, -200)})
			w.sound("ch4_hb_teleport", .1)

func spiral_step(w, dt: float):
	var before: float = spiral_left
	spiral_left -= dt
	var every: float = .075
	var arms: int = 4 if enraged else 3
	if int(before / every) != int(spiral_left / every):
		spiral_turn += .23 * (1.0 if attack_index % 2 else -1.0)
		for k in range(arms):
			var a: float = spiral_turn + k * TAU / arms
			hz.append({"kind":"bolt", "p":p + Vector2(0, -14) + Vector2.from_angle(a) * 12.0, "v":Vector2.from_angle(a) * (125.0 if enraged else 105.0), "age":0.0, "glyph":"{};<>()=/"[(int(spiral_left * 40) + k) % 9]})
		if int(spiral_left * 13) % 3 == 0:w.sound("ch4_hb_tick", .05)

func slam_step(w, dt: float):
	slam_age += dt
	var hunt: float = 1.05;var lock: float = .35
	if slam_age < hunt:slam_at = slam_at.lerp(w.player, 1.0 - exp(-dt * 7.0))
	p = slam_at + Vector2(0, -260.0 * (1.0 - smoothstep(hunt + lock - .12, hunt + lock, slam_age)))
	if slam_age >= hunt + lock and slam_age - dt < hunt + lock:
		set_pose("slam");p = slam_at
		w.sound("ch4_ground_slam", .05);w.sound("explosion", .05);w.shake = .45;shake3d = .6
		if w.player.distance_to(slam_at) < 46:hit_player(w, 5.0)
		var gaps: Array = []
		var gap0: float = w.player.angle_to_point(slam_at) + PI + .5
		for k in range(4 if not enraged else 3):gaps.append(gap0 + k * TAU / (4 if not enraged else 3))
		hz.append({"kind":"wave", "p":slam_at, "age":0.0, "gaps":gaps, "hit":false})
		hz.append({"kind":"crater", "p":slam_at, "age":0.0})
	if slam_age > hunt + lock + .6:slam_age = -1.0;set_pose("idle")

func hazards_step(w, dt: float):
	var pl: Vector2 = w.player
	for h in hz:
		var before: float = h.age
		h.age += dt
		if h.age < 0:continue
		match h.kind:
			"select":
				var del: float = h.drag + h.hold
				if before < h.drag and h.age >= h.drag:w.sound("select", .05)
				if before < del and h.age >= del:w.sound("ch4_hb_shatter", .05);w.shake = maxf(w.shake, .15)
				if h.age >= del and h.age < del + .3 and not h.hit and h.rect.grow(-4).has_point(pl):h.hit = true;hit_player(w, 4.0)
				h.done = h.age > del + .9
			"block":
				if before < h.fall and h.age >= h.fall:
					w.shake = maxf(w.shake, .12);w.sound("ch4_stone_hit", .06)
					if h.block != "ch5q_tnt" and pl.distance_to(h.p) < 17:hit_player(w, 3.0)
				if h.block == "ch5q_tnt" and before < h.fall + .7 and h.age >= h.fall + .7:
					w.sound("explosion", .05);w.shake = maxf(w.shake, .35)
					if pl.distance_to(h.p) < 52:hit_player(w, 5.0)
				h.done = h.age > h.fall + (1.5 if h.block == "ch5q_tnt" else .9)
			"beam":
				if h.age >= h.warn:
					h.angle += h.spin * dt * smoothstep(h.warn, h.warn + .3, h.age)
					var d: Vector2 = Vector2.from_angle(h.angle)
					var rel: Vector2 = pl - (p + Vector2(0, -14))
					if h.age < h.warn + h.life and rel.dot(d) > 10 and absf(rel.cross(d)) < 9.0:hit_player(w, 3.0)
				else:h.angle += h.spin * dt * .15
				if before < h.warn and h.age >= h.warn:w.sound("ch4_hb_beam", .05);w.shake = maxf(w.shake, .15)
				h.done = h.age > h.warn + h.life + .25
			"clone":
				if h.age < h.warn - .2:h.target = h.target.lerp(pl, 1.0 - exp(-dt * 5.0))
				var d: Vector2 = h.from.direction_to(h.target)
				if h.age >= h.warn:
					var k: float = clampf((h.age - h.warn) / h.dash, 0, 1)
					h.p = h.from + d * 420.0 * (1.0 - pow(1.0 - k, 2.0))
					if not h.hit and h.p.distance_to(pl) < 16:h.hit = true;hit_player(w, 4.0)
					if before < h.warn:w.sound("ch4_hb_blitz", .05)
				h.done = h.age > h.warn + h.dash + .35
			"bolt":
				h.p += h.v * dt
				if h.p.distance_to(pl) < 7:hit_player(w, 2.0);h.done = true
				if not Rect2(CENTER - ARENA - Vector2(60, 60), ARENA * 2 + Vector2(120, 120)).has_point(h.p):h.done = true
			"wave":
				var r: float = h.age * 290.0
				var dist: float = pl.distance_to(h.p)
				if not h.hit and absf(dist - r) < 9 and r > 50:
					var a: float = pl.angle_to_point(h.p) + PI
					var safe := false
					for g in h.gaps:safe = safe or absf(angle_difference(a, g)) < .3
					if not safe:h.hit = true;hit_player(w, 4.0)
				h.done = r > 420.0
			"crater":h.done = h.age > 2.0
	hz = hz.filter(func(h):return not h.get("done", false))

# ------------------------------------------------------------------ the battle box

## Undertale rules: the box takes the shape of each attack, the soul is red
## (free) or blue (heavy, thrown against walls), every hit freezes the frame.
const MENU_BOX := Rect2(40, 166, 560, 104)
const WAVE_LENGTH := 7.0
const UT_CENTER := Vector2(320, 206)
## [box size, soul mode, spawn period]
const PATTERNS := [[Vector2(240, 104), "red", .08], [Vector2(240, 96), "blue", .85], [Vector2(170, 130), "red", 1.15], [Vector2(190, 130), "red", .80],
	[Vector2(220, 116), "red", .34], [Vector2(150, 130), "blue", 1.45], [Vector2(230, 112), "red", .52], [Vector2(150, 130), "red", .80]]
## Fourth turn on, a lighter second pattern runs under the main one.
const SECOND := {0:6, 2:4, 3:6, 4:6, 6:4, 7:4}
func start_ut(w):
	clear_arena(w)
	ut_clean = true
	change("ut");ut_hp = UT_HP;ut_hp_shown = UT_HP;ut_wave = 0;ut_bullets.clear();ut_hits = 0;ut_blasters.clear();ut_choice = 0;ut_sparks.clear();ut_selects.clear()
	ut_state = "menu";ut_text = "* Нотч загораживает путь";ut_type = 0.0
	ut_box = MENU_BOX;ut_box_to = MENU_BOX
	soul = UT_CENTER;ut_mode = "red";ut_grav = Vector2.DOWN;ut_freeze = 0.0;ut_hurt = 0.0;ut_quake = 0.0
	w.sound("ch4_hb_glitch", .1)

const BUBBLES := ["Ctrl+C и Ctrl+V — половина моей унылой работы", "Не забывай, что я написал всё, что тут есть", "Кликни, если сможешь!", "Эти штучки я называю своими лапочками", "W\nA\nS\nD\nЭто всё, что ты умеешь?", "Ctrl+Z\nЗапомни, а то забудешь\nНичего не было"]
const FLAVOR := ["* \"Нотч смеётся\"", "* \"Нотч что-то дописывает в воздухе\"", "* Чувствуется дискомфорт", "* «Ты меня ещё удивишь?»", "* \"Строки вокруг дрожат\""]
var ut_mode := "red"
var ut_vy := 0.0
var ut_jump_held := false
var ut_blasters: Array = []
var ut_bubble := ""
var ut_type := 0.0
var ut_slash := -1.0
var ut_number := 0
var ut_number_age := 9.0
var ut_box := MENU_BOX
var ut_box_to := MENU_BOX
var ut_grav := Vector2.DOWN
var ut_freeze := 0.0
var ut_hurt := 0.0
var ut_quake := 0.0
var ut_crit := false
var ut_hp_shown := UT_HP
var ut_sparks: Array = []
var ut_selects: Array = []
var ut_pattern := 0
var ut_slams := 0

func press(w, action: String):
	if phase == "qte":qte.press(action);return
	if phase in ["code", "erase"]:finale.press(action);return
	if phase == "fists":
		if fighter.state == "finisher" and action == "accept":fighter.finish_blow();return
		fighter.press({"accept":"punch", "kick":"kick", "grab":"grab"}.get(action, ""));return
	if phase == "lanes":lane_press(w, action);return
	if phase == "fighter":
		fighter.press({"accept":"punch", "kick":"kick", "special":"special", "grab":"grab", "super":"super"}.get(action, ""));return
	if phase != "ut":return
	ut_press(w, action)

func ut_press(w, action: String):
	var options: Array = menu_options()
	match ut_state:
		"menu":
			if action == "left":ut_choice = posmod(ut_choice - 1, options.size());w.sound("select", .02)
			elif action == "right":ut_choice = posmod(ut_choice + 1, options.size());w.sound("select", .02)
			elif action == "accept":choose(w, options[ut_choice])
		"bar":
			if action == "accept":strike(w)
		"text":
			if action == "accept":
				if ut_type < ut_text.length():ut_type = ut_text.length()
				elif ut_timer <= 0:begin_wave(w)
		"end":
			if action == "accept" and ut_type < ut_text.length():ut_type = ut_text.length()

func menu_options() -> Array:
	return ["fight", "act", "item"] if mercy_gone else ["fight", "act", "item", "mercy"]

func choose(w, option: String):
	w.sound("select", .02)
	match option:
		"fight":ut_state = "bar";bar = 0.0
		"act":show_text("* НОТЧ — АТК 99, ЗАЩ 99\n* Говорит, что написал тебя за выходные")
		"item":
			if ut_items > 0:
				ut_items -= 1;w.hp = minf(20.0, w.hp + 10.0);w.sound("pickup", .1)
				show_text("* Ты съел золотое яблоко\n* Восстановлено 10 HP")
			else:show_text("* В инвентаре пусто")
		"mercy":
			mercy_gone = true;ut_choice = 0
			show_text("* Нотч стирает кнопку ПОЩАДА")
			w.sound("ch4_hb_shatter", .1);w.shake = .2;ut_quake = .3

func show_text(text: String):
	ut_state = "text";ut_text = text;ut_timer = .25;ut_type = 0.0

func strike(w):
	var accuracy: float = clampf(1.0 - absf(bar - .5) * 2.0, 0, 1)
	ut_crit = accuracy > .93
	var damage: float = 8.0 + 26.0 * accuracy + (6.0 if ut_crit else 0.0)
	ut_hp -= damage;ut_hits += 1;ut_flash = .6;ut_slash = 0.0;ut_number = int(damage * 9.7);ut_number_age = -.35
	w.sound("swing", .02)
	ut_state = "slash";ut_timer = 1.5

## Edges travel to the next shape; the soul is pushed in with them.
func box_step(dt: float):
	var k: float = 1.0 - exp(-dt * 14.0)
	var a: Vector2 = ut_box.position.lerp(ut_box_to.position, k);var b: Vector2 = ut_box.end.lerp(ut_box_to.end, k)
	if a.distance_to(ut_box_to.position) < .5 and b.distance_to(ut_box_to.end) < .5:a = ut_box_to.position;b = ut_box_to.end
	ut_box = Rect2(a, b - a)

func box() -> Rect2:return ut_box_to

func begin_wave(w):
	ut_state = "wave";ut_timer = WAVE_LENGTH;ut_wave += 1;ut_serial2 = 0;ut_bullets.clear();ut_blasters.clear();ut_selects.clear()
	serial = 0;ut_vy = 0.0;ut_grav = Vector2.DOWN;ut_slams = 0
	ut_pattern = [0, 2, 1, 3, 4, 5, 6, 7][(ut_wave - 1) % 8]
	var spec: Array = PATTERNS[ut_pattern]
	ut_box_to = Rect2(UT_CENTER - spec[0] / 2.0, spec[0]).abs()
	ut_box_to.position = ut_box_to.position.floor()
	soul = ut_box_to.get_center() + (Vector2(0, ut_box_to.size.y / 2 - 6) if spec[1] == "blue" else Vector2.ZERO)
	ut_mode = spec[1]
	ut_bubble = BUBBLES[(ut_wave - 1) % BUBBLES.size()]
	if ut_mode == "blue":w.sound("ch4_hb_freeze", .1);ut_quake = .15

func battle(w, dt: float, movement: Vector2):
	ut_flash = maxf(0, ut_flash - dt);ut_number_age += dt;ut_hurt = maxf(0, ut_hurt - dt);ut_quake = maxf(0, ut_quake - dt)
	ut_hp_shown = move_toward(ut_hp_shown, ut_hp, dt * 60.0) if ut_number_age > 0 else ut_hp_shown
	if ut_slash >= 0:ut_slash += dt
	for i in range(ut_sparks.size() - 1, -1, -1):
		var s: Dictionary = ut_sparks[i];s.age += dt;s.p += s.v * dt;s.v *= .9
		if s.age > s.life:ut_sparks.remove_at(i)
	box_step(dt)
	# Hitstop: the world holds its breath for a few frames after a hit.
	if ut_freeze > 0:ut_freeze -= dt;return
	ut_timer -= dt
	if ut_state in ["text", "end", "menu"]:
		ut_box_to = MENU_BOX
		var before: int = int(ut_type)
		ut_type = minf(ut_text.length(), ut_type + dt * 32.0)
		if int(ut_type) != before and int(ut_type) % 2 == 0 and ut_text[int(ut_type) - 1] != " ":w.sound("ch4_hb_tick", .03)
	match ut_state:
		"bar":
			bar += dt / 1.05
			if bar > 1.05:
				ut_state = "miss";ut_timer = .8;ut_number_age = 0.0;ut_number = -1
		"slash", "miss":
			if ut_state == "slash" and ut_number_age >= 0 and ut_number_age - dt < 0:
				w.sound("ch4_punch_heavy", .02);w.sound("ch4_flesh_hit", .02);ut_quake = .25 if ut_crit else .14;ut_freeze = .08
				if ut_crit:w.sound("ch4_bone_crack", .05)
			if ut_timer <= 0:
				if ut_hp <= 0:
					ut_state = "end";ut_bullets.clear();ut_timer = 2.6;ut_text = "* …Ладно\nВ целом, мне всё понравилось";ut_type = 0.0
				else:show_text(FLAVOR[ut_hits % FLAVOR.size()])
		"wave":
			soul_move(w, movement, dt)
			var t: float = WAVE_LENGTH - ut_timer
			if t > .45:wave_bullets(w, dt)
			bullets_step(w, dt)
			selects_step(w, dt)
			for bl in ut_blasters:
				bl.age += dt
				var fire: float = bl.get("charge", .75)
				if bl.age < fire:bl.p = bl.p.lerp(bl.to, 1.0 - exp(-dt * 10.0))
				if bl.age > fire and bl.age < fire + .4:
					var d: Vector2 = Vector2.from_angle(bl.angle)
					var rel: Vector2 = soul - bl.p
					if rel.dot(d) > 0 and absf(rel.cross(d)) < bl.get("width", 11.0) * (1.0 - (bl.age - fire) / .55):hurt_soul(w, 3.0)
				if bl.age > fire and bl.age - dt <= fire:w.sound("ghast_intro_burst", .05);ut_quake = maxf(ut_quake, .12)
			ut_blasters = ut_blasters.filter(func(bl):return bl.age < bl.get("charge", .75) + .6)
			if ut_timer <= 0:
				ut_state = "menu";ut_bullets.clear();ut_blasters.clear();ut_selects.clear();ut_text = FLAVOR[ut_wave % FLAVOR.size()];ut_type = 0.0;ut_mode = "red";ut_grav = Vector2.DOWN
		"end":
			if ut_timer <= 0:
				if ut_clean:w.run_progress.award("heart_whole")
				ut_clean = false
				change("to_lanes")
	if w.hp <= 0:lose(w, "ut")

func bullets_step(w, dt: float):
	var bx: Rect2 = ut_box
	var spawned: Array = []
	for b in ut_bullets:
		b.age = float(b.get("age", 0.0)) + dt
		if b.has("delay"):
			if b.age < b.delay:continue
			b.v = Vector2(0, b.drop);b.erase("delay")
		if b.has("fuse") and b.age >= b.fuse and not b.get("done", false):
			b.done = true;w.sound("explosion", .05);w.shake = .1;ut_quake = maxf(ut_quake, .2)
			burst(b.p, Color(1, .6, .2), 14, 140.0)
			spawned.append({"p":Vector2(bx.get_center().x, b.p.y), "v":Vector2.ZERO, "size":Vector2(bx.size.x, 12), "shape":"fire", "life":.4})
			spawned.append({"p":Vector2(b.p.x, bx.get_center().y), "v":Vector2.ZERO, "size":Vector2(12, bx.size.y), "shape":"fire", "life":.4})
			b.p.y = -999.0;continue
		if b.has("life") and b.age > b.life:b.p.y = -999.0;continue
		if b.get("shape", "") == "spike":
			# Rises out of the wall the soul was thrown against, then sinks back.
			var up: float = smoothstep(b.warn, b.warn + .08, b.age) * (1.0 - smoothstep(b.warn + .42, b.warn + .55, b.age))
			b.rise = up
			if b.age > b.warn + .6:b.p.y = -999.0
			if up > .5 and spike_rect(b).grow(-1).has_point(soul):hurt_soul(w)
			continue
		if b.get("gravity", false):
			b.v.y += 300.0 * dt
			if b.p.y > bx.end.y - 6 and b.v.y > 0:b.v.y = -b.v.y * .7
		if b.get("shape", "") == "anvil" and not b.get("landed", false) and b.p.y >= bx.end.y - 8:
			b.landed = true;b.v = Vector2.ZERO;b.p.y = bx.end.y - 8;b.life = b.age + .5
			w.sound("ch4_heavy", .05);ut_quake = maxf(ut_quake, .12);burst(b.p + Vector2(0, 6), Color(.8, .8, .8), 8, 90.0)
		b.p += b.v * dt
		var hit: bool
		if b.has("size"):hit = Rect2(b.p - b.size / 2.0, b.size).grow(-1).has_point(soul)
		else:hit = b.p.distance_to(soul) < float(b.get("r", 4.0))
		if hit and not b.get("safe", false):hurt_soul(w)
	ut_bullets.append_array(spawned)
	ut_bullets = ut_bullets.filter(func(b):return Rect2(bx.position - Vector2(90, 90), bx.size + Vector2(180, 180)).has_point(b.p))

func spike_rect(b: Dictionary) -> Rect2:
	var h: float = 18.0 * float(b.get("rise", 0.0))
	var bx: Rect2 = ut_box
	match b.wall:
		"down":return Rect2(Vector2(b.p.x - b.size / 2, bx.end.y - h), Vector2(b.size, h))
		"up":return Rect2(Vector2(b.p.x - b.size / 2, bx.position.y), Vector2(b.size, h))
		"left":return Rect2(Vector2(bx.position.x, b.p.y - b.size / 2), Vector2(h, b.size))
		_:return Rect2(Vector2(bx.end.x - h, b.p.y - b.size / 2), Vector2(h, b.size))

## A drag-selection: the cursor pulls a rectangle open, it holds, then Delete
## wipes everything inside. Stand outside the blue rectangle.
func selects_step(w, dt: float):
	for s in ut_selects:
		var before: float = s.age;s.age += dt
		if before < s.drag + s.hold and s.age >= s.drag + s.hold:w.sound("ch4_hb_shatter", .05);ut_quake = maxf(ut_quake, .1);s.shards = true
		if before < s.drag and s.age >= s.drag:w.sound("select", .05)
		if s.age >= s.drag + s.hold and s.age < s.drag + s.hold + .22 and s.rect.grow(-2).has_point(soul):hurt_soul(w, 3.0)
	ut_selects = ut_selects.filter(func(s):return s.age < s.drag + s.hold + .5)

func burst(at: Vector2, col: Color, count: int, speed: float):
	for k in range(count):
		var a: float = k * 2.39996 + at.x
		ut_sparks.append({"p":at, "v":Vector2.from_angle(a) * speed * (.4 + .6 * fposmod(k * .618, 1.0)), "age":0.0, "life":.35 + fposmod(k * .37, .3), "col":col})

func hurt_soul(w, amount := 2.0):
	if w.invulnerable > 0:return
	ut_clean = false
	w.hp -= amount;w.invulnerable = 1.0;w.sound("hurt", .05);w.sound("ch4_flesh_hit", .05)
	ut_freeze = .07;ut_hurt = .35;ut_quake = maxf(ut_quake, .18)
	burst(soul, Color(1, .15, .2), 10, 120.0)

func soul_move(w, movement: Vector2, dt: float):
	var bx: Rect2 = ut_box
	var lo: Vector2 = bx.position + Vector2(6, 6);var hi: Vector2 = bx.end - Vector2(6, 6)
	if ut_mode == "red":
		soul = (soul + movement.limit_length() * 128.0 * dt).clamp(lo, hi)
		return
	# Blue: weight towards ut_grav, jump against it, slide along the wall.
	var side: Vector2 = Vector2(absf(ut_grav.y), absf(ut_grav.x))
	soul += side * movement * 120.0 * dt
	var against: float = -movement.dot(ut_grav)
	var floor_hit: bool = false
	var grounded: bool = (ut_grav.y > 0 and soul.y >= hi.y - .5) or (ut_grav.y < 0 and soul.y <= lo.y + .5) or (ut_grav.x > 0 and soul.x >= hi.x - .5) or (ut_grav.x < 0 and soul.x <= lo.x + .5)
	if against > .5 and grounded and not ut_jump_held:ut_vy = -230.0
	if against <= .5 and ut_vy < -70.0:ut_vy = -70.0
	ut_jump_held = against > .5
	var fall_before: float = ut_vy
	ut_vy += (620.0 if ut_vy < 300 else 2400.0) * dt
	soul += ut_grav * ut_vy * dt
	var clamped: Vector2 = soul.clamp(lo, hi)
	if clamped != soul and ut_vy > 0:floor_hit = true
	soul = clamped
	if floor_hit:
		if fall_before > 380.0:
			# Thrown into the wall: a heavy thud.
			w.sound("ch4_ground_slam", .05);w.shake = .15;ut_quake = .28;burst(soul + ut_grav * 6.0, Color(.4, .6, 1), 12, 110.0)
		ut_vy = 0.0

func wave_bullets(w, dt: float):
	var t: float = WAVE_LENGTH - ut_timer - .45
	var every: float = PATTERNS[ut_pattern][2] * (.9 if ut_wave > 8 else 1.0)
	var due: int = int(t / every) + 1
	while serial < due:
		serial += 1
		spawn_pattern(w, ut_pattern, serial)
	if ut_wave >= 4 and SECOND.has(ut_pattern):
		var second: int = SECOND[ut_pattern]
		var every2: float = PATTERNS[second][2] * 1.9
		var due2: int = int(maxf(0.0, t - 1.0) / every2)
		while ut_serial2 < due2:
			ut_serial2 += 1
			spawn_pattern(w, second, ut_serial2 + 100)

func spawn_pattern(w, pattern: int, n: int):
	var bx: Rect2 = box()
	var n0: int = ut_bullets.size()
	spawn_shapes(w, pattern, n, bx)
	for i in range(n0, ut_bullets.size()):ut_bullets[i].age = 0.0

func spawn_shapes(w, pattern: int, n: int, bx: Rect2):
	match pattern:
		0:
			# A tunnel of cobblestone that snakes; follow the gap.
			var tt: float = n * .08
			var gap: float = bx.get_center().y + (sin(tt * 1.9) * .3 + sin(tt * 4.7) * .08) * bx.size.y
			for y in range(int(bx.position.y) + 6, int(bx.end.y), 12):
				if absf(y - gap) > 21:ut_bullets.append({"p":Vector2(bx.end.x + 8, y), "v":Vector2(-150, 0), "size":Vector2(12, 12), "shape":"block"})
		1:
			# Blue soul: fence posts slide along the floor; jump them.
			var tall: float = [14.0, 22.0, 14.0, 30.0][n % 4]
			var from_right: bool = n % 2 == 0
			ut_bullets.append({"p":Vector2(bx.end.x + 6 if from_right else bx.position.x - 6, bx.end.y - tall / 2.0), "v":Vector2(-150 if from_right else 150, 0), "size":Vector2(8, tall), "shape":"fence"})
			if n % 3 == 0:ut_bullets.append({"p":Vector2(bx.end.x + 6, bx.position.y + 24), "v":Vector2(-170, 0), "size":Vector2(8, 46), "shape":"fence", "top":true})
		2:
			# Drag-select + Delete. One rectangle over the soul, one elsewhere.
			var cell: Vector2 = (bx.size * Vector2(.55, .6)).floor()
			var anchor: Vector2 = (soul - cell * Vector2(fposmod(n * .37, 1.0) * .6 + .2, fposmod(n * .61, 1.0) * .6 + .2)).clamp(bx.position, bx.end - cell)
			var from: int = n % 4
			ut_selects.append({"rect":Rect2(anchor, cell).abs(), "corner":from, "age":0.0, "drag":.55, "hold":.4})
			if n % 2 == 0:
				var other := Rect2(Vector2(bx.end.x - anchor.x - cell.x + bx.position.x, anchor.y), cell)
				ut_selects.append({"rect":other, "corner":(from + 2) % 4, "age":-.15, "drag":.55, "hold":.4})
		3:
			# Ghast blasters slide in, open, fire through where the soul is.
			var side: int = n % 4
			var at: Vector2
			match side:
				0:at = Vector2(bx.position.x - 30, soul.y)
				1:at = Vector2(bx.end.x + 30, bx.position.y + fposmod(n * 37.0, bx.size.y))
				2:at = Vector2(soul.x, bx.position.y - 30)
				_:at = Vector2(bx.position.x + fposmod(n * 41.0, bx.size.x), bx.end.y + 30)
			var aim: Vector2 = soul + Vector2(sin(n * 1.7), cos(n * 1.3)) * 8.0
			var ang: float = at.direction_to(aim).angle()
			ut_blasters.append({"p":at - Vector2.from_angle(ang) * 90.0, "to":at, "angle":ang, "age":0.0, "charge":.7, "width":11.0 if n % 5 else 18.0})
			w.sound("ghast_intro_charge", .1)
		4:
			var key: String = ["W", "A", "S", "D"][n % 4]
			ut_bullets.append({"p":Vector2(bx.position.x + 10 + fposmod(n * 47.0, bx.size.x - 20), bx.position.y - 4), "v":Vector2(sin(n) * 40.0, 50.0), "gravity":true, "size":Vector2(12, 12), "shape":"key", "glyph":key})
		5:
			# Notch grabs the soul and slams it into a wall; spikes follow.
			var walls := ["down", "left", "up", "right", "down", "right"]
			var wall: String = walls[ut_slams % walls.size()];ut_slams += 1
			ut_grav = {"down":Vector2.DOWN, "up":Vector2.UP, "left":Vector2.LEFT, "right":Vector2.RIGHT}[wall]
			ut_vy = 520.0
			set_pose("throw");w.sound("ch4_hb_twitch", .05)
			var along: float = bx.size.x if wall in ["down", "up"] else bx.size.y
			var count: int = int(along / 10.0)
			for k in range(count):
				var off: float = 5.0 + k * 10.0
				var p: Vector2 = Vector2(bx.position.x + off, bx.end.y) if wall in ["down", "up"] else Vector2(bx.position.x, bx.position.y + off)
				ut_bullets.append({"p":p, "v":Vector2.ZERO, "shape":"spike", "wall":wall, "size":10.0, "warn":.5, "rise":0.0, "safe":true})
		6:
			# Anvils: a warning column, then a fast drop and a clang.
			var ax: float = bx.position.x + 12 + fposmod(n * 53.0 + soul.x * .5, bx.size.x - 24)
			if n % 3 == 0:ax = clampf(soul.x, bx.position.x + 12, bx.end.x - 12)
			ut_bullets.append({"p":Vector2(ax, bx.position.y - 14), "v":Vector2.ZERO, "size":Vector2(18, 16), "shape":"anvil", "delay":.5, "drop":420.0})
		7:
			# TNT on a grid point, then a cross of fire through the box.
			var at := Vector2(bx.position.x + 20 + fposmod(n * 61.0, bx.size.x - 40), bx.position.y + 20 + fposmod(n * 37.0, bx.size.y - 40))
			if n % 3 == 0:at = soul.clamp(bx.position + Vector2(14, 14), bx.end - Vector2(14, 14))
			ut_bullets.append({"p":at, "v":Vector2.ZERO, "size":Vector2(14, 14), "shape":"tnt", "fuse":.85, "safe":true})

# ------------------------------------------------------------------ the lanes

func start_lanes(w):
	clear_arena(w)
	change("lanes");cursor_dir=Vector2i.ZERO;cursor_wait=0;plants.clear();zombies.clear();arrows.clear();blasts.clear();bone_arrows.clear()
	redstone = 150;card = 0;cursor = Vector2i(2, 2);card_ready = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];trickle = 4.0;lane_age = 0.0;serial = 0
	drops.clear();corpses.clear();carts.clear()
	for r in range(ROWS):carts.append({"state":"ready", "x":LANE_ORIGIN.x - 22})
	schedule = []
	var t := 8.0
	for k in range(36):
		var kind: String = "zombie"
		if k > 3 and k % 5 == 4:kind = "baby"
		if k > 6 and k % 6 == 1:kind = "elite"
		if k > 8 and k % 7 == 2:kind = "spider"
		if k > 10 and k % 6 == 3:kind = "glitch"
		if k > 12 and k % 8 == 5:kind = "slime"
		if k > 14 and k % 7 == 6:kind = "creeper"
		if k > 16 and k % 9 == 0:kind = "skeleton"
		if k > 19 and k % 8 == 7:kind = "vindicator"
		schedule.append({"at":t, "row":(k * 3 + k / 5) % ROWS, "kind":kind})
		t += maxf(1.4, 5.5 - k * .14)
		if k in [16, 28]:
			for extra in range(5):schedule.append({"at":t + extra * .5, "row":(extra * 2 + k) % ROWS, "kind":["zombie", "glitch", "baby", "spider", "vindicator"][extra]})
			t += 6.0
	# The last wave brings the ravager down the middle.
	schedule.append({"at":t + 2.0, "row":2, "kind":"ravager"})
	for extra in range(4):schedule.append({"at":t + 3.0 + extra * .6, "row":[0, 4, 1, 3][extra], "kind":["elite", "skeleton", "slime", "baby"][extra]})
	lane_total = schedule.size()
	say("Всегда любил играть за атаку!", 2.0)

func cell_rect(c: Vector2i) -> Rect2:
	return Rect2(LANE_ORIGIN + Vector2(c.x, c.y) * CELL, CELL)

func lane_press(w, action: String):
	if action in ["left","right","up","down"]:cursor_wait=.32
	match action:
		"left":cursor.x = maxi(0, cursor.x - 1)
		"right":cursor.x = mini(COLS - 1, cursor.x + 1)
		"up":cursor.y = maxi(0, cursor.y - 1)
		"down":cursor.y = mini(ROWS - 1, cursor.y + 1)
		"accept":place(w)
		"1", "2", "3", "4", "5", "6", "7", "8":card = int(action) - 1

func click(w, at: Vector2) -> bool:
	if phase == "qte":qte.press("accept");return true
	if phase == "fighter":fighter.press("punch");return true
	if phase == "fists":
		if fighter.state == "finisher":fighter.finish_blow()
		else:fighter.press("punch")
		return true
	if phase == "code" and finale.phase == "duel" and finale.advanced and Rect2(520, 326, 100, 22).has_point(at):finale.key("run");return true
	if phase == "quake":return true
	if phase == "ut":
		for i in range(menu_options().size()):
			if menu_rect(i).has_point(at):
				ut_choice = i;press(w, "accept");return true
		if ut_state in ["bar", "text"]:press(w, "accept");return true
		return false
	if phase != "lanes":return false
	for i in range(CARDS.size()):
		if card_rect(i).has_point(at):card = i;return true
	for d in drops:
		if d.p.distance_to(at) < 14 and not d.taken:collect(w, d);return true
	var rel: Vector2 = (at - LANE_ORIGIN) / CELL
	if rel.x >= 0 and rel.y >= 0 and rel.x < COLS and rel.y < ROWS:
		cursor = Vector2i(int(rel.x), int(rel.y));place(w);return true
	return false

static func menu_rect(i: int) -> Rect2:return Rect2(40 + i * 142, 308, 132, 26)
static func card_rect(i: int) -> Rect2:return Rect2(108 + i * 46, 40, 42, 46)

func collect(w, d: Dictionary):
	d.taken = true;d.age = 0.0;redstone += int(d.value)
	w.sound("pickup", .03)

func drop_at(from: Vector2, land_y: float, value := 25):
	drops.append({"p":from, "land":land_y, "vy":0.0 if from.y < land_y - 20 else -60.0, "life":0.0, "value":value, "taken":false, "age":0.0, "fall":from.y < land_y - 20})

func place(w):
	var spec: Array = CARDS[card]
	if plants.has(cursor) or redstone < int(spec[1]) or card_ready[card] > 0:
		w.sound("ch4_punch_miss", .05);return
	redstone -= int(spec[1]);card_ready[card] = float(spec[2])
	plants[cursor] = {"kind":spec[0], "hp":PLANT_HP[spec[0]], "timer":1.0 if spec[0] == "tnt" else (.6 if spec[0] == "piston" else 1.5), "age":0.0, "push":0.0}
	w.sound("ch1_wood_place", .05)

func lanes(w, dt: float, movement: Vector2):
	lane_age += dt
	# Keydown owns the first step; held input only repeats after a full delay.
	var direction := Vector2i.ZERO
	if movement.length_squared()>.2:
		direction=Vector2i(signi(int(movement.x)),0) if absf(movement.x)>absf(movement.y) else Vector2i(0,signi(int(movement.y)))
	if direction==Vector2i.ZERO:cursor_dir=Vector2i.ZERO;cursor_wait=0
	elif direction!=cursor_dir:
		if cursor_dir==Vector2i.ZERO and cursor_wait<=0:cursor=(cursor+direction).clamp(Vector2i.ZERO,Vector2i(COLS-1,ROWS-1))
		cursor_dir=direction;cursor_wait=.32
	else:
		cursor_wait-=dt
		if cursor_wait<=0:cursor=(cursor+direction).clamp(Vector2i.ZERO,Vector2i(COLS-1,ROWS-1));cursor_wait=.16
	for i in range(card_ready.size()):card_ready[i] = maxf(0, card_ready[i] - dt)
	trickle -= dt
	if trickle <= 0:
		trickle = 7.0
		var lane: int = (serial * 3 + int(lane_age)) % ROWS;serial += 1
		drop_at(Vector2(LANE_ORIGIN.x + 26 + fposmod(lane_age * 53.0, COLS * CELL.x - 52), 20), row_y(lane) + 6)
	for d in drops:
		if d.taken:
			d.age += dt;d.p = d.p.lerp(Vector2(58, 62), minf(1.0, dt * 8.0));continue
		d.life += dt
		if d.fall:
			d.p.y = minf(d.land, d.p.y + 55.0 * dt)
		else:
			d.vy += 200.0 * dt;d.p.y = minf(d.land, d.p.y + d.vy * dt);d.p.x += 14.0 * dt * (1.0 if d.vy < 0 else 0.0)
		if cell_rect(cursor).has_point(d.p) or d.life > 9.0:collect(w, d)
	drops = drops.filter(func(d):return not d.taken or d.age < .5)
	while not schedule.is_empty() and lane_age >= schedule[0].at:
		var s: Dictionary = schedule.pop_front()
		var spec: Array = ZOMBIES[s.kind]
		spawn_walker(w, s.kind, s.row, LANE_ORIGIN.x + COLS * CELL.x + 20)
		set_pose("throw")
		if s.kind == "ravager":say("А вот и тяжёлая артиллерия!", 2.0);w.sound("ch4_heavy", .05)
	for c in plants.keys():
		var pl: Dictionary = plants[c]
		pl.age += dt;pl.timer -= dt;pl.push = maxf(0, float(pl.get("push", 0.0)) - dt)
		var center: Vector2 = cell_rect(c).get_center()
		match pl.kind:
			"dispenser", "snow_golem":
				if pl.timer <= 0 and zombies.any(func(z):return z.row == c.y and z.x > cell_rect(c).position.x):
					pl.timer = 1.5 if pl.kind == "dispenser" else 1.8
					arrows.append({"row":c.y, "x":center.x, "snow":pl.kind == "snow_golem"})
					w.sound("arrow" if pl.kind == "dispenser" else "ch1_whoosh", .05)
			"redstone_ore":
				if pl.timer <= 0:
					pl.timer = 8.0
					drop_at(center - Vector2(0, 6), center.y + 10);pl.pulse = 0.4
			"tnt":
				if pl.timer <= 0:
					blasts.append({"p":center, "age":0.0})
					for z in zombies:
						if absi(z.row - c.y) <= 1 and absf(z.x - center.x) < CELL.x * 1.6:z.hp -= 30.0
					plants.erase(c);w.sound("explosion", .05);w.shake = .2
			"piston":
				if pl.timer <= 0:
					for z in zombies:
						var dx: float = z.x - center.x
						if z.row == c.y and dx > -6 and dx < CELL.x * 1.3 and z.hp > 0 and not z.get("air", false):
							z.x += CELL.x * (1.6 if z.kind != "ravager" else .4);z.hp -= 2.0;z.flash = .1
							pl.timer = 3.0;pl.push = .3;w.sound("ch4_stone_rise", .08)
			"magma":
				for z in zombies:
					if z.row == c.y and absf(z.x - center.x) < CELL.x * .5 and not z.get("air", false):
						z.hp -= 4.0 * dt;z.burn = .3
	for i in range(arrows.size() - 1, -1, -1):
		var a: Dictionary = arrows[i]
		a.x += 170.0 * dt
		var hit := false
		for z in zombies:
			if z.row == a.row and absf(z.x - a.x) < 8 and z.hp > 0 and not z.get("air", false):
				z.hp -= 2.0 if not a.get("snow", false) else 1.5;z.flash = .08;hit = true
				if a.get("snow", false):z.slow = 3.0
				break
		if hit or a.x > 640:arrows.remove_at(i)
	for i in range(bone_arrows.size() - 1, -1, -1):
		var b: Dictionary = bone_arrows[i]
		b.x -= 150.0 * dt
		var col: int = int((b.x - LANE_ORIGIN.x) / CELL.x)
		var cell := Vector2i(col, b.row)
		if plants.has(cell) and plants[cell].kind not in FLAT:
			plants[cell].hp -= 1.0;w.sound("ch4_flesh_hit", .1)
			if plants[cell].hp <= 0:plants.erase(cell)
			bone_arrows.remove_at(i)
		elif b.x < LANE_ORIGIN.x:bone_arrows.remove_at(i)
	for i in range(zombies.size() - 1, -1, -1):
		var z: Dictionary = zombies[i]
		z.age += dt;z.flash = maxf(0, z.flash - dt);z.bite = maxf(0, z.bite - dt);z.slow = maxf(0, float(z.get("slow", 0.0)) - dt);z.burn = maxf(0, float(z.get("burn", 0.0)) - dt)
		if z.hp <= 0:
			corpses.append({"kind":z.kind, "row":z.row, "x":z.x, "age":0.0});zombies.remove_at(i)
			if z.kind == "slime":
				for k in [-10, 10]:spawn_walker(w, "small_slime", z.row, z.x + k)
			if z.kind == "ravager":blasts.append({"p":Vector2(z.x, row_y(z.row)), "age":0.0});w.sound("explosion", .05);w.shake = .3
			continue
		var speed: float = z.speed * (.5 if z.slow > 0 else 1.0)
		# The spider leaps over the first block in its way.
		if z.get("air", false):
			z.jump += dt
			z.x -= CELL.x * 1.4 * dt / .55
			if z.jump >= .55:z.air = false
			z.visual.gait += speed * dt / 30.0
			w.animation.set_pose(z.visual, "walk", z.visual.gait)
			continue
		var col: int = int((z.x - 10 - LANE_ORIGIN.x) / CELL.x)
		var target := Vector2i(col, z.row)
		var blocked: bool = col >= 0 and col < COLS and plants.has(target) and plants[target].kind not in FLAT and z.x - cell_rect(target).get_center().x < 22
		if z.kind == "skeleton" and col < COLS - 2 and not blocked:
			z.moving = false;z.shot = float(z.get("shot", 1.0)) - dt
			if z.shot <= 0 and plants.keys().any(func(pc):return pc.y == z.row and pc.x < col + 1 and plants[pc].kind not in FLAT):
				z.shot = 2.4;bone_arrows.append({"row":z.row, "x":z.x - 8});w.sound("arrow", .05)
			elif not plants.keys().any(func(pc):return pc.y == z.row and pc.x <= col):
				z.moving = true;z.x -= speed * dt
		elif blocked:
			z.moving = false
			if z.kind == "spider" and not z.get("leapt", false):
				z.leapt = true;z.air = true;z.jump = 0.0;w.sound("ch1_whoosh", .05)
			elif z.kind == "creeper":
				plants.erase(target);blasts.append({"p":Vector2(z.x, row_y(z.row)), "age":0.0});z.hp = 0;w.sound("explosion", .05)
			elif z.kind == "ravager":
				plants.erase(target);z.flash = .1;w.sound("ch4_heavy", .05);w.shake = .2
			elif z.bite <= 0:
				z.bite = .7 if z.kind == "vindicator" else .5
				var pl: Dictionary = plants[target]
				pl.hp -= 3.0 if z.kind == "vindicator" else 1.0;w.sound("ch4_flesh_hit", .1)
				if pl.kind == "cactus":z.hp -= 1.5;z.flash = .08
				if pl.hp <= 0:plants.erase(target)
		else:
			z.moving = true;z.x -= speed * dt
		z.visual.gait += speed * dt / 30.0
		w.animation.set_pose(z.visual, "walk" if z.moving else "attack", z.visual.gait if z.moving else fposmod(z.age, .3))
		if z.x < LANE_ORIGIN.x - 6:
			var cart: Dictionary = carts[z.row]
			if cart.state == "ready":
				cart.state = "run";w.sound("ch4_heavy", .1)
			elif cart.state == "used" and z.x < LANE_ORIGIN.x - 40:
				say("1 мозг тебе или 2 мозга мне?", 1.6);lose(w, "lanes");return
	for r in range(carts.size()):
		var cart: Dictionary = carts[r]
		if cart.state != "run":continue
		cart.x += 260.0 * dt
		for z in zombies:
			if z.row == r and absf(z.x - cart.x) < 18 and z.hp > 0:z.hp = 0.0;z.flash = .2
		if cart.x > 660:cart.state = "used"
	for cp in corpses:cp.age += dt
	corpses = corpses.filter(func(cp):return cp.age < 1.2)
	for b in blasts:b.age += dt
	blasts = blasts.filter(func(b):return b.age < 1.3)
	if schedule.is_empty() and zombies.is_empty():change("lanes_won")

## Contacts of the portal shoves; the view freezes on each for a hit-stop.
const PORTAL_HITS := [.89, 1.80]
const PORTAL_HOLD := .11

## Sounds of a passage between games: the portal opens, a shove, one pulled in, the other jumps.
## Each contact is layered: wind-up whoosh, the fist, flesh, bone, and a low thump.
func portal_sounds(w, dt := 1.0 / 60):
	shake3d = maxf(0, shake3d - dt * 1.4)
	if cue(8, .72):w.sound("ch1_whoosh", .04)
	if cue(9, 1.63):w.sound("ch1_whoosh", .04)
	if cue(6, PORTAL_HITS[0]):
		for id in ["ch4_punch_heavy", "ch4_flesh_hit", "ch4_bone_crack"]:w.sound(id, .03)
		shake3d = .55
	if cue(7, PORTAL_HITS[1]):
		for id in ["ch4_punch_heavy", "ch4_bone_crack", "ch4_flesh_hit", "ch4_hb_shatter", "explosion"]:w.sound(id, .03)
		shake3d = .8
	if cue(1, .2):w.sound("ch5_portal_open", .02)
	if cue(2, 1.0):w.sound("ch1_whoosh", .05)
	if cue(3, 2.0):w.sound("ch4_body_fall", .05)
	if cue(4, 2.4):w.sound("ch5_portal_pass", .02)
	if cue(5, 3.5):w.sound("ch5_portal_pass", .02);w.sound("wind_burst", .05)

func row_y(row: int) -> float:return LANE_ORIGIN.y + (row + .5) * CELL.y

func spawn_walker(w, kind: String, row: int, x: float):
	var spec: Array = ZOMBIES[kind]
	zombies.append({"kind":kind, "row":row, "x":x, "hp":spec[0], "max":spec[0], "speed":spec[1], "bite":0.0, "flash":0.0, "visual":w.animation.actor(), "age":0.0, "slow":0.0, "burn":0.0})

# ------------------------------------------------------------------ 3D: the fighting game

func start_fighter(w):
	clear_arena(w)
	fighter.reset();change("fighter")
	say("Давно мечтал устроить с кем-то мордобой", 2.0)

func fight_sounds(w, events: Array):
	for e in events:
		match e:
			"jump":w.sound("ch4_punch_miss", .1)
			"throw_tnt":w.sound("ch1_whoosh", .05)
			"boom":w.sound("explosion", .03);shake3d = .35
			"shield":w.sound("shield_block", .1)
			"parry":w.sound("shield_block", .02);w.sound("ch4_bell", .05);shake3d = .3
			"finish_him":w.sound("ch4_bell_warn", .02)
			"fatality_start":w.sound("ch4_hb_tick", .02)
			"lightning":w.sound("ch4_hb_lightning", .02);w.sound("lightning", .02);shake3d = .5
			"fatality_boom":w.sound("explosion", .02);w.sound("ch4_hb_shatter", .02);shake3d = .6
			"fatality":w.sound("ch4_totem", .02);w.run_progress.award("fatality")
			"pearl":w.sound("pearl_throw", .1);w.sound("end_teleport", .1)
			"beam":w.sound("ch4_hb_beam", .1)
			"throw":w.sound("ch4_body_fall", .05);shake3d = .25
			"super_steve":w.sound("ch4_heavy", .05);w.sound("level", .05)
			"super_notch":w.sound("ch4_hb_roar", .05)
			"undo":w.sound("ch4_hb_teleport", .05)
			"combo":w.sound("ch4_hb_tick", .1)
			"getup":w.sound("ch4_punch_miss", .1)

func fight3d(w, dt: float, movement: Vector2):
	var events: Array = fighter.step(dt, movement)
	fight_sounds(w, events)
	for e in events:
		match e:
			"hit":w.sound("ch4_punch", .03);shake3d = .1
			"hit_heavy":w.sound("ch4_punch_heavy", .03);shake3d = .2
			"block":w.sound("shield_block", .03)
			"cast_steve":w.sound("ch4_hb_tick", .05)
			"cast_notch":w.sound("ch4_hb_beam", .05)
			"teleport":w.sound("ch4_hb_teleport", .05)
			"ko":w.sound("ch4_hb_shatter", .05);shake3d = .4
			"thud":w.sound("ch4_body_fall", .05)
	shake3d = maxf(0, shake3d - dt)
	if fighter.state == "done":
		if fighter.winner == 0:change("to_quake")
		else:lose(w, "fighter")

# ------------------------------------------------------------------ 3D: the arena

func start_quake(w):
	clear_arena(w)
	quake.reset();change("quake")
	quake_input = {"wish":Vector2.ZERO, "turn":Vector2.ZERO, "fire":false, "jump":false}

func deathmatch(w, dt: float):
	var input: Dictionary = quake_input
	quake.step(dt, input.wish, input.turn, input.fire, input.jump, input.get("weapon", ""))
	quake_input.turn = Vector2.ZERO;quake_input.weapon = ""
	for id in quake.sounds:
		match id:
			"rocket":w.sound("rocket_launch", .05)
			"switch":w.sound("ch4_reload", .05)
			"swing", "nswing":w.sound("swing", .05)
			"charge", "ncharge":w.sound("fire", .04)
			"bolt":w.sound("arrow", .05);w.sound("ch4_hb_beam", .05)
			"hitmark":w.sound("ch4_hb_tick", .04)
			"boom":w.sound("explosion", .03)
			"gib":w.sound("ch4_flesh_hit", .05)
			"pad":w.sound("wind_burst", .1)
			"spawn":w.sound("ch4_hb_teleport", .1)
			_:
				if id.begins_with("pickup"):w.sound("pickup", .05)
	if quake.state == "won":change("quake_won")
	elif quake.state == "lost":lose(w, "quake")

# ------------------------------------------------------------------ the end

func start_code(w, keep_choice := false):
	clear_arena(w)
	change("code")
	if keep_choice:finale.start_duel()
	else:finale.reset();finale.begin_pick()

func code(w, dt: float):
	var r: String = finale.step(dt)
	finale_sounds(w, r)
	if r == "won":
		if finale.submissions==1 and finale.penalty<=0:w.run_progress.award("first_compile")
		finale.begin_erase();change("erase")
	elif r == "lost":
		say("Я какой-то сонный сегодня, не находишь это странным?", 2.0);lose(w, "code")

func finale_sounds(w, _r: String):
	for id in finale.sounds:
		match id:
			"type":w.sound("ch4_hb_tick", .02)
			"wrong":w.sound("ch4_punch_miss", .05)
			"win":w.sound("level", .1)
			"resist":w.sound("ch4_heartbeat", .08)
			"glitch":w.sound("ch4_hb_glitch", .1)
			"throw":w.sound("ch4_breath", .1);w.sound("ch4_hb_charge", .1)
			"whip":w.sound("ch1_whoosh", .05);w.sound("ch4_heavy", .05)
			"console":w.sound("ch4_hb_shatter", .05);w.sound("explosion", .05);w.sound("ch5_shockwave", .05);w.sound("ch4_impact", .05)
			"scan":w.sound("ch4_hb_pulse", .1)
			"draw":w.sound("ch4_heavy", .1)
			"stab":w.sound("ch4_flesh_hit", .05);w.sound("ch4_bone_crack", .05)
			"door":w.sound("ch4_door_open", .1)
			"theme":w.sound("ch5_ending_theme", .1)
			"fade":w.sound("ch5_ending_fade", .1)
			"arrive":w.sound("ch4_hb_teleport", .1)
			"sting":w.sound("ch5_ending_sting", .1)
			"credits":w.sound("ch5_credits", .1)
	finale.sounds.clear()
	if finale.line.is_empty():mirrored = ""
	elif finale.line != mirrored:mirrored = finale.line;say(finale.line, finale.line_length)

func begin_bad_end(w):
	bad_from_qte=phase=="qte"
	bad_blood=minf(.65,.15+qte.beat*.055) if bad_from_qte else 0.0
	bad_entry_track=qte.TRACKS[mini(qte.beat,7)] if qte.success else "miss"
	finale.change("bad_end");change("bad_end");line="";line_length=0;line_queue.clear()

func start_qte(w):
	clear_arena(w);qte.reset();change("qte");say("Чёртов ублюдок, игры кончились",1.5)

func start_fists(w):
	clear_arena(w)
	fighter.reset("fists");change("fists")
	say("Отсюда выйдет только один!", 2.0)

func fists(w, dt: float, movement: Vector2):
	var events: Array = fighter.step(dt, movement)
	fight_sounds(w, events)
	if "wire" in events:fighter.say("ФАТАЛИТИ")
	for e in events:
		match e:
			"hit":w.sound("ch4_punch", .03);shake3d = .1
			"hit_heavy":w.sound("ch4_punch_heavy", .03);shake3d = .2
			"block":w.sound("shield_block", .03)
			"grab":w.sound("ch4_hb_tick", .05)
			"finisher":w.sound("ch4_heartbeat", .1)
			"wire":w.sound("ch4_flesh_hit", .05);w.sound("ch4_hb_shatter", .05);shake3d = .4
	shake3d = maxf(0, shake3d - dt)
	if fighter.state == "done":
		if fighter.winner == 0:finale.change("chair");change("chair")
		else:lose(w, "fists")
