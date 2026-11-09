extends SceneTree
const World=preload("res://scripts/world.gd")
var checks=0
var failures=[]

func _initialize():run.call_deferred()
func check(ok: bool, label: String):
	checks+=1
	if not ok: failures.append(label);push_error(label)
	else:print("PASS: "+label)

func fresh():
	var w=World.new(724)
	w.state="RUNNING"
	return w

func run():
	var w=fresh()
	var anim=w.animation
	for kind in anim.data.actors:
		var spec=anim.data.actors[kind]
		var valid=true
		for state in ["idle","walk","windup","attack","recover","hurt"]:
			for t in [0.0,0.031,0.23,0.9,9.0,10000.0]:
				var f=anim.frame(kind,state,t)
				valid=valid and f>=spec.states[state].start and f<spec.states[state].start+spec.states[state].durations.size()
		check(valid,kind+" six clips stay inside atlas including long elapsed time")
	check(anim.frame("steve","walk",0.085)!=anim.frame("steve","walk",0.095),"Unequal frame durations obey exact boundary")
	check(anim.frame("steve","hurt",100)==21,"One-shot holds last frame")
	check(anim.frame("steve","walk",0.64)==anim.frame("steve","walk",0),"Walk wraps at cycle length")
	for hz in [30,60,144]:
		var elapsed=0.0
		for i in range(hz*3):elapsed+=1.0/hz
		check(anim.frame("steve","walk",elapsed)==anim.frame("steve","walk",3),"Frame sampling independent of "+str(hz)+" FPS")
	var dirs=[Vector2.DOWN,Vector2.UP,Vector2.RIGHT,Vector2.LEFT,Vector2(1,0.2),Vector2(-1,0.2),Vector2(0.2,-1),Vector2(0.2,1)]
	var rows=[0,1,2,2,2,2,1,0]
	for i in range(dirs.size()):check(anim.direction_row(dirs[i])==rows[i],"Direction row "+str(dirs[i]))
	w.step(0.15,Vector2.RIGHT)
	var phase=w.player_visual.gait
	w.step(0.01,Vector2.LEFT)
	check(is_equal_approx(w.player_visual.gait,phase+0.01) and w.facing==Vector2.LEFT,"Turning preserves walking phase and changes facing")
	w=fresh()
	w.cooldowns.sword=0.12
	w.spawn("elite",w.player+Vector2(27,0))
	w.facing=Vector2.RIGHT
	w.step(1.0/60)
	check(w.player_visual.state=="windup" and w.mobs[0].hp==180,"Sword preparation causes no early damage")
	while w.attack_visuals.is_empty():w.step(1.0/60)
	check(w.player_visual.state=="attack" and w.mobs[0].hp==172 and w.effects.any(func(e):return e.kind=="swing"),"Sword contact, body action and damage share one tick")
	for state in ["PAUSED","LEVEL_UP","CHEST","RESULT"]:
		w.state=state
		var snapshot=[w.clock,w.player_visual.duplicate(true),w.weapon_visuals.duplicate(true),w.effects.duplicate(true),w.pixels.duplicate(true)]
		w.step(2,Vector2.UP)
		check(snapshot==[w.clock,w.player_visual,w.weapon_visuals,w.effects,w.pixels],"Attack and every presentation clock freeze in "+state)
	w.state="RUNNING"
	w.step(0.1)
	check(w.player_visual.state=="recover","Sword resumes into recovery")
	w.step(0.2)
	check(w.player_visual.state=="idle","Sword recovery returns to calm idle")
	w.damage_player(2)
	w.animation.advance(w,0.01)
	check(w.player_visual.state=="hurt" and w.hp==18,"Player hurt pose reflects real contact")
	w.hurt(w.mobs[0],1)
	w.animation.advance(w,0.01)
	check(w.mobs[0].visual.state=="hurt","Mob hurt pose reacts without AI stun")
	w=fresh()
	w.spawn("skeleton",w.player+Vector2(150,0))
	w.mobs[0].timer=0.3
	w.step(1.0/60)
	check(w.mobs[0].visual.state=="windup" and w.projectiles.is_empty(),"Skeleton visibly draws before projectile exists")
	w.mobs[0].timer=0.001
	w.step(1.0/60)
	check(w.mobs[0].visual.state=="attack" and w.projectiles.size()==1 and w.sounds.has("arrow"),"Skeleton release, arrow and sound share one tick")
	w.step(0.13)
	check(w.mobs[0].visual.state=="recover","Skeleton release enters recovery")
	w=fresh()
	w.spawn("creeper",w.player+Vector2(18,0))
	w.step(1.0/60)
	check(w.mobs[0].visual.state=="windup" and w.hp==20,"Creeper fuse drives anticipation without early damage")
	for i in range(55):w.step(1.0/60)
	check(w.effects.any(func(e):return e.kind=="enemy_explosion") and w.hp==14,"Creeper explosion appears on damage tick")
	w=fresh()
	w.spawn("ravager",w.player+Vector2(120,0))
	var m=w.mobs[0]
	m.timer=0
	w.step(0.01)
	check(m.visual.state=="windup" and m.visual_dir==m.charge,"Ravager warning and lowered head face locked charge")
	for i in range(81):w.step(0.01)
	check(m.visual.state=="attack" and m.phase=="charge","Ravager anticipation enters real charge")
	for i in range(121):w.step(0.01)
	check(m.visual.state=="recover" and m.phase=="rest","Ravager charge settles into recovery")
	w=fresh()
	w.spawn("slime",w.player+Vector2(90,0))
	m=w.mobs[0]
	for sample in [[0.95,"windup"],[0.15,"attack"],[0.45,"recover"]]:
		m.animation=sample[0]
		w.animation.advance(w,0)
		check(m.visual.state==sample[1],"Slime original hop clock maps to "+sample[1])
	for id in w.db.weapons:
		w=fresh()
		w.build={id:8}
		w.evolved={"sword":true,"bow":true,"trident":true}
		w.cooldowns={id:0.08}
		w.spawn("elite",w.player+Vector2(70,0))
		w.rebuild_hit_grid()
		w.animation.advance(w,0)
		check(w.weapon_visuals.has(id) and w.weapon_visuals[id].state=="windup",id+" has preparation at its unchanged cooldown")
		w.cooldowns[id]=0
		w.step(1.0/60)
		check(w.attack_visuals.has(id) and w.weapon_visuals[id].state=="attack",id+" body attack is triggered by actual combat event")
	w=fresh()
	var rng_state=w.rng.state
	w.emit_pixels("smoke",w.player,20,Vector2.UP)
	check(w.rng.state==rng_state and w.pixels.size()==20 and w.particles.is_empty(),"Presentation particles preserve gameplay RNG and original particle budget")
	w.spawn("zombie",w.player+Vector2(50,0))
	w.hurt(w.mobs[0],999)
	w.resolve_deaths()
	check(w.mobs.is_empty() and w.orbs.size()==1 and not w.pixels.is_empty(),"Death emits debris and preserves XP drop")
	w.reset(724)
	check(w.player_visual.state=="idle" and w.player_visual.gait==0 and w.attack_visuals.is_empty() and w.weapon_visuals.is_empty() and w.pixels.is_empty(),"Restart clears all presentation states")
	FileAccess.open("res://qa/animation_results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("ANIMATION_RESULT ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
