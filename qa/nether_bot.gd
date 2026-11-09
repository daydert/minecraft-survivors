extends RefCounted
func boss_movement(w, melee: bool) -> Vector2:
	var boss=null
	for m in w.mobs:
		if m.kind=="wither":boss=m
	if boss==null:return Vector2.ZERO
	var delta: Vector2=w.player-boss.p
	var ideal=70 if melee else 125
	var wish=delta.normalized()*clampf((ideal-delta.length())/40,-1,1)+delta.orthogonal().normalized()*.8
	var best=-INF
	var direction=Vector2.ZERO
	var speed=w.db.data.player_speed*(1+.08*w.items.get("sugar",0))
	for i in range(17):
		var d=Vector2.from_angle(i*TAU/16) if i<16 else Vector2.ZERO
		var score=d.dot(wish)*5
		for horizon in [.25,.65,1.0]:
			var p: Vector2=w.player+d*speed*horizon
			if not w.ARENA.grow(-20).has_point(p):score-=600
			var predicted_boss: Vector2=boss.p
			if boss.phase in ["dash","rush"]:
				var delay=boss.timer if boss.phase=="dash" else 0.0
				predicted_boss+=boss.charge*(350 if boss.rage else 245)*minf(.6,maxf(0,horizon-delay))
			if boss.phase=="walk":
				var target: Vector2=p+Vector2(sin((w.clock+horizon)*.9)*105,-96)
				predicted_boss+=boss.p.direction_to(target)*(72 if boss.rage else 42)*minf(horizon,maxf(0,boss.attack_tick))
			var dist=p.distance_to(predicted_boss)-boss.radius
			if boss.phase in ["dash","rush"]:dist=minf(dist,Geometry2D.get_closest_point_to_segment(p,boss.p,predicted_boss).distance_to(p)-boss.radius)
			score-=pow(maxf(0,19-dist),2)*.3
			for b in w.projectiles:
				if b.kind!="wither_skull":continue
				var direction_at_time: Vector2=b.dir.rotated(b.get("turn",0.0)*horizon*.5)
				var bp: Vector2=b.p+direction_at_time*(b.speed*horizon+.5*b.get("acceleration",0.0)*horizon*horizon)
				if b.get("orbit_owner",-1)>=0:
					bp=predicted_boss+Vector2.from_angle(b.orbit_angle+b.orbit_speed*horizon)*(42+minf(110,(b.age+horizon)*32))
				var bd=Geometry2D.get_closest_point_to_segment(p,b.p,bp).distance_to(p)
				score-=pow(maxf(0,23-bd),2)*.4
			for h in w.hazards:
				if h.wait<=horizon+.3:score-=pow(maxf(0,h.radius+14-p.distance_to(h.p)),2)*.7
		if score>best:best=score;direction=d
	return direction
