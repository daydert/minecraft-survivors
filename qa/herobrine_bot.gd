extends RefCounted
func movement(w) -> Vector2:
	var f=w.finale
	if f.phase not in ["storm","inferno"]:return Vector2.ZERO
	var center: Vector2=f.BOSS_AT
	var delta: Vector2=w.player-center
	var ideal=72.0
	var wish=delta.normalized()*clampf((ideal-delta.length())/35,-1,1)+delta.orthogonal().normalized()*.65
	for wave in f.waves:
		if absf(w.player.distance_to(f.CENTER)-wave.radius)<100:
			var current=f.CENTER.direction_to(w.player).angle()
			var hole=wave.gap if absf(angle_difference(current,wave.gap))<PI/2 else wave.gap+PI
			var target: Vector2=f.CENTER+Vector2.from_angle(hole)*maxf(65,w.player.distance_to(f.CENTER))
			wish=w.player.direction_to(target)*1.4
	var speed=w.movement_speed();var best=-INF;var direction=Vector2.ZERO
	for i in range(17):
		var d=Vector2.from_angle(i*TAU/16) if i<16 else Vector2.ZERO
		var score=d.dot(wish)*6
		for horizon in [.2,.45,.8]:
			var p: Vector2=w.player+d*speed*horizon
			if not w.free_at(p):score-=120
			for strike in f.strikes:
				if strike.age+horizon>=.85 and strike.age+horizon<1.3:score-=pow(maxf(0,29-p.distance_to(strike.p)),2)*.8
			for wave in f.waves:
				var radius: float=wave.radius+wave.speed*horizon
				if absf(p.distance_to(f.CENTER)-radius)<24 and f.wave_active(f.CENTER.direction_to(p).angle(),wave):score-=280
		if score>best:best=score;direction=d
	if w.cooldowns.get("sword",1)<.12 and w.player.distance_to(center)<100:
		var toward=w.player.direction_to(center)
		if direction.dot(toward)>.4:return toward
	return direction
