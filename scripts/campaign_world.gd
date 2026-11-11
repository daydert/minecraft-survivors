extends "res://scripts/world.gd"
## Changes to solo campaign rules are isolated from coop_world.gd.

var win_music=false
var boss_victory_serial=0
var run_progress=preload("res://scripts/run_progress.gd").new()
## Damage dealt per weapon in this run (presentation bookkeeping, never read by combat).
var damage_by: Dictionary={}
var damage_owner="sword"
const OWNERS={"arrow":"bow","trident":"trident","fire":"fire","hoe":"hoe","hoe_spin":"hoe","bolt":"crossbow","rocket":"crossbow","hook":"fishing","cloud":"potion","bottle":"potion","fangs":"fangs","swing":"sword","axe_spin":"axe"}

func chapter_number() -> int:
	return 1

## Every chapter after the first starts with nothing: the last one ended with the gear lost,
## melted or broken. An iron sword turns up at the spawn, its own way in each
## world, and the run (clock and spawns) waits until Steve picks it up.
const SWORD_STYLES := {2:"lava",3:"sky",4:"ender",5:"void"}
const SWORD_LAND := {"ground":.9,"lava":2.4,"sky":1.25,"ender":1.9,"void":2.2}
const SWORD_REACH := 14.0
var sword_drop: Dictionary = {}

func begin_sword_drop():
	# In chapter I Steve walks in with his sword already.
	if not SWORD_STYLES.has(chapter_number()):return
	sword_drop = {"style":SWORD_STYLES.get(chapter_number(),"ground"),"age":0.0,"taken":false,"take_age":0.0,"cues":0}
	build = {}
	cooldowns.erase("sword")
	weapon_visuals.clear();attack_visuals.clear()

func sword_ready() -> bool:
	return state == "RUNNING" and (not "stage" in self or get("stage") == "survival")

## A free, reachable spot a few steps from Steve, ahead of him if possible.
func sword_spot() -> Vector2:
	for dir in [Vector2.UP, Vector2(-1, -1).normalized(), Vector2(1, -1).normalized(), Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN]:
		for dist in [40.0, 30.0, 52.0]:
			var p: Vector2 = player + dir * dist
			if free_at(p, 9) and line_clear(player, p):return p
	return player + Vector2(0, -24)

func sword_waiting() -> bool:
	return not sword_drop.is_empty() and not sword_drop.taken and sword_drop.has("p")

func sword_cue(bit: int, at: float, id: String):
	if sword_drop.age >= at and not (int(sword_drop.cues) & (1 << bit)):
		sword_drop.cues = int(sword_drop.cues) | (1 << bit)
		sound(id, .02)

## Runs instead of the chapter's step while the sword waits to be picked up.
func sword_step(dt: float, movement: Vector2) -> bool:
	if sword_drop.is_empty():return false
	if sword_drop.taken:
		sword_drop.take_age += dt
		if sword_drop.take_age > 1.2:sword_drop = {}
		return false
	if not sword_ready():return false
	if not sword_drop.has("p"):sword_drop.p = sword_spot()
	clock += dt
	sword_drop.age += dt
	invulnerable = maxf(0, invulnerable - dt);shake = maxf(0, shake - dt);message_timer = maxf(0, message_timer - dt)
	var style: String = sword_drop.style
	var land: float = SWORD_LAND[style]
	match style:
		"ground":sword_cue(0, .2, "ch1_wood_place");sword_cue(1, land, "xp")
		"lava":sword_cue(0, 0.0, "fire");sword_cue(1, 1.0, "potion_splash");sword_cue(2, land - .4, "fire")
		"sky":sword_cue(0, .1, "ch1_whoosh");sword_cue(1, land, "ch4_stone_hit");sword_cue(2, land, "mace_smash")
		"ender":sword_cue(0, .2, "end_teleport");sword_cue(1, land - .3, "end_teleport")
		"void":sword_cue(0, .1, "ch4_hb_glitch");sword_cue(1, 1.2, "ch4_hb_glitch");sword_cue(2, land, "ch4_hb_tick")
	if style == "sky" and sword_drop.age >= land and sword_drop.age - dt < land:shake = .25
	var before: Vector2 = player
	if movement.length_squared() > 0:
		facing = movement.normalized()
		player = move_actor(player, movement.limit_length() * movement_speed() * dt, 6)
	player_visual.travel = before.distance_to(player)
	player_moving = player_visual.travel > .0001
	animation.advance(self, dt)
	update_particles(dt)
	if sword_drop.age >= land and player.distance_to(sword_drop.p) < SWORD_REACH:
		sword_drop.taken = true
		build["sword"] = 1
		cooldowns["sword"] = .35
		sound("pickup")
	return true

func reset(seed_value: int = 0):
	db=preload("res://scripts/campaign_data.gd").new()
	db.configure(chapter_number())
	win_music=false
	boss_victory_serial=0
	damage_by.clear()
	super.reset(seed_value)
	if chapter_number()==1:finale=preload("res://scripts/herobrine_encounter.gd").new()
	run_progress.reset(chapter_number());run_progress.observe(self)

func step(dt: float, movement: Vector2=Vector2.ZERO):
	if state in ["RUNNING","FINALE"]:track_progress(dt)
	super.step(dt,movement)
	if chapter_number()==1 and finale.complete:run_progress.finish(self)

func track_progress(dt: float):
	run_progress.step(self,dt)

func select_attack_owner(attack: Dictionary):
	damage_owner=OWNERS.get(attack.get("kind",""),damage_owner)

func update_attacks(dt: float):
	damage_owner="sword"
	super.update_attacks(dt)

func move_mobs(dt: float):
	damage_owner="fire"
	super.move_mobs(dt)

func hurt(m: Dictionary, amount: float, push: Vector2=Vector2.ZERO):
	if m.get("dodge_all",false) and finale.has_method("dodge"):finale.dodge(self,m);return
	if m.hp>0 and amount>0:damage_by[damage_owner]=damage_by.get(damage_owner,0.0)+minf(amount,m.hp)
	super.hurt(m,amount,push)

func damage_player(amount: float):
	var before=hp
	super.damage_player(amount)
	run_progress.damage(before-hp)

func eligible() -> Array:
	var result: Array=[]
	for id in db.weapons:
		if build.has(id) and build[id]<8 and not evolved.has(id):result.append(id)
		elif not build.has(id) and build.size()<6:result.append(id)
	for id in db.passives:
		if items.has(id) and items[id]<5:result.append(id)
		elif not items.has(id) and items.size()<8:result.append(id)
	return result

func make_choices() -> Array:
	var result=super.make_choices()
	for i in range(result.size()):
		if result[i]=="emerald":result[i]="experience"
	return result

func skip_reward() -> bool:
	if state!="LEVEL_UP":return false
	choices.clear()
	if xp>=db.required_xp(level):next_level()
	elif not pending_chest.is_empty():open_chest(pending_chest)
	else:state="RUNNING"
	return true

func apply_upgrade(id: String):
	run_progress.observe(self)
	if db.passives.has(id):
		if items.get(id,0)<5 and (items.has(id) or items.size()<8):items[id]=items.get(id,0)+1
	elif id in ["emerald","experience"]:
		xp+=8
		sound("pickup")
	elif id=="golden_carrot":
		hp=minf(float(db.data.player_hp),hp+6)
		sound("pickup")
	else:super.apply_upgrade(id)
	if id in ["apple","golden_carrot"]:run_progress.healing()
	run_progress.observe(self)

func break_pumpkin(p: Dictionary):
	if p.get("has_heal",false):loot.append({"kind":"apple","p":p.p})
	add_effect("break",p.p,.3)
	sound("break")

func open_chest(chest: Dictionary):
	run_progress.observe(self)
	super.open_chest(chest)
	if chest_reward.get("evolution",false):run_progress.evolution(chest_reward.id)
	run_progress.observe(self)
	if chest_reward.get("text","")=="Восстановлено 4 HP · +25 очков":chest_reward.text="Восстановлено 4 HP · +8 опыта"

func discard(id: String) -> bool:
	if state!="PAUSED":return false
	run_progress.observe(self)
	if build.has(id):
		build.erase(id)
		evolved.erase(id)
		cooldowns.erase(id)
		attack_visuals.erase(id)
		weapon_visuals.erase(id)
		for i in range(tasks.size()-1,-1,-1):
			if tasks[i].kind==id:tasks.remove_at(i)
		return true
	if items.has(id):
		items.erase(id)
		return true
	return false

func make_map():
	super.make_map()
	assign_healing()

func assign_healing():
	var vessels=props.filter(func(p):return p.type=="pumpkin")
	var selection=RandomNumberGenerator.new()
	selection.seed=int(rng.seed)^0x59a13be
	for p in vessels:p.has_heal=false
	for i in range(vessels.size()-1,0,-1):
		var j=selection.randi_range(0,i)
		var swap=vessels[i];vessels[i]=vessels[j];vessels[j]=swap
	for i in range(vessels.size()/2):vessels[i].has_heal=true

func movement_speed() -> float:
	return db.data.player_speed*(1+.08*items.get("sugar",0))

func boss_defeated(kind: String):
	if not ((kind=="wither" and chapter_number()==2) or (kind=="endersteve_final" and chapter_number()==3)):return
	boss_victory_serial+=1
	win_music=true
	if hp>0:run_progress.finish(self)
	sound("boss_win",.2)

func resolve_deaths():
	for m in mobs:
		if m.hp<=0 and m.kind in ["ravager","brute","wither"]:boss_defeated(m.kind)
	super.resolve_deaths()

func sound(id: String, gap: float=.04):
	super.sound("hurt" if id=="hurt_herobrine" else id,gap)
