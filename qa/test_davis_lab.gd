extends SceneTree
## DAVIS lab: five chapters, every target, custom loadouts, cheats and run actions.
var game
var checks=0
var failures=[]
var shots=false
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if ok:print("PASS: "+label)
	else:failures.append(label);push_error(label)
func key(code: int):
	var e=InputEventKey.new();e.physical_keycode=code;e.keycode=KEY_F if code in [KEY_D,KEY_A,KEY_V,KEY_I,KEY_S] else code;e.pressed=true
	game._input(e)
func secret():
	for code in [KEY_D,KEY_A,KEY_V,KEY_I,KEY_S,KEY_ENTER]:key(code)
## One physics frame as the game runs it, with the cheat driver around the step.
func frame(movement: Vector2=Vector2.ZERO):
	var scale: float=game.davis.before(game)
	game.world.step(1.0/60*scale,movement)
	game.davis.after(game)
func advance(seconds: float,movement: Vector2=Vector2.ZERO):
	for i in range(ceili(seconds*60)):
		if game.world.state=="LEVEL_UP":game.world.choose(0)
		elif game.world.state=="CHEST":game.world.chest_delay=0;game.world.close_chest()
		frame(movement)
func render(name: String):
	game.queue_redraw();await process_frame;await process_frame
	if not shots:return
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://qa/davis_lab/"+name+".png")
func run():
	shots=DisplayServer.get_name()!="headless"
	DirAccess.make_dir_recursive_absolute("res://qa/davis_lab")
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process_input(false);game.set_process(false);game.set_physics_process(false)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360);game.settings.shake=false
	game.lab.persist=false;game.lab.reset_cheats();game.lab.loadouts.clear();game.lab.target.clear();game.lab.hero_level=40
	secret()
	check(game.screen=="boss_lab","DAVIS opens the lab from the menu")
	for chapter in range(1,6):
		game.action("lab_chapter_"+str(chapter))
		var pool: Dictionary=game.lab.pool(chapter)
		check(pool.weapons.size()>=6 and pool.items.size()>=4,"Chapter %d exposes its whole pool (%d weapons, %d items)"%[chapter,pool.weapons.size(),pool.items.size()])
		game.action("lab_tab_sets");await render("ch%d_sets"%chapter)
		check(game.buttons.filter(func(b):return b.id.begins_with("lab_build_")).size()==4,"Chapter %d has four ready sets"%chapter)
		game.action("lab_tab_custom");await render("ch%d_custom"%chapter)
		check(game.buttons.filter(func(b):return b.id.begins_with("lab_item_")).size()==pool.weapons.size()+pool.items.size(),"Chapter %d custom grid shows every item"%chapter)
	game.action("lab_tab_cheats");await render("cheats_menu")
	# ---- custom loadout editing
	game.action("lab_chapter_4");game.action("lab_tab_custom");game.action("lab_clear")
	game.action("lab_item_shotgun");game.action("lab_item_gunpowder")
	check(game.lab.level_of(4,"shotgun")==8 and game.lab.level_of(4,"gunpowder")==5,"A click adds an item at its top level")
	game.lab.focus="shotgun";game.action("lab_level_down");game.action("lab_level_down")
	check(game.lab.level_of(4,"shotgun")==6,"Minus lowers the focused level")
	game.action("lab_evo")
	check(game.lab.level_of(4,"shotgun")==8 and game.lab.loadout(4).evolved.has("shotgun"),"Evolution raises the weapon to its top and marks it")
	for id in ["sword","axe","bow","trident","bell","embryo"]:game.action("lab_item_"+id)
	check(game.lab.loadout(4).weapons.size()==6,"Without cheats the six weapon slots hold")
	game.action("lab_hero_down10");game.action("lab_hero_up")
	check(game.lab.hero_level==31,"Hero level steps by one and by ten")
	await render("ch4_custom_built")
	game.lab.target[4]=0;game.action("lab_start")
	check(game.is_four() and game.world.build.get("shotgun",0)==8 and game.world.evolved.has("shotgun") and game.world.level==31 and game.screen.is_empty(),"Whole chapter IV starts with the custom loadout")
	check(not game.world.run_progress.enabled,"Lab runs never grant achievements")
	advance(3.0)
	check(game.world.state in ["RUNNING","LEVEL_UP"] and game.world.hp>0,"Chapter IV with custom gear keeps running")
	# ---- every boss of every chapter, ready set 0
	var expect={1:{"herobrine":"finale"},2:{"wither":"departure"},3:{"dragon":"departure","endersteve":"betrayal"},4:{"mass":"mass","guardian":"guardian","herobrine":"lure"},5:{"loop":"loop","purge":"countdown","notch":"notch"}}
	for chapter in expect:
		var list: Array=game.BossLab.targets(chapter)
		for i in range(list.size()):
			var id: String=list[i].id
			if not expect[chapter].has(id):continue
			secret();game.action("lab_chapter_"+str(chapter));game.action("lab_tab_sets");game.action("lab_target_"+str(i));game.action("lab_build_0")
			var w=game.world
			var ok:=false
			match id:
				"herobrine":ok=(w.finale.active if chapter==1 else w.ending.phase=="lure")
				"wither","dragon":ok=w.stage=="departure"
				"endersteve":ok=w.stage=="betrayal"
				"mass","guardian":ok=w.encounters.current==id
				"loop":ok=not w.bosses.loop.is_empty()
				"purge":ok=w.purge.phase=="countdown"
				"notch":ok=w.stage=="notch"
			check(ok and w.build.size()>=4,"Chapter %d · %s starts with the ready set"%[chapter,list[i].name])
			game.lab.cheats.god=true
			advance(6.0)
			check(game.world.state!="RESULT","Chapter %d · %s runs six seconds"%[chapter,list[i].name])
			if chapter==3 and id=="endersteve":
				advance(8.0)
				check(game.world.stage in ["last_arrival","last_duel"],"EnderSteve arrives after the betrayal")
			await render("ch%d_%s"%[chapter,id])
			game.lab.cheats.god=false
	# ---- cheats
	game.lab.reset_cheats();game.lab.target[2]=0;secret();game.action("lab_chapter_2");game.action("lab_tab_sets");game.action("lab_build_1")
	var w=game.world
	advance(1.0)
	w.hp=1.0;game.lab.cheats.god=true
	for i in range(30):
		var scale: float=game.davis.before(game);w.invulnerable=0;w.damage_player(50.0);w.step(1.0/60*scale);game.davis.after(game)
	check(w.hp==20.0 and w.state!="RESULT","God mode survives any damage")
	game.lab.cheats.god=false
	var base: float=w.db.stats("sword",8,false,w.items).damage
	game.lab.cheats.damage=2;frame()
	check(is_equal_approx(w.db.stats("sword",8,false,w.items).damage,base*10),"Damage ×10 multiplies weapon damage")
	game.lab.cheats.rapid=true;frame()
	check(w.db.stats("sword",8,false,w.items).interval<1.0,"Rapid fire shortens intervals")
	var speed: float=w.movement_speed();game.lab.cheats.speed=2;frame()
	check(w.movement_speed()>speed*2.4,"Hero speed ×2.5")
	game.lab.cheats.magnet=true;frame()
	check(w.pickup_radius()>300,"Magnet pulls from afar")
	game.lab.cheats.game_speed=2
	check(game.davis.before(game)==2.0,"Game speed ×2 doubles the step");game.davis.after(game)
	game.lab.reset_cheats();frame()
	check(w.cheat_speed==1.0 and w.db.data.cheat_damage==1.0 and not w.cheat_peace,"Resetting cheats restores the world")
	game.lab.cheats.peace=true;w.mobs.clear();w.time=200.0
	advance(4.0)
	check(w.mobs.filter(func(m):return not m.get("boss",false)).is_empty(),"No waves keeps the field empty")
	game.lab.cheats.peace=false
	game.lab.cheats.chain=true
	for i in range(12):w.spawn("zombie" if w.db.data.mobs.has("zombie") else w.db.wave(w.time).weights.keys()[0],w.player+Vector2(60+i*4,0))
	var before_count: int=w.mobs.size()
	w.effects.clear();game.davis.before(game);w.hurt(w.mobs[0],99999.0);w.step(1.0/60);game.davis.after(game)
	check(w.effects.any(func(e):return e.kind=="explosion"),"A death sets off the chain reaction")
	game.lab.cheats.chain=false
	game.lab.cheats.disco=true;await render("disco");game.lab.cheats.disco=false
	# ---- right now, over the running run
	secret();game.action("lab_tab_cheats")
	check(game.lab_run_chapter()==2,"The lab knows the run underneath")
	await render("cheats_in_run")
	game.action("lab_now_horde")
	check(game.screen.is_empty() and w.mobs.size()>=30,"Horde spawns a crowd and returns to the run")
	secret();game.action("lab_now_kill")
	check(w.mobs.filter(func(m):return m.hp>0 and not m.get("boss",false)).is_empty(),"Kill all clears the field")
	secret();var lvl: int=w.level;game.action("lab_now_level");frame()
	check(w.level==lvl+1,"New level arrives")
	if w.state=="LEVEL_UP":w.choose(0)
	secret();var t: float=w.time;game.action("lab_now_time")
	check(w.time>=t+59,"Time skips a minute")
	secret();game.action("lab_target_1");game.action("lab_now_target")
	check(w.stage=="departure" and game.world==w,"Straight to the boss keeps the same run")
	# ---- a normal run is untouched without cheats
	game.lab.reset_cheats();game.close_boss_lab() if game.screen=="boss_lab" else null
	game.start_chapter(1,false)
	check(game.world.run_progress.enabled and game.world.cheat_speed==1.0,"Normal runs stay clean")
	FileAccess.open("res://qa/davis_lab_results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	game.audio.shutdown();await create_timer(.25).timeout;game.free();game=null
	print("DAVIS_LAB_RESULT ",checks," checks; ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
