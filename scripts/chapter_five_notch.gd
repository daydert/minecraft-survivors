extends RefCounted
## Notch, at 12:00. A talk, a fight in the code space, then his games:
## an Undertale-style battle box and a lane defence where he plays the
## zombies. Each phase restarts from its own checkpoint.
const CENTER := Vector2(1024, 1024)
const INTRO := [[0.6, "Ооо, ты всё-таки дошёл?", 2.6], [3.4, "Знаешь, я запускал тебе подобных столько раз, что уже и не знаю, какая это итерация", 3.6],
	[7.2, "Интересно, понравилось ли оцифрованной душе моего брата впервые так жалко подохнуть?\nЭто ещё глупее, чем упасть в зерно и задохнуться", 3.2], [10.6, "ЗДЕСЬ Я ХОЗЯИН\nЯ ТЕБЯ ПОРОДИЛ, Я ТЕБЯ И УНИЧТОЖУ", 3.0],
	[13.8, "Спросишь, зачем это всё? Ну, мне было скучно, да и личный уголок для моего брата-садиста сам себя бы не создал", 3.4], [17.4, "Не знаю, что в моём спагетти настолько мутировало, что ты появился на свет", 3.8],
	[21.4, "Это даже мило, но, боюсь, мне ещё нужно откатить его тело после того, как ты буквально размозжил ему черепушку", 2.6], [24.2, "Покажешь, чему научился?", 2.4]]
const INTRO_LENGTH := 26.8
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

func active() -> bool:return not phase.is_empty()

func say(text: String, length: float):line = text;line_age = 0.0;line_length = length
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
	elif phase == "credits" and finale.age > 2.0:finale.age = finale.CREDITS_LENGTH

func step(w, dt: float, movement: Vector2):
	age += dt;pose_age += dt
	if line_length > 0:
		line_age += dt
		if line_age >= line_length:line = "";line_length = 0
	for list in [popups]:
		for i in range(list.size() - 1, -1, -1):
			list[i].age += dt
			if list[i].age > 1.8:list.remove_at(i)
	w.shake = maxf(0, w.shake - dt);w.invulnerable = maxf(0, w.invulnerable - dt);w.message_timer = maxf(0, w.message_timer - dt)
	match phase:
		"intro":
			for i in range(INTRO.size()):
				if cue(i, INTRO[i][0]):say(INTRO[i][1], INTRO[i][2]);set_pose(["invite", "look_hand", "point", "snap", "aura", "point", "idle", "invite"][i])
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
			var ending_age: float=age-(4.2 if bad_from_qte else 0.0)
			var shift: float=4.2 if bad_from_qte else 0.0
			if cue(0,1.08+shift):w.sound("ch1_whoosh",.1)
			if cue(1,1.35+shift):w.sound("ch4_hb_strip",.1)
			if cue(2,3.15+shift):say("Пора бы завязать с тестированием",3.2)
			if cue(3,6.8+shift):w.sound("ch4_drink",.1)
			if cue(4,13.40+shift):w.sound("ch4_door_open",.1)
			for step_index in range(8):
				if cue(5+step_index,[9.80,10.55,11.45,12.30,13.10,14.45,15.20,15.95][step_index]+shift):w.sound("ch1_step",.05)
			if ending_age>=18.2:w.state="RESULT";w.victory=false
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

# ------------------------------------------------------------------ the fight

func start_fight(w):
	clear_arena(w)
	w.player = CENTER + Vector2(0, 90)
	p = CENTER + Vector2(0, -40)
	w.super_spawn("notch", p)
	var m: Dictionary = w.mobs.back()
	m.code = true;m.glitch = false;m.boss = true;m.owner = 0;m.depth = 0;m.shield = false;m.reveal = 0.0;m.broken = false
	m.hp = FIGHT_HP;m.max_hp = FIGHT_HP
	id = m.id;hp = FIGHT_HP;attack_timer = 2.4;attack_index = 0;walls.clear();falls.clear();slow_left = 0.0
	change("fight");set_pose("idle")

func notch_mob(w):
	for m in w.mobs:
		if m.id == id:return m
	return null

func hurt(w, m: Dictionary, amount: float):
	hp -= amount;m.hp = maxf(1.0, hp);m.flash = .07
	w.add_effect("damage", m.p + Vector2(0, -30), .5, {"amount":int(ceil(amount))})

func fight(w, dt: float, movement: Vector2):
	var m = notch_mob(w)
	if m == null:start_fight(w);return
	slow_left = maxf(0, slow_left - dt)
	var speed: float = w.movement_speed() * (.5 if slow_left > 0 else 1.0)
	var before: Vector2 = w.player
	if movement.length_squared() > 0:
		w.facing = movement.normalized()
		w.player = w.move_actor(w.player, movement.limit_length() * speed * dt, 6)
	w.player = w.player.clamp(CENTER - Vector2(300, 170), CENTER + Vector2(300, 170))
	w.tracked_velocity = (w.player - before) / maxf(.0001, dt)
	w.player_visual.travel = before.distance_to(w.player);w.player_moving = w.player_visual.travel > .0001
	# He drifts, keeping a lazy distance.
	var off: Vector2 = p - w.player
	var want: float = 120.0
	p += (off.normalized() * (want - off.length()) * 1.2 + off.normalized().orthogonal() * 18.0).limit_length(60.0) * dt
	p = p.clamp(CENTER - Vector2(280, 160), CENTER + Vector2(280, 150))
	m.p = p;dir = p.direction_to(w.player);m.dir = dir
	attack_timer -= dt
	if attack_timer <= 0:
		attack(w)
		attack_timer = 2.7 if hp > FIGHT_HP * .5 else 2.1
	for i in range(walls.size() - 1, -1, -1):
		var wl: Dictionary = walls[i]
		wl.x += wl.dir * 150.0 * dt
		if absf(w.player.x - wl.x) < 6 and absf(w.player.y - wl.gap) > 26:w.damage_player(4.0)
		if absf(wl.x - CENTER.x) > 360:walls.remove_at(i)
	for i in range(falls.size() - 1, -1, -1):
		falls[i].age += dt
		if falls[i].age > falls[i].delay + .3:falls.remove_at(i)
	w.rebuild_hit_grid()
	w.update_attacks(dt);w.update_projectiles(dt);w.update_shots(dt)
	w.move_mobs(dt)
	w.arsenal.step(w, dt)
	w.resolve_deaths()
	w.update_effects(dt);w.pickup(dt);w.update_particles(dt);w.animation.advance(w, dt)
	if w.hp <= 0:lose(w, "fight");return
	if hp <= 0:
		m.hp = 0;w.mobs.erase(m);id = -1
		walls.clear();falls.clear();w.shots.clear();w.zones.clear()
		for o in w.mobs:o.hp = 0
		w.mobs.clear()
		change("to_ut")
	if w.xp >= w.db.required_xp(w.level):w.xp = 0

func attack(w):
	attack_index += 1
	var kinds := ["paste", "rain", "sweep", "rewrite", "summon", "blink"]
	var kind: String = kinds[attack_index % kinds.size()]
	match kind:
		"paste":
			set_pose("snap")
			popups.append({"p":p, "text":"Ctrl+C · Ctrl+V", "age":0.0})
			var gap: int = attack_index % 9
			for k in range(9):
				if k == gap:continue
				w.strike(w.player + Vector2((k % 3 - 1) * 44, (k / 3 - 1) * 44), 22.0, 1.0, 4.0)
			w.sound("ch4_hb_strip", .1)
		"rain":
			set_pose("cast")
			for k in range(14):
				var q: Vector2 = w.player + Vector2.from_angle(k * 2.39996 + attack_index) * (10 + k * 9)
				var delay: float = .8 + k * .06
				w.strike(q, 14.0, delay, 3.0)
				falls.append({"p":q, "age":0.0, "delay":delay, "block":["stone", "dirt", "obsidian"][k % 3]})
			w.sound("ch4_hb_rain", .1)
		"sweep":
			set_pose("throw")
			var from_left: bool = w.player.x > p.x
			walls.append({"x":CENTER.x + (-340.0 if from_left else 340.0), "dir":1.0 if from_left else -1.0, "gap":w.player.y + (attack_index % 3 - 1) * 40.0})
			popups.append({"p":p, "text":"delete(row);", "age":0.0})
			w.sound("ch4_hb_beam", .1)
		"rewrite":
			set_pose("point")
			slow_left = 4.0
			popups.append({"p":w.player, "text":"player.speed /= 2;", "age":0.0})
			w.sound("ch4_hb_twitch", .1)
		"summon":
			set_pose("invite")
			for k in range(4):w.spawn(["token", "for_loop", "recursion", "token"][k], p + Vector2.from_angle(k * TAU / 4) * 40.0)
			w.sound("ch4_hb_tick", .1)
		"blink":
			set_pose("lunge")
			var old: Vector2 = p
			p = (w.player + Vector2.from_angle(attack_index * 1.7) * 90.0).clamp(CENTER - Vector2(280, 160), CENTER + Vector2(280, 150))
			w.add_effect("ch5_rewind", old, .5, {"to":p})
			for k in range(16):w.shoot(p + Vector2(0, -16), Vector2.from_angle(k * TAU / 16) * 110.0, 2.0, "0" if k % 2 else "1")
			w.sound("ch4_hb_teleport", .1)

# ------------------------------------------------------------------ the battle box

func start_ut(w):
	clear_arena(w)
	change("ut");ut_hp = UT_HP;ut_wave = 0;ut_bullets.clear();ut_hits = 0;ut_blasters.clear();ut_choice = 0
	ut_state = "menu";ut_text = "* Нотч загораживает путь";ut_type = 0.0
	soul = UT_BOX.get_center();ut_mode = "red"
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
			w.sound("ch4_hb_shatter", .1);w.shake = .2

func show_text(text: String):
	ut_state = "text";ut_text = text;ut_timer = .25;ut_type = 0.0

func strike(w):
	var accuracy: float = clampf(1.0 - absf(bar - .5) * 2.0, 0, 1)
	var damage: float = 8.0 + 26.0 * accuracy
	ut_hp -= damage;ut_hits += 1;ut_flash = .5;ut_slash = 0.0;ut_number = int(damage * 9.7);ut_number_age = 0.0
	w.sound("ch4_punch_heavy", .1)
	ut_state = "slash";ut_timer = 1.1

func begin_wave(w):
	ut_state = "wave";ut_timer = 6.5;ut_wave += 1;ut_serial2 = 0;ut_bullets.clear();ut_blasters.clear();soul = UT_BOX.get_center() + Vector2(0, 20)
	serial = 0;ut_vy = 0.0
	ut_mode = "blue" if (ut_wave - 1) % 6 == 1 else "red"
	ut_bubble = BUBBLES[(ut_wave - 1) % BUBBLES.size()]
	if ut_mode == "blue":w.sound("ch4_hb_freeze", .1)

func battle(w, dt: float, movement: Vector2):
	ut_flash = maxf(0, ut_flash - dt);ut_number_age += dt
	if ut_slash >= 0:ut_slash += dt
	ut_timer -= dt
	if ut_state in ["text", "end", "menu"]:
		var before: int = int(ut_type)
		ut_type = minf(ut_text.length(), ut_type + dt * 32.0)
		if int(ut_type) != before and int(ut_type) % 2 == 0 and ut_text[int(ut_type) - 1] != " ":w.sound("ch4_hb_tick", .03)
	match ut_state:
		"bar":
			bar += dt / 1.2
			if bar > 1.05:
				ut_state = "miss";ut_timer = .8;ut_number_age = 0.0;ut_number = -1
		"slash", "miss":
			if ut_timer <= 0:
				if ut_hp <= 0:
					ut_state = "end";ut_bullets.clear();ut_timer = 2.6;ut_text = "* …Ладно\nВ целом, мне всё понравилось";ut_type = 0.0
				else:show_text(FLAVOR[ut_hits % FLAVOR.size()])
		"wave":
			soul_move(movement, dt)
			wave_bullets(w, dt)
			var spawned: Array = []
			for b in ut_bullets:
				b.age = float(b.get("age", 0.0)) + dt
				if b.has("delay"):
					if b.age < b.delay:continue
					b.v = Vector2(0, b.drop);b.erase("delay")
				if b.has("fuse") and b.age >= b.fuse and not b.get("done", false):
					b.done = true;b.p.y = -999.0;w.sound("explosion", .05);w.shake = .1
				if b.get("shape", "") == "tnt" and not b.has("at_y"):b.at_y = b.p.y;b.at_x = b.p.x
				if b.get("done", false) and b.get("shape", "") == "tnt" and not b.get("cross", false):
					b.cross = true
					spawned.append({"p":Vector2(UT_BOX.get_center().x, b.at_y), "v":Vector2.ZERO, "size":Vector2(UT_BOX.size.x, 10), "shape":"fire", "life":.35})
					spawned.append({"p":Vector2(b.at_x, UT_BOX.get_center().y), "v":Vector2.ZERO, "size":Vector2(10, UT_BOX.size.y), "shape":"fire", "life":.35})
					continue
				if b.has("life") and b.age > b.life:b.p.y = -999.0;continue
				if b.get("reverse_at", -1.0) > 0 and b.age >= b.reverse_at and not b.get("reversed", false):b.reversed = true;b.v = -b.v
				if b.get("gravity", false):
					b.v.y += 300.0 * dt
					if b.p.y > UT_BOX.end.y - 6 and b.v.y > 0:b.v.y = -b.v.y * .7
				if b.get("home", false) and b.age < 1.0:b.v = b.v.lerp(b.p.direction_to(soul) * b.v.length(), dt * 1.4)
				b.p += b.v * dt
				var hit: bool
				if b.get("ring", false):
					b.r += dt * 60.0
					hit = absf(b.p.distance_to(soul) - b.r) < 3.0 and b.r < 60.0
				elif b.has("size"):
					hit = Rect2(b.p - b.size / 2.0, b.size).grow(2).has_point(soul)
				else:
					hit = b.p.distance_to(soul) < float(b.get("r", 4.0))
				if hit and not b.get("safe", false) and b.age >= float(b.get("arm_at", 0.0)):hurt_soul(w)
			ut_bullets.append_array(spawned)
			for bl in ut_blasters:
				bl.age += dt
				if bl.age > .75 and bl.age < 1.15:
					var d: Vector2 = Vector2.from_angle(bl.angle)
					var rel: Vector2 = soul - bl.p
					if rel.dot(d) > 0 and absf(rel.cross(d)) < 10.0:hurt_soul(w)
				if bl.age > .74 and bl.age - dt <= .74:w.sound("ch4_hb_beam", .05)
			ut_blasters = ut_blasters.filter(func(bl):return bl.age < 1.3)
			ut_bullets = ut_bullets.filter(func(b):return Rect2(UT_BOX.position - Vector2(70, 70), UT_BOX.size + Vector2(140, 140)).has_point(b.p) and (not b.get("ring", false) or b.r < 60.0))
			if ut_timer <= 0:
				ut_state = "menu";ut_bullets.clear();ut_blasters.clear();ut_text = FLAVOR[ut_wave % FLAVOR.size()];ut_type = 0.0;ut_mode = "red"
		"end":
			if ut_timer <= 0:change("to_lanes")
	if w.hp <= 0:lose(w, "ut")

func hurt_soul(w):
	if w.invulnerable > 0:return
	w.hp -= 2.0;w.invulnerable = .9;w.sound("hurt", .1);w.shake = .12

func soul_move(movement: Vector2, dt: float):
	var lo: Vector2 = UT_BOX.position + Vector2(5, 5);var hi: Vector2 = UT_BOX.end - Vector2(5, 5)
	if ut_mode == "red":
		soul = (soul + movement.limit_length() * 95.0 * dt).clamp(lo, hi)
		return
	soul.x = clampf(soul.x + movement.x * 95.0 * dt, lo.x, hi.x)
	var grounded: bool = soul.y >= hi.y - .5
	if movement.y < -.5 and grounded and not ut_jump_held:ut_vy = -215.0
	if movement.y >= -.5 and ut_vy < -60.0:ut_vy = -60.0
	ut_jump_held = movement.y < -.5
	ut_vy += 520.0 * dt
	soul.y = clampf(soul.y + ut_vy * dt, lo.y, hi.y)
	if soul.y >= hi.y:ut_vy = 0.0

func wave_bullets(w, dt: float):
	var t: float = 6.5 - ut_timer
	var pattern: int = (ut_wave - 1) % 8
	# He stops playing around: faster, denser, and from the third turn two patterns overlap.
	var every: float = [0.7, 0.85, 0.75, 1.0, 0.35, 0.18, 0.55, 1.1][pattern] * .72
	var due: int = int(t / every)
	while serial < due:
		serial += 1
		spawn_pattern(w, pattern, serial)
	if ut_wave >= 3:
		var second: int = (pattern + 3) % 8
		if second == 1:second = 2
		var every2: float = [0.7, 0.85, 0.75, 1.0, 0.35, 0.18, 0.55, 1.1][second] * 1.5
		var due2: int = int(maxf(0.0, t - 1.0) / every2)
		while ut_serial2 < due2:
			ut_serial2 += 1
			spawn_pattern(w, second, ut_serial2 + 100)

func spawn_pattern(w, pattern: int, serial: int):
	var box: Rect2 = UT_BOX
	var n0: int = ut_bullets.size()
	match pattern:
		0:
			var gap: float = box.position.y + 20 + fposmod(serial * 29.0 + sin(serial) * 20.0, box.size.y - 40)
			for y in range(int(box.position.y) + 6, int(box.end.y), 11):
				if absf(y - gap) > 16:ut_bullets.append({"p":Vector2(box.end.x + 8, y), "v":Vector2(-118, 0), "size":Vector2(9, 9), "shape":"block"})
		1:
			var tall: float = 14.0 + (serial % 3) * 9.0
			var from_right: bool = serial % 2 == 0
			ut_bullets.append({"p":Vector2(box.end.x + 6 if from_right else box.position.x - 6, box.end.y - tall / 2.0), "v":Vector2(-135 if from_right else 135, 0), "size":Vector2(7, tall), "shape":"line"})
			if serial % 3 == 0:ut_bullets.append({"p":Vector2(box.end.x + 6, box.position.y + 22), "v":Vector2(-150, 0), "size":Vector2(7, 40), "shape":"line"})
		2:
			var corner: Vector2 = [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)][serial % 4]
			ut_bullets.append({"p":corner, "v":corner.direction_to(soul) * 95.0, "shape":"cursor", "r":5.0, "home":true})
			if serial % 2 == 0:ut_bullets.append({"p":soul + Vector2.from_angle(serial) * 4.0, "v":Vector2.ZERO, "ring":true, "r":2.0, "shape":"ring", "arm_at":.4})
		3:
			var side: int = serial % 4
			var at: Vector2
			var ang: float
			match side:
				0:at = Vector2(box.position.x - 22, box.position.y + 15 + fposmod(serial * 37.0, box.size.y - 30));ang = 0.0
				1:at = Vector2(box.end.x + 22, box.position.y + 15 + fposmod(serial * 23.0, box.size.y - 30));ang = PI
				2:at = Vector2(box.position.x + 15 + fposmod(serial * 41.0, box.size.x - 30), box.position.y - 22);ang = PI / 2
				_:at = Vector2(soul.x, box.end.y + 22);ang = -PI / 2
			ut_blasters.append({"p":at, "angle":ang, "age":0.0})
			w.sound("ch5_ut_charge", .1)
		4:
			var key: String = ["W", "A", "S", "D"][serial % 4]
			ut_bullets.append({"p":Vector2(box.position.x + 8 + fposmod(serial * 47.0, box.size.x - 16), box.position.y - 4), "v":Vector2(sin(serial) * 30.0, 40.0), "gravity":true, "size":Vector2(10, 10), "shape":"key", "glyph":key})
		5:
			var y: float = box.position.y + 6 + fposmod(serial * 17.0, box.size.y - 12)
			var left: bool = serial % 2 == 0
			ut_bullets.append({"p":Vector2(box.position.x - 6 if left else box.end.x + 6, y), "v":Vector2(110 if left else -110, 0), "r":4.0, "shape":"dot", "reverse_at":1.1})
		6:
			# Anvils: a warning column, then a fast drop.
			var ax: float = box.position.x + 12 + fposmod(serial * 53.0 + soul.x * .5, box.size.x - 24)
			if serial % 3 == 0:ax = clampf(soul.x, box.position.x + 12, box.end.x - 12)
			ut_bullets.append({"p":Vector2(ax, box.position.y - 14), "v":Vector2.ZERO, "size":Vector2(16, 14), "shape":"anvil", "delay":.6, "drop":340.0})
		7:
			# TNT: lit on a grid point, then a cross of fire through the box.
			var at := Vector2(box.position.x + 20 + fposmod(serial * 61.0, box.size.x - 40), box.position.y + 18 + fposmod(serial * 37.0, box.size.y - 36))
			ut_bullets.append({"p":at, "v":Vector2.ZERO, "size":Vector2(12, 12), "shape":"tnt", "fuse":1.0, "safe":true})
	for i in range(n0, ut_bullets.size()):
		var b: Dictionary = ut_bullets[i]
		b.age = 0.0
		if b.has("v"):b.v *= 1.3
		if b.has("drop"):b.drop *= 1.25
		if b.has("delay"):b.delay *= .8
		if b.has("fuse"):b.fuse *= .8

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

static func menu_rect(i: int) -> Rect2:return Rect2(120 + i * 104, 300, 92, 24)
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
			"throw":w.sound("ch1_whoosh", .1)
			"console":w.sound("ch4_hb_shatter", .1);w.sound("explosion", .1)
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
	if not finale.line.is_empty() and finale.line != line:say(finale.line, finale.line_length)

func begin_bad_end(w):
	bad_from_qte=phase=="qte"
	bad_blood=minf(.65,.15+qte.beat*.055) if bad_from_qte else 0.0
	bad_entry_track=qte.TRACKS[mini(qte.beat,7)] if qte.success else "miss"
	finale.change("bad_end");change("bad_end");line="";line_length=0

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
