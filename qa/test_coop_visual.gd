extends SceneTree
var game
var checks = 0
var failures: Array = []

func _initialize(): run.call_deferred()

func check(ok: bool, label: String):
	checks += 1
	if not ok: failures.append(label); push_error(label)
	else: print("PASS: "+label)

func capture(label: String):
	game.queue_redraw()
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://qa/coop_"+label+".png")

func run():
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process_input(false);game.set_process(false)
	game.set_physics_process(false)
	root.size = Vector2i(1280,720)
	game.settings.shake = false
	await capture("menu")
	check(game.buttons.map(func(b):return b.id) == ["chapters","multiplayer","settings","quit"],"Main menu contains the requested fourth vanilla button")
	game.action("multiplayer")
	game.nickname_field.text = "Друг_123"
	game.address_field.text = "10.147.17.42"
	await capture("connect")
	check(game.nickname_field.visible and game.address_field.visible,"Native editable nickname and IP fields appear on the connection screen")
	check(game.nickname_field.get_theme_font("font") == game.font,"Editable fields use the same Minecraft bitmap font")
	game.action("network_host")
	game.coop.roster[2] = "Друг_123"
	await capture("lobby")
	check(not game.nickname_field.visible and game.buttons.any(func(b):return b.id == "network_start"),"Two-person lobby shows start and hides editable fields")
	game.world = load("res://scripts/coop_world.gd").new(724)
	game.world.configure(724,{1:"Ведущий",2:"Друг_123"},1)
	game.coop.running = true
	game.screen = ""
	game.world.players[2].player += Vector2(50,-12)
	for i in range(45):game.world.spawn("zombie",game.world.player+Vector2.from_angle(i*2.39)*(90+i%6*15))
	game.world.step_coop(1.0/60,{1:Vector2.UP,2:Vector2.LEFT})
	await capture("battle")
	check(game.world.players[1].alive and game.world.players[2].alive,"Both named actors render in the live world")
	game.toggle_stats()
	await capture("stats")
	check(game.screen == "stats" and not game.world.can_step(),"L's black stats screen pauses the common arena")
	game.close_stats()
	check(game.world.can_step(),"Closing stats restores the previous running state")
	game.world.set_paused(1,true)
	game.toggle_stats()
	game.close_stats()
	check(game.world.state == "PAUSED" and not game.world.can_step(),"Stats opened from pause retain that exact pause")
	game.world.set_paused(1,false)
	game.world.open_chest({"born":0.0})
	game.world.players[1].phase = "CHEST"
	game.world.save_actor()
	game.toggle_stats()
	var reveal = game.world.chest_delay
	game._process(1)
	game.close_stats()
	check(game.world.state == "CHEST" and game.world.chest_delay == reveal,"Stats pause preserves the exact chest reveal and returns to that chest")
	game.world.chest_for(1)
	game.world.chest_for(1)
	game.world.disconnect_actor(1)
	await capture("spectator")
	check(game.world.state == "SPECTATING","Dead local player sees spectator HUD and living partner")
	game.world.time = 719.99
	game.world.step_coop(1.0/60,{})
	for i in range(1540):game.world.step_coop(1.0/60,{})
	await capture("finale")
	check(game.world.finale.active and game.world.finale.phase == "collapse","Dead player watches the survivor's original finale")
	game.coop.leave()
	game.audio.shutdown()
	await create_timer(.6).timeout
	game.free()
	FileAccess.open("res://qa/coop_visual_results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	quit(0 if failures.is_empty() else 1)
