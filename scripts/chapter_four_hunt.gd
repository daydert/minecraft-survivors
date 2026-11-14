extends RefCounted
## Chapter IV pressure pass (13.11): the pillars become objectives, elites come
## with retinues and affixes, ambushes cut off kiting lines, the raid horn calls
## surges, and the village butcher walks the map and cannot be killed.
## Everything runs on simulation time; the renderer reads the same state.
const Enemies = preload("res://scripts/chapter_four_enemies.gd")

var data: Dictionary = {}
## Ground tells that become mobs: {p, kind, at, born, seed, source}.
var rises: Array = []
## Volatile elite deaths waiting to burst: {p, at, born, radius, damage}.
var blasts: Array = []
var rescued := 0
var stir_at := 0.0
var stirring: Dictionary = {}
var ambush_at := 0.0
var surge_left := 0.0
var surges_done: Dictionary = {}
var butcher_done: Dictionary = {}
var butcher_pending := -1.0
var vengeance_until := -10.0
var forcing := false
var last_reward := ""
var reward_at := -10.0

func reset(w):
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_four_hunt.json"))
	rises.clear();blasts.clear();rescued = 0
	stir_at = float(data.stir.first);stirring = {}
	ambush_at = float(data.ambush.from);surge_left = 0.0
	surges_done.clear();butcher_done.clear();butcher_pending = -1.0
	vengeance_until = -10.0;forcing = false;last_reward = "";reward_at = -10.0

func pillars(w) -> Array:
	return w.landmarks.filter(func(m):return m.kind == "crucifix")

func hanging(mark: Dictionary) -> bool:
	return mark.get("state", "hung") in ["hung", "stirring"]

func damage_scale(w) -> float:
	return float(data.rescue.vengeance_damage) if w.clock < vengeance_until else 1.0

func wave_scale(w) -> float:
	return float(data.surges.rate) if surge_left > 0 else 1.0

func butcher(w):
	for m in w.mobs:
		if m.get("form", "") == "butcher" and m.hp > 0:return m
	return null

## Spawns past the mob cap and the elite limits: scripted arrivals must happen.
func force_spawn(w, kind: String, p: Vector2) -> Dictionary:
	var cap = w.db.data.mob_cap
	w.db.data.mob_cap = 100000;forcing = true
	var ok: bool = w.spawn(kind, p)
	w.db.data.mob_cap = cap;forcing = false
	return w.mobs.back() if ok else {}

func rise(w, kind: String, p: Vector2, delay: float, source: String):
	if not w.free_at(p, 9) or w.in_blood(p):return
	if p.x < 24 or p.y < 24 or p.x > 2024 or p.y > 2024:return
	rises.append({"p": p, "kind": kind, "at": w.clock + delay, "born": w.clock, "seed": w.next_id(), "source": source})

func tick(w, dt: float):
	if w.stage != "survival":return
	update_rises(w)
	update_blasts(w)
	update_pillars(w, dt)
	update_stir(w)
	update_elites(w, dt)
	update_ambush(w)
	update_surges(w, dt)
	update_butcher(w)

# ------------------------------------------------------------------ rises
func update_rises(w):
	for i in range(rises.size() - 1, -1, -1):
		var r: Dictionary = rises[i]
		if w.clock < r.at:continue
		rises.remove_at(i)
		var m: Dictionary = force_spawn(w, r.kind, r.p)
		if m.is_empty():continue
		m.emerge = w.clock;m.stun = maxf(m.stun, .55);m.visual_dir = r.p.direction_to(w.player);m.dir = m.visual_dir
		w.fx.erupt(w, r.p, "dirt", 4)

func ring_rise(w, center: Vector2, count: int, radius: float, delay: float, kinds: Array, source: String):
	var turn: float = w.rng.randf() * TAU
	for j in range(count):
		var p: Vector2 = center + Vector2.from_angle(turn + j * TAU / count) * radius * (1.0 + .08 * sin(j * 2.7))
		rise(w, kinds[j % kinds.size()], p, delay + j * .03, source)

func melee_kinds(w) -> Array:
	if w.time < 110:return ["flayed_zombie"]
	if w.time < 330:return ["flayed_zombie", "hungry_wolf", "flayed_zombie", "torn_spider", "crawler"]
	return ["flayed_zombie", "hungry_wolf", "torn_spider", "fused_villagers", "flayed_zombie", "open_cow"]

# ------------------------------------------------------------------ pillars
func update_pillars(w, dt: float):
	var rules: Dictionary = data.rescue
	for mark in pillars(w):
		if not hanging(mark):continue
		var near: bool = w.player.distance_to(mark.p) < float(rules.radius)
		var progress: float = mark.get("progress", 0.0)
		if near:
			if not mark.get("ambushed", false):
				mark.ambushed = true
				var count: int = mini(int(rules.ambush_max), int(rules.ambush_base) + int(w.time / 60.0 * float(rules.ambush_per_minute)))
				ring_rise(w, mark.p, count, float(rules.ambush_radius), float(rules.ambush_delay), melee_kinds(w), "pillar")
				w.sound("ch4_ambush");w.sound("ch4_stir", .5)
			progress += dt
			if int(progress * 3) != int((progress - dt) * 3):w.sound("ch4_rescue_cut", .25)
		else:
			progress = maxf(0.0, progress - dt * float(rules.decay))
		mark.progress = progress
		if progress >= float(rules.time):free_villager(w, mark)

func on_player_hit(w):
	for mark in pillars(w):
		if hanging(mark) and mark.get("progress", 0.0) > 0 and w.player.distance_to(mark.p) < float(data.rescue.radius) + 8:
			mark.progress = maxf(0.0, mark.progress - float(data.rescue.hit_penalty))

func free_villager(w, mark: Dictionary):
	var rules: Dictionary = data.rescue
	var was_stirring: bool = mark.state == "stirring" if mark.has("state") else false
	mark.state = "freed";mark.progress = 0.0;mark.freed_at = w.clock
	if was_stirring:stirring = {};stir_at = w.clock + float(data.stir.interval)
	rescued += 1
	w.hp = minf(20.0, w.hp + float(rules.heal))
	var xp: float = float(rules.xp) * (float(rules.stir_xp_bonus) if was_stirring else 1.0)
	for j in range(5):w.drop_xp(mark.p + Vector2.from_angle(j * TAU / 5) * 14, int(ceil(xp / 5.0)))
	vengeance_until = w.clock + float(rules.vengeance_time)
	last_reward = "+20%% урона на %d с" % int(rules.vengeance_time)
	if rescued % int(rules.chest_every) == 0:
		w.loot.append({"kind": "chest", "p": mark.p + Vector2(0, 16), "born": w.time})
		last_reward = "Сундук у столба"
	reward_at = w.clock
	w.message = "Житель снят (%d/%d)" % [rescued, pillars(w).size()];w.message_timer = 2.4
	w.sound("ch4_rescue_body");w.sound("ch4_rescue_reward")
	w.add_effect("ch4h_freed", mark.p, 1.2)
	w.fx.pulse(w, "heart")
	w.update_aura()

# ------------------------------------------------------------------ stirring
func update_stir(w):
	if not stirring.is_empty():
		if stirring.state != "stirring":stirring = {};return
		if w.clock >= stirring.stir_until:tear(w, stirring)
		return
	if w.clock < stir_at or w.encounters.busy() or w.time >= float(w.db.data.duration) - 20:return
	var best = null
	var best_score := INF
	for mark in pillars(w):
		if mark.get("state", "hung") != "hung":continue
		var d: float = w.player.distance_to(mark.p)
		if d < float(data.stir.near) or d > float(data.stir.far):continue
		var score: float = absf(d - 520.0) + w.rng.randf() * 120.0
		if score < best_score:best_score = score;best = mark
	if best == null:stir_at = w.clock + 8.0;return
	best.state = "stirring";best.stir_from = w.clock;best.stir_until = w.clock + float(data.stir.warn)
	stirring = best
	w.message = "Житель на столбе зашевелился";w.message_timer = 3.2
	w.sound("ch4_stir")

func tear(w, mark: Dictionary):
	var m: Dictionary = force_spawn(w, "crucified", mark.p + Vector2(0, 14))
	if m.is_empty():mark.stir_until = w.clock + 1.0;return
	mark.state = "torn";mark.progress = 0.0
	stirring = {};stir_at = w.clock + float(data.stir.interval)
	m.emerge = -99.0;m.stun = maxf(m.stun, .9);m.visual_dir = Vector2.DOWN
	w.fx.erupt(w, mark.p, "flesh", 10);w.fx.quake(w, mark.p, 1.2)
	w.sound("ch4_tear");w.sound("ch4_butcher_roar", .3)
	w.add_effect("ch4h_tear", mark.p, .8)
	on_elite(w, m, data.stir.retinue)
	w.message = "Распятый сорвался" + affix_suffix(m);w.message_timer = 2.8
	w.update_aura()

# ------------------------------------------------------------------ elites
func on_elite(w, m: Dictionary, retinue = null):
	var rules: Dictionary = data.affixes
	var pool: Array = ["vampiric", "volatile", "shielded", "frenzied"]
	var count: int = 2 if w.time >= float(rules.second_after) else 1
	m.affixes = []
	for j in range(count):
		var id: String = pool[w.rng.randi_range(0, pool.size() - 1)]
		pool.erase(id);m.affixes.append(id)
	m.raise_at = w.clock + 3.0
	var kinds: Array = retinue if retinue != null else data.retinues.get(m.form, [])
	if not kinds.is_empty():
		ring_rise(w, m.p, kinds.size(), 42.0, .5, kinds, "retinue")
	w.sound("ch4_affix", .2)

func affix_suffix(m: Dictionary) -> String:
	var names: Array = []
	for id in m.get("affixes", []):names.append(data.affixes.names[id])
	return "" if names.is_empty() else ": " + ", ".join(names)

func has_affix(m: Dictionary, id: String) -> bool:
	return id in m.get("affixes", [])

func update_elites(w, dt: float):
	var rules: Dictionary = data.affixes
	for m in w.mobs:
		if m.hp <= 0 or not m.has("affixes"):continue
		if has_affix(m, "shielded"):
			var n := 0
			for other in w.mobs:
				if other.hp > 0 and other.id != m.id and not other.get("boss", false) and other.get("form", "") != "butcher" and other.p.distance_to(m.p) < float(rules.shield_radius):n += 1
			m.shield_n = n
		if has_affix(m, "frenzied") and m.hp < m.max_hp * float(rules.frenzy_hp):
			if not m.get("frenzy", false):
				m.frenzy = true;w.add_effect("ch4h_frenzy", m.p, .6);w.sound("ch4_butcher_grunt", .3)
			m.haste = maxf(m.haste, .1);m.haste_scale = float(rules.frenzy_speed)
			if m.phase == "walk":m.timer -= dt * float(rules.frenzy_cooldown)
		if m.form == "gravedigger" and w.clock >= m.get("raise_at", 0.0):
			var raise: Dictionary = data.gravedigger_raise
			m.raise_at = w.clock + float(raise.interval)
			if m.p.distance_to(w.player) < float(raise.range) and m.stun <= 0:
				for j in range(int(raise.count)):
					var side: Vector2 = m.p.direction_to(w.player).orthogonal() * (1 if j % 2 == 0 else -1)
					rise(w, "flayed_zombie", w.player + side * (58 + j * 10) + w.player.direction_to(m.p) * 22, float(raise.delay), "grave")
				w.add_effect("ch4h_raise", m.p, .7);w.sound("ch4_ambush", .3)

func shield_guard(m: Dictionary) -> float:
	if not has_affix(m, "shielded"):return 0.0
	return float(data.affixes.shield_guard) if m.get("shield_n", 0) >= int(data.affixes.shield_needed) else 0.0

func on_hit_player(w, attacker: Dictionary, taken: float):
	if taken <= 0 or attacker.is_empty() or attacker.get("hp", 0) <= 0:return
	if has_affix(attacker, "vampiric"):
		attacker.hp = minf(attacker.max_hp, attacker.hp + attacker.max_hp * float(data.affixes.vampiric_heal))
		w.add_effect("ch4h_drain", w.player, .5, {"end": attacker.p})
		w.sound("ch4_drink", .3)

func on_elite_death(w, m: Dictionary):
	if has_affix(m, "volatile"):
		var rules: Dictionary = data.affixes
		blasts.append({"p": m.p, "at": w.clock + float(rules.volatile_delay), "born": w.clock, "radius": float(rules.volatile_radius), "damage": float(rules.volatile_damage)})
		w.sound("ch4_charge", .2)

func update_blasts(w):
	for i in range(blasts.size() - 1, -1, -1):
		var b: Dictionary = blasts[i]
		if w.clock < b.at:continue
		blasts.remove_at(i)
		if w.player.distance_to(b.p) < b.radius:w.damage_player(b.damage)
		var shots: int = int(data.affixes.volatile_shots)
		for j in range(shots):
			w.blood_shots.append({"p": b.p, "dir": Vector2.from_angle(j * TAU / shots + .2), "life": 1.6, "speed": 120.0, "damage": 2.0})
		w.add_effect("ch4_burst", b.p, .45, {"radius": b.radius})
		w.fx.erupt(w, b.p, "flesh", 9);w.fx.quake(w, b.p, 1.0)
		w.sound("ch4_creeper_burst")

# ------------------------------------------------------------------ ambush & surges
func update_ambush(w):
	var rules: Dictionary = data.ambush
	if w.clock < ambush_at:return
	if w.encounters.busy() or w.tracked_velocity.length() < float(rules.min_speed):ambush_at = w.clock + 1.5;return
	ambush_at = w.clock + float(rules.interval) + w.rng.randf_range(-1, 1) * float(rules.jitter)
	var dir: Vector2 = w.tracked_velocity.normalized()
	var count: int = mini(int(rules.max), int(rules.base) + int(w.time / 60.0 * float(rules.per_minute)))
	var kinds: Array = melee_kinds(w)
	var spread: float = float(rules.spread)
	for j in range(count):
		var a: float = (float(j) / maxf(1, count - 1) - .5) * 2.0 * spread
		var p: Vector2 = w.player + dir.rotated(a) * float(rules.distance) * (1.0 - .12 * absf(a))
		rise(w, kinds[(j + int(w.time)) % kinds.size()], p, float(rules.delay), "ambush")
	w.sound("ch4_ambush")

func update_surges(w, dt: float):
	surge_left = maxf(0.0, surge_left - dt)
	var rules: Dictionary = data.surges
	for i in range(rules.times.size()):
		if surges_done.has(i) or w.time < float(rules.times[i]):continue
		surges_done[i] = true
		surge_left = float(rules.life)
		w.message = "Набат";w.message_timer = 2.6
		w.sound("ch4_surge");w.sound("ch4_bell", .2)
		w.shake = maxf(w.shake, .3)
		if not w.encounters.busy():
			ring_rise(w, w.player, int(rules.ring), float(rules.ring_radius), float(rules.ring_delay), melee_kinds(w), "surge")

# ------------------------------------------------------------------ butcher
func update_butcher(w):
	var rules: Dictionary = data.butcher
	var b = butcher(w)
	if b != null:
		if not b.has("leave_at"):
			b.immortal = true;b.leave_at = w.clock + float(rules.life);b.stagger_acc = 0.0;b.stagger_lock = 0.0;b.lunge_ready = w.clock + 3.0
		b.control_resist = 99.0
		if b.get("expired", false):return
		b.hp = b.max_hp
		if b.has("sinking"):
			if w.clock - b.sinking >= float(rules.sink):b.immortal = false;b.expired = true;b.hp = 0
		elif w.clock >= b.leave_at and b.phase in ["walk", "recover"] or w.time >= float(w.db.data.duration) - 2:
			b.sinking = w.clock;b.phase = "sink";b.timer = 99.0;b.cast = ""
			w.fx.erupt(w, b.p, "dirt", 8);w.sound("ch4_butcher_leave")
			w.message = "Мясник ушёл";w.message_timer = 2.2
		elif b.p.distance_to(w.player) < 300:
			w.sound("ch4_butcher_step", .62)
		return
	for i in range(rules.times.size()):
		if butcher_done.has(i) or w.time < float(rules.times[i]):continue
		if w.encounters.busy() or w.time >= float(w.db.data.duration) - 30:return
		butcher_done[i] = true
		var back: Vector2 = -w.tracked_velocity.normalized() if w.tracked_velocity.length() > 10 else Vector2.from_angle(w.rng.randf() * TAU)
		for attempt in range(10):
			var p: Vector2 = w.player + back.rotated((attempt - 4.5) * .3) * float(rules.distance)
			if not w.free_at(p, 14) or w.in_blood(p):continue
			var m: Dictionary = force_spawn(w, "butcher", p)
			if m.is_empty():continue
			m.immortal = true;m.leave_at = w.clock + float(rules.life);m.stagger_acc = 0.0;m.stagger_lock = 0.0;m.lunge_ready = w.clock + 3.0
			m.emerge = w.clock;m.stun = 1.6;m.visual_dir = p.direction_to(w.player);m.dir = m.visual_dir;m.control_resist = 99.0
			w.fx.erupt(w, p, "dirt", 12);w.fx.quake(w, p, 1.6)
			w.sound("ch4_butcher_roar");w.sound("ch4_heavy", .2)
			break
		return

func butcher_hurt(w, m: Dictionary, amount: float, push: Vector2):
	m.flash = .08
	w.emit_pixels("impact", m.p - Vector2(0, 14), 2, push)
	if w.clock < m.get("stagger_lock", 0.0):return
	m.stagger_acc = m.get("stagger_acc", 0.0) + amount
	if m.stagger_acc >= float(m.ai.stagger):
		m.stagger_acc = 0.0;m.stagger_lock = w.clock + float(m.ai.stagger_lock)
		m.stun = float(m.ai.stagger_time);Enemies.cancel(m, .2)
		m.knock = push.normalized() * 90 if push.length() > 0 else w.player.direction_to(m.p) * 90
		w.add_effect("ch4h_stagger", m.p, .5);w.sound("ch4_butcher_grunt", .4)

# ------------------------------------------------------------------ AI
func act(w, m: Dictionary, dt: float):
	m.timer -= dt
	var ai: Dictionary = m.ai
	var distance: float = m.p.distance_to(w.player)
	var toward: Vector2 = m.p.direction_to(w.player)
	if m.phase in ["smash_wait", "sink"]:return
	if m.phase == "recover":
		if m.timer <= 0:Enemies.enter(m, "walk", ai.get("cooldown", 1.5))
		return
	match m.form:
		"marksman":marksman(w, m, dt, distance, toward)
		"crucified":crucified(w, m, dt, distance, toward)
		"butcher":butcher_act(w, m, dt, distance, toward)

func marksman(w, m: Dictionary, dt: float, distance: float, toward: Vector2):
	var ai: Dictionary = m.ai
	if m.phase == "windup":
		if distance < 70:Enemies.cancel(m, .3);return
		if m.timer > float(ai.lock):m.charge = toward
		if m.timer <= 0:
			if w.enemy_shots.size() < int(w.db.data.chapter_four.enemy_limits.shots):
				w.enemy_shots.append({"p": m.p - Vector2(0, 2), "dir": m.charge, "kind": "bone", "snipe": true, "speed": float(ai.speed), "damage": m.damage, "life": float(ai.range) / float(ai.speed) + .25})
			if w.visible(m.p, 30):w.sound("ch4_sniper_shot", .1)
			Enemies.enter(m, "attack", ai.attack)
		return
	if m.phase == "attack":
		if m.timer <= 0:Enemies.enter(m, "recover", ai.recover)
		return
	var direction: Vector2 = w.navigation(m.p)
	var speed: float = m.speed
	if distance < float(ai.near):direction = -toward
	elif distance < float(ai.far):direction = toward.orthogonal() * (1 if m.id % 2 else -1);speed *= .45
	if m.timer <= 0 and distance >= 90 and distance < float(ai.range) and w.line_clear(m.p, w.player):
		m.charge = toward;Enemies.enter(m, "windup", ai.windup)
		if w.visible(m.p, 20):w.sound("ch4_sniper_aim", .3)
		return
	Enemies.travel(w, m, direction, speed, dt)

func crucified(w, m: Dictionary, dt: float, distance: float, toward: Vector2):
	var ai: Dictionary = m.ai
	if m.phase == "windup":
		if m.cast == "ram" and m.timer > .25:m.charge = toward
		if m.timer <= 0:
			if m.cast == "ram":
				m.hit_done = false;Enemies.enter(m, "attack", ai.ram_attack)
			else:
				sweep(w, m, float(ai.reach) + 12, float(ai.arc), m.damage)
				w.sound("ch4_butcher_swing", .1)
				Enemies.enter(m, "attack", ai.attack)
		return
	if m.phase == "attack":
		if m.cast == "ram":
			var before: Vector2 = m.p
			Enemies.travel(w, m, m.charge, float(ai.dash_speed), dt)
			if not m.get("hit_done", false) and Geometry2D.get_closest_point_to_segment(w.player, before, m.p).distance_to(w.player) < m.radius + 7:
				m.hit_done = true;w.receive_hit(m.damage * 1.2, m)
			if m.p.distance_to(before) < float(ai.dash_speed) * dt * .4:
				m.stun = float(ai.stun);Enemies.cancel(m, 1.6);w.add_effect("ch4_stun", m.p, .7);w.fx.quake(w, m.p, .8);w.sound("ch4_heavy", .2);return
		if m.timer <= 0:Enemies.enter(m, "recover", ai.recover);m.cast = ""
		return
	if m.timer <= 0:
		if distance < float(ai.reach) + 6:
			m.cast = "sweep";m.charge = toward;Enemies.enter(m, "windup", ai.windup)
			if w.visible(m.p, 25):w.sound("ch4_mob_warn", .3)
			return
		if distance > 70 and distance < float(ai.ram_reach) and w.line_clear(m.p, w.player):
			m.cast = "ram";m.charge = toward;Enemies.enter(m, "windup", ai.ram_windup)
			if w.visible(m.p, 25):w.sound("ch4_stir", .3)
			return
	Enemies.travel(w, m, w.navigation(m.p), m.speed, dt)

func butcher_act(w, m: Dictionary, dt: float, distance: float, toward: Vector2):
	var ai: Dictionary = m.ai
	if m.phase == "windup":
		if m.cast == "lunge" and m.timer > float(ai.lunge_lock):m.charge = toward
		if m.timer <= 0:
			if m.cast == "lunge":
				m.hit_done = false;Enemies.enter(m, "attack", ai.lunge_attack);w.sound("ch4_butcher_grunt", .2)
			else:
				sweep(w, m, float(ai.reach) + 14, float(ai.arc), m.damage)
				w.sound("ch4_butcher_swing", .1);w.fx.shove(w, m.charge, 2.5, .15)
				Enemies.enter(m, "attack", ai.attack)
		return
	if m.phase == "attack":
		if m.cast == "lunge":
			var before: Vector2 = m.p
			Enemies.travel(w, m, m.charge, float(ai.dash_speed), dt)
			if not m.get("hit_done", false) and Geometry2D.get_closest_point_to_segment(w.player, before, m.p).distance_to(w.player) < m.radius + 8:
				m.hit_done = true;w.receive_hit(m.damage, m);w.sound("ch4_heavy", .2)
			if m.timer <= 0 or m.p.distance_to(before) < float(ai.dash_speed) * dt * .3:
				m.cast = "";Enemies.enter(m, "recover", ai.lunge_recover)
			return
		if m.timer <= 0:Enemies.enter(m, "recover", ai.recover)
		return
	if m.timer <= 0:
		if distance < float(ai.reach) + 8:
			m.cast = "cleave";m.charge = toward;Enemies.enter(m, "windup", ai.windup)
			w.sound("ch4_mob_warn", .3);return
		if w.clock >= m.get("lunge_ready", 0.0) and distance > 90 and distance < float(ai.lunge_range) and w.line_clear(m.p, w.player):
			m.lunge_ready = w.clock + float(ai.lunge_cooldown)
			m.cast = "lunge";m.charge = toward;Enemies.enter(m, "windup", ai.lunge_windup)
			w.sound("ch4_butcher_grunt", .3);return
	Enemies.travel(w, m, w.navigation(m.p), m.speed, dt)

func sweep(w, m: Dictionary, reach: float, arc: float, damage: float):
	w.add_effect("ch4h_sweep", m.p, .28, {"dir": m.charge, "reach": reach, "arc": arc})
	var offset: Vector2 = w.player - m.p
	if offset.length() < reach + 6 and absf(angle_difference(m.charge.angle(), offset.angle())) < arc * .5:
		w.receive_hit(damage, m)
