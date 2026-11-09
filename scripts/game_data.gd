class_name GameData
extends RefCounted

var data: Dictionary
var weapons: Dictionary
var passives: Dictionary
var recipes: Dictionary

func _init():
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json"))
	weapons = data.weapons
	passives = data.passives
	recipes = data.recipes

func stats(id: String, level: int, evolved: bool = false, items: Dictionary = {}) -> Dictionary:
	var s = weapons[id].duplicate(true)
	s["back"] = 0
	s["pierce"] = 0
	s["rows"] = 1
	for i in range(mini(level - 1, 7)):
		for k in data.upgrades[id][i]:
			s[k] = s.get(k, 0) + data.upgrades[id][i][k]
	if evolved and id == "sword":
		s.damage += 12
		s.radius += 12
		s.back = 1
	for k in ["damage"]:
		s[k] *= 1.0 + 0.1 * items.get("blaze", 0)
	s.interval *= 1.0 - 0.06 * items.get("redstone", 0)
	s.radius *= 1.0 + 0.1 * items.get("amethyst", 0)
	return s

func required_xp(level: int) -> int:
	return 5 + 3 * (level - 1)

func title(id: String, evolved: bool = false) -> String:
	if evolved and recipes.has(id): return recipes[id].name
	if weapons.has(id): return weapons[id].name
	if passives.has(id): return passives[id].name
	return {"apple":"Яблоко", "emerald":"Изумруд"}.get(id, id)

func icon(id: String, evolved: bool = false) -> String:
	return recipes[id].icon if evolved and recipes.has(id) else id

func description(id: String, level: int) -> String:
	if passives.has(id): return passives[id].effect
	if id == "apple": return "Восстанавливает 4 HP"
	if id == "emerald": return "+25 очков к результату"
	if level == 0:
		return {"sword":"Бьёт перед собой", "bow":"Стреляет в ближайшего врага", "trident":"Пробивает врагов и возвращается", "fire":"Взрывается при попадании", "potion":"Оставляет ядовитое облако", "fangs":"Четыре пары клыков из земли"}[id]
	var a = stats(id, level)
	var b = stats(id, level + 1)
	for k in ["damage", "radius", "interval", "count", "pierce", "range", "speed", "duration", "back", "rows"]:
		if a.get(k, 0) == b.get(k, 0): continue
		if k == "back": return "Второй взмах назад"
		if k == "rows": return "Второй ряд под углом 25°"
		var label = {"damage":"Урон", "radius":"Радиус", "interval":"Интервал", "count":"Клыки" if id == "fangs" else "Снаряды", "pierce":"Пробитие", "range":"Дальность", "speed":"Скорость", "duration":"Облако"}[k]
		return "%s %s → %s%s" % [label, number(a.get(k, 0)), number(b.get(k, 0)), " с" if k in ["interval", "duration"] else ""]
	return ""

func number(n) -> String:
	return str(int(n)) if is_equal_approx(float(n), float(int(n))) else ("%.2f" % n).trim_suffix("0")

func wave(t: float) -> Dictionary:
	var w = data.waves[0]
	for v in data.waves:
		if t >= v.at: w = v
	return w
