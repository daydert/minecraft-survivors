extends "res://scripts/world.gd"
## Changes to solo campaign rules are isolated from coop_world.gd.

var win_music=false
var boss_victory_serial=0
var run_progress=preload("res://scripts/run_progress.gd").new()

func chapter_number() -> int:
	return 1

func reset(seed_value: int = 0):
	db=preload("res://scripts/campaign_data.gd").new()
	db.configure(chapter_number())
	win_music=false
	boss_victory_serial=0
	super.reset(seed_value)
	if chapter_number()==1:finale=preload("res://scripts/herobrine_encounter.gd").new()
	run_progress.reset(chapter_number());run_progress.observe(self)

func step(dt: float, movement: Vector2=Vector2.ZERO):
	if state in ["RUNNING","FINALE"]:track_progress(dt)
	super.step(dt,movement)
	if chapter_number()==1 and finale.complete:run_progress.finish(self)

func track_progress(dt: float):
	run_progress.step(self,dt)

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
