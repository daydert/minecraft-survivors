extends RefCounted
## Chapter I's deterministic, unwinnable encounter. No gameplay RNG is consumed.
const CENTER=Vector2(1024,1024)
const DURATION=34.0
var active=false
var complete=false
var elapsed=0.0
var phase=""
var strikes:Array=[]
var waves:Array=[]
var next_strike=4.3
var next_wave=13.0
var strike_index=0
var wave_index=0
var start_camera=Vector2.ZERO
var rng=RandomNumberGenerator.new()

func reset():
	active=false
	complete=false
	elapsed=0
	phase=""
	strikes.clear()
	waves.clear()
	next_strike=4.3
	next_wave=13
	strike_index=0
	wave_index=0

func begin(w):
	reset()
	start_camera=w.camera()
	rng.seed=int(w.rng.seed)^0x48e12
	active=true
	phase="arrival"
	w.state="FINALE"
	w.time=float(w.db.data.duration)
	w.player=CENTER+Vector2(0,112)
	w.player_moving=false
	w.facing=Vector2.UP
	w.hp=maxf(1,w.hp)
	w.invulnerable=0
	w.victory=false
	for pool in [w.mobs,w.projectiles,w.orbs,w.loot,w.tasks,w.effects,w.particles,w.pixels,w.choices,w.pending_events]:pool.clear()
	w.hit_grid.clear()
	w.pending_chest.clear()
	w.message=""
	w.message_timer=0
	w.attack_visuals.clear()
	w.weapon_visuals.clear()
	w.sound("herobrine",1)

func camera(w) -> Vector2:
	if elapsed<4:
		return start_camera.lerp(CENTER+Vector2(0,48),smoothstep(0,2.2,elapsed))
	var desired=w.player.lerp(CENTER+Vector2(0,48),.75)
	desired.x=clampf(desired.x,w.player.x-250,w.player.x+250)
	desired.y=clampf(desired.y,w.player.y-125,w.player.y+125)
	if elapsed<4.8:desired=(CENTER+Vector2(0,48)).lerp(desired,smoothstep(4,4.8,elapsed))
	if elapsed>=29:desired=desired.lerp(w.player,smoothstep(29,31.5,elapsed))
	return desired.clamp(Vector2(320,180),Vector2(1728,1868))

func scorch() -> float:
	return clampf((elapsed-4)/9,0,1)

func fall_progress() -> float:
	return clampf((elapsed-29)/4,0,1)

func hit(w,amount: float):
	w.damage_player(amount)
	# Keep the full authored disaster visible before its unavoidable final wave.
	# The normal armor formula and hit feedback still apply to these strikes.
	w.hp=maxf(1,w.hp)

func step(w,dt:float,movement:Vector2):
	if not active or complete:return
	elapsed+=dt
	w.invulnerable=maxf(0,w.invulnerable-dt)
	w.shake=maxf(0,w.shake-dt)
	var old=w.player
	if elapsed<4:phase="arrival"
	elif elapsed<13:phase="storm"
	elif elapsed<24:phase="inferno"
	elif elapsed<26:phase="collapse"
	elif elapsed<29:phase="portal"
	elif elapsed<DURATION:phase="fall"
	else:phase="end"
	if phase in ["storm","inferno"]:
		if movement.length_squared()>0:
			w.facing=movement.normalized()
			w.player=w.move_actor(w.player,movement.limit_length()*w.db.data.player_speed*(1+0.08*w.items.get("sugar",0))*dt,6)
		w.update_attacks(dt)
		w.update_projectiles(dt)
		w.update_effects(dt)
	w.player_visual.travel=w.player.distance_to(old)
	w.player_moving=w.player_visual.travel>0.0001
	w.update_particles(dt)
	w.animation.advance(w,dt)
	var created=0
	while elapsed>=next_strike and elapsed<24 and created<5:
		var target:Vector2
		if strike_index%3==0:target=w.player
		elif strike_index%3==1:target=w.player+Vector2.from_angle(strike_index*2.399)*rng.randf_range(38,150)
		else:target=CENTER+Vector2.from_angle(strike_index*2.399)*rng.randf_range(200,1100)
		target=target.clamp(Vector2(30,30),Vector2(2018,2018))
		strikes.append({"p":target,"age":0.0,"hit":false,"seed":strike_index})
		strike_index+=1
		next_strike+=maxf(.23,.9-(elapsed-4)*.027)
		created+=1
	for i in range(strikes.size()-1,-1,-1):
		var s:Dictionary=strikes[i]
		s.age+=dt
		if s.age>=.7 and not s.hit:
			s.hit=true
			if s.p.distance_to(w.player)<26 and elapsed<24:hit(w,5)
			if w.visible(s.p,80):
				w.sound("lightning",.18)
				w.shake=.18
		if s.age>1.15:strikes.remove_at(i)
	while elapsed>=next_wave and elapsed<24:
		waves.append({"age":0.0,"radius":0.0,"speed":190.0+wave_index*22,"index":wave_index})
		next_wave+=maxf(.65,2.2-wave_index*.19)
		wave_index+=1
		w.sound("fire_wave",.35)
	for i in range(waves.size()-1,-1,-1):
		var wave:Dictionary=waves[i]
		wave.age+=dt
		wave.radius=wave.age*wave.speed
		if elapsed<24 and absf(w.player.distance_to(CENTER)-wave.radius)<24:hit(w,6)
		if wave.radius>1700:waves.remove_at(i)
	if elapsed>=24 and w.hp>0:
		# Scripted defeat is independent of armor, healing and invulnerability.
		w.hp=0
		w.invulnerable=0
		w.player_moving=false
		w.player_visual.hurt=.12
		w.projectiles.clear()
		w.effects.clear()
		w.weapon_visuals.clear()
		w.sound("death",1)
		w.shake=.35
	if elapsed>=26 and elapsed-dt<26:w.sound("portal_open",2)
	if elapsed>=29 and elapsed-dt<29:w.sound("portal_travel",2)
	if phase=="end":
		complete=true
		w.state="RESULT"
		w.victory=false
