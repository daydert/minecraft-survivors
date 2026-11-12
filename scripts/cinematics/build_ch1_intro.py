"""Chapter I film. Run through execute_blender_code. Never renders through MCP."""
import bpy, math, random, json
from pathlib import Path
from mathutils import Vector, Quaternion, Matrix
ROOT=Path('/home/daydert/MinecraftSurvivors2'); SRC=ROOT/'assets/art_source/ch1_intro'
NAME='CH1_Garden_Prologue'; FPS=24; LENGTH=50
if NAME in bpy.data.scenes:
 old=bpy.data.scenes[NAME]
 if not old.get('ch1_owned'):raise RuntimeError('Unowned scene')
 for ob in list(old.objects):bpy.data.objects.remove(ob,do_unlink=True)
 bpy.data.scenes.remove(old)
sc=bpy.data.scenes.new(NAME);sc['ch1_owned']=True;bpy.context.window.scene=sc
sc.render.engine='CYCLES';sc.cycles.samples=12;sc.cycles.use_denoising=True
sc.render.fps=FPS;sc.frame_start=1;sc.frame_end=FPS*LENGTH
sc.render.resolution_x=960;sc.render.resolution_y=540;sc.render.resolution_percentage=100
sc.render.image_settings.file_format='PNG';sc.render.image_settings.color_mode='RGB'
sc.view_settings.view_transform='AgX';sc.render.film_transparent=False
sc.world=bpy.data.worlds.new('CH1_World');sc.world.use_nodes=True
bg=sc.world.node_tree.nodes['Background'];bg.inputs[0].default_value=(.29,.43,.61,1)
COL={}
for name in ['Environment','Characters','Cameras','Lights','Effects','Props']:
 col=bpy.data.collections.new('CH1_'+name);sc.collection.children.link(col);COL[name]=col

def link(ob,col='Environment'):COL[col].objects.link(ob);return ob
def empty(name,at=(0,0,0),parent=None,col='Characters'):
 ob=link(bpy.data.objects.new('CH1_'+name,None),col);ob.parent=parent;ob.location=at;ob.rotation_mode='QUATERNION';return ob

def material(name,file=None,color=(1,1,1,1),emit=0):
 m=bpy.data.materials.new('CH1_'+name);m.diffuse_color=color;m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=color;bs.inputs['Roughness'].default_value=.88
 if file:
  im=bpy.data.images.load(str(SRC/file),check_existing=True);im.pack()
  tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=im;tex.interpolation='Closest'
  m.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color']);m.node_tree.links.new(tex.outputs['Alpha'],bs.inputs['Alpha'])
 if emit:bs.inputs['Emission Color'].default_value=color;bs.inputs['Emission Strength'].default_value=emit
 return m
MAT={n:material(n,n+'.png') for n in ['steve','alex','herobrine','grass_block_top','grass_block_side','dirt','dirt_path_top','farmland_moist','wheat_stage7','oak_log','oak_log_top','oak_leaves','oak_planks','cobblestone','normal','iron_sword']}
MAT['water']=material('water',color=(.045,.20,.31,1));MAT['blood']=material('blood',color=(.21,.006,.009,1))
MAT['black']=material('wound',color=(.013,.002,.003,1));MAT['eye']=material('white_eyes',color=(.92,.97,1,1),emit=3)
MAT['gold']=material('brass',color=(.46,.27,.05,1));MAT['smile']=material('smile',color=(.22,.11,.07,1))
# Cube face order: front (-Y), back, right, left, top, bottom. Vanilla cube UV.
def box(name,at,size,mat,parent=None,uv=None,start=0,pixels=None,col='Environment'):
 x,y,z=[s/2 for s in size];verts=[(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]
 faces=[(0,1,5,4),(2,3,7,6),(1,2,6,5),(3,0,4,7),(4,5,6,7),(3,2,1,0)]
 me=bpy.data.meshes.new('CH1_'+name);me.from_pydata(verts,[],faces);me.materials.append(mat);layer=me.uv_layers.new()
 if uv:
  u,v,w,h,d=uv;cnt=pixels if pixels is not None else h
  rects=[(u+d,v+d+start,w,cnt),(u+2*d+w,v+d+start,w,cnt),(u+d+w,v+d+start,d,cnt),(u,v+d+start,d,cnt),(u+d,v,w,d),(u+d+w,v,w,d)];den=64
 else:rects=[(0,0,16,16)]*6;den=16
 for f,(u,v,w,h) in zip(me.polygons,rects):
  for li,(s,t) in zip(f.loop_indices,[(u,v+h),(u+w,v+h),(u+w,v),(u,v)]):layer.data[li].uv=(s/den,1-t/den)
 ob=link(bpy.data.objects.new('CH1_'+name,me),col);ob.parent=parent;ob.location=at
 return ob

def plane(name,at,size,mat,rot=(0,0,0),parent=None,col='Environment'):
 w,h=size;me=bpy.data.meshes.new(name);me.from_pydata([(-w/2,0,0),(w/2,0,0),(w/2,0,h),(-w/2,0,h)],[],[(0,1,2,3)]);me.materials.append(mat);uv=me.uv_layers.new()
 for i,co in enumerate([(0,0),(1,0),(1,1),(0,1)]):uv.data[i].uv=co
 ob=link(bpy.data.objects.new('CH1_'+name,me),col);ob.location=at;ob.rotation_euler=rot;ob.parent=parent;return ob
# Ground tiles keep native texel density rather than stretch a single texture over a field.
R=random.Random(110126)
for x in range(-13,14):
 for y in range(-25,15):
  path=abs(x)<1.4 and y<-2
  farm=-5<=x<=-2 and -1<=y<=4
  top='farmland_moist' if farm else 'dirt_path_top' if path else 'grass_block_top'
  tile=box('tile', (x,y,-.13),(1,1,.25),MAT[top])
  if farm:
   for dx,dy in [(-.24,-.21),(.23,.24)]:
    for angle in [math.pi/4,-math.pi/4]:plane('wheat',(x+dx,y+dy,0),(.65,.7),MAT['wheat_stage7'],(0,0,angle))
for y in range(-1,5):box('irrigation',(-3.5,y,-.004),(.20,.98,.03),MAT['water'])
box('harvest_bed',(.48,-.35,-.05),(.75,.75,.1),MAT['farmland_moist'])
for angle in [0,math.pi/2]:plane('harvest_stalk',(.42,-.28,0),(.62,.66),MAT['wheat_stage7'],(0,0,angle))
# Low garden fence; the path leads into a separate deep forest.
for x in range(-7,5):
 if x in [-1,0,1]:continue
 box('post',(x,5,.45),(.16,.16,.9),MAT['oak_log'])
 for h in [.3,.65]:box('rail',(x+.45,5,h),(.90,.1,.12),MAT['oak_planks'])
# Cottage at rear left: stone foundation, timber walls, layered pitched block roof.
for x in range(-8,-4):
 for y in range(5,9):
  box('foundation',(x,y,.16),(1,1,.32),MAT['cobblestone'])
  if x in [-8,-5] or y in [5,8]:
   for z in [.8,1.8,2.8]:
    if y==5 and x==-6 and z<2.0:continue
    box('cottage',(x,y,z),(1,1,1),MAT['oak_log'] if x in [-8,-5] else MAT['oak_planks'])
for h in range(3):box('roof',(-6.5,6.5,3.4+h*.5),(5.5-h*1.4,5.8,.5),MAT['oak_planks'])
# Tree silhouettes in depth, clear near action. Original leaves; connected trunks/branches.
for i in range(39):
 x=R.uniform(-13,13);y=R.uniform(-25,14)
 if -8<x<5 and -5<y<10:continue
 if -4<x<7 and -12<y<0:continue
 if abs(x)<4 and y<0:continue
 h=R.uniform(3.8,6.8);box('oak_trunk',(x,y,h/2),(.6,.6,h),MAT['oak_log'])
 for j in range(3):box('oak_crown',(x+R.uniform(-.5,.5),y+R.uniform(-.4,.4),h-.5+j*.55),(3.4-j*.65,3.3-j*.55,1.2),MAT['oak_leaves'])
# A few stepping stones and flowers give scale without visual clutter.
for x,y in [(2,3),(3,-2),(-6,-3),(-3,-6),(4,5)]:box('stone',(x,y,.06),(.7,.6,.12),MAT['cobblestone'])
# Real lid hinge and a voxel iron sword, grip under the right palm.
chest=empty('Chest',(-2,-1.3,0),col='Props')
box('chest_body',(0,0,.28),(.85,.65,.54),MAT['normal'],chest,uv=(0,19,14,10,14),col='Props')
lid=empty('Chest_lid',(0,.325,.56),chest,'Props')
box('chest_lid',(0,-.325,.08),(.9,.7,.16),MAT['oak_planks'],lid,col='Props');box('latch',(0,-.69,.03),(.10,.04,.22),MAT['gold'],lid,col='Props')
# Native-profile cinematic rigs: shoulders/elbows, pelvis/knees and separate wrist.
def rig(name,slim=False):
 n={};n['root']=empty(name+'_Root');n['hips']=empty(name+'_Hips',(0,0,.72),n['root']);n['torso']=empty(name+'_Torso',parent=n['hips']);n['head']=empty(name+'_Head',(0,0,.75),n['torso'])
 skin=MAT[name.lower()]
 box(name+'_body',(0,0,.375),(.5,.25,.75),skin,n['torso'],(16,16,8,12,4),col='Characters')
 box(name+'_head',(0,0,.25),(.5,.5,.5),skin,n['head'],(0,0,8,8,8),col='Characters')
 # Hair/hat outer shell uses the original transparent second skin layer.
 box(name+'_hair',(0,0,.25),(.535,.535,.535),skin,n['head'],(32,0,8,8,8),col='Characters')
 for side,sgn in [('R',-1),('L',1)]:
  w=3 if slim else 4;ax=sgn*(.25+w/32)
  n[side+'arm']=empty(name+'_'+side+'Shoulder',(ax,0,.625),n['torso'])
  n[side+'elbow']=empty(name+'_'+side+'Elbow',(0,0,-.375),n[side+'arm'])
  n[side+'wrist']=empty(name+'_'+side+'Wrist',(0,0,-.3125),n[side+'elbow'])
  auv=(40,16,w,12,4) if side=='R' else (32,48,w,12,4)
  for key,st in [(side+'arm',0),(side+'elbow',6)]:box(name+'_'+key,(0,0,-.1875),(w/16,.25,.375),skin,n[key],auv,start=st,pixels=6,col='Characters')
  n[side+'leg']=empty(name+'_'+side+'Hip',(sgn*.125,0,0),n['hips']);n[side+'knee']=empty(name+'_'+side+'Knee',(0,0,-.375),n[side+'leg'])
  luv=(0,16,4,12,4) if side=='R' else (16,48,4,12,4)
  for key,st in [(side+'leg',0),(side+'knee',6)]:box(name+'_'+key,(0,0,-.1875),(.25,.25,.375),skin,n[key],luv,start=st,pixels=6,col='Characters')
 return n
S=rig('Steve');A=rig('Alex',True);H=rig('Herobrine')
# White eye planes respect original face UV locations. Dark lip pixels form a restrained smile.
for x in [-.125,.125]:box('HB_Eye',(x,-.252,.21875),(.125,.005,.0625),MAT['eye'],H['head'],col='Characters')
smile=box('HB_smile',(.026,-.254,.111),(.15,.006,.025),MAT['smile'],H['head'],col='Characters')
# Small explicit wound is attached to Alex's torso; the arm must pass through this location.
wound=box('Alex_wound',(0,-.128,.37),(.18,.008,.17),MAT['black'],A['torso'],col='Effects')
blood=box('Alex_blood',(0,-.134,.28),(.13,.006,.18),MAT['blood'],A['torso'],col='Effects')
sword=empty('Sword_grip',(0,0,0),S['Rwrist'],'Props')
im=MAT['iron_sword'].node_tree.nodes.get('Image Texture').image
# Pixel-perfect sword extrusion, handle pixel (3,13) is at the wrist.
for y in range(16):
 for x in range(16):
  i=(15-y)*16+x;rgba=im.pixels[i*4:i*4+4]
  if rgba[3]>.5:
   # image diagonal becomes vertical blade after a 45-degree in-plane rotation
   px=(x-3)*.053;py=(13-y)*.053
   xx=(px-py)/math.sqrt(2);zz=(px+py)/math.sqrt(2)
   m=material('sword_%d_%d'%(x,y),color=tuple(rgba));box('sword_pixel',(xx,0,zz),(.053,.065,.053),m,sword,col='Props')
# Cameras are separate shots: no camera teleport interpolated across an editorial cut.
def camera(name,lens):
 d=bpy.data.cameras.new('CAM_CH1_'+name);d.lens=lens;d.sensor_width=36;d.clip_end=110
 return link(bpy.data.objects.new(d.name,d),'Cameras')
shots=[(0,5,'Garden',35), (5,9,'Together',53), (9,12,'Sky',30), (12,16,'Behind',48), (16,19,'Contact',53), (19,22,'Steve',46), (22,26,'Invitation',65), (26,30,'Catch',42), (30,36,'Loss',53), (36,41,'Decision',53), (41,46,'Sword',46), (46,50,'Forest',35)]
cams={}
for start,end,name,lens in shots:
 cam=camera(name,lens);cams[name]=cam;sc.timeline_markers.new(name,frame=round(start*FPS)+1).camera=cam
sc.camera=cams['Garden']
# Motivated sun/sky, cool darkness and a house-side warm fill. No flat all-direction wash.
def light(name,typ,at,energy,color,size=4,target=(0,0,1)):
 d=bpy.data.lights.new('LGT_CH1_'+name,typ);d.energy=energy;d.color=color
 if typ=='AREA':d.shape='DISK';d.size=size
 ob=link(bpy.data.objects.new(d.name,d),'Lights');ob.location=at;ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler();return ob
sun=light('Sun','SUN',(-8,-3,10),2.4,(1,.77,.45));sun.data.angle=.12
fill=light('Sky','AREA',(1,-6,7),450,(.49,.68,1),8)
rim=light('Moon','AREA',(3,4,6),650,(.29,.47,1),5)
house=light('Cottage','AREA',(-4,3,3),110,(1,.44,.16),3)
# Controlled finite sky fracture mesh, visible for the event only.
fractures=[]
for i in range(7):
 ob=box('sky_fracture',(-5+i*1.1,3+i*.2,8+i*.18),(1.4,.04,.04),MAT['eye'],col='Effects');ob.rotation_euler.y=(-1)**i*.5;fractures.append(ob)
particles=[]
for i in range(18):particles.append(box('blood_pixel',(0,0,-5),(.035,.035,.035),MAT['blood'],col='Effects'))
# Helpers below pose in native Blender Z-up, forward -Y. IK is evaluated in world space.
def clamp(x):return max(0,min(1,x))
def ease(a,b,t):x=clamp((t-a)/(b-a));return x*x*(3-2*x)
def mix(a,b,k):return a+(b-a)*k
def lerp(a,b,k):return Vector(a).lerp(Vector(b),k)
def qrot(x=0,y=0,z=0):return (Matrix.Rotation(z,3,'Z')@Matrix.Rotation(x,3,'X')@Matrix.Rotation(y,3,'Y')).to_quaternion()
def rot(ob,x=0,y=0,z=0):ob.rotation_quaternion=qrot(x,y,z)
def wm(ob):
 local=Matrix.Translation(ob.location)@ob.rotation_quaternion.to_matrix().to_4x4()@Matrix.Diagonal((*ob.scale,1))
 return wm(ob.parent)@local if ob.parent else local
def update():pass
def reset(n,pos,yaw=0,hip=.745):
 for ob in n.values():ob.rotation_quaternion=Quaternion()
 n['root'].location=pos;rot(n['root'],z=yaw);n['hips'].location=(0,0,hip)
def aim(n,point):
 update();p=wm(n['torso']).inverted()@Vector(point)-Vector((0,0,1.0))
 rot(n['head'],max(-.6,min(.7,math.atan2(-p.z,math.hypot(p.x,p.y)))),0,max(-1.1,min(1.1,math.atan2(p.x,-p.y))))
def ik(n,side,arm,target,pole):
 top=n[side+('arm' if arm else 'leg')];low=n[side+('elbow' if arm else 'knee')];update()
 base=wm(top.parent)@top.location;vec=Vector(target)-base;L1=.375;L2=.3125 if arm else .375
 dist=max(.02,min(L1+L2-.001,vec.length));direc=vec.normalized();pv=Vector(pole)-base;perp=pv-direc*pv.dot(direc)
 if perp.length<.00001:perp=Vector((1,0,0)).cross(direc)
 perp.normalize();along=(L1*L1-L2*L2+dist*dist)/(2*dist);mid=direc*along+perp*math.sqrt(max(0,L1*L1-along*along))
 wtop=Vector((0,0,-1)).rotation_difference(mid.normalized());wlow=Vector((0,0,-1)).rotation_difference((direc*dist-mid).normalized())
 top.rotation_quaternion=wm(top.parent).to_quaternion().inverted()@wtop;low.rotation_quaternion=wtop.inverted()@wlow

def feet(n,points):
 for side,p in zip(['R','L'],points):ik(n,side,False,p,Vector(p)+Vector((0,-1,1)))
def stand(n):
 update();root=n['root'];feet(n,[wm(root)@Vector((x,0,.004)) for x in [-.125,.125]])
def hand(n,side,p):
 update();shoulder=wm(n[side+'arm']).translation;pole=shoulder+Vector((-.6 if side=='R' else .6,.15,-.4));ik(n,side,True,p,pole)
def stroll(n,t,a,b,p0,p1,yaw,run=False):
 u=ease(a,b,t);reset(n,lerp(p0,p1,u),yaw,.65 if run else .675)
 if t<=a or t>=b:stand(n);return
 cycle=.45 if run else .65
 root=lambda tt:lerp(p0,p1,ease(a,b,tt))
 f=[]
 for x,offset in [(-.125,0),(.125,.5)]:
  phase=(t-a)/cycle+offset;k=math.floor(phase);v=phase-k;plant=a+(k-offset)*cycle
  r=qrot(z=yaw);p=root(max(a,min(b,plant+cycle*.3))) + r@Vector((x,0,.004));nxt=root(min(b,plant+cycle*1.3))+r@Vector((x,0,.004))
  if v>.6:p=p.lerp(nxt,ease(.6,1,v));p.z+=math.sin(math.pi*clamp((v-.6)/.4))*(.16 if run else .095)*ease(a,a+.15,t)*(1-ease(b-.15,b,t))
  f.append(p)
 feet(n,f);s=math.sin((t-a)/cycle*math.tau)
 rot(n['torso'],.15 if run else .025,0,-s*.025)
 rot(n['Rarm'],-s*(.65 if run else .28),0,-.07);rot(n['Larm'],s*(.65 if run else .28),0,.07)
 rot(n['Relbow'],.5 if run else .08);rot(n['Lelbow'],.5 if run else .08)

def visibility(ob,yes):ob.hide_render=not yes;ob.hide_viewport=not yes

def pose(t,frame):
 reset(S,(-.72,-.15,0),.85);reset(A,(.75,0,0),-.5);reset(H,(1.30,.28,0),0)
 stand(S);stand(A);stand(H)
 # Small breathing lives in the chest, not in floating feet.
 rot(S['torso'],.016*math.sin(t*1.8));rot(A['torso'],.018*math.sin(t*1.7+.6))
 if t<9:
  bend=.22*(1-ease(1.2,2.8,t));rot(A['torso'],bend);rot(A['head'],.24*(1-ease(2,3.2,t)),0,-.15)
  hand(A,'R',lerp((.42,-.28,.62),(.35,-.45,1.16),ease(1,3,t)))
  hand(A,'L',(.98,-.35,1.02));aim(S,(.75,0,1.6))
  # Steve accepts a playful shoulder nudge; head leads the slight lean.
  k=ease(4.2,5,t)*(1-ease(6.2,7.1,t));hand(S,'L',lerp((-.25,-.38,.9),(.40,-.19,1.35),k))
  rot(S['head'],.04,0,-.1*math.sin(t*.7));rot(A['head'],.06,0,-.20-.22*ease(3,5,t))
  rot(S['torso'],.02,0,-.06*k)
 elif t<16:
  look=ease(9.2,10.5,t);rot(S['head'],-.5*look,0,-.25*look);rot(A['head'],-.43*look,0,.25*look)
  rot(A['Rarm'],.06,0,-.12);rot(A['Larm'],.1,0,.11)
 # Herobrine enters already composed. The shoulders barely move until the thrust.
 if t>=12:
  rot(H['head'],.025,0,-.30);rot(H['Larm'],.07,0,.08)
  prep=ease(16,16.85,t);hit=ease(16.90,17.13,t);pull=ease(26,26.65,t)
  target=lerp((.98,.15,1.10),(.96,.53,1.20),prep)
  target=target.lerp(Vector((.75,-.25,1.10)),hit);target=target.lerp(Vector((.96,.12,1.03)),pull)
  hand(H,'R',target);rot(H['torso'],.025*hit,0,-.03*prep)
  if 22<t<26:rot(H['head'],.065,0,-.28)
 # Alex's impact reaction begins only after the hand arrives.
 if 17.08<=t<27:
  k=ease(17.08,17.23,t);settle=ease(17.5,19,t)
  rot(A['root'],z=0);rot(A['torso'],-.12*k+.08*settle,0,-.025*k)
  rot(A['head'],-.35*k+.18*settle,0,-.12)
  hand(A,'R',(.48,-.17,1.18));hand(A,'L',(.99,-.18,.97))
 # Steve sees the strike, recoils first, then drives off his rear support.
 if 17.2<t<19.1:
  k=ease(17.2,17.45,t);rot(S['torso'],-.08*k);aim(S,(.75,0,1.2))
  hand(S,'L',(-.25,-.4,1.08));rot(S['Rarm'],-.23*k)
 if 19.1<=t<22:
  stroll(S,t,19.1,20.6,(-.72,-.15,0),(.22,-.73,0),.95,True)
  if t>20.6:reset(S,(.22,-.73,0),.95,.68);stand(S)
  aim(S,(1.30,.28,1.7));hand(S,'L',(.48,-.30,1.27));hand(S,'R',(.20,-.42,1.05))
 if 22<=t<27:
  stroll(S,t,26.2,27,(.22,-.73,0),(.35,-.89,0),.10) if t>=26.2 else reset(S,(.22,-.73,0),.55,.68)
  if t<26.2:stand(S)
  aim(S,(1.30,.28,1.7));hand(S,'L',(.52,-.2,1.24));hand(S,'R',(.12,-.4,1.00))
 # Coordinated catch: Steve's base lowers, Alex rotates around her hips into his arms.
 if 27<=t<41:
  fall=ease(27,29.5,t);lower=ease(29.4,31.6,t)
  reset(A,lerp((.75,0,0),(.65,-.52,.0),fall),0,mix(.72,.38,lower))
  rot(A['hips'],mix(0,1.02,fall),0,-.10*fall);rot(A['torso'],.06,0,.05*fall)
  rot(A['head'],-.75*fall+.18*lower,0,.22*fall)
  rot(A['Rarm'],-.06,0,-.16*fall);rot(A['Larm'],.12,0,.23*fall)
  rot(A['Relbow'],.12*(1-fall));rot(A['Lelbow'],.18*(1-fall))
  # Legs fold behind the pelvis, with knees contacting the ground at the end.
  rot(A['Rleg'],-.50*fall);rot(A['Lleg'],-.40*fall);rot(A['Rknee'],.55*fall);rot(A['Lknee'],.50*fall)
  reset(S,(.35,-.89,0),.10,mix(.68,.34,lower));rot(S['torso'],.12+lower*.12)
  feet(S,[(.17,-.82,.018),(.57,-1.13,.018)])
  update();back=wm(A['torso'])@Vector((.15,.08,.53));waist=wm(A['torso'])@Vector((-.17,-.02,.35))
  hand(S,'L',back);hand(S,'R',waist)
  aim(S,wm(A['head'])@Vector((0,-.2,.2)))
  if t>35.5:
   anger=ease(36.8,40.3,t);rot(S['head'],mix(.55,-.1,anger),0,-.16*anger);rot(S['torso'],mix(.24,.12,anger))
 # The held body is lowered onto the ground before Steve lets go.
 if 38.5<t<41:
  lay=ease(38.5,41,t);A['hips'].location.z=mix(.38,.25,lay);rot(A['hips'],mix(1.02,1.48,lay),0,-.10);rot(A['head'],mix(-.57,-.12,lay),0,.22)
  rot(A['Rleg'],mix(-.5,-.08,lay));rot(A['Lleg'],mix(-.4,-.06,lay));rot(A['Rknee'],mix(.55,.05,lay));rot(A['Lknee'],mix(.5,.04,lay))
  hand(S,'L',wm(A['torso'])@Vector((.15,.08,.53)))
  release=ease(38.5,39.3,t);target=lerp(wm(A['torso'])@Vector((-.17,-.02,.35)),wm(S['torso'])@Vector((-.30,-.25,.25)),release);hand(S,'R',target)
 # Once laid down, Alex remains still; only Steve acts from here on.
 if t>=41:
  reset(A,(.65,-.52,0),0,.25);rot(A['hips'],1.48,0,-.10);rot(A['torso'],.06,0,.05);rot(A['head'],-.12,0,.22)
  rot(A['Rarm'],-.06,0,-.16);rot(A['Larm'],.12,0,.23);rot(A['Rleg'],-.08);rot(A['Lleg'],-.06);rot(A['Rknee'],.05);rot(A['Lknee'],.04)
  # Cut to the chest after grief; movement between these locations is shown in the shot bridge.
  stroll(S,t,41,42.5,(.35,-.89,0),(-1.55,-1.55,0),-1.25)
  if 42.5<=t<46:
   reset(S,(-1.55,-1.55,0),-1.1,.69);stand(S);rot(S['torso'],.22*(1-ease(44.2,45.2,t)))
   hand(S,'R',lerp((-1.88,-1.34,.62),(-1.93,-1.83,1.1),ease(43.8,45.2,t)));rot(S['Rwrist'],0,-.3,0)
   hand(S,'L',(-1.72,-1.17,.78));aim(S,(-2,-1.3,.8))
  if t>=46:
   stroll(S,t,46,50,(-1.55,-1.55,0),(-.12,-5.8,0),0)
   rot(S['head'],.03);rot(S['Rarm'],.12,0,-.12);rot(S['Relbow'],.10);rot(S['Rwrist'],.4,0,0)
 # Key every evaluated control. Saved file has no dependency on frame-change handlers.
 update()
 for n in [S,A,H]:
  for ob in n.values():
   ob.keyframe_insert('location',frame=frame);ob.keyframe_insert('rotation_quaternion',frame=frame)
 for ob in [wound,blood]:visibility(ob,t>=17.1);ob.keyframe_insert('hide_render',frame=frame);ob.keyframe_insert('hide_viewport',frame=frame)
 for ob in H['root'].children_recursive:
  visibility(ob,12.6<=t<27.05);ob.keyframe_insert('hide_render',frame=frame);ob.keyframe_insert('hide_viewport',frame=frame)
 visibility(smile,22<=t<27.05);smile.keyframe_insert('hide_render',frame=frame);smile.keyframe_insert('hide_viewport',frame=frame)
 visibility(sword,t>=43.8);sword.scale=(1,1,1) if t>=43.8 else (.0001,)*3;sword.keyframe_insert('scale',frame=frame)
 lid.rotation_quaternion=qrot(-1.5*ease(42.5,43.3,t));lid.keyframe_insert('rotation_quaternion',frame=frame)
 for ob in fractures:
  visibility(ob,10.35<=t<10.8);ob.keyframe_insert('hide_render',frame=frame);ob.keyframe_insert('hide_viewport',frame=frame)
 for i,ob in enumerate(particles):
  dt=t-17.13;visible=0<=dt<.75
  visibility(ob,visible);ob.keyframe_insert('hide_render',frame=frame);ob.keyframe_insert('hide_viewport',frame=frame)
  if visible:
   v=Vector((math.sin(i*7)*.9,-.7-abs(math.cos(i))*.7,math.cos(i*5)*.7));ob.location=Vector((.73,-.22,1.1))+v*dt+Vector((0,0,-2.5))*dt*dt;ob.keyframe_insert('location',frame=frame)
 dark=ease(9.45,10.7,t)
 sun.data.energy=mix(2.4,.025,dark);sun.data.keyframe_insert('energy',frame=frame)
 bg.inputs['Strength'].default_value=mix(.40,.065,dark);bg.inputs['Strength'].keyframe_insert('default_value',frame=frame)
 fill.data.energy=mix(450,165,dark);fill.data.keyframe_insert('energy',frame=frame)
 # Shot cameras. All paths hold the same side of the action axis until the final turn.
 for a,b,name,lens in shots:
  if a<=t<b:
   k=ease(a,b,t)
   if name=='Garden':p=lerp((6,-9,5),(4.5,-7,3.5),k);to=(-.8,1,1)
   elif name=='Together':p=lerp((2.5,-4.1,2.2),(2.0,-3.6,2.0),k);to=(.05,0,1.25)
   elif name=='Sky':p=lerp((1.5,-4,1.4),(1.5,-3.8,1.6),k);to=lerp((0,0,1.4),(0,1,5),ease(9.6,11.6,t))
   elif name=='Behind':p=lerp((3.6,-4.2,2.0),(2.5,-3.8,1.8),k);to=(.65,.35,1.27)
   elif name=='Contact':p=lerp((3.2,-3.2,1.75),(2.8,-2.9,1.6),k);to=(.6,.15,1.15)
   elif name=='Steve':p=lerp((-2.5,-3.0,1.8),(-2.1,-2.8,1.55),k);to=(.15,-.1,1.15)
   elif name=='Invitation':p=lerp((2.8,-2.1,1.96),(2.6,-1.9,1.92),k);to=(1.30,.28,1.65)
   elif name=='Catch':p=lerp((3.2,-4.0,2.1),(2.7,-3.5,1.65),k);to=(.45,-.48,1.0)
   elif name=='Loss':p=lerp((2.4,-3.6,1.7),(2.1,-3.3,1.5),k);to=(.40,-.85,.90)
   elif name=='Decision':p=lerp((1.25,-2.85,1.50),(1.1,-2.65,1.45),k);to=(.20,-1.0,1.25)
   elif name=='Sword':p=lerp((-3.9,-4.7,2.0),(-3.4,-3.9,1.8),k);to=lerp((-.8,-1.2,1.0),(-1.8,-1.4,1.1),ease(41,42.7,t))
   else:
    p=lerp((2.4,-.5,2.3),(-.12,-1.8,14),k);to=lerp((-1.3,-2,1.0),(-.12,-6.47,.5),k)
   cam=cams[name];cam.location=p;cam.rotation_euler=(Vector(to)-cam.location).to_track_quat('-Z','Y').to_euler()
   if name=='Sky':cam.rotation_euler.z+=math.sin((t-10.35)*34)*.025*ease(10.35,10.43,t)*(1-ease(10.43,11.1,t))
   cam.keyframe_insert('location',frame=frame);cam.keyframe_insert('rotation_euler',frame=frame)
   break

# First save a recoverable stepped blocking version for image review.
for f in range(1,sc.frame_end+1):
 pose((f-1)/FPS,f)
 if f%120==0:
  (ROOT/'qa/cinematics/ch1_intro/build_progress.txt').write_text(str(f))
for ob in sc.objects:
 if ob.animation_data and ob.animation_data.action:
  action=ob.animation_data.action;action.name='AN_CH1_'+ob.name
  for layer in action.layers:
   for strip in layer.strips:
    for bag in strip.channelbags:
     for fc in bag.fcurves:
      for k in fc.keyframe_points:
       k.interpolation='CONSTANT' if fc.data_path in ['hide_render','hide_viewport','scale'] else 'BEZIER';k.handle_left_type=k.handle_right_type='AUTO_CLAMPED'
sc.render.use_persistent_data=True
sc['story_ru']='Грядка → небо/темнота → Херобрин/сквозной удар → приглашение → подхват → смерть Алекс → меч → лес'
sc['delivery']='1200 frames, 24fps, 50s; nearest vanilla textures; separate headless render'
sc.frame_set(1)
for area in bpy.context.screen.areas:
 if area.type=='VIEW_3D':
  area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.shading.type='MATERIAL';area.spaces.active.overlay.show_overlays=False
bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'ch1_intro.blend'))
print('CH1_READY',len(sc.objects),sc.frame_end)
