extends RefCounted
## The end of chapter V: the code duel, the erasure and the sword in the
## console, the fistfight with lines of code and the wire, the chair, the
## door and the flight between other worlds. Pure state; views read it.
const Interp = preload("res://scripts/chapter_five_interp.gd")
const LANGS := ["java", "python", "js"]
const LANG_NAMES := {"java":"Java", "python":"Python", "js":"JavaScript"}
const HEADERS := {"java":["void sort(int[] a) {", "}"], "python":["def sort(a):", ""], "js":["function sort(a) {", "}"]}
const SOLUTIONS := {
	"java":["for (int i = 0; i < a.length - 1; i++) {", "    for (int j = 0; j < a.length - 1 - i; j++) {", "        if (a[j] > a[j + 1]) {", "            int t = a[j];", "            a[j] = a[j + 1];", "            a[j + 1] = t;", "        }", "    }", "}"],
	"python":["n = len(a)", "for i in range(n - 1):", "    for j in range(n - 1 - i):", "        if a[j] > a[j + 1]:", "            a[j], a[j + 1] = a[j + 1], a[j]"],
	"js":["for (let i = 0; i < a.length - 1; i++) {", "    for (let j = 0; j < a.length - 1 - i; j++) {", "        if (a[j] > a[j + 1]) {", "            let t = a[j];", "            a[j] = a[j + 1];", "            a[j + 1] = t;", "        }", "    }", "}"]}
const NOTCH_CODE := "void sort(int[] a) {\n  for (int i = 0; i < a.length; i++)\n    for (int j = 0; j + 1 < a.length - i; j++)\n      if (a[j] > a[j + 1]) {\n        int t = a[j]; a[j] = a[j + 1]; a[j + 1] = t;\n      }\n}"
const TESTS := [[5, 3, 9, 1, 7, 2], [1], [], [4, 4, 1, 0, 8, 2], [9, 8, 7, 6, 5, 4, 3, 2, 1]]
const CHAIR := [[0.4, "Серьёзно, верёвка?", 3.0], [4.0, "Слушай, как бы ни было странно, но ты действительно моё лучшее творение", 3.6],
	[8.0, "Чёрт, миллионы итераций, и никто досюда не доходил. Как это вообще могло произойти?", 4.2], [12.6, "Слушай, давай просто будем жить в гармонии? Я могу заново отстроить для тебя любой мир, вернуть \"её\". Зачем нам вражда?", 3.8],
	[16.8, "Если тебя так задел мой брат, давай оставим его в прошлом?", 4.2], [21.4, "Хватит сканировать мой грёбаный мозг! Ты мой код, каждая твоя мысль — это моя строчка, как бы они ни мутировали!", 3.8],
	[25.6, "Ты не имеешь права здесь ничего трогать. Слышишь? Ни-че-го", 4.0], [30.65, "ЭЙ, УБЕРИ ЭТО\nМСТИТЬ — ЭТО ДЕЛО СЛАБЫХ!", 2.25]]
const CHAIR_SCAN := [3.4, 29.6]
const CHAIR_SWORD := 30.0
const CHAIR_STAB := 33.0
const CHAIR_LENGTH := 44.0
const FLIGHT_THEME := 13.0
const FLIGHT_FADE := 23.5
const FLIGHT_OTHER := 27.0
const FLIGHT_STING := 30.6
const FLIGHT_LENGTH := 32.0
const CREDITS := [[1.0, "MINECRAFT SURVIVORS", ""], [6.0, "Создатель", "Daydert"], [11.0, "Композитор", "Kibi"], [16.0, "Музыка · тестирование", "RodinCity"],
	[21.0, "Тестирование", "SET553355"], [26.5, "Спасибо, что дошёл до конца", ""], [31.5, "", ""]]
const CREDITS_LENGTH := 37.0

var phase := ""
var age := 0.0
var cues := 0
var sounds: Array = []
# duel
var lang_index := 0
var advanced := false
var pick_row := 0
var built: Array = []
var pool: Array = []
var pool_choice := 0
var penalty := 0.0
var wrong_flash := 0.0
var editor: Array = [""]
var row := 0
var col := 0
var result := ""
var result_ok := false
var notch_progress := 0.0
# erase
var erase := 0.0
var presses := 0
var thrown := -1.0
# chair / flight
var line := ""
var line_age := 0.0
var line_length := 0.0

func reset():
	phase = "";age = 0.0;cues = 0;sounds.clear();built.clear();pool.clear();editor = [""];row = 0;col = 0;result = "";notch_progress = 0.0
	erase = 0.0;presses = 0;thrown = -1.0;line = ""

func lang() -> String:return LANGS[lang_index]
func change(next: String):phase = next;age = 0.0;cues = 0
func cue(bit: int, at: float) -> bool:
	if age >= at and not (cues & (1 << bit)):
		cues |= 1 << bit;return true
	return false
func say(text: String, length: float):line = text;line_age = 0.0;line_length = length

func duration() -> float:return 180.0 if advanced else 55.0

# ------------------------------------------------------------------ the duel

func begin_pick():
	change("pick");pick_row = 0

func start_duel():
	change("duel");built.clear();penalty = 0.0;notch_progress = 0.0;result = "";result_ok = false
	var sol: Array = SOLUTIONS[lang()]
	pool = range(sol.size())
	# A fixed shuffle so every attempt reads the same.
	for i in range(pool.size() - 1, 0, -1):
		var j: int = (i * 7 + 3) % (i + 1)
		var t = pool[i];pool[i] = pool[j];pool[j] = t
	pool_choice = 0
	editor = [""];row = 0;col = 0
	say("Ты хотя бы знаешь, что такое сортировка пузырьком?", 2.6)

func press(action: String) -> bool:
	match phase:
		"pick":
			match action:
				"left":lang_index = posmod(lang_index - 1, LANGS.size())
				"right":lang_index = posmod(lang_index + 1, LANGS.size())
				"up", "down":advanced = not advanced
				"accept":start_duel()
			return true
		"duel":
			if advanced:return false
			match action:
				"up":pool_choice = posmod(pool_choice - 1, maxi(1, pool.size()))
				"down":pool_choice = posmod(pool_choice + 1, maxi(1, pool.size()))
				"accept":pick(pool_choice)
				_:
					if action.is_valid_int() and int(action) >= 1 and int(action) <= pool.size():pick(int(action) - 1)
			return true
		"erase":
			if action == "accept":presses += 1;erase = maxf(0, erase - .07);sounds.append("resist")
			return true
	return false

func pick(index: int):
	if index < 0 or index >= pool.size():return
	var sol: Array = SOLUTIONS[lang()]
	var want: int = built.size()
	var chosen: int = pool[index]
	# Identical lines (closing braces) count as either.
	if sol[chosen] == sol[want]:
		built.append(want);pool.erase(chosen)
		pool_choice = mini(pool_choice, maxi(0, pool.size() - 1))
		sounds.append("type")
		if built.size() == sol.size():submit(source_of_built())
	else:
		penalty += 4.0;wrong_flash = .4;sounds.append("wrong")

func source_of_built() -> String:
	var sol: Array = SOLUTIONS[lang()]
	var out: Array = []
	for i in built:out.append(sol[i])
	return "\n".join(out)

## Typing in the advanced editor.
func type_text(text: String):
	if phase != "duel" or not advanced:return
	var l: String = editor[row]
	editor[row] = l.substr(0, col) + text + l.substr(col);col += text.length()

func key(name: String):
	if phase != "duel" or not advanced:return
	var l: String = editor[row]
	match name:
		"enter":
			var indent: int = l.length() - l.strip_edges(true, false).length()
			if l.strip_edges().ends_with("{") or l.strip_edges().ends_with(":"):indent += 4
			var rest: String = l.substr(col)
			editor[row] = l.substr(0, col)
			row += 1;editor.insert(row, " ".repeat(indent) + rest.strip_edges(true, false));col = indent
		"backspace":
			if col > 0:
				var n: int = 4 if col >= 4 and l.substr(col - 4, 4) == "    " else 1
				editor[row] = l.substr(0, col - n) + l.substr(col);col -= n
			elif row > 0:
				col = editor[row - 1].length();editor[row - 1] += l;editor.remove_at(row);row -= 1
		"delete":
			if col < l.length():editor[row] = l.substr(0, col) + l.substr(col + 1)
			elif row < editor.size() - 1:editor[row] += editor[row + 1];editor.remove_at(row + 1)
		"tab":type_text("    ")
		"left":
			if col > 0:col -= 1
			elif row > 0:row -= 1;col = editor[row].length()
		"right":
			if col < l.length():col += 1
			elif row < editor.size() - 1:row += 1;col = 0
		"up":row = maxi(0, row - 1);col = mini(col, editor[row].length())
		"down":row = mini(editor.size() - 1, row + 1);col = mini(col, editor[row].length())
		"home":col = 0
		"end":col = l.length()
		"run":submit("\n".join(editor))

func submit(source: String):
	for t in TESTS:
		var r: Dictionary = Interp.new().run(source, lang(), t)
		if not r.ok:
			result = r.error;result_ok = false;sounds.append("wrong");return
		var want: Array = t.duplicate();want.sort()
		if r.array != want:
			result = "Не отсортировано: %s → %s" % [str(t), str(r.array)];result_ok = false;sounds.append("wrong");return
	result = "Все тесты пройдены";result_ok = true;sounds.append("win")

func duel_step(dt: float) -> String:
	wrong_flash = maxf(0, wrong_flash - dt)
	if result_ok:return "won"
	notch_progress = minf(1.0, (age + penalty) / duration())
	if notch_progress >= 1.0:return "lost"
	return ""

# ------------------------------------------------------------------ the erasure

func begin_erase():change("erase");erase = 0.0;presses = 0;thrown = -1.0

func erase_step(dt: float) -> String:
	if cue(0, .2):say("Нет, нет, нет\nТак не пойдёт\nТы больше здесь никогда не появишься!", 2.8);sounds.append("glitch")
	if thrown < 0:
		erase = minf(1.0, erase + dt * .1)
		if presses >= 14:thrown = 0.0;sounds.append("throw")
		elif erase>=1.0:change("erase_failed");return "lost"
	else:
		thrown += dt
		if thrown >= .6 and not (cues & 2):cues |= 2;sounds.append("console");say("Ты… что ты сделал?!", 2.2)
		if thrown >= 3.6:return "done"
	return ""

# ------------------------------------------------------------------ the chair

func chair_step(dt: float) -> String:
	for i in range(CHAIR.size()):
		if cue(i, CHAIR[i][0]):say(CHAIR[i][1], CHAIR[i][2])
	if cue(12, CHAIR_SCAN[0]):sounds.append("scan")
	if cue(13, CHAIR_SWORD):sounds.append("draw")
	if cue(14, CHAIR_STAB):sounds.append("stab")
	if age >= CHAIR_LENGTH:return "done"
	return ""

func scan() -> float:return clampf((age - CHAIR_SCAN[0]) / (CHAIR_SCAN[1] - CHAIR_SCAN[0]), 0, 1)

func skip_line():
	if phase != "chair":return
	for c in CHAIR:
		if c[0] > age + .05:
			age = c[0] - .02;return
	if age > CHAIR[CHAIR.size() - 1][0]:age = maxf(age, CHAIR_LENGTH - 6.0)

# ------------------------------------------------------------------ the door and the flight

func flight_step(dt: float) -> String:
	if cue(0, 3.2):sounds.append("door")
	if cue(1, FLIGHT_THEME):sounds.append("theme")
	if cue(2, FLIGHT_FADE):sounds.append("fade")
	if cue(3, FLIGHT_OTHER):sounds.append("arrive")
	if cue(4, FLIGHT_STING):sounds.append("sting")
	if age >= FLIGHT_LENGTH:return "done"
	return ""

func credits_step(dt: float) -> String:
	if cue(0, .3):sounds.append("credits")
	if age >= CREDITS_LENGTH:return "done"
	return ""

func step(dt: float) -> String:
	age += dt
	if line_length > 0:
		line_age += dt
		if line_age >= line_length:line = "";line_length = 0
	match phase:
		"duel":return duel_step(dt)
		"erase":return erase_step(dt)
		"chair":return chair_step(dt)
		"flight":return flight_step(dt)
		"credits":return credits_step(dt)
	return ""
