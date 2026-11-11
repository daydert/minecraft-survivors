extends RefCounted
## Notch's side-view fighting game. Units are blocks; the stage is a line
## from -STAGE to STAGE, the floor is y = 0. Pure simulation; the 3D view
## reads it every frame.
const STAGE := 6.5
const GRAVITY := 26.0
const JUMP := 10.5
const WALK := 4.2
const MOVES := {
	"punch": {"start":.07, "active":.08, "recover":.14, "damage":6.0, "reach":1.25, "knock":1.6, "stun":.28},
	"punch3": {"start":.1, "active":.09, "recover":.26, "damage":9.0, "reach":1.4, "knock":4.5, "stun":.4},
	"kick": {"start":.17, "active":.1, "recover":.3, "damage":11.0, "reach":1.65, "knock":4.0, "stun":.42},
	"dive": {"start":.05, "active":.4, "recover":.12, "damage":9.0, "reach":1.2, "knock":3.0, "stun":.35},
	"uppercut": {"start":.12, "active":.12, "recover":.4, "damage":12.0, "reach":1.3, "knock":3.0, "stun":.5, "launch":9.0},
	"cast": {"start":.32, "active":.05, "recover":.35, "damage":0.0, "reach":0.0, "knock":0.0, "stun":0.0}}
var state := "intro"
var age := 0.0
var fighters: Array = []
var bolts: Array = []
var sparks: Array = []
var hitstop := 0.0
var slow := 0.0
var winner := -1
var jump_held := false
var ai_timer := 1.0
var ai_plan := ""
var teleport_timer := 7.0
## Tests can hold Notch still.
var ai := true

func reset():
	state = "intro";age = 0.0;bolts.clear();sparks.clear();hitstop = 0.0;slow = 0.0;winner = -1;jump_held = false
	ai_timer = 1.2;ai_plan = "";teleport_timer = 7.0
	fighters = [make(-2.5, 1.0, 100.0, "steve"), make(2.5, -1.0, 120.0, "notch")]

func make(x: float, face: float, hp: float, who: String) -> Dictionary:
	return {"who":who, "x":x, "y":0.0, "vx":0.0, "vy":0.0, "face":face, "hp":hp, "max":hp, "move":"", "t":0.0, "hit":false,
		"chain":0, "chain_window":0.0, "block":false, "stun":0.0, "flash":0.0, "walk":0.0, "cool":0.0, "glitch":0.0, "ko":false}

func steve() -> Dictionary:return fighters[0]
func notch() -> Dictionary:return fighters[1]

func phase_of(f: Dictionary) -> String:
	if f.move.is_empty():return ""
	var m: Dictionary = MOVES[f.move]
	if f.t < m.start:return "start"
	if f.t < m.start + m.active:return "active"
	return "recover"

func start(f: Dictionary, move: String) -> bool:
	if f.ko or f.stun > 0 or (not f.move.is_empty() and phase_of(f) != "recover"):return false
	if not f.move.is_empty() and phase_of(f) == "recover" and not (f.move in ["punch"] and move in ["punch", "punch3"]):return false
	f.move = move;f.t = 0.0;f.hit = false;f.block = false
	return true

## Player buttons: "punch", "kick", "special".
func press(action: String):
	if state != "fight":return
	var s: Dictionary = steve()
	match action:
		"punch":
			if s.y > .01:
				start(s, "dive");return
			var next := "punch"
			if s.chain_window > 0 and s.chain >= 2:next = "punch3"
			if start(s, next):
				s.chain = (s.chain + 1) if next == "punch" else 0
				s.chain_window = .45
		"kick":start(s, "kick")
		"special":
			if s.cool <= 0 and start(s, "cast"):s.cool = 2.4

func step(dt: float, movement: Vector2) -> Array:
	var events: Array = []
	age += dt
	if hitstop > 0:
		hitstop -= dt;return events
	if slow > 0:
		slow -= dt;dt *= .3
	match state:
		"intro":
			if age >= 2.2:state = "fight";age = 0.0
		"fight","ko":
			if state == "fight":
				control(steve(), movement, dt)
				if ai:think(notch(), steve(), dt, events)
			for f in fighters:body(f, dt, events)
			for i in range(2):
				var a: Dictionary = fighters[i];var b: Dictionary = fighters[1 - i]
				if not a.ko and not b.ko:
					a.face = 1.0 if b.x > a.x else -1.0 if a.move.is_empty() or a.y > 0 else a.face
				resolve(a, b, events)
			push_apart()
			update_bolts(dt, events)
			if state == "fight":
				for i in range(2):
					if fighters[i].hp <= 0:
						fighters[i].ko = true;fighters[i].move = "";winner = 1 - i;state = "ko";age = 0.0;slow = .9
						events.append("ko")
			elif age >= 2.6:state = "done"
	for sp in sparks:sp.age += dt
	sparks = sparks.filter(func(sp):return sp.age < .3)
	return events

func control(s: Dictionary, movement: Vector2, dt: float):
	var grounded: bool = s.y <= 0.0
	s.block = grounded and movement.y > .5 and s.move.is_empty() and s.stun <= 0
	if movement.y < -.5 and not jump_held and grounded and s.move.is_empty() and s.stun <= 0:
		s.vy = JUMP;s.vx = movement.x * WALK * 1.1
	jump_held = movement.y < -.5
	if grounded and s.move.is_empty() and s.stun <= 0 and not s.block:
		s.vx = movement.x * WALK
	elif grounded and (not s.move.is_empty() or s.block):
		s.vx = move_toward(s.vx, 0, dt * 30)

## Notch: walks in, mixes combos, blocks some, throws code from range,
## punishes jump-ins and now and then glitches behind you.
func think(n: Dictionary, s: Dictionary, dt: float, events: Array):
	if n.stun > 0 or not n.move.is_empty():return
	var dist: float = absf(s.x - n.x)
	n.block = false
	if s.move in ["punch", "punch3", "kick", "dive"] and phase_of(s) == "start" and dist < 2.0 and int(age * 7) % 10 < 4:
		n.block = true;n.vx = 0.0;return
	if s.y > .8 and dist < 2.0 and n.y <= 0:
		start(n, "uppercut");return
	teleport_timer -= dt
	if teleport_timer <= 0 and n.y <= 0:
		teleport_timer = 6.5
		n.glitch = .35;n.x = clampf(s.x - s.face * 1.3, -STAGE, STAGE);n.face = -s.face
		events.append("teleport");return
	ai_timer -= dt
	if dist > 3.2:
		if ai_timer <= 0:
			ai_timer = 2.6
			start(n, "cast");return
		n.vx = signf(s.x - n.x) * WALK * .8
	elif dist > 1.25:
		n.vx = signf(s.x - n.x) * WALK
	else:
		n.vx = 0.0
		if ai_timer <= 0:
			ai_timer = .55
			var roll: int = int(age * 13) % 6
			if roll < 3:
				if start(n, "punch"):n.chain += 1
				if n.chain >= 3:n.chain = 0;start(n, "punch3")
			elif roll < 5:start(n, "kick")
			else:n.vx = -signf(s.x - n.x) * WALK

func body(f: Dictionary, dt: float, events: Array):
	f.flash = maxf(0, f.flash - dt);f.stun = maxf(0, f.stun - dt);f.cool = maxf(0, f.cool - dt)
	f.chain_window = maxf(0, f.chain_window - dt);f.glitch = maxf(0, f.glitch - dt)
	if f.chain_window <= 0 and f.who == "steve":f.chain = 0
	if not f.move.is_empty():
		f.t += dt
		var m: Dictionary = MOVES[f.move]
		if f.move == "dive":
			f.vx = f.face * 7.0;f.vy = minf(f.vy, -9.0)
		if f.move == "cast" and not f.hit and f.t >= m.start:
			f.hit = true
			bolts.append({"owner":f.who, "x":f.x + f.face * .8, "y":.9 if f.who == "steve" else .7, "vx":f.face * (9.0 if f.who == "steve" else 7.0), "damage":8.0 if f.who == "steve" else 10.0, "age":0.0})
			events.append("cast_" + f.who)
		if f.move == "uppercut" and phase_of(f) == "active" and f.y <= 0:f.vy = 6.0
		if f.t >= m.start + m.active + m.recover or (f.move == "dive" and f.y <= 0 and f.t > .1):f.move = ""
	f.vy -= GRAVITY * dt
	f.x = clampf(f.x + f.vx * dt, -STAGE, STAGE)
	f.y += f.vy * dt
	if f.y <= 0:
		if f.vy < -2 and f.ko:events.append("thud")
		f.y = 0.0;f.vy = 0.0
		if f.move.is_empty() and f.stun <= 0 and absf(f.vx) > WALK * 1.2:f.vx = move_toward(f.vx, 0, dt * 25)
	if f.ko:f.vx = move_toward(f.vx, 0, dt * 6)
	f.walk += absf(f.vx) * dt

func resolve(a: Dictionary, b: Dictionary, events: Array):
	if a.move.is_empty() or a.hit or phase_of(a) != "active" or a.move == "cast":return
	var m: Dictionary = MOVES[a.move]
	var dx: float = (b.x - a.x) * a.face
	if dx < -.2 or dx > m.reach or absf(b.y - a.y) > 1.3:return
	a.hit = true
	land(b, m.damage, a.face, m, events, a.move in ["punch3", "kick", "uppercut"])

func land(b: Dictionary, damage: float, from_face: float, m: Dictionary, events: Array, heavy: bool):
	var blocked: bool = b.block and b.face != from_face
	if blocked:
		b.hp -= damage * .15;b.vx = from_face * 2.0
		events.append("block")
	else:
		b.hp -= damage;b.stun = float(m.get("stun", .3));b.move = "";b.flash = .1
		b.vx = from_face * float(m.get("knock", 2.0))
		if m.has("launch"):b.vy = float(m.launch)
		events.append("hit_heavy" if heavy else "hit")
	hitstop = .09 if heavy and not blocked else .05
	sparks.append({"x":b.x - from_face * .2, "y":b.y + 1.1, "age":0.0, "blocked":blocked})

func push_apart():
	var a: Dictionary = fighters[0];var b: Dictionary = fighters[1]
	var d: float = b.x - a.x
	if absf(d) < .7 and absf(a.y - b.y) < 1.4:
		var fix: float = (.7 - absf(d)) / 2.0 * (1.0 if d >= 0 else -1.0)
		a.x = clampf(a.x - fix, -STAGE, STAGE);b.x = clampf(b.x + fix, -STAGE, STAGE)

func update_bolts(dt: float, events: Array):
	for i in range(bolts.size() - 1, -1, -1):
		var bo: Dictionary = bolts[i]
		bo.age += dt;bo.x += bo.vx * dt
		var target: Dictionary = notch() if bo.owner == "steve" else steve()
		if absf(target.x - bo.x) < .5 and target.y < bo.y + .1 and target.y + 1.8 > bo.y - .3 and not target.ko:
			land(target, bo.damage, signf(bo.vx), {"stun":.35, "knock":3.0}, events, false)
			bolts.remove_at(i)
		elif absf(bo.x) > STAGE + 2:bolts.remove_at(i)
