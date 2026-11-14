extends RefCounted
## Charge tells for chapters I–III and V in the chapter IV ground language.
## Each mob gets its own shape: a fuse for the creeper, an axe bite for the
## vindicator, hoofprints for the ravager, tusk furrows for the hoglin, wind
## chevrons for the phantom, bone dust for bows and a lock for crossbows.
const Tells=preload("res://scripts/chapter_four_tells.gd")

static func draw(g, m: Dictionary, offset: Vector2):
	if m.hp<=0:return
	var w=g.world
	var p: Vector2=(m.p+offset).floor()
	var seed: int=int(m.id)*7
	var clock: float=w.clock
	var to: Vector2=m.p.direction_to(w.player)
	var distance: float=m.p.distance_to(w.player)
	match m.kind:
		"creeper":
			if m.get("fuse",-1.0)>=0:
				var k: float=1.0-m.fuse/.9
				Tells.fuse(g,p,42.0,k,seed,clock)
		"vindicator":
			if m.phase=="windup":Tells.chop(g,p,m.charge,32.0,1.5,1.0-m.timer/.5,seed,clock)
		"ravager":
			if m.phase=="windup":
				var k: float=clampf(1.0-m.timer/.8,0,1);var end: Vector2=p+m.charge*156
				Tells.lane(g,p,end,23.0,k,seed,clock);Tells.hooves(g,p,end,k,seed+3,clock)
		"phantom":
			if m.phase=="windup":
				var k: float=clampf(1.0-m.timer/float(w.night.phantom_windup),0,1)
				var dir: Vector2=(m.mark-m.p).normalized();var end: Vector2=(m.mark+dir*40.0+offset).floor()
				Tells.crack(g,p,end,k,seed,2.0,1.0,clock);Tells.chevrons(g,p,end,k,clock)
		"skeleton":
			if m.timer<.5 and distance>=120 and distance<=220:Tells.aim(g,p-Vector2(0,10),to,90,1.0-m.timer/.5,clock)
		"brute":
			if m.phase=="windup":
				var k: float=clampf(1.0-m.timer/.7,0,1)
				Tells.lane(g,p,p+m.charge*104,14.0,k,seed,clock);Tells.chop(g,p+m.charge*104,m.charge,22.0,1.6,k,seed+5,clock)
		"hoglin","zoglin":
			if m.phase=="windup":Tells.tusks(g,p,m.charge,98.0,clampf(1.0-m.timer/.7,0,1),seed,clock)
		"piglin_crossbow":
			if m.timer<.6 and (m.get("turret",false) or distance>=95) and distance<280:
				var k: float=1.0-m.timer/.6
				Tells.aim(g,p-Vector2(0,10),to,minf(distance,110),k,clock);Tells.lock(g,(w.player+offset).floor(),k,clock)
		"blaze_nether":
			if m.timer<.7 and (m.get("turret",false) or distance>=95) and distance<280:
				var k: float=1.0-m.timer/.7
				for j in range(3):Tells.aim(g,p-Vector2(0,12),to.rotated((j-1)*.14),80,k,clock)
				Tells.embers(g,p-Vector2(0,6),k,seed,clock)
		"dispenser_enderman":
			if m.timer<.6 and distance>=105 and distance<300:
				var k: float=1.0-m.timer/.6
				Tells.aim(g,p-Vector2(0,14),to,minf(distance,110),k,clock);Tells.lock(g,(w.player+offset).floor(),k,clock)
		"shulker":
			if m.timer<.6 and distance<265:
				Tells.aim(g,p-Vector2(0,6),Vector2.UP,30,1.0-m.timer/.6,clock)
		"endermite_brood":
			if m.timer<.9:
				for j in range(3):Tells.bulge(g,(p+Vector2.from_angle(j*TAU/3+float(m.id))*24).floor(),1.0-m.timer/.9,seed+j*5,clock)

## 0..1 while the mob charges, -1 otherwise; mirrors the conditions in draw().
static func progress(w, m: Dictionary) -> float:
	if m.hp<=0:return -1.0
	var distance: float=m.p.distance_to(w.player)
	match m.kind:
		"creeper":return 1.0-m.fuse/.9 if m.get("fuse",-1.0)>=0 else -1.0
		"vindicator":return 1.0-m.timer/.5 if m.phase=="windup" else -1.0
		"ravager":return clampf(1.0-m.timer/.8,0,1) if m.phase=="windup" else -1.0
		"phantom":return clampf(1.0-m.timer/float(w.night.phantom_windup),0,1) if m.phase=="windup" else -1.0
		"skeleton":return 1.0-m.timer/.5 if m.timer<.5 and distance>=120 and distance<=220 else -1.0
		"brute","hoglin","zoglin":return clampf(1.0-m.timer/.7,0,1) if m.phase=="windup" else -1.0
		"piglin_crossbow":return 1.0-m.timer/.6 if m.timer<.6 and (m.get("turret",false) or distance>=95) and distance<280 else -1.0
		"blaze_nether":return 1.0-m.timer/.7 if m.timer<.7 and (m.get("turret",false) or distance>=95) and distance<280 else -1.0
		"dispenser_enderman":return 1.0-m.timer/.6 if m.timer<.6 and distance>=105 and distance<300 else -1.0
		"shulker":return 1.0-m.timer/.6 if m.timer<.6 and distance<265 else -1.0
		"endermite_brood":return 1.0-m.timer/.9 if m.timer<.9 else -1.0
	return -1.0

## A warm glow on a charging body so the tell reads in the darkest night too.
static func lights(g):
	var w=g.world
	for m in w.mobs:
		var k: float=progress(w,m)
		if k<0:continue
		var c: Color=Tells.HOT
		g.ambient_lights.append({"p":m.p-Vector2(0,10),"r":30.0+26.0*k,"c":c,"power":.35+.45*k,"glow":.06+.1*k})
		var reach: float={"ravager":156.0,"brute":104.0,"hoglin":98.0,"zoglin":98.0}.get(m.kind,0.0)
		if m.kind=="phantom":g.ambient_lights.append({"p":m.mark,"r":40.0,"c":c,"power":.45*k,"glow":.05})
		elif m.kind=="creeper":g.ambient_lights.append({"p":m.p,"r":60.0,"c":c,"power":.3+.3*k,"glow":.04})
		elif reach>0:
			for t in [.5,1.0]:g.ambient_lights.append({"p":m.p+m.charge*reach*t,"r":38.0,"c":c,"power":.25+.35*k,"glow":.04})
