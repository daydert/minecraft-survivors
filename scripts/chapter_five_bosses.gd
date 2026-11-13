extends RefCounted
## Chapter V mini-bosses. The Terminal copies Steve with his build and runs
## him against you; the Infinite Loop rolls the arena back every iteration
## while your past selves walk the path you took.
var terminal_done := false
var loop_done := false
var terminal: Dictionary = {}
var loop: Dictionary = {}
var ghosts: Array = []
## Typed lines on the terminal screen: {text, age}.
var screen: Array = []
var rewind_flash := 0.0

func reset():
	terminal_done = false;loop_done = false;terminal = {};loop = {};ghosts.clear();screen.clear();rewind_flash = 0.0

func data(w) -> Dictionary:return w.five.bosses
func active() -> bool:return not terminal.is_empty() or not loop.is_empty()

func type_line(text: String):
	screen.append({"text":text,"age":0.0})
	while screen.size() > 5:screen.pop_front()

func place(w, kind: String, at: Vector2):
	var p: Vector2 = at.clamp(Vector2(90, 90), Vector2(w.SIZE - 90, w.SIZE - 90))
	if not w.free_at(p, 10):p = w.player + Vector2(0, -60)
	w.super_spawn(kind, p)
	var m: Dictionary = w.mobs.back()
	m.code = true;m.glitch = false;m.owner = 0;m.depth = 0;m.shield = false;m.reveal = 0.0;m.broken = false;m.boss = true
	return m

func step(w, dt: float):
	rewind_flash = maxf(0, rewind_flash - dt)
	for l in screen:l.age += dt
	var d: Dictionary = data(w)
	if not terminal_done and terminal.is_empty() and w.time >= float(d.terminal.at):begin_terminal(w)
	if not loop_done and loop.is_empty() and terminal.is_empty() and w.time >= float(d.loop.at):begin_loop(w)
	if not terminal.is_empty():terminal_step(w, dt)
	if not loop.is_empty():loop_step(w, dt)

func mob(w, id: int):
	for m in w.mobs:
		if m.id == id and m.hp > 0:return m
	return null

# ------------------------------------------------------------------ the Terminal

func begin_terminal(w):
	var m = place(w, "terminal", w.player + Vector2(110, -20))
	m.locked = true
	terminal = {"id":m.id,"age":0.0,"clone":-1,"respawn":-1.0,"command":float(data(w).terminal.command_every),"built":false}
	screen.clear()
	type_line("> java -jar steve.jar")
	w.message = "ТЕРМИНАЛ";w.message_timer = 3.0
	w.sound("ch4_hb_glitch", .1)

func spawn_clone(w, hp_share: float):
	var t = mob(w, terminal.id)
	if t == null:return
	var d: Dictionary = data(w).terminal
	var m = place(w, "clone", t.p + Vector2(34, 26))
	m.hp = (float(w.db.data.mobs.clone.hp) + float(d.clone_hp_per_level) * w.level) * hp_share;m.max_hp = m.hp
	m.build = w.build.duplicate();m.cool = {};m.side = 1.0;m.learn = 0.0;m.lean = 0.0;m.learned = false;m.haste = 0.0;m.orbit = 0.0
	for id in m.build:m.cool[id] = 1.0 + 0.4 * m.cool.size()
	terminal.clone = m.id;t.locked = true
	type_line("> new Player(\"Steve (1)\")")
	w.add_effect("ch5_spawn", m.p, .4)
	w.sound("ch4_mirror", .1)

func terminal_step(w, dt: float):
	var d: Dictionary = data(w).terminal
	terminal.age += dt
	var t = mob(w, terminal.id)
	if t == null:return
	if not terminal.built and terminal.age >= float(d.boot):
		terminal.built = true;spawn_clone(w, 1.0)
	var c = mob(w, terminal.clone) if terminal.clone >= 0 else null
	if terminal.built and c == null and terminal.respawn < 0:
		terminal.respawn = float(d.respawn);t.locked = false
		type_line("> process exited with code 1")
		w.message = "Терминал открыт";w.message_timer = 2.0
	if terminal.respawn >= 0:
		terminal.respawn -= dt
		if terminal.respawn <= 0:terminal.respawn = -1.0;spawn_clone(w, float(d.respawn_hp))
	if c != null:
		terminal.command -= dt
		if terminal.command <= 0:
			terminal.command = float(d.command_every)
			match int(terminal.age / float(d.command_every)) % 3:
				0:
					c.p = w.move_actor(w.player - w.facing * 40.0, Vector2.ZERO, 6);w.add_effect("ch5_spawn", c.p, .4)
					type_line("> /tp @clone ^ ^ ^-2")
				1:c.haste = 4.0;type_line("> /effect give @clone speed")
				2:c.hp = minf(c.max_hp, c.hp + c.max_hp * .2);type_line("> /heal @clone")
			w.sound("ch4_hb_tick", .1)
		drive_clone(w, c, dt)

## The copy plays like you do: keeps its distance, circles, uses your gear.
func drive_clone(w, c: Dictionary, dt: float):
	var d: Dictionary = data(w).terminal
	var to: Vector2 = c.p.direction_to(w.player)
	var dist: float = c.p.distance_to(w.player)
	# It learns which way you circle it.
	var rel: Vector2 = w.tracked_velocity
	if rel.length() > 10:c.lean += signf(to.cross(rel)) * dt
	c.learn += dt
	if not c.learned and c.learn >= float(d.learn_after):
		c.learned = true;c.side = -1.0 if c.lean < 0 else 1.0
		type_line("> clone.learn(player.moves)")
		w.notes_add(c.p, "learned")
	c.haste = maxf(0, c.haste - dt)
	var speed: float = c.speed * (1.5 if c.haste > 0 else 1.0)
	var radial: float = clampf((dist - float(d.keep)) / 40.0, -1, 1)
	var move: Vector2 = (to * radial + to.orthogonal() * c.side * .8).normalized()
	var old: Vector2 = c.p
	c.p = w.move_actor(c.p, move * speed * dt + c.knock * dt, 6)
	c.knock = c.knock.move_toward(Vector2.ZERO, dt * 400)
	c.dir = to;c.moving = c.p.distance_squared_to(old) > .0001;c.visual.travel = c.p.distance_to(old)
	for id in c.build:
		c.cool[id] = c.cool.get(id, 1.0) - dt
		if c.cool[id] > 0:continue
		var s: Dictionary = w.db.stats(id, c.build[id], false, {})
		c.cool[id] = maxf(1.1, float(s.interval) * 1.6)
		clone_attack(w, c, id, to, dist)
	if c.build.has("barrier"):
		c.orbit += dt * 2.2
		for k in range(mini(4, int(c.build.barrier / 2) + 1)):
			var q: Vector2 = c.p + Vector2.from_angle(c.orbit + k * TAU / 3) * 30.0
			if q.distance_to(w.player) < 9:w.damage_player(2.0)

func clone_attack(w, c: Dictionary, id: String, to: Vector2, dist: float):
	match id:
		"sword","axe":
			if dist < 70:w.strike(w.player, 26.0, .55, 3.0)
			else:c.knock = to * 180.0
		"command_block","structure_block":w.strike(w.player, 36.0, .85, 4.0)
		"spawn_egg":
			for k in range(2):w.spawn("token", c.p + Vector2.from_angle(k * PI + c.orbit) * 18.0)
		"barrier":pass
		_:
			w.shoot(c.p + Vector2(0, -12), to * 165.0, 2.0, ">")
	c.visual.shot_age = 0.0

## Called from the world before damage reaches the copy or the screen.
func intercept(w, m: Dictionary, amount: float) -> bool:
	if m.kind == "terminal" and m.get("locked", false):
		m.flash = .05;return true
	if m.kind == "clone" and m.get("learned", false) and w.rng.randf() < float(data(w).terminal.evade):
		var side: Vector2 = m.p.direction_to(w.player).orthogonal() * m.side
		m.p = w.move_actor(m.p, side * 26.0, 6)
		w.notes_add(m.p, "evade")
		return true
	if m.kind == "loop_boss":loop.dealt = float(loop.get("dealt", 0.0)) + minf(amount, m.hp)
	return false

func boss_died(w, m: Dictionary):
	match m.kind:
		"terminal":
			terminal_done = true
			w.run_progress.award("terminal_original")
			var c = mob(w, terminal.clone) if terminal.clone >= 0 else null
			if c != null:c.hp = 0;c.xp = 0
			terminal = {}
			type_line("> exit")
			w.loot.append({"kind":"chest","p":m.p,"born":w.time})
			w.message = "Терминал закрыт";w.message_timer = 2.5
			w.sound("ch4_hb_shatter", .1)
		"loop_boss":
			loop_done = true;loop = {};ghosts.clear()
			w.run_progress.award("break_loop")
			w.loot.append({"kind":"chest","p":m.p,"born":w.time})
			w.message = "break;";w.message_timer = 2.5
			w.sound("ch4_hb_shatter", .1)

# ------------------------------------------------------------------ the Infinite Loop

func begin_loop(w):
	var m = place(w, "loop_boss", w.player + Vector2(0, -50))
	loop = {"id":m.id,"age":0.0,"intro_age":0.0,"i":0,"start_hp":m.hp,"dealt":0.0,"snap":{},"path":[],"tick":0.0,"ring":float(data(w).loop.ring_every)}
	snapshot(w)
	w.message = "while (true)";w.message_timer = 3.0
	w.sound("ch4_hb_glitch", .1)

func snapshot(w):
	loop.snap = {}
	for m in w.mobs:
		if m.hp > 0 and not m.get("boss", false):loop.snap[m.id] = m.p
	loop.start_hp = mob(w, loop.id).hp
	loop.dealt = 0.0
	loop.path = [w.player]

func loop_step(w, dt: float):
	var d: Dictionary = data(w).loop
	var b = mob(w, loop.id)
	if b == null:return
	loop.age += dt;loop.intro_age=float(loop.get("intro_age",0))+dt;loop.tick -= dt
	if loop.tick <= 0:
		loop.tick = .1;loop.path.append(w.player)
	loop.ring -= dt
	if loop.ring <= 0:
		loop.ring = float(d.ring_every)
		for k in range(int(d.ring)):w.shoot(b.p + Vector2(0, -14), Vector2.from_angle(k * TAU / int(d.ring) + loop.i * .2) * 90.0, 2.0, "i")
		w.sound("ch4_hb_tick", .1)
	for g in ghosts:
		g.t += dt
		var idx: int = mini(int(g.t / .1), g.path.size() - 1)
		var nxt: int = mini(idx + 1, g.path.size() - 1)
		var old: Vector2 = g.p
		g.p = g.path[idx].lerp(g.path[nxt], fposmod(g.t / .1, 1.0))
		g.dir = old.direction_to(g.p) if old.distance_to(g.p) > .01 else g.dir
		g.visual.gait += old.distance_to(g.p) / 82.0
		w.animation.set_pose(g.visual, "walk" if old.distance_to(g.p) > .01 else "idle", g.visual.gait)
		if g.p.distance_to(w.player) < 10:w.damage_player(float(d.ghost_damage))
	if loop.age >= float(d.iteration):iterate(w, b)

func iterate(w, b: Dictionary):
	var d: Dictionary = data(w).loop
	loop.age = 0.0;loop.i += 1
	if float(loop.dealt) < b.max_hp * float(d.break_share):
		b.hp = maxf(b.hp, float(loop.start_hp))
		type_line("continue;")
		w.message = "continue;";w.message_timer = 1.5
	else:
		w.message = "i++";w.message_timer = 1.2
	for m in w.mobs:
		if loop.snap.has(m.id) and m.hp > 0:m.p = loop.snap[m.id];m.knock = Vector2.ZERO
	w.shots.clear()
	ghosts.append({"path":loop.path.duplicate(),"t":0.0,"p":loop.path[0],"dir":Vector2.DOWN,"visual":w.animation.actor(),"n":loop.i})
	while ghosts.size() > int(d.ghosts):ghosts.pop_front()
	rewind_flash = .5
	w.sound("ch4_hb_teleport", .1)
	snapshot(w)
