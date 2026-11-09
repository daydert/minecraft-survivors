extends RefCounted
const Equipment=preload("res://scripts/chapter_four_equipment.gd")

static func recipes(g):
	g.draw_rect(Rect2(0,0,640,360),Color.BLACK)
	g.text_at("Эволюции",Vector2(22,29),16,g.INK,true)
	g.text_at("Уровни под значками · сундук после 6:00",Vector2(22,47),8,g.MUTED)
	g.button(Rect2(510,13,108,22),"Назад","recipes_back")
	var ids: Array=g.world.db.recipes.keys()
	g.recipe_page=clampi(g.recipe_page,0,maxi(0,(ids.size()-1)/9))
	var index:=0
	for id in ids.slice(g.recipe_page*9,g.recipe_page*9+9):
		var r: Dictionary=g.world.db.recipes[id];var p:=Vector2(22+index%3*202,65+index/3*89)
		g.panel(Rect2(p,Vector2(192,84)))
		var components: Array=Equipment.components(g.world.db,id)
		var x:=8
		for j in range(components.size()):
			var c: Dictionary=components[j]
			var owned: Dictionary=g.world.build if c.kind=="weapon" else g.world.items
			var ready: bool=owned.get(c.id,0)>=c.level and (not c.get("evolved",false) or g.world.evolved.has(c.id))
			g.item_icon(c.id,p+Vector2(x,6),1,c.get("evolved",false))
			g.text_at(str(int(c.level)),p+Vector2(x+5,32),8,Color(.6,.8,.4) if ready else g.MUTED)
			x+=26
			if j<components.size()-1:g.text_at("+",p+Vector2(x-6,18),8,g.MUTED)
		g.text_at("=",p+Vector2(x-3,18),8,g.MUTED)
		g.item_icon(id,p+Vector2(x+11,6),1,true)
		g.wrapped(r.name,p+Vector2(8,45),176,8,g.INK,true)
		g.wrapped(r.effect,p+Vector2(8,64),176,8,g.MUTED)
		index+=1
	if g.recipe_page>0:g.button(Rect2(232,338,70,18),"Назад","recipes_prev")
	if (g.recipe_page+1)*9<ids.size():g.button(Rect2(338,338,70,18),"Далее","recipes_next")
