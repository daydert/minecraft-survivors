extends SceneTree
## Diagnostic film: ordinary rendered mechanics, scripted scene placement and capture-only immunity.
var game
var frame=0
var shots=[]
var cues=[]
var cue_times={}
func _initialize():run.call_deferred()
func film(mode: String, seconds: float, movement: Vector2=Vector2.ZERO):
	game.screen="";game.qa_mode=mode;game.prepare_end_capture()
	var w=game.world;w.invulnerable=999;w.sounds.clear()
	if mode=="end_survival":w.stage_age=5
	if mode in ["end_dragon_death","end_rekindle","end_betrayal"]:w.stage_age=0
	if mode=="end_betrayal":w.portal_lit=true;w.effects.clear()
	if mode=="end_last_duel":
		w.build={};w.items={};w.mobs[0].phase="walk";w.mobs[0].pattern=-1;w.mobs[0].timer=.2
	if mode=="end_steve_death":w.player=w.portal_position+Vector2(-100,100)
	shots.append({"mode":mode,"at":frame/30.0,"seconds":seconds})
	for i in range(int(seconds*30)):
		if w.state=="LEVEL_UP" and mode!="end_choices":w.choose(0);w.tick_choices(1.0/30)
		if mode in ["end_survival","end_flight","end_dragon","end_dragon_rage","end_last_duel","end_betrayal","end_dragon_death","end_steve_death","end_rekindle","end_jump"]:
			w.invulnerable=999
			var input=movement if mode!="end_survival" else Vector2.from_angle(i*.025)
			if mode=="end_last_duel":
				input=w.player.direction_to(w.portal_position+Vector2.from_angle(i*.025)*120)
				if i==510:w.mobs[0].hp=w.mobs[0].max_hp*.48
			if mode=="end_steve_death":
				if w.stage=="hand" and not w.loot.is_empty():input=w.player.direction_to(w.loot[0].p)
				elif w.stage in ["return_portal","portal_ready"]:input=w.player.direction_to(w.portal_position)
			w.step(1.0/30,input)
		elif mode=="end_choices":
			if i==52:w.choose(4)
			w.tick_choices(1.0/30)
		else:
			w.clock+=1.0/30;w.stage_age+=1.0/30
			if mode=="end_betrayal":w.update_effects(1.0/30)
		for id in w.sounds:
			var at=frame/30.0
			if at-cue_times.get(id,-10)>.16:cues.append({"id":id,"time":at});cue_times[id]=at
		w.sounds.clear()
		game.queue_redraw();await process_frame;RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://qa/end_film/%06d.png" % frame);frame+=1
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.settings.shake=false;game.settings.numbers=false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/end_film"))
	await film("end_survival",3)
	await film("end_flight",2,Vector2.RIGHT)
	await film("end_choices",3)
	await film("end_crystals",2)
	await film("end_dragon",6)
	await film("end_dragon_rage",6,Vector2.LEFT)
	await film("end_dragon_death",4.8)
	await film("end_betrayal",8.7)
	await film("end_last_duel",34)
	await film("end_steve_death",17)
	await film("end_overworld",3)
	FileAccess.open("res://qa/end_recording.json",FileAccess.WRITE).store_string(JSON.stringify({"fps":30,"frames":frame,"shots":shots,"diagnostic_immunity":true,"scripted_placement":true,"manual_finale_input":true,"sound_events":cues},"  "))
	game.audio.shutdown();game.coop.diagnostics.close();game.quitting=true;quit()
