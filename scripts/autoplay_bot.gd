class_name SurvivorBot
extends RefCounted
var preference = "sword"
var orbit_sign = 1.0
var last = Vector2.ZERO
var stuck = 0

func _init(style: String = "sword"):
	preference=style

func choose(w) -> int:
	var best=-100.0
	var index=0
	for i in range(w.choices.size()):
		var id=w.choices[i]
		var value=1.0
		var level=w.build.get(id,w.items.get(id,0))
		if preference=="random":value=w.rng.randf()*10
		else:
			if id==preference:value=20+level
			elif id==w.db.recipes[preference].passive:value=15 if level==0 else 4
			elif id=="bow":value=13 if level==0 else 6
			elif id=="fire":value=12 if level==0 else 5
			elif id=="trident":value=10 if level==0 else 5
			elif id=="sword":value=10 if level<5 else 8
			elif id=="potion":value=8
			elif id=="fangs":value=7
			elif id=="blaze":value=8
			elif id=="redstone":value=7
			elif id=="hopper":value=11 if level<1 else 3
			elif id=="sugar":value=9 if level<2 else 3
			elif id=="armor":value=40
			elif id=="apple":value=25 if w.hp<12 else 0
		if value>best:
			best=value
			index=i
	return index

func movement(w) -> Vector2:
	var target=w.player
	var nearest=INF
	for o in w.orbs:
		var d=w.player.distance_squared_to(o.p)
		if d<nearest:
			nearest=d
			target=o.p
	for o in w.loot:
		var d=w.player.distance_squared_to(o.p)*(0.03 if o.kind=="apple" and w.hp<16 else (0.1 if o.kind=="chest" else 0.45))
		if d<nearest:
			nearest=d
			target=o.p
	if w.hp<12:
		for obj in w.props:
			if obj.type!="pumpkin" or obj.hp<=0:continue
			var distance=w.player.distance_to(obj.p)
			if distance<220 and distance*distance*0.25<nearest:
				target=obj.p
				nearest=distance*distance*0.25
				if distance<32 and w.nearest(w.player,50)==null:
					var toward=w.player.direction_to(obj.p)
					if w.facing.dot(toward)<0.9:return toward
					return Vector2.ZERO
	if nearest==INF:
		var mob=w.nearest(w.player,700)
		if mob!=null:target=mob.p
		else:target=Vector2(1024,1024)
	if w.build.size()==1:
		var mob=w.nearest(w.player,600)
		if mob!=null:
			var distance=w.player.distance_to(mob.p)
			var to_mob=w.player.direction_to(mob.p)
			if distance<18:return -to_mob
			if nearest<1600:return w.player.direction_to(target)
			if distance>34:return to_mob
			if w.facing.dot(to_mob)<0.95:return to_mob
			return Vector2.ZERO
	var wish=w.player.direction_to(target)
	var force=Vector2.ZERO
	var closest=null
	var min_dist=9999.0
	for m in w.in_radius(w.player,115):
		var d=w.player.distance_to(m.p)-m.radius
		if d<min_dist:
			min_dist=d
			closest=m
		if d<46:
			force+=m.p.direction_to(w.player)*pow((46-d)/35.0,2)*2.5
		if m.kind=="creeper" and m.fuse>=0:
			force+=m.p.direction_to(w.player)*3
	for b in w.projectiles:
		if b.kind!="enemy_arrow":continue
		var relative=w.player-b.p
		if relative.length()<80 and b.dir.dot(relative.normalized())>0.8:
			force+=b.dir.orthogonal()*(1 if b.dir.cross(relative)>0 else -1)*2
	for s in w.nearby_solids(w.player):
		var d=w.player.distance_to(s.p)
		if d<s.r+22:force+=s.p.direction_to(w.player)*2
	if w.player.x<150:force.x+=2
	if w.player.x>1898:force.x-=2
	if w.player.y<150:force.y+=2
	if w.player.y>1898:force.y-=2
	var desired=(wish+force*0.5).normalized()
	var best_score=-INF
	var best_dir=Vector2.ZERO
	var nearby=w.in_radius(w.player,135)
	var speed=w.db.data.player_speed*(1+0.08*w.items.get("sugar",0))
	for i in range(17):
		var d=Vector2.from_angle(i*TAU/16) if i<16 else Vector2.ZERO
		var score=d.dot(wish)*12+d.dot(desired)*3
		for horizon in [0.18,0.45,0.8]:
			var p=w.player+d*speed*horizon
			if not w.free_at(p,8):score-=120
			if p.x<80 or p.y<80 or p.x>1968 or p.y>1968:score-=30
			for m in nearby:
				var predicted=m.p+m.dir*m.speed*horizon*0.7
				var dist=p.distance_to(predicted)-m.radius
				var safe=20.0
				if m.kind=="creeper":safe=43
				if m.kind=="ravager":safe=45
				score-=pow(maxf(0,safe+12-dist),2)*0.12
				if m.kind=="skeleton" and m.timer<0.5 and d==Vector2.ZERO:score-=20
			for b in w.projectiles:
				if b.kind!="enemy_arrow":continue
				var bp=b.p+b.dir*b.speed*horizon
				var dist=Geometry2D.get_closest_point_to_segment(p,b.p,bp).distance_to(p)
				score-=pow(maxf(0,18-dist),2)*0.18
		if score>best_score:
			best_score=score
			best_dir=d
	if w.build.size()==1 and min_dist>14 and min_dist<30 and closest!=null and best_score>0:
		if w.facing.dot(w.player.direction_to(closest.p))<0.9:return w.player.direction_to(closest.p)
		return Vector2.ZERO
	return best_dir
