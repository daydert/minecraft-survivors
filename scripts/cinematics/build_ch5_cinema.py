"""Run through execute_blender_code. Owns separate scenes, never clears the user's probe.
Blender controls are sampled back to Godot after evaluation, including cameras.
"""
import bpy,sys,math,json
from pathlib import Path
from mathutils import Vector,Matrix,Quaternion
ROOT=Path('/home/daydert/MinecraftSurvivors2');sys.path.insert(0,str(ROOT/'scripts/cinematics'))
import ch5_motion as M
import importlib;importlib.reload(M)
import ch5_fight_polish as P;importlib.reload(P)
C=Matrix(((1,0,0),(0,0,-1),(0,1,0)))
def b(v):return C@Vector(v)
def make_scene(name,length):
 if name in bpy.data.scenes:
  old=bpy.data.scenes[name]
  if not old.get('ch5_owned'):raise RuntimeError('Unowned scene '+name)
  for ob in list(old.objects):bpy.data.objects.remove(ob,do_unlink=True)
  bpy.data.scenes.remove(old)
 sc=bpy.data.scenes.new(name);sc['ch5_owned']=True;bpy.context.window.scene=sc
 sc.render.fps=30;sc.frame_start=1;sc.frame_end=round(length*30)+1
 sc.render.resolution_x=960;sc.render.resolution_y=540;sc.render.resolution_percentage=100
 sc.render.engine='CYCLES';sc.cycles.samples=12;sc.cycles.use_denoising=True
 sc.world=bpy.data.worlds.new(name+'_World');sc.world.use_nodes=True
 sc.world.node_tree.nodes['Background'].inputs[0].default_value=(.025,.032,.05,1);sc.world.node_tree.nodes['Background'].inputs[1].default_value=.35
 sc.view_settings.view_transform='Standard'
 return sc

def empty(sc,name,p,parent=None):
 ob=bpy.data.objects.new(name,None);sc.collection.objects.link(ob);ob.parent=parent;ob.location=b(p);ob.rotation_mode='QUATERNION';return ob

def texmat(name,texture=None,color=(.25,.25,.25,1)):
 existing=bpy.data.materials.get('CH5_'+name)
 if existing:return existing
 m=bpy.data.materials.new('CH5_'+name);m.use_nodes=True;bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=color;bs.inputs['Roughness'].default_value=.9
 if texture:
  im=bpy.data.images.load(str(ROOT/'assets/sprites'/texture),check_existing=True);im.pack()
  node=m.node_tree.nodes.new('ShaderNodeTexImage');node.image=im;node.interpolation='Closest';m.node_tree.links.new(node.outputs['Color'],bs.inputs['Base Color'])
 return m

def box(sc,name,at,size,material,parent=None,uv=None,source_h=None,start=0):
 x,y,z=[v/2 for v in size]
 pts=[(-x,y,z),(x,y,z),(x,-y,z),(-x,-y,z),(-x,y,-z),(x,y,-z),(x,-y,-z),(-x,-y,-z)]
 fs=[(0,1,2,3),(5,4,7,6),(4,0,3,7),(1,5,6,2),(4,5,1,0),(3,2,6,7)]
 me=bpy.data.meshes.new(name);me.from_pydata([b(p) for p in pts],[],fs);me.materials.append(material)
 layer=me.uv_layers.new()
 if uv:
  u,v=uv;w,h,d=size[0]*16,source_h or size[1]*16,size[2]*16;count=size[1]*16
  rects=[(u+d,v+d+start,w,count),(u+2*d+w,v+d+start,w,count),(u,v+d+start,d,count),(u+d+w,v+d+start,d,count),(u+d,v,w,d),(u+d+w,v,w,d)]
  for f,(uu,vv,ww,hh) in zip(me.polygons,rects):
   for li,(xx,yy) in zip(f.loop_indices,[(uu,vv),(uu+ww,vv),(uu+ww,vv+hh),(uu,vv+hh)]):layer.data[li].uv=(xx/64,1-yy/64)
 else:
  for f in me.polygons:
   for li,uvv in zip(f.loop_indices,[(0,0),(1,0),(1,1),(0,1)]):layer.data[li].uv=uvv
 ob=bpy.data.objects.new(name,me);sc.collection.objects.link(ob);ob.parent=parent;ob.location=b(at);return ob

def rig(sc,who):
 skin=texmat(who,'ch5_skin_'+who+'.png');nodes={}
 for k in M.PARTS:nodes[k]=empty(sc,who+'_'+k,M.REST.get(k,(0,0,0)),nodes.get(M.PARENT.get(k)))
 def part(k,at,sz,uv,start=0,h=None):return box(sc,who+'_skin_'+k,at,sz,skin,nodes[k],uv,h,start)
 part('torso',(0,.375,0),(.5,.75,.25),(16,16));part('head',(0,.25,0),(.5,.5,.5),(0,0))
 for side,x in [('r',-.0625),('l',.0625)]:
  uv=(40,16) if side=='r' else (32,48)
  part(side+'a',(x,-.0625,0),(.25,.375,.25),uv,h=12)
  part(side+'e',(x,-.1875,0),(.25,.375,.25),uv,6,12)
  uv=(0,16) if side=='r' else (16,48)
  part(side+'l',(0,-.1875,0),(.25,.375,.25),uv,h=12)
  part(side+'k',(0,-.1875,0),(.25,.375,.25),uv,6,12)
 nodes['root']['intent']='Steve: deliberate decision. Notch: control, bargaining, panic, silence.'
 return nodes

def key_actor(nodes,pose,frame):
 for k,d in pose.items():
  ob=nodes[k]
  if 'p' in d:ob.location=b(d['p'])
  q=d.get('q');rot=Quaternion((q[3],*q[:3])).to_matrix() if q else M.rotation(d['r'])
  ob.rotation_quaternion=(C@rot@C.inverted()).to_quaternion()
  ob.keyframe_insert('location',frame=frame);ob.keyframe_insert('rotation_quaternion',frame=frame)

def setup_cam(sc):
 data=bpy.data.cameras.new(sc.name+'_Camera');data.sensor_fit='VERTICAL';data.sensor_height=24;data.clip_start=.03;data.clip_end=150
 ob=bpy.data.objects.new(data.name,data);sc.collection.objects.link(ob);sc.camera=ob
 target=empty(sc,'Target_'+sc.name,(0,1,0));return ob,target

def lights(sc):
 for name,p,color,power,size in [('Key',(-2.8,3.8,3),(1,.84,.66),230,3),('Rim',(2,2.7,-2),(.35,.65,1),260,2),('Face',(.5,2.5,4.5),(.8,.9,1),80,3)]:
  d=bpy.data.lights.new(sc.name+name,'AREA');d.energy=power;d.color=color;d.shape='DISK';d.size=size
  o=bpy.data.objects.new(d.name,d);sc.collection.objects.link(o);o.location=b(p);o.rotation_euler=(b((0,1,0))-o.location).to_track_quat('-Z','Y').to_euler()

def sword(sc,parent):
 # A voxel for every opaque texel of the real item, matching the runtime holder.
 im=bpy.data.images.load(str(ROOT/'assets/sprites/ch5q_item_iron_sword.png'),check_existing=True);im.pack();pixels=list(im.pixels)
 R=M.rotation((0,math.pi/2,math.radians(-135)))
 for y in range(16):
  for x in range(16):
   c=pixels[((15-y)*16+x)*4:((15-y)*16+x)*4+4]
   if c[3]<.5:continue
   at=R@Vector(((x+.5-8)/16,(8-y-.5)/16,0))*.85+Vector((0,-.42*.85,0))
   o=box(sc,'IronPixel',at,(.85/16,.85/16,.085*.85),texmat('iron'+str(tuple(round(v,3) for v in c)),color=tuple(c)),parent)
   o.rotation_mode='QUATERNION';o.rotation_quaternion=(C@R@C.inverted()).to_quaternion()

def can_model(sc,parent):
 # Necked, rolled-rim tin. A single original UV label wraps the body;
 # metal caps, recessed lid, opening and pull ring remain distinct geometry.
 label=texmat('BeerLabel_v2');bs=label.node_tree.nodes.get('Principled BSDF')
 if not any(n.type=='TEX_IMAGE' for n in label.node_tree.nodes):
  im=bpy.data.images.load(str(ROOT/'assets/art_source/ch5_finale/beer_label.png'),check_existing=True);im.pack()
  node=label.node_tree.nodes.new('ShaderNodeTexImage');node.image=im;node.interpolation='Closest';label.node_tree.links.new(node.outputs['Color'],bs.inputs['Base Color']);bs.inputs['Roughness'].default_value=.62
 metal=texmat('BeerTin_v2',color=(.62,.67,.69,1));metal.node_tree.nodes['Principled BSDF'].inputs['Metallic'].default_value=.65;metal.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.32
 profile=[(-.18,.077),(-.172,.087),(-.15,.092),(.138,.092),(.163,.078),(.174,.078)]
 verts=[b((math.sin(k*math.tau/24)*radius,y,math.cos(k*math.tau/24)*radius)) for y,radius in profile for k in range(25)]
 faces=[]
 for j in range(len(profile)-1):
  for k in range(24):faces.append((j*25+k,j*25+k+1,(j+1)*25+k+1,(j+1)*25+k))
 me=bpy.data.meshes.new('Can_UV');me.from_pydata(verts,[],faces);me.materials.append(label);me.materials.append(metal);uv=me.uv_layers.new()
 for poly in me.polygons:
  j=poly.index//24;k=poly.index%24;poly.material_index=0 if j in [1,2,3] else 1
  for li,uvv in zip(poly.loop_indices,[(k/24,(profile[j][0]+.18)/.36),((k+1)/24,(profile[j][0]+.18)/.36),((k+1)/24,(profile[j+1][0]+.18)/.36),(k/24,(profile[j+1][0]+.18)/.36)]):uv.data[li].uv=uvv
 ob=bpy.data.objects.new('Beer_can_body',me);sc.collection.objects.link(ob);ob.parent=parent
 for name,y,radius,height,mat in [('Lid',.169,.075,.009,metal),('Base',-.174,.074,.012,metal),('Opening',.175,.022,.003,texmat('BeerOpening',color=(.025,.027,.025,1)))]:
  vs=[b((math.sin(k*math.tau/24)*radius,yy+y,math.cos(k*math.tau/24)*radius+(.036 if name=='Opening' else 0))) for yy in [-height/2,height/2] for k in range(24)]
  fs=[tuple(range(23,-1,-1)),tuple(range(24,48))]+[(k,(k+1)%24,(k+1)%24+24,k+24) for k in range(24)]
  mesh=bpy.data.meshes.new(name);mesh.from_pydata(vs,[],fs);mesh.materials.append(mat);o=bpy.data.objects.new('Beer_'+name,mesh);sc.collection.objects.link(o);o.parent=parent
 for y in [-.176,.174]:
  bpy.ops.mesh.primitive_torus_add(major_radius=.078,minor_radius=.005,major_segments=24,minor_segments=6)
  o=bpy.context.object;o.name='Rolled_rim';o.parent=parent;o.location=b((0,y,0));o.data.materials.append(metal)
 bpy.ops.mesh.primitive_torus_add(major_radius=.019,minor_radius=.004,major_segments=12,minor_segments=4)
 o=bpy.context.object;o.name='Pull_ring';o.parent=parent;o.location=b((0,.181,-.009));o.scale=(.7,1.3,.6);o.data.materials.append(metal)

# Export only the owned prop, before authoring the narrative scenes. The same
# mesh/UVs/materials are inspected in Blender and imported by Compatibility.
asset=make_scene('CH5_beer_asset',0)
canroot=empty(asset,'Beer',(0,0,0));can_model(asset,canroot)
bpy.ops.object.select_all(action='DESELECT')
for ob in asset.objects:ob.select_set(True)
bpy.context.view_layer.objects.active=canroot
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/ch5_beer_can.glb'),use_selection=True,use_active_scene=True,export_animations=False,export_yup=True)

def ending_room(sc,stone,wood):
 box(sc,'Terminal_wall',(0,2.2,-3.2),(5.2,3.2,.4),stone)
 box(sc,'Terminal_screen',(0,2.3,-2.98),(4.4,2.4,.05),texmat('terminal_green',color=(.02,.13,.06,1)))
 box(sc,'Can_table',(.65,.86,-2.15),(.9,.12,.9),wood)
 for x in [.31,.99]:
  for z in [-2.49,-1.81]:box(sc,'Can_table_leg',(x,.4,z),(.1,.8,.1),wood)
 iron=texmat('door','ch5q_iron_block.png');hinge=empty(sc,'Bad_door_hinge',(4,0,-4.5))
 box(sc,'Bad_door_leaf',(-.5,1,0),(1,2,.12),iron,hinge)
 box(sc,'Bad_door_handle',(-.8,1.15,.12),(.1,.08,.12),texmat('handle_v2',color=(.3,.3,.3,1)),hinge)
 for name,at,sz in [('Back',(-1.5,2.5,-4.7),(9,5,.3)),('Right',(5,2.5,-4.7),(2,5,.3)),('Lintel',(3.5,3.5,-4.7),(1,3,.3))]:box(sc,'Bad_'+name+'_wall',at,sz,stone)
 can=empty(sc,'Beer_can',P.CAN_AT);can_model(sc,can)
 return hinge,can

tracks={};scenes=[]
for kind,length in [('bad_end',P.BAD_LENGTH),('bad_qte',P.BAD_LENGTH+P.BRIDGE_LENGTH),('finisher',3.6),('chair',44),('door',5),('arrival',5),('erase_throw',3.6),('wire',2.8)]+[(n,2.4) for n in ['qte_hit','qte_block','qte_dodge','qte_miss']]+[('portal_'+str(i),4.4) for i in range(5)]+[(n,2.4) for n in ['qte_jab','qte_cross','qte_hook','qte_uppercut','qte_slip','qte_parry','qte_guard','qte_roll']]:
 sc=make_scene('CH5_'+kind,length);scenes.append(sc);ties={};rigs={who:rig(sc,who) for who in (['steve'] if kind in ['door','arrival'] else ['steve','notch'])}
 stone=texmat('floor','ch5q_polished_deepslate.png');wood=texmat('chair','ch5q_dark_oak_planks.png')
 box(sc,'Stage',(0,-.12,0),(14,.24,12),stone)
 if kind=='chair':
  for x in [-.35,.35]:
   for z in [-.35,.35]:box(sc,'Chair_leg',(x,.25,z),(.12,.5,.12),wood)
  box(sc,'Chair_seat',(0,.55,0),(.9,.1,.9),wood);box(sc,'Chair_back',(0,1.15,-.42),(.9,1.1,.1),wood)
  box(sc,'Backwall',(0,2,-4),(14,5,.2),stone);sword(sc,rigs['steve']['grip'])
  binding=texmat('binding',color=(.5,.46,.38,1));cord=texmat('cord',color=(.60,.43,.24,1))
  for y in [.9,1.17]:
   for turn in [-.045,.045]:
    bpy.ops.mesh.primitive_torus_add(major_radius=.3875,minor_radius=.0225,major_segments=24,minor_segments=6,location=b((0,y+turn,-.04)))
    ob=bpy.context.object;ob.name='Chest_restraint';ob.scale=(1,.87,.6);ob.data.materials.append(cord)
  for side,sign in [('r',-1),('l',1)]:
   box(sc,'Armrest',(sign*.48,.71,0),(.12,.08,.65),wood)
   box(sc,'Cuff',(sign*.0625,-.32,0),(.31,.07,.31),binding,rigs['notch'][side+'e'])
   ties[side]=box(sc,'Tie',(0,0,0),(1,.025,.025),cord)

 if kind=='door':
  iron=texmat('door','ch5q_iron_block.png')
  for x in [-4.25,5.25]:box(sc,'Door_wall',(x,2.5,-6.2),(8.5,7,.4),stone)
  box(sc,'Door_lintel',(.5,4.75,-6.2),(1.3,5.5,.4),stone)
  box(sc,'Door_sill',(.5,-.2,-6), (1.3,.4,.5),stone)
  box(sc,'Door_floor',(.5,-.1,-3),(12,.2,8),stone)
  hinge=empty(sc,'Door_hinge',(1,0,-6))
  box(sc,'Door_leaf',(-.5,1,0),(1,2,.12),iron,hinge)
  box(sc,'Door_handle',(-.8,1.15,.11),(.12,.08,.14),iron,hinge)
  for f in range(1,sc.frame_end+1):
   t=(f-1)/30;hinge.rotation_quaternion=(C@M.rotation((0,-M.clamp((t-3.3)/.9)*1.7,0))@C.inverted()).to_quaternion();hinge.keyframe_insert('rotation_quaternion',frame=f)
 if kind=='finisher':
  box(sc,'KO_tabletop',(.75,.90,1.45),(1.1,.12,1.05),wood)
  for x in [.32,1.18]:
   for z in [1.05,1.85]:box(sc,'KO_table_leg',(x,.42,z),(.10,.84,.10),wood)
 if kind.startswith('qte_') or kind in ['bad_end','bad_qte','finisher']:
  hinge,can=ending_room(sc,stone,wood)
 if kind in ['bad_end','bad_qte']:
  sword(sc,rigs['steve']['grip'])
  for f in range(1,sc.frame_end+1):
   t=(f-1)/30-(P.BRIDGE_LENGTH if kind=='bad_qte' else 0)
   hinge.rotation_quaternion=(C@M.rotation((0,-M.ease(13.45,14.05,t)*1.65,0))@C.inverted()).to_quaternion();hinge.keyframe_insert('rotation_quaternion',frame=f)
 if kind=='arrival':
  import contextlib,io
  with contextlib.redirect_stdout(io.StringIO()):bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/models/ch5_mill_yard.glb'))
 if kind in ['bad_end','bad_qte']:
  # The Blender proof mirrors runtime visibility. Pixel erosion itself is
  # evaluated by the Compatibility material in the game.
  offset=P.BRIDGE_LENGTH if kind=='bad_qte' else 0
  for ob in sc.objects:
   if not (ob.name.startswith('steve_skin_') or ob.name.startswith('IronPixel')):continue
   events=[(1,kind=='bad_qte' and ob.name.startswith('IronPixel')),(round((offset+2.36)*30)+1,True)]
   if kind=='bad_qte' and ob.name.startswith('IronPixel'):events.insert(1,(46,False))
   for frame,hidden in events:
    ob.hide_render=hidden;ob.hide_viewport=hidden
    ob.keyframe_insert('hide_render',frame=frame);ob.keyframe_insert('hide_viewport',frame=frame)
 cam,target=setup_cam(sc);lights(sc)
 sc['motion_kind']=kind;sc['notes']='Pure simulation-clock playback; sample Blender evaluated local transforms, not screen-space PNGs.'
 for frame in range(1,sc.frame_end+1):
  t=(frame-1)/30
  pose=getattr(P,kind,getattr(M,kind,None))(t) if not kind.startswith('portal_') else P.portal(int(kind[-1]),t)
  for who,nodes in rigs.items():key_actor(nodes,pose[who],frame)
  if kind in ['bad_end','bad_qte']:
   local=t-(P.BRIDGE_LENGTH if kind=='bad_qte' else 0)
   mat=P.can_matrix(pose,local)
   can.location=C@mat.to_translation();can.rotation_quaternion=(C@mat.to_3x3()@C.inverted()).to_quaternion();can.keyframe_insert('location',frame=frame);can.keyframe_insert('rotation_quaternion',frame=frame)
  for side,ob in ties.items():
   sign=-1 if side=='r' else 1;anchor=Vector((sign*.48,.69,0));end=M.matrices(pose['notch'])[side+'e']@Vector((sign*.0625,-.32,0));direction=end-anchor
   rot=Vector((1,0,0)).rotation_difference(direction.normalized()).to_matrix()
   ob.location=b((anchor+end)*.5);ob.rotation_mode='QUATERNION';ob.rotation_quaternion=(C@rot@C.inverted()).to_quaternion();ob.scale=(direction.length,1,1)
   for path in ['location','rotation_quaternion','scale']:ob.keyframe_insert(path,frame=frame)
  c=pose['cam'];cam.location=b(c['p']);target.location=b(c['to']);cam.rotation_euler=(target.location-cam.location).to_track_quat('-Z','Y').to_euler();cam['fov']=c['fov']
  cam.data.lens=12/math.tan(math.radians(c['fov'])/2)
  for path in ['location','rotation_euler','["fov"]']:cam.keyframe_insert(path,frame=frame)
  cam.data.keyframe_insert('lens',frame=frame);target.keyframe_insert('location',frame=frame)
 # Preserve exact samples between keyframes; no automatic Bezier overshoot at contact.
 for ob in sc.objects:
  if ob.animation_data and ob.animation_data.action:
   for layer in ob.animation_data.action.layers:
    for strip in layer.strips:
     for bag in strip.channelbags:
      for curve in bag.fcurves:
       for key in curve.keyframe_points:key.interpolation='LINEAR'
 frames=[]
 for frame in range(1,sc.frame_end+1):
  sc.frame_set(frame);entry={}
  for who,nodes in rigs.items():
   entry[who]={}
   for k,ob in nodes.items():
    mat=ob.matrix_basis;loc=C.inverted()@mat.to_translation();rot=(C.inverted()@mat.to_3x3()@C).to_quaternion()
    entry[who][k]=[round(v,6) for v in (*loc,rot.x,rot.y,rot.z,rot.w)]
  entry['cam']=[*[round(v,6) for v in C.inverted()@cam.location],*[round(v,6) for v in C.inverted()@target.location],round(cam['fov'],5)]
  frames.append(entry)
 tracks[kind]={'fps':30,'length':length,'frames':frames}
 sc.frame_set(1)
(ROOT/'data/chapter_five_cinema.json').write_text(json.dumps({'version':1,'source':'assets/art_source/ch5_finale/ch5_cinema.blend','tracks':tracks},separators=(',',':')))
bpy.context.window.scene=bpy.data.scenes['CH5_chair'];bpy.context.scene.frame_set(991)
for area in bpy.context.screen.areas:
 if area.type=='VIEW_3D':area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.shading.type='MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/art_source/ch5_finale/ch5_cinema.blend'))
print('CH5_AUTHORED',[(s.name,s.frame_end) for s in scenes])
