extends RefCounted
## Blender-authored local transforms. Sampling is a pure function of scene age:
## seeking, screenshots, pause and live gameplay all evaluate the same frame.
## For Claude / future reviewers: the user explicitly commissioned these
## cinematic rigs. Native UV limbs gain elbows/knees only in staged scenes;
## the combat rig, collision, simulation clocks and RNG remain independent.
## Rationale and asset permissions: docs/CHAPTER_FIVE_CINEMATIC_POLISH.md.
const DATA_PATH := "res://data/chapter_five_cinema.json"
const PARENTS := {"hips":"root","torso":"hips","head":"torso","ra":"torso","la":"torso","rl":"hips","ll":"hips","re":"ra","le":"la","rk":"rl","lk":"ll","grip":"re"}
const REST := {"hips":Vector3(0,.75,0),"torso":Vector3.ZERO,"head":Vector3(0,.75,0),"ra":Vector3(-.3125,.625,0),"la":Vector3(.3125,.625,0),"rl":Vector3(-.11875,0,0),"ll":Vector3(.11875,0,0),"re":Vector3(0,-.25,0),"le":Vector3(0,-.25,0),"rk":Vector3(0,-.375,0),"lk":Vector3(0,-.375,0),"grip":Vector3(-.0625,-.375,0)}

static func material(v, skin: String) -> ShaderMaterial:
	var m := ShaderMaterial.new();m.shader=load("res://shaders/ch5_cinema_skin.gdshader");m.set_shader_parameter("skin_texture",v.tex(skin));return m

static func segment(size: Vector3, uv: Vector2, start: float, count: float, inflate := 0.0) -> ArrayMesh:
	var w: float=size.x;var h: float=size.y;var d: float=size.z
	var ex: float=(w*.5+inflate)/16.0;var ey: float=(count*.5+inflate)/16.0;var ez: float=(d*.5+inflate)/16.0
	var u: float=uv.x;var q: float=uv.y
	var faces := [
		[[Vector3(-ex,ey,ez),Vector3(ex,ey,ez),Vector3(ex,-ey,ez),Vector3(-ex,-ey,ez)],Rect2(u+d,q+d+start,w,count),Vector3.BACK],
		[[Vector3(ex,ey,-ez),Vector3(-ex,ey,-ez),Vector3(-ex,-ey,-ez),Vector3(ex,-ey,-ez)],Rect2(u+2*d+w,q+d+start,w,count),Vector3.FORWARD],
		[[Vector3(-ex,ey,-ez),Vector3(-ex,ey,ez),Vector3(-ex,-ey,ez),Vector3(-ex,-ey,-ez)],Rect2(u,q+d+start,d,count),Vector3.LEFT],
		[[Vector3(ex,ey,ez),Vector3(ex,ey,-ez),Vector3(ex,-ey,-ez),Vector3(ex,-ey,ez)],Rect2(u+d+w,q+d+start,d,count),Vector3.RIGHT],
		[[Vector3(-ex,ey,-ez),Vector3(ex,ey,-ez),Vector3(ex,ey,ez),Vector3(-ex,ey,ez)],Rect2(u+d,q,w,d),Vector3.UP],
		[[Vector3(-ex,-ey,ez),Vector3(ex,-ey,ez),Vector3(ex,-ey,-ez),Vector3(-ex,-ey,-ez)],Rect2(u+d+w,q,w,d),Vector3.DOWN]]
	var st := SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in faces:
		var rect: Rect2=f[1];var uvs=[rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]
		for i in [0,1,2,0,2,3]:st.set_normal(f[2]);st.set_uv(uvs[i]/64.0);st.add_vertex(f[0][i])
	return st.commit()

static func limb(r: Dictionary, key: String, m: Material, uv: Vector2, outer: Vector2, offset: Vector3, start: int):
	for shell in range(2):
		var mi := MeshInstance3D.new();mi.mesh=segment(Vector3(4,12,4),uv if shell==0 else outer,start,6,0.0 if shell==0 else .25)
		mi.material_override=m;mi.position=offset;r[key].add_child(mi)

static func rig(v, skin: String) -> Dictionary:
	var r: Dictionary={};var m := material(v,skin)
	r.root=Node3D.new();v.scene.add_child(r.root)
	for key in PARENTS:r[key]=v.pivot(r[PARENTS[key]],REST[key])
	v.part(r.torso,skin,Vector3(8,12,4),Vector2(16,16),Vector2(16,32),Vector3(0,.375,0))
	v.part(r.head,skin,Vector3(8,8,8),Vector2.ZERO,Vector2(32,0),Vector3(0,.25,0))
	limb(r,"ra",m,Vector2(40,16),Vector2(40,32),Vector3(-.0625,-.0625,0),0)
	limb(r,"re",m,Vector2(40,16),Vector2(40,32),Vector3(-.0625,-.1875,0),6)
	limb(r,"la",m,Vector2(32,48),Vector2(48,48),Vector3(.0625,-.0625,0),0)
	limb(r,"le",m,Vector2(32,48),Vector2(48,48),Vector3(.0625,-.1875,0),6)
	limb(r,"rl",m,Vector2(0,16),Vector2(0,32),Vector3(0,-.1875,0),0)
	limb(r,"rk",m,Vector2(0,16),Vector2(0,32),Vector3(0,-.1875,0),6)
	limb(r,"ll",m,Vector2(16,48),Vector2(0,48),Vector3(0,-.1875,0),0)
	limb(r,"lk",m,Vector2(16,48),Vector2(0,48),Vector3(0,-.1875,0),6)
	for key in ["torso","head"]:
		for child in r[key].get_children():
			if child is MeshInstance3D:
				child.material_override=m
				for shell in child.get_children():
					if shell is MeshInstance3D:shell.material_override=m
	r.material=m
	return r

static func vec(a: Array) -> Vector3:return Vector3(float(a[0]),float(a[1]),float(a[2]))
static func rotation(a: Array) -> Quaternion:return Quaternion(float(a[3]),float(a[4]),float(a[5]),float(a[6])).normalized()
static func apply(v, track: String, age: float, camera := true):
	if not v.cache.has("cinema_tracks"):v.cache.cinema_tracks=JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)).tracks
	var spec: Dictionary=v.cache.cinema_tracks[track];var frames: Array=spec.frames
	var at: float=clampf(age*float(spec.fps),0,frames.size()-1);var i: int=int(at);var j: int=mini(i+1,frames.size()-1);var k: float=at-i
	var a: Dictionary=frames[i];var b: Dictionary=frames[j]
	for who in ["steve","notch"]:
		if not a.has(who) or not v.rigs.has(who):continue
		var r: Dictionary=v.rigs[who]
		for key in a[who]:
			var x: Array=a[who][key];var y: Array=b[who][key]
			r[key].position=vec(x).lerp(vec(y),k);r[key].quaternion=rotation(x).slerp(rotation(y),k)
		if r.has("material"):r.material.set_shader_parameter("clip_enabled",track.begins_with("portal_"))
	if camera:
		var x: Array=a.cam;var y: Array=b.cam
		# Snap authored cuts also at 60 Hz; no interpolated frame flies between shots.
		var ck: float=0.0 if vec(x).distance_to(vec(y))>.25 and k<.999 else k
		var from: Vector3=vec(x).lerp(vec(y),ck);var to: Vector3=Vector3(x[3],x[4],x[5]).lerp(Vector3(y[3],y[4],y[5]),ck)
		v.shot(v.nodes.cam,from,to,lerpf(x[6],y[6],ck))

static func chair(v, f, clock: float):
	var t: float=f.age;apply(v,"chair",t)
	v.rigs.steve.material.set_shader_parameter("blood_amount",.18+.47*smoothstep(33,33.14,t))
	v.rigs.notch.material.set_shader_parameter("blood_amount",.30+.40*smoothstep(33,33.14,t))
	v.nodes.sword.visible=t>=f.CHAIR_SWORD
	var scan: bool=t>=f.CHAIR_SCAN[0] and t<f.CHAIR_SCAN[1]
	v.nodes.cable.visible=scan
	if scan:
		var from := Vector3(2.0,1,-1);var to: Vector3=v.rigs.notch.head.global_position+Vector3(0,.3,0)
		v.nodes.cable.position=(from+to)*.5;v.nodes.cable.scale=Vector3(from.distance_to(to),1,1);v.nodes.cable.look_at(to,Vector3.UP);v.nodes.cable.rotate_object_local(Vector3.UP,PI/2)
	v.nodes.screen.text="scan: %d%%\n%s"%[int(f.scan()*100),"exit() found" if f.scan()>=1 else "reading…"]
	v.nodes.glow.light_energy=.75 if scan else 0
	v.nodes.lamp.rotation=Vector3(-PI/2,0,0);v.nodes.lamp.light_energy=4.2
	for i in range(3):v.nodes["chain%d"%i].visible=false
	for side in ["r","l"]:
		var cuff: MeshInstance3D=v.nodes["cuff_"+side]
		cuff.global_transform=v.rigs.notch[side+"e"].global_transform.translated_local(Vector3(-.0625 if side=="r" else .0625,-.32,0))
		var anchor := Vector3(-.48 if side=="r" else .48,.69,.0)
		var to: Vector3=cuff.global_position
		var tie: Node3D=v.nodes["tie_"+side];tie.position=(anchor+to)*.5;tie.scale=Vector3(anchor.distance_to(to),1,1)
		tie.look_at(to);tie.rotate_object_local(Vector3.UP,PI/2)
	var since: float=t-f.CHAIR_STAB
	v.nodes.pool.visible=since>.5;var spread: float=smoothstep(.5,9,since)
	v.nodes.pool.scale=Vector3(.08+spread*.6,1,.08+spread*.4)
	var shown: Array=[]
	if scan:
		for i in range(8):
			var q: Node3D=v.take("glyph","");var u: float=fposmod(clock*.45+i*.125,1)
			q.position=(v.rigs.notch.head.global_position+Vector3(0,.4,0)).lerp(Vector3(2.3,1.3,-1),u)
			(q as Label3D).text=["0","1","{","}"][i%4];(q as Label3D).modulate.a=.65;shown.append(q)
	if since>=0 and since<1.0:shown+=v.blood_spray(Vector3(.06,1.12,.05),since*.65,clock)
	if since>.5 and since<9:shown+=v.blood_drips(Vector3(.06,1.05,.16),since,clock)
	if t>38.5 and t<39.1:shown+=v.blood_spray(Vector3(.06,1.12,.20),(t-38.5)*.9,clock)
	v.hide_rest(shown)

static func erase_throw(v, f):
	if f.thrown < 0:
		for joint in ["re","le","rk","lk","grip"]:v.rigs.steve[joint].quaternion=Quaternion.IDENTITY
		v.rigs.steve.hips.position.y=.74
		var prep: float=smoothstep(8,14,float(f.presses))
		v.rigs.steve.ra.rotation.x=lerpf(-.4,-2.2,prep)
		v.rigs.steve.re.rotation.x=-.8*prep
		return
	# Release uses the very same evaluated hand as the held sword. The blade
	# then travels point-first to the console; it cannot jump from a fake origin.
	if not v.nodes.has("release_origin"):
		apply(v,"erase_throw",.16,false)
		v.nodes.release_origin=v.rigs.steve.grip.global_position
		v.nodes.release_rotation=v.rigs.steve.grip.global_basis.get_rotation_quaternion()
	apply(v,"erase_throw",f.thrown)
	v.nodes.sword.visible=f.thrown<.16
	v.nodes.flying.visible=f.thrown>=.16
	var target := Vector3(.3,2.5,-2.7)
	var from: Vector3=v.nodes.release_origin
	var k: float=clampf((f.thrown-.16)/.44,0,1)
	v.nodes.flying.position=from.lerp(target,k)
	v.nodes.flying.quaternion=v.nodes.release_rotation
	if f.thrown>=.6:
		# Breaking delete() restores the body's missing pixels, before the brawl.
		for key in ["torso","head","ra","la","rl","ll","re","le","rk","lk"]:
			for mesh in v.rigs.steve[key].get_children():
				if mesh is MeshInstance3D:mesh.visible=true

static func wire(v, fi, shown: Array):
	var active: bool=fi.mode=="fists" and fi.state in ["wire","done"]
	if not active:
		if v.nodes.has("wire_rigs"):
			for who in ["steve","notch"]:v.nodes.wire_rigs[who].root.visible=false
		return
	if not v.nodes.has("wire_rigs"):
		v.nodes.wire_rigs={"steve":rig(v,"ch5_skin_steve"),"notch":rig(v,"ch5_skin_notch")}
	var combat: Dictionary=v.rigs;v.rigs=v.nodes.wire_rigs
	apply(v,"wire",fi.age,false)
	var face: float=signf(fi.notch().x-fi.steve().x)
	for who in ["steve","notch"]:
		combat[who].root.visible=false;v.rigs[who].root.visible=true
		v.rigs[who].root.position.x=fi.steve().x if who=="steve" else fi.notch().x
		v.rigs[who].root.rotation.y=face*PI/2*(1 if who=="steve" else -1)
	var from: Vector3=v.rigs.steve.grip.global_position
	var chest: Vector3=v.rigs.notch.torso.global_position+Vector3(0,.38,0)
	var to: Vector3=from.lerp(chest+Vector3(face*.7,0,0),smoothstep(0,.2,fi.age))
	var cable: Node3D=v.take("wire","")
	cable.position=(from+to)*.5;cable.scale=Vector3(maxf(.01,from.distance_to(to)),1,1)
	if from.distance_to(to)>.001:cable.look_at(to);cable.rotate_object_local(Vector3.UP,PI/2)
	shown.append(cable)
	var mid: float=(fi.steve().x+fi.notch().x)*.5
	v.shot(v.nodes.cam,Vector3(mid+.6,1.55,4.4+absf(fi.steve().x-fi.notch().x)*.8),Vector3(mid,1,0),42)
	v.rigs=combat

static func impact(v, at: Vector3, age: float, teeth := true):
	v.blood_spray(at,age,v.get_instance_id()%9)
	if teeth:
		for k in range(4):
			var fragment: Node3D=v.take("tooth","")
			fragment.position=at+Vector3((k-1.5)*.65,.6+k*.15,.8+k*.2)*age+Vector3(0,-4.8*age*age,0)
			fragment.rotation=Vector3(age*(12+k),k,age*8);fragment.scale=Vector3.ONE

static func qte(v, q):
	for who in ["steve","notch"]:
		v.rigs[who].root.visible=true;v.rigs[who].material.set_shader_parameter("erase_amount",0.0)
	v.nodes.ko_table.visible=q.finishing
	# The set includes the table legs; hide the whole table assembly together.
	for leg in v.nodes.get("ko_legs",[]):leg.visible=q.finishing
	if q.finishing:
		apply(v,"finisher",q.finish_age)
		if q.finish_age>=.65 and q.finish_age<1.25:impact(v,Vector3(.36,1.65,.25),q.finish_age-.65)
		if q.finish_age>=1.12 and q.finish_age<1.45:impact(v,Vector3(.75,.98,1.18),q.finish_age-1.12,false)
		for who in ["steve","notch"]:v.rigs[who].material.set_shader_parameter("blood_amount",.6)
		v.hide_rest([]);return
	var track: String=q.TRACKS[mini(q.beat,q.TRACKS.size()-1)]
	if q.resolved and not q.success:track="miss"
	apply(v,"qte_"+track,q.age)
	for who in ["steve","notch"]:v.rigs[who].material.set_shader_parameter("blood_amount",minf(.65,.15+q.beat*.055))
	if q.age>=1 and q.age<1.65 and track in ["jab","cross","hook","uppercut","miss"]:
		var victim: String="steve" if track=="miss" else "notch"
		impact(v,v.rigs[victim].head.global_position+Vector3(0,.15,.12),q.age-1)
	if track in ["parry","guard"] and q.age>=1.4 and q.age<2.0:impact(v,v.rigs.notch.head.global_position+Vector3(0,.15,.12),q.age-1.4)
	v.hide_rest([])

static func bad_end(v,n):
	var t: float=n.age
	var offset: float=4.2 if n.bad_from_qte else 0.0
	var local: float=maxf(0,t-offset)
	apply(v,"bad_qte" if n.bad_from_qte else "bad_end",t)
	if n.bad_from_qte and t<.35:
		# Match whichever failed exchange actually ended gameplay, including its
		# camera. This short blend continues the movement instead of resetting it.
		var target: Dictionary={}
		for who in ["steve","notch"]:
			target[who]={}
			for key in PARENTS.keys()+["root"]:target[who][key]=v.rigs[who][key].transform
		var cam_to: Transform3D=v.nodes.cam.transform;var fov_to: float=v.nodes.cam.fov
		apply(v,"qte_"+n.bad_entry_track,2.4)
		var k: float=smoothstep(0,.35,t)
		for who in target:
			for key in target[who]:v.rigs[who][key].transform=v.rigs[who][key].transform.interpolate_with(target[who][key],k)
		v.nodes.cam.transform=v.nodes.cam.transform.interpolate_with(cam_to,k);v.nodes.cam.fov=lerpf(v.nodes.cam.fov,fov_to,k)
	var erased: float=.28*smoothstep(0,.3,local)+.72*smoothstep(1.28,2.32,local)
	v.rigs.steve.material.set_shader_parameter("erase_amount",erased)
	v.rigs.steve.material.set_shader_parameter("blood_amount",n.bad_blood)
	v.rigs.notch.material.set_shader_parameter("blood_amount",n.bad_blood)
	v.rigs.steve.root.visible=local<2.36
	v.rigs.notch.root.visible=local<16.8
	v.rigs.notch.material.set_shader_parameter("erase_amount",0.0)
	v.nodes.bad_sword.visible=local<2.36 and (not n.bad_from_qte or t>=1.5)
	v.nodes.bad_blade_material.set_shader_parameter("erase_amount",erased)
	v.nodes.bad_door.rotation.y=-smoothstep(13.45,14.05,local)*1.65
	v.nodes.beer.global_transform=(v.rigs.notch.grip.global_transform.translated_local(Vector3(0,.015,.15)) if local>=5.1 else Transform3D(Basis.IDENTITY,Vector3(.90,1.10,-1.85)))
	v.nodes.beer.visible=local<16.8
	for i in range(v.nodes.bad_shards.size()):
		var item: Dictionary=v.nodes.bad_shards[i];var age: float=local-item.born
		if age<0 or age>1.6:continue
		var piece: Node3D=v.take("skin_shard",item.variant)
		piece.position=item.p+item.v*age+Vector3(0,-2.5*age*age,0);piece.position.y=maxf(.035,piece.position.y)
		piece.rotation=Vector3(age*7+i,age*9,age*5);piece.scale=Vector3.ONE*(1-smoothstep(.9,1.6,age))
	v.hide_rest([])
