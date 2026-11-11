extends SceneTree
const EW=preload("res://scripts/end_world.gd")
const LAB=preload("res://scripts/boss_lab.gd")
var reports=[]
func _initialize():run.call_deferred()
func avoid(w, desired: Vector2) -> Vector2:
	var boss=null
	for m in w.mobs:
		if m.kind in ["end_dragon","endersteve_final"]:boss=m
	var best=INF;var answer=Vector2.ZERO
	var target_distance=w.player.distance_to(desired)
	for i in range(17):
		var dir=Vector2.ZERO if i==16 else Vector2.from_angle(i*TAU/16)
		var future=w.move_actor(w.player,dir*minf(w.movement_speed()*.45,target_distance),6)
		var score=future.distance_to(desired)*.7
		if target_distance<8 and i==16:score-=10
		for b in w.projectiles:
			if b.kind not in ["end_blade","end_bullet","dragon_fireball","shulker_bullet","enemy_arrow","slow_arrow","poison_arrow"]:continue
			var path_end: Vector2=b.p+b.dir*b.speed*.6
			var d=Geometry2D.get_closest_point_to_segment(future,b.p,path_end).distance_to(future)
			if d<22:score+=(22-d)*25
		for h in w.hazards:
			var d=Geometry2D.get_closest_point_to_segment(future,h.p,h.end).distance_to(future) if h.get("kind","")=="end_cut" else future.distance_to(h.p)
			if d<h.radius+15:score+=(h.radius+15-d)*30
		if boss!=null:
			if boss.phase in ["rush","windup"]:
				var end: Vector2=boss.p+boss.charge*320
				var d=Geometry2D.get_closest_point_to_segment(future,boss.p,end).distance_to(future)
				if d<64:score+=(64-d)*35
			if boss.kind=="endersteve_final" and future.distance_to(boss.p)<29:score+=500
		if score<best:best=score;answer=dir
	return answer
func run():
	for index in range(4):
		var w=EW.new();w.reset(724);w.state="RUNNING";LAB.equip(w,index);w.prepare_arena()
		var elapsed=0.0;var crystals=0;var phase_two=false;var dragon_win=false;var final_win=false;var minimum_hp=20.0
		var target_crystal=-1
		while elapsed<600 and w.hp>0 and not w.end_complete:
			var target=w.player
			if w.stage=="dragon":
				if target_crystal<0 or not w.crystals[target_crystal].alive:
					target_crystal=-1;var best=INF
					for i in range(w.crystals.size()):
						if w.crystals[i].alive and w.crystals[i].p.distance_squared_to(w.player)<best:target_crystal=i;best=w.crystals[i].p.distance_squared_to(w.player)
				if target_crystal>=0:
					target=w.crystals[target_crystal].p+Vector2(0,12)
				else:
					var boss=w.mobs.filter(func(m):return m.kind=="end_dragon")
					if not boss.is_empty():
						var m=boss[0];phase_two=phase_two or m.phase_two
						target=m.p+Vector2.from_angle(elapsed*.45)*(45 if m.phase=="perch" else 105)
				crystals=w.crystals.filter(func(t):return not t.alive).size()
			elif w.stage=="exit_portal":dragon_win=true;target=w.portal_position+Vector2(0,35)
			elif w.stage=="last_duel":
				var m=w.mobs[0];target=m.p+Vector2.from_angle(elapsed*.65)*(65 if w.build.has("bow") else 38)
				if w.items.has("elytra") and w.flight_cooldown<=0 and w.projectiles.size()>25:w.active_item("elytra")
			elif w.stage in ["yield","approach","clash","down"]:final_win=true;target=w.npc.p if not w.npc.is_empty() else w.portal_position
			elif w.stage in ["portal_ready"]:target=w.portal_position
			if w.state=="LEVEL_UP":w.choose(0);w.tick_choices(1.0/60)
			elif w.state=="CHEST":w.chest_delay=0;w.close_chest()
			else:
				var movement=avoid(w,target)
				if target_crystal>=0 and w.stage=="dragon" and w.player.distance_to(w.crystals[target_crystal].p)<35:
					var dragon=w.mobs.filter(func(m):return m.kind=="end_dragon")[0]
					if dragon.phase not in ["rush","windup"] and w.hazards.all(func(h):return w.player.distance_to(h.p)>h.radius+15):movement=w.player.direction_to(target) if w.player.distance_to(target)>6 else Vector2.ZERO
				w.step(1.0/60,movement)
			elapsed+=1.0/60;minimum_hp=minf(minimum_hp,w.hp)
			if w.stage=="chapter_four":break
		var report={"build":LAB.presets(3)[index].name,"seconds":snappedf(elapsed,.01),"hp":snappedf(w.hp,.01),"minimum_hp":snappedf(minimum_hp,.01),"stage":w.stage,"crystals_destroyed":crystals,"phase_two":phase_two,"dragon_win":dragon_win,"final_win":final_win,"complete":w.end_complete,"god_mode":false,"seed":724,"player":[w.player.x,w.player.y],"corpse":[w.endsteve_corpse.get("p",Vector2.ZERO).x,w.endsteve_corpse.get("p",Vector2.ZERO).y],"remaining_boss_hp":w.mobs[0].hp if not w.mobs.is_empty() else 0}
		reports.append(report);print("END_BOSS_RUN ",JSON.stringify(report))
	FileAccess.open("res://qa/end_boss_runs.json",FileAccess.WRITE).store_string(JSON.stringify(reports,"  "))
	quit()
