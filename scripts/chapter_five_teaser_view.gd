extends RefCounted
## After chapter IV's door: Steve falls out of a white sky into the source code
## (the "new location" card every chapter ends with). 3D scene from
## chapter_five_view3d.gd ("teaser"), title and buttons on top.
const NotchView = preload("res://scripts/chapter_five_notch_view.gd")
const INK := Color(.08, .09, .13)
const TEAL := Color(.05, .62, .5)

static func shown(g) -> bool:
	return g.is_four() and g.world.state == "RESULT" and g.world.victory and g.world.ending.phase == "done"

static func draw(g, t: float):
	var v = NotchView.view(g);v.ensure(g, "teaser", Vector2i(640, 360));v.sync_teaser(t)
	g.draw_texture_rect(v.viewport.get_texture(), Rect2(0, 0, 640, 360), false)
	# white sky first; a flash where he lands
	g.draw_rect(Rect2(0, 0, 640, 360), Color(1, 1, 1, 1 - smoothstep(.2, 1.1, t)))
	var land: float = t - v.TEASE_LAND
	if land > 0 and land < .5:g.draw_rect(Rect2(0, 0, 640, 360), Color(1, 1, 1, .55 * (1 - land / .5)))
	var bars: float = 20.0 * smoothstep(.4, 1.4, t)
	g.draw_rect(Rect2(0, 0, 640, bars), Color(.97, .975, .985));g.draw_rect(Rect2(0, 360 - bars, 640, bars), Color(.97, .975, .985))
	g.draw_line(Vector2(0, bars), Vector2(640, bars), Color(INK, .15));g.draw_line(Vector2(0, 360 - bars), Vector2(640, 360 - bars), Color(INK, .15))
	if t > 3.0:
		var a: float = smoothstep(3.0, 3.8, t)
		for i in range(24):
			var f: float = 1.0 - absf(i - 12) / 12.0
			g.draw_rect(Rect2(0, 40 + i * 4, 640, 4), Color(.975, .98, .99, .72 * a * smoothstep(0, .6, f)))
		g.centered("Глава V", 64, 16, Color(.45, .48, .56, a), true)
		title(g, "Исходный код", 98, a, t)
		var line := "> world.load(\"source\");"
		var typed: int = clampi(int((t - 3.6) * 18), 0, line.length())
		var shown_text: String = line.left(typed) + ("_" if int(t * 3) % 2 == 0 else " ")
		g.centered(shown_text, 118, 8, Color(TEAL, a))
	if t > 4.2:
		var a: float = smoothstep(4.2, 4.8, t)
		g.button(Rect2(199, 263, 242, 27), "Продолжить", "chapter_5")
		g.button(Rect2(199, 304, 242, 27), "В меню", "menu")
		if a < 1:g.draw_rect(Rect2(190, 255, 260, 80), Color(.97, .975, .985, 1 - a))

## Big bold title with a rare horizontal tear and a teal/red split.
static func title(g, text: String, y: float, a: float, t: float):
	var tick: int = int(t * 60)
	var glitch: bool = posmod(tick, 173) in [120, 121, 122, 125, 126]
	if glitch:
		g.centered(text, y - 1, 32, Color(.9, .2, .3, .5 * a), true)
		g.centered(text, y + 1, 32, Color(TEAL, .6 * a), true)
	g.centered(text, y, 32, Color(INK, a), true)

## Frees the 3D scene once the card is gone (outside chapter V's own use).
static func idle(g):
	if not g.is_five() and g.has_meta("ch5_view3d"):NotchView.release(g)
