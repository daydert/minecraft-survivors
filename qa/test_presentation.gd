extends SceneTree
## Real playback resources, input transitions, numeric stats and capture matrix.
var game
var checks = 0
var failures = []

func _initialize(): run.call_deferred()

func check(ok: bool,label: String):
	checks += 1
	if ok: print("PASS: "+label)
	else:
		failures.append(label)
		push_error(label)

func key(code: int,physical: bool = false):
	var e = InputEventKey.new()
	e.pressed = true
	if physical: e.physical_keycode = code
	else: e.keycode = code
	game.input_lock = 0
	game._input(e)

func render(path: String = "") -> Image:
	game.queue_redraw()
	await process_frame
	RenderingServer.force_draw(false)
	var im = root.get_texture().get_image()
	if not path.is_empty():im.save_png("res://qa/"+path+".png")
	return im

func run():
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process_input(false);game.set_process(false)
	game.set_physics_process(false)
	game.qa_mode="presentation"
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size=Vector2i(640,360)
	game.settings.shake=false
	check(game.audio.music.stream is AudioStreamOggVorbis,"User soundtrack loads as Ogg Vorbis")
	check(game.audio.music.stream.loop,"User soundtrack loops")
	check(absf(game.audio.music.stream.get_length()-320.04)<0.15,"Complete user track retains its original duration")
	check(game.audio.music.playing,"User soundtrack is playing")
	check(game.audio.boss_music.stream is AudioStreamOggVorbis and game.audio.boss_music.stream.loop,"Herobrine soundtrack is ready as a separate looping stream")
	check(absf(game.audio.boss_music.stream.get_length()-79.962)<.15,"Complete original Herobrine track retains its supplied duration")
	game.audio.set_finale_music(true)
	check(game.audio.boss_music.playing and game.audio.finale_music,"Herobrine arrival starts the supplied battle soundtrack")
	game.audio.set_finale_music(false)
	game.audio._process(1)
	check(not game.audio.boss_music.playing and game.audio.music.playing,"Leaving the encounter restores the normal soundtrack")
	game.audio.set_finale_music(true)
	for i in range(60):game.audio._process(1.0/60)
	game.audio.set_finale_music(false)
	for i in range(60):game.audio._process(1.0/60)
	check(game.audio.music_mix==0 and not game.audio.boss_music.playing,"Frame-by-frame crossfade reaches exact silence and stops the boss decoder")
	var all_streams=true
	for event in game.audio.sound_map.values():
		for variant in event.variants:
			var stream=load(variant.path)
			all_streams=all_streams and stream is AudioStreamOggVorbis and stream.get_length()>0
	check(all_streams,"Every original Minecraft sound variant decodes")
	game.audio.play("swing")
	check(game.audio.voices.has("swing") and game.audio.voices.swing[0].playing,"Vanilla sweep plays through the effect voice pool")
	game.audio.update_volumes(0,0)
	check(game.audio.music.volume_db<=-90 and game.audio.voices.swing[0].volume_db<=-90,"Both volume controls immediately mute active playback")
	game.audio.update_volumes(0.4,0.65)
	var cyrillic=true
	for c in "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯабвгдеёжзийклмнопрстуфхцчшщъыьэюя":
		cyrillic=cyrillic and game.font.has_char(c.unicode_at(0)) and game.bold.has_char(c.unicode_at(0))
	check(cyrillic,"Original Minecraft bitmap font covers Russian in regular and bold")
	game.world.state="MENU"
	await render("presentation_menu")
	key(KEY_L)
	check(game.screen.is_empty() and game.world.state=="MENU","L does not open uninitialized character stats from menu")
	game.world.reset(724)
	key(KEY_L,true)
	check(game.screen=="stats" and game.world.state=="PAUSED","Physical L opens stats and pauses combat")
	var before=game.world.time
	game.world.step(10,Vector2.RIGHT)
	check(game.world.time==before,"Character screen freezes combat")
	await render("presentation_stats_empty")
	key(KEY_L,true)
	check(game.screen.is_empty() and game.world.state=="RUNNING","Physical L closes stats and resumes the previous run")
	for state in ["RUNNING","PAUSED","LEVEL_UP","CHEST"]:
		game.world.state=state
		key(KEY_L)
		key(KEY_ESCAPE)
		check(game.screen.is_empty() and game.world.state==state,"Esc restores exact previous state: "+state)
	game.world.state="RUNNING"
	game.world.hp=15
	game.world.xp=3
	game.world.level=17
	for id in game.world.db.weapons:game.world.build[id]=8
	for id in game.world.db.passives:game.world.items[id]=5
	game.world.evolved={"sword":true,"bow":true,"trident":true}
	var stats=game.character_stats()
	check(stats["Скорость"]=="114.8 пикс/с" and stats["Бонус урона"]=="+50%" and stats["Сбор опыта"]=="60 пикс","Stats show actual passive formulas")
	check(stats["Интервал атак"]=="-30%" and stats["Размер атак"]=="+50%" and stats["Защита"]=="-1 HP за удар","Stats show actual reduction, area and armor values")
	for i in range(9):game.world.spawn(["zombie","skeleton","creeper"][i%3],game.world.player+Vector2(-150+i%3*150,-65+i/3*50))
	await render("presentation_hud")
	key(KEY_L)
	var a=await render("presentation_stats")
	check(a.get_pixel(0,0)==Color.BLACK and a.get_pixel(639,359)==Color.BLACK,"Stats screen has a fully black background")
	game.ui_time+=50
	var b=await render()
	check(a.get_data()==b.get_data(),"Stats stay visually frozen while interface time advances")
	root.size=Vector2i(1280,720)
	# Render the actual 2x framebuffer rather than the pre-stretch 640x360
	# texture returned in viewport-stretch mode. The same logical coordinates,
	# integer scale and nearest sampling are preserved.
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var scaled=await render("presentation_stats_2x")
	check(scaled.get_size()==Vector2i(1280,720),"2x capture contains the actual 1280x720 framebuffer")
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	root.size=Vector2i(640,360)
	key(KEY_L)
	game.world.build.bow=4
	game.world.build.potion=2
	game.world.items.amethyst=2
	game.world.choices=["bow","potion","amethyst"]
	game.world.state="LEVEL_UP"
	await render("presentation_level")
	game.world.state="PAUSED"
	await render("presentation_pause")
	game.screen="settings"
	await render("presentation_settings")
	game.screen=""
	game.world.open_chest({"born":400.0})
	game.world.chest_delay=0
	await render("presentation_chest")
	game.world.state="RESULT"
	game.world.victory=true
	await render("presentation_result")
	FileAccess.open("res://qa/presentation_results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	game.audio.shutdown()
	await create_timer(0.1).timeout
	game.free()
	game=null
	await process_frame
	quit(0 if failures.is_empty() else 1)
