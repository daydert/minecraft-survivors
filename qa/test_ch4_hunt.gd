extends SceneTree
## Chapter IV pressure pass (13.11): pillar rescues and stirring villagers,
## elite retinues and affixes, marksmen, ambushes, surges and the butcher.
var game
var checks=0
var failures=[]
var folder:="res://qa/ch4_hunt/"
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if ok:print("PASS: ",label)
	else:failures.append(label);push_error(label)
func shot(name: String):
	game.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(folder+name+".png")
func advance(w,t: float,move: Vector2=Vector2.ZERO):
	for i in range(ceili(t*60)):
		if w.state=="LEVEL_UP":w.skip_reward()
		if w.state=="CHEST":w.close_chest()
		w.step(1.0/60,move)
func clear(w):
	for m in w.mobs:m.expired=true;m.hp=0
	w.resolve_deaths();w.hunt.rises.clear();w.enemy_shots.clear()
func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_process_input(false);game.qa_mode="review";game.settings.shake=false;root.size=Vector2i(640,360)
	game.action("chapter_4");var w=game.world;var h=w.hunt
	w.state="RUNNING";w.stage="survival";w.invulnerable=0;w.note_presented=true;w.db.data.chapter_four.exploration_only=true
	for id in ["mass","golem","guardian"]:w.encounters.data[id].at=99999
	var pillars: Array=h.pillars(w)
	check(pillars.size()==19,"19 pillars stand across the map")
	var far: int=0
	for m in pillars:
		if m.p.distance_to(Vector2(600,760))>400:far+=1
	check(far>=12,"Most pillars are outside the village")
	# --- rescue
	var mark: Dictionary=pillars[pillars.size()-5]
	w.time=130;w.player=mark.p+Vector2(0,60);advance(w,.2)
	await shot("pillar_hint")
	w.player=mark.p+Vector2(0,12);w.invulnerable=999;advance(w,.4)
	check(mark.get("ambushed",false) and h.rises.size()>=4,"Starting a rescue raises the dead around the pillar")
	await shot("rescue_ambush")
	advance(w,1.2);await shot("rescue_progress")
	w.player=mark.p+Vector2(0,90);advance(w,1.0)
	var decayed: float=mark.progress
	check(decayed>0 and decayed<1.6,"Walking away bleeds the progress")
	w.player=mark.p+Vector2(0,12);w.hp=10
	var level_xp: int=w.orbs.size()
	advance(w,3.5)
	check(mark.get("state","")=="freed","Standing long enough takes the villager down")
	check(w.hp>=13.9 and w.orbs.size()>level_xp,"The rescue heals and drops experience")
	check(h.damage_scale(w)>1.0,"Vengeance raises damage")
	await shot("rescued")
	check(not w.aura_near() or pillars.any(func(p):return p!=mark and h.hanging(p) and p.p.distance_to(w.player)<110),"A freed pillar no longer casts its aura")
	clear(w)
	# --- stirring and tearing loose
	w.player=Vector2(1024,1024);w.time=200;h.stir_at=w.clock;advance(w,.1)
	check(not h.stirring.is_empty(),"A villager starts to stir somewhere on the map")
	var stir: Dictionary=h.stirring
	await shot("stir_hud")
	w.player=stir.p+Vector2(0,70);advance(w,.5);await shot("stir_pillar")
	clear(w);w.player=stir.p+Vector2(0,150)
	stir.stir_until=w.clock+.05;advance(w,.2)
	var crucified=w.mobs.filter(func(m):return m.get("form","")=="crucified" and m.hp>0)
	check(stir.state=="torn" and crucified.size()==1,"Ignored, he tears loose as the Crucified")
	check(crucified.size()==1 and crucified[0].get("affixes",[]).size()>=1,"The Crucified carries an affix")
	advance(w,1.0);await shot("crucified")
	if crucified.size()==1:
		var c=crucified[0];c.timer=0;c.stun=0;c.phase="walk";w.player=c.p+Vector2(0,120)
		for j in range(16):
			var q: Vector2=c.p+Vector2.from_angle(j*TAU/16)*120
			if w.free_at(q,8) and w.line_clear(c.p,q):w.player=q;break
		var acted:=false
		for i in range(150):
			advance(w,1.0/60)
			if c.cast in ["ram","sweep"]:acted=true;break
		if not acted:print("DBG c phase=",c.phase," cast=",c.cast," timer=",c.timer," d=",c.p.distance_to(w.player)," stun=",c.stun," hp=",c.hp," clear=",w.line_clear(c.p,w.player)," p=",c.p," pl=",w.player)
		await shot("crucified_ram")
		check(acted,"The Crucified rams or sweeps")
	clear(w)
	# --- elites with retinues and affixes
	w.time=400;w.player=Vector2(1024,1024)
	w.spawn("gravedigger",w.player+Vector2(120,0));var g=w.mobs.back()
	check(g.get("affixes",[]).size()==2,"Late elites have two affixes")
	check(h.rises.filter(func(r):return r.source=="retinue").size()==4,"The gravedigger brings his own dead")
	advance(w,.8);await shot("retinue")
	g.affixes=["shielded"];advance(w,.2)
	var before: float=g.hp;w.hurt(g,100);var shielded_loss: float=before-g.hp
	check(g.get("shield_n",0)>=3 and shielded_loss<60,"Allies around a shielded elite absorb damage")
	await shot("shielded")
	g.affixes=["volatile"];g.hp=1;w.hurt(g,50);advance(w,.05)
	check(h.blasts.size()==1,"A volatile elite bursts after death")
	advance(w,.6);await shot("volatile_tell")
	advance(w,.8)
	check(h.blasts.is_empty(),"…and the burst resolves")
	clear(w)
	w.spawn("bellringer",w.player+Vector2(80,0));var v=w.mobs.back();v.affixes=["vampiric"];v.hp=v.max_hp*.5;v.stun=0
	w.invulnerable=0;var vh: float=v.hp;w.receive_hit(2.0,v)
	check(v.hp>vh,"A vampiric elite heals by hitting the hero")
	clear(w)
	# --- marksman
	w.invulnerable=999;w.spawn("marksman",w.player+Vector2(220,0));var mk=w.mobs.back();mk.timer=0;mk.stun=0
	advance(w,.3)
	check(mk.phase=="windup","The marksman takes aim from range")
	await shot("marksman_aim")
	advance(w,1.0);await shot("marksman_lock")
	advance(w,.3)
	check(w.enemy_shots.any(func(b):return b.get("snipe",false)),"…and fires a fast bolt")
	await shot("marksman_shot")
	clear(w)
	# --- ambush ahead of a kiting run
	w.invulnerable=999;w.time=300;h.ambush_at=w.clock+99;advance(w,.3,Vector2.RIGHT)
	h.ambush_at=w.clock;advance(w,.3,Vector2.RIGHT)
	var ahead=h.rises.filter(func(r):return r.source=="ambush")
	check(ahead.size()>=5 and ahead.all(func(r):return (r.p-w.player).dot(Vector2.RIGHT)>0),"Ambushes rise ahead of the run")
	await shot("ambush")
	clear(w)
	# --- surge
	h.surges_done.clear();h.surges_done[0]=true;h.surges_done[2]=true;h.surges_done[3]=true;h.surges_done[4]=true
	w.time=h.data.surges.times[1]+.1;advance(w,.1)
	check(h.surge_left>0 and h.wave_scale(w)>1.0,"The raid horn starts a surge")
	check(h.rises.filter(func(r):return r.source=="surge").size()>=10,"A ring closes around the hero")
	advance(w,.6);await shot("surge")
	clear(w);h.surge_left=0
	# --- butcher
	h.butcher_done={1:true,2:true,3:true}
	w.time=h.data.butcher.times[0]+.1;advance(w,.1)
	var b=h.butcher(w)
	check(b!=null,"The butcher arrives on schedule")
	if b!=null:
		advance(w,1.0);await shot("butcher_rise")
		b.stun=0;w.hurt(b,500);w.resolve_deaths()
		check(h.butcher(w)!=null and b.hp==b.max_hp,"The butcher cannot be killed")
		check(b.stun>0,"…but a heavy hit staggers him")
		b.stun=0;b.timer=0;b.phase="walk";w.player=b.p+Vector2(30,0);advance(w,.3)
		await shot("butcher_cleave")
		check(b.phase=="windup" and b.cast=="cleave","He cleaves at close range")
		advance(w,1.5);b.lunge_ready=0;b.timer=0;b.phase="walk";b.stun=0;w.player=b.p+Vector2(140,0);advance(w,.3)
		await shot("butcher_lunge")
		check(b.cast=="lunge","He lunges across the gap")
		b.leave_at=w.clock;b.phase="walk";b.stun=0;advance(w,.4);await shot("butcher_leave")
		advance(w,1.0)
		check(h.butcher(w)==null,"After his time he sinks back into the ground")
	# --- crowded HUD: butcher bar, elite message, reward and a stirring timer at once
	clear(w);h.butcher_done={};h.data.butcher.times=[w.time];advance(w,.1)
	var st=h.pillars(w).filter(func(p):return p.get("state","hung")=="hung")[0]
	st.state="stirring";st.stir_from=w.clock;st.stir_until=w.clock+20;h.stirring=st
	h.last_reward="+20% урона на 25 с";h.reward_at=w.clock
	w.spawn("bellringer",w.player+Vector2(90,40));w.mobs.back().affixes=["vampiric","shielded"]
	w.message="Звонарь"+h.affix_suffix(w.mobs.back());w.message_timer=2
	await shot("hud_stack")
	check(h.butcher(w)!=null and not h.stirring.is_empty(),"Crowded HUD case is staged")
	game.router.open("ch4_note",w);await shot("note")
	print("CH4_HUNT_RESULT %d checks; %d failures" % [checks, failures.size()])
	quit(1 if failures.size()>0 else 0)
