extends SceneTree
## An immutable pre-change simulation is retained as a text fixture. It is never
## part of exports. Compare actual damage/movement/RNG every fixed combat tick.
const World=preload("res://scripts/world.gd")
var failures=[]
var ticks=0

func _initialize():run.call_deferred()

func signature(w) -> Array:
	var result=[w.state,w.hp,w.xp,w.level,w.kills,w.score,w.player,w.facing,w.rng.state,w.cooldowns,w.tasks.size(),w.orbs.size(),w.loot.size()]
	for m in w.mobs:result.append([m.id,m.kind,m.p,m.hp,m.timer,m.fuse,m.phase,m.burn])
	for p in w.projectiles:result.append([p.kind,p.p,p.damage,p.distance,p.returning,p.hit])
	for p in w.props:result.append(p.hp)
	return result

func run():
	var old=GDScript.new()
	old.source_code=FileAccess.get_file_as_string("res://qa/fixtures/world_before.gd.txt")
	if old.reload()!=OK:quit(1);return
	var reports=[]
	for scenario in ["sword","all_weapons","evolved"]:
		var a=old.new(724)
		var b=World.new(724)
		for w in [a,b]:
			# Core combat parity covers the existing enemies. New vindicator
			# waves and the authored chapter ending have dedicated tests.
			w.spawn_credit=-1000000
			w.state="RUNNING"
			if scenario!="sword":
				w.time=580
				for id in w.db.weapons:w.build[id]=8
				for id in w.db.passives:w.items[id]=5
			if scenario=="evolved":w.evolved={"sword":true,"bow":true,"trident":true}
			for i in range(90):w.spawn(["zombie","spider","skeleton","creeper","slime","elite","ravager"][i%7],w.player+Vector2.from_angle(i*2.399)*float(40+i%9*18))
		for frame in range(1800):
			var movement=Vector2.from_angle(frame/240.0)
			for w in [a,b]:
				w.invulnerable=1
				w.xp=0
				if w.state in ["LEVEL_UP","CHEST"]:w.state="RUNNING";w.pending_chest.clear()
				w.step(1.0/60,movement)
				w.sounds.clear()
			ticks+=1
			if signature(a)!=signature(b):
				failures.append({"scenario":scenario,"tick":frame})
				push_error("Combat changed: "+scenario+" tick "+str(frame))
				break
		reports.append({"scenario":scenario,"kills":b.kills,"time":b.time,"mobs":b.mobs.size()})
		print("PARITY ",scenario," ",ticks," ticks ",failures)
	FileAccess.open("res://qa/combat_parity.json",FileAccess.WRITE).store_string(JSON.stringify({"ticks":ticks,"failures":failures,"scenarios":reports},"  "))
	quit(0 if failures.is_empty() else 1)
