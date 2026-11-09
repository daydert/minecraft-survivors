extends "res://scripts/game_data.gd"
## Solo equipment presentation. Network data and balance remain untouched.

func configure(chapter: int):
	if chapter < 2:
		var overworld: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/overworld_balance.json"))
		data.mobs.merge(overworld.mobs,true)
		data.night = overworld.night
		return
	var extra: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/nether_balance.json"))
	for group in ["weapons","upgrades","passives","recipes","mobs"]:
		data[group].merge(extra[group],true)
	data.waves = extra.waves
	data.events = extra.events
	data.rules = extra.rules
	data.bastion = extra.bastion
	if chapter==4:
		# Chapter IV keeps the chapter I–II arsenal; its mobs, waves and rules are its own.
		var four: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_four_balance.json"))
		data.waves=four.waves
		data.events=four.events
		data.rules=four.rules
		data.forms=four.forms
		data.aura=four.aura
		data.duration=four.duration
		data.chapter_four=four
		data.aura_damage=1.0
		data.aura_interval=1.0
		for id in four.remove_passives:data.passives.erase(id)
		for form in four.forms:
			var def: Dictionary=four.forms[form]
			data.mobs[form]={"hp":def.hp,"speed":def.speed,"damage":def.damage,"xp":def.xp,"radius":def.radius}
		return
	if chapter==3:
		extra=JSON.parse_string(FileAccess.get_file_as_string("res://data/end_balance.json"))
		for group in ["weapons","upgrades","passives","recipes","mobs"]:data[group].merge(extra[group],true)
		data.waves=extra.waves
		data.events=extra.events
		data.rules=extra.rules
		data.end_city=extra.end_city
		data.void_gust=extra.void_gust
		for id in ["gold_boots","fire_resist"]:data.passives.erase(id)
		data.recipes.bed.passive="shulker_shell"
		data.recipes.fishing.passive="ender_pearl"
		data.recipes.dragon_breath.passive="ghast_tear"

func equipment_title(id: String, level: int, evolution: bool = false) -> String:
	if id in ["sword","axe","hoe","armor","spear"]:
		var material = "Незеритовый" if level >= (5 if id=="armor" else 8) else "Алмазный" if level>= (3 if id=="armor" else 4) else "Железный"
		if id=="hoe": material = material.trim_suffix("ый")+"ая"
		if id=="spear":material=material.trim_suffix("ый")+"ое"
		return material+" "+{"sword":"меч","axe":"топор","hoe":"мотыга","armor":"нагрудник","spear":"копьё"}[id] if not evolution or id=="sword" else title(id,true)
	return title(id,evolution)

func equipment_icon(id: String, level: int, evolution: bool = false) -> String:
	if id in ["sword","axe","hoe","armor","spear"]:
		var tier = "netherite" if (evolution and id!="armor") or level >= (5 if id=="armor" else 8) else "diamond" if level >= (3 if id=="armor" else 4) else "iron"
		return id+"_"+tier
	return icon(id,evolution)

func title(id: String, evolution: bool = false) -> String:
	return {"golden_carrot":"Золотая морковь","experience":"Опыт","ender_eye":"Око Эндера"}.get(id,super.title(id,evolution))

func description(id: String, level: int) -> String:
	var descriptions={"axe":"Бьёт вокруг героя.","hoe":"Вращается на месте первого попадания.","bed":"Взрывается при приближении. Блок защищает от взрыва.","tnt":"Заряды появляются по очереди. Движение задаёт сторону разлёта.","crossbow":"Стреляет пробивающими болтами.","fishing":"Притягивает врагов и ненадолго оглушает.","golden_carrot":"Восстанавливает 6 HP","experience":"Даёт 8 опыта"}
	if descriptions.has(id) and (level==0 or not weapons.has(id)):return descriptions[id]
	if id in ["spear","mace","end_crystal","knockback_stick","dragon_breath","shield"]:
		if level==0:return {"spear":"Рывок вперёд с неуязвимостью. Урон растёт от скорости.","mace":"Прыжок и тяжёлый удар по области. Урон растёт от высоты.","end_crystal":"Ставит на обсидиан и взрывает каждые 10 с.","knockback_stick":"Сильно отбрасывает врагов. Столкновения наносят урон.","dragon_breath":"Оставляет облако дыхания на месте ближайшего врага.","shield":"Прикрывает спереди от ударов и снарядов. Заряды восстанавливаются."}[id]
		var a=stats(id,level);var b=stats(id,level+1)
		var labels={"damage":"Урон","radius":"Радиус","interval":"Интервал","range":"Дальность","speed":"Сила рывка","height":"Высота прыжка","force":"Отдача","duration":"Облако","count":"Удары щита"}
		for k in labels:
			if a.get(k,0)!=b.get(k,0):return "%s %s → %s%s" % [labels[k],number(a.get(k,0)),number(b.get(k,0))," с" if k in ["interval","duration"] else ""]
	if id=="end_eye":return ["Добавляет ещё один предмет на выбор.","Один переброс предметов при повышении уровня.","Ещё один предмет на выбор.","Один из пяти предметов меняется.","Три из пяти предметов меняются."][clampi(level,0,4)]
	if id=="rabbit_foot":return "Лечение с врагов: шанс +3%." if level<4 else "Шанс +3%. Вместо яблок выпадает золотая морковь."
	if id=="elytra":return "Пробел: полёт над пропастями." if level==0 else "Длительность полёта +0,5 с."
	if id=="ender_pearl":return "E: бросок жемчуга и телепортация." if level==0 else "Перезарядка −1 с."
	if id=="shulker_shell":return "Спасает от падения в пропасть." if level==0 else "Перезарядка −6 с. Урон падения −10%."
	var text=super.description(id,level)
	if id=="hoe":text=text.replace("Облако","Вращение")
	if id in ["tnt","fishing","crossbow"]:text=text.replace("Снаряды",{"tnt":"Заряды","fishing":"Крючки","crossbow":"Болты"}[id])
	return text

func stats(id: String, level: int, evolution: bool = false, items: Dictionary = {}) -> Dictionary:
	var s=super.stats(id,level,evolution,items)
	if evolution:
		match id:
			"axe":s.damage+=34*(1+.1*items.get("blaze",0));s.radius+=12;s.interval*=.9
			"hoe":s.damage+=5*(1+.1*items.get("blaze",0));s.duration+=1.2;s.count=2
			"bed":s.damage+=45*(1+.1*items.get("blaze",0));s.radius+=16
			"tnt":s.count=5;s.damage+=16*(1+.1*items.get("blaze",0));s.cluster=true
			"crossbow":s.damage+=18*(1+.1*items.get("blaze",0));s.radius=42*(1+.1*items.get("amethyst",0))
			"fishing":s.count=6;s.range+=40
	if id=="bed":s.radius*=1.5
	if evolution:
		match id:
			"mace":s.height+=24
			"knockback_stick":s.force*=1.5;s.damage+=15
			"dragon_breath":s.damage+=8;s.duration+=2;s.count=2
			"shield":s.count+=3
	if id=="spear":s.damage*=1+.08*items.get("sugar",0)
	if data.has("chapter_four"):
		s.damage*=float(data.aura_damage)
		s.interval*=float(data.aura_interval)
	return s
