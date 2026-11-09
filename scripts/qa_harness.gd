extends RefCounted
## Capture, stress, autoplay and recording helpers. Never used by an ordinary run.

static func prepare_capture(g):
	if g.qa_mode in ["achievements","achievement_toast"]:
		if g.qa_mode=="achievements":
			g.screen="achievements";g.achievement_tier="all";g.achievement_page=0
			g.achievements.unlocked={"chapter_one":"preview","first_evolution":"preview","full_inventory":"preview"}
		else:g.achievement_toast="first_evolution";g.achievement_toast_age=.3
		return
	if g.qa_mode.begins_with("end_"):
		prepare_end_capture(g)
		return
	if g.qa_mode=="boss_lab":
		for code in [KEY_D,KEY_A,KEY_V,KEY_I,KEY_S,KEY_ENTER]:
			var event=InputEventKey.new();event.physical_keycode=code
			g.secret_input(event)
		g.lab_chapter=2
		return
	if g.qa_mode.begins_with("nether_"):
		prepare_nether_capture(g)
		return
	if g.qa_mode.begins_with("herobrine_") or g.qa_mode in ["finale","portal","fall","chapter_end"]:
		prepare_herobrine_capture(g)
		return
	if g.qa_mode=="menu":return
	g.world.reset(724)
	g.world.time=378
	g.world.level=17
	g.world.hp=16
	g.world.build={"sword":8,"bow":5,"trident":4,"fire":3,"potion":2,"fangs":3}
	g.world.items={"blaze":3,"redstone":2,"amethyst":2,"hopper":2}
	g.world.evolved={"sword":true}
	g.world.kills=286
	for i in range(25):
		var p=g.world.player+Vector2.from_angle(i*2.39)*g.world.rng.randf_range(45,210)
		g.world.spawn(["zombie","skeleton","creeper","spider","slime"][i%5],p)
	for i in range(28):g.world.drop_xp(g.world.player+Vector2.from_angle(i*2.39)*g.world.rng.randf_range(18,180),1)
	g.world.rebuild_hit_grid()
	g.world.swing(Vector2.RIGHT,g.world.db.stats("sword",8,true,g.world.items))
	g.world.add_effect("cloud",g.world.player+Vector2(70,20),3,{"radius":38.0,"damage":3})
	g.world.loot.append({"kind":"chest","p":g.world.player+Vector2(-80,42),"born":g.world.time})
	if g.qa_mode=="level":
		g.world.choices=["bow","potion","amethyst"]
		g.world.state="LEVEL_UP"
	elif g.qa_mode=="pause":g.world.state="PAUSED"
	elif g.qa_mode=="result":
		g.world.state="RESULT"
		g.world.victory=true
		g.world.time=720
	elif g.qa_mode=="chest":
		g.world.evolved={}
		g.world.open_chest({"born":378.0})
		g.world.chest_delay=0
	elif g.qa_mode=="stats": g.toggle_stats()

static func prepare_herobrine_capture(g):
	g.world.reset(724)
	g.world.build={}
	g.world.finale.begin(g.world)
	for i in range(4*60):g.world.step(1.0/60)
	var target={"finale":"storm","portal":"portal","fall":"fall","chapter_end":"end","herobrine_seated":"storm","herobrine_rise":"rising","herobrine_kneel":"kneel","herobrine_rift":"rift","herobrine_wipe":"vanish","herobrine_loss":"fall","herobrine_end":"end"}.get(g.qa_mode,"storm")
	if target!="storm":
		if g.qa_mode=="herobrine_loss":g.world.hp=0
		else:g.world.finale.boss.hp=0
		for i in range(30*60):
			g.world.step(1.0/60)
			if g.world.finale.phase==target:break
	var age:float={"rising":2.6,"kneel":.95,"rift":2.15,"vanish":1.6,"portal":1.5,"fall":2.1}.get(target,.2)
	for i in range(int(age*60)):g.world.step(1.0/60)

static func capture(g):
	await RenderingServer.frame_post_draw
	var img=g.get_viewport().get_texture().get_image()
	var output = "res://qa/"+g.qa_mode+".png" if OS.has_feature("editor") else "user://capture_"+g.qa_mode+".png"
	img.save_png(output)
	print("CAPTURE ", ProjectSettings.globalize_path(output))
	g.quit_game()

static func prepare_stress(g):
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	g.get_window().size=Vector2i(1280,720)
	g.world.reset(724)
	g.world.time=580
	for id in g.world.db.weapons: g.world.build[id]=8
	for id in g.world.db.passives: g.world.items[id]=5
	g.world.evolved={"sword":true,"bow":true,"trident":true}
	for i in range(250):g.world.spawn(["zombie","spider","creeper","slime"][i%4],g.world.player+Vector2.from_angle(i*2.39)*g.world.rng.randf_range(45,250))
	g.world.rebuild_hit_grid()

static func stats_report(g, samples: Array) -> Dictionary:
	var sorted=samples.duplicate()
	sorted.sort()
	var sum=0.0
	for v in sorted:sum+=v
	return {"mean_ms":sum/maxi(1,sorted.size()),"p95_ms":sorted[int(sorted.size()*0.95)] if not sorted.is_empty() else 0,"max_ms":sorted.back() if not sorted.is_empty() else 0}

static func finish_stress(g):
	g.stress_mode=false
	var report={"rendered_frame":stats_report(g,g.frame_samples.slice(60)),"simulation":stats_report(g,g.sim_samples.slice(60)),"samples":g.frame_samples.size()-60,"wall_seconds":g.frame_samples.reduce(func(sum,v):return sum+v,0.0)/1000.0,"renderer":RenderingServer.get_video_adapter_name(),"resolution":str(g.get_window().size),"render_viewport":str(g.get_viewport().get_texture().get_size()),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"enemies":g.world.normal_count(),"all_weapons":8,"all_passives":5,"evolutions":g.world.evolved.keys(),"godot":Engine.get_version_info().string,"executable":OS.get_executable_path()}
	var path="res://qa/performance.json" if OS.has_feature("editor") else "user://performance.json"
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("PERFORMANCE ",JSON.stringify(report))
	g.quit_game()

static func finish_autoplay(g):
	var report={"style":g.autoplay_style,"victory":g.world.victory,"chapter_complete":g.world.finale.complete,"ending":g.world.finale.phase,"time":g.world.time,"hp":g.world.hp,"kills":g.world.kills,"level":g.world.level,"build":g.world.build,"items":g.world.items,"evolved":g.world.evolved,"simulation":stats_report(g,g.sim_samples),"executable":OS.get_executable_path()}
	var path="res://qa/native_run.json" if OS.has_feature("editor") else "user://native_run.json"
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("AUTOPLAY ",JSON.stringify(report))
	g.quit_game()

static func prepare_recording(g):
	g.qa_controller=load("res://scripts/autoplay_bot.gd").new("sword")
	g.world.reset(151)
	if g.recording_stage=="foundation":return
	g.world.build={"sword":3,"bow":1}
	g.world.level=4
	g.world.time=61
	if g.recording_stage in ["combat","evolution"]:
		g.world.build={"sword":8,"bow":6,"trident":5,"fire":4,"potion":4,"fangs":4}
		g.world.items={"blaze":3,"amethyst":2,"redstone":3,"sugar":2,"hopper":2}
		g.world.level=24
		g.world.time=370
		for i in range(55):g.world.spawn(["zombie","spider","creeper","slime","skeleton"][i%5],g.world.player+Vector2.from_angle(i*2.39)*g.world.rng.randf_range(90,240))
		if g.recording_stage=="evolution":
			g.world.open_chest({"born":370.0})
			g.world.chest_delay=0

static func prepare_nether_capture(g):
	g.start_chapter(2)
	g.world.reset(724)
	g.world.build={"sword":8,"axe":8,"hoe":8,"tnt":8,"crossbow":8,"fishing":8}
	g.world.items={"gold_boots":3,"fire_resist":3,"ghast_tear":3,"feather":3,"armor":3,"blaze":3,"redstone":3,"amethyst":3}
	g.world.evolved={"axe":true,"crossbow":true}
	g.world.time=420
	if g.qa_mode.begins_with("nether_ghast"):
		g.world.begin_arena()
		while g.world.stage!="arrival":g.world.step(1.0/60)
		var age:float={"nether_ghast":1.7,"nether_ghast_charge":4.8,"nether_ghast_burst":5.6,"nether_ghast_reveal":7.3}.get(g.qa_mode,1.7)
		for i in range(int(age*60)):g.world.step(1.0/60)
		return
	if g.qa_mode=="nether_portal_camera":
		g.world.prepare_arena();g.world.stage="wither";g.world.ghast.reset()
		g.world.mobs[0].p=Vector2(800,900);g.world.mobs[0].hp=0;g.world.resolve_deaths()
		while g.world.stage=="defeat":g.world.step(1.0/60)
		g.world.player=g.world.loot.filter(func(o):return o.kind=="ender_eye")[0].p
		g.world.pickup(.01)
		for i in range(90):g.world.step(1.0/60)
		return
	if g.qa_mode in ["nether_boss","nether_end"]:
		g.world.begin_arena()
		while g.world.stage!="wither":g.world.step(1.0/60)
		if g.qa_mode=="nether_end":
			g.world.mobs[0].hp=0
			g.world.resolve_deaths()
			while g.world.stage=="defeat":g.world.step(1.0/60)
			g.world.player=g.world.loot.filter(func(o):return o.kind=="ender_eye")[0].p
			g.world.pickup(.01)
			g.world.player=g.world.portal_position+Vector2(40,0)
			g.world.step(.01)
			while g.world.stage=="lighting":g.world.step(1.0/60)
			g.world.player=g.world.portal_position
			g.world.step(.01)
			while g.world.stage in ["jump","crossing"]:g.world.step(1.0/60)
	else:
		for i in range(8):g.world.spawn(["zombified_piglin","piglin_sword","piglin_crossbow","wither_skeleton","blaze_nether","hoglin","zoglin","brute"][i],g.world.player+Vector2(-180+i%4*118,-55+i/4*100))
		g.world.rebuild_hit_grid()
		g.world.update_attacks(.01)
		if g.qa_mode=="nether_inventory":g.toggle_inventory()

static func prepare_end_capture(g):
	if g.qa_mode=="end_victory":
		g.start_chapter(3);g.world.prepare_arena();g.world.mobs.clear();g.world.stage="last_duel";g.world.build={}
		for crystal in g.world.crystals:crystal.alive=false
		g.world.spawn("endersteve_final",g.world.portal_position+Vector2(0,-35));g.world.mobs[0].hp=0;g.world.resolve_deaths()
		g.world.stage_age=7.61;g.world.end_boss.story(g.world,.02);return
	g.start_chapter(3);g.world.reset(724);g.world.state="RUNNING";g.world.stage="survival"
	g.world.build={"sword":8,"spear":8,"mace":8,"end_crystal":8,"knockback_stick":8,"shield":8}
	g.world.items={"elytra":5,"ender_pearl":5,"rabbit_foot":5,"end_eye":5,"shulker_shell":5,"sugar":4,"armor":4,"feather":4}
	g.world.evolved={"spear":true,"mace":true,"shield":true};g.world.shield_charges=7
	g.world.time=480;g.world.level=35;g.world.kills=520
	if g.qa_mode=="end_scale":g.world.stage="end_arrival";return
	if g.qa_mode=="end_choices":g.world.xp=g.world.db.required_xp(g.world.level);g.world.next_level();return
	if g.qa_mode=="end_inventory":g.toggle_inventory();return
	if g.qa_mode=="end_recipes":g.screen="recipes";g.recipe_page=1;return
	if g.qa_mode=="end_overworld":g.world.stage="chapter_four";g.world.stage_age=3;g.world.state="RESULT";return
	if g.qa_mode=="end_shulker":
		g.world.build={};g.world.invulnerable=60
		for i in range(4):
			var at=g.world.player+Vector2.from_angle(i*1.7+.4)*(150+i*20)
			if g.world.on_land(at):g.world.spawn("shulker",at);g.world.mobs.back().timer=i*.4
		for i in range(150):g.world.move_mobs(1.0/60);g.world.update_projectiles(1.0/60);g.world.clock+=1.0/60
		return
	if g.qa_mode in ["end_dragon","end_crystals","end_dragon_rage","end_betrayal","end_last_duel","end_dragon_death","end_rekindle","end_jump","end_steve_death"]:
		g.world.prepare_arena();g.world.stage="dragon";g.world.invulnerable=60
		g.world.build={"sword":8,"spear":8,"mace":8,"end_crystal":8,"knockback_stick":8,"shield":8}
		var dragon=g.world.mobs.back();dragon.p=Vector2(1024,1030);dragon.dir=Vector2.RIGHT;dragon.altitude=40;g.world.scene_camera=Vector2(1024,1040)
		g.world.player=Vector2(1024,1160)
		if g.qa_mode=="end_dragon_rage":
			for t in g.world.crystals:t.alive=false
			dragon.phase_two=true;dragon.hp=dragon.max_hp*.5;dragon.phase="perch";dragon.altitude=0;dragon.timer=5
			g.world.player=Vector2(1170,1190);var saved_build=g.world.build;g.world.build={}
			for i in range(100):g.world.step(1.0/60,Vector2.ZERO)
			g.world.build=saved_build
		elif g.qa_mode=="end_crystals":g.world.player=g.world.crystals[3].p+Vector2(0,20);g.world.update_elevation(0);g.world.scene_camera=g.world.player-Vector2(0,32)
		elif g.qa_mode=="end_dragon_death":g.world.hurt(dragon,20000);dragon.hp=0;g.world.resolve_deaths();g.world.stage_age=2.4
		elif g.qa_mode in ["end_betrayal","end_last_duel","end_rekindle","end_jump","end_steve_death"]:
			g.world.mobs.clear();
			for crystal in g.world.crystals:crystal.alive=false
			g.world.stage="betrayal";g.world.stage_age=3.35;g.world.portal_lit=false;g.world.player=Vector2(1024,1140)
			g.world.add_effect("portal_shatter",g.world.portal_position,3.8,{"radius":100.0});g.world.effects.back().age=.3
			if g.qa_mode=="end_last_duel":
				g.world.stage="last_duel";g.world.effects.clear();g.world.spawn("endersteve_final",Vector2(1024,1020));g.world.mobs.back().phase="cast";g.world.mobs.back().pattern=1;g.world.mobs.back().timer=3
				var saved_build=g.world.build;g.world.build={};g.world.player=Vector2(1130,1180)
				for i in range(140):g.world.step(1.0/60,Vector2.ZERO)
				g.world.build=saved_build
			elif g.qa_mode=="end_rekindle":g.world.stage="rekindle";g.world.stage_age=1.45;g.world.hand_taken=true;g.world.player=g.world.portal_position+Vector2(0,46);g.world.facing=Vector2.UP;g.world.jump_start=g.world.player
			elif g.qa_mode=="end_jump":g.world.stage="exit_jump";g.world.stage_age=0;g.world.portal_lit=true;g.world.jump_start=g.world.portal_position+Vector2(0,35)
			elif g.qa_mode=="end_steve_death":
				g.world.stage="last_duel";g.world.spawn("endersteve_final",g.world.portal_position+Vector2(30,20));g.world.mobs[0].hp=0;g.world.resolve_deaths()
		return
	for i in range(26):
		var p=g.world.player+Vector2.from_angle(i*2.39996)*(60+i%5*36)
		if g.world.on_land(p):g.world.spawn(["endermite","enderman","shulker","dispenser_enderman","endermite_brood","endersteve"][i%6],p)
	g.world.rebuild_hit_grid();g.world.facing=Vector2.RIGHT
	if g.qa_mode=="end_flight":g.world.active_item("rocket");g.world.dash_left=.8
	else:g.world.update_attacks(.01)
	for i in range(35):g.world.update_effects(1.0/60);g.world.update_projectiles(1.0/60)
