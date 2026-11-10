extends SceneTree
## Chapter IV finale end to end: summit, intro, both stages and every attack,
## the erase, the fistfight QTE, death, coordinates, road, door and the retries.
const FW=preload("res://scripts/chapter_four_world.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok: bool, label: String):
	checks+=1
	if ok:print("PASS: ",label)
	else:failures.append(label);push_error(label)
func advance(w, seconds: float):
	for i in range(ceili(seconds*60)):
		if w.state=="LEVEL_UP":w.skip_reward()
		w.step(1.0/60)
func until(w, condition: Callable, limit: float) -> bool:
	for i in range(ceili(limit*60)):
		if condition.call():return true
		if w.state=="LEVEL_UP":w.skip_reward()
		w.step(1.0/60)
	return condition.call()

func fresh():
	var w=FW.new();w.reset(724);w.state="RUNNING";w.stage="survival";w.stage_age=10;w.note_presented=true
	w.db.data.chapter_four.exploration_only=true;w.build={"sword":3,"bow":2};w.items={"armor":1};w.time=719.95
	return w

func run():
	handoff_checks()
	var w=fresh();var e=w.ending
	advance(w,.2)
	check(w.stage=="finale" and e.phase=="summit","At 12:00 the waves stop and the pyramid calls")
	check(w.mobs.filter(func(m):return m.has("form") and m.hp>0).is_empty(),"Remaining mobs dissolve at the summit")
	w.player=e.center+Vector2(0,150);advance(w,.05)
	check(e.phase=="intro" and not e.hb.is_empty() and e.scale()>=2.0,"Approaching the arena starts Herobrine's introduction at twice a man's height")
	check(e.locked() and w.camera().distance_to(w.player)>=0,"The introduction holds the world still")
	var said=false
	for i in range(ceili(9*60)):
		w.step(1.0/60)
		if e.text_events.any(func(t):return t.text=="Ты опять здесь."):said=true
	check(said,"Herobrine says «Ты опять здесь.» without surprise")
	check(e.phase=="tower","The introduction ends with him raising a tower")
	advance(w,2.0)
	check(e.tower_h>=float(e.data.tower.height) and e.hb.get("perched",false) and e.candidates().is_empty(),"He stands on the tower out of reach")
	w.hp=20;w.invulnerable=0;e.start_tower(w,"storm");w.player=e.marks[0].p;advance(w,float(e.data.tower.storm.windup)+.05)
	check(w.hp<20,"The tower storm walks lightning onto the hero")
	w.hp=20;w.invulnerable=0;e.waves.clear();e.start_tower(w,"waves");var wv: Dictionary=e.waves[0]
	var away: Vector2=Vector2.from_angle(wv.gap+PI);w.player=wv.p+Vector2(away.x,away.y*0.5)*120.0;advance(w,120.0/float(e.data.tower.waves.speed)+.05)
	check(w.hp<20,"Chapter I fire waves roll out from the foot of the tower")
	w.player=wv.p+Vector2(cos(wv.gap),sin(wv.gap)*0.5)*200.0;w.hp=20;w.invulnerable=0;e.waves=[wv];advance(w,(200.0-wv.r)/float(e.data.tower.waves.speed)+.05)
	check(w.hp==20,"The gap in a fire wave is a safe way through")
	w.invulnerable=999
	check(until(w,func():return e.phase=="vortex",90.0) and e.locked(),"The tower ends in the vortex from chapter I")
	advance(w,float(e.data.vortex.cut)+.1)
	check(e.vortex_cut,"The hero cuts the vortex open from inside")
	check(until(w,func():return e.phase=="one",10.0) and e.fighting() and not e.hb.get("perched",false),"He comes down from the tower and stage I begins")
	advance(w,3.0)
	check(e.tower_h==0.0,"The tower sinks back into the ground")
	w.invulnerable=0
	w.rebuild_hit_grid()
	check(w.in_radius(e.hb.p,30).has(e.hb),"Herobrine is a real target for every weapon")
	var before=e.hb.hp;w.hurt(e.hb,100.0);check(e.hb.hp==before-100.0 and w.damage_by.get(w.damage_owner,0)>=100,"Hits damage Herobrine and are attributed")
	w.invulnerable=0;w.hp=20
	e.start(w,"lightning");var marked=e.marks.size()==int(e.data.one.lightning.count)
	w.player=e.marks[0].p;advance(w,1.0)
	check(marked and w.hp<20,"Lightning marks strike where they were shown")
	w.hp=20;w.invulnerable=0;e.start(w,"ring");var gap=e.rings[0].gap;var ring_center=e.rings[0].p
	w.player=ring_center+Vector2.from_angle(gap)*40;advance(w,2.4)
	check(w.hp==20,"The gap in the fire ring is a safe way out")
	w.hp=20;w.invulnerable=0;e.start(w,"strike");w.player=e.lanes[0].a.lerp(e.lanes[0].b,.6);advance(w,.8)
	check(w.hp<20,"The blink strike hits along its cracked lane")
	e.hb.hp=e.hb.max_hp*.5;e.looked=false;w.hurt(e.hb,1.0)
	check(e.move=="look","A strong blow makes him look at his hand")
	w.hurt(e.hb,e.hb.hp+10)
	check(e.phase=="kneel" and e.locked(),"At zero he drops to one knee")
	said=false
	for i in range(ceili(7*60)):
		w.step(1.0/60)
		if e.text_events.any(func(t):return t.text=="Хорошо. Давай всерьёз."):said=true
	check(said and e.phase=="two" and e.hb.max_hp==float(e.data.two.hp),"«Хорошо. Давай всерьёз.» opens stage II at full strength")
	for name in ["hole","blitz","rain","rift","tear"]:
		w.hp=20;w.invulnerable=0;e.start(w,name);var ok=until(w,func():return e.move=="rest",14.0)
		check(ok and w.hp>0,"Stage II pattern "+name+" plays through and ends in a response window")
	w.hp=20;w.invulnerable=999;e.start(w,"rift");advance(w,1.4)
	var walls=0
	for cell in w.solid_grid:
		walls+=w.solid_grid[cell].filter(func(o):return o.get("rift",false)).size()
	check(walls>0,"Raised rift strips block movement")
	until(w,func():return e.move=="rest",10.0)
	walls=0
	for cell in w.solid_grid:
		walls+=w.solid_grid[cell].filter(func(o):return o.get("rift",false)).size()
	check(walls==0,"Rift strips sink again and leave the arena open")
	w.invulnerable=999;e.start(w,"day");var bright=0.0;var split_seen=false;var stunned=false;var shadow=false;var frozen=0;var released=false
	for i in range(ceili(20*60)):
		w.step(1.0/60);bright=maxf(bright,e.sky);split_seen=split_seen or e.split>0.5;stunned=stunned or e.move=="stunned";shadow=shadow or e.shadow_on
		frozen=maxi(frozen,e.shots.filter(func(b):return b.get("frozen",false)).size())
		released=released or (frozen>0 and e.shots.any(func(b):return b.kind=="knife" and not b.get("frozen",false)))
		if e.move=="rest":break
	check(bright>.9 and split_seen and stunned and shadow,"Day acceleration cycles the sky with his shadow as the hand, stops time, then leaves him stunned")
	check(frozen>=60 and released,"Stopped time hangs rings of shards around the hero and releases them together")
	var below_safe:=true
	for i in range(21):
		e.shadow_angle=-PI*i/20.0
		if e.in_shadow(e.hb.p+Vector2(0,30)) or e.in_shadow(e.hb.p+Vector2(60,40)):below_safe=false
	check(below_safe,"The ground below him is never under the shadow hand")
	var speed: float=w.movement_speed()
	check(float(e.data.two.hole.pull)<speed*0.75 and float(e.data.two.rain.drift)*e.arena.size.x/float(e.data.two.rain.lanes)<speed,"The hole's pull and the drift of the safe rain lanes stay slower than the hero")
	check(float(e.data.last.beam_off)>=0.6 and float(e.data.last.beam_speed[1])*120.0<speed,"The last attack's beams close for long enough to cross and turn slower than the hero")
	e.shadow_angle=0.0;check(e.in_shadow(e.hb.p+Vector2(40,0)) and not e.in_shadow(e.hb.p+Vector2(-40,0)),"The shadow hand covers exactly the ground it is drawn on")
	w.invulnerable=0;w.hp=0;w.step(1.0/60)
	check(e.phase=="retry" and w.state=="RUNNING","Dying in stage II retries the stage instead of ending the run")
	advance(w,2.4)
	check(e.phase=="two" and w.hp>=12,"The retry restores the stage II checkpoint")
	e.day_done=[];e.hb.hp=e.hb.max_hp;w.hurt(e.hb,e.hb.max_hp*2)
	check(e.phase=="two" and e.hb.hp>e.hb.max_hp*.55,"Stage II cannot be burst past its day acceleration")
	w.invulnerable=999;e.day_done=[0,1];var gear_before: int=w.build.size()+w.items.size();w.hurt(e.hb,e.hb.hp+10)
	check(e.phase=="last" and e.text_events.any(func(t):return t.text=="ХВАТИТ."),"Defeat in stage II does not end him: «ХВАТИТ.» and his last attack")
	advance(w,float(e.data.last.duration)*0.6)
	check(w.build.size()+w.items.size()<gear_before and e.void_r<float(e.data.last.void_from) and not e.beams.is_empty(),"The last attack tears the gear off piece by piece and erases the world from the edges")
	advance(w,float(e.data.last.duration)*0.4+.05)
	check(e.phase=="erase" and e.scale()>=2.0,"After the last attack he still stands at full size")
	advance(w,float(e.data.erase.shrink[1])+.1)
	check(e.scale()==1.0,"Spent, he shrinks to a man's size")
	advance(w,float(e.data.erase.duration)-float(e.data.erase.shrink[1]))
	check(e.phase=="three" and w.build.is_empty() and not e.stored.is_empty(),"The fistfight starts with nothing in either hand")
	check(e.candidates().is_empty(),"No weapon can touch Herobrine during the fistfight")
	# Fail one prompt on purpose, then answer every prompt correctly.
	var failed=false
	var steps=0
	while e.phase=="three" and steps<60*120:
		steps+=1
		var q: Dictionary=e.qte
		if not q.is_empty() and q.result=="" and q.age>=q.windup+.05:
			if not failed and q.kind=="dodge":
				e.press("down" if q.dir!="down" else "up");failed=true
			else:
				match q.kind:
					"dodge":e.press(q.dir)
					"attack":e.press("attack")
					"seq":e.press(q.dirs[q.progress])
					"mash":e.press("attack")
			e.hold=q.kind=="hold"
		w.step(1.0/60)
	check(failed and e.phase=="death","The fistfight survives a missed prompt and ends in his fall")
	var lines={}
	for i in range(ceili(22*60)):
		for t in e.text_events:lines[t.text]=true
		w.step(1.0/60)
	check(lines.has("АХАХАХАХАХХАХА") and lines.has("ТЫ НИЧЕРТА НЕ ПОНЯЛ") and lines.has("Я ВСЕГО ЛИШЬ СОГЛАСИЛСЯ ВЫПОЛНИТЬ ГРЯЗНУЮ РАБОТУ ЗА НЕГО"),"All three final lines are spoken")
	check(e.phase in ["coords","road"] and e.pose=="headless" and e.music=="","The final blow destroys his head; the coordinates follow in silence")
	until(w,func():return e.phase=="door",30.0)
	check(e.phase=="door","The road leads to the black door")
	until(w,func():return w.state=="RESULT",20.0)
	check(w.state=="RESULT" and w.victory and w.build==e.stored.build,"Stepping through the door ends chapter IV with the build restored")
	# Retry inside the fistfight
	w=fresh();e=w.ending;advance(w,.1);w.player=e.center+Vector2(0,150);w.invulnerable=999;until(w,func():return e.phase=="one",120.0);w.invulnerable=0
	w.hurt(e.hb,e.hb.hp+10);advance(w,7.2);e.day_done=[0,1];var full: int=w.build.size();w.hurt(e.hb,e.hb.hp+10)
	advance(w,4.0);w.invulnerable=0;w.hp=0;w.step(1.0/60);advance(w,2.4)
	check(e.phase=="last" and w.build.size()==full,"Dying in the last attack replays it with the gear restored")
	w.invulnerable=999;advance(w,float(e.data.last.duration)+float(e.data.erase.duration)+.3)
	w.hp=1;w.invulnerable=0
	until(w,func():return e.phase=="retry",30.0)
	check(e.phase=="retry","Losing the fistfight retries it")
	advance(w,2.5)
	check(e.phase=="three" and e.qte_index==0 and w.hp>=12,"The fistfight restarts from its own checkpoint")
	# Pause freezes everything
	var age_before=e.age;w.state="PAUSED";advance(w,1.0)
	check(e.age==age_before,"Pause freezes the finale")
	print("CHAPTER_FOUR_FINALE_RESULT %d checks; %d failures" % [checks,failures.size()])
	quit(1 if failures.size()>0 else 0)

func handoff_checks():
	for encounter in ["guardian","mass","golem"]:
		var w=fresh();var e=w.encounters
		w.build={};w.player=w.ending.center+Vector2(0,300);w.invulnerable=999
		match encounter:
			"guardian":
				e.launch_guardian(w);e.enter(e.guardian,"walk",.1)
				e.proposal=e.plan_geometry(w,0);e.commit_geometry(w)
			"mass":e.launch_mass(w,w.player+Vector2(0,-100))
			"golem":e.launch_golem(w)
		var kills: int=w.kills;var loot: int=w.loot.size();var xp_before: float=w.xp
		w.time=719.99;w.step(.02)
		check(w.ending.phase=="summit" and e.candidates().is_empty() and not e.busy(),"12:00 retires the unfinished "+encounter+" before the finale")
		var solids_left:=0
		for cell in w.solid_grid:
			solids_left+=w.solid_grid[cell].filter(func(s):return s.get("encounter","")=="guardian").size()
		check(solids_left==0 and e.blocks.is_empty() and e.shots.is_empty() and e.beams.is_empty() and not e.golem.visible,"The "+encounter+" leaves no attacks, raised collision or rescue actor")
		check(w.kills==kills and w.loot.size()==loot and w.xp==xp_before,"Retiring the "+encounter+" does not award a kill, chest or XP")
		w.db.data.chapter_four.exploration_only=false;advance(w,1.0)
		check(e.candidates().is_empty() and e.current.is_empty() and not e.golem.visible,"Survival encounters cannot restart after 12:00: "+encounter)
		w.player=w.ending.center+Vector2(0,150);w.step(.02)
		check(w.ending.phase=="intro" and e.visual_camera(w,w.camera())==w.camera(),"The "+encounter+" cannot override the finale camera")
	# Both active items must retain their costs and charges during locked scenes.
	var w=fresh();w.stage="finale";w.items={"heart_booster":5,"bat_wings":5};w.evolved={"bat_wings":true}
	w.arsenal.tick(w,.01,Vector2.ZERO)
	for phase in ["intro","vortex","kneel","erase","three","death","coords","road","door","retry"]:
		w.ending.phase=phase
		var before=var_to_str([w.hp,w.arsenal.heart_charges,w.arsenal.heart_price,w.arsenal.heart_buff,w.arsenal.bat_left,w.arsenal.bat_recharge])
		check(not w.active_item("heart") and not w.active_item("bat") and before==var_to_str([w.hp,w.arsenal.heart_charges,w.arsenal.heart_price,w.arsenal.heart_buff,w.arsenal.bat_left,w.arsenal.bat_recharge]),"Active equipment spends nothing in locked phase "+phase)
	w.ending.phase="one"
	check(w.active_item("heart") and w.active_item("bat"),"Active equipment remains available during the actual boss fight")
