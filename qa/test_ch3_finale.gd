extends SceneTree
## Chapter III finale rework (2026-11-14): lines, the EnderSteve fight, rebirth, ending.
const EW=preload("res://scripts/end_world.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if ok:print("PASS: ",label)
	else:failures.append(label);push_error(label)
func fresh():
	var w=EW.new();w.reset(724);w.stage="survival";w.state="RUNNING";w.db.data.waves=[{"at":0,"rate":0,"weights":{"endermite":1}}];w.db.data.events=[];return w
func run():
	lines()
	frame_rules()
	projection()
	intercept()
	clock()
	rebirth()
	ending()
	FileAccess.open("res://qa/ch3_finale_results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("CH3_FINALE_RESULT ",checks," checks; ",failures.size()," failures");quit(0 if failures.is_empty() else 1)

func lines():
	var w=fresh()
	check(w.ECHO_LINES[4]=="Стой\nТуда нельзя\nНе заставляй меня","The last echo before the arena says the old portal-break lines")
	var e=w.end_boss
	var texts: Array=e.BETRAYAL_LINES.map(func(l):return l[1])
	check(texts==["Ладно...","У меня нет другого выбора...","Ты ничем не отличаешься от остальных...","НАЧНЁМ!"],"The portal break says the old last-echo lines, in order")
	w.prepare_arena();w.mobs.clear();w.stage="betrayal";w.stage_age=0;w.portal_lit=true
	var scream_at=-1.0;var unlit_at=-1.0;var overlap=false
	for i in range(int((e.BETRAYAL_END-.1)*60)):
		w.step(1.0/60)
		var shown=w.lines.filter(func(l):return l.age>=0)
		if shown.size()>1:overlap=true
		if scream_at<0 and shown.any(func(l):return l.text=="НАЧНЁМ!"):scream_at=w.stage_age
		if unlit_at<0 and not w.portal_lit:unlit_at=w.stage_age
	check(scream_at>0 and absf(scream_at-e.BETRAYAL_IMPACT)<=.05,"The scream lands on the blow that breaks the portal (%.2f vs %.2f)"%[scream_at,e.BETRAYAL_IMPACT])
	check(absf(unlit_at-e.BETRAYAL_IMPACT)<=.05,"The portal goes dark on the same beat")
	check(not overlap,"No two lines of the betrayal overlap on screen")

func duel_world():
	var w=fresh();w.prepare_arena();w.mobs.clear();w.crystals.clear();w.build={};w.items={};w.stage="last_duel"
	w.spawn("endersteve_final",Vector2(1024,1000));w.player=Vector2(1024,1100);w.last_safe=w.player;w.invulnerable=0;w.hp=20
	return w

func frame_rules():
	print("T frame")
	var w=duel_world()
	w.jump_age=.4;w.jump_height=20;w.invulnerable=.06
	check(w.boss_strike(w.player+Vector2(10,0),4) and w.hp==16,"His blow reaches the hero mid mace leap")
	w=duel_world();w.flight=2.0;w.invulnerable=.12
	check(w.boss_strike(w.player+Vector2(10,0),4) and w.hp==16,"His blow reaches the hero while gliding on elytra")
	check(not w.boss_strike(w.player+Vector2(10,0),4) and w.hp==16,"The grace after a hit protects from the next one")
	w=duel_world();w.dash_left=.3
	check(not w.boss_strike(w.player+Vector2(10,0),4),"A spear dash slips through his blow")
	w=duel_world();w.teleport_to(w.player+Vector2(30,0))
	check(not w.boss_strike(w.player+Vector2(10,0),4),"A pearl blink slips through his blow")
	w=duel_world();var m=w.mobs[0];m.phase="recover";var hp0=m.hp;w.hurt(m,100)
	check(is_equal_approx(hp0-m.hp,100.0),"Full damage lands in his recovery")
	m.phase="rush";hp0=m.hp;w.hurt(m,100)
	check(is_equal_approx(hp0-m.hp,40.0),"Only 40% lands while he attacks")
	w=duel_world();w.items={"sugar":5}
	check(absf(w.speed_scale()-1.4)<.001,"Sugar V makes him 1.4 times faster")
	w.slow_time=3.0;w.flight=1.0
	check(absf(w.speed_scale()-1.4)<.001,"Slows and the glide do not change his pace")
	w.items={"sugar":20}
	check(w.speed_scale()<=1.6,"His pace is capped")
	w=duel_world()
	check(not w.spawn("endersteve_final",Vector2(900,1000)),"A second EnderSteve cannot be spawned while one lives")
	var most=0;w.invulnerable=0
	for i in range(60*240):
		w.hp=20;w.step(1.0/60,Vector2.from_angle(i*.013))
		most=maxi(most,w.mobs.filter(func(v):return "steve" in v.kind and v.hp>0).size())
		if w.stage!="last_duel":break
	check(most==1,"Only one EnderSteve exists through four minutes of the duel (%d, %s)"%[most,w.stage])

func tick(w, seconds: float, move: Vector2=Vector2.ZERO):
	for i in range(ceili(seconds*60)):w.step(1.0/60,move)

func projection():
	print("T projection")
	var w=duel_world();var b=w.steve_boss
	check([b.lap_speed(w,0),b.lap_speed(w,1),b.lap_speed(w,2)]==[320.0,480.0,700.0],"Projection laps run at 320 / 480 / 700")
	check(absf(b.lap_preview(w,0)-.40)<.001 and absf(b.lap_preview(w,2)-.22)<.001,"Each lap is shown for 0.40 then down to 0.22 s")
	w.items={"sugar":5}
	check(absf(b.lap_speed(w,0)-448.0)<.01 and absf(b.lap_preview(w,0)-.40/sqrt(1.4))<.001,"Sugar V speeds the laps up but shortens the warning only by the square root")
	# Caught: the hero stands on his path.
	w=duel_world();var m=w.mobs[0];m.p=Vector2(1024,1000);m.phase="projection";m.lap=0;m.seg=1;m.after=0.0;m.path=[m.p,w.player,w.player+Vector2(0,60)]
	tick(w,.4)
	check(w.framed>0,"His body touching the hero freezes him in a frame")
	var at: Vector2=w.player;tick(w,.3,Vector2.RIGHT)
	check(w.player==at and not w.active_item("ender_pearl"),"In the frame the hero can neither move nor use items")
	tick(w,1.2)
	check(w.hp==20-w.steve_boss.CRUSH and w.framed<=0,"The crushing blow takes its full weight and frees the hero")
	# Caught mid mace leap.
	w=duel_world();m=w.mobs[0];w.build={"mace":1};m.p=Vector2(1024,1000);m.phase="projection";m.lap=0;m.seg=1;m.after=0.0;m.path=[m.p,w.player,w.player+Vector2(0,60)]
	w.jump_age=.3;w.jump_stats={"height":30,"damage":1,"radius":10};w.jump_height=20
	tick(w,.4)
	check(w.framed>0 and w.jump_age<0 and w.fall_age<0,"A mace leap is no escape from the frame, and he does not throw the hero off")
	# Off the path: no frame, three laps, then he is winded.
	w=duel_world();m=w.mobs[0];m.p=Vector2(900,950);w.player=Vector2(1300,1300);w.steve_boss.begin(w,m,b.PROJECTION)
	var laps={};var winded=false;var t=0.0
	while t<8.0 and not winded:
		w.player=Vector2(1300,1300)+Vector2(0,40)*sin(t);w.hp=20;w.hit_grace=1.0;tick(w,1.0/60);t+=1.0/60
		if m.phase=="projection":laps[int(m.lap)]=true
		winded=m.phase=="winded"
	check(laps.size()==3 and winded,"Three laps, then he stands winded")
	var hp0=m.hp;w.hurt(m,100)
	check(is_equal_approx(hp0-m.hp,100.0),"Winded he takes full damage")
	w=duel_world();m=w.mobs[0];m.p=Vector2(1024,1000);m.phase="projection";m.lap=0;m.seg=1;m.after=0.0;m.path=[m.p,w.player,w.player+Vector2(0,60)];tick(w,.4)
	var f=w.framed;w.state="PAUSED";tick(w,1.0);w.state="RUNNING"
	check(w.framed==f,"Pause keeps the frame exactly where it was")

func leap_world(drift: Vector2):
	var w=duel_world();var m=w.mobs[0];w.duel.learned="mace";m.p=w.player+Vector2(90,0);m.phase="walk";m.timer=99;w.build={"mace":1};w.cooldowns={"mace":0.0}
	w.jump_age=0.0;w.jump_stats={"height":30,"damage":1,"radius":10};w.jump_height=0;w.air_serial+=1
	return w

func intercept():
	print("T intercept")
	var w=leap_world(Vector2.ZERO);var m=w.mobs[0]
	tick(w,.05)
	check(m.phase=="intercept","A mace leap close to him draws the intercept")
	tick(w,.6)
	check(w.hp==20-w.steve_boss.HIT,"Staying on the spot, the hero is cut at the top of the leap")
	w=leap_world(Vector2.ZERO);m=w.mobs[0];tick(w,.05);var mark: Vector2=m.mark
	for i in range(40):w.step(1.0/60,Vector2.RIGHT)
	check(w.player.distance_to(mark)>=24 and w.hp==20,"Drifting off the landing spot in the air avoids the cut")
	w=duel_world();m=w.mobs[0];w.duel.learned="mace";w.items={"elytra":1};m.p=w.player+Vector2(90,0);m.phase="walk";m.timer=99;w.flight=.7;w.air_serial+=1
	tick(w,.05);var phase=m.phase;tick(w,.8)
	check(phase=="intercept" and w.hp<20,"The end of a glide close to him is cut on landing")
	w=leap_world(Vector2.ZERO);m=w.mobs[0];m.phase="cast";m.timer=3;m.pattern=1
	tick(w,.05)
	check(m.phase!="intercept","Busy with a move he does not intercept")

func clock_world():
	var w=duel_world();var m=w.mobs[0];m.p=w.player+Vector2(0,-120);m.phase="walk";m.timer=99;m.hp=m.max_hp*.59
	return w

func clock():
	print("T clock")
	var w=clock_world();var m=w.mobs[0];tick(w,.05)
	check(m.get("clock",{}).get("state","")=="running","Below 60% HP he winds his clock")
	var hp0: float=m.clock.hp0;m.phase="recover";m.timer=99;w.damage_owner="mace";w.hurt(m,m.max_hp*.13)
	tick(w,.05)
	check(m.clock.state=="rewind","Hurting him hard while the clock runs turns time back")
	tick(w,1.8)
	check(is_equal_approx(m.hp,hp0) and absf(float(w.duel.adapt.get("mace",1.0))-.6)<.001,"The rewind restores his HP and he adapts to the mace")
	m.phase="recover";m.timer=99;var before=m.hp;w.damage_owner="mace";w.hurt(m,100)
	check(absf(before-m.hp-60.0)<.01,"The mace now deals 60% to him")
	m.clock={"state":"running","age":0.0,"hp0":m.hp,"p0":m.p,"trail":[m.p],"tick":0.0,"dealt":{"mace":m.max_hp}};m.phase="walk";tick(w,1.8)
	check(absf(float(w.duel.adapt.mace)-.4)<.001,"A second rewind against the mace cuts it to 40%")
	w=clock_world();m=w.mobs[0];tick(w,.05)
	var t=0.0
	while t<9.5 and m.clock.state=="running":w.hp=20;w.hit_grace=1.0;tick(w,1.0/60);t+=1.0/60
	check(m.clock.state=="broken" and m.phase=="clock_broken","Played patiently, the clock breaks")
	m.timer=99;before=m.hp;w.damage_owner="sword";w.hurt(m,100)
	check(absf(before-m.hp-150.0)<.01,"While it is broken he takes 150%")
	w=clock_world();m=w.mobs[0];tick(w,.05);m.phase="recover";m.timer=99;w.damage_owner="mace";w.hurt(m,m.hp+10);w.resolve_deaths()
	check(m.hp<=0 and m.clock.state!="rewind","A killing blow is not undone by the clock")

func kill_fight_one(w, weapon: String):
	var m=w.mobs[0];m.phase="recover";m.timer=99;w.damage_owner=weapon;w.hurt(m,m.max_hp*.5);m.clock={"state":"spent"};m.clocks=1;w.hurt(m,m.max_hp*.6);w.resolve_deaths()

func rebirth():
	print("T rebirth")
	var w=duel_world();w.save_duel_checkpoint("fight1");kill_fight_one(w,"mace")
	check(w.stage=="rebirth" and w.duel.learned=="mace","His first death starts the rebirth; he learned the mace")
	var most=0;var heard=false;var spoke=""
	while w.stage=="rebirth":
		w.step(1.0/60)
		most=maxi(most,w.mobs.filter(func(v):return "steve" in v.kind and v.hp>0).size())
		heard=heard or w.sounds.has("return_by_death");w.sounds.clear()
		for l in w.lines:spoke=l.text
	check(heard,"Return by Death plays when he dies the first time")
	check(spoke==w.steve_boss.REBIRTH_LINES.mace,"Coming back he speaks to the mace")
	check(most<=1 and w.stage=="last_duel" and w.duel.fight==2 and w.mobs.size()==1 and w.mobs[0].hp==w.mobs[0].max_hp,"Exactly one EnderSteve, at full HP, starts fight two")
	check(w.steve_boss.intercept_chance(w)==1.0 and absf(float(w.duel.adapt.mace)-.7)<.001,"In fight two he always intercepts the mace and takes 70% from it")
	# A death in fight two returns to fight two.
	w.hp=0;w.step(1.0/60)
	tick(w,1.0)
	check(w.stage=="fallen" and w.state=="RUNNING","Dying in the duel shows the fallen card and stays there, not the result screen")
	w.retry_duel()
	check(w.stage=="last_arrival" and w.duel.fight==2 and w.hp>=12 and w.mobs.size()==1 and absf(float(w.duel.adapt.mace)-.7)<.001,"Retrying from fight two keeps what he learned")
	# A death in fight one returns to fight one with the gear intact.
	w=duel_world();w.build={"spear":3};w.save_duel_checkpoint("fight1");w.build={};w.hp=0;w.step(1.0/60)
	w.retry_duel()
	check(w.stage=="last_arrival" and w.duel.fight==1 and w.build.get("spear",0)==3,"Retrying fight one restores the gear of the checkpoint")
	# Both down in one frame: the hero's death wins.
	w=duel_world();w.save_duel_checkpoint("fight1");var m=w.mobs[0];m.hp=0;w.hp=0;w.step(1.0/60)
	check(w.stage=="fallen","When both fall in one frame the duel restarts")
	# Fight two reads the spear.
	w=duel_world();w.duel.fight=2;w.duel.learned="spear";m=w.mobs[0];m.p=w.player+Vector2(0,-120);m.phase="walk";m.timer=99;w.facing=Vector2.UP;w.start_dash(.3)
	var at: Vector2=m.p;tick(w,1.0/60)
	check(m.p.distance_to(at)>30 and w.hazards.any(func(h):return h.get("steve",false)),"Against the spear he steps off the line and cuts along it")
	# The Loop never freezes the hero.
	w=duel_world();w.duel.fight=2;m=w.mobs[0];m.history=[w.steve_boss.PROJECTION,0,4,5];m.phase="windup";m.pattern=w.steve_boss.LOOP;m.timer=0
	var froze=false;var ghosts=false
	for i in range(140):
		w.hp=20;w.hit_grace=1.0;w.step(1.0/60);froze=froze or w.framed>0 or m.phase=="projection"
		ghosts=ghosts or w.effects.any(func(e):return e.kind=="steve_loop_ghost")
	check(ghosts and not froze,"The Loop replays his moves but never the frame")

func to_race(w):
	w.duel.fight=2;var m=w.mobs[0];m.hp=0;w.resolve_deaths()
	var seen={}
	while w.stage in ["standoff","clash"]:w.step(1.0/60);seen[w.stage]=true
	return seen

func play_race(w, good: bool):
	var q=w.sword_race;var guard=0
	while w.stage=="sword_race" and guard<1200:
		guard+=1;w.step(1.0/60)
		if not good or not q.live() or w.stage_age<w.end_boss.RACE_INTRO:continue
		match q.beat:
			0:q.press("attack")
			1:
				if q.age>.45:q.press(q.dir)
			2:
				if q.age>=.9:q.press("attack")

func ending():
	print("T ending")
	var w=duel_world()
	w.damage_by={"mace":900.0,"end_crystal":5000.0,"sword":100.0}
	check(w.top_held_weapon()=="mace","The clash weapon is the most used weapon held in the hand")
	w.damage_by={"end_crystal":5000.0,"dragon_breath":10.0}
	check(w.top_held_weapon()=="sword","With nothing held in the hand Steve clashes with a sword")
	w=duel_world();w.build={"mace":4,"spear":2};w.damage_by={"mace":800.0};w.save_duel_checkpoint("fight1")
	var seen=to_race(w)
	check(seen.has("standoff") and seen.has("clash") and w.stage=="sword_race" and w.duel.clash_weapon=="mace","After fight two: a standoff, the clash with the mace, then the race")
	check(w.build.is_empty(),"The clash breaks everything he carried")
	var paused_age=-1.0
	for i in range(80):w.step(1.0/60)
	var q=w.sword_race;var a0: float=q.age;w.state="PAUSED"
	for i in range(100):w.step(1.0/60)
	w.state="RUNNING"
	check(q.age==a0,"Pause freezes the race")
	play_race(w,true)
	check(w.stage=="mercy" and w.build.get("sword",0)==1,"Winning the race, the last iron sword is Steve's")
	var stages={}
	var guard=0
	while w.stage not in ["portal_ready"] and guard<60*200:guard+=1;w.step(1.0/60);stages[w.stage]=true
	check(stages.has("talk") and stages.has("restore") and not stages.has("to_edge") and not stages.has("sit") and not stages.has("down"),"Mercy, the talk by the portal, the portal restored, no walk to the rim "+str(stages.keys())+w.stage)
	check(w.stage=="portal_ready" and w.keepsake and w.build.get("sword",0)==1,"The Eye of the End is his gift; the sword stays with Steve")
	w=duel_world();w.build={"spear":3};w.save_duel_checkpoint("fight1");to_race(w);play_race(w,false)
	check(w.stage=="bad_end","Losing the race leads to the bad ending")
	tick(w,w.end_boss.BAD_LENGTH+.6)
	check(w.stage=="bad_card" and not w.end_complete and not w.victory and w.state=="RUNNING","The bad ending does not complete the chapter")
	w.retry_duel()
	check(w.stage=="last_arrival" and w.duel.fight==1 and w.build.get("spear",0)==3 and w.mobs.size()==1,"From the bad ending the duel restarts at fight one with the gear whole")
