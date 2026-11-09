extends SceneTree
var results=[]
func _initialize():run.call_deferred()
func choose(w) -> int:
	var best=-INF;var index=0
	for i in range(w.choices.size()):
		var id=w.choices[i];var n=w.build.get(id,w.items.get(id,0))
		var priorities={"crossbow":23,"hoe":20,"sword":16,"bow":12,"tnt":12,"trident":14,"armor":18,"sugar":16 if n<3 else 6,"blaze":14,"redstone":14,"ghast_tear":22,"gold_boots":32 if n==0 else 4,"fire_resist":12,"hopper":20 if n==0 else 7,"amethyst":8,"feather":3,"fishing":3,"bed":3,"axe":10,"apple":30 if w.hp<13 else 0,"golden_carrot":30 if w.hp<13 else 0}
		var value=priorities.get(id,1)+(1 if n>0 else 0)
		if id=="fire_resist" and n<3 and w.time>180:value=35
		if id=="armor" and n<3 and w.hp<14:value=30
		if id in ["crossbow","hoe","bow","trident","fire","potion","fangs","axe","tnt"] and n==0 and w.build.size()<3:value+=20
		if value>best:best=value;index=i
	return index
func avoid_fire(w, wish: Vector2) -> Vector2:
	var best=-INF;var dir=wish
	for i in range(17):
		var d=Vector2.from_angle(i*TAU/16) if i<16 else Vector2.ZERO
		var score=d.dot(wish)*15-d.length()*.1
		var p: Vector2=w.player+d*82*.6
		for patch in w.magma:
			var distance=p.distance_to(patch.p)
			score-=pow(maxf(0,patch.radius+12-distance),2)*.3
		for b in w.projectiles:
			if b.kind!="enemy_flame":continue
			var distance=Geometry2D.get_closest_point_to_segment(p,b.p,b.p+b.dir*b.speed*.6).distance_to(p)
			score-=pow(maxf(0,20-distance),2)*.2
		if score>best:best=score;dir=d
	return dir
func survival_movement(w, bot) -> Vector2:
	if w.build.has("sword") and w.cooldowns.get("sword",0)<.13:
		var target=w.nearest(w.player,w.db.stats("sword",w.build.sword,w.evolved.has("sword"),w.items).radius)
		if target!=null:return w.player.direction_to(target.p)
	var melee_only=not w.build.keys().any(func(id):return id in ["bow","crossbow","trident","hoe","fire","potion","fangs","tnt"])
	var all=w.build
	if melee_only:w.build={"sword":all.get("sword",1)}
	var wish=bot.movement(w)
	w.build=all
	return avoid_fire(w,wish)
func run():
	var w=load("res://scripts/nether_world.gd").new(151);w.state="RUNNING"
	var bot=load("res://scripts/autoplay_bot.gd").new("trident")
	var helper=load("res://qa/nether_bot.gd").new()
	var ticks=0;var movement=Vector2.ZERO
	while w.state!="RESULT" and w.stage not in ["portal","end"] and ticks<60*1000:
		if w.state=="LEVEL_UP":w.choose(choose(w))
		elif w.state=="CHEST":w.chest_delay=0;w.close_chest()
		else:
			if ticks%6==0:movement=helper.boss_movement(w,false) if w.stage=="wither" else survival_movement(w,bot)
			w.step(1.0/60,movement)
		ticks+=1
	var r={"seed":151,"time":w.time,"hp":w.hp,"stage":w.stage,"victory":w.victory,"kills":w.kills,"level":w.level,"build":w.build,"items":w.items,"evolved":w.evolved,"boss_hits":w.boss_hits,"artificial_invulnerability":false}
	print("CAMPAIGN_RUN ",JSON.stringify(r));results.append(r)
	FileAccess.open("res://qa/nether_campaign_runs.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	quit(0 if w.victory else 1)
