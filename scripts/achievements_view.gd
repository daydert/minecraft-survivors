extends RefCounted
const TIERS=["all","easy","medium","hard","secret"]
const LABELS=["Все","Лёгкие","Средние","Сложные","Секретные"]

func screen(g):
	g.draw_rect(Rect2(0,0,640,360),Color("101010"))
	g.text_at("Достижения",Vector2(24,31),16,g.INK,true)
	g.text_at("%d / %d" % [g.achievements.unlocked.size(),g.achievements.catalog.size()],Vector2(268,29),8,g.MUTED)
	g.button(Rect2(510,13,108,22),"Назад","achievements_back")
	for i in range(TIERS.size()):
		var rect=Rect2(24+i*120,49,112,25)
		g.button(rect,LABELS[i],"achievement_tier_"+TIERS[i])
		if g.achievement_tier==TIERS[i]:g.draw_line(rect.position+Vector2(3,23),rect.end-Vector2(3,2),g.INK,1)
	var entries=g.achievements.catalog.filter(func(e):return g.achievement_tier=="all" or e.tier==g.achievement_tier)
	var pages=maxi(1,ceili(entries.size()/6.0))
	g.achievement_page=clampi(g.achievement_page,0,pages-1)
	for i in range(mini(6,entries.size()-g.achievement_page*6)):
		var entry=entries[g.achievement_page*6+i]
		var earned=g.achievements.unlocked.has(entry.id)
		var hidden=entry.get("secret",false) and not earned
		var p=Vector2(24+(i%3)*200,87+(i/3)*119)
		var rect=Rect2(p,Vector2(192,111))
		g.panel(rect)
		if earned:g.draw_rect(rect.grow(-3),Color("999999"),false,1)
		g.sprite("achievement_"+("unknown" if hidden else entry.icon),p+Vector2(9,9),Vector2(32,32),Color.WHITE if earned or hidden else Color(.46,.46,.46))
		g.wrapped("???" if hidden else entry.name,p+Vector2(50,22),130,8,g.INK if earned else g.MUTED,true)
		g.text_at("Получено" if earned else "Не получено",p+Vector2(50,38),8,g.MUTED)
		g.wrapped("Секретное достижение" if hidden else entry.description,p+Vector2(9,57),174,8,g.MUTED)
	if pages>1:
		if g.achievement_page>0:g.button(Rect2(24,329,108,22),"Назад","achievements_prev")
		if g.achievement_page<pages-1:g.button(Rect2(508,329,108,22),"Далее","achievements_next")
		g.centered("%d / %d" % [g.achievement_page+1,pages],344,8,g.MUTED)

func toast(g):
	if g.achievement_toast.is_empty():return
	var entry=g.achievements.entry(g.achievement_toast)
	if entry.is_empty():return
	var age=g.achievement_toast_age
	var slide=1-smoothstep(0,.22,age) if age<.22 else smoothstep(3.1,3.5,age)
	var p=Vector2(398,9-58*slide).floor()
	g.panel(Rect2(p,Vector2(234,48)))
	g.sprite("achievement_"+entry.icon,p+Vector2(7,8),Vector2(32,32))
	g.text_at("Достижение получено",p+Vector2(47,18),8,g.MUTED)
	g.text_at(entry.name,p+Vector2(47,34),8,g.INK,true)
