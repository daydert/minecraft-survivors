extends RefCounted
## Overlays shown during a run: rewards, pause, chest, result and boss lab.
const BossLab = preload("res://scripts/boss_lab.gd")
const W = preload("res://scripts/campaign_world.gd")

static func draw_level_up(g):
	if g.is_end() and not g.world.chosen_item.is_empty():
		g.dim(.83)
		g.panel(Rect2(176,107,288,143))
		g.item_icon(g.world.chosen_item,Vector2(296,122),3,false,g.world.chosen_level)
		g.wrapped(g.gear_title(g.world.chosen_item,false,g.world.chosen_level),Vector2(194,193),252,12,g.INK,true)
		if g.world.db.weapons.has(g.world.chosen_item) or g.world.db.passives.has(g.world.chosen_item):g.text_at("Уровень %d" % g.world.chosen_level,Vector2(194,229),8,g.MUTED)
		return
	if (g.is_end() and g.world.choices.size()>3) or (g.is_four() and (g.world.choices.size()>3 or g.world.rerolls>0)):
		draw_end_choices(g);return
	g.dim(0.77)
	g.centered("НОВЫЙ УРОВЕНЬ",67,23,g.LIME,true)
	g.centered("Уровень %d" % g.world.level,89,8,g.MUTED)
	for i in range(g.world.choices.size()):
		var id=g.world.choices[i]
		var owned=g.world.build.get(id,g.world.items.get(id,0))
		var r=Rect2(29+i*197,112,188,159)
		var active=g.selected==g.buttons.size()
		g.buttons.append({"rect":r,"id":"choice_"+str(i)})
		g.panel(r,Color("314831") if active else Color("20362b"),g.LIME if active else Color("697655"))
		g.draw_rect(Rect2(r.position+Vector2(12,12),Vector2(43,43)),Color("151515"))
		g.item_icon(id,r.position+Vector2(17,17),2,false,owned+1)
		g.text_at("%d" % (i+1),r.position+Vector2(164,24),12,g.LIME,true)
		g.text_at("НОВОЕ" if owned==0 else "УЛУЧШЕНИЕ",r.position+Vector2(66,26),8,g.GOLD if owned==0 else g.MUTED,true)
		g.text_at("Уровень %d" % (owned+1),r.position+Vector2(66,42),9,g.INK)
		g.wrapped(g.gear_title(id,false,owned+1),r.position+Vector2(12,77),165,11,g.INK,true)
		g.wrapped(g.world.db.description(id,owned),r.position+Vector2(12,112),164,9,g.LIME)
		if active:g.draw_rect(Rect2(r.position+Vector2(1,154),Vector2(186,4)),g.LIME)
	g.button(Rect2(255,321,130,22),"В меню","menu")
	if not g.coop.active and g.world is W:g.button(Rect2(24,321,150,22),"Пропустить","skip_reward")

static func draw_end_choices(g):
	g.dim(.82)
	g.centered("НОВЫЙ УРОВЕНЬ",54,24,g.INK,true)
	g.centered("Уровень %d" % g.world.level,76,8,g.MUTED)
	var count=g.world.choices.size()
	var width=112 if count==5 else 141
	var gap=8
	var start=(640-count*width-(count-1)*gap)/2
	for i in range(count):
		var id=g.world.choices[i];var owned=g.world.build.get(id,g.world.items.get(id,0))
		var r=Rect2(start+i*(width+gap),98,width,192)
		var active=g.selected==g.buttons.size();g.buttons.append({"rect":r,"id":"choice_"+str(i)})
		g.panel(r);g.item_icon(id,r.position+Vector2(12,14),2,false,owned+1)
		g.text_at(str(i+1),r.position+Vector2(width-18,25),8,g.INK,true)
		g.text_at("I" if owned==0 else str(owned+1),r.position+Vector2(53,35),8,g.MUTED)
		g.wrapped(g.gear_title(id,false,owned+1),r.position+Vector2(8,69),width-16,8,g.INK,true)
		g.wrapped(g.world.db.description(id,owned),r.position+Vector2(8,107),width-16,8,g.MUTED)
		if active:g.draw_rect(Rect2(r.position+Vector2(1,188),Vector2(width-2,3)),g.INK)
	if g.world.rerolls>0:g.button(Rect2(207,304,226,23),"Перебросить · "+str(g.world.rerolls),"end_reroll")
	g.button(Rect2(255,333,130,22),"В меню","menu")
	g.button(Rect2(20,333,150,22),"Пропустить","skip_reward")

static func draw_pause(g):
	if g.coop.active:
		g.dim(.78);g.panel(Rect2(173,60,294,231));g.centered("Пауза",96,24,g.INK,true)
		g.button(Rect2(207,120,226,27),"Продолжить","resume")
		g.button(Rect2(207,157,226,27),"Характеристики","stats")
		g.button(Rect2(207,194,226,27),"Настройки","settings")
		g.button(Rect2(207,231,226,27),"В меню","menu");return
	g.dim(.78)
	g.panel(Rect2(173,39,294,275))
	g.centered("Пауза",76,24,g.INK,true)
	g.button(Rect2(207,94,226,27),"Продолжить","resume")
	g.button(Rect2(207,133,226,27),"Характеристики","stats")
	if not g.coop.active:g.button(Rect2(207,172,226,27),"Достижения","achievements")
	g.button(Rect2(207,211,226,27),"Настройки","settings")
	g.button(Rect2(207,250,226,27),"В меню","menu")

static func draw_chest(g):
	var evolution=g.world.chest_reward.get("evolution",false)
	if evolution and not g.coop.active:
		if g.is_four():g.four_renderer.ArsenalView.evolution(g)
		else:preload("res://scripts/ui/evolution_view.gd").draw(g)
		return
	g.dim(0.78)
	g.panel(Rect2(105,47,430,266),Color("203329"),g.GOLD)
	g.centered("ЭВОЛЮЦИЯ" if evolution else "СУНДУК ОТКРЫТ",82,21,g.GOLD,true)
	var id=g.world.chest_reward.get("id","apple")
	if g.world.chest_delay>0:
		g.draw_clip("chest_open",Vector2(296,99),Vector2(48,48),0.65-g.world.chest_delay,Color.WHITE,false)
	else:
		g.item_icon(id,Vector2(296,105),3,evolution)
	g.centered(g.gear_title(id,evolution),181,15,g.INK,true)
	g.centered(g.world.chest_reward.get("text",""),208,10,g.LIME)
	g.button(Rect2(214,248,212,31),"Открыть" if g.world.chest_delay>0 else "Продолжить","chest")
	g.button(Rect2(263,287,114,18),"В меню","menu")

static func draw_result(g):
	g.dim(0.68)
	g.panel(Rect2(93,38,454,287),Color("21372d"),g.LIME if g.world.victory else Color("a17d5c"))
	g.centered("Победа" if g.world.victory else "Вы погибли",80,24,g.INK,true)
	var values=[g.format_time(g.world.time),str(g.world.kills),str(g.world.level),str(g.world.score)]
	var labels=["ВРЕМЯ","УБИЙСТВА","УРОВЕНЬ","ГЛАВА"] if not g.coop.active else ["ВРЕМЯ","УБИЙСТВА","УРОВЕНЬ","ОЧКИ"]
	if not g.coop.active:values[3]=str(g.solo_chapter)
	for i in range(4):
		var x=128+i*102
		g.text_at(values[i],Vector2(x,143),19,g.INK,true)
		g.text_at(labels[i],Vector2(x,161),8,g.MUTED)
	var dealt: Dictionary=g.world.get("damage_by") if "damage_by" in g.world else {}
	var ranked: Array=dealt.keys().filter(func(id):return (g.world.db.weapons.has(id) or (g.is_four() and g.world.db.passives.has(id))) and dealt[id]>=1)
	ranked.sort_custom(func(a,b):return dealt[a]>dealt[b])
	if ranked.is_empty():
		var ids=g.world.build.keys()+g.world.items.keys()
		var x0=320-ids.size()*13
		for i in range(ids.size()):
			var id=ids[i]
			g.item_icon(id,Vector2(x0+i*26,190),1.3,g.world.evolved.has(id))
	else:
		# Damage per weapon: the run's story in six bars.
		var top: float=dealt[ranked[0]]
		for i in range(mini(6,ranked.size())):
			var id=ranked[i]
			var p=Vector2(116+(i%2)*218,172+(i/2)*20)
			g.item_icon(id,p,1,g.world.evolved.has(id))
			var share: float=dealt[id]/top
			g.draw_rect(Rect2(p+Vector2(21,7),Vector2(120,4)),Color("333333"))
			g.draw_rect(Rect2(p+Vector2(21,7),Vector2(roundf(120*share),4)),g.LIME if i==0 else Color("9a9a9a"))
			var label=g.world.db.number(roundf(dealt[id])) if dealt[id]<10000 else "%dk" % int(dealt[id]/1000)
			g.text_at(label,p+Vector2(147,13),8,g.INK)
	if not g.coop.active or g.coop.hosting: g.button(Rect2(131,239,178,33),"Ещё раз","retry")
	g.button(Rect2(330,239,178,33),"В меню","menu")

static func draw_boss_lab(g):
	g.draw_rect(Rect2(0,0,640,360),Color.BLACK)
	g.text_at("Испытание босса",Vector2(22,29),16,g.INK,true)
	g.button(Rect2(510,13,108,22),"Назад","lab_back")
	g.button(Rect2(24,53,192,26),"I · Херобрин","lab_chapter_1")
	g.button(Rect2(224,53,192,26),"II · Иссушитель","lab_chapter_2")
	g.button(Rect2(424,53,192,26),"III · Край","lab_chapter_3")
	g.draw_line(Vector2(24+(g.lab_chapter-1)*200,82),Vector2(216+(g.lab_chapter-1)*200,82),g.INK,2)
	var presets=BossLab.presets(g.lab_chapter)
	for i in range(presets.size()):
		var p=Vector2(24+i%2*304,105+i/2*110)
		g.panel(Rect2(p,Vector2(288,96)))
		for j in range(presets[i].weapons.size()):g.item_icon(presets[i].weapons[j],p+Vector2(12+j*28,12),1,false,8)
		g.button(Rect2(p+Vector2(8,56),Vector2(272,30)),presets[i].name,"lab_build_"+str(i))
