extends SceneTree
## Chapter I story: the walk-in through the party gate, Herobrine's greeting and
## dodges, the rebuilt throne, the villager wrung into a creeper, the "fun"
## punch of the canonical ending and the deflection of the secret one.
var game
var checks=0
var failures=[]
var out="res://qa/chapter_one/"
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if ok:print("PASS: ",label)
	else:failures.append(label);push_error(label)
func render(name: String="") -> Image:
	game.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(false)
	var image=root.get_texture().get_image()
	if not name.is_empty():image.save_png(out+name+".png")
	return image
func advance(seconds: float,movement: Vector2=Vector2.ZERO):
	for i in range(ceili(seconds*60)):
		if game.world.state=="LEVEL_UP":game.world.choose(0)
		elif game.world.state=="CHEST":game.world.chest_delay=0;game.world.close_chest()
		else:game.world.step(1.0/60,movement)
func until(phase: String, limit: float=60.0, movement: Vector2=Vector2.ZERO):
	var t=0.0
	while game.world.finale.phase!=phase and t<limit:advance(1.0/60,movement);t+=1.0/60
func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="review";game.settings.shake=false;game.settings.numbers=false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360)
	game.action("chapter_1");var w=game.world
	check(w.state=="INTRO" and w.player.y>2048,"Chapter I opens outside the fence on the path")
	advance(1.6);await render("intro_path")
	advance(2.8);await render("intro_sign")
	check(w.gate_grow==0.0,"The gate stands open while Steve reads the sign")
	advance(4.2);await render("intro_grow")
	advance(1.4);await render("intro_closed")
	check(w.gate_grow==1.0,"The gap grows shut behind him")
	advance(4.0)
	check(w.state=="RUNNING" and w.player.distance_to(w.RUN_START)<1 and w.time<3.0,"The run begins inside the fence once the walk-in ends")
	await render("run_start")
	game.action("chapter_1");w=game.world;w.skip_intro()
	check(w.state=="RUNNING" and w.gate_grow==1.0,"Skipping the walk-in starts the run at once")
	# The duel.
	w.invulnerable=0;w.finale.begin(w)
	advance(2.2);await render("hb_appear")
	advance(1.3);await render("hb_wave")
	check(w.finale.phase=="greet" and w.finale.hb_pose=="wave","Herobrine appears at his own size and waves")
	until("tease")
	w.player=w.finale.hb_p+Vector2(0,40)
	var dodged=w.finale.dodges
	for i in range(240):
		advance(1.0/60,w.player.direction_to(w.finale.hb_p))
		if w.finale.dodges>dodged and w.finale.dodge_age>.06 and w.finale.dodge_age<.12:await render("hb_dodge");break
	check(w.finale.dodges>dodged and w.finale.boss.hp==w.finale.boss.max_hp,"He dodges every blow during the warm-up and takes no damage")
	until("throne",30.0,Vector2.ZERO)
	check(w.finale.phase=="throne","After his warm-up he goes to rebuild his throne")
	advance(2.4);await render("throne_build")
	advance(1.9);await render("throne_seat")
	until("storm",10.0)
	w.invulnerable=999
	advance(5.6);await render("villager_lift")
	advance(1.4);await render("villager_twist")
	advance(1.6);await render("villager_legs")
	advance(1.0)
	check(w.mobs.any(func(m):return m.kind=="ch1_crawler"),"The wrung villager drops as a legless crawler")
	advance(1.5);await render("crawler")
	# Canonical ending: Steve loses and Herobrine shows off.
	w.invulnerable=0;w.hp=0.0;advance(1.0/60)
	check(w.finale.phase=="showtime","A lost fight leads into Herobrine's showpiece")
	advance(1.4);await render("show_laugh")
	advance(2.5);await render("show_wind")
	until_age(w.finale.SHOW_PUNCH+.3)
	await render("show_donut")
	check(w.hp==0,"The punch is the killing blow")
	until_age(6.8);await render("show_hole")
	until("defeated",5.0);advance(.9);await render("show_fallen")
	until("fall",10.0);advance(2.0);await render("show_nether")
	# Secret ending.
	game.action("chapter_1");w=game.world;w.skip_intro();w.finale.begin(w)
	until("tease");until("throne",30.0);until("storm",10.0)
	w.finale.boss.hp=0;advance(2.0/60)
	check(w.finale.phase=="rising","Emptying his health leads into the secret ending")
	until("descend",5.0)
	advance(2.8);await render("secret_wind")
	until_age(w.finale.DESCEND_PARRY+.05);await render("secret_parry")
	check(w.finale.hb_face!="smile" or w.finale.phase_age<w.finale.DESCEND_PARRY+1.3,"The deflection breaks his grin")
	until_age(w.finale.DESCEND_PARRY+1.6);await render("secret_rage")
	until_age(w.finale.WHISPER[0]+2.8);await render("secret_whisper")
	check(w.finale.whisper()>.9,"His question fills the screen")
	until("rift",10.0);advance(2.0);await render("secret_rift")
	until("fall",15.0)
	check(w.finale.phase=="fall","The secret ending still ends in the Nether")
	print("CHAPTER_ONE_STORY_RESULT %d checks; %d failures" % [checks,failures.size()])
	quit(1 if failures.size() else 0)
func until_age(age: float):
	var t=0.0
	while game.world.finale.phase_age<age and t<20.0:advance(1.0/60);t+=1.0/60
