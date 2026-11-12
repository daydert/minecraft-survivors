extends SceneTree
## Targeted checks for the unfinished V review items. No changes to save data.
var game
var failures: Array = []
var checks := 0
var out := "res://qa/ch5_review_fixes/"
func _initialize():run.call_deferred()
func check(ok: bool, label: String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
	else:print("PASS ",label)
func render(name := "") -> Image:
	game.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(false)
	var im=root.get_texture().get_image()
	if not name.is_empty():im.save_png(out+name+".png")
	return im
func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false)
	game.qa_mode="review";game.settings.shake=false;root.size=Vector2i(640,360)
	game.action("chapter_5")
	var w=game.world;var n=w.notch
	check(game.ch5_music()=="chapter_four_end:ch5_ambient","V survival selects its own ambient track")
	n.begin(w);n.start_lanes(w)
	for c in range(8):
		n.redstone=999;n.card=c;n.card_ready[c]=0;n.cursor=Vector2i(c,2);n.lane_press(w,"accept")
	await render("pvz")
	check(game.textures.icon_pvz_dispenser.get_size()==Vector2(32,32),"Blocks use native-size 32px projections")
	check(game.textures.icon_pvz_snow_golem.get_size()==Vector2(40,48),"Whole snow golem and unclipped arms")
	# All five gates must hold exactly, including the shader and particle pool.
	for phase in ["to_ut","to_lanes","lanes_won","to_quake","to_code"]:
		n.change(phase);n.age=1.3;w.clock=40.3
		await render(phase)
		var v=game.get_meta("ch5_view3d")
		await render()
		var before: Image=v.viewport.get_texture().get_image();var transform: Transform3D=v.nodes.portal_rim.transform
		w.state="PAUSED"
		for k in range(30):w.step(1.0/60,Vector2.ZERO)
		await render()
		var after: Image=v.viewport.get_texture().get_image()
		check(n.age==1.3 and w.clock==40.3 and before.get_data()==after.get_data(),phase+" exact pause image")
		check(v.nodes.portal_rim.transform.is_equal_approx(transform),phase+" rim does not accumulate rotation")
		w.state="RUNNING";w.sounds.clear();w.sound_times.clear();n.age=0;n.cues=0
		for k in range(264):w.step(1.0/60,Vector2.ZERO)
		check(w.sounds.has("ch5_portal_open") and w.sounds.has("ch5_portal_pass"),phase+" passage sound cues")
	# Whole-character clones are absent even on the fastest active attack.
	n.start_fighter(w);var fi=n.fighter
	fi.ai=false;fi.state="fight";fi.age=1.0
	fi.steve().move="dash";fi.steve().t=.13
	await render("dash")
	var v=game.get_meta("ch5_view3d")
	check(v.rigs.size()==2 and not v.nodes.has("ghosts_steve"),"Exactly two fighter rigs, including dash")
	fi.steve().move="sweep";fi.steve().crouch=true;fi.steve().block=true;fi.steve().stun=.8;fi.notch().hp=0
	fi.check_end()
	check(fi.winner==0 and not fi.steve().crouch and not fi.steve().block and fi.steve().move.is_empty(),"K.O. clears the winning low attack and held input")
	for k in range(20):
		fi.step(1.0/60,Vector2.ZERO)
		await render()
	await render("winner")
	var r: Dictionary=v.rigs.steve
	check(r.hips.position.y>.65 and absf(r.rl.rotation.x)<.4 and absf(r.ll.rotation.x)<.4,"Winner stands on two legs")
	# Density and warning checks for the already strengthened battle-box rules.
	n.start_ut(w);n.ut_wave=2;n.begin_wave(w);w.invulnerable=0
	n.ut_timer=2.0;n.wave_bullets(w,1.0/60)
	check(n.serial>=8 and n.ut_serial2>0,"Third wave combines both attack patterns")
	n.ut_bullets.clear();n.ut_blasters.clear();n.spawn_pattern(w,2,2)
	var ring: Dictionary=n.ut_bullets.back()
	check(ring.get("arm_at",0.0)>=.4,"Expanding ring gives an escape warning before damage")
	n.ut_bullets.clear();n.spawn_pattern(w,6,1)
	var warning: Dictionary=n.ut_bullets.back()
	check(warning.delay>=.45 and warning.drop>=400,"Anvil keeps a warning before the faster drop")
	await render("anvil_warning")
	n.start_ut(w);n.ut_wave=3;n.begin_wave(w)
	for k in range(150):n.step(w,1.0/60,Vector2.RIGHT if k%80<40 else Vector2.LEFT)
	await render("undertale")
	for key in ["ch5_portal_open","ch5_portal_pass","ch5_ut_charge"]:check(game.audio.sound_map.has(key),key+" loads in runtime audio map")
	n.change("retry");n.retry_of="fighter"
	check(game.ch5_music()=="chapter_four_end:ch5_fighter","Checkpoint retains the current game's music")
	game.audio.set_music_context(game.ch5_music(),true);game.audio._process(1.0)
	check(game.audio.music.stream_paused and game.audio.end_track=="ch5_music/fight_phase2","Generic playlist is muted during V music")
	game.audio.shutdown();game.quitting=true
	FileAccess.open(out+"summary.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("CH5_REVIEW_FIXES ",checks," checks; ",failures.size()," failures")
	quit(1 if not failures.is_empty() else 0)
