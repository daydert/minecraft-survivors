extends SceneTree
## Pixel registration of terrain, props, water and landmarks under the same
## camera transform; settings persistence and simulation isolation.
class WorldOnly:
	extends "res://scripts/main.gd"
	const SETTINGS_PATH="user://camera_visual_settings.cfg"
	var settings_preview:=false
	func load_settings(path: String=SETTINGS_PATH):super.load_settings(path)
	func save_settings(path: String=SETTINGS_PATH):super.save_settings(path)
	func _draw():
		if settings_preview:
			buttons.clear();MenuScreens.draw_settings(self)
		else:WorldView.draw_world(self)

var game
var checks:=0
var failures: Array=[]

func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if ok:print("PASS: ",label)
	else:failures.append(label);push_error(label)

func render(name: String="") -> Image:
	game.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(false)
	var img=root.get_texture().get_image()
	if not name.is_empty():img.save_png("user://camera_"+name+".png")
	return img

func snapshot() -> String:
	var w=game.world
	return var_to_str([w.player,w.hp,w.clock,w.time,w.rng.state,w.build,w.items,w.cooldowns,w.camera()])

func registered(a: Image,b: Image,rect: Rect2i,shift: Vector2i) -> bool:
	return a.get_region(rect).get_data()==b.get_region(Rect2i(rect.position+shift,rect.size)).get_data()

func prepare(chapter: int):
	game.start_chapter(chapter)
	var w=game.world
	w.reset(724);w.state="RUNNING";w.clock=.1;w.time=30;w.player=Vector2(1024.375,1024.625)
	w.props.clear();w.mobs.clear();w.loot.clear();w.orbs.clear();w.effects.clear();w.projectiles.clear();w.pixels.clear()
	w.weapon_visuals.clear();w.build={};w.items={};w.shake=0
	if chapter>1:w.stage="survival"
	if "landmarks" in w:w.landmarks.clear()
	if chapter==1:
		w.props.append({"type":"flowers","p":w.player+Vector2(-110,30),"hp":-1.0,"id":17,"radius":0.0})
		w.landmarks.append({"kind":"well","p":w.player+Vector2(140,60)})
		w.water.clear()
		for y in range(58,61):
			for x in range(62,66):w.water[Vector2i(x,y)]=true
	if chapter==2:w.magma.clear()
	if chapter==4:
		w.threats.clear();w.chickens.clear();w.terrain.pools=[]
	game.settings.lighting=false;game.settings.shake=false;game.settings.flashes=false
	game.cam_lead=Vector2.ZERO

func run():
	# Existing profiles have no camera_lead key; the update must opt them out.
	var legacy=ConfigFile.new();legacy.set_value("settings","music",0.0);legacy.set_value("settings","effects",0.0)
	legacy.set_value("settings","shake",true);legacy.save(WorldOnly.SETTINGS_PATH)
	game=WorldOnly.new();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="camera_test"
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360)
	check(not game.settings.get("camera_lead",true) and game.settings.shake,"Old profiles default to no movement offset while keeping their shake preference")
	for chapter in range(1,5):
		prepare(chapter);var w=game.world;var before=snapshot()
		game.settings.camera_lead=false
		var base=await render("chapter_%d_base"%chapter)
		game.cam_lead=Vector2(13,-7)
		var disabled=await render()
		check(base.get_data()==disabled.get_data(),"Chapter %d: disabled movement offset ignores stale camera state"%chapter)
		game.settings.camera_lead=true
		var shifted=await render("chapter_%d_lead"%chapter)
		var ground_rect=Rect2i(150,70,64,40) if chapter!=3 else Rect2i(260,148,36,25)
		check(registered(base,shifted,ground_rect,Vector2i(-13,7)),"Chapter %d: terrain follows the movement offset exactly"%chapter)
		check(base.get_data()!=shifted.get_data(),"Chapter %d: enabled movement offset really moves the view"%chapter)
		if chapter==1:
			for pair in [["flowers",Rect2i(198,188,30,32)],["well",Rect2i(424,184,74,64)],["pond",Rect2i(286,82,68,52)]]:
				check(registered(base,shifted,pair[1],Vector2i(-13,7)),"Chapter I: "+pair[0]+" stay registered with terrain")
		game.cam_lead=Vector2.ZERO;game.settings.shake=true;w.shake=.2
		var shaken=await render("chapter_%d_shake"%chapter)
		var amount: float=1.5 if chapter<=2 else 2.0 if chapter==3 else 1.0
		var shift:=Vector2i((Vector2(sin(w.clock*75),cos(w.clock*87)).round()*amount).round())
		check(registered(base,shaken,ground_rect,shift),"Chapter %d: terrain and objects share pixel-aligned shake"%chapter)
		game.settings.shake=false
		check(base.get_data()==(await render()).get_data(),"Chapter %d: shake can be disabled independently"%chapter)
		game.settings.camera_lead=false;game.cam_lead=Vector2(8,5);game.update_camera_lead()
		check(game.cam_lead==Vector2.ZERO and before==snapshot(),"Chapter %d: camera settings never move the simulation or consume RNG"%chapter)
		game.settings.camera_lead=true;game.cam_lead=Vector2(13,-7);w.shake=0;w.state="PAUSED"
		var paused=await render()
		for i in range(60):w.step(1.0/60,Vector2.RIGHT);game.update_camera_lead()
		check(paused.get_data()==(await render()).get_data(),"Chapter %d: pause freezes the view with movement offset enabled"%chapter)
	# Local coop presentation uses the same terrain renderer, without sockets.
	game.action("menu")
	game.world=load("res://scripts/coop_world.gd").new(724)
	game.world.configure(724,{1:"Ведущий",2:"Друг"},1)
	game.coop.active=true;game.coop.running=true
	game.world.props.clear();game.world.mobs.clear();game.world.loot.clear();game.world.orbs.clear()
	game.world.clock=.1;game.world.shake=0;game.cam_lead=Vector2.ZERO
	game.settings.camera_lead=true;game.settings.shake=true
	var coop_base=await render()
	game.cam_lead=Vector2(13,-7)
	check(coop_base.get_data()==(await render()).get_data(),"Coop keeps its original camera even when movement offset is enabled")
	game.world.shake=.2
	var coop_shift:=Vector2i((Vector2(sin(.1*75),cos(.1*87)).round()*1.5).round())
	check(registered(coop_base,await render(),Rect2i(150,70,64,40),coop_shift),"Coop terrain shares the same shake as its actors")
	game.update_camera_lead()
	check(game.cam_lead==Vector2.ZERO,"Coop clears residual solo movement offset")
	game.coop.active=false;game.coop.running=false
	prepare(1)
	game.settings.camera_lead=true;game.world.facing=Vector2.RIGHT;game.world.player_moving=true
	game.lead_clock=game.world.clock;game.world.clock+=.1
	var before=snapshot();game.update_camera_lead();var moving_lead: Vector2=game.cam_lead
	check(moving_lead.x>0 and moving_lead.y==0 and before==snapshot(),"Enabled movement offset follows the actual direction without changing combat")
	game.world.player_moving=false;game.world.clock+=.1;game.update_camera_lead()
	check(game.cam_lead.x<moving_lead.x and game.cam_lead.x>=0,"Movement offset settles back when the hero stops")
	game.settings.camera_lead=false;game.cam_lead=Vector2(8,5);game.action("camera_lead")
	check(game.settings.camera_lead and game.cam_lead==Vector2.ZERO,"The settings action enables movement offset from a clean start")
	game.settings.camera_lead=false;game.load_settings()
	check(game.settings.camera_lead,"Movement offset preference survives settings reload")
	game.action("camera_lead")
	check(not game.settings.camera_lead and game.cam_lead==Vector2.ZERO,"Turning movement offset off clears it immediately")
	game.settings_preview=true;await render("settings")
	var buttons: Array=game.buttons
	check(buttons.any(func(b):return b.id=="camera_lead") and buttons.any(func(b):return b.id=="shake"),"Settings expose separate movement offset and shake switches")
	var overlaps:=false
	for i in range(buttons.size()):
		for j in range(i+1,buttons.size()):
			if buttons[i].rect.intersects(buttons[j].rect):overlaps=true
	check(not overlaps and buttons.all(func(b):return Rect2(0,0,640,360).encloses(b.rect)),"Every settings control fits on screen without overlap")
	game.audio.shutdown();game.quitting=true
	print("CAMERA_VISUAL_RESULT %d checks; %d failures"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
