extends RefCounted
## Cinematic only: separate RNG and debris, with no combat hitboxes.
const DURATION=10.2
const BURST=5.25
const ORIGIN=Vector2(1024,1094)
var pieces: Array=[]
var cues=0
var ruptured=false
var rng=RandomNumberGenerator.new()
var assets: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/ghast_intro_assets.json"))

func reset():pieces.clear();cues=0;ruptured=false
func begin(seed_value: int):reset();rng.seed=seed_value^0x6a57b

func rupture(w):
	ruptured=true
	for i in range(assets.pieces.size()):
		var spec=assets.pieces[i];var c=Vector3(spec.center[0],spec.center[1],spec.center[2])
		var outward=Vector2(c.x,c.z*.8+float(i%3)-1).normalized()
		if outward.length_squared()<.01:outward=Vector2.from_angle(i*2.399)
		var p=ORIGIN+Vector2(c.x*6,-c.z*6*sin(deg_to_rad(20)))
		pieces.append({"sprite":spec.sprite,"size":Vector2(spec.size[0],spec.size[1]),"p":p,"height":c.y*6*cos(deg_to_rad(20)),"v":outward*rng.randf_range(130,215),"lift":rng.randf_range(65,145),"age":0.0,"life":rng.randf_range(4.4,6.8),"spin":rng.randf_range(-2.8,2.8),"leg":i>=8,"bounces":0})
	w.shake=maxf(w.shake,.3)

func step(w, dt: float):
	if w.stage=="arrival":
		var schedule=[[1.2,"ghast_intro_cry"],[3.0,"ghast_intro_charge"],[BURST,"ghast_intro_death"],[BURST,"ghast_intro_burst"],[6.45,"herobrine"],[8.5,"wither_charge"]]
		for i in range(schedule.size()):
			if w.stage_age>=float(schedule[i][0]) and not (cues & (1<<i)):
				cues|=1<<i;w.sound(schedule[i][1],.05)
		if w.stage_age>=BURST and not ruptured:rupture(w)
	for i in range(pieces.size()-1,-1,-1):
		var p=pieces[i];p.age+=dt
		p.p+=p.v*dt;p.height+=p.lift*dt;p.lift-=235*dt
		if p.height<0:
			p.height=0
			if p.bounces<2 and p.lift< -45:p.lift=-p.lift*.28;p.v*=.7;p.bounces+=1
			else:p.lift=0;p.v=p.v.move_toward(Vector2.ZERO,dt*120)
		var bounds=w.ARENA.grow(-8)
		if p.p.x<bounds.position.x or p.p.x>bounds.end.x:p.v.x*= -.5
		if p.p.y<bounds.position.y or p.p.y>bounds.end.y:p.v.y*= -.5
		p.p=p.p.clamp(bounds.position,bounds.end)
		if p.age>=p.life:pieces.remove_at(i)
