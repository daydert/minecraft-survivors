extends RefCounted
## Notch, at 12:00. A talk, a fight in the code space, then his games:
## an Undertale-style battle box and a lane defence where he plays the
## zombies. Each phase restarts from its own checkpoint.
const CENTER := Vector2(1024, 1024)
const INTRO := [[0.6, "А. Ты всё-таки дошёл.", 2.6], [3.4, "Знаешь, сколько раз я тебя запускал? На третьей тысяче я сбился.", 3.6],
	[7.2, "Трава, Незер, Край, тот дурацкий трон — это всё я.", 3.2], [10.6, "Я это написал. Я это и сотру. Мне можно.", 3.0],
	[13.8, "Зачем? Было скучно. Хотелось посмотреть, что получится.", 3.4], [17.4, "А потом в коде появился ты. Строчка, которая решила, что она живая.", 3.8],
	[21.4, "Даже мило. Но баги надо чинить.", 2.6], [24.2, "Давай. Покажи, чему научился.", 2.4]]
const INTRO_LENGTH := 26.8
const FIGHT_HP := 1500.0
const UT_BOX := Rect2(220, 160, 200, 110)
const UT_HP := 100.0
const LANE_ORIGIN := Vector2(112, 96)
const CELL := Vector2(52, 46)
const COLS := 9
const ROWS := 5
const CARDS := [["dispenser", 100, 4.0], ["redstone_ore", 50, 4.0], ["obsidian", 50, 12.0], ["tnt", 150, 20.0]]
const PLANT_HP := {"dispenser": 6.0, "redstone_ore": 6.0, "obsidian": 40.0, "tnt": 99.0}
const ZOMBIES := {"zombie": [10.0, 9.0], "elite": [26.0, 8.0], "glitch": [7.0, 18.0], "creeper": [10.0, 10.0]}
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
var blasts: Array = []
var redstone := 150
var card := 0
var cursor := Vector2i(2, 2)
var card_ready: Array = [0.0, 0.0, 0.0, 0.0]
var trickle := 6.0
var schedule: Array = []
var lane_age := 0.0
var cursor_wait := 0.0
var serial := 0

func reset():
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
	elif phase in ["to_ut", "to_lanes", "lanes_won"] and age > .8:age = 99.0

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
			if cue(0, .1):say("Скучно так. Давай в мои любимые игры.", 2.6);set_pose("snap")
			idle_world(w, dt)
			if age >= 3.0:start_ut(w)
		"ut":battle(w, dt, movement)
		"to_lanes":
			if cue(0, .1):say("Ладно. Тогда так: я за зомби, ты за грядку.", 2.8)
			if age >= 3.0:start_lanes(w)
		"lanes":lanes(w, dt, movement)
		"lanes_won":
			if cue(0, .1):say("Ха. Неплохо. Но это была разминка.", 2.8)
			if age >= 3.2:finish(w)
		"retry":
			if age >= 2.4:
				w.hp = 20.0;w.invulnerable = 1.5
				match retry_of:
					"fight":start_fight(w)
					"ut":start_ut(w)
					"lanes":start_lanes(w)

func idle_world(w, dt: float):
	w.player_visual.travel = 0.0;w.player_moving = false
	w.update_particles(dt);w.animation.advance(w, dt)

func lose(w, which: String):
	retry_of = which;change("retry")
	w.sound("death", .2)
	say("Чекпоинт. Ещё раз.", 2.0)

func finish(w):
	# Stage E (the fighter and the arena) follows; until then the run ends here.
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
	change("ut");ut_hp = UT_HP;ut_state = "menu";ut_choice = 0;ut_wave = 0;ut_bullets.clear();ut_hits = 0
	ut_text = "* Нотч загораживает путь."
	soul = UT_BOX.get_center()
	w.sound("ch4_hb_glitch", .1)

func press(w, action: String):
	if phase == "lanes":lane_press(w, action);return
	if phase != "ut":return
	var options: Array = menu_options()
	match ut_state:
		"menu":
			if action == "left":ut_choice = posmod(ut_choice - 1, options.size());w.sound("select", .02)
			elif action == "right":ut_choice = posmod(ut_choice + 1, options.size());w.sound("select", .02)
			elif action == "accept":choose(w, options[ut_choice])
		"bar":
			if action == "accept":strike(w)
		"text":
			if action == "accept" and ut_timer <= 0:begin_wave(w)

func menu_options() -> Array:
	return ["fight", "act", "item"] if mercy_gone else ["fight", "act", "item", "mercy"]

func choose(w, option: String):
	match option:
		"fight":ut_state = "bar";bar = 0.0
		"act":show_text("* НОТЧ — АТК 99, ЗАЩ 99.\n* Говорит, что написал тебя за выходные.")
		"item":
			if ut_items > 0:
				ut_items -= 1;w.hp = minf(20.0, w.hp + 8.0);w.sound("pickup", .1)
				show_text("* Ты съел яблоко. +8 HP.")
			else:show_text("* В инвентаре пусто.")
		"mercy":
			mercy_gone = true;ut_choice = 0
			show_text("* Нотч стирает кнопку ПОЩАДА.")
			w.sound("ch4_hb_shatter", .1);w.shake = .2

func show_text(text: String):
	ut_state = "text";ut_text = text;ut_timer = .3

func strike(w):
	var accuracy: float = 1.0 - absf(bar - .5) * 2.0
	var damage: float = 12.0 + 22.0 * clampf(accuracy, 0, 1)
	ut_hp -= damage;ut_hits += 1;ut_flash = .4
	popups.append({"p":Vector2(320, 70), "text":str(int(damage)), "age":0.0, "screen":true})
	w.sound("ch4_punch_heavy", .1)
	if ut_hp <= 0:
		ut_state = "end";ut_bullets.clear();ut_timer = 2.2
		ut_text = "* …Ладно. Это было в моём вкусе."
		return
	show_text(["* Нотч смеётся.", "* Нотч поправляет код.", "* «Ты меня ещё удивишь?»", "* Строки вокруг дрожат."][ut_hits % 4])

func begin_wave(w):
	ut_state = "wave";ut_timer = 6.0;ut_wave += 1;ut_bullets.clear();soul = UT_BOX.get_center()
	serial = 0

func battle(w, dt: float, movement: Vector2):
	ut_flash = maxf(0, ut_flash - dt)
	ut_timer -= dt
	match ut_state:
		"bar":
			bar += dt / 1.3
			if bar > 1.0:strike(w);ut_hp += 0.0
		"wave":
			soul = (soul + movement.limit_length() * 95.0 * dt).clamp(UT_BOX.position + Vector2(5, 5), UT_BOX.end - Vector2(5, 5))
			wave_bullets(w, dt)
			for b in ut_bullets:
				b.p += b.v * dt
				if b.get("home", false):b.v = b.v.lerp(b.p.direction_to(soul) * 55.0, dt * 1.5)
				if b.p.distance_to(soul) < b.get("r", 4.0) and w.invulnerable <= 0:
					w.hp -= 2.0;w.invulnerable = .8;w.sound("hurt", .1);w.shake = .1
			ut_bullets = ut_bullets.filter(func(b):return Rect2(UT_BOX.position - Vector2(60, 60), UT_BOX.size + Vector2(120, 120)).has_point(b.p))
			if ut_timer <= 0:ut_state = "menu";ut_bullets.clear();ut_text = "* Нотч ждёт."
		"end":
			if ut_timer <= 0:change("to_lanes")
	if w.hp <= 0:lose(w, "ut")

func wave_bullets(w, dt: float):
	var t: float = 6.0 - ut_timer
	var pattern: int = (ut_wave - 1) % 4
	var due: int = int(t / [0.55, 0.22, 1.2, 1.6][pattern])
	while serial < due:
		serial += 1
		match pattern:
			0:
				var gap: float = UT_BOX.position.y + 18 + fposmod(serial * 37.0, UT_BOX.size.y - 36)
				for y in range(int(UT_BOX.position.y) + 4, int(UT_BOX.end.y), 8):
					if absf(y - gap) > 14:ut_bullets.append({"p":Vector2(UT_BOX.end.x + 8, y), "v":Vector2(-110, 0), "glyph":"="})
			1:
				ut_bullets.append({"p":Vector2(UT_BOX.position.x + fposmod(serial * 53.0, UT_BOX.size.x), UT_BOX.position.y - 6), "v":Vector2(0, 90 + serial % 3 * 20), "glyph":"■", "r":5.0})
			2:
				var gap_angle: float = serial * 1.3
				for k in range(18):
					var a: float = k * TAU / 18
					if absf(angle_difference(a, gap_angle)) < .45:continue
					ut_bullets.append({"p":soul + Vector2.from_angle(a) * 70, "v":-Vector2.from_angle(a) * 45, "glyph":"·"})
			3:
				for k in range(2):
					ut_bullets.append({"p":Vector2(UT_BOX.position.x if k == 0 else UT_BOX.end.x, UT_BOX.position.y + fposmod(serial * 41.0, UT_BOX.size.y)), "v":Vector2(40 if k == 0 else -40, 0), "glyph":"?", "home":true, "r":5.0})

# ------------------------------------------------------------------ the lanes

func start_lanes(w):
	clear_arena(w)
	change("lanes");plants.clear();zombies.clear();arrows.clear();blasts.clear()
	redstone = 150;card = 0;cursor = Vector2i(2, 2);card_ready = [0.0, 0.0, 0.0, 0.0];trickle = 6.0;lane_age = 0.0;serial = 0
	schedule = []
	var t := 8.0
	for k in range(34):
		var kind: String = "zombie"
		if k > 6 and k % 4 == 0:kind = "elite"
		if k > 10 and k % 5 == 2:kind = "glitch"
		if k > 14 and k % 7 == 3:kind = "creeper"
		schedule.append({"at":t, "row":(k * 3 + k / 5) % ROWS, "kind":kind})
		t += maxf(1.4, 5.5 - k * .14)
		if k in [16, 28]:
			for extra in range(4):schedule.append({"at":t + extra * .5, "row":(extra * 2 + k) % ROWS, "kind":"zombie" if extra % 2 else "glitch"})
			t += 6.0
	say("Ладно. Тогда так: я за зомби, ты за грядку.", 2.0)

func cell_rect(c: Vector2i) -> Rect2:
	return Rect2(LANE_ORIGIN + Vector2(c.x, c.y) * CELL, CELL)

func lane_press(w, action: String):
	match action:
		"left":cursor.x = maxi(0, cursor.x - 1)
		"right":cursor.x = mini(COLS - 1, cursor.x + 1)
		"up":cursor.y = maxi(0, cursor.y - 1)
		"down":cursor.y = mini(ROWS - 1, cursor.y + 1)
		"accept":place(w)
		"1", "2", "3", "4":card = int(action) - 1

func click(w, at: Vector2) -> bool:
	if phase == "ut":
		for i in range(menu_options().size()):
			if menu_rect(i).has_point(at):
				ut_choice = i;press(w, "accept");return true
		if ut_state in ["bar", "text"]:press(w, "accept");return true
		return false
	if phase != "lanes":return false
	for i in range(CARDS.size()):
		if card_rect(i).has_point(at):card = i;return true
	var rel: Vector2 = (at - LANE_ORIGIN) / CELL
	if rel.x >= 0 and rel.y >= 0 and rel.x < COLS and rel.y < ROWS:
		cursor = Vector2i(int(rel.x), int(rel.y));place(w);return true
	return false

static func menu_rect(i: int) -> Rect2:return Rect2(120 + i * 104, 300, 92, 24)
static func card_rect(i: int) -> Rect2:return Rect2(112 + i * 56, 40, 50, 46)

func place(w):
	var spec: Array = CARDS[card]
	if plants.has(cursor) or redstone < int(spec[1]) or card_ready[card] > 0:
		w.sound("ch4_punch_miss", .05);return
	redstone -= int(spec[1]);card_ready[card] = float(spec[2])
	plants[cursor] = {"kind":spec[0], "hp":PLANT_HP[spec[0]], "timer":1.0 if spec[0] == "tnt" else 1.5, "age":0.0}
	w.sound("ch1_wood_place", .05)

func lanes(w, dt: float, movement: Vector2):
	lane_age += dt
	cursor_wait -= dt
	if movement.length_squared() > .2 and cursor_wait <= 0:
		cursor_wait = .16
		if absf(movement.x) > absf(movement.y):lane_press(w, "right" if movement.x > 0 else "left")
		else:lane_press(w, "down" if movement.y > 0 else "up")
	elif movement.length_squared() <= .2:cursor_wait = 0.0
	for i in range(4):card_ready[i] = maxf(0, card_ready[i] - dt)
	trickle -= dt
	if trickle <= 0:trickle = 6.0;redstone += 25
	while not schedule.is_empty() and lane_age >= schedule[0].at:
		var s: Dictionary = schedule.pop_front()
		var spec: Array = ZOMBIES[s.kind]
		zombies.append({"kind":s.kind, "row":s.row, "x":LANE_ORIGIN.x + COLS * CELL.x + 20, "hp":spec[0], "max":spec[0], "speed":spec[1], "bite":0.0, "flash":0.0, "visual":w.animation.actor(), "age":0.0})
		set_pose("throw")
	for c in plants.keys():
		var pl: Dictionary = plants[c]
		pl.age += dt;pl.timer -= dt
		match pl.kind:
			"dispenser":
				if pl.timer <= 0 and zombies.any(func(z):return z.row == c.y and z.x > cell_rect(c).position.x):
					pl.timer = 1.5
					arrows.append({"row":c.y, "x":cell_rect(c).get_center().x})
					w.sound("arrow", .05)
			"redstone_ore":
				if pl.timer <= 0:pl.timer = 8.0;redstone += 25;popups.append({"p":cell_rect(c).get_center(), "text":"+25", "age":0.0, "screen":true})
			"tnt":
				if pl.timer <= 0:
					blasts.append({"p":cell_rect(c).get_center(), "age":0.0})
					for z in zombies:
						if absi(z.row - c.y) <= 1 and absf(z.x - cell_rect(c).get_center().x) < CELL.x * 1.6:z.hp -= 30.0
					plants.erase(c);w.sound("explosion", .05);w.shake = .2
	for i in range(arrows.size() - 1, -1, -1):
		var a: Dictionary = arrows[i]
		a.x += 170.0 * dt
		var hit := false
		for z in zombies:
			if z.row == a.row and absf(z.x - a.x) < 8 and z.hp > 0:
				z.hp -= 2.0;z.flash = .08;hit = true;break
		if hit or a.x > 640:arrows.remove_at(i)
	for i in range(zombies.size() - 1, -1, -1):
		var z: Dictionary = zombies[i]
		z.age += dt;z.flash = maxf(0, z.flash - dt);z.bite = maxf(0, z.bite - dt)
		if z.hp <= 0:
			w.emit_pixels("smoke", Vector2(z.x, row_y(z.row)), 6, Vector2.UP);zombies.remove_at(i);continue
		var col: int = int((z.x - 10 - LANE_ORIGIN.x) / CELL.x)
		var target := Vector2i(col, z.row)
		if col >= 0 and col < COLS and plants.has(target) and z.x - cell_rect(target).get_center().x < 22:
			z.moving = false
			if z.kind == "creeper":
				plants.erase(target);blasts.append({"p":Vector2(z.x, row_y(z.row)), "age":0.0});z.hp = 0;w.sound("explosion", .05)
			elif z.bite <= 0:
				z.bite = .5;plants[target].hp -= 1.0;w.sound("ch4_flesh_hit", .1)
				if plants[target].hp <= 0:plants.erase(target)
		else:
			z.moving = true;z.x -= z.speed * dt
		z.visual.gait += z.speed * dt / 30.0
		w.animation.set_pose(z.visual, "walk" if z.moving else "attack", z.visual.gait if z.moving else fposmod(z.age, .3))
		if z.x < LANE_ORIGIN.x - 14:
			say("Мозги.", 1.6);lose(w, "lanes");return
	for b in blasts:b.age += dt
	blasts = blasts.filter(func(b):return b.age < .5)
	if schedule.is_empty() and zombies.is_empty():change("lanes_won")

func row_y(row: int) -> float:return LANE_ORIGIN.y + (row + .5) * CELL.y
