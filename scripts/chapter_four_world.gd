extends "res://scripts/arsenal_world.gd"
## IV owns its terrain, waves and arsenal. Special encounters and the final
## boss are the following stages of the chapter plan.
const TERRAIN := "res://data/chapter_four_terrain.json"
const Enemies = preload("res://scripts/chapter_four_enemies.gd")
const Equipment = preload("res://scripts/chapter_four_equipment.gd")
var arsenal = preload("res://scripts/chapter_four_arsenal.gd").new()
var encounters = preload("res://scripts/chapter_four_encounters.gd").new()
var ending = preload("res://scripts/chapter_four_finale.gd").new()
## Presentation-only impact state (gore, stains, smoke); see chapter_four_fx.gd.
var fx = preload("res://scripts/chapter_four_fx.gd").new()
var enemy_shots: Array = []
var enemy_fields: Array = []
var enemy_bottles: Array = []
var mob_walls: Array = []
var chickens: Array = []
var mob_slow := 1.0
var terrain: Dictionary = {}
var pools: Dictionary = {}
var landmarks: Array = []
var threats: Array = []
var blood_shots: Array = []
var blood_hand: Dictionary = {}
var hand_cooldown := 0.0
var held := 0.0
var note_read := false
var note_pending := false
var note_presented := false
var aura_state := "none"
var aura_changed_at := -10.0
var victory_stage := ""
var damage_popups: Dictionary={}

func chapter_number() -> int:
	return 4

func reset(seed_value: int = 0):
	terrain = JSON.parse_string(FileAccess.get_file_as_string(TERRAIN))
	pools.clear();landmarks.clear();threats.clear();blood_shots.clear()
	blood_hand.clear();hand_cooldown = 2.0;held = 0.0
	enemy_shots.clear();enemy_fields.clear();enemy_bottles.clear();mob_walls.clear();chickens.clear();mob_slow=1.0
	note_read = false;note_pending = false;note_presented = false
	aura_state = "none";aura_changed_at = -10.0;victory_stage = ""
	damage_popups.clear()
	super.reset(seed_value)
	var actors: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_four_mobs.json"))
	animation.data.actors.merge(actors.actors,true)
	var equipment: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_four_arsenal.json"))
	for id in equipment.weapons:animation.data.weapons[id]={"windup":.2,"attack":.12,"recover":.36}
	arsenal.reset(self)
	if FileAccess.file_exists("res://data/chapter_four_encounter_assets.json"):
		var special: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_four_encounter_assets.json"))
		animation.data.actors.merge(special.actors,true)
	encounters.reset(self)
	ending.reset(self)
	fx.reset(self)
	stage = "arrival"
	facing = Vector2.UP

func add_solid(p: Vector2, radius: float):
	var cell := Vector2i(p / 64.0)
	if not solid_grid.has(cell):solid_grid[cell] = []
	solid_grid[cell].append({"p": p, "r": radius})
	blocked[Vector2i(p / CELL)] = true

func make_map():
	for cell in terrain.pool_cells:
		pools[Vector2i(int(cell) % 128, int(cell) / 128)] = true
	for item in terrain.props:
		var p := Vector2(item.p[0], item.p[1])
		if item.type == "trunk":
			if encounters.reserve(p):continue
			add_prop("tree", p)
			props.back().variant = int(item.variant)
			continue
		var mark := {"kind": item.type, "p": p, "variant": int(item.get("variant", 0)), "id": next_id(), "phase": fposmod(p.x * .137 + p.y * .071, TAU)}
		if item.type in ["growth","growth_big"] and encounters.reserve(p):continue
		landmarks.append(mark)
		match item.type:
			"house":
				# Ruined rear and side walls; the doorway and note remain accessible.
				for x in range(-30, 31, 10):add_solid(p + Vector2(x, -10), 5)
				for y in range(-28, -9, 8):add_solid(p + Vector2(-30, y), 5)
			"crucifix":add_solid(p, 5)
			"growth", "growth_big":
				make_threat(mark, db.data.chapter_four.growth)
				if mark.kind == "growth_big":
					mark.radius = float(db.data.chapter_four.growth.large_radius)
					mark.hp = float(db.data.chapter_four.growth.large_hp);mark.max_hp = mark.hp
				add_solid(mark.p, mark.radius)
			"torch":
				mark.hostile = item.get("hostile", false)
				if mark.hostile:make_threat(mark, db.data.chapter_four.cursed_torch)
	var pyramid := Vector2(terrain.pyramid[0], terrain.pyramid[1])
	landmarks.append({"kind": "pyramid", "p": pyramid, "variant": 0, "id": next_id(), "phase": 0.0})
	# The baked solid occupies the whole stepped footprint, not a thin back row.
	for x in range(-110, 111, 12):
		for y in range(-62, 11, 12):add_solid(pyramid + Vector2(x, y), 8)
	var note := Vector2(terrain.note[0], terrain.note[1])
	landmarks.append({"kind": "note", "p": note, "variant": 0, "id": next_id(), "phase": 0.0})
	for i in range(18):
		var p: Vector2 = player + Vector2.from_angle(i * 2.39996) * (150 + i % 5 * 130)
		if free_at(p, 10) and not in_blood(p):
			if encounters.reserve(p):continue
			props.append({"type": "pumpkin", "p": p, "hp": 12.0, "id": next_id(), "radius": 7.0})
	assign_healing()
	for i in range(5):
		var p=Vector2(820,840)+Vector2((i%3)*17,(i/3)*16)
		chickens.append({"p":p,"dir":Vector2.DOWN,"state":"watch","age":0.0})

func remove_mob_solid(p: Vector2):
	var cell:=Vector2i(p/64.0)
	if solid_grid.has(cell):solid_grid[cell]=solid_grid[cell].filter(func(s):return s.p!=p)
	var nav_cell:=Vector2i(p/CELL)
	if not nearby_solids(p).any(func(s):return Vector2i(s.p/CELL)==nav_cell):blocked.erase(nav_cell)
	update_flow()

func spawn(kind: String, at = null) -> bool:
	if not db.data.forms.has(kind):return super.spawn(kind,at)
	var def: Dictionary=db.data.forms[kind]
	if encounters.busy() and def.elite:return false
	var limits: Dictionary=db.data.chapter_four.enemy_limits
	if kind=="parasite" and mobs.filter(func(m):return m.kind==kind and m.hp>0).size()>=int(limits.parasites):return false
	if kind=="infected_witch" and mobs.filter(func(m):return m.kind==kind and m.hp>0).size()>=int(limits.witches):return false
	if kind=="growth_skeleton" and mobs.filter(func(m):return m.kind==kind and m.hp>0).size()>=int(limits.skeletons):return false
	if def.elite and mobs.filter(func(m):return m.get("boss",false) and m.hp>0).size()>=int(limits.elites):return false
	if not super.spawn(kind,at):return false
	var m: Dictionary=mobs.back()
	m.merge({"form":kind,"skin":"ch4_"+kind,"undead":true,"ai":def.ai,"boss":def.elite,"haste":0.0,"haste_scale":1.0,"changed":false,"cast":"","phase_duration":1.0,"phase_age":0.0,"lift":0.0,"passes":0,"pass_origin":m.p,"wall_points":[],"exploded":false,"expired":false,"expires":clock+float(def.ai.get("lifetime",99999))},true)
	m.timer=1.2+float(m.id%7)*.27
	m.phase="walk"
	return true

func move_mobs(dt: float):
	# Legacy actors may appear in a QA fixture; their old update remains intact.
	var all: Array=mobs
	mobs=all.filter(func(m):return not m.has("form"))
	super.move_mobs(dt)
	mobs=all
	Enemies.update(self,dt)

func heal_undead(at: Vector2, radius: float, damage: float):
	# Shared hook for the Chapter IV healing potion (arsenal stage C).
	for m in in_radius(at,radius):
		if m.get("undead",false) and not m.get("allied",false):hurt(m,damage)

func add_effect(kind: String,p: Vector2,life: float,extra: Dictionary={}):
	# Fast pellets/saw ticks share one nearby number for 120 ms. Damage and hit
	# reactions still run per hit; only redundant text draw calls are combined.
	if kind=="damage":
		var cell:=Vector2i((p/8).floor())
		var previous: Dictionary=damage_popups.get(cell,{})
		if previous.get("life",0)>0 and previous.get("age",1)<.12:
			previous.amount+=extra.get("amount",0);return
		var count: int=effects.size()
		super.add_effect(kind,p,life,extra)
		if effects.size()>count:damage_popups[cell]=effects.back()
		return
	super.add_effect(kind,p,life,extra)

func update_effects(dt: float):
	super.update_effects(dt)
	for cell in damage_popups.keys():
		if damage_popups[cell].life<=0:damage_popups.erase(cell)

func resolve_deaths():
	for i in range(mobs.size()-1,-1,-1):
		var m: Dictionary=mobs[i]
		if m.hp>0 or not m.has("form"):continue
		if not m.expired and not m.exploded:
			arsenal.after_kill(self,m)
			kills+=1;drop_xp(m.p,m.xp)
			if m.boss:loot.append({"kind":"chest","p":m.p,"born":time})
			add_effect("ch4_remains",m.p,.6,{"skin":m.skin,"dir":m.visual_dir})
			fx.death(self,m)
		if m.exploded and threats.filter(func(t):return t.hp>0 and t.has("parasite_at")).size()<int(db.data.chapter_four.enemy_limits.cysts):
			var cyst={"kind":"growth","p":m.p,"variant":1,"id":next_id(),"phase":float(m.id)}
			make_threat(cyst,db.data.chapter_four.growth);cyst.hp=18.0;cyst.max_hp=18.0;cyst.radius=9.0;cyst.timer=999.0
			cyst.parasite_at=clock+float(m.ai.cyst_delay);cyst.parasites_left=3;cyst.expires_at=clock+float(m.ai.cyst_life)
			landmarks.append(cyst);add_solid(cyst.p,cyst.radius)
		mobs.remove_at(i)
	super.resolve_deaths()

func make_threat(mark: Dictionary, rules: Dictionary):
	mark.merge({"hp": float(rules.hp), "max_hp": float(rules.hp), "radius": float(rules.radius), "timer": 2.0 + fposmod(mark.phase, 3), "attack": "idle", "flash": 0.0, "burn": 0.0, "burn_tick": .5, "visual": animation.actor(), "knock": Vector2.ZERO, "boss": false, "control_resist": 0.0, "undead": true, "aim": Vector2.DOWN, "link": -1, "dead": false})
	threats.append(mark)

func in_blood(p: Vector2) -> bool:
	return pools.has(Vector2i((p / 16).floor()))

func move_actor(p: Vector2, velocity: Vector2, radius: float) -> Vector2:
	# Keep long steps from tunnelling through the ruined walls and pyramid.
	var steps := maxi(1, ceili(velocity.length() / 4.0))
	for i in range(steps):p = super.move_actor(p, velocity / steps, radius)
	if stage == "finale" and ending.fighting():
		p = p.clamp(ending.arena.position + Vector2.ONE * (8 + radius), ending.arena.end - Vector2.ONE * (8 + radius))
	return p

func camera() -> Vector2:
	if stage == "finale" and ending.phase not in ["", "summit"]:return ending.camera(self)
	var cam: Vector2 = super.camera()
	if stage == "arrival":cam += Vector2(0, -24 * (1 - smoothstep(0, float(db.data.chapter_four.arrival_duration), stage_age)))
	return cam

func rebuild_hit_grid():
	super.rebuild_hit_grid()
	for m in threats:
		if m.hp <= 0:continue
		var cell := Vector2i(m.p / CELL)
		if not hit_grid.has(cell):hit_grid[cell] = []
		hit_grid[cell].append(m)
	for m in ending.candidates()+encounters.candidates():
		var cell:=Vector2i(m.p/CELL)
		if not hit_grid.has(cell):hit_grid[cell]=[]
		hit_grid[cell].append(m)

func hurt(m: Dictionary, amount: float, push: Vector2 = Vector2.ZERO):
	if m.get("allied",false) or m.hp<=0:return
	if not arsenal.piercing:amount*=1-clampf(float(m.get("guard",0)),0,.8)
	amount*=1+minf(4,m.get("ch4_cracks",0))*.025
	if m.has("finale_actor"):ending.hurt(self,m,amount,push);return
	if m.has("encounter_actor"):encounters.hurt(self,m,amount,push);return
	var before: float=m.hp
	if not m.has("attack"):
		if m.has("form"):
			var kind: String=m.kind
			m.kind=db.data.forms[kind].base
			super.hurt(m,amount,push)
			m.kind=kind
			fx.hit(self,m,minf(before,amount),push,damage_owner)
			arsenal.melee_hit(self,m,minf(before,amount))
			if m.hp>0:
				if kind=="bellringer" and m.phase=="windup":Enemies.cancel(m,1.6)
				if kind=="infected_witch" and m.phase=="windup" and m.cast=="heal":Enemies.cancel(m,1.3)
				if kind in ["matted_sheep","fused_villagers"] and not m.changed and m.hp<m.max_hp*m.ai.shed_hp:
					m.changed=true;m.speed*=m.ai.shed_speed;m.skin="ch4_sheared_sheep" if kind=="matted_sheep" else "ch4_fused_lower"
					if kind=="matted_sheep":m.hp=minf(m.hp,9)
					add_effect("ch4_shed",m.p,.6);Enemies.cancel(m,.3)
			return
		super.hurt(m, amount, push)
		arsenal.melee_hit(self,m,minf(before,amount))
		return
	if m.hp <= 0:return
	if not m.get("expiring",false):damage_by[damage_owner] = damage_by.get(damage_owner, 0.0) + minf(m.hp, amount)
	m.hp -= amount;m.flash = .1
	emit_pixels("impact", m.p - Vector2(0, 10), 3, push)
	fx.hit(self,m,amount,push,damage_owner)
	if m.hp <= 0:
		m.attack = "dead";m.dead = true
		fx.erupt(self,m.p,"flesh" if m.kind != "torch" else "dirt",7 if m.kind == "growth_big" else 4)
		if m.kind != "torch":
			var grid_cell := Vector2i(m.p / 64.0)
			solid_grid[grid_cell] = solid_grid[grid_cell].filter(func(s):return s.p != m.p)
			var nav_cell := Vector2i(m.p / CELL)
			if not nearby_solids(m.p).any(func(s):return Vector2i(s.p/CELL) == nav_cell):blocked.erase(nav_cell)
			update_flow()
		if not m.get("expiring",false):drop_xp(m.p, 3 if m.kind == "torch" else 6)
		sound("ch4_break")

func hook_target(m: Dictionary, evolved_hook: bool):
	if m.has("finale_actor"):ending.hooked(self,m);return
	if m.get("encounter_actor","") in ["golem","golem_node","guardian_torch"]:return
	if m.get("encounter_actor","")=="mass_part":m=encounters.mass
	if not m.has("attack"):
		if m.get("control_resist",0.0)>0:return
		super.hook_target(m, evolved_hook)
		if m.has("form") and m.phase in ["windup","smash_wait"]:Enemies.cancel(m)
		if m.has("encounter_actor") and m.phase=="windup":encounters.enter(m,"recover",.65)

func aura_near() -> bool:
	for mark in landmarks:
		if mark.kind == "crucifix" and player.distance_to(mark.p) < float(db.data.aura.radius):return true
	return false

func update_aura():
	var next := ("rage" if note_read else "despair") if aura_near() else "none"
	if next != aura_state:
		aura_state = next;aura_changed_at = clock
		if next != "none":sound("ch4_rage" if next == "rage" else "ch4_despair", 1.0)
	db.data.aura_damage = 1.0 if next == "none" else float(db.data.aura[next + "_damage"])
	db.data.aura_interval = 1.0 if next == "none" else float(db.data.aura[next + "_interval"])

func read_note():
	if note_read:return
	note_read = true;note_pending = false
	update_aura()
	aura_changed_at = clock
	sound("ch4_note")

func update_threats(dt: float):
	for m in threats:
		if m.hp <= 0:continue
		if encounters.current=="guardian" and encounters.arena().grow(40).has_point(m.p):m.attack="idle";m.timer=maxf(m.timer,.5);continue
		m.flash = maxf(0, m.flash - dt)
		if m.burn > 0:
			m.burn -= dt;m.burn_tick -= dt
			if m.burn_tick <= 0:
				m.burn_tick += .5;damage_owner = "fire";hurt(m, burn_damage(m))
		if m.hp <= 0:continue
		m.timer -= dt
		var rules: Dictionary = db.data.chapter_four.cursed_torch if m.kind == "torch" else db.data.chapter_four.growth
		if m.attack == "idle" and m.timer <= 0 and m.p.distance_to(player) < float(rules.range):
			m.attack = "windup";m.timer = float(rules.windup);m.aim = m.p.direction_to(player)
			if m.kind == "torch":
				m.link = -1
				for other in threats:
					if other.kind == "torch" and other.hp > 0 and other.id != m.id and other.p.distance_to(m.p) < 150:
						m.link = other.id;break
				if m.link < 0:m.attack = "idle";m.timer = rules.cooldown;continue
			if visible(m.p, 40):sound("ch4_charge", .8)
		elif m.attack == "windup" and m.timer <= 0:
			if m.kind == "torch":
				var other = linked_torch(m)
				if other != null:
					add_effect("ch4_arc", m.p, .22, {"end": other.p, "seed": m.id})
					if Geometry2D.get_closest_point_to_segment(player, m.p, other.p).distance_to(player) < float(rules.width):damage_player(rules.damage)
			else:
				for j in range(int(rules.count)):
					var a := (float(j) / maxf(1, rules.count - 1) - .5) * float(rules.spread)
					blood_shots.append({"p": m.p, "dir": m.aim.rotated(a), "life": float(rules.range) / float(rules.speed), "speed": float(rules.speed), "damage": float(rules.damage)})
				if visible(m.p, 40):sound("ch4_pulse", .3)
			m.attack = "recover";m.timer = .45
		elif m.attack == "recover" and m.timer <= 0:
			m.attack = "idle";m.timer = float(rules.cooldown)
		if m.kind == "torch" and m.attack == "windup" and linked_torch(m) == null:
			m.attack = "idle";m.timer = float(rules.cooldown)
	for i in range(blood_shots.size() - 1, -1, -1):
		var b = blood_shots[i]
		var before: Vector2 = b.p
		b.p += b.dir * b.speed * dt;b.life -= dt
		if Geometry2D.get_closest_point_to_segment(player, before, b.p).distance_to(player) < 8:
			damage_player(b.damage);b.life = 0
		if b.life <= 0:blood_shots.remove_at(i)
	update_hand(dt)

func linked_torch(m: Dictionary):
	for other in threats:
		if other.id == m.link and other.hp > 0:return other
	return null

func update_hand(dt: float):
	held = maxf(0, held - dt)
	hand_cooldown -= dt
	var rules: Dictionary = db.data.chapter_four.blood_hand
	if blood_hand.is_empty():
		if hand_cooldown <= 0 and in_blood(player):
			blood_hand = {"p": player, "age": 0.0, "caught": false}
			sound("ch4_hand")
		return
	blood_hand.age += dt
	if blood_hand.age >= float(rules.windup) and not blood_hand.caught:
		blood_hand.caught = true
		if in_blood(player) and player.distance_to(blood_hand.p) < float(rules.radius):
			damage_player(rules.damage);held = float(rules.hold)
	if blood_hand.age >= float(rules.windup) + .8:
		blood_hand.clear();hand_cooldown = float(rules.cooldown)

func step(dt: float, movement: Vector2 = Vector2.ZERO):
	if state != "RUNNING":return
	track_progress(dt)
	clock += dt;stage_age += dt
	invulnerable = maxf(0, invulnerable - dt);shake = maxf(0, shake - dt)
	message_timer = maxf(0, message_timer - dt)
	if stage == "arrival":
		player_visual.travel = 0;player_moving = false
		animation.advance(self, dt)
		var total: float = float(db.data.chapter_four.arrival_duration)
		if stage_age >= total-1.25 and stage_age-dt < total-1.25:sound("ch4_hb_twitch")
		if stage_age >= total:stage = "survival";stage_age = 0
		return
	time = minf(db.data.duration, time + dt)
	if stage == "survival" and time >= float(db.data.duration) and not ending.active():
		stage = "finale";ending.begin_summit(self)
	if stage == "finale" and ending.locked():
		var before_lock: Vector2 = player
		ending.step(self,dt,movement)
		player_visual.travel = before_lock.distance_to(player);player_moving = player_visual.travel > .0001
		animation.advance(self, dt);update_particles(dt);update_effects(dt);fx.update(self,dt)
		return
	if stage == "survival" and fx.opening == 0 and stage_age >= .45:first_contact()
	arsenal.tick(self,dt,movement)
	var before: Vector2 = player
	if arsenal.bat_left>0:
		movement=arsenal.bat_direction
		invulnerable=maxf(invulnerable,.08)
	if movement.length_squared() > 0:
		facing = movement.normalized()
		player = move_actor(player, movement.limit_length() * movement_speed() * dt, 6)
		moved += dt
	tracked_velocity = tracked_velocity.lerp((player - before) / maxf(.0001, dt), minf(1, dt * 10))
	player_visual.travel = before.distance_to(player);player_moving = player_visual.travel > .0001
	flow_timer -= dt
	if flow_timer <= 0 and flow_cell != Vector2i(player / CELL):update_flow();flow_timer = .25
	update_aura()
	if not db.data.chapter_four.exploration_only and time<float(db.data.duration) and stage == "survival":spawn_wave(dt)
	move_mobs(dt)
	encounters.tick(self,dt)
	rebuild_hit_grid()
	update_attacks(dt);update_projectiles(dt);update_explosives(dt)
	arsenal.step(self,dt)
	update_hazards(dt);update_fire(dt);update_threats(dt);resolve_deaths()
	Enemies.environment(self,dt)
	update_effects(dt);pickup(dt);update_particles(dt);fx.update(self,dt)
	animation.advance(self, dt);update_regeneration(dt)
	Enemies.poses(self)
	encounters.poses(self)
	if hp<=0:try_totem()
	if stage == "finale":ending.step(self,dt,movement)
	if hp <= 0:
		state = "RESULT";victory = false;sound("death");return
	if xp >= db.required_xp(level):next_level()
	elif not pending_chest.is_empty():open_chest(pending_chest)
	if not note_presented:
		var note := Vector2(terrain.note[0], terrain.note[1])
		if player.distance_to(note) < 18:note_presented = true;note_pending = true

## The first enemies of the chapter do not walk in: they claw out of the soil
## around the hero. Skipped in exploration fixtures and when the run starts late.
func first_contact():
	fx.opening = 1
	if db.data.chapter_four.exploration_only or time > 3.0:return
	var risen := 0
	for j in range(8):
		if risen >= 6:break
		var p: Vector2 = player + Vector2.from_angle(j * TAU / 8 + .35) * (96 + j % 2 * 22)
		if not free_at(p, 9) or in_blood(p) or not spawn("flayed_zombie", p):continue
		var m: Dictionary = mobs.back()
		m.stun = 1.2 + risen * .07;m.emerge = clock + risen * .07;m.visual_dir = p.direction_to(player);m.dir = m.visual_dir
		fx.erupt(self, p, "dirt", 5)
		risen += 1
	if risen > 0:
		sound("ch4_growth_rip");shake = maxf(shake, .2)
		fx.shove(self, Vector2(0, 1), 2.0)

func close_chest():
	var evolution: bool = state == "CHEST" and chest_delay <= 0 and chest_reward.get("evolution", false)
	var id: String = chest_reward.get("id", "")
	super.close_chest()
	if evolution:fx.evolve(self, id)

func movement_speed() -> float:
	if arsenal.bat_left>0:return float(arsenal.rules(self).bat_speed)
	return float(db.data.player_speed) * (1 + .08 * items.get("sugar", 0)) * (.15 if held > 0 else mob_slow)

func active_item(id: String) -> bool:
	if stage=="arrival" or (stage=="finale" and ending.locked()):return false
	return arsenal.activate(self,id)

func eligible() -> Array:
	return super.eligible().filter(func(id):return not evolved.has(id) and (not db.weapons.has(id) or db.weapons[id].get("lootable",true)) and not (build.has("sky_tnt") and id in ["fishing","tnt"]) and not (id=="empty_totem" and arsenal.totem_spent and items.has(id)))

func evolution_candidates(born: float) -> Array:
	if born<360:return []
	return db.recipes.keys().filter(func(id):return Equipment.ready(self,id))

func open_chest(chest: Dictionary):
	var candidates: Array=evolution_candidates(chest.born)
	if candidates.is_empty():super.open_chest(chest);return
	var id: String=candidates[rng.randi_range(0,candidates.size()-1)]
	run_progress.observe(self)
	var recipe: Dictionary=db.recipes[id]
	for ingredient in recipe.get("consume",[]):
		var prior: String=state;state="PAUSED";discard(ingredient);state=prior
	if not recipe.get("consume",[]).is_empty():build[id]=8;cooldowns[id]=.3
	evolved[id]=true
	arsenal.clear(id)
	run_progress.evolution(id);run_progress.observe(self)
	chest_reward={"id":id,"evolution":true,"text":recipe.effect}
	pending_chest={};chest_delay=.65;state="CHEST";sound("chest")

func discard(id: String) -> bool:
	if not super.discard(id):return false
	evolved.erase(id);arsenal.clear(id)
	# Consumed rods cannot leave hooks pulling enemies after the fusion.
	if id=="fishing":projectiles=projectiles.filter(func(b):return b.kind!="hook")
	return true

func update_attacks(dt: float):
	var all: Dictionary=build
	build={}
	for id in all:
		if not arsenal.own(self,id):build[id]=all[id]
	super.update_attacks(dt)
	build=all
	arsenal.update_attacks(self,dt)

func receive_hit(amount: float,attacker: Dictionary):
	arsenal.incoming=attacker;damage_player(amount);arsenal.incoming={}

func damage_player(amount: float):
	if invulnerable>0 or hp<=0:return
	var armor: float=.2*items.get("armor",0)
	var protection: float=float(arsenal.rules(self).bedrock_defense)*items.get("bedrock",0) if arsenal.still>=.7 else 0.0
	var taken: float=maxf(1,amount-armor)*(1-protection)
	hp-=taken;run_progress.damage(taken)
	invulnerable=.95 if evolved.has("armor") and items.has("armor") else .65
	player_visual.hurt=.12;shake=.12;sound("hurt",.15);add_effect("player_hit",player,.22)
	fx.spray(player,Vector2.ZERO if arsenal.incoming.is_empty() else arsenal.incoming.p.direction_to(player),5,80.0,1.4)
	var attacker: Dictionary=arsenal.incoming
	if not attacker.is_empty():player=move_actor(player,resist_displacement(attacker.p.direction_to(player)*9),6)
	if not attacker.is_empty() and attacker.hp>0 and items.has("thorns") and arsenal.retaliation<=0:
		arsenal.retaliation=float(arsenal.rules(self).maiden_interval)
		arsenal.hit(self,attacker,float(arsenal.rules(self).thorns_damage)*items.thorns*(1.5 if evolved.has("armor") else 1),"thorns",Vector2.ZERO,true)
		if evolved.has("armor") and arsenal.heal_lock<=0 and hp>0:hp=minf(20,hp+.35)
		add_effect("ch4_thorns",player,.25,{"end":attacker.p});fx.pulse(self,"thorns")
	if hp<=0:try_totem()

func try_totem() -> bool:
	if hp>0 or not items.has("empty_totem") or arsenal.totem_spent:return false
	arsenal.totem_spent=true;hp=3+3*items.empty_totem;invulnerable=2.2+.2*items.empty_totem;sound("ch4_totem");add_effect("ch4_revive",player,1.2);fx.pulse(self,"revive")
	return true

func resist_displacement(velocity: Vector2) -> Vector2:
	return velocity*(1-.12*items.get("bedrock",0))

func update_regeneration(dt: float):
	if arsenal.heal_lock>0:return
	super.update_regeneration(dt)

func neutral(m: Dictionary) -> bool:
	return m.get("allied",false)

func spawn_wave(dt: float):
	super.spawn_wave(dt*float(encounters.data.rules.wave_scale) if encounters.busy() else dt)

func replace_special_solids(owner: String,positions: Array,radius: float):
	# Batch replacement updates navigation once, rather than once per stone.
	var changed: Dictionary={}
	for cell in solid_grid.keys():
		var previous: Array=solid_grid[cell]
		for solid in previous:
			if solid.get("encounter","")==owner:changed[Vector2i(solid.p/CELL)]=true
		solid_grid[cell]=previous.filter(func(s):return s.get("encounter","")!=owner)
	for cell in changed:
		if not nearby_solids(Vector2(cell*CELL)+Vector2.ONE*CELL/2).any(func(s):return Vector2i(s.p/CELL)==cell):blocked.erase(cell)
	for p in positions:
		var cell:=Vector2i(p/64)
		if not solid_grid.has(cell):solid_grid[cell]=[]
		solid_grid[cell].append({"p":p,"r":radius,"encounter":owner});blocked[Vector2i(p/CELL)]=true
	if not changed.is_empty() or not positions.is_empty():update_flow()
