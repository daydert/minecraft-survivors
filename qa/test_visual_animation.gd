extends SceneTree
var game
var checks=0
var failures=[]

func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if not ok: failures.append(label);push_error(label)
	else:print("PASS: "+label)

func render() -> Image:
	game.queue_redraw()
	await process_frame
	RenderingServer.force_draw(false)
	return root.get_texture().get_image()

func run():
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process_input(false);game.set_process(false)
	game.set_physics_process(false)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size=Vector2i(640,360)
	game.settings.shake=false
	var w=game.world
	w.reset(724)
	for id in w.db.weapons:w.build[id]=8
	w.evolved={"sword":true,"bow":true,"trident":true}
	for i in range(8):
		w.spawn(["zombie","skeleton","creeper","slime","spider","elite","ravager","zombie"][i],w.player+Vector2(-170+i%4*110,-45+i/4*100))
	w.rebuild_hit_grid()
	w.step(0.16,Vector2.RIGHT)
	w.add_effect("bottle",w.player,0.55,{"end":w.player+Vector2(80,0),"stats":w.db.stats("potion",1)})
	w.add_effect("cloud",w.player+Vector2(80,0),3,{"radius":38.0,"damage":3})
	w.add_effect("lightning",w.player+Vector2(-60,0),0.35,{"radius":36.0})
	w.state="PAUSED"
	var a=await render()
	game.ui_time+=300
	var b=await render()
	check(a.get_data()==b.get_data(),"Paused render stays pixel-identical while UI clock advances")
	a.save_png("res://qa/animation_pause.png")
	w.state="LEVEL_UP"
	w.choices=["bow","fire","armor"]
	a=await render()
	game.ui_time+=300
	b=await render()
	check(a.get_data()==b.get_data(),"Upgrade render freezes bow, bottle, cloud, lightning, flames and actors")
	w.state="RUNNING"
	w.effects.clear()
	w.projectiles.clear()
	w.pixels.clear()
	w.weapon_visuals.clear()
	w.player_visual=w.animation.actor()
	w.mobs.clear()
	w.orbs.clear()
	for i in range(8):
		w.spawn(["zombie","skeleton","creeper","slime","spider","elite","ravager","zombie"][i],w.player+Vector2(-170+i%4*110,-45+i/4*100))
	var sheet=Image.create(1280,720,false,Image.FORMAT_RGBA8)
	var dirs=[Vector2.DOWN,Vector2.UP,Vector2.RIGHT,Vector2.LEFT]
	for i in range(4):
		w.facing=dirs[i]
		for m in w.mobs:
			m.visual_dir=dirs[i]
			m.visual.state="walk"
			m.visual.time=0.15+i*0.1
		a=await render()
		a.resize(640,360,Image.INTERPOLATE_NEAREST)
		sheet.blit_rect(a,Rect2i(0,0,640,360),Vector2i(i%2*640,i/2*360))
		check(not a.is_empty(),"Real scene renders direction "+str(dirs[i]))
	sheet.save_png("res://qa/animation_directions_live.png")
	game.settings.flashes=false
	w.invulnerable=0.6
	check(game.invulnerable_tint()==Color.WHITE,"Flashes off suppresses player blink")
	# Recoil remains readable with flashes disabled; all effect kinds draw safely.
	w.invulnerable=0
	w.damage_player(1)
	w.animation.advance(w,0.01)
	w.add_effect("explosion",w.player+Vector2(40,20),0.4,{"radius":30.0})
	w.add_effect("lightning",w.player+Vector2(-60,20),0.35,{"radius":36.0})
	a=await render()
	a.save_png("res://qa/effects_flashes_off.png")
	check(not a.is_empty(),"Effects remain renderable with flashes and camera shake disabled")
	FileAccess.open("res://qa/visual_animation_results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"framebuffer":str(root.size)},"  "))
	game.audio.shutdown()
	await create_timer(0.1).timeout
	game.free()
	game=null
	await process_frame
	quit(0 if failures.is_empty() else 1)
