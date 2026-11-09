extends SceneTree
func _initialize():run.call_deferred()
func run():
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360)
	var timeline=await game.QAHarness.record_four_arsenal(game,self)
	FileAccess.open("res://qa/recordings/chapter_four_c_timeline.json",FileAccess.WRITE).store_string(JSON.stringify(timeline,"  "))
	game.audio.shutdown();game.quitting=true;quit()
