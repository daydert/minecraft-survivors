extends RefCounted
const Tells=preload("res://scripts/chapter_four_tells.gd")
const Figures=preload("res://scripts/chapter_four_finale_view.gd")
static func floor_layer(g,offset: Vector2):
 var e=g.world.ending;var a=e.terrain_attack
 for echo in a.echoes:
  Figures.figure(g,"ch4_hb_calm","herobrine",echo.pose,echo.pose_age,echo.p+offset,echo.dir,echo.scale,Color(.6,.34,.42,.17*(1-echo.age/.32)),false)
 if a.kind=="spiral":
  var r: Dictionary=e.data.terrain_attacks.spiral
  var previous: Dictionary={}
  for spike in a.spikes:
   if not previous.is_empty() and spike.seed==previous.seed+1:
    g.draw_line(previous.p+offset,spike.p+offset,Color(.025,.01,.02,.65),3)
    g.draw_line(previous.p+offset,spike.p+offset,Color(.8,.36,.3,.35),1)
   previous=spike
   var t: float=e.move_age-spike.born
   if t>float(r.rise)+float(r.hold)+float(r.sink):continue
   var k: float=clampf((e.move_age-(spike.born-float(r.windup)))/float(r.windup),0,1)
   Tells.bulge(g,spike.p+offset,k,int(spike.seed),g.world.clock)
 elif a.kind=="fault_smash":
  var r: Dictionary=e.data.terrain_attacks.smash
  var age: float=e.move_age-float(r.windup)
  if age<0:
   Tells.bulge(g,a.faults[0].origin+offset,clampf(e.move_age/r.windup,0,1),75,g.world.clock)
   return
  for fault in a.faults:
   var points: PackedVector2Array=fault.points
   var grow: float=smoothstep(0,.45,age)
   var glow: float=smoothstep(.5,float(r.delay),age)*(1-smoothstep(float(r.delay)+float(r.beam),e.move_time-float(r.windup),age))
   for i in range(1,points.size()):
    if float(i-1)/(points.size()-1)>grow:break
    var p: Vector2=points[i-1]+offset;var end: Vector2=points[i]+offset
    g.draw_line(p,end,Color(.025,.0,.01),4)
    if glow>0:
     g.draw_line(p,end,Color(.8,.035,.045,.75*glow),3)
     g.draw_line(p,end,Color(1,.38,.26,glow),1)
static func spike(g,spike: Dictionary,offset: Vector2):
 var e=g.world.ending;var r: Dictionary=e.data.terrain_attacks.spiral
 var age: float=e.move_age-spike.born
 var rise: float=smoothstep(0,float(r.rise),age)*(1-smoothstep(float(r.rise)+float(r.hold),float(r.rise)+float(r.hold)+float(r.sink),age))
 if rise<=0:return
 if not g.textures.has("ch4_spiral_spike"):g.load_texture("ch4_spiral_spike")
 var tex: Texture2D=g.textures.get("ch4_spiral_spike")
 if tex==null:return
 var size:=Vector2(tex.get_size());var h: float=roundf(size.y*rise)
 var p: Vector2=spike.p+offset
 g.draw_texture_rect_region(tex,Rect2((p-Vector2(size.x,h*2)).floor(),Vector2(size.x*2,h*2)),Rect2(0,0,size.x,h))
static func air_layer(g,offset: Vector2):
 var e=g.world.ending;var a=e.terrain_attack
 if a.kind!="fault_smash":return
 var r: Dictionary=e.data.terrain_attacks.smash
 var t: float=e.move_age-float(r.windup)-float(r.delay)
 if t<0 or t>=float(r.beam):return
 var envelope: float=smoothstep(0,.075,t)*(1-smoothstep(float(r.beam)-.15,float(r.beam),t))
 for fault in a.faults:
  var points: PackedVector2Array=fault.points
  for i in [2,4,6]:
   var p: Vector2=points[i]+offset
   var h: float=(float(r.height)+sin(i*2.1+float(fault.seed))*11)*envelope
   for layer in range(3):
    var width: float=[11.0,6.0,2.0][layer]*envelope
    var color: Color=[Color(1,.015,.035,.13),Color(1,.035,.04,.50),Color(1,.35,.16,.85)][layer]
    var vertices:=PackedVector2Array([p+Vector2(-width,0),p+Vector2(width,0),p+Vector2(width*.5,-h*.72),p-Vector2(0,h),p+Vector2(-width*.5,-h*.72)])
    g.draw_polygon(vertices,PackedColorArray([Color(color,color.a*envelope),Color(color,color.a*envelope),Color(color,color.a*.42*envelope),Color(color,0),Color(color,color.a*.42*envelope)]))
   for j in range(2):
    var lift: float=fposmod(t*135+i*17+j*23,maxf(1,h))
    var q: Vector2=p+Vector2(sin(i*2.1+j)*3,-lift)
    g.draw_rect(Rect2(q.floor(),Vector2(1,3)),Color(1,.64,.30,envelope*(1-lift/maxf(1,h))))
