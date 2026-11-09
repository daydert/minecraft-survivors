extends SceneTree

var failures: Array = []
var checks = 0
var report: Array = []
const World = preload("res://scripts/world.gd")

func _initialize():
	run.call_deferred()

func check(condition: bool, label: String):
	checks += 1
	if not condition:
		failures.append(label)
		push_error("FAIL: "+label)
	else: print("PASS: "+label)

func fresh():
	var w = World.new(724)
	w.state = "RUNNING"
	return w

func run():
	var w = fresh()
	check(w.db.required_xp(1)==5 and w.db.required_xp(10)==32,"XP formula")
	check(w.build.size()==1 and w.build.sword==1 and w.hp==20,"Starting inventory and health")
	var a = w.player
	w.step(1.0/60,Vector2(1,1))
	check(absf(w.player.distance_to(a)-82.0/60)<0.0002,"Normalized diagonal movement")
	var t = w.time
	for state in ["PAUSED","LEVEL_UP","CHEST","MENU","RESULT"]:
		w.state=state
		w.step(2,Vector2.RIGHT)
		check(w.time==t,"Time frozen in "+state)
	w.state="RUNNING"
	w.damage_player(2)
	w.damage_player(6)
	check(w.hp==18,"Crowd hit invulnerability")
	w.invulnerable=0
	w.items={"armor":5}
	w.damage_player(0.1)
	check(w.hp==17,"Armor retains minimum 1 HP damage")
	w.items={"blaze":5,"redstone":5,"amethyst":5}
	var s=w.db.stats("sword",1,false,w.items)
	check(is_equal_approx(s.damage,12) and is_equal_approx(s.interval,0.7) and is_equal_approx(s.radius,63),"Additive passive bonuses applied once")
	w=fresh()
	for i in range(10):
		for id in w.db.weapons:w.apply_upgrade(id)
		for id in w.db.passives:w.apply_upgrade(id)
	check(w.build.size()==6 and w.items.size()==6,"Six independent weapon and passive slots")
	check(w.build.values().all(func(v):return v==8) and w.items.values().all(func(v):return v==5),"Weapon VIII and passive V limits")
	check(w.make_choices().size()==2 and w.make_choices().has("apple") and w.make_choices().has("emerald"),"Fallback rewards without empty cards or duplicates")
	w=fresh()
	var unique=true
	var current=true
	for i in range(200):
		var options=w.make_choices()
		unique=unique and options.size()==3 and options[0]!=options[1] and options[1]!=options[2] and options[0]!=options[2]
		current=current and options.has("sword")
	check(unique,"200 weighted choices contain no repeated options")
	check(current,"At least one choice improves current build")
	w.xp=30
	w.next_level()
	while w.state=="LEVEL_UP":w.choose(0)
	check(w.level==4 and w.xp==6,"Multiple level-ups preserve excess XP")
	for id in ["sword","bow","trident"]:
		w=fresh()
		w.build[id]=8
		w.items[w.db.recipes[id].passive]=1
		check(w.evolution_candidates(359.99).is_empty(),id+" rejects an old chest")
		check(w.evolution_candidates(360).has(id),id+" eligible with a new chest")
		w.open_chest({"born":360.0})
		check(w.evolved.has(id) and w.items.size()==1,id+" evolves in slot and retains passive")
		check(not w.eligible().has(id),id+" evolution no longer offered")
	w=fresh()
	w.build.sword=8
	check(w.evolution_candidates(400).is_empty(),"Evolution needs its passive")
	w=fresh()
	w.spawn("elite",w.player+Vector2(40,0))
	w.time=365
	w.mobs[0].hp=0
	w.resolve_deaths()
	check(w.loot[0].born==365,"Elite chest creation time uses kill time")
	w=fresh()
	w.spawn("zombie",w.player+Vector2(25,0))
	w.rebuild_hit_grid()
	w.swing(Vector2.RIGHT,w.db.stats("sword",1))
	check(w.mobs[0].hp==0,"One swing deals exactly one hit")
	w=fresh()
	w.spawn("elite",w.player+Vector2(35,0))
	w.rebuild_hit_grid()
	var hit={}
	for i in range(4):w.add_effect("fangs",w.player+Vector2(25+i*4,0),0.6,{"delay":0.0,"radius":15.0,"damage":9.0,"hit":hit})
	w.update_effects(0.1)
	w.update_effects(0.1)
	check(w.mobs[0].hp==171,"Overlapping fang pairs share a hit set")
	w.add_effect("cloud",w.mobs[0].p,3,{"radius":30.0,"damage":2.0})
	w.add_effect("cloud",w.mobs[0].p,3,{"radius":30.0,"damage":4.0})
	w.poison_timer=0
	w.update_effects(0.01)
	check(w.mobs[0].hp==167,"Overlapping poison uses strongest tick")
	w=fresh()
	w.spawn("elite",w.player+Vector2(40,0))
	w.rebuild_hit_grid()
	w.fire_projectile("arrow",w.player,Vector2.RIGHT,{"speed":10000,"damage":6,"range":280,"radius":3,"pierce":0},false)
	w.update_projectiles(1.0/60)
	check(w.mobs[0].hp==174,"Fast projectile checks complete movement segment")
	w=fresh()
	w.spawn("elite",w.player+Vector2(40,0))
	w.rebuild_hit_grid()
	w.fire_projectile("trident",w.player,Vector2.RIGHT,w.db.stats("trident",1),false)
	for i in range(200):w.update_projectiles(1.0/60)
	check(w.mobs[0].hp==160,"Trident hits once outbound and once returning")
	w=fresh()
	w.spawn("creeper",w.player+Vector2(20,0))
	w.move_mobs(0.1)
	w.player+=Vector2(120,0)
	for i in range(60):w.move_mobs(1.0/60)
	check(w.mobs[0].hp<=0 and w.hp==20,"Creeper fuse persists after player escapes")
	w=fresh()
	w.spawn("slime",w.player+Vector2(40,0))
	w.mobs[0].hp=0
	w.resolve_deaths()
	check(w.mobs.size()==2 and w.mobs.all(func(m):return m.kind=="small_slime" and m.xp==0),"Slime splits into exactly two non-XP children")
	for i in range(260):w.spawn("zombie",w.player+Vector2(100,0))
	check(w.normal_count()==250,"Ordinary mob limit includes slime children")
	w=fresh()
	for i in range(30):w.spawn("skeleton",w.player+Vector2(180+i,0))
	check(w.mobs.size()==12,"Skeleton cap also survives camera movement")
	w=fresh()
	for i in range(310):w.drop_xp(Vector2(600+i,600),1)
	var total=0
	for o in w.orbs:total+=o.value
	check(w.orbs.size()==300 and total==310,"XP limit merges without losing experience")
	w=fresh()
	w.xp=5
	w.pending_chest={"born":0.0,"p":w.player}
	w.step(1.0/60)
	check(w.state=="LEVEL_UP","Level-up precedes pending chest")
	w.choose(0)
	check(w.state=="CHEST","Chest opens after queued level-ups")
	w=fresh()
	w.time=719.99
	w.step(1.0/60)
	check(not w.victory and w.state=="FINALE" and w.time==720 and w.finale.active,"Living player enters the chapter finale at 12:00")
	w=fresh()
	w.time=719.99
	w.hp=1
	w.spawn("zombie",w.player)
	w.step(1.0/60)
	check(not w.victory and w.state=="RESULT" and w.hp<=0,"Damage wins tie against sunrise")
	w=fresh()
	var spawns_ok=true
	for i in range(100):
		if w.spawn("zombie"):
			spawns_ok=spawns_ok and not w.visible(w.mobs.back().p) and w.free_at(w.mobs.back().p)
	check(spawns_ok,"100 spawns remain off screen and outside obstacles")
	for i in range(10):
		w.reset(i+10)
		w.step(0.1,Vector2.RIGHT)
	check(w.level==1 and w.kills==0 and w.time<1 and w.mobs.is_empty() and w.projectiles.is_empty() and w.orbs.is_empty() and w.loot.is_empty() and w.evolved.is_empty(),"Ten restarts fully clear run state")
	var result={"checks":checks,"failures":failures,"godot":Engine.get_version_info().string}
	FileAccess.open("res://qa/unit_results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("RESULT: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
