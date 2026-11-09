extends SceneTree
const World=preload("res://scripts/world.gd")
var checks=0
var failures=[]

func _initialize():run.call_deferred()

func check(ok:bool,label:String):
	checks+=1
	if ok:print("PASS: "+label)
	else:
		failures.append(label)
		push_error(label)

func advance(w,seconds:float,input:Vector2=Vector2.ZERO):
	for i in range(int(ceil(seconds*60))):w.step(1.0/60,input)

func run():
	var w=World.new(724)
	w.state="RUNNING"
	w.time=719.99
	w.step(1.0/60)
	check(w.state=="FINALE" and w.finale.active and not w.victory,"12:00 starts Herobrine instead of a victory")
	check(w.time==720 and w.player.distance_to(w.finale.CENTER)<140,"Arrival stages the player at the map center")
	check(w.mobs.is_empty() and w.loot.is_empty() and w.orbs.is_empty(),"Arrival clears pending ordinary combat rewards")
	var rng_state=w.rng.state
	advance(w,7)
	check(w.finale.phase=="storm" and not w.finale.strikes.is_empty(),"Herobrine summons telegraphed lightning")
	check(w.rng.state==rng_state,"Cinematic hazards do not consume combat RNG")
	var before=w.player
	w.step(.1,Vector2.RIGHT)
	check(w.player.distance_to(before)>1,"Player can move during the boss's attacks")
	var elapsed=w.finale.elapsed
	var clock=w.clock
	var strikes=JSON.stringify(w.finale.strikes)
	w.state="PAUSED"
	w.step(20,Vector2.RIGHT)
	check(w.finale.elapsed==elapsed and w.clock==clock and JSON.stringify(w.finale.strikes)==strikes,"Pause freezes the entire finale and its hazards")
	w.state="FINALE"
	advance(w,7)
	check(w.finale.phase=="inferno" and w.finale.scorch()==1 and not w.finale.waves.is_empty(),"Forest is dead when severe fire waves begin")
	advance(w,10.2)
	check(w.hp==0 and w.state=="FINALE" and w.finale.phase=="collapse","Canonical defeat continues into the scene rather than a normal results screen")
	before=w.player
	w.step(.1,Vector2.RIGHT)
	check(w.player==before,"Collapsed player cannot walk away from the portal")
	advance(w,2)
	check(w.finale.phase=="portal","A Nether portal opens after the defeat")
	advance(w,3)
	check(w.finale.phase=="fall" and w.finale.fall_progress()>0,"The player falls through the portal")
	advance(w,5)
	check(w.state=="RESULT" and w.finale.complete and not w.victory,"The chapter ends in the Nether teaser, never a boss victory")
	w.reset(724)
	check(not w.finale.active and not w.finale.complete and w.finale.strikes.is_empty() and w.finale.waves.is_empty(),"Retry fully resets the story scene and forest rendering state")
	for id in w.db.weapons:w.build[id]=8
	for id in w.db.passives:w.items[id]=5
	w.evolved={"sword":true,"bow":true,"trident":true}
	w.hp=1000000
	w.invulnerable=1000000
	w.finale.begin(w)
	w.invulnerable=1000000
	advance(w,34.2,Vector2.RIGHT)
	check(w.hp==0 and not w.victory and w.finale.complete,"Maximum gear and artificial invulnerability cannot defeat the canonical ending")
	w=World.new(724)
	w.state="RUNNING"
	w.time=240
	for i in range(200):w.spawn_wave(.5)
	check(w.mobs.any(func(m):return m.kind=="vindicator"),"Vindicator is reachable through the real wave spawner")
	w=World.new(724)
	w.state="RUNNING"
	w.spawn("vindicator",w.player+Vector2(20,0))
	var v=w.mobs[0]
	v.timer=0
	w.move_mobs(.01)
	w.animation.advance(w,.01)
	check(v.phase=="windup" and v.visual.state=="windup" and w.hp==20,"Vindicator visibly prepares its axe before damage")
	for i in range(32):w.move_mobs(1.0/60)
	check(w.hp==16 and v.phase=="attack","Axe contact deals the configured damage once")
	w.invulnerable=0
	for i in range(15):w.move_mobs(1.0/60)
	check(w.hp==16 and v.phase=="recover","Vindicator recovery causes no repeated contact damage")
	w=World.new(724)
	w.state="RUNNING"
	w.spawn("vindicator",w.player+Vector2(20,0))
	w.mobs[0].timer=0
	w.move_mobs(.01)
	w.player+=Vector2(0,90)
	for i in range(32):w.move_mobs(1.0/60)
	check(w.hp==20,"Player can dodge a locked vindicator swing")
	w=World.new(724)
	w.state="RUNNING"
	w.hp=0
	w.step(1.0/60)
	check(w.state=="RESULT" and not w.finale.active,"An ordinary earlier death keeps the normal retry flow")
	FileAccess.open("res://qa/chapter_results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("CHAPTER_RESULT ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
