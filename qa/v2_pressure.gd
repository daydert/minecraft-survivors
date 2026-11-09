extends SceneTree
## Difficulty pressure: the bot is kept alive and every hit it takes is summed
## per minute. Usage: -- --script=res://scripts/x_world.gd --seeds=151,152,153
const Bot=preload("res://scripts/autoplay_bot.gd")
func _initialize():run.call_deferred()

func safe(w, bot) -> Vector2:
	var desired: Vector2=bot.movement(w)
	if not w.has_method("on_land") or desired.length_squared()<.01:return desired
	for i in range(16):
		var direction=desired.rotated((i/2+1)*TAU/32*(1 if i%2==0 else -1)) if i>0 else desired
		var ok=true
		for j in range(1,13):
			if not w.on_land(w.player+direction*w.movement_speed()*.8*j/12):ok=false;break
		if ok:return direction
	return Vector2.ZERO

func run():
	var script="res://scripts/overworld_world.gd";var seeds=[151,152,153]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--script="):script=arg.trim_prefix("--script=")
		if arg.begins_with("--seeds="):seeds=Array(arg.trim_prefix("--seeds=").split(",")).map(func(s):return int(s))
	var minutes=[];minutes.resize(12);minutes.fill(0.0)
	for seed_value in seeds:
		var w=load(script).new();w.reset(seed_value);w.state="RUNNING"
		if "stage" in w and w.stage=="end_arrival":w.stage="survival"
		var bot=Bot.new("sword");var guard=60*760
		while guard>0 and w.time<719 and w.state!="RESULT":
			guard-=1
			if w.state=="LEVEL_UP":
				if w.has_method("tick_choices"):
					if w.chosen_item.is_empty():w.choose(bot.choose(w))
					w.tick_choices(1.0/60)
				else:w.choose(bot.choose(w))
			elif w.state=="CHEST":w.chest_delay=0;w.close_chest()
			else:
				var before=w.hp
				w.step(1.0/60,safe(w,bot))
				if w.hp<before:minutes[mini(11,int(w.time/60))]+=before-w.hp
				if w.hp<8:w.hp=20.0
			w.sounds.clear()
	var per=minutes.map(func(v):return snappedf(v/seeds.size(),.1))
	print("PRESSURE ",script.get_file()," per_minute=",per," total=",snappedf(per.reduce(func(a,b):return a+b,0.0),.1))
	quit()
