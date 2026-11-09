extends SceneTree
## Actual chapter A contracts: collisions, telegraphs, ordinary weapon damage,
## exact pause/overlay restoration, isolation and deterministic simulation.
const FW = preload("res://scripts/chapter_four_world.gd")
const NW = preload("res://scripts/nether_world.gd")
var checks := 0
var failures: Array = []
func _initialize():run.call_deferred()
func check(ok: bool, label: String):
	checks += 1
	if ok:print("PASS: ",label)
	else:failures.append(label);push_error(label)
func advance(w, seconds: float, movement := Vector2.ZERO):
	for i in range(ceili(seconds*60)):w.step(1.0/60,movement)
func fresh():
	var w = FW.new();w.reset(724);w.stage = "survival";w.build = {};w.state = "RUNNING";w.db.data.chapter_four.exploration_only=true
	return w
func run():
	var w = FW.new();w.reset(724)
	check(w.chapter_number()==4 and w.stage=="arrival" and not w.finale.active,"IV has its own arrival and never starts the old finale")
	check(w.db.data.duration==720 and w.db.data.chapter_four.content_stage=="C","Chapter C owns its stage metadata and duration")
	var kinds: Array = w.landmarks.map(func(m):return m.kind)
	check(["house","crucifix","growth","growth_big","torch","pyramid","note"].all(func(k):return kinds.has(k)),"All seven environment landmarks exist")
	check(w.threats.size()>8 and not w.pools.is_empty(),"Destructible hazards and blood pools exist")
	var start: Vector2 = w.player
	advance(w,1,Vector2.RIGHT)
	check(w.player==start and w.time==0,"Arrival does not move the hero or start the survival clock")
	w.state="PAUSED";var before: float=w.clock;var cam: Vector2=w.camera();advance(w,.5)
	check(w.clock==before and w.camera()==cam,"Arrival camera and animation freeze exactly on pause")
	w.state="RUNNING";advance(w,4)
	check(w.stage=="survival","Arrival releases control")
	w=fresh();w.rebuild_hit_grid()
	var note := Vector2(w.terrain.note[0],w.terrain.note[1])
	check(w.free_at(note,6) and w.flow[int(note.y/32)*64+int(note.x/32)]>=0,"Note has a collision-free route from spawn")
	for pool in w.terrain.pools:
		var p := Vector2(pool.p[0],pool.p[1])
		check(w.in_blood(p) and w.free_at(p,6),"Blood surface is walkable and agrees with the terrain mask")
	var pyramid := Vector2(w.terrain.pyramid[0],w.terrain.pyramid[1])
	check(not w.free_at(pyramid-Vector2(0,25),6),"Pyramid footprint blocks movement")
	var q: Vector2=w.move_actor(pyramid+Vector2(0,40),Vector2(0,-150),6)
	check(q.y>pyramid.y,"Long movement cannot tunnel through the pyramid")
	w.player=note;w.step(1.0/60)
	check(w.note_pending and not w.note_read and w.items.is_empty(),"Finding the note requests an overlay without using a passive slot")
	w.player=Vector2(600,780);w.update_aura()
	var base=w.db.stats("sword",1,false,{})
	check(w.aura_state=="despair","Pillars cause despair before the note")
	w.read_note();var rage=w.db.stats("sword",1,false,{})
	check(w.aura_state=="rage" and rage.damage>base.damage and rage.interval<base.interval,"The note changes actual damage and attack interval")
	w.player=Vector2(1024,1024);w.update_aura();var normal=w.db.stats("sword",1,false,{})
	check(w.aura_state=="none" and normal.damage<rage.damage and normal.damage>base.damage,"Aura is local and clears when leaving the pillars")
	w=fresh();var growth=w.threats.filter(func(m):return m.kind=="growth")[0]
	check(not w.free_at(growth.p,6),"A living growth has a solid footprint")
	w.player=growth.p+Vector2(70,0);growth.timer=0;var hp: float=w.hp
	w.update_threats(.01)
	check(growth.attack=="windup" and w.blood_shots.is_empty() and w.hp==hp,"Growth visibly prepares before firing")
	for i in range(70):w.update_threats(1.0/60)
	check(w.blood_shots.size()==5,"Growth fires a bounded five-clot fan")
	w=fresh();growth=w.threats.filter(func(m):return m.kind=="growth")[0]
	w.player=growth.p+Vector2(24,0);w.facing=Vector2.LEFT;w.rebuild_hit_grid();w.damage_owner="sword"
	w.swing(Vector2.LEFT,w.db.stats("sword",8,false,{}))
	check(growth.hp<growth.max_hp and w.damage_by.get("sword",0)>0,"A normal sword hits growth and attributes its damage")
	w.hurt(growth,999)
	check(w.free_at(growth.p,6),"Destroying growth removes its collision and opens the ground")
	w=fresh();growth=w.threats.filter(func(m):return m.kind=="growth")[0]
	w.player=growth.p+Vector2(90,0);w.rebuild_hit_grid()
	w.fire_projectile("arrow",w.player,Vector2.LEFT,w.db.stats("bow",8,false,{}),false)
	for i in range(60):w.update_projectiles(1.0/60)
	check(growth.hp<growth.max_hp,"An ordinary bow projectile hits environmental enemies")
	w=fresh();var torches=w.threats.filter(func(m):return m.kind=="torch" and m.p.y>1400)
	var torch=torches[0];var other=torches[1]
	w.player=torch.p.lerp(other.p,.5);torch.timer=0;w.update_threats(.01)
	check(torch.attack=="windup" and w.effects.is_empty(),"Cursed chain warns before dealing damage")
	w.hurt(other,999);w.update_threats(1.1)
	check(w.hp==20 and not w.effects.any(func(e):return e.kind=="ch4_arc" and e.p==torch.p),"Destroying an endpoint interrupts a charged chain")
	w=fresh();torches=w.threats.filter(func(m):return m.kind=="torch" and m.p.y>1400)
	torch=torches[0];other=torches[1];w.player=torch.p.lerp(other.p,.5);torch.timer=0
	w.update_threats(.01);w.update_threats(1.1)
	check(w.hp<20 and w.effects.any(func(e):return e.kind=="ch4_arc"),"The chain effect and collision share the same segment")
	w=fresh();w.player=Vector2(1300,640);w.hand_cooldown=0;w.update_hand(.01)
	check(not w.blood_hand.is_empty() and w.hp==20,"Blood hand starts with a harmless shadow")
	w.player+=Vector2(60,0);w.update_hand(1.5)
	check(w.hp==20 and w.held==0,"Moving away from the marked shadow avoids the hand")
	w=fresh();w.player=Vector2(1300,640);w.hand_cooldown=0;w.update_hand(.01);w.update_hand(1.5)
	check(w.hp<20 and w.held>0,"Waiting on the marked blood surface permits a short grab")
	w=fresh();w.hand_cooldown=0;w.update_hand(5)
	check(w.blood_hand.is_empty(),"Hands cannot appear on dry land")
	w=fresh();w.player=Vector2(1300,640);w.hand_cooldown=0;w.update_hand(.01)
	var snapshot=JSON.stringify([w.clock,w.blood_hand,w.threats,w.hp]);w.state="PAUSED";advance(w,2,Vector2.RIGHT)
	check(JSON.stringify([w.clock,w.blood_hand,w.threats,w.hp])==snapshot,"Pause freezes every hazard timer and damage")
	var a=fresh();var b=fresh()
	for i in range(1200):
		var direction=Vector2.from_angle(i*.013)
		a.step(1.0/60,direction);b.step(1.0/60,direction)
	check(JSON.stringify([a.player,a.hp,a.clock,a.threats,a.blood_shots,a.rng.state])==JSON.stringify([b.player,b.hp,b.clock,b.threats,b.blood_shots,b.rng.state]),"Same seed and inputs reproduce the whole chapter A simulation")
	w.reset(725)
	check(not w.note_read and w.blood_hand.is_empty() and w.blood_shots.is_empty() and w.aura_state=="none","Reset clears the note, hazards and aura")
	var n=NW.new();n.reset(724)
	check(not n.db.data.has("chapter_four") and n.chapter_number()==2,"New chapter data does not leak into the Nether")
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game.qa_mode="test_four";game.set_physics_process(false)
	check(not game.four_assets_loaded and not game.textures.has("ch4_ground"),"Menu does not load chapter IV textures")
	game.action("chapter_4");game.world.stage="survival"
	check(game.is_four() and game.four_assets_loaded and not game.end_assets_loaded,"Chapter selection loads only IV's large resources")
	game.world.state="LEVEL_UP";game.router.open("ch4_note",game.world)
	game.router.open("stats",game.world);game.router.close(game.world)
	check(game.screen=="ch4_note" and game.world.state=="PAUSED","A nested overlay returns to the paused note")
	game.close_four_note()
	check(game.screen.is_empty() and game.world.state=="LEVEL_UP" and game.world.note_read,"Closing the note restores the exact previous level-up state")
	game.start_chapter(3);game.world.stage="chapter_four";game.world.state="RESULT";game.action("chapter_4")
	check(game.is_four() and game.world.stage=="arrival","Continuing after III starts IV's arrival")
	game.action("menu")
	check(not game.four_assets_loaded and not game.textures.has("ch4_ground"),"Returning to the menu releases IV's textures")
	game.audio.shutdown();game.free()
	print("CHAPTER_FOUR_RESULT %d checks; %d failures"%[checks,failures.size()])
	quit(1 if failures.size()>0 else 0)
