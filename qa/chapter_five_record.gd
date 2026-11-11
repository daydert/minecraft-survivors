extends SceneTree
## Diagnostic film of chapter V stage A: the three tones, code enemies and
## world events. Strong build, bot movement, time jumps between segments.
var game
var folder:="res://qa/recordings/chapter_five_frames"
var state:={"frame":0,"cues":[],"music":[{"track":"music","time":0.0}]}
var bot=SurvivorBot.new("sword")
func _initialize():run.call_deferred()
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="film"
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	game.action("chapter_5");var w=game.world;game.settings.shake=true;game.settings.numbers=false
	jump(w,60.0,{"debug_stick":5});await segment(w,8.0)
	jump(w,100.0,{"command_block":5});await segment(w,9.0)
	jump(w,150.0,{"barrier":6,"debug_stick":4});await segment(w,8.0)
	jump(w,200.0,{"structure_block":6,"barrier":3});await segment(w,9.0)
	jump(w,250.0,{"spawn_egg":6,"debug_stick":5});await segment(w,9.0)
	w.items={"knowledge_book":1,"chain_block":1,"light_block":2,"structure_void":1,"name_tag":1,"recovery_compass":1}
	for id in ["debug_stick","command_block","barrier","structure_block","spawn_egg"]:w.evolved[id]=true
	jump(w,380.0,{"debug_stick":8,"command_block":8,"barrier":8,"structure_block":8,"spawn_egg":8,"sword":6});await segment(w,16.0)
	jump(w,520.0,{"debug_stick":8,"command_block":8,"barrier":8,"structure_block":8,"spawn_egg":8,"sword":8});await segment(w,14.0)
	var timeline={"fps":30,"frames":state.frame,"sound_events":state.cues,"music":state.music}
	FileAccess.open("res://qa/recordings/chapter_five_timeline.json",FileAccess.WRITE).store_string(JSON.stringify(timeline,"  "))
	game.audio.shutdown();game.quitting=true
	print("CHAPTER_FIVE_FILM ",state.frame," frames");quit()

func jump(w,time: float,build: Dictionary):
	w.time=time;w.build=build;w.level=int(time/14);w.arsenal.allies.clear()
	for id in w.next_event:w.next_event[id]=maxf(w.next_event[id],time+60.0)
	for id in build:
		if not w.cooldowns.has(id):w.cooldowns[id]=0.3
	for k in range(int(8+time/30)):
		var wave=w.db.wave(time);var kinds=wave.weights.keys()
		w.spawn(kinds[k%kinds.size()],w.player+Vector2.from_angle(k*2.4)*(170+k%5*30))

func segment(w,seconds: float):
	for f in range(int(seconds*30)):
		for i in range(2):
			if w.state=="LEVEL_UP":w.skip_reward()
			if w.state=="CHEST":w.chest_delay=0;w.close_chest()
			w.hp=maxf(w.hp,14)
			var move: Vector2=bot.movement(w)
			if w.invert>0:move=-move
			w.step(1.0/60,move)
		for id in w.sounds:state.cues.append({"id":id,"time":state.frame/30.0})
		w.sounds.clear()
		game.ui_time+=1.0/30
		game.queue_redraw();await process_frame;RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(folder+"/%05d.png"%state.frame);state.frame+=1
