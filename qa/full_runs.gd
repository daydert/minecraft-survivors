extends SceneTree
const World=preload("res://scripts/world.gd")
const Bot=preload("res://scripts/autoplay_bot.gd")
func _initialize():run.call_deferred()
func run():
	var report=[]
	var styles=["sword","bow","random"]
	var seed_value=151
	var output="res://qa/full_runs.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--style="):styles=[arg.trim_prefix("--style=")]
		if arg.begins_with("--styles="):styles=arg.trim_prefix("--styles=").split(",")
		if arg.begins_with("--seed="):seed_value=arg.trim_prefix("--seed=").to_int()
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	for i in range(styles.size()):
		var style=styles[i]
		var w=World.new(seed_value+i)
		w.state="RUNNING"
		var bot=Bot.new(style)
		var steps=0
		var started=Time.get_ticks_usec()
		var max_step=0
		var first_level=-1.0
		var checkpoints=[]
		var last_minute=-1
		while w.state!="RESULT" and steps<48000:
			if w.state=="LEVEL_UP":
				if first_level<0:first_level=w.time
				w.choose(bot.choose(w))
			elif w.state=="CHEST":
				w.chest_delay=0
				w.close_chest()
			else:
				var begin=Time.get_ticks_usec()
				w.step(1.0/60,bot.movement(w))
				max_step=maxi(max_step,Time.get_ticks_usec()-begin)
				steps+=1
				if int(w.time)/60>last_minute:
					last_minute=int(w.time)/60
					var checkpoint={"time":snappedf(w.time,0.01),"hp":w.hp,"level":w.level,"kills":w.kills,"mobs":w.mobs.size()}
					checkpoints.append(checkpoint)
					print(style," ",checkpoint)
			w.sounds.clear()
		var result={"style":style,"seed":seed_value+i,"time":w.time,"victory":w.victory,"chapter_complete":w.finale.complete,"ending":w.finale.phase,"hp":w.hp,"level":w.level,"kills":w.kills,"first_level":first_level,"build":w.build,"items":w.items,"evolved":w.evolved,"wall_seconds":(Time.get_ticks_usec()-started)/1000000.0,"max_step_ms":max_step/1000.0,"checkpoints":checkpoints}
		report.append(result)
		print("RUN_RESULT ",JSON.stringify(result))
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	quit()
