extends RefCounted
## Title menu, chapter choice, settings and multiplayer lobby.

static func draw_menu(g):
	g.dim(.65)
	g.centered("Minecraft Survivors",106,32,g.INK,true)
	g.button(Rect2(199,151,242,29),"Играть","chapters")
	g.button(Rect2(199,191,242,29),"Мультиплеер","multiplayer")
	g.button(Rect2(199,231,242,29),"Настройки","settings")
	g.button(Rect2(199,271,242,29),"Выход","quit")

static func draw_chapters(g):
	g.dim(.9)
	g.centered("Выбор главы",76,24,g.INK,true)
	g.button(Rect2(478,12,140,22),"Достижения","achievements")
	g.button(Rect2(172,113,296,35),"Глава I · Верхний мир","chapter_1")
	g.button(Rect2(172,164,296,35),"Глава II · Незер","chapter_2")
	g.button(Rect2(172,215,296,35),"Глава III · Край","chapter_3")
	g.button(Rect2(219,282,202,27),"Назад","back")

static func draw_settings(g):
	g.dim(0.88)
	g.panel(Rect2(125,27,390,306),Color("20372c"),Color("6c7e58"))
	g.centered("НАСТРОЙКИ",61,20,g.INK,true)
	var keys=["music","effects","fullscreen","shake","flashes","numbers"]
	var labels=["Громкость музыки","Громкость эффектов","Полный экран · F11","Тряска камеры","Вспышки при попадании","Числа урона"]
	for i in range(keys.size()):
		var key=keys[i]
		var y=82+i*32
		g.text_at(labels[i],Vector2(146,y+15),10,g.INK)
		if i<2:
			g.button(Rect2(358,y,24,24),"−","volume_"+key+"_down")
			g.text_at("%d%%" % roundi(g.settings[key]*100),Vector2(392,y+15),8,g.INK)
			g.button(Rect2(468,y,24,24),"+","volume_"+key+"_up")
		else:g.button(Rect2(408,y,84,24),"Вкл" if g.settings[key] else "Выкл",key)
	g.button(Rect2(147,287,161,27),"Папка логов","logs")
	g.button(Rect2(327,287,166,27),"Назад","back")

static func draw_multiplayer(g):
	g.dim(.88)
	g.centered("Мультиплеер",65,16,g.INK,true)
	if not g.coop.active:
		g.text_at("Ник",Vector2(199,99),8,g.MUTED)
		g.text_at("IP ZeroTier",Vector2(199,153),8,g.MUTED)
		g.button(Rect2(199,207,116,27),"Создать","network_host")
		g.button(Rect2(325,207,116,27),"Подключиться","network_join")
	else:
		var index = 0
		for id in g.coop.roster:
			g.centered(g.coop.roster[id],112+index*24,8,g.INK)
			index += 1
		g.centered("%d / %d" % [g.coop.roster.size(),g.coop.MAX_PLAYERS],213,8,g.MUTED)
		if g.coop.hosting and g.coop.roster.size() >= 2:
			g.button(Rect2(199,227,242,27),"Начать","network_start")
	if not g.coop.status.is_empty(): g.centered(g.coop.status,262,8,g.MUTED)
	g.button(Rect2(199,289,242,27),"Назад","network_back")

static func draw_network_wait(g):
	g.dim(.6)
	var label = "Загрузка…" if g.coop.loading else "Пауза: "+g.world.blocked_by()
	g.centered(label,153,8,g.INK)
	g.button(Rect2(219,190,202,27),"В меню","menu")

static func create_network_fields(g):
	for index in range(2):
		var field = LineEdit.new()
		field.position = Vector2(199,106+index*54)
		field.size = Vector2(242,25)
		field.add_theme_font_override("font",g.font)
		field.add_theme_font_size_override("font_size",8)
		field.add_theme_color_override("font_color",g.INK)
		field.add_theme_color_override("caret_color",g.INK)
		var style = StyleBoxFlat.new()
		style.bg_color = Color.BLACK
		style.border_color = Color("777777")
		style.set_border_width_all(1)
		style.content_margin_left = 6
		style.content_margin_right = 6
		field.add_theme_stylebox_override("normal",style)
		var focus_style = style.duplicate()
		focus_style.border_color = Color.WHITE
		field.add_theme_stylebox_override("focus",focus_style)
		field.max_length = 16 if index == 0 else 64
		field.context_menu_enabled = false
		field.visible = false
		g.add_child(field)
		if index == 0:
			g.nickname_field = field
			field.text = g.network_nick
			field.text_submitted.connect(func(_value): g.address_field.grab_focus())
		else:
			g.address_field = field
			field.text = g.network_address
			field.text_submitted.connect(func(_value): g.action("network_join"))

static func sync_network_fields(g):
	if not is_instance_valid(g.nickname_field): return
	var show_fields = g.screen == "multiplayer" and not g.coop.active
	g.nickname_field.visible = show_fields
	g.address_field.visible = show_fields
