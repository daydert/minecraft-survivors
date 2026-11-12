extends SceneTree
## Audit every real solo recipe; optionally record each distinct reveal once.
## Only QA setups and the UI's chest-delay clock advance during the ceremony.
var game
var recording := false
var frames := 0
var checks := 0
var failures: Array = []
var audit: Array = []
var segments: Array = []
var cues: Array = []
var seen: Dictionary = {}
const OUT := "res://qa/evolution_reveals/"
const FRAMES := "res://qa/recordings/evolution_reveals_frames"

func _initialize():run.call_deferred()

func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func draw():
	game.queue_redraw()
	await process_frame
	RenderingServer.force_draw(false)

func frame(w):
	for id in w.sounds:cues.append({"id":id,"time":frames/30.0})
	w.sounds.clear()
	await draw()
	root.get_texture().get_image().save_png(FRAMES+"/%05d.png"%frames)
	frames += 1
	game.ui_time += 1.0/30.0
	# Same timer as main._process; world.step is intentionally frozen in CHEST.
	if w.state == "CHEST":w.chest_delay=maxf(0,w.chest_delay-1.0/30.0)

func icon_exists(w, id: String, evolved: bool) -> bool:
	var name: String=w.db.equipment_icon(id,w.build.get(id,w.items.get(id,8)),evolved)
	var key: String=name+"_enchanted" if name in ["netherite","flamebow","channeling"] or (evolved and game.minecraft_assets.clips.has(name+"_enchanted")) else "icon_"+name
	if not game.textures.has(key):return false
	var texture: Texture2D=game.textures[key]
	return texture.get_width()>0 and texture.get_height()>0

func prepare(w, chapter: int, id: String):
	w.state="RUNNING";w.time=400;w.clock=400;w.hp=20;w.xp=0
	w.build={};w.items={};w.evolved={};w.cooldowns={};w.sounds.clear();w.sound_times.clear()
	w.mobs.clear();w.projectiles.clear();w.effects.clear();w.weapon_visuals.clear();w.attack_visuals.clear()
	w.sword_drop={};w.chest_reward={};w.pending_chest={};w.chest_delay=0
	w.facing=Vector2.DOWN;w.player_moving=false;w.player_visual=w.animation.actor()
	if chapter>1:w.stage="survival"
	if chapter==1:w.skip_intro()
	if chapter==4:
		w.arsenal.reset(w)
		for part in w.Equipment.components(w.db,id):
			if part.kind=="weapon":w.build[part.id]=int(part.level)
			else:w.items[part.id]=int(part.level)
			if part.get("evolved",false):w.evolved[part.id]=true
	else:
		w.build[id]=8
		w.items[w.db.recipes[id].passive]=5
	w.sounds.clear()

func run():
	recording=OS.get_cmdline_user_args().has("--record-reveals")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if recording:DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FRAMES))
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false)
	game.qa_mode="evolution_review";game.audio.update_volumes(0,0)
	game.settings.shake=false;game.settings.flashes=true;root.size=Vector2i(640,360)
	for chapter in range(1,6):
		game.action("chapter_%d"%chapter)
		var w=game.world
		var recipes: Array=w.db.recipes.keys()
		for id in recipes:
			prepare(w,chapter,id)
			var label: String="Chapter %d / %s"%[chapter,id]
			check(w.evolution_candidates(600).has(id),label+": actual ingredients eligible")
			w.open_chest({"born":600.0,"p":w.player})
			check(w.state=="CHEST" and w.chest_reward.get("id","")==id and w.chest_reward.get("evolution",false) and w.evolved.has(id),label+": actual chest grants requested evolution")
			check(is_equal_approx(w.chest_delay,1.7),label+": full reveal duration")
			var title: String=game.gear_title(id,true)
			var icon: String=w.db.equipment_icon(id,8,true)
			var key: String=title+"|"+icon+"|"+("IV-body" if chapter==4 else "standard-body")
			var distinct: bool=not seen.has(key)
			seen[key]=true
			var entry: Dictionary={"chapter":chapter,"id":id,"title":title,"icon":icon,"distinct_reveal":distinct,"duration":w.chest_delay}
			audit.append(entry)
			var clock: float=w.clock
			var rng_before: int=w.rng.state
			if recording and distinct:
				entry["video_time"]=frames/30.0
				segments.append({"name":"chapter_%d_%s"%[chapter,id],"chapter":chapter,"id":id,"title":title,"time":frames/30.0})
				print("EVOLUTION_CAPTURE ",chapter," ",id," ",frames/30.0)
				for i in range(81):
					await frame(w)
					if i in [0,24,48,80]:root.get_texture().get_image().save_png(OUT+"%d_%s_%02d.png"%[chapter,id,i])
			else:
				for delay in [1.7,.9,.1,0.0]:
					w.chest_delay=delay
					await draw()
					if distinct:root.get_texture().get_image().save_png(OUT+"%d_%s_%02d.png"%[chapter,id,roundi((1.7-delay)*30)])
			check(icon_exists(w,id,false) and icon_exists(w,id,true),label+": both item icons loaded")
			check(not title.is_empty() and title!=id,label+": localized title")
			check(w.rng.state==rng_before and w.clock==clock,label+": presentation preserves simulation and RNG")
			w.chest_delay=0
			w.close_chest()
			check(w.state=="RUNNING" and w.evolved.has(id),label+": continue retains evolution")
		print("EVOLUTION_CHAPTER ",chapter," recipes ",recipes.size())
	var result: Dictionary={"checks":checks,"failures":failures,"recipe_chapter_pairs":audit.size(),"distinct_reveals":seen.size(),"recipes":audit,"coop":"Legacy reward panel; shared solo ceremony is not enabled in coop."}
	FileAccess.open(OUT+"audit.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	if recording:
		FileAccess.open("res://qa/recordings/evolution_reveals_timeline.json",FileAccess.WRITE).store_string(JSON.stringify({"fps":30,"frames":frames,"sound_events":cues,"music":[],"effects_volume":.65,"segments":segments,"diagnostic_montage":true,"description":"Actual chest reward flow; all distinct solo evolution reveals without repeats."},"  "))
	game.action("menu");game.audio.shutdown();game.quitting=true
	print("EVOLUTION_RESULT ",checks," checks; ",failures.size()," failures; ",audit.size()," recipes; ",seen.size()," distinct; ",frames," frames")
	quit(0 if failures.is_empty() else 1)
