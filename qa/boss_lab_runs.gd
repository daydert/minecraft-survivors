extends SceneTree
func _initialize():run.call_deferred()
func run():
	var results=[]
	var lab=load("res://scripts/boss_lab.gd")
	for chapter in [1,2]:
		for preset in range(4):
			var w=load("res://scripts/campaign_world.gd").new(724) if chapter==1 else load("res://scripts/nether_world.gd").new(724)
			w.state="RUNNING";lab.equip(w,preset)
			var bot=load("res://qa/herobrine_bot.gd").new() if chapter==1 else load("res://qa/nether_bot.gd").new()
			if chapter==1:w.finale.begin(w)
			else:
				w.begin_arena()
				while w.stage!="wither":w.step(1.0/60)
			var ticks=0;var movement=Vector2.ZERO
			while ticks<60*180:
				if chapter==1 and w.finale.phase not in ["arrival","storm","inferno"]:break
				if chapter==2 and (w.stage!="wither" or w.state=="RESULT"):break
				if ticks%5==0:movement=bot.movement(w) if chapter==1 else bot.boss_movement(w,preset in [0,2])
				w.step(1.0/60,movement);ticks+=1
			var win=w.finale.first_stage_won if chapter==1 else w.victory
			var row={"chapter":chapter,"preset":lab.presets(chapter)[preset].name,"won":win,"hp":w.hp,"seconds":ticks/60.0,"artificial_invulnerability":false}
			results.append(row);print("LAB_RUN ",JSON.stringify(row))
	FileAccess.open("res://qa/boss_lab_runs.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	quit(0 if results.all(func(r):return r.won) else 1)
