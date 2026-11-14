extends RefCounted
## DAVIS lab: hidden diagnostic and fun screen. Cheats last until the game closes.
## Never used by ordinary rewards or networking.
## Ready-made and custom loadouts, any boss or the whole chapter, and solo cheats.
const Equipment = preload("res://scripts/chapter_four_equipment.gd")
const WORLDS := {1:"res://scripts/overworld_world.gd",2:"res://scripts/nether_world.gd",3:"res://scripts/end_world.gd",4:"res://scripts/chapter_four_world.gd",5:"res://scripts/chapter_five_world.gd"}
const SAVE_PATH := "user://davis_lab.cfg"
const CHAPTER_TITLES := ["I · Верхний мир","II · Незер","III · Край","IV · Обычный мир","V · Исходный код"]
const WEAPON_MAX := 8
const PASSIVE_MAX := 5
const OVERCAP_WEAPON_MAX := 12
const DAMAGE_STEPS := [1.0,3.0,10.0,100.0]
const SPEED_STEPS := [1.0,1.6,2.5]
const GAME_STEPS := [1.0,.5,2.0]
const CHEATS := [
	{"id":"god","name":"Бессмертие","hint":"сердца не тратятся"},
	{"id":"damage","name":"Сила удара","hint":"урон оружия"},
	{"id":"rapid","name":"Пулемёт","hint":"атаки втрое чаще"},
	{"id":"speed","name":"Скорость героя","hint":"бег ×1,6 · ×2,5"},
	{"id":"game_speed","name":"Скорость игры","hint":"замедление или турбо"},
	{"id":"magnet","name":"Магнит опыта","hint":"опыт летит издалека"},
	{"id":"peace","name":"Без волн","hint":"враги не приходят"},
	{"id":"overcap","name":"Без лимитов","hint":"слоты и уровень 12"},
	{"id":"chain","name":"Цепная реакция","hint":"взрывы при смерти"},
	{"id":"disco","name":"Дискотека","hint":"ну а вдруг"}]
const NOW := [
	{"id":"kill","name":"Убить всех врагов"},
	{"id":"horde","name":"Орда · +40 врагов"},
	{"id":"level","name":"Новый уровень"},
	{"id":"heal","name":"Полное здоровье"},
	{"id":"time","name":"Время +1 мин"},
	{"id":"gear","name":"Выдать свой набор"},
	{"id":"target","name":"Сразу к"}]

var tab := "sets"
var target := {}
var focus := ""
var hero_level := 40
var loadouts := {}
var cheats := {"god":false,"damage":0,"rapid":false,"speed":0,"game_speed":0,"magnet":false,"peace":false,"overcap":false,"chain":false,"disco":false}
var pool_worlds := {}
## Tests switch saving off so they never touch the player's loadouts.
var persist := true

static func presets(chapter: int) -> Array:
	if chapter==5:
		return [
			{"name":"Админ","weapons":["debug_stick","command_block","barrier","structure_block","spawn_egg","repeating_block"],"items":["knowledge_book","chain_block","light_block","structure_void","name_tag","breakpoint","blaze","armor"]},
			{"name":"Ванилла","weapons":["sword","bow","axe","crossbow","command_block","barrier"],"items":["blaze","redstone","amethyst","armor","sugar","hopper","feather","ghast_tear"]},
			{"name":"Армия","weapons":["spawn_egg","repeating_block","structure_block","sword","crossbow","debug_stick"],"items":["name_tag","breakpoint","structure_void","blaze","armor","recovery_compass","redstone","chain_block"]},
			{"name":"Отладка","weapons":["debug_stick","barrier","command_block","axe","bow","structure_block"],"items":["knowledge_book","light_block","chain_block","recovery_compass","armor","blaze","amethyst","structure_void"]}]
	if chapter==4:
		return [
			{"name":"Мясорубка","weapons":["sword","bone_saw","axe","shotgun","red_torch","blood_pool"],"items":["bedrock","black_candle","gunpowder","blaze","armor","bat_wings","thorns","redstone"]},
			{"name":"Обстрел","weapons":["shotgun","bow","trident","embryo","bell","potion"],"items":["gunpowder","empty_totem","mirror_shard","redstone","amethyst","blaze","feather","end_eye"]},
			{"name":"Подрывник","weapons":["tnt","bed","shotgun","fishing","hoe","sword"],"items":["gunpowder","bedrock","blaze","armor","minecart","ghast_tear","redstone","fire_resist"]},
			{"name":"Кровь","weapons":["blood_pool","red_torch","embryo","bell","sword","potion"],"items":["black_candle","empty_totem","mirror_shard","bat_wings","heart_booster","bedrock","blaze","armor"]}]
	if chapter==3:
		return [
			{"name":"Рывок","weapons":["sword","spear","mace","shield","knockback_stick","end_crystal"],"items":["elytra","sugar","feather","shulker_shell","blaze","redstone","armor","ghast_tear"]},
			{"name":"Дыхание","weapons":["bow","trident","crossbow","dragon_breath","shield","end_crystal"],"items":["blaze","redstone","amethyst","rabbit_foot","armor","ghast_tear","shulker_shell","ender_pearl"]},
			{"name":"Край","weapons":["spear","mace","knockback_stick","end_crystal","dragon_breath","shield"],"items":["elytra","sugar","feather","amethyst","rabbit_foot","shulker_shell","armor","ghast_tear"]},
			{"name":"Смешанная","weapons":["sword","bow","mace","end_crystal","dragon_breath","shield"],"items":["blaze","redstone","amethyst","feather","rabbit_foot","shulker_shell","armor","ghast_tear"]}]
	if chapter==1:
		return [
			{"name":"Клинки","weapons":["sword","fangs","fire","potion"]},
			{"name":"Стрелы","weapons":["bow","trident","potion","fire"]},
			{"name":"Смешанная","weapons":["sword","bow","trident","fire","potion","fangs"]},
			{"name":"Пламя","weapons":["sword","fire","potion","bow","fangs"]}]
	return [
		{"name":"Клинки","weapons":["sword","axe","hoe","fishing","bed","fangs"],"items":["blaze","armor","hopper","gold_boots","amethyst","fire_resist","redstone","ghast_tear"]},
		{"name":"Стрелы","weapons":["sword","bow","trident","crossbow","tnt","potion"],"items":["blaze","redstone","amethyst","sugar","armor","fire_resist","feather","ghast_tear"]},
		{"name":"Ловушки","weapons":["axe","hoe","tnt","bed","potion","fishing"],"items":["armor","hopper","feather","fire_resist","gold_boots","redstone","blaze","ghast_tear"]},
		{"name":"Пламя","weapons":["sword","fire","bow","crossbow","fangs","fishing"],"items":["blaze","redstone","gold_boots","fire_resist","armor","amethyst","ghast_tear","sugar"]}]

## What can be started: the whole chapter or one of its bosses. The last entry is the main boss.
static func targets(chapter: int) -> Array:
	match chapter:
		1:return [{"id":"chapter","name":"Вся глава"},{"id":"herobrine","name":"Херобрин"}]
		2:return [{"id":"chapter","name":"Вся глава"},{"id":"wither","name":"Иссушитель"}]
		3:return [{"id":"chapter","name":"Вся глава"},{"id":"dragon","name":"Дракон"},{"id":"endersteve","name":"ЭндерСтив"}]
		4:return [{"id":"chapter","name":"Вся глава"},{"id":"mass","name":"Масса"},{"id":"guardian","name":"Страж"},{"id":"herobrine","name":"Херобрин"}]
		5:return [{"id":"chapter","name":"Вся глава"},{"id":"loop","name":"Цикл"},{"id":"purge","name":"Зачистка"},{"id":"notch","name":"Нотч"}]
	return []

## Kept for older callers: the preset build at once, as the boss lab always did.
static func equip(w, index: int):
	var lab=new()
	lab.apply_loadout(w,lab.preset_loadout(w,index),40)

func _init():
	load_state()

# ------------------------------------------------------------------ pools

## A fresh world of the chapter tells which weapons and items exist there.
func pool_world(chapter: int):
	if not pool_worlds.has(chapter):
		var w=load(WORLDS[chapter]).new()
		w.reset(1)
		pool_worlds[chapter]=w
	return pool_worlds[chapter]

func pool(chapter: int) -> Dictionary:
	var w=pool_world(chapter)
	var saved_build: Dictionary=w.build;var saved_items: Dictionary=w.items
	w.build={};w.items={}
	var ids: Array=w.eligible()
	w.build=saved_build;w.items=saved_items
	return {"weapons":ids.filter(func(id):return w.db.weapons.has(id)),"items":ids.filter(func(id):return w.db.passives.has(id))}

func can_evolve(chapter: int, id: String) -> bool:
	var db=pool_world(chapter).db
	return db.recipes.has(id) and db.recipes[id].get("result")==null

func weapon_cap() -> int:
	return OVERCAP_WEAPON_MAX if cheats.overcap else WEAPON_MAX

# ------------------------------------------------------------------ loadouts

func loadout(chapter: int) -> Dictionary:
	if not loadouts.has(chapter):
		var w=pool_world(chapter)
		loadouts[chapter]=preset_loadout(w,0)
	return loadouts[chapter]

func preset_loadout(w, index: int) -> Dictionary:
	var preset: Dictionary=presets(w.chapter_number())[clampi(index,0,3)]
	var result := {"weapons":{},"items":{},"evolved":{}}
	for id in preset.weapons:
		if w.db.weapons.has(id):result.weapons[id]=WEAPON_MAX
	for id in preset.get("items",["blaze","redstone","amethyst","sugar","armor","hopper"]):
		if w.db.passives.has(id):result.items[id]=PASSIVE_MAX
	# The recipe decides: the same evolutions the old boss lab granted.
	var saved_build: Dictionary=w.build;var saved_items: Dictionary=w.items;var saved_evolved: Dictionary=w.evolved
	w.build=result.weapons.duplicate();w.items=result.items.duplicate();w.evolved={}
	for id in w.db.recipes:
		var recipe: Dictionary=w.db.recipes[id]
		if recipe.get("result")!=null:continue
		var ready: bool
		if w.chapter_number()==4:ready=(w.build.has(id) or w.items.has(id)) and Equipment.ready(w,id)
		else:ready=w.build.has(id) and w.items.has(str(recipe.get("passive","")))
		if ready:result.evolved[id]=true
	w.build=saved_build;w.items=saved_items;w.evolved=saved_evolved
	return result

func use_preset(chapter: int, index: int):
	loadouts[chapter]=preset_loadout(pool_world(chapter),index)
	focus="";save_state()

func level_of(chapter: int, id: String) -> int:
	var l: Dictionary=loadout(chapter)
	return int(l.weapons.get(id,l.items.get(id,0)))

func is_weapon(chapter: int, id: String) -> bool:
	return pool_world(chapter).db.weapons.has(id)

func max_level(chapter: int, id: String) -> int:
	return weapon_cap() if is_weapon(chapter,id) else PASSIVE_MAX

func slots_free(chapter: int, id: String) -> bool:
	if cheats.overcap:return true
	var l: Dictionary=loadout(chapter)
	return l.weapons.size()<6 if is_weapon(chapter,id) else l.items.size()<8

## Click on a tile: an absent item comes in at its top level, a present one gets the focus.
func pick(chapter: int, id: String):
	var l: Dictionary=loadout(chapter)
	var group: Dictionary=l.weapons if is_weapon(chapter,id) else l.items
	if not group.has(id) and slots_free(chapter,id):group[id]=mini(max_level(chapter,id),WEAPON_MAX)
	focus=id;save_state()

func set_level(chapter: int, id: String, level: int):
	var l: Dictionary=loadout(chapter)
	var group: Dictionary=l.weapons if is_weapon(chapter,id) else l.items
	if level<=0:
		group.erase(id);l.evolved.erase(id)
	elif group.has(id) or slots_free(chapter,id):
		group[id]=clampi(level,1,max_level(chapter,id))
	save_state()

func toggle_evolution(chapter: int, id: String):
	var l: Dictionary=loadout(chapter)
	if l.evolved.has(id):l.evolved.erase(id)
	elif can_evolve(chapter,id):
		if level_of(chapter,id)==0:pick(chapter,id)
		set_level(chapter,id,max_level(chapter,id))
		l.evolved[id]=true
	save_state()

func all_max(chapter: int):
	var l: Dictionary=loadout(chapter)
	for id in l.weapons:l.weapons[id]=weapon_cap()
	for id in l.items:l.items[id]=PASSIVE_MAX
	for id in l.weapons.keys()+l.items.keys():
		if can_evolve(chapter,id):l.evolved[id]=true
	save_state()

func clear(chapter: int):
	loadouts[chapter]={"weapons":{},"items":{},"evolved":{}};focus="";save_state()

## A random build: six weapons and eight items at random levels, evolutions by chance.
func roll_random(chapter: int):
	var p: Dictionary=pool(chapter);var rng:=RandomNumberGenerator.new();rng.randomize()
	var l := {"weapons":{},"items":{},"evolved":{}}
	var weapons: Array=p.weapons.duplicate();var items: Array=p.items.duplicate()
	weapons.shuffle();items.shuffle()
	for id in weapons.slice(0,6):
		l.weapons[id]=rng.randi_range(3,WEAPON_MAX)
		if l.weapons[id]==WEAPON_MAX and can_evolve(chapter,id) and rng.randf()<.5:l.evolved[id]=true
	for id in items.slice(0,8):l.items[id]=rng.randi_range(1,PASSIVE_MAX)
	loadouts[chapter]=l;focus="";save_state()

func apply_loadout(w, l: Dictionary, level: int):
	w.run_progress.enabled=false
	if "sword_drop" in w:w.sword_drop={}
	w.build.clear();w.items.clear();w.evolved.clear();w.cooldowns.clear()
	for id in l.weapons:
		if w.db.weapons.has(id):w.build[id]=int(l.weapons[id])
	for id in l.items:
		if w.db.passives.has(id):w.items[id]=int(l.items[id])
	for id in l.evolved:
		if (w.build.has(id) or w.items.has(id)) and w.db.recipes.has(id):w.evolved[id]=true
	var beyond: bool=w.build.size()>6 or w.items.size()>8 or w.build.values().any(func(v):return v>WEAPON_MAX)
	if beyond and not w.overcap:w.overcap=true;w.set_meta("davis_overcap",true)
	if w.build.has("shield") and w.has_method("block_hit"):w.shield_charges=int(w.db.stats("shield",w.build.shield,w.evolved.has("shield"),w.items).count)
	w.level=maxi(1,level);w.xp=0;w.hp=float(w.db.data.player_hp);w.invulnerable=0

# ------------------------------------------------------------------ targets

func selected_target(chapter: int) -> String:
	var list: Array=targets(chapter)
	return list[clampi(int(target.get(chapter,list.size()-1)),0,list.size()-1)].id

func target_name(chapter: int) -> String:
	var list: Array=targets(chapter)
	return list[clampi(int(target.get(chapter,list.size()-1)),0,list.size()-1)].name

## Moves a running world of the chapter straight to `id`, keeping its gear.
static func begin_target(w, id: String):
	var chapter: int=w.chapter_number()
	match chapter:
		1:
			if id=="herobrine" and not w.finale.active:w.finale.begin(w)
		2:
			if id=="wither" and w.stage=="survival":w.begin_arena()
		3:
			if id=="dragon" and w.stage in ["survival","end_arrival"]:w.begin_arena()
			elif id=="endersteve":
				w.prepare_arena();w.mobs.clear()
				for crystal in w.crystals:crystal.alive=false
				w.hitstop=0.0
				w.stage="betrayal";w.stage_age=w.end_boss.BETRAYAL_IMPACT-.6;w.portal_lit=true
				w.player=w.portal_position+Vector2(0,62);w.facing=Vector2.UP;w.last_safe=w.player
				w.scene_camera=w.portal_position+Vector2(0,30)
		4:
			if w.stage=="arrival":w.stage="survival";w.stage_age=1.0;w.fx.opening=1
			if w.stage!="survival":return
			match id:
				"mass":w.encounters.launch_mass(w)
				"guardian":
					var arena: Rect2=w.encounters.arena()
					w.player=arena.get_center()+Vector2(0,arena.size.y*.32);w.facing=Vector2.UP
					w.encounters.launch_guardian(w)
				"herobrine":
					w.time=float(w.db.data.duration);w.stage="finale";w.stage_age=0.0
					w.ending.begin_summit(w);w.ending.start_lure(w)
		5:
			if w.stage=="notch":return
			match id:
				"loop":
					w.time=maxf(w.time,float(w.five.bosses.loop.at))
					if w.bosses.loop.is_empty() and not w.purge.active():w.bosses.begin_loop(w)
				"purge":
					if not w.purge.active():w.purge.begin(w)
				"notch":w.notch.begin(w)

# ------------------------------------------------------------------ cheats

func cheat_label(id: String) -> String:
	match id:
		"damage":return "×%s" % str(DAMAGE_STEPS[int(cheats.damage)]).trim_suffix(".0")
		"speed":return "×%s" % str(SPEED_STEPS[int(cheats.speed)]).replace(".",",").trim_suffix(",0")
		"game_speed":return ["×1","×0,5","×2"][int(cheats.game_speed)]
	return "Вкл" if cheats[id] else "Выкл"

func cheat_on(id: String) -> bool:
	return bool(cheats[id]) if typeof(cheats[id])==TYPE_BOOL else int(cheats[id])>0

func toggle_cheat(id: String):
	match id:
		"damage":cheats.damage=(int(cheats.damage)+1)%DAMAGE_STEPS.size()
		"speed":cheats.speed=(int(cheats.speed)+1)%SPEED_STEPS.size()
		"game_speed":cheats.game_speed=(int(cheats.game_speed)+1)%GAME_STEPS.size()
		_:cheats[id]=not cheats[id]
	if id=="overcap" and not cheats.overcap:
		for chapter in loadouts:
			for weapon in loadouts[chapter].weapons:loadouts[chapter].weapons[weapon]=mini(int(loadouts[chapter].weapons[weapon]),WEAPON_MAX)
	save_state()

func reset_cheats():
	for id in cheats:cheats[id]=false if typeof(cheats[id])==TYPE_BOOL else 0
	save_state()

func any_cheat() -> bool:
	return cheats.keys().any(func(id):return cheat_on(id))

func active_names() -> Array:
	var result: Array=[]
	for c in CHEATS:
		if cheat_on(c.id):result.append(c.name.to_lower()+(" "+cheat_label(c.id) if c.id in ["damage","speed","game_speed"] else ""))
	return result

func damage_scale() -> float:return float(DAMAGE_STEPS[int(cheats.damage)])
func game_scale() -> float:return float(GAME_STEPS[int(cheats.game_speed)])

# ------------------------------------------------------------------ persistence

func save_state():
	if not persist:return
	var cfg := ConfigFile.new()
	cfg.set_value("lab","loadouts",loadouts)
	cfg.set_value("lab","hero_level",hero_level)
	cfg.set_value("lab","target",target)
	cfg.save(SAVE_PATH)

func load_state():
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH)!=OK:return
	var saved=cfg.get_value("lab","loadouts",{})
	if typeof(saved)==TYPE_DICTIONARY:
		for chapter in saved:
			var l=saved[chapter]
			if typeof(l)==TYPE_DICTIONARY and l.has("weapons") and l.has("items"):
				loadouts[int(chapter)]={"weapons":l.weapons,"items":l.items,"evolved":l.get("evolved",{})}
	hero_level=clampi(int(cfg.get_value("lab","hero_level",40)),1,99)
	var t=cfg.get_value("lab","target",{})
	if typeof(t)==TYPE_DICTIONARY:target=t
