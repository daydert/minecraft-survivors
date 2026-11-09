extends RefCounted
## Solo first-stage duel; the second stage is an authored defeat.
const CENTER=Vector2(1024,1024)
const BOSS_AT=CENTER+Vector2(0,-24)
const KNEEL_AT=CENTER+Vector2(0,44)
var active=false
var complete=false
var elapsed=0.0
var phase=""
var phase_age=0.0
var fight_age=0.0
var ritual_elapsed=0.0
var strikes: Array=[]
var waves: Array=[]
var boss: Dictionary={}
var next_strike=1.4
var next_wave=5.0
var strike_index=0
var wave_index=0
var start_camera=Vector2.ZERO
var ritual_camera=Vector2.ZERO
var teleport_from=Vector2.ZERO
var teleported=false
var destroyed=false
var first_stage_won=false
var rng=RandomNumberGenerator.new()

func reset():
	active=false;complete=false;elapsed=0;phase="";phase_age=0;fight_age=0;ritual_elapsed=0
	strikes.clear();waves.clear();boss={}
	next_strike=1.4;next_wave=5;strike_index=0;wave_index=0
	teleported=false;destroyed=false;first_stage_won=false

func duel_phase() -> bool:return true

func begin(w):
	reset();start_camera=w.camera();rng.seed=int(w.rng.seed)^0x48e12
	active=true;phase="arrival";w.state="FINALE";w.time=720
	w.player=CENTER+Vector2(0,116);w.facing=Vector2.UP;w.player_moving=false
	w.win_music=false;w.victory=false;w.invulnerable=0
	for pool in [w.mobs,w.projectiles,w.orbs,w.loot,w.tasks,w.effects,w.particles,w.pixels,w.choices,w.pending_events]:pool.clear()
	w.hit_grid.clear();w.pending_chest.clear();w.attack_visuals.clear();w.weapon_visuals.clear()
	w.message="";w.message_timer=0
	boss={"id":w.next_id(),"kind":"herobrine","p":BOSS_AT,"dir":Vector2.DOWN,"hp":5200.0,"max_hp":5200.0,"speed":0.0,"damage":0.0,"xp":0,"radius":26.0,"timer":0.0,"fuse":-1.0,"flash":0.0,"burn":0.0,"burn_tick":.5,"phase":"idle","charge":Vector2.ZERO,"animation":0.0,"knock":Vector2.ZERO,"visual":w.animation.actor(),"moving":false,"visual_dir":Vector2.DOWN}
	w.mobs.append(boss);w.rebuild_hit_grid();w.sound("herobrine",1)

func camera(w) -> Vector2:
	if phase=="arrival":return start_camera.lerp(CENTER+Vector2(0,38),smoothstep(0,2.6,phase_age))
	if phase in ["storm","inferno"]:
		var desired=(w.player.lerp(CENTER+Vector2(0,-20),.65)).clamp(w.player-Vector2(245,125),w.player+Vector2(245,125))
		return (CENTER+Vector2(0,38)).lerp(desired,smoothstep(0,1.2,fight_age)) if fight_age<1.2 else desired
	if not first_stage_won and phase in ["defeated","portal","fall"]:
		return ritual_camera.lerp(w.player+Vector2(0,-12),smoothstep(0,1.2,ritual_elapsed))
	var target=CENTER+Vector2(0,30)
	if phase=="fall":target=target.lerp(w.player,smoothstep(0,2,phase_age))
	return ritual_camera.lerp(target,smoothstep(0,2.8,ritual_elapsed))

func scorch() -> float:return clampf(fight_age/15,0,.95)
func fall_progress() -> float:return clampf(phase_age/4,0,1) if phase=="fall" else 0.0
func cinematic_player() -> bool:return phase in ["rising","summon","kneel","rift","vanish","defeated","portal","fall"]
func blood_progress() -> float:return smoothstep(.1,4.9,phase_age) if phase=="rift" else 1.0 if phase=="vanish" else 0.0
func blood_wipe() -> float:return smoothstep(0,3,phase_age) if phase=="vanish" else 0.0

func wave_active(angle: float, wave: Dictionary) -> bool:
	for hole in [wave.gap,wave.gap+PI]:
		if absf(angle_difference(angle,hole))<.38:return false
	return true

func hit(w, amount: float):w.damage_player(amount)

func change(next: String):phase=next;phase_age=0

func begin_second(w):
	first_stage_won=true
	w.run_progress.award("herobrine")
	ritual_camera=camera(w);ritual_elapsed=0;change("rising")
	strikes.clear();waves.clear()
	for pool in [w.mobs,w.projectiles,w.effects,w.tasks,w.weapon_visuals,w.attack_visuals]:pool.clear()
	w.hit_grid.clear();w.player_moving=false

func begin_fall(w):
	ritual_camera=camera(w);ritual_elapsed=0
	change("defeated");w.hp=0;destroyed=true;w.player_moving=false
	strikes.clear();waves.clear()
	for pool in [w.mobs,w.projectiles,w.effects,w.tasks,w.weapon_visuals,w.attack_visuals]:pool.clear()
	w.hit_grid.clear();w.sound("death",1)

func combat(w, dt: float, movement: Vector2):
	fight_age+=dt
	phase="storm" if fmod(fight_age,20)<11 else "inferno"
	if movement.length_squared()>0:
		w.facing=movement.normalized()
		w.player=w.move_actor(w.player,movement.limit_length()*w.movement_speed()*dt,6)
	if boss.burn>0:
		boss.burn-=dt;boss.burn_tick-=dt
		if boss.burn_tick<=0:boss.burn_tick+=.5;w.hurt(boss,w.burn_damage(boss))
	w.rebuild_hit_grid();w.update_attacks(dt);w.update_projectiles(dt);w.update_effects(dt);w.pickup(dt)
	if boss.hp<=0:begin_second(w);return
	while fight_age>=next_strike:
		var target=w.player if strike_index%3!=2 else CENTER+Vector2.from_angle(strike_index*2.399)*rng.randf_range(180,430)
		if strike_index%3==1:target+=Vector2.from_angle(strike_index*2.399)*60
		strikes.append({"p":target,"age":0.0,"hit":false,"seed":strike_index})
		strike_index+=1;next_strike+=1.1
	for i in range(strikes.size()-1,-1,-1):
		var s=strikes[i];s.age+=dt
		if s.age>=.85 and not s.hit:
			s.hit=true
			if s.p.distance_to(w.player)<20:hit(w,2.5)
			if w.visible(s.p,40):w.sound("lightning",.25);w.shake=.08
		if s.age>1.25:strikes.remove_at(i)
	while fight_age>=next_wave:
		waves.append({"age":0.0,"radius":0.0,"speed":115.0,"index":wave_index,"gap":CENTER.direction_to(w.player).angle()+wave_index*.25})
		wave_index+=1;next_wave+=3.6;w.sound("fire_wave",.4)
	for i in range(waves.size()-1,-1,-1):
		var wave=waves[i];wave.age+=dt;wave.radius=wave.age*wave.speed
		if absf(w.player.distance_to(CENTER)-wave.radius)<14 and wave_active(CENTER.direction_to(w.player).angle(),wave):hit(w,2.5)
		if wave.radius>1200:waves.remove_at(i)
	if w.hp<=0:
		begin_fall(w)

func step(w, dt: float, movement: Vector2):
	if not active or complete:return
	elapsed+=dt;phase_age+=dt
	if not boss.is_empty():boss.flash=maxf(0,boss.flash-dt)
	w.invulnerable=maxf(0,w.invulnerable-dt);w.shake=maxf(0,w.shake-dt)
	var old=w.player
	if phase=="arrival":
		if phase_age>=4:change("storm")
	elif phase in ["storm","inferno"]:combat(w,dt,movement)
	else:
		ritual_elapsed+=dt
		match phase:
			"rising":
				if phase_age>=3.2:change("summon");teleport_from=w.player;w.sound("herobrine_warp")
			"summon":
				if phase_age>=.45 and not teleported:w.player=KNEEL_AT;w.facing=Vector2.UP;teleported=true
				if phase_age>=1.2:change("kneel")
			"kneel":
				if phase_age>=1.2:change("rift");w.sound("blood_rift")
			"rift":
				if phase_age>=1.4 and not destroyed:
					w.hp=0;w.invulnerable=0;destroyed=true;w.sound("death");w.shake=.3
				if phase_age>=5.2:change("vanish")
			"vanish":
				if phase_age>=3:change("portal");w.sound("portal_open")
			"defeated":
				if phase_age>=1.2:change("portal");w.sound("portal_open")
			"portal":
				if phase_age>=2:change("fall");w.sound("portal_travel")
			"fall":
				if phase_age>=4:change("end");complete=true;w.state="RESULT";w.victory=false;w.win_music=false
	w.player_visual.travel=w.player.distance_to(old) if phase in ["storm","inferno"] else 0.0
	w.player_moving=w.player_visual.travel>.0001
	w.update_particles(dt);w.animation.advance(w,dt)
