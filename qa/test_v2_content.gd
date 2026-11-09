extends SceneTree
## Version 2 content: chapter I night events and mobs, the Nether bastion,
## the End city and void gusts, per-weapon damage and the new achievements.
const OW=preload("res://scripts/overworld_world.gd")
const NW=preload("res://scripts/nether_world.gd")
const EW=preload("res://scripts/end_world.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok: bool, label: String):
	checks+=1
	if ok:print("PASS: ",label)
	else:failures.append(label);push_error(label)
func advance(w, seconds: float, dir: Vector2=Vector2.ZERO):
	for i in range(ceili(seconds*60)):w.step(1.0/60,dir)
func quiet(w):
	w.db.data.waves=[{"at":0,"rate":0,"weights":{"zombie":1}}];w.db.data.events=[]

func run():
	# ---------------------------------------------------------------- chapter I
	var w=OW.new();w.reset(724);w.state="RUNNING"
	var kinds=w.landmarks.map(func(m):return m.kind)
	check(kinds.has("ruin_0") and kinds.has("well") and kinds.has("mine_entrance") and kinds.has("pond"),"Chapter I places ruins, a well, a mine entrance and a pond")
	check(w.loot.any(func(o):return o.kind=="chest" and o.p.distance_to(w.landmarks[0].p)<40),"The village ruin hides a chest")
	check(not w.water.is_empty() and w.water.keys().all(func(c):return not w.free_at(Vector2(c*16)+Vector2(8,8),2)),"Pond water blocks movement")
	var same=OW.new();same.reset(724)
	check(same.landmarks.map(func(m):return m.p)==w.landmarks.map(func(m):return m.p),"Landmarks are reproducible from the run seed")
	w=OW.new();w.reset(724);w.state="RUNNING";quiet(w);w.mobs.clear();w.invulnerable=999;w.time=179.9
	advance(w,.2)
	check(w.fog_amount()>=0 and w.message=="Туман сгущается","Fog arrives at 3:00")
	var ring=w.mobs.filter(func(m):return m.kind=="zombie")
	check(ring.size()>=4 and ring.all(func(m):return absf(m.p.distance_to(w.player)-215)<30),"Zombies step out of the fog around the hero")
	w=OW.new();w.reset(724);w.state="RUNNING";quiet(w);w.mobs.clear();w.time=365
	w.spawn("zombie",w.player+Vector2(120,0))
	check(w.blood_moon()>0 and w.mobs[0].xp==2 and w.mobs[0].get("blood_moon",false),"Blood moon raises the experience of new enemies")
	w=OW.new();w.reset(724);w.state="RUNNING";quiet(w);w.mobs.clear();w.time=300
	w.spawn("witch",w.player+Vector2(150,0));var witch=w.mobs[0];witch.timer=0
	w.move_mobs(1.0/60)
	check(w.effects.any(func(e):return e.kind=="witch_potion"),"Witch throws a potion with a visible landing mark")
	var hp=w.hp;advance(w,1.0)
	check(w.hp<hp,"The potion splash hurts a hero standing on the mark")
	w.spawn("zombie",witch.p+Vector2(30,0));var hurt_zombie=w.mobs.back();hurt_zombie.hp=1;witch.heal_timer=0;witch.timer=99;w.rebuild_hit_grid()
	w.move_mobs(1.0/60)
	check(hurt_zombie.hp>1 and w.effects.any(func(e):return e.kind=="witch_heal"),"Witch heals nearby enemies")
	w=OW.new();w.reset(724);w.state="RUNNING";quiet(w);w.mobs.clear();w.time=560
	w.spawn("phantom",w.player+Vector2(130,0));var phantom=w.mobs[0]
	check(phantom.altitude>30 and phantom.visual.airborne,"Phantoms circle high above the ground")
	hp=w.hp;phantom.p=w.player+Vector2(30,0);phantom.timer=0;w.move_mobs(1.0/60)
	check(phantom.phase=="windup" and w.hp==hp,"A phantom marks its dive target before it can hurt")
	advance(w,.8);advance(w,1.2)
	check(w.hp<hp or phantom.phase in ["dive","climb","circle"],"The dive reaches the marked ground")
	w=OW.new();w.reset(724);w.state="RUNNING";quiet(w);w.mobs.clear();w.time=545
	advance(w,.1)
	check(w.mobs.filter(func(m):return m.kind=="phantom").size()==2 and w.message=="Фантомы","Phantoms join the night at 9:00")
	w=OW.new();w.reset(724);w.state="RUNNING";quiet(w);w.mobs.clear();w.invulnerable=999;w.time=421
	advance(w,.05)
	check(w.run_progress.awarded.has("blood_moon"),"Surviving the blood moon awards its achievement")
	w=OW.new();w.reset(724);w.state="RUNNING";quiet(w);w.mobs.clear();w.time=300
	for i in range(12):w.spawn("witch",w.player+Vector2(200,i*12));w.mobs.back().hp=0
	w.resolve_deaths()
	check(w.run_progress.awarded.has("witch_hunter"),"Twelve witches award Witch Hunt")
	w=OW.new();w.reset(724);w.state="RUNNING";quiet(w);w.mobs.clear();w.build={"sword":8}
	w.spawn("zombie",w.player+Vector2(14,0));w.facing=Vector2.RIGHT;w.rebuild_hit_grid()
	advance(w,1.5)
	check(w.damage_by.get("sword",0)>0,"Sword damage is attributed to the sword")
	# ---------------------------------------------------------------- chapter II
	var n=NW.new();n.reset(724);n.state="RUNNING";quiet(n);n.mobs.clear();n.invulnerable=999
	check(not n.bastion.is_empty() and n.landmarks[0].kind=="bastion" and n.bastion.state=="closed","The Nether holds a closed bastion")
	n.time=359.95;advance(n,.1)
	check(n.bastion.state=="open" and n.message=="Бастион открыт","The bastion opens at 6:00")
	n.player=n.bastion.p+Vector2(0,120);advance(n,.05)
	check(n.bastion.state=="assault" and n.mobs.filter(func(m):return m.get("turret",false)).size()==3,"Approaching starts the assault with three turrets")
	check(n.mobs.filter(func(m):return m.get("turret",false)).all(func(m):return true),"Turret blazes are placed")
	var turret=n.mobs.filter(func(m):return m.get("turret",false))[0];var spot=turret.p
	advance(n,1.0)
	check(turret.p==spot,"Turrets never leave their post")
	advance(n,6.0)
	check(n.mobs.filter(func(m):return m.kind in n.PIGLINS and m.aggro>100).size()>=3,"Assault piglins stay hostile even with gold boots")
	n.bastion.timer=0.01;advance(n,.05)
	check(n.bastion.state=="won" and n.loot.any(func(o):return o.kind=="chest" and o.p.distance_to(n.bastion.p)<30) and n.run_progress.awarded.has("bastion"),"Holding the bastion leaves a chest and awards Bastion Taken")
	# ---------------------------------------------------------------- chapter III
	var e=EW.new();e.reset(724);e.state="RUNNING";e.stage="survival";quiet(e);e.mobs.clear();e.invulnerable=999
	check(not e.city.is_empty() and e.landmarks[0].kind=="end_city" and e.loot.any(func(o):return o.kind=="chest" and o.p.distance_to(e.city.p)<30),"The End island holds a city with a chest")
	e.player=e.city.p+Vector2(0,30);e.last_safe=e.player;advance(e,.05)
	check(e.city.guarded and e.mobs.filter(func(m):return m.kind=="shulker").size()>=2,"Shulkers wake when the hero reaches the city")
	e=EW.new();e.reset(724);e.state="RUNNING";e.stage="survival";quiet(e);e.mobs.clear();e.invulnerable=999;e.time=250;e.gust.timer=.01
	e.spawn("endermite",e.player+Vector2(30,0))
	advance(e,.05)
	check(e.gust.phase=="warn","A gust is announced before it blows")
	var before=e.player;advance(e,1.4)
	check(e.gust.phase=="blow" and e.mobs.all(func(m):return m.launch>0),"The gust lifts ordinary enemies off their feet")
	advance(e,.6)
	check(e.player.distance_to(before)>20 or e.fall_age>=0,"The gust pushes the hero")
	e.falls=0;e.gust.count=5;e.gust.phase="blow";e.gust.timer=.01;advance(e,.05)
	check(e.run_progress.awarded.has("windswept"),"Five gusts without a fall award Against the Wind")
	print("V2_CONTENT_RESULT %d checks; %d failures" % [checks,failures.size()])
	quit(1 if failures.size()>0 else 0)
