extends SceneTree
## Honest bot runs (no invulnerability) comparing a chapter before and after
## version 2 content. Usage: -- --chapter=1|2|3 [--seeds=151,152,153]
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

func play(script: String, seed_value: int, style: String) -> Dictionary:
	var w=load(script).new();w.reset(seed_value);w.state="RUNNING"
	var bot=Bot.new(style);var guard=60*800
	while guard>0 and w.state!="RESULT" and w.time<719.9:
		guard-=1
		if w.state=="LEVEL_UP":
			if w.has_method("tick_choices"):
				if w.chosen_item.is_empty():w.choose(bot.choose(w))
				w.tick_choices(1.0/60)
			else:w.choose(bot.choose(w))
		elif w.state=="CHEST":w.chest_delay=0;w.close_chest()
		else:w.step(1.0/60,safe(w,bot))
		w.sounds.clear()
	return {"time":snappedf(w.time,.1),"alive":w.hp>0,"level":w.level,"kills":w.kills}

func run():
	var chapter=1;var seeds=[151,152,153]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--chapter="):chapter=arg.trim_prefix("--chapter=").to_int()
		if arg.begins_with("--seeds="):seeds=Array(arg.trim_prefix("--seeds=").split(",")).map(func(s):return int(s))
	var pairs={1:["res://scripts/campaign_world.gd","res://scripts/overworld_world.gd"],2:["res://scripts/nether_world.gd"],3:["res://scripts/end_world.gd"]}[chapter]
	for script in pairs:
		for i in range(seeds.size()):
			var style=["sword","bow","random"][i%3]
			print("BALANCE ",script.get_file()," seed=",seeds[i]," ",style," ",JSON.stringify(play(script,seeds[i],style)))
	quit()
