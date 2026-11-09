extends RefCounted
## Capture, stress, autoplay and recording helpers. Never used by an ordinary run.

static func prepare_capture(g):
	if g.qa_mode.begins_with("ch4c_"):
		prepare_four_arsenal_capture(g)
		return
	if g.qa_mode.begins_with("ch4e_"):
		prepare_four_finale_capture(g)
		return
	if g.qa_mode.begins_with("ch4d_"):
		prepare_four_encounter_capture(g)
		return
	if g.qa_mode.begins_with("ch4b_"):
		prepare_four_enemies_capture(g)
		return
	if g.qa_mode.begins_with("ch4_"):
		prepare_four_capture(g)
		return
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
	g.world=g.OW.new()
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
	if g.qa_mode=="dawn":g.world.time=700
	if g.qa_mode=="dusk":g.world.time=20
	if g.qa_mode=="low_hp":g.world.hp=3
	if g.qa_mode.begins_with("landmark_"):
		var kind: String=g.qa_mode.trim_prefix("landmark_")
		for mark in g.world.landmarks:
			if mark.kind==kind:g.world.player=mark.p+Vector2(30,70);g.world.time=40
		g.world.mobs.clear()
		return
	if g.qa_mode in ["blood_moon","witches","phantoms","fog"]:
		g.world.mobs.clear()
		g.world.time={"blood_moon":372.0,"witches":300.0,"phantoms":560.0,"fog":190.0}[g.qa_mode]
		for i in range(10):g.world.spawn(["zombie","skeleton","spider"][i%3],g.world.player+Vector2.from_angle(i*0.9)*(90+i*12))
		if g.qa_mode=="witches":
			for i in range(3):g.world.spawn("witch",g.world.player+Vector2.from_angle(i*2.1+.3)*150)
		if g.qa_mode=="phantoms":
			for i in range(3):g.world.spawn("phantom",g.world.player+Vector2.from_angle(i*2.1)*130)
		g.world.state="RUNNING";g.world.invulnerable=999
		for i in range(150):g.world.step(1.0/60)
		g.world.invulnerable=0
		return
	if g.qa_mode=="level":
		g.world.choices=["bow","potion","amethyst"]
		g.world.state="LEVEL_UP"
	elif g.qa_mode=="pause":g.world.state="PAUSED"
	elif g.qa_mode=="result":
		g.world.state="RUNNING";g.world.invulnerable=999
		for i in range(900):g.world.step(1.0/60)
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
		if g.qa_mode=="nether_bastion":
			g.world.mobs.clear();g.world.time=365;g.world.state="RUNNING";g.world.invulnerable=999
			g.world.player=g.world.bastion.p+Vector2(0,150)
			for i in range(60):g.world.step(1.0/60,Vector2.UP)
			for i in range(420):g.world.step(1.0/60)
			g.world.invulnerable=0

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
	if g.qa_mode in ["end_city","end_gust"]:
		g.world.mobs.clear();g.world.invulnerable=999
		if g.qa_mode=="end_city":g.world.player=g.world.city.p+Vector2(0,30);g.world.last_safe=g.world.player
		else:
			g.world.time=260;g.world.gust.timer=0.01
			for i in range(14):
				var at=g.world.player+Vector2.from_angle(i*.45)*(60+i*9)
				if g.world.on_land(at):g.world.spawn("endermite",at)
		for i in range(100 if g.qa_mode=="end_city" else 95):g.world.step(1.0/60)
		return
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

static func prepare_four_capture(g):
	g.start_chapter(4)
	g.world.reset(724)
	var w = g.world
	w.state = "RUNNING";w.stage = "survival";w.clock = 18.0;w.stage_age = 18.0
	g.cam_lead = Vector2.ZERO
	if g.qa_mode == "ch4_arrival":w.stage = "arrival";w.stage_age = 2.4;w.clock = 2.4
	elif g.qa_mode in ["ch4_village","ch4_rage","ch4_note"]:
		w.player = Vector2(625,810)
		if g.qa_mode == "ch4_rage":w.read_note()
		w.update_aura()
		if g.qa_mode == "ch4_note":g.router.open("ch4_note",w)
	elif g.qa_mode in ["ch4_pool","ch4_hand","ch4_warning"]:
		w.player = Vector2(1322,690)
		if g.qa_mode != "ch4_pool":
			w.blood_hand = {"p":Vector2(1302,670),"age":1.65 if g.qa_mode == "ch4_hand" else 1.1,"caught":g.qa_mode == "ch4_hand"}
	elif g.qa_mode in ["ch4_pyramid","ch4_chain","ch4_unlit"]:
		w.player = Vector2(1454,1538)
		if g.qa_mode == "ch4_unlit":g.settings.lighting = false
		if g.qa_mode == "ch4_chain":
			for m in w.threats:
				if m.kind == "torch" and m.p.y>1400:
					m.attack = "windup";m.timer = .3
					for other in w.threats:
						if other.kind == "torch" and other.id != m.id and other.p.distance_to(m.p)<100:m.link=other.id;break
	w.update_flow()

## Review film uses explicit camera cuts. It is never a full-run/boss proof.
static func record_four(g, tree: SceneTree) -> Dictionary:
	var frame := 0
	var cues: Array = []
	var segments: Array = []
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/recordings/chapter_four_frames"))
	for shot in [{"mode":"arrival","seconds":3.0},{"mode":"village","seconds":4.0},{"mode":"note","seconds":3.0},{"mode":"rage","seconds":4.0},{"mode":"pool","seconds":5.0},{"mode":"chain","seconds":4.0},{"mode":"growth","seconds":6.0}]:
		g.qa_mode = "ch4_"+shot.mode
		prepare_four_capture(g)
		g.settings.shake = false
		var w = g.world
		w.build = {}
		if shot.mode == "pool":w.hand_cooldown = .4
		if shot.mode == "growth":
			var growth = w.threats.filter(func(m):return m.kind == "growth")[0]
			w.player = growth.p+Vector2(100,10);growth.timer = .4
			w.update_flow()
		segments.append({"mode":shot.mode,"time":frame/30.0})
		for i in range(int(shot.seconds*30)):
			var direction := Vector2.ZERO
			if shot.mode == "growth" and i>90:
				w.build = {"sword":8};direction = Vector2.LEFT if i<145 else Vector2.ZERO
			for tick in range(2):
				if w.state == "LEVEL_UP":w.skip_reward()
				w.step(1.0/60,direction)
			for id in w.sounds:cues.append({"id":id,"time":frame/30.0})
			w.sounds.clear()
			g.queue_redraw();await tree.process_frame;RenderingServer.force_draw(false)
			tree.root.get_texture().get_image().save_png("res://qa/recordings/chapter_four_frames/%05d.png"%frame)
			frame+=1
	return {"fps":30,"frames":frame,"segments":segments,"sound_events":cues,"diagnostic_cuts":true,"invulnerability":false,"content_stage":"A"}

static func prepare_four_enemies_capture(g):
	g.start_chapter(4);g.world.reset(724)
	var w=g.world
	w.state="RUNNING";w.stage="survival";w.clock=20;w.time=0
	w.db.data.chapter_four.exploration_only=true;w.build={};w.note_presented=true
	g.cam_lead=Vector2.ZERO;g.settings.lighting=true;g.settings.shake=false
	var mode: String=g.qa_mode.trim_prefix("ch4b_")
	if mode in ["gallery","unlit"]:
		var i:=0
		for kind in w.db.data.forms:
			w.spawn(kind,w.player+Vector2(-205+(i%5)*103,-90+(i/5)*78));i+=1
		for m in w.mobs:m.timer=10;m.dir=Vector2.DOWN
		if mode=="unlit":g.settings.lighting=false
	elif mode=="crowd":
		var kinds=["flayed_zombie","growth_skeleton","torn_spider","hungry_wolf","matted_sheep","fused_villagers"]
		for i in range(48):w.spawn(kinds[i%kinds.size()],w.player+Vector2.from_angle(i*2.39996)*(75+i%5*22))
		w.build={"sword":8,"bow":6,"axe":5};w.items={"armor":3,"redstone":2};w.facing=Vector2.UP
	elif mode=="flock":w.player=Vector2(845,940)
	else:
		var kinds={"skeleton":"growth_skeleton","cow":"open_cow","spider":"torn_spider","rider":"bone_rider","grave":"gravedigger","bell":"bellringer","witch":"infected_witch","cyst":"bloated_creeper","mutations":"matted_sheep"}
		var kind: String=kinds[mode]
		w.spawn(kind,w.player+Vector2(-95,-20) if mode!="cyst" else w.player+Vector2(20,0))
		var m=w.mobs.back();m.timer=0;m.dir=m.p.direction_to(w.player)
		if mode=="witch":w.spawn("flayed_zombie",m.p+Vector2(35,5));w.mobs.back().hp=2
		if mode=="bell":
			for j in range(3):w.spawn("flayed_zombie",m.p+Vector2(35+j*24,40))
		if mode=="mutations":
			w.hurt(m,m.max_hp*.6);w.spawn("fused_villagers",w.player+Vector2(75,-20));w.hurt(w.mobs.back(),w.mobs.back().max_hp*.6)
	w.rebuild_hit_grid();w.update_flow()
	var preview: float={"skeleton":.56,"cow":.65,"spider":.85,"rider":.7,"grave":1.35,"bell":.8,"witch":.55,"cyst":1.3,"mutations":.1,"crowd":.4}.get(mode,0.0)
	for i in range(ceili(preview*60)):w.step(1.0/60)
	w.Enemies.poses(w)

static func record_four_enemies(g,tree: SceneTree) -> Dictionary:
	var frame:=0;var cues: Array=[];var segments: Array=[]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/recordings/chapter_four_b_frames"))
	for mode in ["gallery","skeleton","spider","cow","grave","bell","rider","witch","cyst","mutations","crowd"]:
		g.qa_mode="ch4b_"+mode;prepare_four_enemies_capture(g)
		var w=g.world
		segments.append({"mode":mode,"time":frame/30.0})
		for i in range(90):
			var dir:=Vector2.ZERO
			if mode in ["skeleton","spider","cow","rider"] and i>10:dir=Vector2.DOWN if i<40 else Vector2.RIGHT if i<75 else Vector2.ZERO
			if mode!="gallery":
				for tick in range(2):
					if w.state=="LEVEL_UP":w.skip_reward()
					w.step(1.0/60,dir)
			for id in w.sounds:cues.append({"id":id,"time":frame/30.0})
			w.sounds.clear()
			g.queue_redraw();await tree.process_frame;RenderingServer.force_draw(false)
			tree.root.get_texture().get_image().save_png("res://qa/recordings/chapter_four_b_frames/%05d.png"%frame);frame+=1
	return {"fps":30,"frames":frame,"segments":segments,"sound_events":cues,"diagnostic_cuts":true,"invulnerability":false,"max_gear_only_in_crowd":true,"content_stage":"B"}

static func finale_run(w, seconds: float):
	for i in range(ceili(seconds*60)):w.step(1.0/60)

static func finale_qte(w, e):
	var q: Dictionary=e.qte
	if q.is_empty() or q.result!="" or q.age<q.windup+.05:return
	match q.kind:
		"dodge":e.press(q.dir)
		"attack":e.press("attack")
		"seq":e.press(q.dirs[q.progress])
	e.hold=q.kind=="hold"

static func prepare_four_finale_capture(g):
	g.start_chapter(4);g.world.reset(724)
	var w=g.world;var e=w.ending;var mode: String=g.qa_mode.trim_prefix("ch4e_")
	w.state="RUNNING";w.stage="survival";w.stage_age=30;w.note_presented=true;w.note_read=true
	w.db.data.chapter_four.exploration_only=true;w.build={"sword":8,"bow":6,"shotgun":6,"bell":5};w.items={"armor":4,"bedrock":3}
	g.settings.shake=false;w.time=719.95
	finale_run(w,.1);w.player=e.center+Vector2(0,150);finale_run(w,.05)
	if mode=="intro":finale_run(w,4.0);return
	w.invulnerable=999;finale_run(w,7.5)
	if mode.begins_with("one_"):
		e.start(w,mode.trim_prefix("one_"))
		finale_run(w,{"lightning":.6,"ring":1.2,"strike":.45}[mode.trim_prefix("one_")]);return
	w.hurt(e.hb,e.hb.hp+1)
	if mode=="kneel":finale_run(w,4.6);return
	finale_run(w,6.8)
	if mode.begins_with("two_"):
		var name: String=mode.trim_prefix("two_")
		e.hb.hp=e.hb.max_hp*.8;e.day_done=[0,1]
		var at: float={"hole":2.0,"blitz":1.75,"rain":1.6,"rift":2.2,"tear":2.0,"rift_warn":.8}.get(name,1.0)
		e.start(w,"rift" if name=="rift_warn" else name);finale_run(w,at);return
	if mode in ["day","day_split"]:
		e.start(w,"day");finale_run(w,3.2 if mode=="day" else 8.6);return
	e.day_done=[0,1];w.hurt(e.hb,e.hb.hp+1)
	if mode=="erase":finale_run(w,1.8);return
	finale_run(w,float(e.data.erase.duration)+.1)
	if mode=="three":
		for i in range(ceili(1.0*60)):finale_qte(w,e);w.step(1.0/60)
		e.qte.age=e.qte.windup+.3;return
	while e.phase=="three":finale_qte(w,e);w.step(1.0/60)
	var death_at: Dictionary={"death_laugh":2.6,"death_crawl":6.2,"death_plead":11.8,"death_final":12.75,"death_hold":15.0}
	if death_at.has(mode):finale_run(w,death_at[mode]);return
	finale_run(w,21.1)
	if mode=="coords":finale_run(w,3.5);return
	finale_run(w,9.0)
	if mode=="road":finale_run(w,4.8);return
	finale_run(w,10.9)
	var door_at: Dictionary={"door":2.0,"door_open":5.4,"door_enter":8.4}
	finale_run(w,door_at.get(mode,2.0))

## Film pilot for the finale: reads the same hazards the player sees and moves
## out of them. Diagnostic only (the recording also keeps the hero invulnerable).
static func finale_pilot(w, e) -> Vector2:
	if not e.fighting() or e.hb.is_empty():return Vector2.ZERO
	var p: Vector2=w.player
	var to_hb: Vector2=p.direction_to(e.hb.p)
	var d: float=p.distance_to(e.hb.p)
	var wish: Vector2=to_hb.orthogonal()*0.8+to_hb*clampf((d-70.0)/40.0,-1,1)
	for m in e.marks:
		if not m.hit and p.distance_to(m.p)<34:wish+=m.p.direction_to(p)*3
	for ring in e.rings:
		if ring.has("r"):wish=(ring.p+Vector2.from_angle(ring.gap)*(ring.r+30))-p;wish=wish.normalized()*2
	for lane in e.lanes:
		var q: Vector2=Geometry2D.get_closest_point_to_segment(p,lane.a,lane.b)
		if q.distance_to(p)<26:wish+=q.direction_to(p)*3
	if not e.hole.is_empty():wish+=e.hole.p.direction_to(p)*(3 if p.distance_to(e.hole.p)<90 else 1)
	if e.move=="rain":
		var lanes: int=int(e.data.two.rain.lanes)
		var safe_x: float=e.arena.position.x+(e.hb.get("rain_safe",lanes/2)+0.5)*e.arena.size.x/lanes
		wish=Vector2(signf(safe_x-p.x)*minf(1,absf(safe_x-p.x)/12),0.3)
	if not e.seam.is_empty() and absf(p.x-e.seam.x)<40:wish.x+=signf(p.x-e.seam.x)*2
	for leg in e.path:
		if leg.get("marked",false):
			var q: Vector2=Geometry2D.get_closest_point_to_segment(p,leg.a,leg.b)
			if q.distance_to(p)<24:wish+=q.direction_to(p)*3
	for b in e.shots:
		if b.p.distance_to(p)<30:wish+=b.v.normalized().orthogonal()*signf(b.v.normalized().orthogonal().dot(p-b.p))*2
	return wish.limit_length()

static func record_four_finale(g, tree: SceneTree) -> Dictionary:
	g.start_chapter(4);g.world.reset(724)
	var w=g.world;var e=w.ending
	w.state="RUNNING";w.stage="survival";w.stage_age=30;w.note_presented=true;w.note_read=true
	w.db.data.chapter_four.exploration_only=true
	w.build={"sword":8,"bow":7,"shotgun":4,"bell":4};w.items={"armor":4,"bedrock":2,"redstone":3}
	g.settings.shake=true;w.time=719.0;w.player=e.center+Vector2(0,330)
	var frame:=0;var cues:Array=[];var music:Array=[];var phases:Array=[]
	var last_music:="?";var last_phase:="?"
	var folder:="res://qa/recordings/chapter_four_finale_frames"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var limit:=30*330
	while frame<limit and w.state!="RESULT":
		for tick in range(2):
			if w.state=="LEVEL_UP":w.skip_reward()
			if w.state=="CHEST":w.chest_delay=0;w.close_chest()
			var move:=Vector2.ZERO
			if e.phase in ["","summit"]:move=w.player.direction_to(e.center)
			else:move=finale_pilot(w,e)
			if e.fighting():w.invulnerable=maxf(w.invulnerable,.2);w.hp=maxf(w.hp,14)
			finale_qte(w,e)
			w.step(1.0/60,move)
		var t: float=frame/30.0
		for id in w.sounds:cues.append({"id":id,"time":t})
		w.sounds.clear()
		if e.music!=last_music:last_music=e.music;music.append({"track":e.music,"time":t})
		if e.phase!=last_phase:last_phase=e.phase;phases.append({"phase":e.phase,"time":t})
		g.ui_time+=1.0/30;g.update_camera_lead()
		g.queue_redraw();await tree.process_frame;RenderingServer.force_draw(false)
		tree.root.get_texture().get_image().save_png(folder+"/%05d.png"%frame)
		frame+=1
	return {"fps":30,"frames":frame,"music":music,"phases":phases,"sound_events":cues,"diagnostic":"invulnerable hero, scripted dodging and QTE answers","state":w.state}

static func prepare_four_encounter_capture(g):
	g.start_chapter(4);g.world.reset(724)
	var w=g.world;var e=w.encounters;var mode: String=g.qa_mode.trim_prefix("ch4d_")
	w.state="RUNNING";w.stage="survival";w.stage_age=30;w.clock=200;w.note_presented=true;w.invulnerable=999
	w.db.data.chapter_four.exploration_only=true;w.build={"sword":8,"bow":6,"shotgun":5};g.settings.shake=false
	match mode:
		"mass":w.time=361;e.launch_mass(w);w.player=e.mass.p+Vector2(0,130)
		"golem":w.time=160;e.golem.visible=true;w.player=e.golem.p+Vector2(0,110);e.launch_golem(w)
		"guardian":w.time=520;w.player=e.arena().get_center()+Vector2(0,40);e.launch_guardian(w)
	var preview: float={"mass":2.2,"golem":1.6,"guardian":3.0}.get(mode,1.0)
	for i in range(ceili(preview*60)):w.step(1.0/60)
	w.invulnerable=0

static func prepare_four_arsenal_capture(g):
	g.start_chapter(4);g.world.reset(874)
	var w=g.world;var mode: String=g.qa_mode.trim_prefix("ch4c_")
	w.stage="survival";w.state="RUNNING";w.clock=184;w.time=420;w.stage_age=184;w.note_read=true;w.db.data.chapter_four.exploration_only=true
	w.player=Vector2(1050,1100);w.facing=Vector2.RIGHT;w.threats=[];w.chickens=[];w.build={};w.items={};w.evolved={};g.cam_lead=Vector2.ZERO
	var id: String={"bedrock":"sword","pool":"blood_pool","pet":"embryo","saw":"bone_saw","torch":"red_torch","sky":"sky_tnt","heart":"shotgun","bat":"sword"}.get(mode,mode)
	if id in w.db.weapons:w.build[id]=8
	if mode in ["bedrock","shotgun","pool","pet","bell","saw","torch","sky","potion"]:w.evolved[id]=true
	if mode in ["bedrock","saw","bat"]:w.items={"bat_wings":5,"armor":5,"thorns":3,"mirror_shard":3};w.evolved.armor=true
	if mode=="heart":w.items={"heart_booster":5,"black_candle":4,"empty_totem":1};w.hp=15
	if mode=="bat":w.evolved.bat_wings=true
	w.arsenal.reset(w);w.arsenal.tick(w,.01,Vector2.ZERO)
	for i in range(14):
		var p: Vector2=w.player+Vector2.from_angle(i*2.39996)*float(50+i%4*28)
		w.spawn(["flayed_zombie","growth_skeleton","matted_sheep","open_cow","hungry_wolf","fused_villagers"][i%6],p)
		w.mobs.back().hp*=5;w.mobs.back().max_hp=w.mobs.back().hp;w.mobs.back().timer=4
	w.rebuild_hit_grid();w.arsenal.kills=48
	if mode=="heart":w.active_item("heart")
	if mode=="bat":w.active_item("bat")
	if mode=="torch":
		for i in range(6):w.arsenal.torches.append({"p":w.player+Vector2.from_angle(i*TAU/6)*68,"life":13.0,"id":w.next_id()})
	if mode=="pool":
		w.arsenal.pools.append({"p":w.player,"base":42.0,"radius":62.0,"power":10,"life":15.0,"tick":.05,"damage":14.0})
	if mode.begins_with("recipes"):
		w.build={"sword":8,"fishing":8,"tnt":8,"shotgun":8,"bell":8,"bone_saw":8};w.items={"bedrock":1,"gunpowder":5,"mirror_shard":3,"armor":5,"thorns":3,"bat_wings":5,"empty_totem":1,"black_candle":3};w.evolved={"fishing":true,"tnt":true}
		g.router.open("recipes",w);g.recipe_page=1 if mode=="recipes2" else 0
	elif mode=="inventory":
		w.build={"sword":8,"shotgun":8,"sky_tnt":8,"bell":8,"bone_saw":8,"embryo":8};w.items={"heart_booster":5,"mirror_shard":3,"armor":5,"thorns":3,"bat_wings":5,"empty_totem":1,"black_candle":3,"bedrock":2};w.evolved={"sword":true,"armor":true,"bat_wings":true,"sky_tnt":true}
		g.router.open("inventory",w)
	else:
		var preview: float={"bedrock":.23,"shotgun":.34,"sky":1.5,"pool":.5,"pet":.2,"bell":.65,"saw":.28,"torch":.1,"potion":2.0,"heart":.32,"bat":.12}.get(mode,.2)
		for i in range(ceili(preview*60)):w.step(1.0/60)
	w.update_flow()

static func record_four_arsenal(g,tree: SceneTree) -> Dictionary:
	var frame:=0;var cues: Array=[];var segments: Array=[]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/recordings/chapter_four_c_frames"))
	for mode in ["bedrock","shotgun","pool","pet","bell","saw","torch","sky","heart","bat","potion"]:
		g.qa_mode="ch4c_"+mode;prepare_four_arsenal_capture(g);var w=g.world
		segments.append({"mode":mode,"time":frame/30.0})
		for i in range(90):
			for tick in range(2):
				if w.state=="LEVEL_UP":w.skip_reward()
				w.step(1.0/60,Vector2.RIGHT if mode in ["torch","bat"] and i<50 else Vector2.ZERO)
			for id in w.sounds:cues.append({"id":id,"time":frame/30.0})
			w.sounds.clear();g.queue_redraw();await tree.process_frame;RenderingServer.force_draw(false)
			tree.root.get_texture().get_image().save_png("res://qa/recordings/chapter_four_c_frames/%05d.png"%frame);frame+=1
	return {"fps":30,"frames":frame,"segments":segments,"sound_events":cues,"diagnostic_cuts":true,"invulnerability":false,"max_gear":true,"content_stage":"C"}
