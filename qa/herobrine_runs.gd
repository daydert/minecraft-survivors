extends SceneTree
func _initialize():run.call_deferred()
func run():
	var results=[]
	var bot=load("res://qa/herobrine_bot.gd").new()
	for style in ["hybrid","melee"]:
		var w=load("res://scripts/campaign_world.gd").new(724);w.state="RUNNING"
		w.build={"sword":8,"bow":8,"trident":8,"fire":7,"potion":6,"fangs":6} if style=="hybrid" else {"sword":8,"bow":3,"trident":5,"fire":3,"potion":3,"fangs":7}
		w.items={"blaze":4,"redstone":4,"amethyst":3,"sugar":3,"armor":4,"hopper":2};w.evolved={"sword":true}
		w.finale.begin(w);var movement=Vector2.ZERO;var ticks=0
		while w.finale.phase not in ["rising","failed"] and ticks<60*180:
			if ticks%4==0:movement=bot.movement(w)
			w.step(1.0/60,movement);ticks+=1
		var r={"style":style,"first_stage_defeated":w.finale.phase=="rising","hp_after_duel":w.hp,"seconds":ticks/60.0,"boss_hp":w.finale.boss.hp,"artificial_invulnerability":false}
		if w.finale.phase=="rising":
			while not w.finale.complete:w.step(1.0/60)
		r["chapter_complete"]=w.finale.complete;r["final_hp"]=w.hp;r["victory"]=w.victory
		results.append(r);print("HEROBRINE_RUN ",JSON.stringify(r))
	FileAccess.open("res://qa/herobrine_runs.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	quit(0 if results.all(func(r):return r.first_stage_defeated and r.chapter_complete and not r.victory) else 1)
