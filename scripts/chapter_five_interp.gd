extends RefCounted
## A tiny interpreter for the code duel. One language subset, three surface
## syntaxes: Java, JavaScript ({ } blocks, ;) and Python (indentation).
## Enough for loops, conditions, arrays and swaps; nothing else is reachable.
const STEP_LIMIT := 400000
var lang := "java"
var tokens: Array = []
var pos := 0
var error := ""
var steps := 0
var vars: Dictionary = {}

class Brk:
	var kind := ""

## Returns {"ok":bool, "error":String, "array":Array}.
func run(source: String, language: String, input: Array) -> Dictionary:
	lang = language;error = "";steps = 0;pos = 0
	vars = {"a":input.duplicate()}
	tokens = lex(source)
	if not error.is_empty():return {"ok":false, "error":error, "array":[]}
	var program: Array = []
	while not at("EOF"):
		var s = statement()
		if not error.is_empty():return {"ok":false, "error":error, "array":[]}
		if s != null:program.append(s)
	exec_block(program)
	if not error.is_empty():return {"ok":false, "error":error, "array":vars.a}
	return {"ok":true, "error":"", "array":vars.a}

# ------------------------------------------------------------------ lexer

func lex(src: String) -> Array:
	var out: Array = []
	var lines: PackedStringArray = src.replace("\t", "    ").split("\n")
	var indents: Array = [0]
	for ln in range(lines.size()):
		var line: String = lines[ln]
		var stripped: String = line.strip_edges()
		if stripped.is_empty() or stripped.begins_with("//") or stripped.begins_with("#"):continue
		if lang == "python":
			var ind: int = line.length() - line.strip_edges(true, false).length()
			if ind > indents.back():indents.append(ind);out.append(["INDENT", "", ln])
			while ind < indents.back():
				indents.pop_back();out.append(["DEDENT", "", ln])
			if ind != indents.back():error = "Строка %d: отступ не совпадает" % (ln + 1);return out
		var i := 0
		while i < line.length():
			var c: String = line[i]
			if c == " ":i += 1;continue
			if line.substr(i, 2) == "//" or c == "#":break
			if c.is_valid_int():
				var j := i
				while j < line.length() and line[j].is_valid_int():j += 1
				out.append(["NUM", line.substr(i, j - i), ln]);i = j;continue
			if c.is_valid_identifier() or c == "_":
				var j := i
				while j < line.length() and (line[j].is_valid_identifier() or line[j].is_valid_int() or line[j] == "_"):j += 1
				out.append(["ID", line.substr(i, j - i), ln]);i = j;continue
			var two: String = line.substr(i, 2)
			if two in ["==", "!=", "<=", ">=", "&&", "||", "++", "--", "+=", "-=", "*=", "//"]:
				out.append(["OP", two, ln]);i += 2;continue
			if c in "+-*/%<>=!()[]{},;:.":
				out.append(["OP", c, ln]);i += 1;continue
			error = "Строка %d: непонятный символ «%s»" % [ln + 1, c];return out
		if lang == "python":out.append(["NL", "", ln])
	while indents.size() > 1:indents.pop_back();out.append(["DEDENT", "", lines.size()])
	out.append(["EOF", "", lines.size()])
	return out

# ------------------------------------------------------------------ parser

func peek(k := 0) -> Array:return tokens[mini(pos + k, tokens.size() - 1)]
func at(kind: String, text := "") -> bool:
	var t: Array = peek()
	return t[0] == kind and (text.is_empty() or t[1] == text)
func take(kind: String, text := "") -> Array:
	var t: Array = peek()
	if t[0] != kind or (not text.is_empty() and t[1] != text):
		if error.is_empty():error = "Строка %d: ожидалось «%s», а там «%s»" % [t[2] + 1, text if not text.is_empty() else kind, t[1] if t[1] != "" else t[0]]
		return t
	pos += 1
	return t
func accept(kind: String, text := "") -> bool:
	if at(kind, text):pos += 1;return true
	return false

const TYPES := ["int", "long", "var", "let", "const", "boolean", "double", "float", "short"]

func statement():
	if not error.is_empty():return null
	if lang == "python":return py_statement()
	if accept("OP", ";"):return null
	if at("OP", "{"):return {"k":"block", "body":block()}
	if at("ID", "for"):
		pos += 1;take("OP", "(")
		var init = null
		if not at("OP", ";"):init = simple()
		take("OP", ";")
		var cond = {"k":"lit", "v":true} if at("OP", ";") else expr()
		take("OP", ";")
		var step = null
		if not at("OP", ")"):step = simple()
		take("OP", ")")
		return {"k":"for", "init":init, "cond":cond, "step":step, "body":body()}
	if accept("ID", "while"):
		take("OP", "(");var c = expr();take("OP", ")")
		return {"k":"while", "cond":c, "body":body()}
	if accept("ID", "if"):
		take("OP", "(");var c = expr();take("OP", ")")
		var then = body();var other = null
		if accept("ID", "else"):other = body()
		return {"k":"if", "cond":c, "then":then, "else":other}
	if accept("ID", "return"):accept("OP", ";");return {"k":"return"}
	if accept("ID", "break"):accept("OP", ";");return {"k":"break"}
	if accept("ID", "continue"):accept("OP", ";");return {"k":"continue"}
	var s = simple()
	take("OP", ";")
	return s

func body() -> Array:
	if at("OP", "{"):return block()
	var s = statement()
	return [s] if s != null else []

func block() -> Array:
	take("OP", "{")
	var out: Array = []
	while not at("OP", "}") and not at("EOF") and error.is_empty():
		var s = statement()
		if s != null:out.append(s)
	take("OP", "}")
	return out

## Declarations, assignments, ++/--, compound assignment.
func simple():
	if at("ID") and peek()[1] in TYPES:
		pos += 1
		while accept("OP", "[") :take("OP", "]")
	var target = expr()
	if accept("OP", "="):return {"k":"set", "targets":[target], "values":[expr()]}
	for op in ["+=", "-=", "*="]:
		if accept("OP", op):return {"k":"set", "targets":[target], "values":[{"k":"bin", "op":op[0], "a":target, "b":expr()}]}
	if accept("OP", "++"):return {"k":"set", "targets":[target], "values":[{"k":"bin", "op":"+", "a":target, "b":{"k":"lit", "v":1}}]}
	if accept("OP", "--"):return {"k":"set", "targets":[target], "values":[{"k":"bin", "op":"-", "a":target, "b":{"k":"lit", "v":1}}]}
	return {"k":"expr", "e":target}

func py_statement():
	while accept("NL"):pass
	if at("EOF") or at("DEDENT"):
		if at("DEDENT"):pos += 1
		return null
	if accept("ID", "pass"):take("NL");return null
	if accept("ID", "for"):
		var name: String = take("ID")[1];take("ID", "in");take("ID", "range");take("OP", "(")
		var args: Array = [expr()]
		while accept("OP", ","):args.append(expr())
		take("OP", ")");take("OP", ":")
		return {"k":"range", "name":name, "args":args, "body":py_block()}
	if accept("ID", "while"):
		var c = expr();take("OP", ":")
		return {"k":"while", "cond":c, "body":py_block()}
	if accept("ID", "if"):return py_if()
	if accept("ID", "return"):take("NL");return {"k":"return"}
	if accept("ID", "break"):take("NL");return {"k":"break"}
	if accept("ID", "continue"):take("NL");return {"k":"continue"}
	var targets: Array = [expr()]
	while accept("OP", ","):targets.append(expr())
	var s
	if accept("OP", "="):
		var values: Array = [expr()]
		while accept("OP", ","):values.append(expr())
		if values.size() != targets.size():error = "Строка %d: слева и справа разное число значений" % (peek()[2] + 1)
		s = {"k":"set", "targets":targets, "values":values}
	elif at("OP", "+=") or at("OP", "-=") or at("OP", "*="):
		var op: String = take("OP")[1]
		s = {"k":"set", "targets":[targets[0]], "values":[{"k":"bin", "op":op[0], "a":targets[0], "b":expr()}]}
	else:s = {"k":"expr", "e":targets[0]}
	take("NL")
	return s

func py_if():
	var c = expr();take("OP", ":")
	var then: Array = py_block();var other = null
	if accept("ID", "elif"):other = [py_if()]
	elif accept("ID", "else"):take("OP", ":");other = py_block()
	return {"k":"if", "cond":c, "then":then, "else":other}

func py_block() -> Array:
	take("NL");take("INDENT")
	var out: Array = []
	while not at("DEDENT") and not at("EOF") and error.is_empty():
		var s = py_statement()
		if s != null:out.append(s)
	accept("DEDENT")
	return out

func expr():return logic_or()
func logic_or():
	var a = logic_and()
	while at("OP", "||") or at("ID", "or"):pos += 1;a = {"k":"bin", "op":"or", "a":a, "b":logic_and()}
	return a
func logic_and():
	var a = logic_not()
	while at("OP", "&&") or at("ID", "and"):pos += 1;a = {"k":"bin", "op":"and", "a":a, "b":logic_not()}
	return a
func logic_not():
	if accept("OP", "!") or accept("ID", "not"):return {"k":"not", "a":logic_not()}
	return compare()
func compare():
	var a = additive()
	while peek()[0] == "OP" and peek()[1] in ["<", ">", "<=", ">=", "==", "!="]:
		var op: String = take("OP")[1];a = {"k":"bin", "op":op, "a":a, "b":additive()}
	return a
func additive():
	var a = term()
	while at("OP", "+") or at("OP", "-"):
		var op: String = take("OP")[1];a = {"k":"bin", "op":op, "a":a, "b":term()}
	return a
func term():
	var a = unary()
	while at("OP", "*") or at("OP", "/") or at("OP", "%") or at("OP", "//"):
		var op: String = take("OP")[1];a = {"k":"bin", "op":op, "a":a, "b":unary()}
	return a
func unary():
	if accept("OP", "-"):return {"k":"bin", "op":"-", "a":{"k":"lit", "v":0}, "b":unary()}
	return postfix()
func postfix():
	var a = primary()
	while error.is_empty():
		if accept("OP", "["):a = {"k":"index", "a":a, "i":expr()};take("OP", "]")
		elif accept("OP", "."):
			var name: String = take("ID")[1]
			if name == "length":a = {"k":"len", "a":a}
			else:error = "Строка %d: «.%s» не поддерживается" % [peek()[2] + 1, name]
		else:break
	return a
func primary():
	var t: Array = peek()
	if accept("NUM"):return {"k":"lit", "v":int(t[1])}
	if accept("OP", "("):
		var e = expr();take("OP", ")");return e
	if at("ID"):
		pos += 1
		match t[1]:
			"true", "True":return {"k":"lit", "v":true}
			"false", "False":return {"k":"lit", "v":false}
			"len":
				take("OP", "(");var e = expr();take("OP", ")");return {"k":"len", "a":e}
		return {"k":"var", "name":t[1], "line":t[2]}
	error = "Строка %d: не понял «%s»" % [t[2] + 1, t[1] if t[1] != "" else t[0]]
	pos += 1
	return {"k":"lit", "v":0}

# ------------------------------------------------------------------ evaluation

func tick() -> bool:
	steps += 1
	if steps > STEP_LIMIT:
		if error.is_empty():error = "Слишком долго — похоже на бесконечный цикл"
		return false
	return error.is_empty()

func exec_block(list: Array):
	for s in list:
		var r = exec(s)
		if r != null:return r
	return null

func exec(s):
	if s == null or not tick():return "stop"
	match s.k:
		"block":return exec_block(s.body)
		"expr":ev(s.e);return null
		"set":
			var values: Array = []
			for v in s.values:values.append(ev(v))
			for i in range(s.targets.size()):assign(s.targets[i], values[i])
			return null
		"if":
			if truth(ev(s.cond)):return exec_block(s.then)
			elif s.else != null:return exec_block(s.else)
			return null
		"while":
			while truth(ev(s.cond)) and tick():
				var r = exec_block(s.body)
				if r == "break":break
				if r in ["return", "stop"]:return r
			return null
		"for":
			if s.init != null:exec(s.init)
			while truth(ev(s.cond)) and tick():
				var r = exec_block(s.body)
				if r == "break":break
				if r in ["return", "stop"]:return r
				if s.step != null:exec(s.step)
			return null
		"range":
			var args: Array = s.args.map(func(e):return int(ev(e)))
			var from: int = 0 if args.size() == 1 else args[0]
			var to: int = args[0] if args.size() == 1 else args[1]
			var by: int = args[2] if args.size() > 2 else 1
			if by == 0:error = "range: шаг 0";return "stop"
			var i: int = from
			while (i < to if by > 0 else i > to) and tick():
				vars[s.name] = i
				var r = exec_block(s.body)
				if r == "break":break
				if r in ["return", "stop"]:return r
				i += by
			return null
		"return":return "return"
		"break":return "break"
		"continue":return "continue"
	return null

func truth(v) -> bool:
	if v is bool:return v
	return v != 0

func assign(target, value):
	match target.k:
		"var":vars[target.name] = value
		"index":
			var arr = ev(target.a);var i = ev(target.i)
			if not (arr is Array) or not (i is int) or i < 0 or i >= arr.size():
				if error.is_empty():error = "Выход за границы массива: индекс %s" % str(i)
				return
			arr[i] = value
		_:if error.is_empty():error = "Сюда нельзя присвоить"

func ev(e):
	if not error.is_empty():return 0
	match e.k:
		"lit":return e.v
		"var":
			if not vars.has(e.name):
				error = "Строка %d: неизвестная переменная «%s»" % [e.line + 1, e.name];return 0
			return vars[e.name]
		"len":
			var a = ev(e.a)
			return a.size() if a is Array else 0
		"index":
			var arr = ev(e.a);var i = ev(e.i)
			if not (arr is Array) or not (i is int) or i < 0 or i >= arr.size():
				if error.is_empty():error = "Выход за границы массива: индекс %s" % str(i)
				return 0
			return arr[i]
		"not":return not truth(ev(e.a))
		"bin":
			if e.op == "and":return truth(ev(e.a)) and truth(ev(e.b))
			if e.op == "or":return truth(ev(e.a)) or truth(ev(e.b))
			var a = ev(e.a);var b = ev(e.b)
			if not error.is_empty():return 0
			match e.op:
				"+":return a + b
				"-":return a - b
				"*":return a * b
				"/", "//":
					if b == 0:error = "Деление на ноль";return 0
					return int(a / b)
				"%":
					if b == 0:error = "Деление на ноль";return 0
					return a % b
				"<":return a < b
				">":return a > b
				"<=":return a <= b
				">=":return a >= b
				"==":return a == b
				"!=":return a != b
	return 0
