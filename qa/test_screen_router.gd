extends SceneTree
## Nested overlays return to the exact screen and world state they were opened from.
var failures=[]
var checks=0
var game
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
	else:print("PASS: "+label)
func key(k, physical:=false):
	var e=InputEventKey.new();e.pressed=true
	if physical:e.physical_keycode=k
	else:e.keycode=k
	game.input_lock=0
	game._input(e)
func run():
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.action("chapters")
	game.action("achievements")
	check(game.screen=="achievements" and game.world.state=="MENU","Achievements open above chapter choice without pausing the menu")
	key(KEY_ESCAPE)
	check(game.screen=="chapters" and game.world.state=="MENU","Esc returns to chapter choice")
	game.action("chapter_1")
	check(game.screen.is_empty() and game.world.state=="RUNNING" and game.router.depth()==0,"Starting a chapter clears the overlay stack")
	game.world.state="LEVEL_UP"
	key(KEY_I)
	check(game.screen=="inventory" and game.world.state=="PAUSED","Inventory pauses a level-up")
	game.action("recipes")
	check(game.screen=="recipes" and game.router.depth()==2,"Recipes open above the inventory")
	key(KEY_ESCAPE)
	check(game.screen=="inventory" and game.world.state=="PAUSED","Esc from recipes returns to the inventory")
	game.action("recipes")
	game.action("recipes_back")
	check(game.screen=="inventory","Back from recipes returns to the inventory")
	key(KEY_ESCAPE)
	check(game.screen.is_empty() and game.world.state=="LEVEL_UP","Closing the inventory restores the exact level-up state")
	game.world.state="FINALE"
	key(KEY_L)
	check(game.screen=="stats" and game.world.state=="PAUSED","Stats pause the finale")
	key(KEY_L)
	check(game.screen.is_empty() and game.world.state=="FINALE","Stats return to the finale")
	game.world.state="RUNNING"
	key(KEY_ESCAPE)
	check(game.world.state=="PAUSED" and game.pause_from=="RUNNING","Esc pauses the run")
	game.action("achievements")
	check(game.screen=="achievements" and game.world.state=="PAUSED","Achievements open from pause")
	for k in [KEY_D,KEY_A,KEY_V,KEY_I,KEY_S,KEY_ENTER]:key(k,true)
	check(game.screen=="boss_lab" and game.router.depth()==2,"Boss lab stacks above achievements")
	key(KEY_ESCAPE)
	check(game.screen=="achievements","Esc from boss lab returns to achievements")
	key(KEY_ESCAPE)
	check(game.screen.is_empty() and game.world.state=="PAUSED","Esc from achievements returns to pause")
	game.action("resume")
	check(game.world.state=="RUNNING","Resume continues the run")
	game.action("pause")
	game.action("settings")
	game.action("back")
	check(game.screen.is_empty() and game.world.state=="PAUSED","Settings return to pause")
	print("ROUTER_RESULT %d checks; %d failures" % [checks,failures.size()])
	game.free()
	quit(1 if failures.size()>0 else 0)
