extends SceneTree
## Diagnostic montage of real Godot gameplay, not a full boss completion run.
## Starts selected waves/round states explicitly to make each repair reviewable.
var game
var frames := 0
var cues: Array = []
var music: Array = []
var segments: Array = []
var folder := "res://qa/recordings/chapter_five_review_fixes_frames"
func _initialize():run.call_deferred()
func mark_segment(name: String):segments.append({"name":name,"time":frames/30.0})
func shoot(w):
	for id in w.sounds:cues.append({"id":id,"time":frames/30.0})
	w.sounds.clear()
	var track: String=game.ch5_music()
	if music.is_empty() or music[-1].track!=track:music.append({"track":track,"time":frames/30.0})
	game.ui_time+=1.0/30;game.queue_redraw()
	await process_frame;RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(folder+"/%05d.png"%frames);frames+=1
func tick(w,move:=Vector2.ZERO):
	for k in range(2):w.step(1.0/60,move)
	await shoot(w)
func idle(w,seconds: float,move:=Vector2.ZERO):
	for k in range(roundi(seconds*30)):await tick(w,move)
func passage(w,phase: String):
	w.notch.change(phase);mark_segment(phase)
	await idle(w,4.4)
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="film"
	root.size=Vector2i(640,360);game.settings.shake=true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	game.action("chapter_5");var w=game.world;var n=w.notch
	n.begin(w)
	await passage(w,"to_ut")
	for wave in [1,2,4,7,8]:
		n.start_ut(w);w.hp=20;w.invulnerable=0
		n.ut_wave=wave-1;n.begin_wave(w);mark_segment("ut_wave_%d"%wave)
		for k in range(90):
			var movement=Vector2(sin(k*.08),-1 if wave==2 and k%28<14 else 0)
			await tick(w,movement)
	await passage(w,"to_lanes")
	n.start_lanes(w);mark_segment("pvz_native_blocks")
	for c in range(8):
		n.redstone=999;n.card=c;n.card_ready[c]=0;n.cursor=Vector2i(c,2);n.lane_press(w,"accept")
	for r in range(5):
		if r==2:continue
		n.redstone=999;n.card_ready[0]=0;n.card=0;n.cursor=Vector2i(2,r);n.lane_press(w,"accept")
	for r in range(5):n.spawn_walker(w,["zombie","skeleton","vindicator","spider","elite"][r],r,570+r*8)
	await idle(w,8.0)
	await passage(w,"lanes_won")
	n.start_fighter(w);var fi=n.fighter;fi.ai=false;mark_segment("fighter_no_clones")
	await idle(w,2.4)
	for attack in ["dash","jab","spin","dash","kick","sweep"]:
		fi.steve().x=-1;fi.notch().x=4;fi.steve().stun=0;fi.steve().cool=0;fi.steve().move=""
		fi.start(fi.steve(),attack)
		await idle(w,.8,Vector2.RIGHT if attack=="dash" else Vector2.ZERO)
	fi.steve().move="sweep";fi.steve().crouch=true;fi.notch().hp=0
	fi.check_end();mark_segment("winner_standing")
	await idle(w,2.2)
	await passage(w,"to_quake")
	await idle(w,1.0)
	await passage(w,"to_code")
	await idle(w,1.0)
	var timeline={"fps":30,"frames":frames,"sound_events":cues,"music":music,"music_volume":.45,"effects_volume":.65,"diagnostic_montage":true,"segments":segments}
	FileAccess.open("res://qa/recordings/chapter_five_review_fixes_timeline.json",FileAccess.WRITE).store_string(JSON.stringify(timeline,"  "))
	game.audio.shutdown();game.quitting=true
	print("CH5_REVIEW_FILM ",frames," frames");quit()
