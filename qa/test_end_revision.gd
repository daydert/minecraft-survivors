extends SceneTree
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
	var w=fresh();var columns=w.props.filter(func(p):return p.type=="end_ruin")
	check(columns.size()>20,"Plain End columns remain plentiful on supported land")
	var c=columns[0].p;var start=c-Vector2(40,0);var stopped=w.move_actor(start,Vector2(40,0),6)
	check(stopped.distance_to(c)>=14.99 and stopped.x<c.x,"A walking body collides with the column base")
	stopped=w.move_actor(start,Vector2(100,0),6)
	check(stopped.x<c.x and stopped.distance_to(c)>=14.99,"A high-speed dash cannot tunnel through a column")
	check(not w.free_at(c,6) and w.blocked.has(Vector2i(c/w.CELL)),"Teleportation and pathfinding use column collision too")
	w.items={"end_eye":5};w.build={};w.next_level();var original=w.choices.duplicate();w.tick_choices(.2)
	check(w.choices==original,"Eye no longer changes before 0.21 seconds")
	w.tick_choices(.02);check(w.choices!=original,"Eye cycles after the slower display interval")
	var selected=w.choices[4];var owned=w.build.get(selected,w.items.get(selected,0));var combat_rng=w.rng.state
	w.choose(4);w.choose(0);w.reroll_choices();w.tick_choices(.3)
	check(w.chosen_item==selected and w.choices[4]==selected and w.state=="LEVEL_UP","Click freezes the exact displayed reward and ignores repeat input")
	check(w.build.get(selected,w.items.get(selected,0))==owned and w.rng.state==combat_rng,"Receipt does not apply another rotating reward early")
	w.state="PAUSED";var remaining=w.choice_hold;w.tick_choices(10)
	check(w.choice_hold==remaining,"Pause preserves the exact reward receipt duration")
	w.state="LEVEL_UP";w.tick_choices(.26)
	check(w.chosen_item.is_empty() and w.state!="LEVEL_UP","Reward is granted and combat resumes after the short receipt")
	w=fresh();w.prepare_arena();w.stage="last_duel";w.mobs.clear();w.crystals.clear();w.build={};w.spawn("endersteve_final",Vector2(1024,1020));var m=w.mobs[0]
	var signatures=[];var saw_leap=false;var saw_echo=false;var saw_cleave=false
	for pattern in [0,1,2,3,4,5,6,9,10,11]:
		w.projectiles.clear();w.hazards.clear();w.effects.clear();m.p=Vector2(1024,1020);w.player=Vector2(1024,1120);m.phase="walk";m.timer=0;m.seq=w.end_boss.SEQUENCE.find(pattern)-1;m.rage=false;m.hp=m.max_hp;m.combo=0
		var phases={};var kinds={};var hazards={};w.invulnerable=100
		for i in range(300):
			w.clock+=1.0/60;w.move_mobs(1.0/60);w.update_hazards(1.0/60);w.update_effects(1.0/60);w.update_end_poses(1.0/60)
			phases[m.phase]=true
			for p in w.projectiles:kinds[p.kind]=true
			for h in w.hazards:hazards[h.get("kind","cloud")]=true
			if m.phase=="leap":saw_leap=saw_leap or m.altitude>30
			if m.phase=="cleave":saw_cleave=true
			if hazards.has("end_cut"):saw_echo=true
			if m.phase in ["recover","pose"] and i>20:break
		var signature=str(phases.keys())+str(kinds.keys())+str(hazards.keys())+str(w.projectiles.size())
		signatures.append(signature)
		check((phases.has("recover") or phases.has("pose")) and (not kinds.is_empty() or phases.has("rush") or hazards.has("end_cut")),"Final attack %d has active threats and a recovery window" % (pattern+1))
	check(saw_leap and saw_echo and saw_cleave,"Duel includes an airborne strike, delayed echo cuts and a close sword cleave")
	var unique={}
	for signature in signatures:unique[signature]=true
	check(unique.size()>=6,"Final attacks produce at least six distinct movement and projectile patterns")
	w.projectiles.clear();w.hazards.clear();w.player=Vector2(1024,1100);w.invulnerable=0;w.hp=20
	w.end_boss.cut(w,Vector2(960,1100),Vector2(1088,1100),.8)
	w.update_hazards(.79);check(w.hp==20,"Echo cut cannot hurt during its visible preparation")
	w.update_hazards(.02);check(w.hp==15,"Echo cut deals real damage on its warned segment")
	w.invulnerable=0;w.hp=20;w.hazards.clear();w.player=Vector2(1024,1140);w.end_boss.cut(w,Vector2(960,1100),Vector2(1088,1100),.8);w.update_hazards(.81)
	check(w.hp==20,"Stepping clear of an echo segment avoids its damage")
	w=fresh();w.build={"axe":8};w.items={};w.mobs.clear();w.spawn("endermite_brood",w.player+Vector2(20,0));w.rebuild_hit_grid();m=w.mobs[0];var hp=m.hp
	w.update_attacks(.01);var ordinary=hp-m.hp
	check(ordinary>=61,"Maximum solo axe deals the increased real hit damage")
	w=fresh();w.build={"axe":8};w.evolved={"axe":true};w.items={};w.spawn("endermite_brood",w.player+Vector2(20,0));m=w.mobs[0];m.hp=1000;m.max_hp=1000;w.rebuild_hit_grid();w.update_attacks(.01);hp=m.hp;w.update_effects(.31)
	check(m.hp<hp-50,"Enchanted axe makes a second damaging return sweep")
	hp=m.hp;w.state="PAUSED";w.discard("axe");w.update_effects(.4)
	check(m.hp==hp and not w.effects.any(func(e):return e.kind=="axe_spin"),"Removing the axe cancels its delayed return hit")
	w=fresh();w.prepare_arena();w.mobs.clear();w.build={};w.stage="last_duel";w.spawn("endersteve_final",w.END_ARENA.end-Vector2(6,26));w.mobs[0].hp=0;w.resolve_deaths()
	for i in range(int((w.end_boss.CLASH_LENGTH+w.end_boss.DOWN_LENGTH+.6)*60)):w.step(1.0/60)
	check(w.stage=="to_edge","A boss beaten against the arena wall still leads to the walk to the rim")
	FileAccess.open("res://qa/end_revision_results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("END_REVISION_RESULT ",checks," checks; ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
