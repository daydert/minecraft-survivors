extends SceneTree
var game
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if ok:print("PASS: ",label)
	else:failures.append(label);push_error(label)
func render(name: String="") -> Image:
	game.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(false)
	var image=root.get_texture().get_image()
	if not name.is_empty():image.save_png("res://qa/end_revision_"+name+".png")
	return image
func advance(seconds: float,movement: Vector2=Vector2.ZERO):
	for i in range(ceili(seconds*60)):
		if game.world.state=="LEVEL_UP":
			game.world.choose(0)
			if game.world.has_method("tick_choices"):game.world.tick_choices(1.0/60)
		else:game.world.step(1.0/60,movement)
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.settings.shake=false;game.settings.numbers=false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360)
	game.action("chapter_3");var w=game.world;w.stage="survival";w.invulnerable=999;w.db.data.events=[];w.db.data.waves=[{"at":0,"rate":0,"weights":{"endermite":1}}]
	var column=w.props.filter(func(p):return p.type=="end_ruin")[0];w.player=column.p+Vector2(0,25);w.last_safe=w.player;w.build={};await render("columns")
	w.items={"end_eye":5};w.next_level();await render("choices");var item=w.choices[4];game.action("choice_4");var receipt=await render("receipt")
	check(w.chosen_item==item and game.buttons.all(func(b):return not b.id.begins_with("choice_")),"Receipt draws the chosen icon and name without live card buttons")
	w.tick_choices(.3);var same=await render();check(receipt.get_data()==same.get_data(),"Receipt remains visually fixed while its short display timer elapses")
	w.tick_choices(.3);w.state="RUNNING";w.build={};w.items={};w.prepare_arena();w.stage="exit_portal";w.portal_lit=true;w.mobs.clear();w.crystals.clear();w.player=w.portal_position+Vector2(0,80);w.scene_camera=w.portal_position+Vector2(0,10)
	advance(.02);await render("betrayal_arrive");advance(2.35);var windup=await render("betrayal_windup");advance(.6);await render("betrayal_strike");advance(.4);var impact=await render("betrayal_impact")
	check(not w.portal_lit and windup.get_data()!=impact.get_data(),"Portal charge, sword strike and actual rubble use distinct rendered stages")
	advance(5.5);w.stage="last_duel";var m=w.mobs[0];w.player=w.portal_position+Vector2(110,80);w.scene_camera=w.portal_position+Vector2(30,20);m.p=w.portal_position+Vector2(-45,-45)
	for pattern in [4,5,6]:
		m.phase="walk";m.timer=0;m.pattern=pattern-1;w.hazards.clear();w.projectiles.clear();w.effects.clear();w.invulnerable=999
		advance(1.25 if pattern==5 else 2)
		await render("attack_"+str(pattern))
	m.p=w.portal_position+Vector2(70,55);w.player=w.portal_position+Vector2(-55,80);m.hp=0;w.resolve_deaths();w.scene_camera=w.portal_position+Vector2(0,15)
	advance(1);var knees=await render("death_knees");advance(2);await render("death_cracks");advance(2);var fracture=await render("death_fracture");advance(1.4);await render("death_light");advance(1.3);await render("hand")
	check(w.stage=="hand" and w.loot.size()==1 and knees.get_data()!=fracture.get_data(),"Defeat progresses through knees, cracks and disintegration to a single hand")
	w.player=w.hand_position()+Vector2(0,5);advance(.1,Vector2.UP);await render("pickup");advance(.7);var p=w.player;advance(2)
	check(w.stage=="return_portal" and w.player==p,"Rendered finale returns movement and waits after hand pickup")
	for i in range(120):
		if w.stage!="return_portal":break
		w.step(1.0/60,w.player.direction_to(w.portal_position))
	advance(1.2);await render("rekindle");advance(1.7);await render("ready")
	check(w.stage=="portal_ready" and w.portal_lit,"Portal reconstruction ends with player still outside")
	for i in range(120):
		if w.stage=="exit_jump":break
		w.step(1.0/60,w.player.direction_to(w.portal_position))
	advance(.65);await render("jump");advance(.8);await render("jump_fall");advance(2.1);await render("overworld")
	check(w.stage=="chapter_four","Manual portal entry reaches the rendered bloody Overworld")
	w.stage_age=142.0/60;await render("title_glitch")
	game.action("chapter_2");w=game.world;w.build={"axe":8};w.evolved={"axe":true};w.items={};w.db.data.events=[];w.db.data.waves=[{"at":0,"rate":0,"weights":{"magma_cube":1}}];w.invulnerable=999
	w.spawn("hoglin",w.player+Vector2(30,0));w.mobs.back().hp=3000;w.mobs.back().max_hp=3000;w.rebuild_hit_grid();w.facing=Vector2.RIGHT;w.update_attacks(.01);advance(.09,Vector2.RIGHT);await render("axe_sweep");advance(.29,Vector2.RIGHT);await render("axe_return")
	game.audio.shutdown();game.coop.diagnostics.close();game.quitting=true
	FileAccess.open("res://qa/end_revision_visual_results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("END_REVISION_VISUAL_RESULT ",checks," checks; ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
