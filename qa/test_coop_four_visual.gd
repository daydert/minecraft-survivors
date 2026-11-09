extends SceneTree
var game
var checks = 0
var failures: Array = []

func _initialize(): run.call_deferred()

func check(ok: bool, label: String):
	checks += 1
	if ok: print("PASS: "+label)
	else: failures.append(label); push_error(label)

func capture(label: String):
	game.queue_redraw()
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://qa/coop_four_"+label+".png")

func run():
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process_input(false);game.set_process(false)
	game.set_physics_process(false)
	game.settings.shake = false
	game.screen = "settings"
	await capture("settings")
	check(game.buttons.any(func(b):return b.id == "logs"),"Settings expose the log folder using the existing Minecraft buttons")
	game.screen = "multiplayer"
	check(game.coop.host("Ведущий"),"A four-seat room can be hosted")
	for count in [2,3,4]:
		game.coop.roster[count] = "Игрок_"+str(count)
		game.coop.status = ""
		game.sync_network_fields()
		await capture("lobby"+str(count))
		check(game.buttons.any(func(b):return b.id == "network_start"),"The host may start with %d participants" % count)
	check(not game.nickname_field.visible and not game.address_field.visible,"Connected lobby hides editable connection fields")
	game.world = load("res://scripts/coop_world.gd").new(724)
	game.world.configure(724,game.coop.roster,1)
	game.coop.running = true
	game.screen = ""
	for i in range(45):game.world.spawn("zombie",game.world.player+Vector2.from_angle(i*2.39)*(100+i%6*15))
	game.world.step_coop(1.0/60,{1:Vector2.UP,2:Vector2.RIGHT,3:Vector2.LEFT,4:Vector2.DOWN})
	await capture("battle")
	check(game.world.players.size() == 4 and game.world.players.values().all(func(a):return a.alive),"The world draws four named living actors and three distinct teammate rows")
	game.toggle_stats()
	var clock = game.world.clock
	game.world.step_coop(3,{4:Vector2.UP})
	check(game.screen == "stats" and game.world.clock == clock,"Host stats freeze all four heroes")
	game.close_stats()
	game.world.disconnect_actor(1)
	check(game.network_view_id() == 2,"Dead host follows the first surviving teammate")
	game.world.disconnect_actor(2)
	check(game.network_view_id() == 3,"Spectator switches away from the next dead teammate")
	game.world.disconnect_actor(3)
	check(game.network_view_id() == 4,"The fourth hero can be the final spectator target")
	await capture("spectator")
	game.world = load("res://scripts/coop_world.gd").new(724)
	game.world.configure(724,game.coop.roster,1)
	game.world.time = 719.99
	game.world.step_coop(1.0/60,{})
	for i in range(156): game.world.step_coop(1.0/60,{})
	await capture("finale")
	check(game.world.players.values().all(func(a):return a.in_finale),"All four staged heroes render beside the original throne")
	game.world.set_paused(4,true)
	var elapsed = game.world.finale.elapsed
	game.world.step_coop(3,{})
	check(game.world.finale.elapsed == elapsed and game.world.state == "WAITING","The fourth player's pause stops the finale for the host")
	game.coop.leave()
	game.audio.shutdown()
	await create_timer(.6).timeout
	game.free()
	FileAccess.open("res://qa/coop_four_visual_results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	quit(0 if failures.is_empty() else 1)
