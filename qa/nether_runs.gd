extends SceneTree
var results=[]
func _initialize():run.call_deferred()
func run():
	for style in ["hybrid","melee","developing"]:
		var w=load("res://scripts/nether_world.gd").new(724);w.state="RUNNING"
		w.build={"sword":8,"crossbow":8,"hoe":8,"bow":8,"tnt":8,"trident":8} if style=="hybrid" else {"sword":8,"axe":8,"hoe":8,"bed":8,"fishing":8,"fangs":8}
		w.items={"blaze":4,"redstone":4,"amethyst":4,"sugar":4,"armor":4,"ghast_tear":3,"feather":3,"fire_resist":3}
		w.evolved={"sword":true,"crossbow":true} if style=="hybrid" else {"sword":true,"axe":true}
		if style=="developing":
			w.build={"sword":6,"crossbow":6,"hoe":5,"bow":4,"tnt":3,"trident":4}
			w.items={"blaze":3,"redstone":3,"amethyst":2,"sugar":3,"armor":3,"ghast_tear":2,"fire_resist":2,"gold_boots":1}
			w.evolved={}
		w.begin_arena()
		while w.stage!="wither":w.step(1.0/60)
		var movement=Vector2.ZERO
		var ticks=0
		while w.stage=="wither" and w.state!="RESULT" and ticks<60*240:
			if ticks%5==0:movement=load("res://qa/nether_bot.gd").new().boss_movement(w,style=="melee")
			if w.state=="LEVEL_UP":w.choose(0)
			elif w.state=="CHEST":w.chest_delay=0;w.close_chest()
			else:w.step(1.0/60,movement)
			ticks+=1
		var r={"style":style,"stage":w.stage,"hp":w.hp,"seconds":ticks/60.0,"boss_hits":w.boss_hits,"victory":w.victory,"boss_hp":w.mobs[0].hp if not w.mobs.is_empty() else 0,"artificial_invulnerability":false}
		print("BOSS_RUN ",JSON.stringify(r));results.append(r)
	FileAccess.open("res://qa/nether_boss_runs.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	quit(0 if results.filter(func(r):return r.style!="developing").all(func(r):return r.victory) else 1)
