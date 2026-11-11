extends RefCounted
## Notch's fighting game, in the spirit of old Mortal Kombat and Smash:
## rounds to two wins, specials on Q + direction (Smash style), throws,
## juggles in the air, a combo counter, a super meter and heavy impact.
## Units are blocks; the stage is -STAGE..STAGE, the floor is y = 0.
const STAGE := 6.5
const GRAVITY := 26.0
const JUMP := 10.5
const WALK := 4.2
const ROUND_TIME := 60.0
## start/active/recover (s), damage, reach, knock (x), launch (y), stun, hitstop, kind.
const MOVES := {
	"jab": {"start":.06, "active":.07, "recover":.12, "damage":4.0, "reach":1.2, "knock":1.0, "stun":.3, "stop":.05},
	"jab2": {"start":.06, "active":.07, "recover":.14, "damage":5.0, "reach":1.25, "knock":1.4, "stun":.32, "stop":.06},
	"hook": {"start":.1, "active":.09, "recover":.26, "damage":9.0, "reach":1.4, "knock":2.5, "launch":7.5, "stun":.5, "stop":.1},
	"kick": {"start":.16, "active":.1, "recover":.3, "damage":10.0, "reach":1.65, "knock":5.5, "stun":.45, "stop":.09},
	"sweep": {"start":.14, "active":.12, "recover":.34, "damage":8.0, "reach":1.6, "knock":1.0, "launch":3.0, "stun":.7, "low":true, "stop":.08},
	"launcher": {"start":.12, "active":.1, "recover":.32, "damage":8.0, "reach":1.25, "knock":.8, "launch":11.0, "stun":.6, "stop":.1},
	"air": {"start":.05, "active":.3, "recover":.1, "damage":7.0, "reach":1.25, "knock":2.0, "launch":2.0, "stun":.35, "stop":.07},
	"spin": {"start":.08, "active":.2, "recover":.15, "damage":9.0, "reach":1.5, "knock":4.0, "launch":4.0, "stun":.4, "stop":.08},
	"uppercut": {"start":.05, "active":.18, "recover":.45, "damage":14.0, "reach":1.35, "knock":1.5, "launch":13.0, "stun":.7, "stop":.14, "armor":true},
	"tnt": {"start":.22, "active":.05, "recover":.32},
	"wall": {"start":.2, "active":.05, "recover":.3},
	"pearl": {"start":.18, "active":.05, "recover":.2},
	"throw": {"start":.1, "active":.08, "recover":.4, "damage":12.0, "reach":1.0, "knock":5.0, "launch":6.0, "stun":.8, "stop":.12, "grab":true},
	"swing": {"start":.12, "active":.1, "recover":.26, "damage":13.0, "reach":1.95, "knock":5.0, "stun":.45, "stop":.1},
	"code": {"start":.3, "active":.05, "recover":.35},
	"beam": {"start":.45, "active":.4, "recover":.4},
	"super": {"start":.6, "active":1.6, "recover":.5}}
const LINES := ["System.exit(0);", "return null;", "int hp = 0;", "while (true)", "steve.kill();", "throw new Error();"]
var state := "intro"
var age := 0.0
var round := 1
var wins: Array = [0, 0]
var clock := ROUND_TIME
var fighters: Array = []
var bolts: Array = []
var sparks: Array = []
var walls: Array = []
var falls: Array = []
var hitstop := 0.0
var slow := 0.0
var zoom := 0.0
var winner := -1
var announce := ""
var announce_age := 0.0
var jump_held := false
var input_dir := Vector2.ZERO
var ai_timer := 1.0
var teleport_timer := 7.0
var undo_used := false
var ai := true
var mode := "fight"
var items: Array = []
var grabbed: Array = []
var wired := false
var events: Array = []

func reset(which := "fight"):
	mode = which;items.clear();wins = [0, 0];round = 1;undo_used = false
	if mode == "fists":
		for i in range(4):items.append({"x":-5.0 + i * 3.4, "text":LINES[i], "holder":-1, "uses":0})
	start_round()

func start_round():
	state = "intro";age = 0.0;clock = ROUND_TIME;bolts.clear();sparks.clear();walls.clear();falls.clear()
	hitstop = 0.0;slow = 0.0;zoom = 0.0;winner = -1;jump_held = false;ai_timer = 1.2;teleport_timer = 7.0
	fighters = [make(-2.5, 1.0, 100.0, "steve"), make(2.5, -1.0, 100.0, "notch")]
	say("РАУНД %d" % round if mode == "fight" else "БЕЗ ПРАВИЛ")

func say(text: String):announce = text;announce_age = 0.0

func make(x: float, face: float, hp: float, who: String) -> Dictionary:
	return {"who":who, "x":x, "y":0.0, "vx":0.0, "vy":0.0, "face":face, "hp":hp, "max":hp, "move":"", "t":0.0, "hit":false,
		"chain":0, "chain_window":0.0, "block":false, "stun":0.0, "flash":0.0, "walk":0.0, "cool":0.0, "glitch":0.0, "ko":false,
		"meter":0.0, "combo":0, "combo_t":0.0, "down":0.0, "air_hits":0, "armor":false}

func steve() -> Dictionary:return fighters[0]
func notch() -> Dictionary:return fighters[1]
func other(f: Dictionary) -> Dictionary:return notch() if f.who == "steve" else steve()

func phase_of(f: Dictionary) -> String:
	if f.move.is_empty():return ""
	var m: Dictionary = MOVES[f.move]
	if f.t < m.start:return "start"
	if f.t < m.start + m.active:return "active"
	return "recover"

func start(f: Dictionary, move: String) -> bool:
	if f.ko or f.stun > 0 or f.down > 0:return false
	if not f.move.is_empty():
		var chain_ok: bool = phase_of(f) == "recover" and ((f.move == "jab" and move == "jab2") or (f.move == "jab2" and move == "hook") or (f.move in ["jab2", "hook"] and move in ["kick", "launcher", "uppercut", "tnt"]))
		if not chain_ok:return false
	f.move = move;f.t = 0.0;f.hit = false;f.block = false
	f.armor = MOVES[move].get("armor", false)
	return true

func dir_of(f: Dictionary) -> String:
	if input_dir.y < -.5:return "up"
	if input_dir.y > .5:return "down"
	if input_dir.x * f.face < -.5:return "back"
	if input_dir.x * f.face > .5:return "forward"
	return ""

## Player buttons: "punch" (Space), "kick" (E), "special" (Q + direction),
## "grab" (F: throw, or pick up a line in the brawl), "super" (R).
func press(action: String):
	if state != "fight":return
	var s: Dictionary = steve()
	var d: String = dir_of(s)
	match action:
		"punch":
			if s.y > .01:start(s, "air");return
			if held(0) != null:
				if start(s, "swing"):
					var it = held(0);it.uses -= 1
					if it.uses <= 0:it.holder = -1;it.x = s.x
				return
			if d == "down":start(s, "sweep");return
			if d == "up":start(s, "launcher");return
			var next: String = "jab" if s.move != "jab" and s.move != "jab2" else ("jab2" if s.move == "jab" else "hook")
			start(s, next)
		"kick":
			if s.y > .01:start(s, "spin")
			else:start(s, "kick")
		"special":
			if mode != "fight" or s.cool > 0:return
			var move: String = {"up":"uppercut", "down":"wall", "back":"pearl"}.get(d, "tnt")
			if start(s, move):s.cool = {"uppercut":.9, "wall":4.0, "pearl":3.0, "tnt":1.6}[move]
		"grab":
			if mode == "fists":grab(0)
			else:start(s, "throw")
		"super":
			if mode == "fight" and s.meter >= 100.0 and start(s, "super"):s.meter = 0.0;events.append("super_steve");zoom = 1.0

func held(i: int):
	for it in items:
		if it.holder == i:return it
	return null

func grab(i: int) -> bool:
	var f: Dictionary = fighters[i]
	if held(i) != null or f.y > 0 or not f.move.is_empty():return false
	for it in items:
		if it.holder == -1 and absf(it.x - f.x) < .9:
			it.holder = i;it.uses = 3;grabbed.append(i);return true
	return false

## The finishing wire, once Notch is down in the brawl.
func finish_blow():
	if state == "finisher" and age > .6:state = "wire";age = 0.0;wired = true

func step(dt: float, movement: Vector2) -> Array:
	events = []
	input_dir = movement
	for g in grabbed:events.append("grab")
	grabbed.clear()
	if wired:wired = false;events.append("wire")
	age += dt;announce_age += dt
	zoom = maxf(0, zoom - dt * 1.5)
	if hitstop > 0:
		hitstop -= dt;return events
	if slow > 0:
		slow -= dt;dt *= .3
	match state:
		"intro":
			if age >= 1.3 and announce.begins_with("РАУНД"):say("В БОЙ!")
			if age >= 2.2:state = "fight";age = 0.0
		"finisher":
			for f in fighters:body(f, dt)
		"wire":
			for f in fighters:body(f, dt)
			if age >= 2.8:state = "done"
		"fight", "ko":
			if state == "fight":
				clock = maxf(0, clock - dt) if mode == "fight" else clock
				control(steve(), movement, dt)
				if ai:think(notch(), steve(), dt)
			for f in fighters:body(f, dt)
			for i in range(2):
				var a: Dictionary = fighters[i];var b: Dictionary = fighters[1 - i]
				if not a.ko and not b.ko and a.move.is_empty() and a.y <= 0:a.face = 1.0 if b.x > a.x else -1.0
				resolve(a, b)
			push_apart()
			update_bolts(dt)
			update_falls(dt)
			if state == "fight":check_end()
			elif age >= 3.0:next_round()
	for sp in sparks:sp.age += dt
	sparks = sparks.filter(func(sp):return sp.age < .45)
	for wl in walls:wl.life -= dt
	walls = walls.filter(func(wl):return wl.life > 0)
	return events

func check_end():
	var loser := -1
	for i in range(2):
		if fighters[i].hp <= 0:loser = i
	if loser < 0 and clock <= 0:loser = 0 if steve().hp < notch().hp else 1
	if loser < 0:return
	if mode == "fists" and loser == 1:
		var n: Dictionary = notch();n.hp = 0.0;n.move = "";n.stun = 99.0;n.vx = 0.0
		steve().move = "";steve().vx = 0.0
		winner = 0;state = "finisher";age = 0.0;say("ДОБЕЙ ЕГО!");events.append("finisher");return
	fighters[loser].ko = true;fighters[loser].move = "";winner = 1 - loser;wins[winner] += 1;state = "ko";age = 0.0;slow = .9;zoom = 1.0
	var w: Dictionary = fighters[winner]
	say("K.O." if clock > 0 else "ВРЕМЯ!")
	if w.hp >= w.max and winner == 0:say("БЕЗУПРЕЧНО")
	events.append("ko")

func next_round():
	if wins[0] >= 2 or wins[1] >= 2 or mode == "fists":
		state = "done";winner = 0 if wins[0] >= 2 else 1;return
	round += 1
	var keep: Array = [steve().meter, notch().meter]
	start_round()
	steve().meter = keep[0];notch().meter = keep[1]

func control(s: Dictionary, movement: Vector2, dt: float):
	var grounded: bool = s.y <= 0.0
	var free: bool = s.move.is_empty() and s.stun <= 0 and s.down <= 0
	s.block = grounded and free and movement.x * s.face < -.5
	var crouch: bool = grounded and free and movement.y > .5
	if movement.y < -.5 and not jump_held and grounded and free:
		s.vy = JUMP;s.vx = movement.x * WALK * 1.15;events.append("jump")
	jump_held = movement.y < -.5
	if grounded and free and not crouch:
		s.vx = movement.x * WALK * (.6 if s.block else 1.0)
	elif grounded and (not free or crouch):
		s.vx = move_toward(s.vx, 0, dt * 30)
	s.crouch = crouch

## Notch: spaces, mixes strings, blocks, throws code, deletes the floor,
## glitches behind you, punishes whiffs, undoes damage once, and supers.
func think(n: Dictionary, s: Dictionary, dt: float):
	if n.stun > 0 or not n.move.is_empty() or n.down > 0:return
	var dist: float = absf(s.x - n.x)
	n.block = false
	n.face = 1.0 if s.x > n.x else -1.0
	if mode == "fight" and n.meter >= 100.0 and dist < 5.0:
		start(n, "super");n.meter = 0.0;events.append("super_notch");zoom = 1.0;return
	if mode == "fight" and not undo_used and n.hp < 35.0:
		undo_used = true;n.hp = minf(n.max, n.hp + 18.0);n.glitch = .6;events.append("undo");say("Ctrl+Z");return
	if s.move in ["jab", "jab2", "hook", "kick", "launcher", "sweep"] and phase_of(s) == "start" and dist < 2.0 and int(age * 7) % 10 < 5:
		n.block = true;n.vx = 0.0;return
	if not s.move.is_empty() and phase_of(s) == "recover" and dist < 1.6:
		start(n, "hook" if int(age * 5) % 2 == 0 else "throw");return
	if s.y > .6 and dist < 2.2 and n.y <= 0:
		start(n, "launcher");return
	for b in bolts:
		if b.owner == "steve" and absf(b.x - n.x) < 2.0 and n.y <= 0:
			n.vy = JUMP;n.vx = signf(s.x - n.x) * 3.0;return
	teleport_timer -= dt
	if mode == "fight" and teleport_timer <= 0 and n.y <= 0:
		teleport_timer = 6.0
		n.glitch = .35;n.x = clampf(s.x - s.face * 1.3, -STAGE, STAGE);n.face = -s.face
		events.append("teleport");return
	if mode == "fists" and held(1) == null and int(age * 5) % 9 == 0 and grab(1):return
	ai_timer -= dt
	if dist > 3.0:
		if ai_timer <= 0 and mode == "fight":
			ai_timer = 2.2
			start(n, "beam" if int(age) % 3 == 0 else "code");return
		n.vx = signf(s.x - n.x) * WALK * .85
	elif dist > 1.2:
		n.vx = signf(s.x - n.x) * WALK
	else:
		n.vx = 0.0
		if ai_timer <= 0:
			ai_timer = .45
			var roll: int = int(age * 13) % 8
			if held(1) != null and roll < 4:
				if start(n, "swing"):
					var it = held(1);it.uses -= 1
					if it.uses <= 0:it.holder = -1;it.x = n.x
			elif roll < 4:start(n, "jab")
			elif roll < 5:start(n, "throw")
			elif roll < 7:start(n, "kick")
			else:start(n, "sweep")
	if n.move == "jab" and int(age * 9) % 3 == 0:pass

func body(f: Dictionary, dt: float):
	f.flash = maxf(0, f.flash - dt);f.stun = maxf(0, f.stun - dt);f.cool = maxf(0, f.cool - dt)
	f.glitch = maxf(0, f.glitch - dt);f.combo_t = maxf(0, f.combo_t - dt)
	if f.combo_t <= 0:f.combo = 0
	if f.down > 0:
		f.down -= dt
		if f.down <= 0:events.append("getup")
	if not f.move.is_empty():
		f.t += dt
		var m: Dictionary = MOVES[f.move]
		var ph: String = phase_of(f)
		if f.move == "air" and ph == "active":f.vx = f.face * 6.5;f.vy = minf(f.vy, -8.0)
		if f.move == "uppercut" and ph == "active" and not f.hit:f.vy = maxf(f.vy, 8.0);f.vx = f.face * 1.5
		if not f.hit and ph == "active":
			match f.move:
				"tnt":
					f.hit = true;bolts.append({"owner":f.who, "kind":"tnt", "x":f.x + f.face * .6, "y":1.3, "vx":f.face * 5.5, "vy":5.5, "damage":12.0, "age":0.0});events.append("throw_tnt")
				"code":
					f.hit = true;bolts.append({"owner":f.who, "kind":"code", "x":f.x + f.face * .8, "y":.9, "vx":f.face * 7.5, "vy":0.0, "damage":9.0, "age":0.0});events.append("cast_notch")
				"wall":
					f.hit = true;walls.append({"owner":f.who, "x":f.x + f.face * 1.1, "life":3.0, "hp":2});events.append("wall")
				"pearl":
					f.hit = true;var o: Dictionary = other(f);f.glitch = .25
					f.x = clampf(o.x - o.face * 1.0, -STAGE, STAGE);f.face = -o.face if o.face != 0 else f.face;events.append("pearl")
				"beam":
					f.hit = true;bolts.append({"owner":f.who, "kind":"beam", "x":f.x + f.face * .6, "y":.12, "vx":f.face * 9.0, "vy":0.0, "damage":10.0, "age":0.0, "low":true});events.append("beam")
				"super":
					if f.who == "notch":
						f.hit = true
						for k in range(9):falls.append({"x":-STAGE + 1.4 * k + fmod(age * 3, 1.0), "y":9.0 + k % 3 * 1.5, "vy":0.0, "wait":.25 * (k % 4), "damage":9.0})
		if f.move == "super" and f.who == "steve" and ph == "active":
			# A diamond-sword flurry: several hits while the opponent is in reach.
			var o: Dictionary = other(f)
			var hits: int = int((f.t - m.start) / .2)
			if hits > f.air_hits and absf(o.x - f.x) < 2.2:
				f.air_hits = hits;land(o, 5.0, f.face, {"stun":.5, "knock":.4, "launch":3.0 if hits < 7 else 9.0, "stop":.06}, true, f)
				f.x = clampf(f.x + f.face * .2, -STAGE, STAGE)
		if f.t >= m.start + m.active + m.recover or (f.move == "air" and f.y <= 0 and f.t > .1):
			f.move = "";f.air_hits = 0;f.armor = false
	if f.y <= 0 and (f.stun > 0 or f.ko or f.down > 0 or (f.who == "notch" and not ai)):f.vx = move_toward(f.vx, 0, dt * 16)
	f.vy -= GRAVITY * dt
	f.x = clampf(f.x + f.vx * dt, -STAGE, STAGE)
	for wl in walls:
		if wl.owner != f.who and absf(f.x - wl.x) < .45:f.x = wl.x - signf(wl.x - f.x) * .45
	f.y += f.vy * dt
	if f.y <= 0:
		if f.vy < -6:
			events.append("thud")
			if f.stun > .3 and not f.ko and f.down <= 0:f.down = .55;f.vy = 3.5;f.y = 0.01;return
		f.y = 0.0;f.vy = 0.0
		if f.move.is_empty() and f.stun <= 0 and absf(f.vx) > WALK * 1.2:f.vx = move_toward(f.vx, 0, dt * 25)
	if f.ko:f.vx = move_toward(f.vx, 0, dt * 6)
	f.walk += absf(f.vx) * dt

func resolve(a: Dictionary, b: Dictionary):
	if a.move.is_empty() or a.hit or phase_of(a) != "active":return
	var m: Dictionary = MOVES[a.move]
	if not m.has("damage"):return
	var dx: float = (b.x - a.x) * a.face
	if dx < -.2 or dx > m.reach or absf(b.y - a.y) > 1.4 or b.down > 0:return
	if m.get("grab", false):
		if b.y > .2 or b.ko:return
		a.hit = true;b.block = false
		b.x = clampf(a.x - a.face * .4, -STAGE, STAGE)
		land(b, m.damage, -a.face, m, true, a);events.append("throw")
		return
	a.hit = true
	land(b, m.damage, a.face, m, a.move in ["hook", "kick", "launcher", "uppercut", "swing", "sweep"], a)

func land(b: Dictionary, damage: float, from_face: float, m: Dictionary, heavy: bool, by = null):
	var low: bool = m.get("low", false)
	var blocked: bool = b.block and b.face != from_face and not m.get("grab", false) and not (low and not b.get("crouch", false))
	if b.armor and not blocked and not heavy:damage *= .5;blocked = false
	var scale: float = 1.0
	if by != null:
		by.combo = by.combo + 1 if by.combo_t > 0 else 1;by.combo_t = 1.1
		scale = maxf(.45, 1.0 - .1 * maxi(0, by.combo - 2))
	if blocked:
		b.hp -= damage * .12;b.vx = from_face * 2.4;events.append("block")
		if by != null:by.meter = minf(100.0, by.meter + damage * .5)
	else:
		b.hp -= damage * scale;b.stun = float(m.get("stun", .3));b.move = "";b.flash = .12;b.armor = false
		b.vx = from_face * float(m.get("knock", 2.0))
		if m.has("launch") or b.y > 0:b.vy = maxf(b.vy * .3, float(m.get("launch", 3.0)))
		events.append("hit_heavy" if heavy else "hit")
		if by != null:by.meter = minf(100.0, by.meter + damage * 1.2);b.meter = minf(100.0, b.meter + damage * .8)
		if by != null and by.combo >= 3:events.append("combo")
		if heavy:zoom = maxf(zoom, .5)
	hitstop = float(m.get("stop", .06)) * (.6 if blocked else 1.0)
	sparks.append({"x":b.x - from_face * .2, "y":b.y + 1.1, "age":0.0, "blocked":blocked, "heavy":heavy})

func push_apart():
	var a: Dictionary = fighters[0];var b: Dictionary = fighters[1]
	var d: float = b.x - a.x
	if absf(d) < .7 and absf(a.y - b.y) < 1.4:
		var fix: float = (.7 - absf(d)) / 2.0 * (1.0 if d >= 0 else -1.0)
		a.x = clampf(a.x - fix, -STAGE, STAGE);b.x = clampf(b.x + fix, -STAGE, STAGE)

func update_bolts(dt: float):
	for i in range(bolts.size() - 1, -1, -1):
		var bo: Dictionary = bolts[i]
		bo.age += dt;bo.x += bo.vx * dt
		if bo.kind == "tnt":
			bo.vy -= GRAVITY * .6 * dt;bo.y += bo.vy * dt
		var target: Dictionary = notch() if bo.owner == "steve" else steve()
		var wall_hit := false
		for wl in walls:
			if wl.owner != bo.owner and absf(wl.x - bo.x) < .4:wall_hit = true;wl.hp -= 1;wl.life = wl.life if wl.hp > 0 else 0.0
		var hit: bool = absf(target.x - bo.x) < .55 and target.y < bo.y + .2 and target.y + 1.8 > bo.y - .3 and not target.ko and target.down <= 0
		if bo.kind == "tnt" and (hit or bo.y <= 0 or wall_hit):
			explode(bo);bolts.remove_at(i);continue
		if wall_hit:
			events.append("block");bolts.remove_at(i);continue
		if hit:
			land(target, bo.damage, signf(bo.vx), {"stun":.4, "knock":3.0, "launch":2.5 if bo.kind == "beam" else 0.0, "low":bo.get("low", false), "stop":.07}, false, fighters[0] if bo.owner == "steve" else fighters[1])
			bolts.remove_at(i)
		elif absf(bo.x) > STAGE + 2:bolts.remove_at(i)

func explode(bo: Dictionary):
	events.append("boom")
	sparks.append({"x":bo.x, "y":maxf(.4, bo.y), "age":0.0, "blocked":false, "heavy":true, "boom":true})
	var target: Dictionary = notch() if bo.owner == "steve" else steve()
	if absf(target.x - bo.x) < 1.4 and target.y < 2.0:
		land(target, bo.damage, signf(target.x - bo.x) if target.x != bo.x else 1.0, {"stun":.6, "knock":4.0, "launch":8.0, "stop":.12}, true, fighters[0] if bo.owner == "steve" else fighters[1])
	zoom = maxf(zoom, .6)

func update_falls(dt: float):
	for i in range(falls.size() - 1, -1, -1):
		var fl: Dictionary = falls[i]
		if fl.wait > 0:fl.wait -= dt;continue
		fl.vy -= GRAVITY * dt;fl.y += fl.vy * dt
		var s: Dictionary = steve()
		if absf(s.x - fl.x) < .6 and fl.y < s.y + 1.8 and fl.y > s.y:
			land(s, fl.damage, 1.0 if s.x > fl.x else -1.0, {"stun":.5, "knock":2.0, "launch":5.0, "stop":.1}, true, notch());falls.remove_at(i);continue
		if fl.y <= 0:events.append("thud");sparks.append({"x":fl.x, "y":.2, "age":0.0, "blocked":true, "heavy":false});falls.remove_at(i)
