extends RefCounted
## New terrain attacks share their exact stored paths with tells and damage.
## Own encounter RNG only; every timer follows the paused boss clock.
var spikes: Array=[]
var faults: Array=[]
var echoes: Array=[]
var kind:=""
var contact:=false
var emitted:=false
var motion_move:=""
var motion_index:=-1
var motion_from:=Vector2.ZERO
var motion_to:=Vector2.ZERO
var echo_clock:=-1.0
func reset():
 spikes.clear();faults.clear();echoes.clear();kind="";contact=false;emitted=false;motion_move="";motion_index=-1;echo_clock=-1
func start(e,w,name: String):
 spikes.clear();faults.clear();kind=name;contact=false;emitted=false
 if name=="spiral":
  var r: Dictionary=e.data.terrain_attacks.spiral
  var origin: Vector2=e.hb.p
  var turn: float=e.rng.randf()*TAU
  for i in range(int(r.count)):
   var u: float=float(i)/(int(r.count)-1)
   var angle: float=turn+u*TAU*float(r.turns)
   var p: Vector2=origin+Vector2(cos(angle),sin(angle)*.62)*lerpf(r.inner,r.outer,u)
   if not e.arena.grow(-10).has_point(p):continue
   spikes.append({"p":p,"born":float(r.windup)+i*float(r.step),"hit":false,"seed":i})
  e.begin_move(w,"spiral",float(r.windup)+(int(r.count)-1)*float(r.step)+float(r.rise)+float(r.hold)+float(r.sink)+.2)
  e.set_pose("spiral_raise");w.sound("ch4_hb_charge",.1);e.cast_fx(w)
 else:
  var r: Dictionary=e.data.terrain_attacks.smash
  var origin: Vector2=e.hb.p+e.hb.p.direction_to(w.player)*12
  var turn: float=e.rng.randf()*TAU
  for i in range(6):
   var angle: float=turn+i*TAU/6+e.rng.randf_range(-.16,.16)
   var dir:=Vector2.from_angle(angle);var side:=dir.orthogonal()
   var length: float=e.rng.randf_range(float(r.min_length),float(r.max_length))
   var points:=PackedVector2Array([origin+dir*12])
   for j in range(1,8):
    var p: Vector2=origin+dir*length*j/7.0+side*e.rng.randf_range(-12,12)*sin(j*PI/7)
    points.append(p.clamp(e.arena.position+Vector2(12,12),e.arena.end-Vector2(12,12)))
   faults.append({"points":points,"seed":i+e.rng.randi_range(0,999),"origin":origin})
  e.begin_move(w,"fault_smash",float(r.windup)+float(r.delay)+float(r.beam)+float(r.recover))
  e.set_pose("ground_smash");w.sound("ch4_hb_charge",.1)
func step(e,w,dt: float):
 if kind=="spiral":
  var r: Dictionary=e.data.terrain_attacks.spiral
  e.pose="spiral_raise";e.pose_age=minf(e.move_age,2.6)
  for spike in spikes:
   var t: float=e.move_age-spike.born
   if t<0:continue
   if not spike.hit and t>=float(r.rise):
    spike.hit=true;w.sound("ch4_stone_rise",.10)
    if spike.seed%5==0:w.fx.dust(spike.p,3,16)
   if t>=float(r.rise) and t<float(r.rise)+float(r.hold) and w.player.distance_to(spike.p)<float(r.radius):w.receive_hit(float(r.damage),e.hb)
 else:
  var r: Dictionary=e.data.terrain_attacks.smash
  e.pose="ground_smash";e.pose_age=e.move_age
  if not contact and e.move_age>=float(r.windup):
   contact=true;w.sound("ch4_ground_slam",.1);w.sound("ch4_stone_rise",.1);w.fx.quake(w,e.hb.p,1.4);w.fx.erupt(w,e.hb.p,"stone",10);w.hitstop=maxf(w.hitstop,.09)
  var t: float=e.move_age-float(r.windup)-float(r.delay)
  if t>=0 and not emitted:emitted=true;w.sound("ch4_hb_fire",.1);w.sound("ch4_hb_rift",.1);w.fx.quake(w,e.hb.p,.55)
  if t>=0 and t<float(r.beam):
   for fault in faults:
    var points: PackedVector2Array=fault.points
    for i in range(1,points.size()):
     if Geometry2D.get_closest_point_to_segment(w.player,points[i-1],points[i]).distance_to(w.player)<float(r.width):w.receive_hit(float(r.damage),e.hb);break
 if e.move_age>=e.move_time:
  spikes.clear();faults.clear();kind=""
  if e.phase=="tower":e.begin_move(w,"rest",float(e.data.tower.rest));e.set_pose("aura")
  else:e.rest(w,.35)
func step_motion(e,w,dt: float):
 for ghost in echoes:ghost.age+=dt
 echoes=echoes.filter(func(ghost):return ghost.age<.32)
 if e.phase!="two" or e.move not in ["hole","rain","rift","tear","day"]:
  motion_move="";return
 if motion_move!=e.move:motion_move=e.move;motion_index=-1
 # One short planted step, then a pause to cast. Never translate an idle
 # sprite continuously. Day's levitation keeps its airborne pose.
 var age: float=e.move_age-1.35
 if age<0:return
 var index: int=int(age/2.7);var step_age: float=fposmod(age,2.7)
 if index!=motion_index:
  motion_index=index;motion_from=e.hb.p
  var toward: Vector2=e.hb.p.direction_to(w.player)
  if e.hb.p.distance_to(w.player)<75:toward=-toward
  motion_to=(motion_from+toward*12).clamp(e.arena.position+Vector2(28,38),e.arena.end-Vector2(28,28))
 if step_age>1:return
 var before: Vector2=e.hb.p
 e.hb.p=motion_from.lerp(motion_to,smoothstep(0,1,step_age))
 var walking: String="cast_step" if e.pose!="float" else "float"
 if walking=="cast_step":e.pose=walking;e.pose_age=step_age
 if before.distance_squared_to(e.hb.p)>.001 and w.clock-echo_clock>.13:
  echo_clock=w.clock;echoes.append({"p":before,"dir":e.hb.visual_dir,"pose":walking,"pose_age":step_age,"age":0.0,"scale":e.scale()})
  while echoes.size()>3:echoes.pop_front()
