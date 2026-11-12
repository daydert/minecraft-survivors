"""Run via Blender MCP. Owns CH4_Polish scenes, preserves the user's scenes."""
import bpy,sys,math,importlib
from pathlib import Path
from mathutils import Matrix,Vector,Quaternion
ROOT=Path('/home/daydert/MinecraftSurvivors2');sys.path.insert(0,str(ROOT/'scripts/cinematics'))
import ch5_motion as M
import ch4_combat_motion as P;importlib.reload(P)
C=Matrix(((1,0,0),(0,0,-1),(0,1,0)))
def b(v):return C@Vector(v)
def scene(name,length):
 if name in bpy.data.scenes:
  old=bpy.data.scenes[name]
  if not old.get('ch4_polish_owned'):raise RuntimeError('Unowned scene')
  for ob in list(old.objects):bpy.data.objects.remove(ob,do_unlink=True)
  bpy.data.scenes.remove(old)
 sc=bpy.data.scenes.new(name);sc['ch4_polish_owned']=True;bpy.context.window.scene=sc
 sc.render.fps=30;sc.frame_start=1;sc.frame_end=round(length*30)+1
 sc.render.resolution_x=640;sc.render.resolution_y=360;sc.render.resolution_percentage=100
 sc.world=bpy.data.worlds.new(name+'_World');sc.world.use_nodes=True;sc.world.node_tree.nodes['Background'].inputs[0].default_value=(.08,.07,.085,1)
 sc.render.engine='CYCLES';sc.cycles.samples=8;sc.view_settings.view_transform='Standard'
 return sc

def mat(name,path):
 m=bpy.data.materials.get('CH4P_'+name)
 if m:return m
 m=bpy.data.materials.new('CH4P_'+name);m.use_nodes=True
 im=bpy.data.images.load(str(ROOT/path),check_existing=True);im.pack()
 tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=im;tex.interpolation='Closest'
 bs=m.node_tree.nodes.get('Principled BSDF');m.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color']);m.node_tree.links.new(tex.outputs['Alpha'],bs.inputs['Alpha']);bs.inputs['Roughness'].default_value=.9
 return m
skin=mat('Herobrine','assets/art_source/ch4_combat/hb_skin.png');stone=mat('SpikeStone','assets/art_source/ch4_combat/stone.png')
def empty(sc,name,p,parent=None):
 ob=bpy.data.objects.new(name,None);sc.collection.objects.link(ob);ob.parent=parent;ob.location=b(p);ob.rotation_mode='QUATERNION';return ob

def box(sc,name,at,size,material,parent=None,uv=None,start=0,inflate=0):
 x,y,z=[v/2+inflate for v in size]
 verts=[(-x,y,z),(x,y,z),(x,-y,z),(-x,-y,z),(-x,y,-z),(x,y,-z),(x,-y,-z),(-x,-y,-z)]
 fs=[(0,1,2,3),(5,4,7,6),(4,0,3,7),(1,5,6,2),(4,5,1,0),(3,2,6,7)]
 me=bpy.data.meshes.new(name);me.from_pydata([b(v) for v in verts],[],fs);me.materials.append(material);layer=me.uv_layers.new()
 rects=[(0,0,16,16)]*6;tw=16
 if uv:
  tw=64;u,v=uv;w=size[0]*16;h=12 if name.endswith(('ra','re','la','le','rl','rk','ll','lk')) else size[1]*16;d=size[2]*16;cnt=size[1]*16
  rects=[(u+d,v+d+start,w,cnt),(u+2*d+w,v+d+start,w,cnt),(u,v+d+start,d,cnt),(u+d+w,v+d+start,d,cnt),(u+d,v,w,d),(u+d+w,v,w,d)]
 for f,(u,v,w,h) in zip(me.polygons,rects):
  for li,(xx,yy) in zip(f.loop_indices,[(u,v),(u+w,v),(u+w,v+h),(u,v+h)]):layer.data[li].uv=(xx/tw,1-yy/tw)
 ob=bpy.data.objects.new(name,me);sc.collection.objects.link(ob);ob.parent=parent;ob.location=b(at);ob['ch4_bake']=True;return ob

def rig(sc):
 nodes={}
 for k in M.PARTS:nodes[k]=empty(sc,'HB_'+k,M.REST.get(k,(0,0,0)),nodes.get(M.PARENT.get(k)))
 for shell in range(2):
  uv=(16,16) if shell==0 else (16,32);box(sc,'HB_skin_torso',(0,.375,0),(.5,.75,.25),skin,nodes['torso'],uv,inflate=0 if shell==0 else .015625)
  uv=(0,0) if shell==0 else (32,0);box(sc,'HB_skin_head',(0,.25,0),(.5,.5,.5),skin,nodes['head'],uv,inflate=0 if shell==0 else .03125)
 for key,at,uv in [('ra',(-.0625,-.0625,0),(40,16)),('re',(-.0625,-.1875,0),(40,16)),('la',(.0625,-.0625,0),(32,48)),('le',(.0625,-.1875,0),(32,48)),('rl',(0,-.1875,0),(0,16)),('rk',(0,-.1875,0),(0,16)),('ll',(0,-.1875,0),(16,48)),('lk',(0,-.1875,0),(16,48))]:
  start=6 if key in ['re','le','rk','lk'] else 0
  box(sc,'HB_skin_'+key,at,(.25,.375,.25),skin,nodes[key],uv,start)
 return nodes

def key(nodes,pose,frame):
 for name,d in pose.items():
  ob=nodes[name];ob.location=b(d.get('p',M.REST.get(name,(0,0,0))))
  q=d.get('q');R=Quaternion((q[3],*q[:3])).to_matrix() if q else M.rotation(d['r'])
  ob.rotation_quaternion=(C@R@C.inverted()).to_quaternion();ob.keyframe_insert('location',frame=frame);ob.keyframe_insert('rotation_quaternion',frame=frame)

def stage(sc):
 floor=box(sc,'Proof_floor',(0,-.07,0),(7,.14,6),stone);floor['ch4_bake']=False
 for name,power,p in [('Key',250,(-3,4,4)),('Rim',220,(3,3,-2))]:
  data=bpy.data.lights.new(name,'AREA');data.energy=power;data.size=4
  ob=bpy.data.objects.new(name,data);sc.collection.objects.link(ob);ob.location=b(p);ob.rotation_euler=(b((0,1,0))-ob.location).to_track_quat('-Z','Y').to_euler()
 data=bpy.data.cameras.new('Proof_camera');data.type='ORTHO';data.ortho_scale=4.8
 cam=bpy.data.objects.new('Proof_camera',data);sc.collection.objects.link(cam);cam.location=b((3,2.2,4.5));cam.rotation_euler=(b((0,.9,.2))-cam.location).to_track_quat('-Z','Y').to_euler();sc.camera=cam

for kind,(length,fn) in P.TRACKS.items():
 sc=scene('CH4_Polish_'+kind,length);sc['motion_kind']=kind;nodes=rig(sc);stage(sc)
 for frame in range(1,sc.frame_end+1):key(nodes,fn((frame-1)/30),frame)
 sc.frame_set(1)
sc=scene('CH4_Polish_spike',0);sc['motion_kind']='spike'
# Tapered, faceted stone shards with actual UVs and silhouette, not a flat triangle.
for name,at,size,rot in [('Core',(0,.65,0),(.28,1.3,.25),0),('Left',(-.18,.31,.02),(.20,.62,.20),-.22),('Right',(.15,.4,-.04),(.16,.8,.17),.18)]:
 ob=box(sc,'Spike_'+name,at,size,stone);ob.rotation_euler[1]=rot
 # Taper each shard's upper vertices into a narrow chisel.
 for v in ob.data.vertices:
  if v.co.z>0:v.co.x*=.22;v.co.y*=.22
stage(sc)
bpy.context.window.scene=bpy.data.scenes['CH4_Polish_ground_smash'];bpy.context.scene.frame_set(34)
for area in bpy.context.screen.areas:
 if area.type=='VIEW_3D':area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.shading.type='MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/art_source/ch4_combat/ch4_combat.blend'))
print('CH4_COMBAT_READY',[(s.name,s.frame_end) for s in bpy.data.scenes if s.get('ch4_polish_owned')])
