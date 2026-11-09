extends SceneTree
## Exercise production draw_actor: both mirrors, all Steve poses, moving attacks.
var game
var mode="mobs"
var elapsed=0.12
var checks=0
var failures=[]
var poses=[]
var record_frame=0
var finished=false
var kinds=["steve","zombie","skeleton","creeper","spider","slime","ravager","elite","vindicator"]

func _initialize():start.call_deferred()

func check(ok:bool,label:String):
	checks+=1
	if not ok:
		failures.append(label)
		push_error(label)

func render() -> Image:
	game.queue_redraw()
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	return root.get_texture().get_image()

func draw_catalog():
	game.draw_rect(Rect2(0,0,640,360),Color("1a1a1a"))
	if mode=="mobs":
		game.text_at("ДВИЖЕНИЕ ВЛЕВО И ВПРАВО",Vector2(18,24),14,Color.WHITE,true)
		for i in range(kinds.size()):
			var x=(i%3)*210
			var y=(i/3)*106
			game.text_at(kinds[i],Vector2(x+22,y+53),10,Color.WHITE)
			game.text_at("<",Vector2(x+20,y+100),12,Color.WHITE)
			game.text_at(">",Vector2(x+174,y+100),12,Color.WHITE)
			var scale=1.0 if kinds[i]=="ravager" else 1.7
			for side in [-1,1]:
				game.draw_actor(kinds[i],Vector2(x+54 if side<0 else x+144,y+121),Vector2(side,0),elapsed,true,Color.WHITE,"walk",scale,{"state":"walk","time":elapsed})
	else:
		game.text_at("СТИВ: ВСЕ 22 ПОЗЫ · ПРЯМО / ВЛЕВО / ВПРАВО",Vector2(16,21),11,Color.WHITE,true)
		for i in range(poses.size()):
			var x=32+(i%11)*57
			var y=69+(i/11)*145
			game.text_at(poses[i].label,Vector2(x-22,y-31),7,Color.WHITE)
			for row in range(3):
				var dir=[Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT][row]
				game.draw_actor("steve",Vector2(x,y+row*45),dir,elapsed,true,Color.WHITE,"walk",1.0,{"state":poses[i].state,"time":poses[i].time,"gait":elapsed})

func has_eyes(im:Image,origin:Vector2i,side:int) -> bool:
	var white=0
	var pupil=0
	var eye_x=0.0
	var eye_count=0
	for y in range(14):
		for x in range(32):
			var c=im.get_pixel(origin.x+x,origin.y+y)
			var sclera=minf(c.r,minf(c.g,c.b))>160.0/255
			var iris=c.b>c.r*1.15 and c.b>c.g*1.4
			if sclera:white+=1
			if iris:pupil+=1
			if sclera or iris:
				eye_x+=x-15.5
				eye_count+=1
	return white>0 and pupil>0 and (side==0 or eye_x/eye_count*side>0)

func start():
	game=load("res://qa/minecraft_catalog.gd").new()
	game.reviewer=self
	root.add_child(game)
	game.set_process_input(false);game.set_process(false)
	game.set_physics_process(false)
	game.qa_mode="character_facing"
	game.audio.update_volumes(0,0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size=Vector2i(640,360)
	game.world.reset(724)
	for state in game.world.animation.data.actors.steve.states:
		var clip=game.world.animation.data.actors.steve.states[state]
		var t=0.0
		for i in range(clip.durations.size()):
			poses.append({"state":state,"time":t+clip.durations[i]/2,"label":state.substr(0,3)+str(i)})
			t+=clip.durations[i]
	if "--record" in OS.get_cmdline_user_args():
		var driver=load("res://qa/animation_review_driver.gd").new()
		driver.review=self
		root.add_child(driver)
		return
	var a=await render()
	a.save_png("res://qa/minecraft_facing_live.png")
	a.save_png("res://.impeccable/review/character-facing-desktop.png")
	elapsed=.34
	var b=await render()
	check(a.get_data()!=b.get_data(),"All-direction gallery visibly advances walking poses")
	mode="steve"
	a=await render()
	a.save_png("res://qa/minecraft_steve_eyes_live.png")
	a.save_png("res://.impeccable/review/steve-eyes-desktop.png")
	for i in range(poses.size()):
		for row in range(3):
			var p=Vector2i(32+(i%11)*57,69+(i/11)*145+row*45)
			check(has_eyes(a,p-Vector2i(16,29),[0,-1,1][row]),"Steve open eyes and facing: %s %d"%[poses[i].label,row])
	FileAccess.open("res://qa/character_facing_results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("CHARACTER_FACING_RESULT ",checks," checks; failures=",failures.size())
	await finish()

func tick():
	if finished:return
	elapsed=record_frame/30.0
	mode="mobs" if record_frame<120 else "steve"
	game.queue_redraw()
	record_frame+=1
	if record_frame>=210:finish.call_deferred()

func finish():
	finished=true
	game.audio.shutdown()
	await create_timer(.15).timeout
	game.free()
	game=null
	quit(0 if failures.is_empty() else 1)
