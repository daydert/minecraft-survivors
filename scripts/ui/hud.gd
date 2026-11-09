extends RefCounted
## In-run HUD: hearts, timer, experience, equipment bars and boss bars.
const Atmosphere = preload("res://scripts/ui/atmosphere.gd")

static func draw_hud(g):
	Atmosphere.health_edges(g)
	# Vanilla-sized health and experience sit above the two equipment bars.
	var origin = Vector2(192 if g.coop.active else 172,332)
	for i in range(10):
		var p=origin+Vector2(i*8,-22)
		g.sprite("heart_empty",p)
		var health=clampf(ceilf(g.world.hp)-i*2,0,2)
		var blink = g.settings.flashes and g.world.invulnerable>0 and fmod(g.world.clock,0.2)<0.1
		var withered=g.is_nether() and g.world.player_wither>0
		if health==2:g.sprite(("heart_wither_blink" if blink else "heart_wither") if withered else ("heart_blink" if blink else "heart"),p)
		elif health==1:g.sprite(("heart_wither_half_blink" if blink else "heart_wither_half") if withered else ("heart_half_blink" if blink else "heart_half"),p)
	g.centered(g.format_time(g.world.time),24,16,g.INK,true)
	g.text_at("Убийств: %d" % g.world.kills,Vector2(12,16),8,g.INK)
	if g.coop.active:g.text_at("Изумруды: %d" % g.world.score,Vector2(12,29),8,g.MUTED)
	else:g.text_at("Глава IV · «Обычный мир»" if g.is_four() else "Глава III · Край" if g.is_end() else "Глава II · Незер" if g.is_nether() else "Глава I · Верхний мир",Vector2(12,29),8,g.MUTED)
	if g.is_four() and g.world.aura_state != "none":
		g.text_at("Ярость" if g.world.aura_state == "rage" else "Опустошённость",Vector2(12,46),8,Color("e6a496") if g.world.note_read else g.MUTED)
	if g.coop.active and g.coop.running:
		var row = 0
		for a in g.world.players.values():
			if a.id == g.world.local_id: continue
			g.text_at(a.nick+"  "+("%d / 20" % maxi(0,ceili(a.hp)) if a.alive else "Погиб"),Vector2(12,43+row*12),8,g.MUTED)
			row += 1
		if not g.world.players[g.world.local_id].alive and not g.world.finale.active:
			g.centered("Наблюдение: "+g.world.players[g.network_view_id()].nick,291,8,g.MUTED)
	if g.world.state in ["RUNNING","FINALE","SPECTATING"]:
		g.buttons.append({"rect":Rect2(572,8,58,20),"id":"pause"})
		g.text_at("Пауза",Vector2(586,20),8,g.INK)
		g.buttons.append({"rect":Rect2(370,305,80,18),"id":"stats"})
	g.text_at("Статы",Vector2(406,317),8,g.MUTED)
	if not g.coop.active:
		g.text_at("Инвентарь",Vector2(464,317),8,g.MUTED)
		g.buttons.append({"rect":Rect2(462,305,90,18),"id":"inventory"})
	var ratio=clampf(float(g.world.xp)/g.world.db.required_xp(g.world.level),0,1)
	var xp_width=256 if g.coop.active else 296
	g.sprite("hud_xp_empty",origin+Vector2(0,-9),Vector2(xp_width,5))
	if ratio>0:
		g.draw_texture_rect_region(g.textures.hud_xp_full,Rect2(origin+Vector2(0,-9),Vector2(floorf(xp_width*ratio),5)),Rect2(0,0,floorf(182*ratio),5))
	g.centered(str(g.world.level),318,8,Color("80ff20"))
	for row in range(2):
		var collection=g.world.build if row==0 else g.world.items
		var ids=collection.keys()
		var x0=(192 if row==0 else 326) if g.coop.active else (172 if row==0 else 306)
		g.sprite("hud_eight_slots" if row==1 and not g.coop.active else "hud_six_slots",Vector2(x0,332))
		for i in range(8 if row==1 and not g.coop.active else 6):
			var p=Vector2(x0+3+i*20,335)
			if i<ids.size():
				var id=ids[i]
				if row==0 and id==g.world.player_visual.get("weapon","sword"):
					g.sprite("hud_selection",Vector2(x0-1+i*20,331))
				g.item_icon(id,p,1,g.world.evolved.has(id))
				if row==0 and not g.coop.active:
					var interval: float=g.world.db.stats(id,collection[id],g.world.evolved.has(id),g.world.items).interval
					var left: float=clampf(g.world.cooldowns.get(id,0.0)/maxf(.01,interval),0,1)
					if left>0:
						var height=ceilf(16*left)
						g.draw_rect(Rect2(p+Vector2(0,16-height),Vector2(16,height)),Color(1,1,1,.43))
						g.draw_line(p+Vector2(0,16-height),p+Vector2(16,16-height),Color(1,1,1,.8),1)
				var level_text = str(collection[id])
				g.text_at(level_text,p+Vector2(17-g.font.get_string_size(level_text,HORIZONTAL_ALIGNMENT_LEFT,-1,8).x,17),8,g.INK)
	if g.is_end():g.end_renderer.hud(g)
	if g.is_nether():g.nether_renderer.hud(g)
	if g.world.message_timer>0 and g.world.state=="RUNNING" and (not g.is_nether() or g.world.stage!="wither"):
		g.centered(g.world.message,68,12,g.GOLD,true)
	if g.is_nether() and g.world.bastion.get("state","")=="assault" and g.world.stage=="survival":
		var left: float=g.world.bastion.timer/float(g.world.db.data.bastion.duration)
		g.draw_rect(Rect2(229,46,182,5),Color("333333"))
		g.draw_rect(Rect2(229,46,182*clampf(left,0,1),5),Color("d9a334"))
		g.centered("Штурм бастиона",41,8,g.INK)
	for m in g.world.mobs:
		if m.kind!="ravager" or m.hp<=0:continue
		g.draw_rect(Rect2(229,46,182,5),Color("333333"))
		g.draw_rect(Rect2(229,46,182*maxf(0,m.hp)/m.max_hp,5),Color("a92c2c"))
		g.centered("Разоритель",41,8,g.INK)
