extends RefCounted
## Full-screen equipment views: inventory, recipe book and character stats.
const WorldView = preload("res://scripts/ui/world_view.gd")

static func draw_inventory(g):
	g.draw_rect(Rect2(0,0,640,360),Color.BLACK)
	g.text_at("Инвентарь",Vector2(22,29),16,g.INK,true)
	g.button(Rect2(510,13,108,22),"Готово","close_inventory")
	g.draw_line(Vector2(22,59),Vector2(618,59),Color("555555"))
	for row in range(2):
		var collection=g.world.build if row==0 else g.world.items
		var slots=6 if row==0 else 8
		var step_x=99 if row==0 else 74
		var y=85 if row==0 else 212
		g.text_at(("Оружие · %d / 6" if row==0 else "Усиления · %d / 8") % collection.size(),Vector2(24,y-9),8,g.INK,true)
		var ids=collection.keys()
		for i in range(slots):
			var x=24+i*step_x
			g.panel(Rect2(x,y,step_x-5,103))
			if i>=ids.size():
				g.text_at("—",Vector2(x+step_x/2-4,y+45),8,g.MUTED)
				continue
			var id=ids[i]
			g.item_icon(id,Vector2(x+7,y+7),1,g.world.evolved.has(id))
			g.text_at(str(collection[id])+" / "+("8" if row==0 else "5"),Vector2(x+29,y+19),8,g.MUTED)
			g.wrapped(g.gear_title(id,g.world.evolved.has(id)),Vector2(x+6,y+38),step_x-14,8,g.INK)
			g.button(Rect2(x+5,y+77,step_x-15,20),"Удалить","discard_"+id)
	g.button(Rect2(24,330,100,22),"Рецепты","recipes")

static func draw_recipe_book(g):
	if g.is_four():preload("res://scripts/chapter_four_gear_view.gd").recipes(g);return
	g.draw_rect(Rect2(0,0,640,360),Color.BLACK)
	g.text_at("Эволюции",Vector2(22,29),16,g.INK,true)
	g.text_at("Оружие VIII · сундук после 6:00",Vector2(22,47),8,g.MUTED)
	g.button(Rect2(510,13,108,22),"Назад","recipes_back")
	var index=0
	var ids=g.world.db.recipes.keys()
	g.recipe_page=clampi(g.recipe_page,0,maxi(0,(ids.size()-1)/9))
	for id in ids.slice(g.recipe_page*9,g.recipe_page*9+9):
		var recipe=g.world.db.recipes[id]
		var p=Vector2(22+(index%3)*202,65+(index/3)*(89 if ids.size()>9 else 94))
		g.panel(Rect2(p,Vector2(192,84 if ids.size()>9 else 88)))
		g.item_icon(id,p+Vector2(8,8))
		g.text_at("+",p+Vector2(31,20),8,g.MUTED)
		g.item_icon(recipe.passive,p+Vector2(44,8))
		g.text_at("=",p+Vector2(67,20),8,g.MUTED)
		g.item_icon(id,p+Vector2(80,8),1,true)
		g.wrapped(recipe.name,p+Vector2(8,37),175,8,g.INK,true)
		g.wrapped(recipe.effect,p+Vector2(8,65),175,8,g.MUTED)
		index+=1

	if ids.size()>9:
		if g.recipe_page>0:g.button(Rect2(232,338,70,18),"Назад","recipes_prev")
		if (g.recipe_page+1)*9<ids.size():g.button(Rect2(338,338,70,18),"Далее","recipes_next")

static func draw_stats(g):
	g.draw_rect(Rect2(0,0,640,360),Color.BLACK)
	g.text_at("Характеристики",Vector2(22,31),16,g.INK,true)
	g.button(Rect2(510,13,108,22),"Готово","close_stats")
	g.draw_line(Vector2(22,59),Vector2(618,59),Color("555555"))
	if g.is_four():preload("res://scripts/chapter_four_arsenal_view.gd").body(g,Vector2(48,112),g.world.facing,g.world.build.keys()[0] if not g.world.build.is_empty() else "idle","idle",0,Color.WHITE)
	else:WorldView.draw_actor(g,"steve",Vector2(48,112),g.world.facing,g.world.clock,false,Color.WHITE,"idle",1.5,{"state":"idle","time":0.0})
	g.text_at("Уровень %d" % g.world.level,Vector2(83,83),8,g.INK,true)
	g.text_at("Убийств: %d" % g.world.kills,Vector2(83,97),8,g.MUTED)
	if g.coop.active:g.text_at("Изумрудных очков: %d" % g.world.score,Vector2(83,111),8,g.MUTED)
	var stats = character_stats(g)
	var index = 0
	for label in stats:
		var y = 125+index*(12 if g.is_nether() or g.is_four() else 15)
		g.text_at(label,Vector2(24,y),8,g.MUTED)
		g.text_at(stats[label],Vector2(134,y),8,g.INK)
		index += 1
	g.draw_line(Vector2(282,74),Vector2(282,255),Color("333333"))
	g.text_at("Оружие",Vector2(300,83),8,g.INK,true)
	index = 0
	for id in g.world.build:
		var y = 100+index*26
		var evolved: bool = g.world.evolved.has(id)
		var s = g.world.db.stats(id,g.world.build[id],evolved,g.world.items)
		g.item_icon(id,Vector2(300,y),1,evolved)
		g.text_at(g.gear_title(id,evolved)+"  "+str(g.world.build[id]),Vector2(324,y+7),8,g.INK)
		g.text_at("Урон %s | %s с | радиус %s" % [g.world.db.number(s.damage),g.world.db.number(s.interval),g.world.db.number(s.radius)],Vector2(324,y+20),8,g.MUTED)
		index += 1
	g.draw_line(Vector2(22,272),Vector2(618,272),Color("555555"))
	g.text_at("Предметы",Vector2(24,287),8,g.INK,true)
	if g.world.items.is_empty():g.text_at("Пока нет предметов",Vector2(24,309),8,g.MUTED)
	index = 0
	for id in g.world.items:
		var x = 24+index*(100 if g.coop.active else 75)
		g.item_icon(id,Vector2(x,296))
		g.text_at(str(g.world.items[id])+" / 5",Vector2(x+22,308),8,g.INK)
		g.wrapped(g.gear_title(id,g.is_four() and g.world.evolved.has(id)),Vector2(x,325),92 if g.coop.active else 69,8,g.MUTED)
		index += 1

static func character_stats(g) -> Dictionary:
	var result = {
		"Здоровье":"%s / %d" % [g.world.db.number(maxf(0,g.world.hp)),g.world.db.data.player_hp],
		"Скорость":"%s пикс/с" % g.world.db.number(g.world.movement_speed() if g.world.has_method("movement_speed") else g.world.db.data.player_speed*(1+0.08*g.world.items.get("sugar",0))),
		"Бонус урона":"+%d%%" % (g.world.items.get("blaze",0)*10),
		"Интервал атак":"-%d%%" % (g.world.items.get("redstone",0)*6),
		"Размер атак":"+%d%%" % (g.world.items.get("amethyst",0)*10),
		"Защита":"-%s HP за удар" % g.world.db.number(0.2*g.world.items.get("armor",0)),
		"Сбор опыта":"%s пикс" % g.world.db.number(24*(1+0.3*g.world.items.get("hopper",0))),
		"Опыт":"%d / %d (ур. %d)" % [g.world.xp,g.world.db.required_xp(g.world.level),g.world.level]
	}

	if g.is_nether():
		result["Огонь / иссушение"]="−%d%%" % (g.world.items.get("fire_resist",0)*16)
		result["Регенерация"]="%s HP / 5 с" % g.world.db.number(.3*g.world.items.get("ghast_tear",0))
		result["Притяжение"]="+%d%%" % (g.world.items.get("feather",0)*12)
		result["Песок душ"]="−%d%% штрафа" % (g.world.items.get("gold_boots",0)*20)
	if g.is_four():
		result["Вампиризм"]="≤%s HP / с"%g.world.db.number(.12*g.world.items.get("bat_wings",0))
		result["Свеча"]="+%d%% урона"%roundi((g.world.db.data.four_buffs.damage-1)*100)
		result["Множитель атак"]="×%s"%g.world.db.number(g.world.db.data.four_buffs.speed)
		result["Защита в покое"]="−%d%%"%(g.world.items.get("bedrock",0)*4 if g.world.arsenal.still>=.7 else 0)
	return result
