extends SceneTree
## Targeted real-game capture: door → 11 logos → 2Fort → credits.
## No combat, invulnerability, time skips or altered event timings in the film.
var game
var count := 0
var cues: Array = []
var folder := "res://qa/recordings/chapter_five_logos_2fort_frames"
var shots := "res://qa/ch5_worlds_review"
var review := false
func _initialize():run.call_deferred()
func draw_frame() -> Image:
	game.queue_redraw()
	await process_frame
	RenderingServer.force_draw(false)
	return root.get_texture().get_image()
func run():
	review = OS.get_cmdline_user_args().has("--review")
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="film"
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360)
	game.action("chapter_5");game.settings.shake=true
	var w=game.world;var n=w.notch;var f=n.finale
	n.begin(w);n.change("flight");f.change("flight");w.sounds.clear()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shots))
	await draw_frame();await draw_frame()
	if review:
		for i in range(15):
			f.age = 6.5+i*1.8 if i<11 else [2.5,27.8,29.2,30.5][i-11]
			w.clock=f.age
			await draw_frame();var im=await draw_frame();im.save_png(shots+"/actual_%02d.png"%i)
		# Pause must freeze both simulation time and the complete rendered image.
		f.age=29.2;w.clock=29.2;w.state="FINALE"
		await draw_frame();var before=await draw_frame();var clock_before=w.clock
		w.state="PAUSED"
		for k in range(12):w.step(1.0/60,Vector2.ZERO)
		var after=await draw_frame()
		assert(w.clock==clock_before and f.age==29.2,"Paused finale advanced")
		assert(before.get_data()==after.get_data(),"Paused 2Fort image changed")
		w.state="FINALE";w.step(1.0/60,Vector2.ZERO)
		assert(f.age>29.2,"Finale did not resume")
		print("ENDING_REVIEW: 11 logos, arrival frames, pause and resume PASS")
	else:
		while count < 2070:
			for step in range(2):
				w.step(1.0/60,Vector2.ZERO)
				for id in w.sounds:cues.append({"id":id,"time":count/30.0+step/60.0})
				w.sounds.clear()
			game.ui_time+=1.0/30.0
			var im=await draw_frame();im.save_png(folder+"/%05d.png"%count);count+=1
			if count%300==0:print("ENDING_CAPTURE ",count," / 2070")
		var timeline={"fps":30,"frames":count,"sound_events":cues,"music_volume":.5,"effects_volume":.7}
		FileAccess.open("res://qa/recordings/chapter_five_logos_2fort_timeline.json",FileAccess.WRITE).store_string(JSON.stringify(timeline,"  "))
	game.audio.shutdown();game.quitting=true;quit()
