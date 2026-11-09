extends SceneTree
var failures=[]
var checks=0
var game
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
	else:print("PASS: "+label)
func key(k):
	var e=InputEventKey.new();e.keycode=k;e.pressed=true
	game.input_lock=0
	game._input(e)
func run():
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(game.world.state=="MENU","Boot reaches main menu")
	game.action("start")
	check(game.world.state=="RUNNING","Play starts a real run")
	key(KEY_ESCAPE)
	check(game.world.state=="PAUSED","Esc pauses")
	game.world.step(10,Vector2.RIGHT)
	check(game.world.time==0,"Pause freezes active time")
	game.action("settings")
	check(game.screen=="settings","Settings open from pause")
	game.action("numbers")
	game.action("numbers")
	key(KEY_ESCAPE)
	check(game.screen.is_empty() and game.world.state=="PAUSED","Esc returns from settings to pause")
	key(KEY_ESCAPE)
	check(game.world.state=="RUNNING","Esc resumes")
	game._focus_lost()
	check(game.world.state=="PAUSED","Focus loss pauses without auto-resume")
	game.action("resume")
	game.world.xp=30
	game.world.next_level()
	var old=game.world.level
	key(KEY_1)
	check(game.world.level==old+1 and game.world.state=="LEVEL_UP","Keyboard 1 handles one queued level only")
	while game.world.state=="LEVEL_UP":key(KEY_1)
	check(game.world.state=="RUNNING","Queued level-ups return to battle")
	game.world.open_chest({"born":0.0})
	game.action("chest")
	check(game.world.state=="CHEST" and game.world.chest_delay==0,"First chest press skips reveal only")
	game.action("chest")
	check(game.world.state=="RUNNING","Second chest press continues")
	game.world.hp=0
	game.world.step(1.0/60)
	check(game.world.state=="RESULT" and not game.world.victory,"Death reaches result")
	game.action("retry")
	check(game.world.hp==20 and game.world.time==0 and game.world.level==1,"Retry starts a clean game")
	game.action("menu")
	check(game.world.state=="MENU","Return to menu")
	FileAccess.open("res://qa/ui_results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("UI_RESULT ",checks," checks; ",failures.size()," failures")
	game.set_process_input(false);game.set_process(false)
	game.set_physics_process(false)
	game.world.sounds.clear()
	game.audio.shutdown()
	await create_timer(0.5).timeout
	game.free()
	game=null
	await process_frame
	await create_timer(0.1).timeout
	quit(0 if failures.is_empty() else 1)
