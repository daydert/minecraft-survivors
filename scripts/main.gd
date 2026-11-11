extends "res://scripts/ui/game_canvas.gd"
## Game node: lifecycle, input, actions and screen flow. Drawing lives in scripts/ui/.
const ChapterOneView=preload("res://scripts/chapter_one_view.gd")

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
	var v2_assets: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/v2_assets.json"))
	for name in v2_assets.clips:minecraft_assets.clips[name]=v2_assets.clips[name]
	for name in v2_assets.sprites:load_texture(name)
	for name in JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_five_assets.json")).sprites:load_texture(name)
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
		QAHarness.prepare_capture(self)
	if not autoplay_style.is_empty():
		qa_controller = load("res://scripts/autoplay_bot.gd").new(autoplay_style)
		world.reset(151 if autoplay_style in ["sword","trident"] else (153 if autoplay_style == "random" else 152))
	if stress_mode: QAHarness.prepare_stress(self)
	if not recording_stage.is_empty(): QAHarness.prepare_recording(self)
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

func load_settings(path: String = "user://settings.cfg"):
	var cfg = ConfigFile.new()
	if cfg.load(path) == OK:
		for key in settings:
			var value = cfg.get_value("settings",key,settings[key])
			if typeof(value) == typeof(settings[key]): settings[key] = value
	for key in record: record[key] = cfg.get_value("record",key,record[key])
	network_nick = str(cfg.get_value("network","nick","Стив")).left(16)
	network_address = str(cfg.get_value("network","address","")).left(64)
	settings.music = snappedf(clampf(settings.music,0,1),.1)
	settings.effects = snappedf(clampf(settings.effects,0,1),.1)
	if settings.fullscreen: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func save_settings(path: String = "user://settings.cfg"):
	var cfg = ConfigFile.new()
	for key in settings: cfg.set_value("settings",key,settings[key])
	for key in record: cfg.set_value("record",key,record[key])
	cfg.set_value("network","nick",network_nick)
	cfg.set_value("network","address",network_address)
	cfg.save(path)

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
	if is_four():world.ending.hold=Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_J) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
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
					QAHarness.finish_autoplay(self)
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
			if is_four() and world.note_pending:
				world.note_pending = false
				router.open("ch4_note",world)
				selected = 0;input_lock = .2

func _process(delta):
	if quitting:return
	coop.present(delta)
	sync_network_fields()
	var hero_theme=world.finale.active and (not world.finale.has_method("duel_phase") or not world.finale.complete)
	if is_end() and world.stage=="chapter_four":world.stage_age+=delta
	var theme="victory" if world.get("win_music")==true else "silence" if is_end() and world.stage in ["betrayal","yield","approach"] else "chapter_four_end:coords" if is_end() and world.stage in ["to_edge","sit","restore","portal_ready","exit_jump","chapter_four"] else "endersteve" if is_end() and world.stage in ["last_arrival","last_duel"] else "dragon" if is_end() and world.stage in ["departure","dragon_arrival","dragon","dragon_death"] else "herobrine" if hero_theme else "wither" if is_nether() and world.stage in ["departure","arrival","wither","defeat"] else ""
	var four_theme: String=("chapter_four_end:"+world.ending.music) if is_four() and world.stage=="finale" and world.ending.phase not in ["","summit"] else ("chapter_four_pyramid" if is_four() and world.encounters.current=="guardian" else "chapter_four")
	audio.set_music_context(four_theme if is_four() else theme,world.state not in ["MENU","RESULT"])
	update_achievements(delta)
	update_camera_lead()
	ui_time += delta
	if stress_mode:
		frame_samples.append(delta*1000)
		if frame_samples.size()>=1860: QAHarness.finish_stress(self)
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
	if is_four() and world.stage=="finale" and world.ending.phase=="three" and world.state=="RUNNING" and screen.is_empty():
		var qte_action := ""
		if event is InputEventKey and event.pressed and not event.echo:
			var code: int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
			qte_action={KEY_A:"left",KEY_LEFT:"left",KEY_D:"right",KEY_RIGHT:"right",KEY_W:"up",KEY_UP:"up",KEY_S:"down",KEY_DOWN:"down",KEY_SPACE:"attack",KEY_J:"attack",KEY_ENTER:"attack"}.get(code,"")
		elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:qte_action="attack"
		if not qte_action.is_empty():
			world.ending.press(qte_action);return
	if screen == "multiplayer" and event is InputEventKey and (nickname_field.has_focus() or address_field.has_focus()) and event.keycode not in [KEY_ESCAPE,KEY_F11,KEY_F8]: return
	if event is InputEventMouseMotion:
		mouse = get_global_mouse_position()
		for i in range(buttons.size()):
			if buttons[i].rect.has_point(mouse): selected = i
	if world.state=="INTRO" and screen.is_empty() and ((event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE,KEY_ENTER,KEY_ESCAPE]) or (event is InputEventMouseButton and event.pressed)):
		world.skip_intro();input_lock=.2;return
	if event is InputEventKey and event.pressed and not event.echo:
		if is_four() and world.state=="RUNNING" and screen.is_empty():
			if event.physical_keycode==KEY_E:world.active_item("heart");return
			if event.physical_keycode==KEY_SPACE:world.active_item("bat");return
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
			if screen=="ch4_note":close_four_note()
			elif screen=="achievements":close_achievements()
			elif screen=="boss_lab":close_boss_lab()
			elif screen=="recipes":close_recipes()
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
		"chapter_4":start_chapter(4)
		"chapter_5":start_chapter(5)
		"ch4_note_close":close_four_note()
		"end_reroll":
			if is_end() or is_four():world.reroll_choices()
		"skip_reward":
			if not coop.active and world is W:world.skip_reward()
		"recipes_next":recipe_page+=1
		"recipes_prev":recipe_page=maxi(0,recipe_page-1)
		"inventory":toggle_inventory()
		"close_inventory":close_inventory()
		"recipes":router.open("recipes",world,false);recipe_page=0
		"recipes_back":close_recipes()
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
			start_chapter(solo_chapter,id=="start")
		"menu":
			collect_achievements()
			if coop.active:
				coop.leave()
				world = W.new()
			world = W.new()
			solo_chapter=1
			unload_end_assets()
			unload_four_assets()
			ChapterOneView.unload(self)
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
		"shake","flashes","numbers","lighting","camera_lead":
			settings[id] = not settings[id]
			if id=="camera_lead":cam_lead=Vector2.ZERO;lead_clock=world.clock
		"music","effects":
			adjust_volume(id,.1)
	save_settings()
	selected = 0

func secret_input(event: InputEventKey) -> bool:
	if coop.active or screen=="multiplayer":secret_keys="";return false
	var code=event.physical_keycode if event.physical_keycode!=0 else event.keycode
	if Time.get_ticks_msec()-secret_key_time>3000:secret_keys=""
	secret_key_time=Time.get_ticks_msec()
	if code in [KEY_ENTER,KEY_KP_ENTER] and secret_keys=="davis":
		secret_keys=""
		if screen!="boss_lab":
			lab_chapter=mini(solo_chapter,3)
			router.open("boss_lab",world);selected=3
		return true
	var letter: String={KEY_D:"d",KEY_A:"a",KEY_V:"v",KEY_I:"i",KEY_S:"s"}.get(code,"")
	var candidate=secret_keys+letter
	if not letter.is_empty() and "davis".begins_with(candidate):
		secret_keys=candidate
		return true
	secret_keys="d" if letter=="d" else ""
	return false

func close_boss_lab():
	router.close(world);selected=0;input_lock=.12

func update_camera_lead():
	if not settings.get("camera_lead",false) or coop.active or world.state=="MENU":
		cam_lead=Vector2.ZERO
		lead_clock=world.clock
		return
	if world.state!="RUNNING":
		lead_clock=world.clock
		return
	var dt: float=clampf(world.clock-lead_clock,0,.1)
	lead_clock=world.clock
	var target: Vector2=world.facing*20.0 if world.player_moving else Vector2.ZERO
	cam_lead=cam_lead.lerp(target,1-exp(-dt*3.0))

func close_recipes():
	router.close(world,"inventory")

func start_chapter(chapter: int, intro: bool=true):
	if coop.active:return
	collect_achievements()
	solo_chapter=chapter
	if chapter==3:ensure_end_assets()
	else:unload_end_assets()
	if chapter==4:ensure_four_assets()
	else:unload_four_assets()
	if chapter!=1:ChapterOneView.unload(self)
	world=VW.new() if chapter==5 else FW.new() if chapter==4 else EW.new() if chapter==3 else NW.new() if chapter==2 else OW.new()
	world.reset()
	if chapter==1 and intro:world.begin_intro()
	audio.reset_run_music()
	cam_lead=Vector2.ZERO;lead_clock=0.0
	screen=""
	selected=0

func adjust_volume(id: String, delta: float):
	settings[id]=float(clampi(roundi(settings[id]*10)+roundi(delta*10),0,10))/10
	audio.update_volumes(settings.music,settings.effects)
	save_settings()

func close_four_note():
	if not is_four() or screen != "ch4_note":return
	world.read_note()
	router.close(world)
	selected = 0

func toggle_inventory():
	if coop.active:return
	if screen=="inventory":close_inventory()
	elif screen.is_empty() and world.state in ["RUNNING","PAUSED","LEVEL_UP","CHEST","FINALE"]:
		router.open("inventory",world)
		selected=0
		input_lock=.12

func close_inventory():
	router.close(world)
	selected=0
	input_lock=.12

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
		router.open("stats",world)
		selected = 0
		input_lock = 0.12

func close_stats():
	if coop.active:
		screen = ""
		coop.command("pause",1 if stats_coop_was_paused else 0)
	else: router.close(world)
	selected = 0
	input_lock = 0.12

func _draw():
	var began = Time.get_ticks_usec()
	draw_scene()
	achievements_view.toast(self)
	var end_power=0.0
	if is_end():
		if world.stage=="betrayal":end_power=.95*smoothstep(1.4,3.4,world.stage_age)*(1-smoothstep(5.0,10.0,world.stage_age))
		elif world.stage=="last_arrival":end_power=.55*(1-smoothstep(2,3.2,world.stage_age))
		elif world.stage=="last_duel":
			for boss in world.mobs:
				if boss.kind=="endersteve_final" and boss.phase=="rage":end_power=sin(clampf(1-boss.timer/1.6,0,1)*PI)*.45
		elif world.stage=="endsteve_death":end_power=.7*sin(smoothstep(1.7,7.1,world.stage_age)*PI)
		elif world.stage=="rekindle":end_power=sin(clampf(world.stage_age/2.8,0,1)*PI)*.35
		elif world.stage=="restore":end_power=.5*smoothstep(3.6,6.2,world.stage_age)*(1-smoothstep(8.0,10.4,world.stage_age))
	var end_focus=world.endsteve_corpse.p-Vector2(0,20) if is_end() and world.stage=="endsteve_death" else world.portal_position if is_end() else Vector2.ZERO
	end_rift.configure(end_power>0 and screen.is_empty() and world.state=="RUNNING",end_focus+Vector2(320,180)-world.camera() if is_end() else Vector2.ZERO,end_power,world.clock)
	var duel=world.finale.has_method("blood_progress")
	var enabled=duel and world.finale.phase in ["rift","vanish"] and world.state=="FINALE" and screen.is_empty()
	blood_rift.configure(enabled,world.player+Vector2(320,172)-world.camera(),world.finale.blood_progress() if duel else 0,world.clock,world.finale.blood_wipe() if duel else 0)
	coop.diagnostics.measure("draw_cpu_ms",(Time.get_ticks_usec()-began)/1000.0)

func draw_scene():
	buttons.clear()
	if screen=="ch4_note":
		WorldView.draw_world(self)
		four_renderer.note(self)
		return
	if screen=="achievements":
		achievements_view.screen(self);return
	if screen=="boss_lab":
		RunScreens.draw_boss_lab(self)
		return
	if screen=="recipes":
		GearScreens.draw_recipe_book(self)
		return
	if screen=="inventory":
		GearScreens.draw_inventory(self)
		return
	if is_nether() and world.stage=="crossing":
		nether_renderer.ending(self,false)
		if world.state=="PAUSED":RunScreens.draw_pause(self)
		return
	if is_end() and world.stage=="chapter_four":
		end_renderer.ending(self)
		return
	if is_nether() and world.stage=="end":
		nether_renderer.ending(self)
		return
	if screen=="stats":
		GearScreens.draw_stats(self)
		return
	if world.state=="RESULT" and world.finale.complete:
		finale_renderer.ending(self)
		return
	WorldView.draw_world(self)
	if (not is_four() or (world.stage != "arrival" and not world.ending.locked())) and world.state != "MENU" and world.state!="INTRO" and (not world.finale.active or world.finale.phase in ["storm","inferno","tease"]) and (not is_nether() or world.stage in ["survival","wither","portal"]) and (not is_end() or world.stage in ["survival","dragon","last_duel","exit_portal","hand","return_portal","portal_ready"]):Hud.draw_hud(self)
	if screen=="chapters":MenuScreens.draw_chapters(self)
	elif screen == "multiplayer": MenuScreens.draw_multiplayer(self)
	elif not screen.is_empty(): MenuScreens.draw_settings(self)
	elif world.state == "MENU": MenuScreens.draw_menu(self)
	elif world.state == "LEVEL_UP": RunScreens.draw_level_up(self)
	elif world.state == "PAUSED": RunScreens.draw_pause(self)
	elif world.state == "CHEST": RunScreens.draw_chest(self)
	elif world.state == "RESULT": RunScreens.draw_result(self)
	elif world.state == "WAITING": MenuScreens.draw_network_wait(self)
	if coop.network_waiting():
		draw_rect(Rect2(206,70,228,24),Color(0,0,0,.8))
		centered("Ожидание сети…",86,8,MUTED)

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

func open_achievements():
	if coop.active:return
	router.open("achievements",world,world.state in ["RUNNING","FINALE","LEVEL_UP","CHEST"])
	achievement_tier="all";achievement_page=0

func close_achievements():
	router.close(world);selected=0;input_lock=.12

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
