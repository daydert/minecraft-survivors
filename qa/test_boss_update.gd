extends SceneTree
const Campaign=preload("res://scripts/campaign_world.gd")
const Nether=preload("res://scripts/nether_world.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if ok:print("PASS: "+label)
	else:failures.append(label);push_error(label)
func advance(w, seconds: float, movement: Vector2=Vector2.ZERO):
	for i in range(ceili(seconds*60)):w.step(1.0/60,movement)
func run():
	for kind in [Campaign,Nether]:
		for seed_value in [724,151,918,11]:
			var w=kind.new(seed_value);w.state="RUNNING"
			var vessels=w.props.filter(func(p):return p.type=="pumpkin")
			var loaded=vessels.filter(func(p):return p.has_heal)
			check(loaded.size()*2==vessels.size(),"Exactly half of vessels heal, chapter %d seed %d" % [w.chapter_number(),seed_value])
			var state=w.rng.state
			for p in vessels:p.hp=0;w.break_pumpkin(p)
			check(w.loot.size()==vessels.size()/2 and w.rng.state==state,"Breaking vessels uses predetermined contents without combat RNG")
	var w=Nether.new(724);w.state="RUNNING"
	check(w.db.passives.has("gold_boots") and not w.db.passives.has("gold_leggings"),"Gold boots replace leggings in the real pool")
	var sand=Vector2.ZERO
	for index in range(w.soul_sand.size()):
		if not w.soul_sand[index]:continue
		var p=Vector2((index%128)*16+8,(index/128)*16+8)
		if w.free_at(p):sand=p;break
	check(sand!=Vector2.ZERO,"Soul-sand mask contains traversable vanilla terrain")
	w.player=sand;var speed=w.movement_speed();var p=w.player;w.build={};w.step(1.0/60,Vector2.RIGHT)
	check(is_equal_approx(speed,82*.58) and absf(w.player.distance_to(p)-speed/60)<.001,"Soul sand actually reduces player movement")
	var monotone=true;var previous=speed
	for boots in range(1,6):
		w.items={"gold_boots":boots};w.player=sand;var current=w.movement_speed()
		monotone=monotone and current>previous;previous=current
	check(monotone and is_equal_approx(previous,82),"Each boot level removes one fifth of the penalty; V removes it all")
	w.spawn("piglin_sword",w.player+Vector2(80,0));w.rebuild_hit_grid()
	check(w.neutral(w.mobs[0]),"Boots retain the original piglin neutrality")
	w.prepare_arena();w.stage="wither";var boss=w.mobs[0]
	w.player=Vector2(850,1120);boss.p=Vector2(1180,1000)
	var middle=(w.player+boss.p)/2+Vector2(0,-28)
	w.arena_camera=middle;w.update_arena_camera(1)
	check(w.camera()==middle,"Boss camera stays between the two actors")
	w.player+=Vector2(8,0);w.update_arena_camera(.016)
	check(w.camera()==middle,"Small player movements stay inside the camera dead zone")
	w.player=Vector2(1270,1080);boss.p=Vector2(1260,1160)
	middle=(w.player+boss.p)/2+Vector2(0,-28)
	w.arena_camera=middle;w.update_arena_camera(1)
	check(w.camera()==middle,"Arena edges do not pull the midpoint camera back toward the old center")
	w.player=Vector2(780,1220);boss.p=Vector2(1280,850)
	for i in range(180):w.update_arena_camera(1.0/60)
	var hero_screen=w.player-w.camera()+Vector2(320,180)
	check(hero_screen.x>25 and hero_screen.y<310 and w.camera().x>w.player.x+120,"At extreme separation the camera releases only enough to keep the hero visible")
	w.projectiles.clear();w.hazards.clear();boss.rage=false
	w.encounter.begin(w,boss,"bombard")
	w.encounter.bombard_step(w,boss,.16)
	check(w.hazards.size()==1,"First ignition appears after the casting beat")
	w.encounter.bombard_step(w,boss,.1);w.encounter.bombard_step(w,boss,.1)
	check(w.hazards.size()==3 and w.hazards.all(func(h):return h.total<=.51 and h.total>=.45 and h.radius>=43),"Three wide ignitions are separated by 0.1 seconds and short warnings")
	w.encounter.bombard_step(w,boss,.1)
	check(w.hazards.size()==6,"The three ignitions are followed by a triple line")
	w.projectiles.clear();w.encounter.begin(w,boss,"spiral");boss.timer=0;w.move_mobs(.01);w.move_mobs(.01)
	var first=w.projectiles.size()
	check(first>=18,"First-phase barrage fills the whole circle")
	boss.rage=true;w.projectiles.clear();w.encounter.begin(w,boss,"spiral");boss.timer=0;w.move_mobs(.01);w.move_mobs(.01)
	check(w.projectiles.size()>first and w.projectiles.any(func(b):return absf(b.turn)>.1),"Rage adds denser curved projectile waves")
	for i in range(220):w.fire_projectile("wither_skull",boss.p,Vector2.RIGHT,{"speed":100,"damage":4,"range":700,"radius":18},false)
	var count=w.projectiles.size();w.fire_projectile("arrow",w.player,Vector2.UP,{"speed":200,"damage":5,"range":200,"radius":3},false)
	check(w.projectiles.size()==count+1 and w.projectiles.back().kind=="arrow","Enemy bullet density does not consume player weapon capacity")
	w.mobs[0].hp=0;w.resolve_deaths()
	check(w.win_music and w.sounds.has("boss_win"),"Wither victory triggers the shared celebration")
	var c=Campaign.new(724);c.state="RUNNING";c.spawn("ravager",c.player);c.mobs[0].hp=0;c.resolve_deaths()
	check(not c.win_music and c.boss_victory_serial==0,"Miniboss deaths do not start chapter-victory audio")
	c.reset(724);c.finale.begin(c);var f=c.finale
	check(f.has_method("duel_phase") and f.boss.hp==5200 and c.mobs.size()==1,"Solo Herobrine begins as a damageable first-stage boss")
	f.skip_to_fight(c);advance(c,.1);c.rebuild_hit_grid();var before=f.boss.hp;c.hurt(f.boss,40)
	check(f.boss.hp==before-40,"Ordinary weapon damage reduces Herobrine health")
	var wave={"gap":0.0,"radius":100.0}
	check(not f.wave_active(0,wave) and not f.wave_active(PI,wave) and f.wave_active(PI/2,wave),"Fire rings have two real collision-free openings")
	c.invulnerable=0;c.hp=1;f.hit(c,3)
	check(c.hp<=0,"First-stage damage is no longer clamped to one remaining HP")
	c.reset(724);c.finale.begin(c);f=c.finale;f.skip_to_fight(c);advance(c,.1);f.boss.hp=0;c.step(.016)
	check(f.phase=="rising" and not c.win_music and not c.sounds.has("boss_win"),"Optional first-stage win starts the rise without a victory stinger")
	advance(c,3.25);advance(c,f.DESCEND_LENGTH+.4);advance(c,.55)
	check(f.teleported and c.player==f.KNEEL_AT,"Second stage teleports the hero before kneeling")
	advance(c,1)
	check(f.phase=="kneel","The authored sequence includes a separate kneeling phase")
	advance(c,1.3);c.invulnerable=1000000;c.hp=20;advance(c,1.5)
	check(f.phase=="rift" and c.hp==0 and f.destroyed,"Blood distortion defeats the hero despite artificial invulnerability")
	var clock=c.clock;var ritual=f.phase_age;c.state="PAUSED";c.step(5)
	check(c.clock==clock and f.phase_age==ritual,"Pausing freezes the complete ritual and shader clock")
	c.state="FINALE"
	for i in range(1200):
		if f.complete:break
		c.step(1.0/60)
	check(f.complete and c.state=="RESULT" and not c.victory and not c.win_music,"The second stage ends in the Nether and stops the victory track")
	c.reset(724)
	check(not c.win_music and c.boss_victory_serial==0 and not c.finale.active,"New runs clear celebration and encounter state")
	FileAccess.open("res://qa/boss_update_results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("BOSS_UPDATE_RESULT ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
