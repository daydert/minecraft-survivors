extends SceneTree
var game
func _initialize():run.call_deferred()
func percentile(values: Array,p: float):
	values.sort();return values[mini(values.size()-1,int(values.size()*p))]
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="iv_pressure"
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360)
	game.start_chapter(4);var w=game.world;w.reset(724);w.stage="survival";w.state="RUNNING";w.build={};w.db.data.chapter_four.exploration_only=true;w.note_presented=true
	var kinds=["flayed_zombie","growth_skeleton","torn_spider","bloated_creeper","hungry_wolf","matted_sheep","fused_villagers","infected_witch","crawler","open_cow"]
	for i in range(150):w.spawn(kinds[i%kinds.size()],w.player+Vector2.from_angle(i*2.39996)*(60+i%6*20))
	var sim: Array=[];var draw: Array=[];var peak: int=w.mobs.size()
	for i in range(240):
		w.invulnerable=1;w.xp=0;w.state="RUNNING"
		var begin=Time.get_ticks_usec();w.step(1.0/60,Vector2.from_angle(i*.012));var elapsed=(Time.get_ticks_usec()-begin)/1000.0
		begin=Time.get_ticks_usec();game.queue_redraw();await process_frame;RenderingServer.force_draw(false)
		if i>=30:sim.append(elapsed);draw.append((Time.get_ticks_usec()-begin)/1000.0)
		peak=maxi(peak,w.mobs.size())
	var result={"frames":240,"peak_mobs":peak,"last_mobs":w.mobs.size(),"sim_p50_ms":percentile(sim,.5),"sim_p95_ms":percentile(sim,.95),"draw_and_frame_wait_p50_ms":percentile(draw,.5),"draw_and_frame_wait_p95_ms":percentile(draw,.95),"clock_seconds":w.clock,"invulnerability_for_measurement":true,"natural_run":false}
	FileAccess.open("res://qa/chapter_four_b/pressure.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("CHAPTER_FOUR_PRESSURE_RESULT ",JSON.stringify(result));game.audio.shutdown();game.quitting=true;quit()
