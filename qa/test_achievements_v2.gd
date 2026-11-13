extends SceneTree
## Actual chapter events, failure cases and profile migration for the new book.
const WORLDS=[preload("res://scripts/overworld_world.gd"),preload("res://scripts/nether_world.gd"),preload("res://scripts/end_world.gd"),preload("res://scripts/chapter_four_world.gd"),preload("res://scripts/chapter_five_world.gd")]
const Store=preload("res://scripts/achievements.gd")
var checks:=0
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if ok:print("PASS: ",label)
	else:failures.append(label);push_error(label)
func fresh(chapter: int):
	var w=WORLDS[chapter-1].new();w.reset(724);w.state="RUNNING"
	if chapter>1:w.stage="survival";w.sword_drop={}
	w.build={};w.items={};w.mobs.clear();w.loot.clear();w.orbs.clear()
	return w
func snapshot(w) -> String:
	return var_to_str([w.clock,w.time,w.hp,w.player,w.rng.state,w.mobs,w.projectiles,w.effects,w.sounds,w.build,w.items,w.loot,w.orbs])
func run():
	var w=fresh(1)
	for mark in w.landmarks:
		if mark.kind=="ruin_1":continue
		w.player=mark.p;w.track_progress(.01)
	check(w.run_progress.awarded.has("trailblazer"),"I: visiting the four landmark types earns exploration")
	w=fresh(1);w.player=w.landmarks[0].p
	for i in range(10):w.track_progress(.01)
	check(not w.run_progress.awarded.has("trailblazer"),"Repeated visits cannot replace missing landmark types")
	var history=var_to_str(w.run_progress.visited);w.state="PAUSED";w.player=w.landmarks[2].p;w.step(10)
	check(var_to_str(w.run_progress.visited)==history,"Pause does not discover landmarks")
	w=fresh(2);w.prepare_arena();w.mobs.clear();w.stage="wither";w.spawn("wither",w.player+Vector2(0,-100))
	var m: Dictionary=w.mobs.back();w.hook_target(m,false)
	for i in range(4):w.hook_target(m,false)
	check(w.run_progress.counters.get("boss_angler",0)==1,"II: rejected hooks during boss protection do not count")
	for i in range(2):m.control_resist=0;w.hook_target(m,false)
	check(w.run_progress.awarded.has("boss_angler"),"II: three accepted hooks catch the Wither")
	w=fresh(3);w.prepare_arena();w.stage="survival";w.mobs.clear()
	w.solid_grid.clear();w.blocked.clear()
	var edge:=Vector2.ZERO
	for y in range(20,108):
		for x in range(20,100):
			var p:=Vector2(x*16+8,y*16+8)
			if w.on_land(p) and not w.on_land(p+Vector2(120,0)):edge=p
	w.player=edge-Vector2(20,0);w.build={"knockback_stick":8};w.facing=Vector2.RIGHT
	for i in range(5):
		w.spawn("endermite",edge);m=w.mobs.back();m.hp=999;m.speed=0;w.cooldowns.knockback_stick=0;w.rebuild_hit_grid();w.update_attacks(.01);m.knock=Vector2(1200,0);w.move_mobs(.1)
	check(w.run_progress.awarded.has("void_bouncer"),"III: five actual launched falls earn the knockback challenge")
	var falls: int=w.run_progress.counters.get("void_bouncer",0);w.move_mobs(.1)
	check(w.run_progress.counters.get("void_bouncer",0)==falls,"Dead enemies cannot be counted twice")
	w.run_progress.reset(3);w.evolved={"knockback_stick":true}
	w.spawn("endermite",edge);m=w.mobs.back();m.hp=999;m.speed=0;w.cooldowns.knockback_stick=0;w.rebuild_hit_grid();w.update_attacks(.01);m.knock=Vector2(1200,0)
	w.spawn("endermite",edge-Vector2(3,0));var child: Dictionary=w.mobs.back();child.hp=999;child.speed=0;w.rebuild_hit_grid();w.move_mobs(.1)
	check((child.hp<=0 and w.run_progress.counters.get("void_bouncer",0)==2) or w.run_progress.stick_launches.has(child.id),"The evolved stick keeps credit through a collision after the first enemy falls")
	w.run_progress.reset(3);w.build={};w.spawn("endermite",edge);m=w.mobs.back();m.speed=0
	w.time=500;w.gust={"phase":"warn","timer":0.0,"dir":Vector2.RIGHT,"age":0.0,"count":0};w.update_gust(.01);m.knock=Vector2(1200,0);w.move_mobs(.1)
	check(m.hp<=0 and w.run_progress.counters.get("void_bouncer",0)==0,"A void gust kill is not credited to the knockback stick")
	w=fresh(3);w.fall_age=.86;w.items.shulker_shell=1;w.last_safe=w.player;w.step(.01)
	check(w.run_progress.awarded.has("shell_rescue") and w.hp==20,"III: a ready shell really prevents fall damage")
	w=fresh(3);w.fall_age=.86;w.items.shulker_shell=1;w.shell_cooldown=10;w.last_safe=w.player;w.step(.01)
	check(not w.run_progress.awarded.has("shell_rescue") and w.hp<20,"A shell on cooldown is not a rescue")
	w=fresh(4);w.read_note();w.read_note()
	check(w.run_progress.events.count("read_note")==1,"IV: reading the actual note awards once")
	w.encounters.launch_golem(w)
	for node in w.encounters.nodes:w.hurt(node,9999)
	w.encounters.enter(w.encounters.golem,"walk",1);w.encounters.update_golem(w,.01)
	check(w.encounters.rescued and w.run_progress.awarded.has("free_golem"),"IV: breaking the three tethers frees the golem")
	w=fresh(4)
	for i in range(20):
		w.spawn("flayed_zombie",w.player+Vector2(30,0));m=w.mobs.back();m.hp=1
		w.arsenal.hit(w,m,999,"minecart",Vector2.ZERO,true)
	check(w.run_progress.awarded.has("cart_rider"),"IV: twenty lethal minecart impacts earn the cart challenge")
	w.arsenal.hit(w,m,999,"minecart",Vector2.ZERO,true)
	check(w.run_progress.counters.cart_rider==20,"Repeated impacts on a corpse add no cart kills")
	w=fresh(4)
	for i in range(20):
		w.spawn("flayed_zombie",w.player+Vector2(30,0));m=w.mobs.back();m.hp=1
		w.rebuild_hit_grid();w.heal_undead(m.p,40,999)
	check(w.run_progress.awarded.has("healing_undead"),"IV: healing damage kills twenty actual undead enemies")
	w.spawn("flayed_zombie",w.player+Vector2(30,0));m=w.mobs.back();m.allied=true;m.hp=1;w.rebuild_hit_grid();w.heal_undead(m.p,40,999)
	check(m.hp==1 and w.run_progress.counters.healing_undead==20,"Healing leaves allies and their achievement count alone")
	w=fresh(4);w.ending.phase="door";w.ending.age=float(w.ending.data.door.duration);w.ending.step_door(w,.01)
	check(w.run_progress.awarded.has("chapter_four") and w.victory,"IV completion is awarded at the actual door ending")
	w=fresh(5);w.bosses.begin_terminal(w);m=w.mobs.back();m.locked=false;w.hurt(m,99999);w.resolve_deaths()
	check(w.run_progress.awarded.has("terminal_original"),"V: the actual Terminal death earns its hidden achievement")
	w.bosses.begin_loop(w);m=w.mobs.back();w.hurt(m,99999);w.resolve_deaths()
	check(w.run_progress.awarded.has("break_loop"),"V: the actual Infinite Loop death earns its hidden achievement")
	w=fresh(5);w.begin_double();m=w.mobs.back();w.hurt(m,99999);w.resolve_deaths()
	check(w.run_progress.awarded.has("own_controls") and w.hijack.is_empty(),"V: killing the live hijacker returns control and earns the achievement")
	w=fresh(5);w.begin_double();m=w.mobs.back();w.hijack.left=0;w.hurt(m,99999);w.resolve_deaths()
	check(not w.run_progress.awarded.has("own_controls"),"An expired hijack cannot award timely recovery")
	w=fresh(5);var n=w.notch;n.start_code(w);var f=n.finale;f.lang_index=1;f.start_duel()
	f.submit("\n".join(f.SOLUTIONS.python));n.code(w,.01)
	check(w.run_progress.awarded.has("first_compile"),"V: a correct first submission earns the code challenge")
	w=fresh(5);n=w.notch;n.start_code(w);f=n.finale;f.lang_index=1;f.start_duel();f.submit("nonsense");f.submit("\n".join(f.SOLUTIONS.python));n.code(w,.01)
	check(not w.run_progress.awarded.has("first_compile"),"An earlier rejected program cannot be erased by later success")
	w=fresh(5);n=w.notch;n.start_ut(w);n.ut_state="end";n.ut_timer=0;n.battle(w,.01,Vector2.ZERO)
	check(w.run_progress.awarded.has("heart_whole"),"V: finishing the heart battle without hits earns its challenge")
	w=fresh(5);n=w.notch;n.start_ut(w);w.invulnerable=0;n.hurt_soul(w);w.hp=20;n.ut_state="end";n.ut_timer=0;n.ut_freeze=0;n.battle(w,.01,Vector2.ZERO)
	check(not w.run_progress.awarded.has("heart_whole"),"Healing the heart does not erase the hit history")
	w=fresh(5);w.notch.begin_bad_end(w)
	check(not w.run_progress.awarded.has("chapter_five"),"A bad ending does not complete the good branch")
	w.notch.finish(w)
	check(w.run_progress.awarded.has("chapter_five") and w.victory,"V: the completed flight awards chapter completion")
	w=fresh(4);w.run_progress.enabled=false;w.read_note();w.run_progress.count("cart_rider",1);w.run_progress.finish(w)
	check(w.run_progress.events.is_empty(),"Disabled tracking blocks new counters, discoveries and completion")
	w.run_progress.reset(4)
	check(w.run_progress.counters.is_empty() and w.run_progress.visited.is_empty(),"A new attempt clears all new counters and visits")
	for chapter in range(1,6):
		var a=fresh(chapter);var b=fresh(chapter);b.run_progress.enabled=false
		for i in range(30):a.step(1.0/60,Vector2.RIGHT);b.step(1.0/60,Vector2.RIGHT)
		check(snapshot(a)==snapshot(b),"Tracking leaves combat, clocks and RNG unchanged in chapter %d" % chapter)
	var store=Store.new();var file="user://qa_achievements_v2_%d.json" % OS.get_process_id();store.load_profile(file)
	for item in store.catalog:
		var display: Dictionary=store.display_entry(item.id)
		if store.is_secret(item):check(display.name=="???" and display.description=="Секретное достижение" and display.icon=="unknown","Hidden story content: "+item.id)
	store.unlock("chapter_one");store.unlock("bad_ending");var loaded=Store.new();loaded.load_profile(file)
	check(loaded.unlocked.size()==2 and loaded.display_entry("bad_ending").name=="Тестирование завершено","Existing profile version preserves old IDs and reveals only earned stories")
	for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute(ProjectSettings.globalize_path(file+suffix))
	FileAccess.open("res://qa/achievements_v2/results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("ACHIEVEMENTS_V2_RESULT ",checks," checks; ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
