extends RefCounted
## One boss bar for every chapter (13.11): the same frame, size and type
## everywhere; only the fill colour belongs to the boss. Lost health lingers as
## a pale chunk that drains after the hit, so every blow reads.
const FRAME := Rect2(169, 46, 302, 7)

static func draw(g, title: String, k: float, fill: Color, key: String = ""):
	k = clampf(k, 0, 1)
	var memo: Dictionary = g.get_meta("boss_bar_trail", {})
	var id: String = key if not key.is_empty() else title
	var trail: float = float(memo.get(id, k))
	trail = k if k > trail else move_toward(trail, k, .004 if trail - k < .02 else (trail - k) * .06)
	memo[id] = trail;g.set_meta("boss_bar_trail", memo)
	g.centered(title, 41, 8, Color.WHITE, true)
	g.draw_rect(FRAME.grow(1), Color(0, 0, 0, .75))
	g.draw_rect(FRAME, Color("1a1416"))
	g.draw_rect(Rect2(FRAME.position, Vector2(FRAME.size.x * trail, FRAME.size.y)), Color(1, .92, .85, .55))
	g.draw_rect(Rect2(FRAME.position, Vector2(FRAME.size.x * k, FRAME.size.y)), fill)
	g.draw_rect(Rect2(FRAME.position, Vector2(FRAME.size.x * k, 1)), Color(1, 1, 1, .45))
	g.draw_rect(Rect2(FRAME.position + Vector2(0, FRAME.size.y - 1), Vector2(FRAME.size.x * k, 1)), Color(0, 0, 0, .3))
