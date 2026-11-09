extends Node2D

const W = preload("res://scripts/campaign_world.gd")
const NW = preload("res://scripts/nether_world.gd")
const EW = preload("res://scripts/end_world.gd")
var end_renderer=preload("res://scripts/end_renderer.gd").new()
var recipe_page=0
var achievements=preload("res://scripts/achievements.gd").new()
var achievements_view=preload("res://scripts/achievements_view.gd").new()
var achievement_tier="all"
var achievement_page=0
var achievements_from=""
var achievement_state="MENU"
var achievement_toast=""
var achievement_toast_age=0.0
var end_rift=preload("res://scripts/end_rift_view.gd").new()
var end_assets: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/end_assets.json"))
var end_assets_loaded=false
const BG = Color("101010")
const INK = Color("ffffff")
const MUTED = Color("aaaaaa")
const GOLD = Color("dddddd")
const LIME = Color("eeeeee")
var world = W.new()
var blood_rift=preload("res://scripts/blood_rift_view.gd").new()
var finale_renderer=preload("res://scripts/finale_renderer.gd").new()
var chapter_assets:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_assets.json"))
var audio: GameSound
var font: Font = preload("res://assets/fonts/minecraft/minecraft_regular.fnt")
var bold: Font = preload("res://assets/fonts/minecraft/minecraft_bold.fnt")
var button_styles: Array[StyleBoxTexture] = []
var textures = {}
var minecraft_assets: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/minecraft_assets.json"))
var buttons: Array = []
var selected = 0
var mouse = Vector2.ZERO
var ui_time = 0.0
var screen = ""
var record = {"time":0.0,"kills":0,"score":0}
var pause_from = "RUNNING"
var stats_from = "RUNNING"
var inventory_from = "RUNNING"
var solo_chapter = 1
var nether_renderer = preload("res://scripts/nether_renderer.gd").new()
var last_state = "MENU"
var input_lock = 0.0
var settings = {"music":0.4,"effects":0.6,"fullscreen":false,"shake":true,"flashes":true,"numbers":false}
var qa_mode = ""
var qa_frames = 0
var autoplay_style = ""
var qa_controller
var fast_run = false
var frame_samples: Array = []
var sim_samples: Array = []
var stress_mode = false
var recording_stage = ""
var quitting = false
var chapter_preview=false
var secret_keys=""
var secret_key_time=0
var lab_chapter=1
var lab_state=""
var lab_screen=""
const BossLab=preload("res://scripts/boss_lab.gd")
var coop = preload("res://scripts/coop_session.gd").new()
var nickname_field: LineEdit
var address_field: LineEdit
var network_nick = "Стив"
var network_address = ""
var stats_coop_was_paused = false
var coop_probe = false

func _ready():
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(blood_rift)
	add_child(end_rift)
	get_window().title="Minecraft Survivors"
	for name in chapter_assets.clips:minecraft_assets.clips[name]=chapter_assets.clips[name]
	var nether_assets: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/nether_assets.json"))
	for name in nether_assets.clips:minecraft_assets.clips[name]=nether_assets.clips[name]
	for name in nether_assets.sprites:load_texture(name)
	var ghast_assets: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/ghast_intro_assets.json"))
	for name in ghast_assets.clips:minecraft_assets.clips[name]=ghast_assets.clips[name]
	for name in ghast_assets.sprites:load_texture(name)
	var duel_assets: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/duel_assets.json"))
	for name in duel_assets.clips:minecraft_assets.clips[name]=duel_assets.clips[name]
	for name in duel_assets.sprites:load_texture(name)
	for name in ["ground","heart","heart_half","heart_empty","rock","pumpkin","stump","flowers","tree_0","tree_1","tree_2","experience_orb","icon_arrow","icon_splash_potion","flamebow_draw"]:
		load_texture(name)
	for name in minecraft_assets.clips:
		load_texture(name)
		var clip: Dictionary = minecraft_assets.clips[name]
		clip["total"] = 0.0
		clip["uniform"] = true
		for duration in clip.durations:
			clip.total += duration
			if not is_equal_approx(duration,clip.durations[0]): clip.uniform = false
	for id in world.db.weapons.keys() + world.db.passives.keys() + ["apple","emerald","chest","netherite","flamebow","channeling"]:
		load_texture("icon_"+id)
	for kind in ["steve","zombie","skeleton","creeper","spider","slime","ravager","elite","vindicator"]:
		load_texture(kind+"_atlas")
	for name in ["herobrine_throne","tree_dead_0","tree_dead_1","tree_dead_2","ground_scorched","nether_backdrop","portal_frame"]:load_texture(name)
	for name in ["hud_six_slots","hud_selection","hud_xp_empty","hud_xp_full","gui_button","gui_button_active","heart_blink","heart_half_blink"]:
		load_texture(name)
	for name in ["gui_button","gui_button_active"]:
		var style = StyleBoxTexture.new()
		style.texture = textures[name]
		for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: style.set_texture_margin(side,2)
		button_styles.append(style)
	for name in JSON.parse_string(FileAccess.get_file_as_string("res://data/achievement_assets.json")).sprites:load_texture(name)
	achievements.load_profile()
	load_settings()
	audio = GameSound.new()
	add_child(audio)
	audio.update_volumes(settings.music,settings.effects)
	coop.name = "CoopSession"
	coop.game = self
	add_child(coop)
	create_network_fields()
	get_window().focus_exited.connect(_focus_lost)
	get_window().close_requested.connect(quit_game)
	get_tree().auto_accept_quit = false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): qa_mode = arg.trim_prefix("--capture=")
		if arg.begins_with("--autoplay="): autoplay_style = arg.trim_prefix("--autoplay=")
		if arg == "--fast-run": fast_run = true
		if arg == "--stress": stress_mode = true
		if arg=="--chapter-preview":chapter_preview=true
		if arg=="--coop-probe":coop_probe=true
		if arg=="--nether-preview":start_chapter(2)
		if arg=="--end-preview":start_chapter(3)
		if arg.begins_with("--record-stage="): recording_stage = arg.trim_prefix("--record-stage=")
	if not qa_mode.is_empty():
		set_process_input(false)
		prepare_capture()
	if not autoplay_style.is_empty():
		qa_controller = load("res://scripts/autoplay_bot.gd").new(autoplay_style)
		world.reset(151 if autoplay_style in ["sword","trident"] else (153 if autoplay_style == "random" else 152))
	if stress_mode: prepare_stress()
	if not recording_stage.is_empty(): prepare_recording()
	if chapter_preview:
		world.reset(724)
		world.time=719.9
		world.hp=20
		world.build={"sword":8,"bow":5,"trident":4,"fire":3,"potion":2,"fangs":3}
		world.items={"blaze":3,"redstone":2,"amethyst":2,"armor":2,"sugar":2,"hopper":2}
	if coop_probe:
		var probe = load("res://scripts/coop_probe.gd").new()
		probe.game = self
		add_child(probe)

func ensure_end_assets(icons_only: bool=false):
	if end_assets_loaded:return
	for name in end_assets.sprites:
		if not icons_only or name.begins_with("icon_"):load_texture(name)
	if not icons_only:end_assets_loaded=true

func unload_end_assets():
	for name in end_assets.sprites:textures.erase(name)
	end_assets_loaded=false

func load_texture(name: String):
	var p = "res://assets/sprites/%s.png" % name
	if ResourceLoader.exists(p): textures[name] = load(p)

func load_settings():
	var cfg = ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		for key in settings:
			var value = cfg.get_value("settings",key,settings[key])
			if typeof(value) == typeof(settings[key]): settings[key] = value
	for key in record: record[key] = cfg.get_value("record",key,record[key])
	network_nick = str(cfg.get_value("network","nick","Стив")).left(16)
	network_address = str(cfg.get_value("network","address","")).left(64)
	settings.music = snappedf(clampf(settings.music,0,1),.1)
	settings.effects = snappedf(clampf(settings.effects,0,1),.1)
	if settings.fullscreen: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func save_settings():
	var cfg = ConfigFile.new()
	for key in settings: cfg.set_value("settings",key,settings[key])
	for key in record: cfg.set_value("record",key,record[key])
	cfg.set_value("network","nick",network_nick)
	cfg.set_value("network","address",network_address)
	cfg.save("user://settings.cfg")

func _focus_lost():
	if coop.active:
		# Switching windows must not repeatedly pause both testers' clients.
		return
	if world.state in ["RUNNING","FINALE"] and qa_mode.is_empty() and autoplay_style.is_empty() and qa_controller == null and not stress_mode:
		pause_from = world.state
		world.state = "PAUSED"
		selected = 0

func _physics_process(delta):
	if quitting:return
	var movement = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): movement.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): movement.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): movement.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): movement.y += 1
	if coop.active:
		if not get_window().has_focus(): movement = Vector2.ZERO
		coop.tick(delta,movement)
		return
	if screen.is_empty() and qa_mode.is_empty():
		if qa_controller != null:
			for i in range(120 if fast_run else 1):
				if world.state=="LEVEL_UP": world.choose(qa_controller.choose(world))
				elif world.state=="CHEST":
					if recording_stage=="evolution" and ui_time<2.0:return
					world.chest_delay=0
					world.close_chest()
				elif world.state=="RESULT":
					finish_autoplay()
					return
				else:
					var start=Time.get_ticks_usec()
					world.step(1.0/60,qa_controller.movement(world))
					sim_samples.append((Time.get_ticks_usec()-start)/1000.0)
		elif stress_mode:
			var start=Time.get_ticks_usec()
			world.invulnerable=1
			world.state="RUNNING"
			world.xp=0
			world.step(delta,Vector2.from_angle(world.clock*0.2))
			while world.normal_count()<250: world.spawn("zombie",world.player+Vector2.from_angle(world.rng.randf()*TAU)*world.rng.randf_range(45,260))
			sim_samples.append((Time.get_ticks_usec()-start)/1000.0)
		else:
			if is_end() and world.state=="LEVEL_UP":world.tick_choices(delta)
			world.step(delta,movement)

func _process(delta):
	if quitting:return
	coop.present(delta)
	sync_network_fields()
	var hero_theme=world.finale.active and (not world.finale.has_method("duel_phase") or not world.finale.complete)
	if is_end() and world.stage=="chapter_four":world.stage_age+=delta
	var theme="victory" if world.get("win_music")==true else "endersteve" if is_end() and world.stage in ["betrayal","last_arrival","last_duel","endsteve_death","hand","hand_pickup","return_portal","portal_ready","rekindle","exit_jump","chapter_four"] else "dragon" if is_end() and world.stage in ["departure","dragon_arrival","dragon","dragon_death"] else "herobrine" if hero_theme else "wither" if is_nether() and world.stage in ["departure","arrival","wither","defeat"] else ""
	audio.set_music_context(theme,world.state not in ["MENU","RESULT"])
	update_achievements(delta)
	ui_time += delta
	if stress_mode:
		frame_samples.append(delta*1000)
		if frame_samples.size()>=1860: finish_stress()
	input_lock = maxf(0,input_lock - delta)
	if coop.active and coop.hosting and coop.running:
		world.save_actor()
		var paused = world.players.values().any(func(a): return a.paused)
		if not paused:
			for actor in world.players.values(): actor.chest_delay = maxf(0,actor.chest_delay-delta)
		world.active_id = 0
		world.use_actor(world.local_id)
	elif not coop.active and world.state == "CHEST": world.chest_delay = maxf(0,world.chest_delay - delta)
	if world.state != last_state:
		selected = 0
		input_lock = 0.12
		last_state = world.state
		if world.state=="RESULT" and qa_mode.is_empty():
			if world.time>record.time or (world.time==record.time and world.score>record.score):
				record={"time":world.time,"kills":world.kills,"score":world.score}
				save_settings()
	for id in world.sounds: audio.play(id)
	world.sounds.clear()
	if not qa_mode.is_empty():
		qa_frames += 1
		if qa_frames == 12: capture.call_deferred()
	queue_redraw()
	if not qa_mode.is_empty() or not recording_stage.is_empty() or stress_mode:
		RenderingServer.force_draw(false)

func _input(event):
	if screen == "multiplayer" and event is InputEventKey and (nickname_field.has_focus() or address_field.has_focus()) and event.keycode not in [KEY_ESCAPE,KEY_F11,KEY_F8]: return
	if event is InputEventMouseMotion:
		mouse = get_global_mouse_position()
		for i in range(buttons.size()):
			if buttons[i].rect.has_point(mouse): selected = i
	if event is InputEventKey and event.pressed and not event.echo:
		if is_end() and screen.is_empty() and world.state=="RUNNING":
			if event.physical_keycode==KEY_E or event.keycode==KEY_E:world.active_item("ender_pearl");return
			if event.physical_keycode==KEY_SPACE or event.keycode==KEY_SPACE:world.active_item("elytra");return
			if event.keycode==KEY_SHIFT:world.active_item("rocket");return
		if secret_input(event):return
		if event.keycode == KEY_F8:
			coop.mark_lag()
			if coop.diagnostics.enabled: audio.play("select")
			return
		if event.keycode==KEY_I or event.physical_keycode==KEY_I:
			toggle_inventory()
			return
		if event.keycode==KEY_L or event.physical_keycode==KEY_L:
			toggle_stats()
			return
		if event.keycode == KEY_F11:
			action("fullscreen")
			return
		if event.keycode == KEY_ESCAPE:
			if screen=="achievements":close_achievements()
			elif screen=="boss_lab":close_boss_lab()
			elif screen=="recipes":screen="inventory"
			elif screen=="inventory":close_inventory()
			elif screen=="stats": close_stats()
			elif screen == "multiplayer": action("network_back")
			elif not screen.is_empty():
				screen = ""
				selected = 0
			elif coop.active and coop.running:
				coop.command("pause",0 if world.players[world.local_id].paused else 1)
			elif world.state == "PAUSED": action("resume")
			elif world.state in ["RUNNING","LEVEL_UP","CHEST","FINALE"]:
				pause_from = world.state
				world.state = "PAUSED"
				selected = 0
			return
		if event.keycode in [KEY_LEFT,KEY_UP]: selected = posmod(selected-1,maxi(1,buttons.size()))
		if event.keycode in [KEY_RIGHT,KEY_DOWN,KEY_TAB]: selected = posmod(selected+1,maxi(1,buttons.size()))
		if input_lock <= 0 and world.state == "LEVEL_UP" and screen.is_empty() and event.keycode in [KEY_1,KEY_2,KEY_3,KEY_4,KEY_5] and event.keycode-KEY_1<world.choices.size():
			if coop.active: coop.command("choice",event.keycode-KEY_1)
			else: world.choose(event.keycode-KEY_1)
			input_lock = 0.14
		elif event.keycode in [KEY_ENTER,KEY_SPACE] and input_lock <= 0 and not buttons.is_empty():
			action(buttons[mini(selected,buttons.size()-1)].id)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and input_lock <= 0:
		mouse = get_global_mouse_position()
		for b in buttons:
			if b.rect.has_point(mouse):
				action(b.id)
				break

func action(id: String):
	audio.play("select")
	input_lock = 0.1
	if id.begins_with("achievement_tier_"):
		achievement_tier=id.trim_prefix("achievement_tier_");achievement_page=0;selected=0;return
	if id.begins_with("lab_chapter_"):
		lab_chapter=id.trim_prefix("lab_chapter_").to_int()
		if lab_chapter==3:ensure_end_assets(true)
		return
	if id.begins_with("lab_build_"):
		if coop.active:return
		start_chapter(lab_chapter)
		BossLab.equip(world,id.trim_prefix("lab_build_").to_int())
		if is_nether() or is_end():world.begin_arena()
		else:world.finale.begin(world)
		return
	if id.begins_with("choice_"):
		if coop.active: coop.command("choice",id.trim_prefix("choice_").to_int())
		else: world.choose(id.trim_prefix("choice_").to_int())
		return
	if id.begins_with("discard_"):
		if not coop.active and screen=="inventory":world.discard(id.trim_prefix("discard_"))
		return
	if id.begins_with("volume_"):
		var parts=id.split("_")
		adjust_volume(parts[1],-.1 if parts[2]=="down" else .1)
		return
	match id:
		"lab_back":close_boss_lab()
		"chapters":screen="chapters"
		"achievements":open_achievements()
		"achievements_back":close_achievements()
		"achievements_next":achievement_page+=1
		"achievements_prev":achievement_page=maxi(0,achievement_page-1)
		"chapter_1":start_chapter(1)
		"chapter_2":start_chapter(2)
		"chapter_3":start_chapter(3)
		"end_reroll":
			if is_end():world.reroll_choices()
		"skip_reward":
			if not coop.active and world is W:world.skip_reward()
		"recipes_next":recipe_page+=1
		"recipes_prev":recipe_page=maxi(0,recipe_page-1)
		"inventory":toggle_inventory()
		"close_inventory":close_inventory()
		"recipes":screen="recipes";recipe_page=0
		"recipes_back":screen="inventory"
		"logs": coop.open_log_folder()
		"multiplayer":
			screen = "multiplayer"
			coop.status = ""
			sync_network_fields()
		"network_host","network_join":
			network_nick = coop.clean_nick(nickname_field.text)
			network_address = address_field.text.strip_edges()
			if id == "network_host": coop.host(network_nick)
			else: coop.join(network_address,network_nick)
			nickname_field.release_focus()
			address_field.release_focus()
			sync_network_fields()
		"network_start": coop.start_run()
		"network_back":
			coop.leave()
			screen = ""
			sync_network_fields()
		"stats": toggle_stats()
		"close_stats": close_stats()
		"start","retry":
			if coop.active:
				if coop.hosting: coop.start_run()
				return
			start_chapter(solo_chapter)
		"menu":
			collect_achievements()
			if coop.active:
				coop.leave()
				world = W.new()
			world = W.new()
			solo_chapter=1
			unload_end_assets()
			world.finale.reset()
			audio.set_finale_music(false)
			world.state = "MENU"
			screen = ""
		"resume":
			if coop.active: coop.command("pause",0)
			else: world.state = pause_from
		"pause":
			if coop.active: coop.command("pause",1)
			else:
				pause_from = world.state
				world.state = "PAUSED"
		"chest":
			if coop.active: coop.command("chest")
			elif world.chest_delay > 0: world.chest_delay = 0
			else: world.close_chest()
		"settings":
			screen = "settings"
		"back": screen = ""
		"quit": quit_game()
		"fullscreen":
			settings.fullscreen = not settings.fullscreen
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
			if not settings.fullscreen: get_window().size = Vector2i(1280,720)
			get_window().grab_focus()
		"shake","flashes","numbers": settings[id] = not settings[id]
		"music","effects":
			adjust_volume(id,.1)
	save_settings()
	selected = 0

func is_nether() -> bool:
	return not coop.active and world is NW and world.chapter_number()==2

func is_end() -> bool:
	return not coop.active and world is EW

func secret_input(event: InputEventKey) -> bool:
	if coop.active or screen=="multiplayer":secret_keys="";return false
	var code=event.physical_keycode if event.physical_keycode!=0 else event.keycode
	if Time.get_ticks_msec()-secret_key_time>3000:secret_keys=""
	secret_key_time=Time.get_ticks_msec()
	if code in [KEY_ENTER,KEY_KP_ENTER] and secret_keys=="davis":
		secret_keys=""
		if screen!="boss_lab":
			lab_state=world.state;lab_screen=screen;lab_chapter=solo_chapter
			world.state="PAUSED";screen="boss_lab";selected=3
		return true
	var letter: String={KEY_D:"d",KEY_A:"a",KEY_V:"v",KEY_I:"i",KEY_S:"s"}.get(code,"")
	var candidate=secret_keys+letter
	if not letter.is_empty() and "davis".begins_with(candidate):
		secret_keys=candidate
		return true
	secret_keys="d" if letter=="d" else ""
	return false

func close_boss_lab():
	world.state=lab_state;screen=lab_screen;selected=0;input_lock=.12

func draw_boss_lab():
	draw_rect(Rect2(0,0,640,360),Color.BLACK)
	text_at("Испытание босса",Vector2(22,29),16,INK,true)
	button(Rect2(510,13,108,22),"Назад","lab_back")
	button(Rect2(24,53,192,26),"I · Херобрин","lab_chapter_1")
	button(Rect2(224,53,192,26),"II · Иссушитель","lab_chapter_2")
	button(Rect2(424,53,192,26),"III · Край","lab_chapter_3")
	draw_line(Vector2(24+(lab_chapter-1)*200,82),Vector2(216+(lab_chapter-1)*200,82),INK,2)
	var presets=BossLab.presets(lab_chapter)
	for i in range(presets.size()):
		var p=Vector2(24+i%2*304,105+i/2*110)
		panel(Rect2(p,Vector2(288,96)))
		for j in range(presets[i].weapons.size()):item_icon(presets[i].weapons[j],p+Vector2(12+j*28,12),1,false,8)
		button(Rect2(p+Vector2(8,56),Vector2(272,30)),presets[i].name,"lab_build_"+str(i))

func start_chapter(chapter: int):
	if coop.active:return
	collect_achievements()
	solo_chapter=chapter
	if chapter==3:ensure_end_assets()
	else:unload_end_assets()
	world=EW.new() if chapter==3 else NW.new() if chapter==2 else W.new()
	world.reset()
	audio.reset_run_music()
	screen=""
	selected=0

func adjust_volume(id: String, delta: float):
	settings[id]=float(clampi(roundi(settings[id]*10)+roundi(delta*10),0,10))/10
	audio.update_volumes(settings.music,settings.effects)
	save_settings()

func toggle_inventory():
	if coop.active:return
	if screen=="inventory":close_inventory()
	elif screen.is_empty() and world.state in ["RUNNING","PAUSED","LEVEL_UP","CHEST","FINALE"]:
		inventory_from=world.state
		world.state="PAUSED"
		screen="inventory"
		selected=0
		input_lock=.12

func close_inventory():
	screen=""
	world.state=inventory_from
	selected=0
	input_lock=.12

func gear_title(id: String, evolution: bool = false, level: int = -1) -> String:
	if not coop.active and world.db.has_method("equipment_title"):
		return world.db.equipment_title(id,world.build.get(id,world.items.get(id,1)) if level<0 else level,evolution)
	return world.db.title(id,evolution)

func toggle_stats():
	if screen=="stats":
		close_stats()
	elif coop.active and coop.running and screen.is_empty() and world.run_state != "RESULT":
		stats_coop_was_paused = world.players[world.local_id].paused
		screen = "stats"
		coop.command("pause",1)
		selected = 0
		input_lock = .12
	elif screen.is_empty() and world.state in ["RUNNING","PAUSED","LEVEL_UP","CHEST","FINALE"]:
		stats_from = world.state
		screen = "stats"
		world.state = "PAUSED"
		selected = 0
		input_lock = 0.12

func close_stats():
	screen = ""
	if coop.active: coop.command("pause",1 if stats_coop_was_paused else 0)
	else: world.state = stats_from
	selected = 0
	input_lock = 0.12

func _draw():
	var began = Time.get_ticks_usec()
	draw_scene()
	achievements_view.toast(self)
	var end_power=0.0
	if is_end():
		if world.stage=="betrayal":end_power=sin(clampf(world.stage_age/6.4,0,1)*PI)*.9
		elif world.stage=="last_arrival":end_power=.55*(1-smoothstep(2,3.2,world.stage_age))
		elif world.stage=="last_duel":
			for boss in world.mobs:
				if boss.kind=="endersteve_final" and boss.phase=="rage":end_power=sin(clampf(1-boss.timer/1.6,0,1)*PI)*.45
		elif world.stage=="endsteve_death":end_power=.7*sin(smoothstep(1.7,7.1,world.stage_age)*PI)
		elif world.stage=="rekindle":end_power=sin(clampf(world.stage_age/2.8,0,1)*PI)*.35
	var end_focus=world.endsteve_corpse.p-Vector2(0,20) if is_end() and world.stage=="endsteve_death" else world.portal_position if is_end() else Vector2.ZERO
	end_rift.configure(end_power>0 and screen.is_empty() and world.state=="RUNNING",end_focus+Vector2(320,180)-world.camera() if is_end() else Vector2.ZERO,end_power,world.clock)
	var duel=world.finale.has_method("blood_progress")
	var enabled=duel and world.finale.phase in ["rift","vanish"] and world.state=="FINALE" and screen.is_empty()
	blood_rift.configure(enabled,world.player+Vector2(320,172)-world.camera(),world.finale.blood_progress() if duel else 0,world.clock,world.finale.blood_wipe() if duel else 0)
	coop.diagnostics.measure("draw_cpu_ms",(Time.get_ticks_usec()-began)/1000.0)

func draw_scene():
	buttons.clear()
	if screen=="achievements":
		achievements_view.screen(self);return
	if screen=="boss_lab":
		draw_boss_lab()
		return
	if screen=="recipes":
		draw_recipe_book()
		return
	if screen=="inventory":
		draw_inventory()
		return
	if is_nether() and world.stage=="crossing":
		nether_renderer.ending(self,false)
		if world.state=="PAUSED":draw_pause()
		return
	if is_end() and world.stage=="chapter_four":
		end_renderer.ending(self)
		return
	if is_nether() and world.stage=="end":
		nether_renderer.ending(self)
		return
	if screen=="stats":
		draw_stats()
		return
	if world.state=="RESULT" and world.finale.complete:
		finale_renderer.ending(self)
		return
	draw_world()
	if world.state != "MENU" and (not world.finale.active or world.finale.phase in ["storm","inferno"]) and (not is_nether() or world.stage in ["survival","wither","portal"]) and (not is_end() or world.stage in ["survival","dragon","last_duel","exit_portal","hand","return_portal","portal_ready"]):draw_hud()
	if screen=="chapters":draw_chapters()
	elif screen == "multiplayer": draw_multiplayer()
	elif not screen.is_empty(): draw_settings()
	elif world.state == "MENU": draw_menu()
	elif world.state == "LEVEL_UP": draw_level_up()
	elif world.state == "PAUSED": draw_pause()
	elif world.state == "CHEST": draw_chest()
	elif world.state == "RESULT": draw_result()
	elif world.state == "WAITING": draw_network_wait()
	if coop.network_waiting():
		draw_rect(Rect2(206,70,228,24),Color(0,0,0,.8))
		centered("Ожидание сети…",86,8,MUTED)

func pixel_font_size(size: int) -> int:
	return maxi(8,int(round(float(size)/8))*8)

func text_at(value: String, p: Vector2, size: int = 10, color: Color = INK, heavy: bool = false):
	var f = bold if heavy else font
	var actual = pixel_font_size(size)
	draw_string(f,p.round()+Vector2.ONE*(actual/8),value,HORIZONTAL_ALIGNMENT_LEFT,-1,actual,Color(0,0,0,color.a))
	draw_string(f,p.round(),value,HORIZONTAL_ALIGNMENT_LEFT,-1,actual,color)

func centered(value: String, y: float, size: int = 12, color: Color = INK, heavy: bool = false):
	var f = bold if heavy else font
	text_at(value,Vector2((640-f.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,pixel_font_size(size)).x)/2,y),size,color,heavy)

func panel(rect: Rect2, color: Color = Color("242424"), border: Color = Color("777777")):
	# Shared monochrome window frame, including legacy callers' color inputs.
	draw_rect(rect,Color.BLACK)
	draw_rect(rect.grow(-1),Color(0.14,0.14,0.14,color.a))
	draw_rect(rect.grow(-1),Color("777777"),false,1)
	draw_line(rect.position+Vector2(2,2),rect.position+Vector2(rect.size.x-3,2),Color("aaaaaa"))

func button(rect: Rect2, label: String, id: String):
	var index = buttons.size()
	buttons.append({"rect":rect,"id":id})
	var active = selected == index
	draw_style_box(button_styles[1 if active else 0],rect)
	var size = 8
	var tw = bold.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	text_at(label,rect.position+Vector2((rect.size.x-tw)/2,rect.size.y/2+3),size,INK,true)

func sprite(name: String, p: Vector2, size: Vector2 = Vector2.ZERO, tint: Color = Color.WHITE):
	if not textures.has(name): return
	var tex: Texture2D = textures[name]
	if size == Vector2.ZERO: size = tex.get_size()
	draw_texture_rect(tex,Rect2(p,size),false,tint)

func item_icon(id: String, p: Vector2, scale_factor: float = 1.0, evolution: bool = false, equipment_level: int = -1):
	var name: String = world.db.icon(id,evolution)
	if not coop.active and world.db.has_method("equipment_icon"):
		name=world.db.equipment_icon(id,world.build.get(id,world.items.get(id,1)) if equipment_level<0 else equipment_level,evolution)
	if name in ["netherite","flamebow","channeling"] or (evolution and minecraft_assets.clips.has(name+"_enchanted")):
		draw_clip(name+"_enchanted",p,Vector2.ONE*16*scale_factor,item_time())
	else: sprite("icon_"+name,p,Vector2.ONE*16*scale_factor)

func item_time() -> float:
	# Menus have no simulation. All in-run visuals use its paused clock.
	return ui_time if world.state=="MENU" else world.clock

func clip_frame(name: String, time: float, looping: bool = true) -> int:
	var clip: Dictionary = minecraft_assets.clips[name]
	var total: float = clip.total
	if clip.uniform:
		var frame_index = int((maxf(0,time)+0.000001)/float(clip.durations[0]))
		return int(clip.frames[frame_index%clip.frames.size() if looping else mini(clip.frames.size()-1,frame_index)])
	var remaining = fposmod(maxf(0,time),total) if looping else clampf(time,0,total)
	for i in range(clip.frames.size()):
		if remaining < float(clip.durations[i]): return int(clip.frames[i])
		remaining -= float(clip.durations[i])
	return int(clip.frames.back())

func draw_clip(name: String, p: Vector2, size: Vector2, time: float, tint: Color = Color.WHITE, looping: bool = true):
	if not textures.has(name):return
	var frame_size = Vector2(minecraft_assets.clips[name].frame_size[0],minecraft_assets.clips[name].frame_size[1])
	draw_texture_rect_region(textures[name],Rect2(p,size),Rect2(Vector2(clip_frame(name,time,looping)*frame_size.x,0),frame_size),tint)

func draw_world():
	if is_end():end_renderer.world(self);return
	var saved_actor = 0
	if coop.active and coop.running:
		saved_actor = world.active_id
		world.use_actor(network_view_id())
	var cam = world.camera()
	if world.state == "MENU": cam = Vector2(1024+sin(ui_time*0.06)*32,1024+cos(ui_time*0.08)*24)
	var offset = Vector2(320,180)-cam.floor()
	if world.shake > 0 and settings.shake and world.state in ["RUNNING","FINALE"]: offset += Vector2(sin(world.clock*75),cos(world.clock*87)).round()*1.5
	if is_nether():nether_renderer.ground(self,offset)
	elif textures.has("ground"):
		draw_texture_rect_region(textures.ground,Rect2(Vector2.ZERO,Vector2(640,360)),Rect2(cam-Vector2(320,180),Vector2(640,360)))
	else: draw_rect(Rect2(0,0,640,360),Color("40563a"))
	if world.finale.active:
		draw_texture_rect_region(textures.ground_scorched,Rect2(0,0,640,360),Rect2(cam-Vector2(320,180),Vector2(640,360)),Color(1,1,1,world.finale.scorch()))
	# Short rail fence and dense forest at the edge of a finite arena.
	for side in range(4):
		for j in range(64):
			var p = Vector2(24+j*32,22) if side == 0 else (Vector2(24+j*32,2026) if side == 1 else (Vector2(22,24+j*32) if side == 2 else Vector2(2026,24+j*32)))
			var s = p + offset
			if not Rect2(-40,-60,720,480).has_point(s): continue
			if is_nether():
				sprite("nether_pillar_"+str(j%3),s-Vector2(32,50))
				continue
			sprite(("tree_dead_" if world.finale.active and world.finale.scorch()>.2 else "tree_")+str(j%3),s-Vector2(32,50))
			draw_line(s+Vector2(-16,-1),s+Vector2(16,-1),Color("9b8758"),3)
			draw_line(s+Vector2(-16,3),s+Vector2(16,3),Color("6f603f"),2)
			draw_rect(Rect2(s+Vector2(-2,-7),Vector2(4,13)),Color("b09a68"))
	if is_nether():nether_renderer.floor_effects(self,offset)
	for o in world.orbs:
		var p: Vector2 = o.p+offset
		if not Rect2(-8,-8,656,376).has_point(p): continue
		var frame = 0 if o.value<5 else (3 if o.value<30 else 6)
		var pulse = 0.78+0.22*sin(world.clock*5+o.p.x)
		oval(p,Vector2(4,2),Color(0.3,0.8,0.2,0.12*pulse))
		draw_texture_rect_region(textures.experience_orb,Rect2((p-Vector2(4,5)).floor(),Vector2(8,8)),Rect2((frame%4)*16,(frame/4)*16,16,16),Color(0.45+0.25*pulse,1,0.2,1))
	for e in world.effects:
		if e.kind in ["cloud","fangs","player_hit"]: draw_effect(e,offset)
	if world.finale.active:finale_renderer.floor_effects(self,offset)
	for m in world.mobs:
		var p: Vector2 = m.p+offset
		if m.kind == "ravager" and m.phase == "windup":
			var dir: Vector2 = m.charge
			var edge = dir.orthogonal()*23
			draw_colored_polygon(PackedVector2Array([p-edge,p+edge,p+dir*160+edge,p+dir*160-edge]),Color(0.93,0.6,0.4,0.14))
			draw_line(p-edge,p+dir*160-edge,Color("deab76"),1)
			draw_line(p+edge,p+dir*160+edge,Color("deab76"),1)
	var actors: Array = []
	if world.finale.active:actors.append({"sort":world.finale.CENTER.y+18,"kind":"throne"})
	for obj in world.props:
		if obj.type == "pumpkin" and obj.hp <= 0: continue
		if world.finale.active and world.finale.scorch()>.65 and obj.type in ["flowers","pumpkin","stump"]:continue
		if Rect2(-80,-80,800,540).has_point(obj.p+offset): actors.append({"sort":obj.p.y,"kind":"prop","obj":obj})
	for m in world.mobs:
		if Rect2(-140,-140,920,640).has_point(m.p+offset): actors.append({"sort":m.p.y,"kind":"mob","obj":m})
	if coop.active and (coop.running or coop.loading):
		world.save_actor()
		for a in world.players.values():
			if a.alive or a.in_finale: actors.append({"sort":a.player.y,"kind":"coop_player","id":a.id})
	elif world.state!="MENU":actors.append({"sort":world.player.y,"kind":"player"})
	for o in world.loot:
		if Rect2(-20,-20,680,400).has_point(o.p+offset): actors.append({"sort":o.p.y,"kind":"loot","obj":o})
	actors.sort_custom(func(a,b): return a.sort < b.sort)
	for actor in actors:
		if actor.kind=="throne":
			finale_renderer.stage(self,offset)
		elif actor.kind == "prop":
			var obj = actor.obj
			var p: Vector2 = obj.p+offset
			var name = obj.type
			var size = Vector2(24,24)
			if obj.type == "tree":
				name = ("tree_dead_" if world.finale.active and world.finale.scorch()>float(obj.id%8)/12 else "tree_")+str(obj.id%3)
				size = Vector2(64,72)
			elif obj.type == "rock": size = Vector2(32,32)
			elif obj.type == "flowers": size = Vector2(16,16)
			if is_nether():
				if obj.type=="tree":name="nether_pillar_"+str(obj.id%3)
				elif obj.type=="rock":name="nether_rock"
				elif obj.type=="pumpkin":name="nether_pot";size=Vector2(24,28)
			oval(p,Vector2(18,5) if obj.type == "tree" else Vector2(10,3),Color(0.08,0.16,0.12,0.3))
			var alpha = 0.42 if obj.type == "tree" and abs(world.player.x-obj.p.x)<30 and world.player.y<obj.p.y and world.player.y>obj.p.y-60 else 1.0
			sprite(name,p-Vector2(size.x/2,size.y-5),size,Color(1,1,1,alpha))
		elif actor.kind == "coop_player":
			var previous = world.active_id
			world.use_actor(actor.id)
			if world.finale.active and world.finale.elapsed >= 24: finale_renderer.player(self,world.player+offset)
			else:
				draw_actor("steve",world.player+offset,world.facing,world.clock,world.player_moving,invulnerable_tint(),"walk",1.0,world.player_visual)
				draw_held_weapons(world.player+offset)
			if not world.finale.active or world.finale.elapsed < 24:
				draw_nickname(world.players[actor.id].nick,world.player+offset)
			world.use_actor(previous)
		elif actor.kind == "player":
			if is_nether() and nether_renderer.player(self,offset):pass
			elif world.finale.active and (world.finale.cinematic_player() if world.finale.has_method("cinematic_player") else world.finale.elapsed>=24):
				finale_renderer.player(self,world.player+offset)
			else:
				draw_actor("steve",world.player+offset,world.facing,world.clock,world.player_moving,invulnerable_tint(),"walk",1.0,world.player_visual)
				draw_held_weapons(world.player+offset)
		elif actor.kind == "mob":
			var m = actor.obj
			if m.kind=="herobrine":continue
			var tint = Color.WHITE
			if settings.flashes and (m.flash>0 or (m.kind=="creeper" and m.fuse>=0 and fmod(world.clock,0.16)<0.08)): tint = Color(1.8,1.8,1.8)
			if is_nether() and m.kind=="wither":nether_renderer.boss(self,m,offset)
			else:draw_actor(m.kind,m.p+offset,m.visual_dir,m.animation,m.moving,tint,m.phase,1.0,m.visual)
			if m.kind=="skeleton" and m.visual.state in ["windup","attack","recover"]:
				var aim:Vector2=m.visual_dir
				draw_bow(m.p+offset+aim*8+Vector2(0,-10),aim,clampf(m.visual.time/0.5,0,1) if m.visual.state=="windup" else 0)

			if m.burn>0:
				draw_clip("fire_animation",(m.p+offset-Vector2(9,19)).floor(),Vector2(18,21),world.clock+m.id*0.03,Color(1,1,1,0.85))
			if m.kind in ["elite","ravager"]:
				var p: Vector2=m.p+offset+Vector2(-15,-40 if m.kind=="ravager" else -35)
				draw_rect(Rect2(p,Vector2(30,3)),Color("26342b"))
				draw_rect(Rect2(p,Vector2(30*maxf(0,m.hp)/m.max_hp,2)),GOLD)
		else:
			var o = actor.obj
			var p: Vector2=o.p+offset
			if o.kind == "chest":
				oval(p,Vector2(12,4),Color(0.84,0.69,0.3,0.18))
				draw_line(p+Vector2(0,-22),p+Vector2(0,-30),GOLD,1)
			var bob = sin(world.clock*3+o.p.x*0.1)*2
			oval(p,Vector2(6,2),Color(0.04,0.1,0.05,0.3))
			# The vanilla ground-item turn is a transform of the original pixels.
			var turn = cos(world.clock*1.6+o.p.x*0.1)
			draw_set_transform((p-Vector2(0,8+bob)).floor(),0,Vector2(signf(turn)*maxf(0.18,absf(turn)),1))
			item_icon(o.kind,Vector2(-8,-8))
			draw_set_transform(Vector2.ZERO)
	for b in world.projectiles: draw_projectile(b,offset)
	for e in world.effects:
		if e.kind not in ["cloud","fangs","player_hit"]: draw_effect(e,offset)
	for pool in [world.particles,world.pixels]:
		for particle in pool:
			var size: float = particle.get("size",2.0)*clampf(particle.life/0.1,0.3,1)
			draw_rect(Rect2((particle.p+offset).floor(),Vector2.ONE*ceilf(size)),Color(particle.color,clampf(particle.life/0.1,0,1)))
	# A quiet uniform night tint keeps warnings and XP clearly separated from grass.
	var dusk = 0.09 * (1-clampf((world.time-660)/60,0,1))
	draw_rect(Rect2(0,0,640,360),Color(0.05,0.12,0.16,dusk))
	for m in world.mobs:
		if m.kind not in ["elite","ravager"] or world.visible(m.p,0): continue
		var dir = world.camera().direction_to(m.p)
		var p = Vector2(320,180)+dir*Vector2(292,134)
		draw_colored_polygon(PackedVector2Array([p+dir*7,p-dir*4+dir.orthogonal()*5,p-dir*4-dir.orthogonal()*5]),GOLD)
	if is_nether():nether_renderer.foreground(self,offset)
	if world.finale.active:finale_renderer.foreground(self,offset)
	if saved_actor: world.use_actor(saved_actor)

func network_view_id() -> int:
	var id: int = world.local_id
	if world.players[id].alive or world.players[id].in_finale: return id
	for a in world.players.values():
		if a.alive or a.in_finale: return a.id
	return id

func draw_nickname(value: String, at: Vector2):
	var width = font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,8).x
	var p = (at+Vector2(-width/2,-36)).floor()
	draw_rect(Rect2(p+Vector2(-2,-8),Vector2(width+4,11)),Color(0,0,0,.55))
	text_at(value,p,8,INK)

func invulnerable_tint() -> Color:
	return Color(1,0.65,0.55,0.65) if settings.flashes and world.invulnerable>0 and fmod(world.clock,0.14)<0.07 else Color.WHITE

func oval(p: Vector2, size: Vector2, color: Color):
	draw_set_transform(p,0,size)
	draw_circle(Vector2.ZERO,1,color)
	draw_set_transform(Vector2.ZERO)

func draw_actor(kind: String, p: Vector2, dir: Vector2, anim: float, moving: bool, tint: Color, phase: String = "walk", actor_scale: float = 1.0, visual: Dictionary = {}):
	var small = kind == "small_slime"
	if kind == "small_slime": kind = "slime"
	var size = Vector2(32,32)
	if kind == "spider": size = Vector2(48,32)
	if kind == "ravager": size = Vector2(64,64)
	if kind in ["hoglin","zoglin"]:size=Vector2(48,48)
	if world.animation.data.actors.has(kind):
		var meta=world.animation.data.actors[kind]
		size=Vector2(meta.frame_size[0],meta.frame_size[1])
	var name=kind+"_atlas"
	var frame = world.animation.frame(kind,visual.get("state","walk" if moving else "idle"),visual.get("time",anim)) if world.animation.data.actors.has(kind) else (2+int(anim*7)%4)
	var row = world.animation.direction_row(dir)
	var flip = dir.x<0 and row==2
	var shadow_size=Vector2(size.x*0.24,3 if kind!="ravager" else 6)
	if world.animation.data.actors.get(kind,{}).has("shadow_size"):
		var shadow=world.animation.data.actors[kind].shadow_size
		shadow_size=Vector2(shadow[0],shadow[1])
	oval(p+Vector2(0,1),shadow_size,Color(0.06,0.12,0.1,0.4))
	var actor_anchor=Vector2(size.x/2,size.y-3)
	if world.animation.data.actors.has(kind) and world.animation.data.actors[kind].has("anchor"):
		var anchor=world.animation.data.actors[kind].anchor;actor_anchor=Vector2(anchor[0],anchor[1])
	var display_size = size * actor_scale * (0.5 if small else (1.25 if kind=="elite" else 1.0))
	var display_anchor=Vector2(display_size.x/2,display_size.y-3)
	if world.animation.data.actors.has(kind) and world.animation.data.actors[kind].has("anchor"):display_anchor=actor_anchor*actor_scale
	var dest = Rect2(p-display_anchor,display_size)
	if textures.has(name):
		if flip:
			draw_set_transform(p,0,Vector2(-1,1))
			dest.position = -display_anchor
		if moving and kind in ["steve","zombie","elite","skeleton"] and visual.get("state","") in ["windup","attack","recover","hurt"]:
			# Keep the eight-step legs underneath the acting upper body while moving.
			var gait_frame=world.animation.frame(kind,"walk",visual.get("gait",0.0))
			var upper=Rect2(dest.position,Vector2(dest.size.x,dest.size.y*0.75))
			var lower=Rect2(dest.position+Vector2(0,dest.size.y*0.75),Vector2(dest.size.x,dest.size.y*0.25))
			draw_texture_rect_region(textures[name],upper,Rect2(frame*32,row*32,32,24),tint)
			draw_texture_rect_region(textures[name],lower,Rect2(gait_frame*32,row*32+24,32,8),tint)
		else:draw_texture_rect_region(textures[name],dest,Rect2(Vector2(frame*size.x,row*size.y),size),tint)
		if flip: draw_set_transform(Vector2.ZERO)
	else:
		# Import failures remain visibly diagnosable rather than crashing a run.
		draw_rect(Rect2(p-Vector2(7,22),Vector2(14,21)),Color("59a899") if kind=="steve" else Color("7da256"))

func draw_bow(p: Vector2, aim: Vector2, draw_amount: float, flame: bool = false):
	var frame = 0 if draw_amount<=0 else mini(3,1+int(draw_amount*3))
	draw_set_transform(p.floor(),aim.angle()+PI/4)
	if flame:
		var glint_frame = clip_frame("flamebow_enchanted",item_time())
		draw_texture_rect_region(textures.flamebow_draw,Rect2(-8,-8,16,16),Rect2(glint_frame*16,frame*16,16,16))
	else:
		draw_texture_rect_region(textures.bow_draw,Rect2(-8,-8,16,16),Rect2(frame*16,0,16,16))
	draw_set_transform(Vector2.ZERO)

func draw_held_weapons(p: Vector2):
	for id in world.weapon_visuals:
		if id=="axe" and is_nether() and world.effects.any(func(e):return e.kind=="axe_spin"):continue
		var pose: Dictionary = world.weapon_visuals[id]
		if id!="fangs" and id!=world.player_visual.get("weapon",""):continue
		if id=="sword" and pose.state!="windup": continue
		var aim: Vector2 = pose.dir
		var hand_side=-1 if world.facing.x<0 else 1
		var q = p+Vector2(hand_side*5,-8)+Vector2(aim.x,aim.y*0.4)*7
		var progress: float = pose.progress
		if id=="bow":
			draw_bow(q,aim,progress if pose.state=="windup" else 0,world.evolved.has(id))
			continue
		if id=="fangs":
			if pose.state=="windup":
				var stats = world.db.stats(id,world.build[id],false,world.items)
				for j in range(int(stats.count)):
					var point = p+aim*(20+j*20)
					draw_line(point-aim.orthogonal()*4,point+aim.orthogonal()*4,Color(0.73,0.64,0.39,0.35),1)
					if progress>0.6: draw_rect(Rect2(point-Vector2(1,2),Vector2(2,2)),Color("b6b494"))
			continue
		var rotation = aim.angle()+PI/4
		if id=="sword":
			rotation -= 1.4+progress*0.5
			q -= aim*3
		elif id=="trident": q -= aim*progress*6
		elif id=="potion":
			q -= aim*progress*5
			q.y -= progress*4
			rotation = -progress*0.6
		elif id=="fire":
			draw_clip("fire_animation",q-Vector2(8,13),Vector2(16,16),world.clock,Color(1,1,1,0.7))
			rotation = -progress*0.4
		draw_set_transform(q,rotation)
		item_icon(id,Vector2(-8,-8),1,world.evolved.has(id))
		draw_set_transform(Vector2.ZERO)

func draw_projectile(b: Dictionary, offset: Vector2):
	var p: Vector2=b.p+offset+Vector2(0,-9)
	if not Rect2(-30,-30,700,420).has_point(p):return
	if is_nether() and nether_renderer.projectile(self,b,offset):return
	var tick = int(b.age*24)
	if b.kind=="fire":
		for j in range(5):
			var q=p-b.dir*(5+j*3)+b.dir.orthogonal()*sin(tick+j*2)*2
			var sz=12-j*1.5
			draw_clip("fire_animation",(q-Vector2.ONE*sz/2).floor(),Vector2.ONE*sz,b.age+j*0.06,Color(1,1,1,1-j*0.15))
		item_icon("fire",p-Vector2(8,8))
	elif b.kind=="trident":
		var col=Color("c7b878") if b.returning else Color("6caca8")
		for j in range(3):
			var q=p-b.dir*(6+j*5)
			draw_rect(Rect2(q.floor(),Vector2(2,2)),Color(col,0.6-j*0.15))
		if b.returning and b.turn_age<0.13: draw_arc(p,7,0,TAU,12,Color(col,0.7),1)
		draw_set_transform(p,b.dir.angle()+PI/4)
		item_icon("trident",Vector2(-8,-8),1,b.evolved)
		draw_set_transform(Vector2.ZERO)
	else:
		if b.evolved:
			for j in range(4):
				var q=p-b.dir*(4+j*3)+b.dir.orthogonal()*((tick+j)%3-1)
				draw_clip("fire_animation",(q-Vector2(4,5)).floor(),Vector2(8,10),b.age+j*0.04,Color(1,1,1,1-j*0.2))
		draw_set_transform(p.floor(),b.dir.angle()+PI/4)
		sprite("icon_arrow",Vector2(-8,-8),Vector2(16,16))
		draw_set_transform(Vector2.ZERO)

func draw_effect(e: Dictionary, offset: Vector2):
	var p: Vector2=e.p+offset
	if not Rect2(-150,-150,940,660).has_point(p):return
	if is_nether() and nether_renderer.effect(self,e,offset):return
	var progress=clampf(e.age/e.total,0,1)
	match e.kind:
		"vindicator_slash":
			draw_set_transform(p+Vector2(0,-9)+e.direction*16,e.direction.angle()+PI/2)
			draw_clip("sweep_animation",Vector2(-20,-14),Vector2(40,28),e.age,Color.WHITE,false)
			draw_set_transform(Vector2.ZERO)
		"swing":
			p.y-=9
			var angle: float=e.direction.angle()
			var color=Color("d9dcc2") if not e.evolved else Color("b09abc")
			# The complete contact sector is visible on the damage tick. A 70ms trail
			# follows; the remaining lifetime is the hand/blade settling back.
			if e.age<0.2:
				draw_set_transform(p+e.direction*e.radius*0.5,angle+PI/2)
				draw_clip("sweep_animation",Vector2(-e.radius*0.65,-e.radius*0.45),Vector2(e.radius*1.3,e.radius*0.9),e.age,Color(1,1,1,0.8 if settings.flashes else 0.4),false)
				draw_set_transform(Vector2.ZERO)
			var a=angle+PI/3+progress*0.25
			var hand_origin=p.lerp(world.player+offset+Vector2(0,-9),smoothstep(0.25,1.0,progress))
			var blade_pos=hand_origin+Vector2.from_angle(a)*lerpf(e.radius*0.65,13,progress)
			draw_set_transform(blade_pos,a+PI/4+progress*0.4)
			item_icon("sword",Vector2(-8,-8),1,e.evolved)
			draw_set_transform(Vector2.ZERO)
		"cloud":
			var fade=clampf(e.life/0.4,0,1)
			for i in range(5):
				var q=p+Vector2.from_angle(i*TAU/5+0.1*sin(e.age))*e.radius*0.46
				draw_circle(q,e.radius*0.49,Color(0.5,0.66,0.31,0.075*fade))
			for i in range(10):
				var phase=fposmod(e.age*0.6+i*0.17,1)
				var q=p+Vector2.from_angle(i*2.399)*e.radius*(0.3+phase*0.5)-Vector2(0,phase*5)
				draw_clip("poison_animation",q.floor()-Vector2(4,4),Vector2(8,8),e.age+i*0.08,Color(0.53,0.64,0.39,(1-phase)*0.7*fade))
		"explosion","enemy_explosion":
			if e.kind=="enemy_explosion" and e.age<0.065:
				draw_actor("creeper",p,e.get("direction",Vector2.DOWN),0,false,Color(1.3,1.3,1.3) if settings.flashes else Color.WHITE,"attack",1.0,{"state":"attack","time":e.age})
			draw_clip("explosion_animation",p-Vector2.ONE*e.radius,Vector2.ONE*e.radius*2,progress*0.399,Color(1,1,1,0.9 if settings.flashes else 0.45),false)
		"bottle":
			var ground:Vector2=p.lerp(e.end+offset,progress)
			oval(ground,Vector2(4,2),Color(0.05,0.13,0.1,0.3))
			var q=ground-Vector2(0,sin(progress*PI)*28)
			q.y-=9*(1-progress)
			draw_set_transform(q,progress*TAU)
			sprite("icon_splash_potion",Vector2(-8,-8),Vector2(16,16))
			draw_set_transform(Vector2.ZERO)
		"fangs":
			var age:float=e.age-e.delay
			if age<0:
				oval(p,Vector2(e.radius,3),Color(0.7,0.64,0.42,0.23))
				if age< -0.08:return
			var height=12.0
			if age<0:height=12*(1+age/0.08)
			elif age>0.1:
				# The old hit window lasts 0.65s: teeth must remain visible to late
				# entrants, then sink during its final 0.1s without moving damage.
				height=lerpf(12,6,clampf((age-0.1)/0.45,0,1))
				if age>0.55:height=6*(1-clampf((age-0.55)/0.1,0,1))
			oval(p,Vector2(e.radius,3),Color("2c342b"))
			var display_height = maxf(1,height*2)
			draw_clip("fangs_animation",(p-Vector2(16,display_height-2)).floor(),Vector2(32,display_height),maxf(0,age),Color.WHITE,false)
		"lightning":
			var alpha=(1-progress)*(0.95 if settings.flashes else 0.4)
			var points=PackedVector2Array([p-Vector2(0,90),p-Vector2(9,58),p+Vector2(5,-32),p])
			draw_polyline(points,Color(0.3,0.62,0.66,alpha*0.6),5)
			draw_polyline(points,Color(0.86,0.9,0.73,alpha),2)
			for j in range(6):
				var dir=Vector2.from_angle(j*TAU/6)
				draw_line(p+dir*5,p+dir*e.radius*progress,Color(0.66,0.79,0.73,alpha),1)
		"damage":
			if settings.numbers:text_at(str(e.amount),p+Vector2(-4,-progress*13),8,Color("eddda9"),true)
		"player_hit":pass
		"break":
			for j in range(5):draw_rect(Rect2(p+Vector2.from_angle(j*TAU/5)*progress*15,Vector2(3,3)),Color("c89850"))

func draw_hud():
	# Vanilla-sized health and experience sit above the two equipment bars.
	var origin = Vector2(192 if coop.active else 172,332)
	for i in range(10):
		var p=origin+Vector2(i*8,-22)
		sprite("heart_empty",p)
		var health=clampf(ceilf(world.hp)-i*2,0,2)
		var blink = settings.flashes and world.invulnerable>0 and fmod(world.clock,0.2)<0.1
		var withered=is_nether() and world.player_wither>0
		if health==2:sprite(("heart_wither_blink" if blink else "heart_wither") if withered else ("heart_blink" if blink else "heart"),p)
		elif health==1:sprite(("heart_wither_half_blink" if blink else "heart_wither_half") if withered else ("heart_half_blink" if blink else "heart_half"),p)
	centered(format_time(world.time),24,16,INK,true)
	text_at("Убийств: %d" % world.kills,Vector2(12,16),8,INK)
	if coop.active:text_at("Изумруды: %d" % world.score,Vector2(12,29),8,MUTED)
	else:text_at("Глава III · Край" if is_end() else "Глава II · Незер" if is_nether() else "Глава I · Верхний мир",Vector2(12,29),8,MUTED)
	if coop.active and coop.running:
		var row = 0
		for a in world.players.values():
			if a.id == world.local_id: continue
			text_at(a.nick+"  "+("%d / 20" % maxi(0,ceili(a.hp)) if a.alive else "Погиб"),Vector2(12,43+row*12),8,MUTED)
			row += 1
		if not world.players[world.local_id].alive and not world.finale.active:
			centered("Наблюдение: "+world.players[network_view_id()].nick,291,8,MUTED)
	if world.state in ["RUNNING","FINALE","SPECTATING"]:
		buttons.append({"rect":Rect2(572,8,58,20),"id":"pause"})
		text_at("Пауза",Vector2(586,20),8,INK)
		buttons.append({"rect":Rect2(370,305,80,18),"id":"stats"})
	text_at("Статы",Vector2(406,317),8,MUTED)
	if not coop.active:
		text_at("Инвентарь",Vector2(464,317),8,MUTED)
		buttons.append({"rect":Rect2(462,305,90,18),"id":"inventory"})
	var ratio=clampf(float(world.xp)/world.db.required_xp(world.level),0,1)
	var xp_width=256 if coop.active else 296
	sprite("hud_xp_empty",origin+Vector2(0,-9),Vector2(xp_width,5))
	if ratio>0:
		draw_texture_rect_region(textures.hud_xp_full,Rect2(origin+Vector2(0,-9),Vector2(floorf(xp_width*ratio),5)),Rect2(0,0,floorf(182*ratio),5))
	centered(str(world.level),318,8,Color("80ff20"))
	for row in range(2):
		var collection=world.build if row==0 else world.items
		var ids=collection.keys()
		var x0=(192 if row==0 else 326) if coop.active else (172 if row==0 else 306)
		sprite("hud_eight_slots" if row==1 and not coop.active else "hud_six_slots",Vector2(x0,332))
		for i in range(8 if row==1 and not coop.active else 6):
			var p=Vector2(x0+3+i*20,335)
			if i<ids.size():
				var id=ids[i]
				if row==0 and id==world.player_visual.get("weapon","sword"):
					sprite("hud_selection",Vector2(x0-1+i*20,331))
				item_icon(id,p,1,world.evolved.has(id))
				if row==0 and not coop.active:
					var interval: float=world.db.stats(id,collection[id],world.evolved.has(id),world.items).interval
					var left: float=clampf(world.cooldowns.get(id,0.0)/maxf(.01,interval),0,1)
					if left>0:
						var height=ceilf(16*left)
						draw_rect(Rect2(p+Vector2(0,16-height),Vector2(16,height)),Color(1,1,1,.43))
						draw_line(p+Vector2(0,16-height),p+Vector2(16,16-height),Color(1,1,1,.8),1)
				var level_text = str(collection[id])
				text_at(level_text,p+Vector2(17-font.get_string_size(level_text,HORIZONTAL_ALIGNMENT_LEFT,-1,8).x,17),8,INK)
	if is_end():end_renderer.hud(self)
	if is_nether():nether_renderer.hud(self)
	if world.message_timer>0 and world.state=="RUNNING" and (not is_nether() or world.stage!="wither"):
		centered(world.message,68,12,GOLD,true)
	for m in world.mobs:
		if m.kind!="ravager" or m.hp<=0:continue
		draw_rect(Rect2(229,46,182,5),Color("333333"))
		draw_rect(Rect2(229,46,182*maxf(0,m.hp)/m.max_hp,5),Color("a92c2c"))
		centered("Разоритель",41,8,INK)

func character_stats() -> Dictionary:
	var result = {
		"Здоровье":"%s / %d" % [world.db.number(maxf(0,world.hp)),world.db.data.player_hp],
		"Скорость":"%s пикс/с" % world.db.number(world.movement_speed() if world.has_method("movement_speed") else world.db.data.player_speed*(1+0.08*world.items.get("sugar",0))),
		"Бонус урона":"+%d%%" % (world.items.get("blaze",0)*10),
		"Интервал атак":"-%d%%" % (world.items.get("redstone",0)*6),
		"Размер атак":"+%d%%" % (world.items.get("amethyst",0)*10),
		"Защита":"-%s HP за удар" % world.db.number(0.2*world.items.get("armor",0)),
		"Сбор опыта":"%s пикс" % world.db.number(24*(1+0.3*world.items.get("hopper",0))),
		"Опыт":"%d / %d (ур. %d)" % [world.xp,world.db.required_xp(world.level),world.level]
	}

	if is_nether():
		result["Огонь / иссушение"]="−%d%%" % (world.items.get("fire_resist",0)*16)
		result["Регенерация"]="%s HP / 5 с" % world.db.number(.3*world.items.get("ghast_tear",0))
		result["Притяжение"]="+%d%%" % (world.items.get("feather",0)*12)
		result["Песок душ"]="−%d%% штрафа" % (world.items.get("gold_boots",0)*20)
	return result

func draw_stats():
	draw_rect(Rect2(0,0,640,360),Color.BLACK)
	text_at("Характеристики",Vector2(22,31),16,INK,true)
	button(Rect2(510,13,108,22),"Готово","close_stats")
	draw_line(Vector2(22,59),Vector2(618,59),Color("555555"))
	draw_actor("steve",Vector2(48,112),world.facing,world.clock,false,Color.WHITE,"idle",1.5,{"state":"idle","time":0.0})
	text_at("Уровень %d" % world.level,Vector2(83,83),8,INK,true)
	text_at("Убийств: %d" % world.kills,Vector2(83,97),8,MUTED)
	if coop.active:text_at("Изумрудных очков: %d" % world.score,Vector2(83,111),8,MUTED)
	var stats = character_stats()
	var index = 0
	for label in stats:
		var y = 125+index*(12 if is_nether() else 15)
		text_at(label,Vector2(24,y),8,MUTED)
		text_at(stats[label],Vector2(134,y),8,INK)
		index += 1
	draw_line(Vector2(282,74),Vector2(282,255),Color("333333"))
	text_at("Оружие",Vector2(300,83),8,INK,true)
	index = 0
	for id in world.build:
		var y = 100+index*26
		var evolved: bool = world.evolved.has(id)
		var s = world.db.stats(id,world.build[id],evolved,world.items)
		item_icon(id,Vector2(300,y),1,evolved)
		text_at(gear_title(id,evolved)+"  "+str(world.build[id]),Vector2(324,y+7),8,INK)
		text_at("Урон %s | %s с | радиус %s" % [world.db.number(s.damage),world.db.number(s.interval),world.db.number(s.radius)],Vector2(324,y+20),8,MUTED)
		index += 1
	draw_line(Vector2(22,272),Vector2(618,272),Color("555555"))
	text_at("Предметы",Vector2(24,287),8,INK,true)
	if world.items.is_empty():text_at("Пока нет предметов",Vector2(24,309),8,MUTED)
	index = 0
	for id in world.items:
		var x = 24+index*(100 if coop.active else 75)
		item_icon(id,Vector2(x,296))
		text_at(str(world.items[id])+" / 5",Vector2(x+22,308),8,INK)
		wrapped(gear_title(id),Vector2(x,325),92 if coop.active else 69,8,MUTED)
		index += 1

func dim(alpha: float = 0.72):
	draw_rect(Rect2(0,0,640,360),Color(0,0,0,alpha))

func draw_menu():
	dim(.65)
	centered("Minecraft Survivors",106,32,INK,true)
	button(Rect2(199,151,242,29),"Играть","chapters")
	button(Rect2(199,191,242,29),"Мультиплеер","multiplayer")
	button(Rect2(199,231,242,29),"Настройки","settings")
	button(Rect2(199,271,242,29),"Выход","quit")

func create_network_fields():
	for index in range(2):
		var field = LineEdit.new()
		field.position = Vector2(199,106+index*54)
		field.size = Vector2(242,25)
		field.add_theme_font_override("font",font)
		field.add_theme_font_size_override("font_size",8)
		field.add_theme_color_override("font_color",INK)
		field.add_theme_color_override("caret_color",INK)
		var style = StyleBoxFlat.new()
		style.bg_color = Color.BLACK
		style.border_color = Color("777777")
		style.set_border_width_all(1)
		style.content_margin_left = 6
		style.content_margin_right = 6
		field.add_theme_stylebox_override("normal",style)
		var focus_style = style.duplicate()
		focus_style.border_color = Color.WHITE
		field.add_theme_stylebox_override("focus",focus_style)
		field.max_length = 16 if index == 0 else 64
		field.context_menu_enabled = false
		field.visible = false
		add_child(field)
		if index == 0:
			nickname_field = field
			field.text = network_nick
			field.text_submitted.connect(func(_value): address_field.grab_focus())
		else:
			address_field = field
			field.text = network_address
			field.text_submitted.connect(func(_value): action("network_join"))

func sync_network_fields():
	if not is_instance_valid(nickname_field): return
	var show_fields = screen == "multiplayer" and not coop.active
	nickname_field.visible = show_fields
	address_field.visible = show_fields

func draw_multiplayer():
	dim(.88)
	centered("Мультиплеер",65,16,INK,true)
	if not coop.active:
		text_at("Ник",Vector2(199,99),8,MUTED)
		text_at("IP ZeroTier",Vector2(199,153),8,MUTED)
		button(Rect2(199,207,116,27),"Создать","network_host")
		button(Rect2(325,207,116,27),"Подключиться","network_join")
	else:
		var index = 0
		for id in coop.roster:
			centered(coop.roster[id],112+index*24,8,INK)
			index += 1
		centered("%d / %d" % [coop.roster.size(),coop.MAX_PLAYERS],213,8,MUTED)
		if coop.hosting and coop.roster.size() >= 2:
			button(Rect2(199,227,242,27),"Начать","network_start")
	if not coop.status.is_empty(): centered(coop.status,262,8,MUTED)
	button(Rect2(199,289,242,27),"Назад","network_back")

func draw_network_wait():
	dim(.6)
	var label = "Загрузка…" if coop.loading else "Пауза: "+world.blocked_by()
	centered(label,153,8,INK)
	button(Rect2(219,190,202,27),"В меню","menu")

func wrapped(value: String, p: Vector2, width: float, size: int=10, color: Color=INK, heavy: bool=false):
	size = pixel_font_size(size)
	var f=bold if heavy else font
	var line=""
	var y=p.y
	for word in value.split(" "):
		if f.get_string_size(word,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width:
			if not line.is_empty():
				text_at(line,Vector2(p.x,y),size,color,heavy)
				y+=size+5
				line=""
			var fragment=""
			for letter in word:
				if not fragment.is_empty() and f.get_string_size(fragment+letter+"-",HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width:
					text_at(fragment+"-",Vector2(p.x,y),size,color,heavy)
					y+=size+5
					fragment=""
				fragment+=letter
			line=fragment+" "
			continue
		if f.get_string_size(line+word,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width and not line.is_empty():
			text_at(line,p+Vector2(0,y-p.y),size,color,heavy)
			y+=size+5
			line=""
		line+=word+" "
	text_at(line,p+Vector2(0,y-p.y),size,color,heavy)

func draw_level_up():
	if is_end() and not world.chosen_item.is_empty():
		dim(.83)
		panel(Rect2(176,107,288,143))
		item_icon(world.chosen_item,Vector2(296,122),3,false,world.chosen_level)
		wrapped(gear_title(world.chosen_item,false,world.chosen_level),Vector2(194,193),252,12,INK,true)
		if world.db.weapons.has(world.chosen_item) or world.db.passives.has(world.chosen_item):text_at("Уровень %d" % world.chosen_level,Vector2(194,229),8,MUTED)
		return
	if is_end() and world.choices.size()>3:
		draw_end_choices();return
	dim(0.77)
	centered("НОВЫЙ УРОВЕНЬ",67,23,LIME,true)
	centered("Уровень %d" % world.level,89,8,MUTED)
	for i in range(world.choices.size()):
		var id=world.choices[i]
		var owned=world.build.get(id,world.items.get(id,0))
		var r=Rect2(29+i*197,112,188,159)
		var active=selected==buttons.size()
		buttons.append({"rect":r,"id":"choice_"+str(i)})
		panel(r,Color("314831") if active else Color("20362b"),LIME if active else Color("697655"))
		draw_rect(Rect2(r.position+Vector2(12,12),Vector2(43,43)),Color("151515"))
		item_icon(id,r.position+Vector2(17,17),2,false,owned+1)
		text_at("%d" % (i+1),r.position+Vector2(164,24),12,LIME,true)
		text_at("НОВОЕ" if owned==0 else "УЛУЧШЕНИЕ",r.position+Vector2(66,26),8,GOLD if owned==0 else MUTED,true)
		text_at("Уровень %d" % (owned+1),r.position+Vector2(66,42),9,INK)
		wrapped(gear_title(id,false,owned+1),r.position+Vector2(12,77),165,11,INK,true)
		wrapped(world.db.description(id,owned),r.position+Vector2(12,112),164,9,LIME)
		if active:draw_rect(Rect2(r.position+Vector2(1,154),Vector2(186,4)),LIME)
	button(Rect2(255,321,130,22),"В меню","menu")
	if not coop.active and world is W:button(Rect2(24,321,150,22),"Пропустить","skip_reward")

func draw_pause():
	if coop.active:
		dim(.78);panel(Rect2(173,60,294,231));centered("Пауза",96,24,INK,true)
		button(Rect2(207,120,226,27),"Продолжить","resume")
		button(Rect2(207,157,226,27),"Характеристики","stats")
		button(Rect2(207,194,226,27),"Настройки","settings")
		button(Rect2(207,231,226,27),"В меню","menu");return
	dim(.78)
	panel(Rect2(173,39,294,275))
	centered("Пауза",76,24,INK,true)
	button(Rect2(207,94,226,27),"Продолжить","resume")
	button(Rect2(207,133,226,27),"Характеристики","stats")
	if not coop.active:button(Rect2(207,172,226,27),"Достижения","achievements")
	button(Rect2(207,211,226,27),"Настройки","settings")
	button(Rect2(207,250,226,27),"В меню","menu")

func draw_chest():
	dim(0.78)
	panel(Rect2(105,47,430,266),Color("203329"),GOLD)
	var evolution=world.chest_reward.get("evolution",false)
	centered("ЭВОЛЮЦИЯ" if evolution else "СУНДУК ОТКРЫТ",82,21,GOLD,true)
	var id=world.chest_reward.get("id","apple")
	if world.chest_delay>0:
		draw_clip("chest_open",Vector2(296,99),Vector2(48,48),0.65-world.chest_delay,Color.WHITE,false)
	else:
		item_icon(id,Vector2(296,105),3,evolution)
	centered(gear_title(id,evolution),181,15,INK,true)
	centered(world.chest_reward.get("text",""),208,10,LIME)
	button(Rect2(214,248,212,31),"Открыть" if world.chest_delay>0 else "Продолжить","chest")
	button(Rect2(263,287,114,18),"В меню","menu")

func draw_result():
	dim(0.68)
	panel(Rect2(93,38,454,287),Color("21372d"),LIME if world.victory else Color("a17d5c"))
	centered("Победа" if world.victory else "Вы погибли",80,24,INK,true)
	var values=[format_time(world.time),str(world.kills),str(world.level),str(world.score)]
	var labels=["ВРЕМЯ","УБИЙСТВА","УРОВЕНЬ","ГЛАВА"] if not coop.active else ["ВРЕМЯ","УБИЙСТВА","УРОВЕНЬ","ОЧКИ"]
	if not coop.active:values[3]=str(solo_chapter)
	for i in range(4):
		var x=128+i*102
		text_at(values[i],Vector2(x,143),19,INK,true)
		text_at(labels[i],Vector2(x,161),8,MUTED)
	var ids=world.build.keys()+world.items.keys()
	var x0=320-ids.size()*13
	for i in range(ids.size()):
		var id=ids[i]
		item_icon(id,Vector2(x0+i*26,190),1.3,world.evolved.has(id))
	if not coop.active or coop.hosting: button(Rect2(131,239,178,33),"Ещё раз","retry")
	button(Rect2(330,239,178,33),"В меню","menu")

func draw_settings():
	dim(0.88)
	panel(Rect2(125,27,390,306),Color("20372c"),Color("6c7e58"))
	centered("НАСТРОЙКИ",61,20,INK,true)
	var keys=["music","effects","fullscreen","shake","flashes","numbers"]
	var labels=["Громкость музыки","Громкость эффектов","Полный экран · F11","Тряска камеры","Вспышки при попадании","Числа урона"]
	for i in range(keys.size()):
		var key=keys[i]
		var y=82+i*32
		text_at(labels[i],Vector2(146,y+15),10,INK)
		if i<2:
			button(Rect2(358,y,24,24),"−","volume_"+key+"_down")
			text_at("%d%%" % roundi(settings[key]*100),Vector2(392,y+15),8,INK)
			button(Rect2(468,y,24,24),"+","volume_"+key+"_up")
		else:button(Rect2(408,y,84,24),"Вкл" if settings[key] else "Выкл",key)
	button(Rect2(147,287,161,27),"Папка логов","logs")
	button(Rect2(327,287,166,27),"Назад","back")

func format_time(t: float) -> String:
	return "%02d:%02d" % [int(t)/60,int(t)%60]

func prepare_capture():
	if qa_mode in ["achievements","achievement_toast"]:
		if qa_mode=="achievements":
			screen="achievements";achievement_tier="all";achievement_page=0
			achievements.unlocked={"chapter_one":"preview","first_evolution":"preview","full_inventory":"preview"}
		else:achievement_toast="first_evolution";achievement_toast_age=.3
		return
	if qa_mode.begins_with("end_"):
		prepare_end_capture()
		return
	if qa_mode=="boss_lab":
		for code in [KEY_D,KEY_A,KEY_V,KEY_I,KEY_S,KEY_ENTER]:
			var event=InputEventKey.new();event.physical_keycode=code
			secret_input(event)
		lab_chapter=2
		return
	if qa_mode.begins_with("nether_"):
		prepare_nether_capture()
		return
	if qa_mode.begins_with("herobrine_") or qa_mode in ["finale","portal","fall","chapter_end"]:
		prepare_herobrine_capture()
		return
	if qa_mode=="menu":return
	world.reset(724)
	world.time=378
	world.level=17
	world.hp=16
	world.build={"sword":8,"bow":5,"trident":4,"fire":3,"potion":2,"fangs":3}
	world.items={"blaze":3,"redstone":2,"amethyst":2,"hopper":2}
	world.evolved={"sword":true}
	world.kills=286
	for i in range(25):
		var p=world.player+Vector2.from_angle(i*2.39)*world.rng.randf_range(45,210)
		world.spawn(["zombie","skeleton","creeper","spider","slime"][i%5],p)
	for i in range(28):world.drop_xp(world.player+Vector2.from_angle(i*2.39)*world.rng.randf_range(18,180),1)
	world.rebuild_hit_grid()
	world.swing(Vector2.RIGHT,world.db.stats("sword",8,true,world.items))
	world.add_effect("cloud",world.player+Vector2(70,20),3,{"radius":38.0,"damage":3})
	world.loot.append({"kind":"chest","p":world.player+Vector2(-80,42),"born":world.time})
	if qa_mode=="level":
		world.choices=["bow","potion","amethyst"]
		world.state="LEVEL_UP"
	elif qa_mode=="pause":world.state="PAUSED"
	elif qa_mode=="result":
		world.state="RESULT"
		world.victory=true
		world.time=720
	elif qa_mode=="chest":
		world.evolved={}
		world.open_chest({"born":378.0})
		world.chest_delay=0
	elif qa_mode=="stats": toggle_stats()

func prepare_herobrine_capture():
	world.reset(724)
	world.build={}
	world.finale.begin(world)
	for i in range(4*60):world.step(1.0/60)
	var target={"finale":"storm","portal":"portal","fall":"fall","chapter_end":"end","herobrine_seated":"storm","herobrine_rise":"rising","herobrine_kneel":"kneel","herobrine_rift":"rift","herobrine_wipe":"vanish","herobrine_loss":"fall","herobrine_end":"end"}.get(qa_mode,"storm")
	if target!="storm":
		if qa_mode=="herobrine_loss":world.hp=0
		else:world.finale.boss.hp=0
		for i in range(30*60):
			world.step(1.0/60)
			if world.finale.phase==target:break
	var age:float={"rising":2.6,"kneel":.95,"rift":2.15,"vanish":1.6,"portal":1.5,"fall":2.1}.get(target,.2)
	for i in range(int(age*60)):world.step(1.0/60)

func capture():
	await RenderingServer.frame_post_draw
	var img=get_viewport().get_texture().get_image()
	var output = "res://qa/"+qa_mode+".png" if OS.has_feature("editor") else "user://capture_"+qa_mode+".png"
	img.save_png(output)
	print("CAPTURE ", ProjectSettings.globalize_path(output))
	quit_game()

func prepare_stress():
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	get_window().size=Vector2i(1280,720)
	world.reset(724)
	world.time=580
	for id in world.db.weapons: world.build[id]=8
	for id in world.db.passives: world.items[id]=5
	world.evolved={"sword":true,"bow":true,"trident":true}
	for i in range(250):world.spawn(["zombie","spider","creeper","slime"][i%4],world.player+Vector2.from_angle(i*2.39)*world.rng.randf_range(45,250))
	world.rebuild_hit_grid()

func stats_report(samples: Array) -> Dictionary:
	var sorted=samples.duplicate()
	sorted.sort()
	var sum=0.0
	for v in sorted:sum+=v
	return {"mean_ms":sum/maxi(1,sorted.size()),"p95_ms":sorted[int(sorted.size()*0.95)] if not sorted.is_empty() else 0,"max_ms":sorted.back() if not sorted.is_empty() else 0}

func finish_stress():
	stress_mode=false
	var report={"rendered_frame":stats_report(frame_samples.slice(60)),"simulation":stats_report(sim_samples.slice(60)),"samples":frame_samples.size()-60,"wall_seconds":frame_samples.reduce(func(sum,v):return sum+v,0.0)/1000.0,"renderer":RenderingServer.get_video_adapter_name(),"resolution":str(get_window().size),"render_viewport":str(get_viewport().get_texture().get_size()),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"enemies":world.normal_count(),"all_weapons":8,"all_passives":5,"evolutions":world.evolved.keys(),"godot":Engine.get_version_info().string,"executable":OS.get_executable_path()}
	var path="res://qa/performance.json" if OS.has_feature("editor") else "user://performance.json"
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("PERFORMANCE ",JSON.stringify(report))
	quit_game()

func finish_autoplay():
	var report={"style":autoplay_style,"victory":world.victory,"chapter_complete":world.finale.complete,"ending":world.finale.phase,"time":world.time,"hp":world.hp,"kills":world.kills,"level":world.level,"build":world.build,"items":world.items,"evolved":world.evolved,"simulation":stats_report(sim_samples),"executable":OS.get_executable_path()}
	var path="res://qa/native_run.json" if OS.has_feature("editor") else "user://native_run.json"
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("AUTOPLAY ",JSON.stringify(report))
	quit_game()

func prepare_recording():
	qa_controller=load("res://scripts/autoplay_bot.gd").new("sword")
	world.reset(151)
	if recording_stage=="foundation":return
	world.build={"sword":3,"bow":1}
	world.level=4
	world.time=61
	if recording_stage in ["combat","evolution"]:
		world.build={"sword":8,"bow":6,"trident":5,"fire":4,"potion":4,"fangs":4}
		world.items={"blaze":3,"amethyst":2,"redstone":3,"sugar":2,"hopper":2}
		world.level=24
		world.time=370
		for i in range(55):world.spawn(["zombie","spider","creeper","slime","skeleton"][i%5],world.player+Vector2.from_angle(i*2.39)*world.rng.randf_range(90,240))
		if recording_stage=="evolution":
			world.open_chest({"born":370.0})
			world.chest_delay=0

func quit_game():
	collect_achievements()
	if quitting:return
	quitting=true
	coop.leave()
	if is_instance_valid(audio):audio.shutdown()
	await get_tree().create_timer(0.6).timeout
	var tree = get_tree()
	tree.create_timer(0.1).timeout.connect(tree.quit)
	queue_free()

func draw_chapters():
	dim(.9)
	centered("Выбор главы",76,24,INK,true)
	button(Rect2(478,12,140,22),"Достижения","achievements")
	button(Rect2(172,113,296,35),"Глава I · Верхний мир","chapter_1")
	button(Rect2(172,164,296,35),"Глава II · Незер","chapter_2")
	button(Rect2(172,215,296,35),"Глава III · Край","chapter_3")
	button(Rect2(219,282,202,27),"Назад","back")

func draw_inventory():
	draw_rect(Rect2(0,0,640,360),Color.BLACK)
	text_at("Инвентарь",Vector2(22,29),16,INK,true)
	button(Rect2(510,13,108,22),"Готово","close_inventory")
	draw_line(Vector2(22,59),Vector2(618,59),Color("555555"))
	for row in range(2):
		var collection=world.build if row==0 else world.items
		var slots=6 if row==0 else 8
		var step_x=99 if row==0 else 74
		var y=85 if row==0 else 212
		text_at(("Оружие · %d / 6" if row==0 else "Усиления · %d / 8") % collection.size(),Vector2(24,y-9),8,INK,true)
		var ids=collection.keys()
		for i in range(slots):
			var x=24+i*step_x
			panel(Rect2(x,y,step_x-5,103))
			if i>=ids.size():
				text_at("—",Vector2(x+step_x/2-4,y+45),8,MUTED)
				continue
			var id=ids[i]
			item_icon(id,Vector2(x+7,y+7),1,world.evolved.has(id))
			text_at(str(collection[id])+" / "+("8" if row==0 else "5"),Vector2(x+29,y+19),8,MUTED)
			wrapped(gear_title(id,world.evolved.has(id)),Vector2(x+6,y+38),step_x-14,8,INK)
			button(Rect2(x+5,y+77,step_x-15,20),"Удалить","discard_"+id)
	button(Rect2(24,330,100,22),"Рецепты","recipes")

func prepare_nether_capture():
	start_chapter(2)
	world.reset(724)
	world.build={"sword":8,"axe":8,"hoe":8,"tnt":8,"crossbow":8,"fishing":8}
	world.items={"gold_boots":3,"fire_resist":3,"ghast_tear":3,"feather":3,"armor":3,"blaze":3,"redstone":3,"amethyst":3}
	world.evolved={"axe":true,"crossbow":true}
	world.time=420
	if qa_mode.begins_with("nether_ghast"):
		world.begin_arena()
		while world.stage!="arrival":world.step(1.0/60)
		var age:float={"nether_ghast":1.7,"nether_ghast_charge":4.8,"nether_ghast_burst":5.6,"nether_ghast_reveal":7.3}.get(qa_mode,1.7)
		for i in range(int(age*60)):world.step(1.0/60)
		return
	if qa_mode=="nether_portal_camera":
		world.prepare_arena();world.stage="wither";world.ghast.reset()
		world.mobs[0].p=Vector2(800,900);world.mobs[0].hp=0;world.resolve_deaths()
		while world.stage=="defeat":world.step(1.0/60)
		world.player=world.loot.filter(func(o):return o.kind=="ender_eye")[0].p
		world.pickup(.01)
		for i in range(90):world.step(1.0/60)
		return
	if qa_mode in ["nether_boss","nether_end"]:
		world.begin_arena()
		while world.stage!="wither":world.step(1.0/60)
		if qa_mode=="nether_end":
			world.mobs[0].hp=0
			world.resolve_deaths()
			while world.stage=="defeat":world.step(1.0/60)
			world.player=world.loot.filter(func(o):return o.kind=="ender_eye")[0].p
			world.pickup(.01)
			world.player=world.portal_position+Vector2(40,0)
			world.step(.01)
			while world.stage=="lighting":world.step(1.0/60)
			world.player=world.portal_position
			world.step(.01)
			while world.stage in ["jump","crossing"]:world.step(1.0/60)
	else:
		for i in range(8):world.spawn(["zombified_piglin","piglin_sword","piglin_crossbow","wither_skeleton","blaze_nether","hoglin","zoglin","brute"][i],world.player+Vector2(-180+i%4*118,-55+i/4*100))
		world.rebuild_hit_grid()
		world.update_attacks(.01)
		if qa_mode=="nether_inventory":toggle_inventory()

func draw_recipe_book():
	draw_rect(Rect2(0,0,640,360),Color.BLACK)
	text_at("Эволюции",Vector2(22,29),16,INK,true)
	text_at("Оружие VIII · сундук после 6:00",Vector2(22,47),8,MUTED)
	button(Rect2(510,13,108,22),"Назад","recipes_back")
	var index=0
	var ids=world.db.recipes.keys()
	recipe_page=clampi(recipe_page,0,maxi(0,(ids.size()-1)/9))
	for id in ids.slice(recipe_page*9,recipe_page*9+9):
		var recipe=world.db.recipes[id]
		var p=Vector2(22+(index%3)*202,65+(index/3)*(89 if ids.size()>9 else 94))
		panel(Rect2(p,Vector2(192,84 if ids.size()>9 else 88)))
		item_icon(id,p+Vector2(8,8))
		text_at("+",p+Vector2(31,20),8,MUTED)
		item_icon(recipe.passive,p+Vector2(44,8))
		text_at("=",p+Vector2(67,20),8,MUTED)
		item_icon(id,p+Vector2(80,8),1,true)
		wrapped(recipe.name,p+Vector2(8,37),175,8,INK,true)
		wrapped(recipe.effect,p+Vector2(8,65),175,8,MUTED)
		index+=1

	if ids.size()>9:
		if recipe_page>0:button(Rect2(232,338,70,18),"Назад","recipes_prev")
		if (recipe_page+1)*9<ids.size():button(Rect2(338,338,70,18),"Далее","recipes_next")

func draw_end_choices():
	dim(.82)
	centered("НОВЫЙ УРОВЕНЬ",54,24,INK,true)
	centered("Уровень %d" % world.level,76,8,MUTED)
	var count=world.choices.size()
	var width=112 if count==5 else 141
	var gap=8
	var start=(640-count*width-(count-1)*gap)/2
	for i in range(count):
		var id=world.choices[i];var owned=world.build.get(id,world.items.get(id,0))
		var r=Rect2(start+i*(width+gap),98,width,192)
		var active=selected==buttons.size();buttons.append({"rect":r,"id":"choice_"+str(i)})
		panel(r);item_icon(id,r.position+Vector2(12,14),2,false,owned+1)
		text_at(str(i+1),r.position+Vector2(width-18,25),8,INK,true)
		text_at("I" if owned==0 else str(owned+1),r.position+Vector2(53,35),8,MUTED)
		wrapped(gear_title(id,false,owned+1),r.position+Vector2(8,69),width-16,8,INK,true)
		wrapped(world.db.description(id,owned),r.position+Vector2(8,107),width-16,8,MUTED)
		if active:draw_rect(Rect2(r.position+Vector2(1,188),Vector2(width-2,3)),INK)
	if world.rerolls>0:button(Rect2(207,304,226,23),"Перебросить · "+str(world.rerolls),"end_reroll")
	button(Rect2(255,333,130,22),"В меню","menu")
	button(Rect2(20,333,150,22),"Пропустить","skip_reward")

func prepare_end_capture():
	if qa_mode=="end_victory":
		start_chapter(3);world.prepare_arena();world.mobs.clear();world.stage="last_duel";world.build={}
		for crystal in world.crystals:crystal.alive=false
		world.spawn("endersteve_final",world.portal_position+Vector2(0,-35));world.mobs[0].hp=0;world.resolve_deaths()
		world.stage_age=7.61;world.end_boss.story(world,.02);return
	start_chapter(3);world.reset(724);world.state="RUNNING";world.stage="survival"
	world.build={"sword":8,"spear":8,"mace":8,"end_crystal":8,"knockback_stick":8,"shield":8}
	world.items={"elytra":5,"ender_pearl":5,"rabbit_foot":5,"end_eye":5,"shulker_shell":5,"sugar":4,"armor":4,"feather":4}
	world.evolved={"spear":true,"mace":true,"shield":true};world.shield_charges=7
	world.time=480;world.level=35;world.kills=520
	if qa_mode=="end_scale":world.stage="end_arrival";return
	if qa_mode=="end_choices":world.xp=world.db.required_xp(world.level);world.next_level();return
	if qa_mode=="end_inventory":toggle_inventory();return
	if qa_mode=="end_recipes":screen="recipes";recipe_page=1;return
	if qa_mode=="end_overworld":world.stage="chapter_four";world.stage_age=3;world.state="RESULT";return
	if qa_mode in ["end_dragon","end_crystals","end_dragon_rage","end_betrayal","end_last_duel","end_dragon_death","end_rekindle","end_jump","end_steve_death"]:
		world.prepare_arena();world.stage="dragon";world.invulnerable=60
		world.build={"sword":8,"spear":8,"mace":8,"end_crystal":8,"knockback_stick":8,"shield":8}
		var dragon=world.mobs.back();dragon.p=Vector2(1024,1030);dragon.dir=Vector2.RIGHT;dragon.altitude=40;world.scene_camera=Vector2(1024,1040)
		world.player=Vector2(1024,1160)
		if qa_mode=="end_dragon_rage":
			for t in world.crystals:t.alive=false
			dragon.phase_two=true;dragon.hp=dragon.max_hp*.5;dragon.phase="perch";dragon.altitude=0;dragon.timer=5
			world.player=Vector2(1170,1190);var saved_build=world.build;world.build={}
			for i in range(100):world.step(1.0/60,Vector2.ZERO)
			world.build=saved_build
		elif qa_mode=="end_crystals":world.player=world.crystals[3].p+Vector2(0,20);world.update_elevation(0);world.scene_camera=world.player-Vector2(0,32)
		elif qa_mode=="end_dragon_death":world.hurt(dragon,20000);dragon.hp=0;world.resolve_deaths();world.stage_age=2.4
		elif qa_mode in ["end_betrayal","end_last_duel","end_rekindle","end_jump","end_steve_death"]:
			world.mobs.clear();
			for crystal in world.crystals:crystal.alive=false
			world.stage="betrayal";world.stage_age=3.35;world.portal_lit=false;world.player=Vector2(1024,1140)
			world.add_effect("portal_shatter",world.portal_position,3.8,{"radius":100.0});world.effects.back().age=.3
			if qa_mode=="end_last_duel":
				world.stage="last_duel";world.effects.clear();world.spawn("endersteve_final",Vector2(1024,1020));world.mobs.back().phase="cast";world.mobs.back().pattern=1;world.mobs.back().timer=3
				var saved_build=world.build;world.build={};world.player=Vector2(1130,1180)
				for i in range(140):world.step(1.0/60,Vector2.ZERO)
				world.build=saved_build
			elif qa_mode=="end_rekindle":world.stage="rekindle";world.stage_age=1.45;world.hand_taken=true;world.player=world.portal_position+Vector2(0,46);world.facing=Vector2.UP;world.jump_start=world.player
			elif qa_mode=="end_jump":world.stage="exit_jump";world.stage_age=0;world.portal_lit=true;world.jump_start=world.portal_position+Vector2(0,35)
			elif qa_mode=="end_steve_death":
				world.stage="last_duel";world.spawn("endersteve_final",world.portal_position+Vector2(30,20));world.mobs[0].hp=0;world.resolve_deaths()
		return
	for i in range(26):
		var p=world.player+Vector2.from_angle(i*2.39996)*(60+i%5*36)
		if world.on_land(p):world.spawn(["endermite","enderman","shulker","dispenser_enderman","endermite_brood","endersteve"][i%6],p)
	world.rebuild_hit_grid();world.facing=Vector2.RIGHT
	if qa_mode=="end_flight":world.active_item("rocket");world.dash_left=.8
	else:world.update_attacks(.01)
	for i in range(35):world.update_effects(1.0/60);world.update_projectiles(1.0/60)

func open_achievements():
	if coop.active:return
	achievements_from=screen;achievement_state=world.state
	if world.state in ["RUNNING","FINALE","LEVEL_UP","CHEST"]:world.state="PAUSED"
	achievement_tier="all";achievement_page=0;screen="achievements"

func close_achievements():
	screen=achievements_from;world.state=achievement_state;selected=0;input_lock=.12

func achievements_allowed() -> bool:
	if coop.active or not (world is W) or not world.run_progress.enabled:return false
	if not qa_mode.is_empty() or not autoplay_style.is_empty() or stress_mode or chapter_preview or not recording_stage.is_empty():return false
	for arg in OS.get_cmdline_args():
		if arg in ["-s","--script"] or arg.begins_with("--script="):return false
	return true

func collect_achievements():
	if achievements_allowed():
		for id in world.run_progress.drain():achievements.unlock(id)

func update_achievements(delta: float):
	collect_achievements()
	if achievement_toast.is_empty():
		if not achievements.pending.is_empty():
			achievement_toast=achievements.pending.pop_front();achievement_toast_age=0
			audio.play("achievement")
	else:
		achievement_toast_age+=delta
		if achievement_toast_age>=3.5:achievement_toast="";achievement_toast_age=0
