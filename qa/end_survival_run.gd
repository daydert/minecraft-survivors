extends SceneTree
## Ordinary rewards, health and damage. This probe never edits a live build or HP.
const EW=preload("res://scripts/end_world.gd")
var w
var bot=preload("res://scripts/autoplay_bot.gd").new("sword")
func _initialize():run.call_deferred()
func movement() -> Vector2:
	var desired=bot.movement(w)
	if desired.length_squared()<.01:return Vector2.ZERO
	for i in range(16):
		var direction=desired.rotated((i/2+1)*TAU/32*(1 if i%2==0 else -1)) if i>0 else desired
		var safe=w.supported_at(w.player+direction*w.movement_speed()/60,3)
		for j in range(1,13):
			var sample=w.player+direction*w.movement_speed()*.8*j/12
			if not w.on_land(sample):safe=false;break
		if safe:return direction
	return Vector2.ZERO
func choice() -> int:
	var priority=["sword","mace","end_crystal","knockback_stick","shield","dragon_breath","ghast_tear","armor","blaze","redstone","amethyst","rabbit_foot","shulker_shell","elytra"]
	var best=-INF;var index=0
	for i in range(w.choices.size()):
		var id=w.choices[i];var at=priority.find(id);var score=100-at*2 if at>=0 else 0
		if id=="apple" or id=="golden_carrot":score=120 if w.hp<8 else -5
		if score>best:best=score;index=i
	return index
func run():
	w=EW.new();w.reset(151);w.state="RUNNING"
	var steps=0;var peak=0;var health_events=[]
	while w.hp>0 and w.time<720 and steps<60*760:
		if w.state=="LEVEL_UP":w.choose(choice())
		elif w.state=="CHEST":w.chest_delay=0;w.close_chest()
		else:
			var hp=w.hp;var pos=w.player;var falling=w.fall_age>=0
			w.step(1.0/60,movement());steps+=1
			if w.hp<hp:health_events.append({"time":w.time,"damage":hp-w.hp,"falling":falling,"position":[pos.x,pos.y],"land":w.on_land(pos)})
		peak=maxi(peak,w.mobs.size())
	var report={"seed":151,"time":w.time,"hp":w.hp,"level":w.level,"kills":w.kills,"build":w.build,"items":w.items,"evolved":w.evolved,"stage":w.stage,"peak_mobs":peak,"god_mode":false,"reached_arena":w.time>=720,"complete":false,"health_events":health_events}
	FileAccess.open("res://qa/end_survival_run.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("END_SURVIVAL_RUN ",JSON.stringify(report));quit()
