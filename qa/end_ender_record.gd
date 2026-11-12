extends SceneTree
## Diagnostic film of the reworked Chapter III finale: dragon, the broken portal,
## the duel, the rim of the island and the restored portal. Invulnerable hero,
## scripted kills; the dialogue, music cues and sounds are the game's own.
var game
var folder:="res://qa/recordings/end_ender_frames"
var state:={"frame":0,"cues":[],"music":[],"last_music":""}
func _initialize():run.call_deferred()
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="film"
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	game.action("chapter_3");var w=game.world;game.settings.shake=true
	w.build={"sword":8,"bow":7,"spear":6,"mace":6};w.items={"armor":4,"elytra":3}
	w.state="RUNNING";w.stage="survival";w.invulnerable=999
	# Two of the echoes with the reworked lines: the scream at 5:00 and "НАЧНЁМ!" at 11:30.
	w.db.data.events=w.db.data.events.filter(func(e):return e.at in [300,690])
	w.time=296.0;w.echo_count=1
	await run_for(w,8.0,"")
	for m in w.mobs:
		if m.kind=="endersteve":m.hp=0
	w.resolve_deaths();w.time=686.0;w.echo_count=4
	await run_for(w,14.0,"")
	if not w.gateways.is_empty():
		w.teleport_to(w.gateways[0].p+Vector2(0,60))
		for f in range(75):await tick(w,w.player.direction_to(w.gateways[0].p))
		await run_for(w,1.5,"")
	w.prepare_arena()
	while w.stage=="dragon_arrival":await tick(w,Vector2.ZERO)
	var dragon=w.mobs.filter(func(m):return m.kind=="end_dragon")[0]
	for t in w.crystals:t.alive=false
	for m in w.mobs:
		if m.kind=="arena_crystal":m.hp=0
	w.resolve_deaths()
	dragon.hp=dragon.max_hp*.55
	await run_for(w,9.0,"orbit")
	dragon.hp=1;w.hurt(dragon,50)
	while w.stage!="exit_portal":await tick(w,Vector2.ZERO)
	await run_for(w,1.5,"")
	while w.stage=="exit_portal":await tick(w,w.player.direction_to(w.portal_position))
	while w.stage!="last_duel":await tick(w,Vector2.ZERO)
	var boss=w.mobs.filter(func(m):return m.kind=="endersteve_final")[0]
	await run_for(w,5.0,"orbit")
	boss.hp=boss.max_hp*.45
	await run_for(w,12.0,"orbit")
	boss.hp=1;w.hurt(boss,50)
	while w.stage!="portal_ready":await tick(w,Vector2.ZERO)
	await run_for(w,1.0,"")
	while w.stage=="portal_ready":await tick(w,w.player.direction_to(w.portal_position))
	while w.state=="RUNNING" and w.stage!="chapter_four":await tick(w,Vector2.ZERO)
	for i in range(60):await shoot(w)
	var timeline={"fps":30,"frames":state.frame,"sound_events":state.cues,"music":state.music,"diagnostic":"invulnerable hero, scripted orbit and kills"}
	FileAccess.open("res://qa/recordings/end_ender_timeline.json",FileAccess.WRITE).store_string(JSON.stringify(timeline,"  "))
	game.audio.shutdown();game.quitting=true
	print("END_ENDER_FILM ",state.frame," frames");quit()

func run_for(w,seconds: float,mode: String):
	for f in range(int(seconds*30)):
		var move:=Vector2.ZERO
		if mode=="orbit":
			var boss=w.mobs.filter(func(m):return m.kind in ["end_dragon","endersteve_final"])
			if not boss.is_empty():
				var target: Vector2=boss[0].p+boss[0].p.direction_to(w.player).rotated(.6*sin(f/30.0*.7))*95
				move=((target-w.player)/30.0).limit_length()
		await tick(w,move)

func tick(w,move: Vector2):
	for i in range(2):
		if w.state=="LEVEL_UP":w.skip_reward()
		if w.state=="CHEST":w.chest_delay=0;w.close_chest()
		if w.stage in ["dragon","last_duel","survival"]:w.invulnerable=maxf(w.invulnerable,.2);w.hp=maxf(w.hp,12)
		w.step(1.0/60,move)
	await shoot(w)

func shoot(w):
	for id in w.sounds:state.cues.append({"id":id,"time":state.frame/30.0})
	w.sounds.clear()
	var theme: String="end" if w.stage=="survival" else "victory" if w.win_music else "silence" if w.stage in ["betrayal","yield","approach"] else "relic" if w.stage in ["to_edge","sit","restore","portal_ready","exit_jump","chapter_four"] else "endersteve" if w.stage in ["last_arrival","last_duel"] else "dragon"
	if theme!=state.last_music:state.last_music=theme;state.music.append({"track":theme,"time":state.frame/30.0})
	game.ui_time+=1.0/30;game.update_camera_lead()
	game.queue_redraw();await process_frame;RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(folder+"/%05d.png"%state.frame);state.frame+=1
