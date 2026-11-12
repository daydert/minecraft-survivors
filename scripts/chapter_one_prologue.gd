extends Control
## Isolated movie owner. Combat is never stepped while this owner is active.
signal completed
var active := false
var paused := false
var player: VideoStreamPlayer
var pause_panel: VBoxContainer
var music: AudioStreamPlayer
var effects: AudioStreamPlayer
var game
var last_position := 0.0
const MOVIE := "res://assets/cinematics/ch1_intro.ogv"

func begin(g):
	stop()
	game = g
	active = true
	last_position = 0.0
	paused = false
	visible = true
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	game.world.state = "PROLOGUE"
	# The exact first frame covers the decoder's initial upload.
	var poster := TextureRect.new()
	poster.texture = load("res://assets/cinematics/ch1_intro_poster.png")
	poster.size = size
	poster.stretch_mode = TextureRect.STRETCH_SCALE
	poster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(poster)
	player = VideoStreamPlayer.new()
	player.expand = true
	player.size = size
	player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player.stream = load(MOVIE)
	player.volume_db = linear_to_db(maxf(.0001, game.settings.effects))
	add_child(player)
	player.finished.connect(finish)
	player.play()
	effects = AudioStreamPlayer.new()
	effects.stream = load("res://assets/cinematics/ch1_intro_sfx.ogg")
	effects.volume_db = linear_to_db(maxf(.0001, game.settings.effects))
	add_child(effects)
	effects.play()
	music = AudioStreamPlayer.new()
	music.stream = load("res://assets/audio/music.ogg")
	add_child(music)
	music.play()
	pause_panel = VBoxContainer.new()
	pause_panel.add_theme_font_override("font", game.font)
	pause_panel.add_theme_font_size_override("font_size", 12)
	pause_panel.position = Vector2(215, 125)
	pause_panel.add_theme_constant_override("separation", 8)
	add_child(pause_panel)
	for spec in [["Продолжить", resume], ["Пропустить", finish], ["В меню", leave]]:
		var button := Button.new()
		button.text = spec[0]
		button.custom_minimum_size = Vector2(210, 30)
		if game.button_styles.size() >= 2:
			button.add_theme_stylebox_override("normal", game.button_styles[0])
			button.add_theme_stylebox_override("hover", game.button_styles[1])
			button.add_theme_stylebox_override("focus", game.button_styles[1])
		button.pressed.connect(spec[1])
		pause_panel.add_child(button)
	pause_panel.hide()

func set_paused(value: bool):
	if not active: return
	paused = value
	player.paused = value
	music.stream_paused = value
	effects.stream_paused = value
	pause_panel.visible = value
	if value: pause_panel.get_child(0).grab_focus()

func resume():
	set_paused(false)

func finish():
	if not active: return
	var g = game
	last_position = maxf(last_position, player.stream_position)
	stop()
	# The film ends on black; the walk-in keeps its own fade from black.
	g.world.begin_intro(false)
	g.input_lock = .25
	completed.emit()

func leave():
	var g = game
	stop()
	g.action("menu")

func stop():
	active = false
	paused = false
	visible = false
	if is_instance_valid(player):
		player.stop()
		player.stream = null
	if is_instance_valid(music): music.stop()
	if is_instance_valid(effects): effects.stop()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	player = null
	music = null
	effects = null
	pause_panel = null
	game = null

func _process(_delta):
	if not active or not is_instance_valid(music): return
	var t := player.stream_position
	last_position = maxf(last_position, t)
	var gain := clampf(t, 0, 1) * (1.0 - smoothstep(8.7, 9.5, t)) * .13
	music.volume_db = linear_to_db(maxf(.0001, game.settings.music * gain))
	if t >= 9.5 and music.playing: music.stop()

func handle(event: InputEvent) -> bool:
	if not active: return false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			set_paused(not paused)
		elif event.keycode in [KEY_SPACE, KEY_ENTER] and not paused:
			finish()
	elif event is InputEventMouseButton and event.pressed and not paused:
		finish()
	return true
