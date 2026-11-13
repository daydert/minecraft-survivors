extends "res://scripts/game_data.gd"
const EYE_TEXT := ["Ещё один предмет на выбор", "Один переброс при новом уровне", "Пятый предмет на выбор", "Ещё два варианта над и под центральной карточкой", "Шанс 4% — предмет сразу с эволюцией"]
const FourEquipment=preload("res://scripts/chapter_four_equipment.gd")
## Solo equipment presentation. Network data and balance remain untouched.

func configure(chapter: int):
	data.passives.hopper.effect="Притяжение опыта +85% за уровень · подтягивает и лечение"
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
	if chapter==5:
		var five: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_five_balance.json"))
		data.mobs.merge(five.mobs,true)
		data.waves=five.waves
		data.events=five.events
		data.duration=five.duration
		data.mob_cap=five.mob_cap
		data.chapter_five=five
		var arsenal: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_five_arsenal.json"))
		data.five_arsenal=arsenal
		for group in ["weapons","upgrades","passives","recipes"]:data[group].merge(arsenal[group],true)
		for id in arsenal.exclude_weapons:weapons.erase(id);recipes.erase(id)
		for id in arsenal.exclude_passives:passives.erase(id)
		return
	if chapter==4:
		# IV extends the solo arsenal with its own equipment, recipes and rules.
		var four: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_four_balance.json"))
		data.waves=four.waves
		data.events=four.events
		data.rules=four.rules
		data.forms=four.forms
		data.aura=four.aura
		data.duration=four.duration
		data.mob_cap=four.mob_cap
		data.chapter_four=four
		data.aura_damage=1.0
		data.aura_interval=1.0
		for id in four.remove_passives:data.passives.erase(id)
		for form in four.forms:
			var def: Dictionary=four.forms[form]
			data.mobs[form]={"hp":def.hp,"speed":def.speed,"damage":def.damage,"xp":def.xp,"radius":def.radius}
		FourEquipment.configure(self)
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
	if data.has("four_arsenal") and evolution and recipes.has(id):return recipes[id].name
	if id in ["sword","axe","hoe","armor","spear"]:
		var material = "Незеритовый" if level >= (5 if id=="armor" else 8) else "Алмазный" if level>= (3 if id=="armor" else 4) else "Железный"
		if id=="hoe": material = material.trim_suffix("ый")+"ая"
		if id=="spear":material=material.trim_suffix("ый")+"ое"
		return material+" "+{"sword":"меч","axe":"топор","hoe":"мотыга","armor":"нагрудник","spear":"копьё"}[id] if not evolution or id=="sword" else title(id,true)
	return title(id,evolution)

func equipment_icon(id: String, level: int, evolution: bool = false) -> String:
	if data.has("four_arsenal"):
		var four_icon: String=FourEquipment.icon(self,id,evolution)
		if not four_icon.is_empty():return four_icon
	if id in ["sword","axe","hoe","armor","spear"]:
		var tier = "netherite" if (evolution and id!="armor") or level >= (5 if id=="armor" else 8) else "diamond" if level >= (3 if id=="armor" else 4) else "iron"
		return id+"_"+tier
	return icon(id,evolution)

func title(id: String, evolution: bool = false) -> String:
	if data.has("five_arsenal") and id=="healing_v":return "Зелье лечения"
	return {"golden_carrot":"Золотая морковь","experience":"Опыт","ender_eye":"Око Эндера"}.get(id,super.title(id,evolution))

## What the next level of a chapter IV passive changes, in its own numbers.
func four_passive(id: String, level: int) -> String:
	var r: Dictionary=data.four_arsenal.rules;var n:=level;var m:=level+1
	match id:
		"bedrock":return "Отбрасывание −%d%% → −%d%% · защита стоя %d%% → %d%%"%[12*n,12*m,int(100*float(r.bedrock_defense)*n),int(100*float(r.bedrock_defense)*m)]
		"thorns":return "Ответный урон %s → %s"%[number(float(r.thorns_damage)*n),number(float(r.thorns_damage)*m)]
		"bat_wings":return "Вампиризм %d%% → %d%% урона · до %s → %s HP/с"%[n,m,number(float(r.vamp_per_level)*n),number(float(r.vamp_per_level)*m)]
		"heart_booster":return "Ускорение ×%s → ×%s · перезарядка %d → %d с%s"%[number(r.heart_speed[n-1]),number(r.heart_speed[m-1]),int(r.heart_recharge[n-1]),int(r.heart_recharge[m-1])," · второй заряд" if m==4 else ""]
		"mirror_shard":return "Повтор после %d → %d ударов · сила %d%% → %d%%"%[int(r.mirror_hits[n-1]),int(r.mirror_hits[m-1]),int(100*(float(r.mirror_scale)-.03*(5-n))),int(100*(float(r.mirror_scale)-.03*(5-m)))]
		"black_candle":return "Урон стоя до +%d%% → +%d%%"%[int(100*float(r.candle_per_level)*n),int(100*float(r.candle_per_level)*m)]
		"empty_totem":return "Здоровье после возрождения %d → %d"%[3+3*n,3+3*m]
		"gunpowder":return "Взрывной урон +%d%% → +%d%%"%[6*n,6*m]
		"minecart":return "Поездка %s → %s с · таран %d → %d · перезарядка %d → %d с"%[number(float(r.cart_duration)+float(r.cart_duration_per_level)*(n-1)),number(float(r.cart_duration)+float(r.cart_duration_per_level)*(m-1)),int(float(r.cart_damage)+float(r.cart_damage_per_level)*(n-1)),int(float(r.cart_damage)+float(r.cart_damage_per_level)*(m-1)),int(maxf(4.0,float(r.cart_cooldown)-float(r.cart_cooldown_per_level)*(n-1))),int(maxf(4.0,float(r.cart_cooldown)-float(r.cart_cooldown_per_level)*(m-1)))]
		"end_eye":return EYE_TEXT[clampi(n,0,4)]
	return ""

func description(id: String, level: int) -> String:
	if id=="healing_v":return "Восстанавливает 4 HP"
	if data.has("five_arsenal"):
		var five: Dictionary=data.five_arsenal
		if five.passives.has(id):
			if id=="recovery_compass" and level>0:return "Перезарядка отката %d → %d с"%[int(five.rules.compass_cooldown[mini(level,5)-1]),int(five.rules.compass_cooldown[mini(level,4)])]
			return five.passives[id].effect
		if five.descriptions.has(id):
			if level==0:return five.descriptions[id]
			var a: Dictionary=stats(id,level);var b: Dictionary=stats(id,mini(8,level+1))
			var labels: Dictionary={"damage":"Урон","interval":"Интервал","radius":"Радиус","count":"Количество","duration":"Длительность","speed":"Скорость"}
			labels.merge(five.labels.get(id,{}),true)
			for key in ["damage","interval","radius","count","duration","speed"]:
				if a.get(key,0)!=b.get(key,0):return "%s %s → %s%s"%[labels[key],number(a.get(key,0)),number(b.get(key,0))," с" if key in ["interval","duration"] else ""]
			return five.descriptions[id]
	if data.has("four_arsenal") and level>0 and level<5 and (data.four_arsenal.passives.has(id) or id=="end_eye"):
		var text: String=four_passive(id,level)
		if not text.is_empty():return text
	if data.has("four_arsenal") and data.four_arsenal.descriptions.has(id):
		if level==0:return data.four_arsenal.descriptions[id]
		var a: Dictionary=stats(id,level);var b: Dictionary=stats(id,mini(8,level+1))
		for key in ["damage","interval","radius","pellets","reach","duration"]:
			if a.get(key,0)!=b.get(key,0):return "%s %s → %s"%[{"damage":"Урон","interval":"Интервал","radius":"Область","pellets":"Дробь","reach":"Дальность","duration":"Длительность"}[key],number(a.get(key,0)),number(b.get(key,0))]
		return data.four_arsenal.descriptions[id]
	var descriptions={"axe":"Бьёт вокруг героя.","hoe":"Вращается на месте первого попадания.","bed":"Взрывается при приближении. Блок защищает от взрыва.","tnt":"Заряды появляются по очереди. Движение задаёт сторону разлёта.","crossbow":"Стреляет пробивающими болтами.","fishing":"Притягивает врагов и ненадолго оглушает.","golden_carrot":"Восстанавливает 6 HP","experience":"Даёт 8 опыта"}
	if descriptions.has(id) and (level==0 or not weapons.has(id)):return descriptions[id]
	if id in ["spear","mace","end_crystal","knockback_stick","dragon_breath","shield"]:
		if level==0:return {"spear":"Рывок вперёд с неуязвимостью. Урон растёт от скорости.","mace":"Прыжок и тяжёлый удар по области. Урон растёт от высоты.","end_crystal":"Ставит на обсидиан и взрывает каждые 10 с.","knockback_stick":"Сильно отбрасывает врагов. Столкновения наносят урон.","dragon_breath":"Оставляет облако дыхания на месте ближайшего врага.","shield":"Прикрывает спереди от ударов и снарядов. Заряды восстанавливаются."}[id]
		var a=stats(id,level);var b=stats(id,level+1)
		var labels={"damage":"Урон","radius":"Радиус","interval":"Интервал","range":"Дальность","speed":"Сила рывка","height":"Высота прыжка","force":"Отдача","duration":"Облако","count":"Удары щита"}
		for k in labels:
			if a.get(k,0)!=b.get(k,0):return "%s %s → %s%s" % [labels[k],number(a.get(k,0)),number(b.get(k,0))," с" if k in ["interval","duration"] else ""]
	if id=="end_eye" and data.has("four_arsenal"):return four_passive(id,level)
	if id=="end_eye":return EYE_TEXT[clampi(level,0,4)]
	if id=="rabbit_foot":return "Шанс лечения с врагов +3%" if level<4 else "Шанс +3% · вместо яблок золотая морковь"
	if id=="elytra":return "Пробел — полёт над пропастью · в воздухе неуязвим" if level==0 else "Полёт +0,6 с · перезарядка −0,7 с · удар при посадке сильнее"
	if id=="ender_pearl":return "E — бросок жемчуга и телепорт" if level==0 else "Перезарядка −1 с"
	if id=="shulker_shell":return "Спасает от падения в пропасть" if level==0 else "Перезарядка −6 с · урон падения −10%"
	var text=super.description(id,level)
	if id=="hoe":text=text.replace("Облако","Вращение")
	if id in ["tnt","fishing","crossbow"]:text=text.replace("Снаряды",{"tnt":"Заряды","fishing":"Крючки","crossbow":"Болты"}[id])
	return text

func stats(id: String, level: int, evolution: bool = false, items: Dictionary = {}) -> Dictionary:
	if data.has("four_arsenal"):return FourEquipment.stats(self,id,level,evolution,items)
	return stats_standard(id,level,evolution,items)

func stats_standard(id: String, level: int, evolution: bool = false, items: Dictionary = {}) -> Dictionary:
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
	if data.has("five_arsenal"):s.interval*=1.0-.05*items.get("chain_block",0)
	if data.has("chapter_four"):
		s.damage*=float(data.aura_damage)
		s.interval*=float(data.aura_interval)
	return s
