extends SceneTree
## Balance probe for chapter V stage A: a simple kiting bot, automatic upgrades.
func _initialize():
	var World=load("res://scripts/chapter_five_world.gd")
	var out=[]
	for seed in [11,22,33]:
		var w=World.new(seed);w.reset(seed);w.state="RUNNING"
		var bot=SurvivorBot.new("sword");var move=Vector2.ZERO;var ticks=0;var marks={}
		while w.state!="RESULT" and ticks<60*725:
			if w.state=="LEVEL_UP":w.choose(pick(w))
			elif w.state=="CHEST":w.chest_delay=0;w.close_chest()
			else:
				move=bot.movement(w)
				var dodge=Vector2.ZERO
				for sh in w.shots:
					var d: Vector2=w.player-sh.p
					if d.length()<46 and sh.v.dot(d)>0:dodge+=sh.v.normalized().orthogonal()*signf(sh.v.normalized().orthogonal().dot(d)+.01)
				for z in w.zones:
					if z.p.distance_to(w.player)<z.r+8:dodge+=(w.player-z.p+Vector2(1,0)).normalized()*2
				for d in w.deleted:
					if d.rect.grow(14).has_point(w.player):dodge+=(w.player-d.rect.get_center()).normalized()*3
				if dodge.length()>.1:move=(move*.4+dodge).normalized()
				if w.invert>0:move=-move
				w.step(1.0/60,move)
			ticks+=1
			var minute=int(w.time/120)
			if not marks.has(minute):marks[minute]={"lvl":w.level,"hp":snappedf(w.hp,.1),"mobs":w.mobs.size()}
		out.append({"seed":seed,"time":snappedf(w.time,1),"victory":w.victory,"level":w.level,"kills":w.kills,"hp":snappedf(w.hp,.1),"build":w.build,"marks":marks})
		print(out.back())
	quit()

func pick(w) -> int:
	var order=["debug_stick","command_block","barrier","armor","structure_block","spawn_egg","sword","recovery_compass","knowledge_book","chain_block","name_tag","structure_void","light_block","hopper","sugar"]
	var best=999;var index=0
	for i in range(w.choices.size()):
		var id=w.choices[i];var rank=order.find(id)
		if id=="apple" and w.hp<12:rank=-1
		if rank<0 and id!="apple":rank=50
		if rank<best:best=rank;index=i
	return index
