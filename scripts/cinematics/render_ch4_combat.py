"""Separate headless process: evaluate the saved Blender rig then bake its
full UV quads through the game's existing z-buffer rasterizer. This retains
exact pixel size, light convention and projection of IV's original atlases.
"""
import bpy,json,math,subprocess
from pathlib import Path
from mathutils import Vector,Matrix
R=Path('/home/daydert/MinecraftSurvivors2');out=R/'qa/ch4_combat_polish/blender';out.mkdir(parents=True,exist_ok=True)
C=Matrix(((1,0,0),(0,0,-1),(0,1,0)));data={}
assert all(im.packed_file for im in bpy.data.images if im.source=='FILE' and im.users)
assert 'MS_Walk_Probe' in bpy.data.scenes
for sc in bpy.data.scenes:
 if not sc.get('ch4_polish_owned'):continue
 bpy.context.window.scene=sc;kind=sc['motion_kind'];frames=[];length=(sc.frame_end-1)/30
 count=1 if kind=='spike' else round(length*12)+1
 for i in range(count):
  t=min(length,i/12);sc.frame_set(int(t*30)+1,subframe=t*30-int(t*30))
  root=next((o for o in sc.objects if o.name.startswith('HB_root') and o.type=='EMPTY'),None)
  offset=root.matrix_world.to_translation() if kind=='cast_step' and root else Vector((0,0,0))
  faces=[]
  for ob in sc.objects:
   if ob.type!='MESH' or not ob.get('ch4_bake'):continue
   image=next(n.image for n in ob.active_material.node_tree.nodes if n.type=='TEX_IMAGE')
   width,height=image.size;uv=ob.data.uv_layers.active
   for poly in ob.data.polygons:
    verts=[];uvs=[]
    for li in poly.loop_indices:
     p=C.inverted()@(ob.matrix_world@ob.data.vertices[ob.data.loops[li].vertex_index].co-offset)
     verts.append([p.x*16,p.y*16,-p.z*16]);u=uv.data[li].uv;uvs.append([u.x*width,(1-u.y)*height])
    u0=min(u[0] for u in uvs);v0=min(u[1] for u in uvs);u1=max(u[0] for u in uvs);v1=max(u[1] for u in uvs)
    order=[min(range(len(uvs)),key=lambda j:(uvs[j][0]-u)**2+(uvs[j][1]-v)**2) for u,v in [(u0,v0),(u1,v0),(u1,v1),(u0,v1)]]
    faces.append({'verts':[verts[j] for j in order],'texture':bpy.path.abspath(image.filepath),'uv':[u0,v0,u1-u0,v1-v0],'shade':[.86,.80,.68,.70,1,.55][poly.index%6]})
  frames.append(faces)
 data[kind]={'fps':12,'length':length,'frames':frames}
(out/'evaluated_meshes.json').write_text(json.dumps(data,separators=(',',':')))
subprocess.run(['python3',str(R/'scripts/cinematics/bake_ch4_combat_frames.py')],cwd=R,check=True)
# Genuine camera proofs after reopening, independent of the game raster bake.
for kind,frame in [('ground_smash',1),('ground_smash',34),('ground_smash',100),('cast_step',16),('spiral_raise',34)]:
 sc=bpy.data.scenes['CH4_Polish_'+kind];bpy.context.window.scene=sc;sc.frame_set(frame)
 sc.render.engine='CYCLES';sc.cycles.device='CPU';sc.cycles.samples=4;sc.cycles.use_denoising=True;sc.render.threads_mode='FIXED';sc.render.threads=4
 sc.render.filepath=str(out/(kind+'_%03d.png'%frame));bpy.ops.render.render(write_still=True,scene=sc.name)
print('CH4_COMBAT_HEADLESS_COMPLETE')
