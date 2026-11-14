extends SceneTree
## Charge tells for every chapter's mobs, frozen mid-windup.
var game
func _initialize():run.call_deferred()
func shot(name: String):
	game.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://qa/mob_tells/"+name+".png")
func put(w,kind: String,at: Vector2) -> Dictionary:
	w.spawn(kind,w.player+at)
	var m: Dictionary=w.mobs.back();m.speed=0;return m
func setup(ch: String):
	game.action(ch);var w=game.world
	w.db.data.waves=[]
	if w.state=="INTRO":w.skip_intro()
	for i in range(30):w.step(1.0/60,Vector2.ZERO)
	w.mobs.clear();w.invulnerable=999;w.clock=3.3;w.player+=Vector2(0,-260)
	return w
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="review";game.settings.numbers=false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360)
	var w=setup("chapter_1")
	var c=put(w,"creeper",Vector2(-110,-40));c.fuse=.35
	var v=put(w,"vindicator",Vector2(-40,60));v.phase="windup";v.timer=.18;v.charge=Vector2.UP.rotated(.4)
	var r=put(w,"ravager",Vector2(150,-80));r.phase="windup";r.timer=.3;r.charge=Vector2(-1,.5).normalized()
	var s=put(w,"skeleton",Vector2(160,90));s.timer=.2
	w.add_effect("witch_potion",w.player+Vector2(-150,90),1.0,{"start":w.player+Vector2(-230,40),"end":w.player+Vector2(-120,70),"radius":30.0,"damage":1.0,"owner":3})
	w.effects.back().age=.6
	var ph=put(w,"phantom",Vector2(110,40));ph.phase="windup";ph.timer=float(w.night.phantom_windup)*.35;ph.mark=w.player+Vector2(-10,10)
	print("CH1 ",w.mobs.map(func(m):return m.kind)," fx ",w.effects.map(func(e):return e.kind))
	await shot("ch1")
	w=setup("chapter_2")
	var b=put(w,"brute",Vector2(-150,-30));b.phase="windup";b.timer=.25;b.charge=Vector2.RIGHT
	var h=put(w,"hoglin",Vector2(120,-90));h.phase="windup";h.timer=.3;h.charge=Vector2(-.6,.8).normalized()
	var pc=put(w,"piglin_crossbow",Vector2(150,80));pc.timer=.2
	var bl=put(w,"blaze_nether",Vector2(-130,100));bl.timer=.25
	await shot("ch2")
	w=setup("chapter_3");w.stage="survival";w.state="RUNNING"
	var d=put(w,"dispenser_enderman",Vector2(160,-40));d.timer=.2
	var sh=put(w,"shulker",Vector2(-120,-70));sh.timer=.25
	var br=put(w,"endermite_brood",Vector2(-100,80));br.timer=.35
	await shot("ch3")
	w=setup("chapter_5")
	w.spawn("for_loop",w.player+Vector2(-120,-40));var f=w.mobs.back();f.phase="windup";f.timer=.25;f.speed=0
	w.spawn("if_else",w.player+Vector2(140,-60));var ie=w.mobs.back();ie.timer=.2
	w.spawn("function",w.player+Vector2(-60,90));var fn=w.mobs.back();fn.timer=.3
	w.strike(w.player+Vector2(90,70),30.0,.8,1.0);w.zones.back().age=.5
	var cr=put(w,"creeper",Vector2(40,-110));cr.fuse=.4
	await shot("ch5")
	game.audio.shutdown();game.quitting=true;print("MOB_TELLS_DONE");quit()
