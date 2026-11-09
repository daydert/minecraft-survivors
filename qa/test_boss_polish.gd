extends SceneTree
var checks=0
var failures=[]
const Nether=preload("res://scripts/nether_world.gd")
const Campaign=preload("res://scripts/campaign_world.gd")
const Lab=preload("res://scripts/boss_lab.gd")
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if ok:print("PASS: "+label)
	else:failures.append(label);push_error(label)
func advance(w, seconds: float):
	for i in range(ceili(seconds*60)):w.step(1.0/60)
func run():
	var c=Campaign.new(724);c.state="RUNNING";c.build={};c.finale.begin(c);advance(c,4.1)
	c.player=c.finale.CENTER+Vector2(450,300);c.hp=0;c.step(1.0/60)
	check(c.state=="FINALE" and c.finale.phase=="defeated" and not c.finale.first_stage_won,"Losing the optional first stage enters the Nether-fall scene")
	advance(c,1.3)
	check((c.player-c.camera()+Vector2(320,180)).distance_to(Vector2(320,192))<1,"A distant first-stage death keeps the fallen hero and portal in view")
	advance(c,8)
	check(c.state=="RESULT" and c.finale.complete and not c.victory,"The loss route completes the chapter instead of showing an ordinary defeat")
	check(not c.win_music and not c.sounds.has("boss_win"),"Losing to Herobrine never triggers victory audio")
	c.reset(724);c.build={};c.finale.begin(c);advance(c,4.1);c.finale.boss.hp=0;c.step(.02)
	check(c.finale.first_stage_won and c.finale.phase=="rising" and not c.win_music,"The optional win preserves the full second-stage scene without a victory stinger")
	while c.finale.phase!="rift":c.step(1.0/60)
	advance(c,5.1);var expansion=c.finale.blood_progress();c.step(.12)
	check(c.finale.phase=="vanish" and expansion>.99 and c.finale.blood_progress()==1,"The distortion stays fully expanded across the phase boundary")
	check(c.finale.blood_wipe()<.01,"The clearing wave begins at the same center without an abrupt reset")
	advance(c,1.5);var wipe=c.finale.blood_wipe();var clock=c.clock;c.state="PAUSED";c.step(4)
	check(wipe>.4 and wipe<.7 and c.finale.blood_wipe()==wipe and c.clock==clock,"Pause freezes the expanding black wave")
	c.state="FINALE";advance(c,2)
	check(c.finale.phase=="portal","The cleared distortion transitions to the dark portal scene")
	c.reset(724);c.state="RUNNING";c.hp=0;c.step(.02)
	check(c.state=="RESULT" and not c.finale.complete,"Death before the boss retains ordinary retry")
	for kind in ["ravager","brute"]:
		var w=Nether.new(724);w.state="RUNNING";w.spawn(kind,w.player);w.mobs.back().hp=0;w.resolve_deaths()
		check(not w.win_music and not w.sounds.has("boss_win"),kind+" does not play chapter-victory audio")
	var w=Nether.new(724);w.state="RUNNING";w.prepare_arena();w.stage="wither";w.build={}
	var boss=w.mobs[0];boss.p=w.player+Vector2(160,0);boss.attack_tick=10
	var before=boss.p;w.hook_target(boss,false);advance(w,.2)
	check(boss.p.distance_to(before)>30 and boss.p.distance_to(w.player)<before.distance_to(w.player),"Fishing physically moves the Wither toward the player")
	advance(w,.18)
	check(boss.pull_left==0 and boss.stun>0,"The boss is stunned after the pull finishes")
	var timer=boss.attack_tick;var at=boss.p;advance(w,.1)
	check(boss.p==at and boss.attack_tick==timer,"Stun freezes boss movement and attack preparation")
	var remaining=boss.stun;w.hook_target(boss,true)
	check(boss.stun==remaining and boss.pull_left==0,"Repeated hooks cannot lock a boss permanently")
	advance(w,2);w.hook_target(boss,true)
	check(boss.pull_left>0 or boss.stun>0,"Boss control becomes available again after its short resistance")
	boss.control_resist=0;boss.pull_left=0;boss.stun=0;boss.phase="rush";boss.timer=.5
	w.hook_target(boss,true)
	check(boss.phase=="recover" and boss.burst_left==0,"A successful hook interrupts the active boss attack")
	w=Nether.new(724);w.state="RUNNING";w.build={};w.magma.clear();w.spawn("zoglin",w.player+Vector2(100,0));var mob=w.mobs[0]
	w.hook_target(mob,true);advance(w,.25)
	check(mob.pull_left==0 and mob.stun>.8,"Evolved fishing gives ordinary enemies a longer stun after pulling")
	w=Nether.new(724);w.state="RUNNING";w.magma.clear();w.spawn("wither_skeleton",w.player);w.move_mobs(.01)
	check(w.player_wither>3,"A landed Wither-skeleton strike applies withering")
	w.mobs.clear();w.invulnerable=0;w.wither_tick=0;var hp=w.hp;w.update_fire(.01);var damage=hp-w.hp
	check(is_equal_approx(damage,1.5),"Withering deals actual periodic damage")
	w.items={"fire_resist":5};w.invulnerable=0;w.wither_tick=0;hp=w.hp;w.update_fire(.01)
	check(is_equal_approx(hp-w.hp,damage*.2),"Magma cream reduces withering by the same 80 percent as fire")
	w.state="PAUSED";var duration=w.player_wither;w.step(2)
	check(w.player_wither==duration,"Withering duration and ticks freeze on pause")
	w.reset(724);check(w.player_wither==0,"New runs clear withering")
	w.state="RUNNING";w.prepare_arena();w.stage="wither";w.build={};boss=w.mobs[0]
	w.encounter.passive(w,boss,3.99);check(w.projectiles.is_empty(),"The passive waits four active seconds")
	w.encounter.passive(w,boss,.01)
	check(w.projectiles.size()==4 and w.projectiles.all(func(b):return b.orbit_owner==boss.id),"Every four seconds the boss releases exactly four orbital heads")
	var directions=[]
	for b in w.projectiles:directions.append(roundi(b.dir.angle()/(PI/2)))
	check(directions.size()==4 and w.projectiles[0].dir.dot(w.projectiles[1].dir)<.001,"Orbital heads start in four perpendicular directions")
	var bullet=w.projectiles[0];var offset: Vector2=bullet.p-boss.p;boss.p+=Vector2(10,0);w.update_projectiles(.1)
	check(not (bullet.p-boss.p).is_equal_approx(offset) and bullet.age>.09,"Heads rotate around the moving boss")
	w.projectiles.clear();w.encounter.passive(w,boss,4)
	check(w.projectiles.size()==4,"The passive repeats independently of the main attack cycle")
	w.projectiles.clear();boss.rage=false;w.encounter.fire_mark(w,w.player,false)
	check(is_equal_approx(w.hazards.back().wait,.51),"First-phase fire gains exactly 150 ms of warning")
	w.encounter.fire_mark(w,w.player,true)
	check(is_equal_approx(w.hazards.back().wait,.45),"Second-phase fire also gains exactly 150 ms")
	w.projectiles.clear();w.encounter.begin(w,boss,"spiral");boss.timer=0;w.encounter.step(w,boss,.01);w.encounter.step(w,boss,.01)
	var angles=[]
	for b in w.projectiles:angles.append(fposmod(b.dir.angle(),TAU))
	angles.sort();var largest=0.0
	for i in range(angles.size()):largest=maxf(largest,fposmod(angles[(i+1)%angles.size()]-angles[i],TAU))
	check(w.projectiles.size()>=18 and largest<.36,"The barrage has no large permanent safe sector")
	check(w.projectiles.any(func(b):return b.turn>0) and w.projectiles.any(func(b):return b.turn<0),"Curving streams cross in both directions")
	var speeds={}
	for b in w.projectiles:speeds[b.speed]=true
	check(speeds.size()>2,"Different bullet speeds require weaving through the stream")
	for chapter in [1,2]:
		for preset in range(4):
			var test=Campaign.new(724) if chapter==1 else Nether.new(724)
			Lab.equip(test,preset)
			check(test.build.size()<=6 and test.items.size()<=8 and test.hp==20 and test.invulnerable==0 and test.build.values().all(func(v):return v==8),"Top loadout %d/%d respects slots and grants no god mode" % [chapter,preset])
			check(test.evolved.keys().all(func(id):return test.items.has(test.db.recipes[id].passive)),"Top loadout keeps valid evolution ingredients")
	FileAccess.open("res://qa/boss_polish_results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("BOSS_POLISH_RESULT ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
