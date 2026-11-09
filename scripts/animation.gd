class_name SurvivorAnimation
extends RefCounted
## Presentation only. Reads combat clocks; never schedules or applies damage.
var data: Dictionary

func _init():
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data/animations.json"))

func actor() -> Dictionary:
	return {"state":"idle", "time":0.0, "gait":0.0, "hurt":0.0, "shot_age":100.0, "travel":0.0}

func frame(kind: String, state: String, elapsed: float) -> int:
	if kind == "small_slime": kind = "slime"
	var clips: Dictionary = data.actors[kind].states
	var clip: Dictionary = clips.get(state, clips.idle)
	var duration = 0.0
	for d in clip.durations: duration += d
	var t = fposmod(maxf(0,elapsed)+0.0000001,duration) if clip.loop else clampf(elapsed,0,duration-0.000001)
	for i in range(clip.durations.size()):
		if t < clip.durations[i]: return int(clip.start)+i
		t -= clip.durations[i]
	return int(clip.start)+clip.durations.size()-1

func direction_row(direction: Vector2) -> int:
	return 2 if absf(direction.x)>absf(direction.y) else (1 if direction.y<0 else 0)

func strike(w, id: String, direction: Vector2):
	w.attack_visuals[id] = {"at":w.clock, "dir":direction}

func set_pose(v: Dictionary, state: String, elapsed: float):
	v.state = state
	v.time = maxf(0,elapsed)

func weapon(w, id: String) -> Dictionary:
	var timing: Dictionary = data.weapons[id]
	var recent: Dictionary = w.attack_visuals.get(id,{})
	var age: float = w.clock - recent.get("at",-100.0)
	if age < timing.attack + timing.recover:
		return {"state":"attack" if age<timing.attack else "recover", "age":age, "progress":clampf((age-timing.attack)/timing.recover,0,1), "dir":recent.dir}
	var left: float = w.cooldowns.get(id,0.0)
	if left>0 and left<=timing.windup:
		var target = null if id=="sword" else w.nearest(w.player)
		if id=="sword" or target!=null:
			return {"state":"windup", "age":timing.windup-left, "progress":1-left/timing.windup, "dir":w.facing if id=="sword" else w.player.direction_to(target.p)}
	return {}

func advance(w, dt: float, advance_mobs: bool = true):
	var v: Dictionary = w.player_visual
	v.gait += v.travel/float(w.db.data.player_speed)
	v.hurt = maxf(0,v.hurt-dt)
	var idle_time: float = v.time+dt if v.state=="idle" else 0.0
	set_pose(v,"walk" if w.player_moving else "idle",v.gait if w.player_moving else idle_time)
	w.weapon_visuals.clear()
	var selected = ""
	for id in w.build:
		var pose = weapon(w,id)
		if pose.is_empty(): continue
		w.weapon_visuals[id] = pose
		if selected.is_empty() or id=="sword": selected=id
	v.weapon=selected
	if not selected.is_empty():
		var pose: Dictionary = w.weapon_visuals[selected]
		# Normalize action clips to each weapon's own timing.
		var timing: Dictionary = data.weapons[selected]
		var t: float = pose.progress*0.16 if pose.state=="windup" else pose.age if pose.state=="attack" else pose.progress*0.24
		set_pose(v,pose.state,t)
	if v.hurt>0: set_pose(v,"hurt",0.12-v.hurt)
	if not advance_mobs: return
	for m in w.mobs:
		var a: Dictionary = m.visual
		a.hurt = maxf(0,a.hurt-dt)
		a.shot_age += dt
		a.gait += a.travel/maxf(1,m.speed)
		idle_time = a.time+dt if a.state=="idle" else 0.0
		set_pose(a,"walk" if m.moving else "idle",a.gait if m.moving else idle_time)
		m.visual_dir = m.dir
		match m.kind:
			"vindicator":
				if m.phase=="windup":set_pose(a,"windup",.5-m.timer)
				elif m.phase=="attack":set_pose(a,"attack",.14-m.timer)
				elif m.phase=="recover":set_pose(a,"recover",(.7-m.timer)/.7*.24)
				if m.phase in ["windup","attack"]:m.visual_dir=m.charge
			"creeper":
				if m.fuse>=0: set_pose(a,"windup",0.9-m.fuse)
			"skeleton":
				if a.shot_age<0.09: set_pose(a,"attack",a.shot_age)
				elif a.shot_age<0.33: set_pose(a,"recover",a.shot_age-0.09)
				elif m.timer>0 and m.timer<0.5 and w.visible(m.p): set_pose(a,"windup",0.5-m.timer)
				if a.state in ["windup","attack","recover"]: m.visual_dir = m.p.direction_to(w.player)
			"slime","small_slime":
				var cycle = fposmod(m.animation,1.1)
				if cycle<0.35: set_pose(a,"attack",cycle/0.35*0.09)
				elif cycle<0.6: set_pose(a,"recover",(cycle-0.35)/0.25*0.24)
				elif cycle>=0.85: set_pose(a,"windup",(cycle-0.85)/0.25*0.16)
				else: set_pose(a,"idle",cycle)
			"ravager":
				if m.phase=="windup":
					set_pose(a,"windup",0.8-m.timer)
					m.visual_dir = m.charge
				elif m.phase=="charge": set_pose(a,"attack",fposmod(1.2-m.timer,0.09))
				elif m.phase=="rest": set_pose(a,"recover",(1-m.timer)*0.24)
		if a.hurt>0 and a.state not in ["windup","attack"]: set_pose(a,"hurt",0.12-a.hurt)
