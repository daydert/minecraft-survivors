extends RefCounted
## DAVIS lab screen: chapters, ready sets, a custom loadout and cheats.
const BossLab = preload("res://scripts/boss_lab.gd")
const TILE := Vector2(30, 32)
const COLUMNS := 13
const FRAME := Color("777777")
const OWNED := Color("2c2c2c")
const EMPTY := Color("161616")

static func draw(g):
	var lab = g.lab
	var chapter: int = g.lab_chapter
	g.draw_rect(Rect2(0, 0, 640, 360), Color.BLACK)
	g.text_at("Лаборатория Дэвиса", Vector2(22, 27), 16, g.INK, true)
	g.button(Rect2(530, 11, 88, 20), "Назад", "lab_back")
	for i in range(5):
		g.button(Rect2(22 + i * 119, 37, 114, 22), BossLab.CHAPTER_TITLES[i], "lab_chapter_" + str(i + 1))
	g.draw_line(Vector2(22 + (chapter - 1) * 119, 62), Vector2(136 + (chapter - 1) * 119, 62), g.INK, 2)
	var tabs := [["sets", "Наборы"], ["custom", "Свой набор"], ["cheats", "Читы"]]
	for i in range(tabs.size()):
		g.button(Rect2(22 + i * 125, 68, 120, 20), tabs[i][1], "lab_tab_" + tabs[i][0])
		if lab.tab == tabs[i][0]:g.draw_line(Vector2(22 + i * 125, 91), Vector2(142 + i * 125, 91), g.INK, 2)
	if lab.tab == "cheats":
		g.button(Rect2(497, 68, 121, 20), "Сбросить читы", "lab_cheats_reset")
	else:
		g.text_at("Уровень героя %d" % lab.hero_level, Vector2(400, 82), 8, g.MUTED)
	match lab.tab:
		"sets":draw_sets(g, chapter)
		"custom":draw_custom(g, chapter)
		"cheats":draw_cheats(g, chapter)
	draw_targets(g, chapter)

static func icon(g, db, id: String, p: Vector2, scale_factor: float, evolution: bool, level: int, tint: Color = Color.WHITE):
	var name: String = db.equipment_icon(id, maxi(1, level), evolution) if db.has_method("equipment_icon") else db.icon(id, evolution)
	if evolution and g.minecraft_assets.clips.has(name + "_enchanted") and g.textures.has(name + "_enchanted"):
		g.draw_clip(name + "_enchanted", p, Vector2.ONE * 16 * scale_factor, g.ui_time, tint)
		return
	if not g.textures.has("icon_" + name):g.load_texture("icon_" + name)
	g.sprite("icon_" + name, p, Vector2.ONE * 16 * scale_factor, tint)

# ------------------------------------------------------------------ ready sets

static func draw_sets(g, chapter: int):
	var lab = g.lab
	var db = lab.pool_world(chapter).db
	var presets: Array = BossLab.presets(chapter)
	for i in range(presets.size()):
		var p := Vector2(22 + i % 2 * 306, 98 + i / 2 * 112)
		g.panel(Rect2(p, Vector2(290, 104)))
		g.text_at(presets[i].name, p + Vector2(10, 16), 9, g.INK, true)
		var loadout: Dictionary = lab.preset_loadout(lab.pool_world(chapter), i)
		var j := 0
		for id in loadout.weapons:
			icon(g, db, id, p + Vector2(10 + j * 22, 22), 1, loadout.evolved.has(id), BossLab.WEAPON_MAX);j += 1
		j = 0
		for id in loadout.items:
			icon(g, db, id, p + Vector2(10 + j * 22, 44), 1, loadout.evolved.has(id), BossLab.PASSIVE_MAX);j += 1
		g.button(Rect2(p + Vector2(8, 70), Vector2(134, 26)), "В бой", "lab_build_" + str(i))
		g.button(Rect2(p + Vector2(148, 70), Vector2(134, 26)), "Изменить", "lab_preset_edit_" + str(i))

# ------------------------------------------------------------------ custom loadout

static func draw_custom(g, chapter: int):
	var lab = g.lab
	var db = lab.pool_world(chapter).db
	var pool: Dictionary = lab.pool(chapter)
	var loadout: Dictionary = lab.loadout(chapter)
	g.panel(Rect2(22, 96, 400, 222))
	var y := 110.0
	for group in ["weapons", "items"]:
		var ids: Array = pool[group]
		var owned: Dictionary = loadout[group]
		var limit: String = "∞" if lab.cheats.overcap else ("6" if group == "weapons" else "8")
		g.text_at(("Оружие" if group == "weapons" else "Предметы") + " %d/%s" % [owned.size(), limit], Vector2(32, y), 8, g.INK, true)
		for k in range(ids.size()):
			var id: String = ids[k]
			var r := Rect2(Vector2(28 + k % COLUMNS * TILE.x, y + 5 + k / COLUMNS * TILE.y), TILE - Vector2(2, 2))
			var level: int = int(owned.get(id, 0))
			g.buttons.append({"rect":r, "id":"lab_item_" + id})
			var hot: bool = g.selected == g.buttons.size() - 1 or lab.focus == id
			g.draw_rect(r, OWNED if level > 0 else EMPTY)
			g.draw_rect(r, g.INK if hot else (Color("aaaaaa") if level > 0 else Color("3a3a3a")), false, 1)
			icon(g, db, id, r.position + Vector2(6, 3), 1, loadout.evolved.has(id), level, Color.WHITE if level > 0 else Color(1, 1, 1, .35))
			if level > 0:
				g.text_at(str(level), r.position + Vector2(20, 28), 7, g.INK, true)
				if loadout.evolved.has(id):
					g.draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(5, 5)), g.INK)
					g.draw_rect(Rect2(r.position + Vector2(3, 3), Vector2(3, 3)), Color("8a4dff"))
		y += 5 + ceili(ids.size() / float(COLUMNS)) * TILE.y + 14
	g.text_at("ЛКМ — добавить · ПКМ — убрать", Vector2(32, 310), 7, g.MUTED)
	g.panel(Rect2(428, 96, 190, 222))
	var focus: String = lab.focus
	if focus.is_empty() or not (pool.weapons.has(focus) or pool.items.has(focus)):
		g.wrapped("Выбери вещь слева, чтобы настроить её уровень и эволюцию", Vector2(438, 112), 170, 8, g.MUTED)
	else:
		var level: int = lab.level_of(chapter, focus)
		var evo: bool = loadout.evolved.has(focus)
		g.draw_rect(Rect2(436, 104, 36, 36), EMPTY)
		icon(g, db, focus, Vector2(438, 106), 2, evo, maxi(level, 1))
		var title: String = db.equipment_title(focus, maxi(level, 1), evo) if db.has_method("equipment_title") else db.title(focus, evo)
		g.wrapped(title, Vector2(478, 114), 134, 8, g.INK, true)
		g.text_at("Уровень %d/%d" % [level, lab.max_level(chapter, focus)], Vector2(438, 158), 8, g.INK)
		g.button(Rect2(554, 146, 28, 18), "−", "lab_level_down")
		g.button(Rect2(586, 146, 28, 18), "+", "lab_level_up")
		if lab.can_evolve(chapter, focus):
			g.button(Rect2(436, 170, 178, 18), "Эволюция: " + ("вкл" if evo else "выкл"), "lab_evo")
		else:
			g.text_at("Без эволюции", Vector2(438, 183), 8, g.MUTED)
		g.button(Rect2(436, 192, 178, 18), "Убрать" if level > 0 else "Добавить", "lab_remove" if level > 0 else "lab_add")
		g.wrapped(db.description(focus, maxi(0, level - 1)), Vector2(438, 222), 172, 7, g.MUTED)
	g.draw_line(Vector2(434, 252), Vector2(612, 252), Color("3a3a3a"))
	g.text_at("Герой: ур. %d" % lab.hero_level, Vector2(438, 268), 8, g.INK)
	g.button(Rect2(520, 256, 22, 18), "«", "lab_hero_down10")
	g.button(Rect2(544, 256, 22, 18), "−", "lab_hero_down")
	g.button(Rect2(568, 256, 22, 18), "+", "lab_hero_up")
	g.button(Rect2(592, 256, 22, 18), "»", "lab_hero_up10")
	g.button(Rect2(436, 282, 58, 28), "Всё макс", "lab_all_max")
	g.button(Rect2(496, 282, 58, 28), "Очистить", "lab_clear")
	g.button(Rect2(556, 282, 58, 28), "Случайно", "lab_random")

# ------------------------------------------------------------------ cheats

static func draw_cheats(g, chapter: int):
	var lab = g.lab
	g.panel(Rect2(22, 96, 400, 222))
	for i in range(BossLab.CHEATS.size()):
		var c: Dictionary = BossLab.CHEATS[i]
		var p := Vector2(30 + i / 5 * 196, 102 + i % 5 * 43)
		var on: bool = lab.cheat_on(c.id)
		g.text_at(c.name, p + Vector2(0, 12), 8, g.INK if on else Color("cccccc"), true)
		g.text_at(c.hint, p + Vector2(0, 24), 6, g.MUTED)
		g.button(Rect2(p + Vector2(132, 1), Vector2(52, 20)), lab.cheat_label(c.id), "lab_cheat_" + c.id)
		if on:g.draw_rect(Rect2(p + Vector2(132, 23), Vector2(52, 2)), g.INK)
	g.panel(Rect2(428, 96, 190, 222))
	g.text_at("Прямо сейчас", Vector2(438, 112), 9, g.INK, true)
	var running: bool = g.lab_run_chapter() == chapter
	if not running:
		g.wrapped("Работает во время забега главы " + ["I", "II", "III", "IV", "V"][chapter - 1] + " · открой DAVIS прямо в игре", Vector2(438, 130), 170, 7, g.MUTED)
		return
	var row := 0
	for a in BossLab.NOW:
		if a.id == "target" and lab.selected_target(chapter) == "chapter":continue
		var label: String = a.name + (" · " + lab.target_name(chapter) if a.id == "target" else "")
		g.button(Rect2(436, 122 + row * 27, 178, 22), label, "lab_now_" + a.id);row += 1

# ------------------------------------------------------------------ start

static func draw_targets(g, chapter: int):
	var lab = g.lab
	var list: Array = BossLab.targets(chapter)
	g.text_at("Цель", Vector2(22, 341), 8, g.MUTED, true)
	var width: float = (432.0 - (list.size() - 1) * 4) / list.size()
	var chosen: String = lab.selected_target(chapter)
	for i in range(list.size()):
		var r := Rect2(54 + i * (width + 4), 326, width, 24)
		g.button(r, list[i].name, "lab_target_" + str(i))
		if list[i].id == chosen:g.draw_line(Vector2(r.position.x, 352), Vector2(r.end.x, 352), g.INK, 2)
	g.button(Rect2(496, 326, 122, 24), "Начать · свой набор", "lab_start")
