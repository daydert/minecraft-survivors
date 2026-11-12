"""Owned set polish and static mesh batching. Execute with Blender MCP."""
import bpy, math
from pathlib import Path
ROOT=Path('/home/daydert/MinecraftSurvivors2');sc=bpy.data.scenes['CH1_Garden_Prologue'];bpy.context.window.scene=sc
for ob in list(sc.objects):
 if any(ob.name.startswith('CH1_'+p) for p in ['Held_wheat','Alex_lid','Alex_lash','HB_departure','Backdrop']):bpy.data.objects.remove(ob,do_unlink=True)
for i,ob in enumerate(o for o in sc.objects if o.name.startswith('CH1_sky_fracture')):ob.location=(-3+i,2+i*.12,4.8+i*.12)
# Replace only the derived Herobrine image with original Steve and true white eye texels.
from mathutils import Vector
im=bpy.data.images.load(str(ROOT/'assets/art_source/ch1_intro/steve.png'),check_existing=True)
pix=list(im.pixels)
for x in [9,10,13,14]:
 for y in [12]:
  i=((63-y)*64+x)*4;pix[i:i+4]=[1,1,1,1]
hb=bpy.data.images.new('CH1_Herobrine_Corrected',width=64,height=64,alpha=True);hb.pixels=pix
hb.filepath_raw=str(ROOT/'assets/art_source/ch1_intro/herobrine.png');hb.file_format='PNG';hb.save();hb.pack()
body=sc.objects['CH1_Herobrine_body'];skin=body.data.materials[0]
for node in skin.node_tree.nodes:
 if node.type=='TEX_IMAGE':node.image=hb
# Use existing builder helpers for small native texture props, no external resources.
source=(ROOT/'scripts/cinematics/build_ch1_intro.py').read_text()
COL={n:bpy.data.collections.get('CH1_'+n) for n in ['Environment','Characters','Props','Effects']}
# If names were suffixed by Blender, take the collection actually linked to the owned scene.
for n in COL:COL[n]=next(c for c in sc.collection.children if c.name.startswith('CH1_'+n))
exec(source[source.index('def link('):source.index('MAT={n:')])
exec(source[source.index('def box('):source.index('# Ground tiles')])
M={n:next(m for m in bpy.data.materials if m.name.startswith('CH1_'+n)) for n in ['wheat_stage7']}
wr=sc.objects['CH1_Alex_RWrist'];stalks=[o for o in sc.objects if o.name.startswith('CH1_harvest_stalk')]
for angle in [0,math.pi/2]:
 ob=plane('Held_wheat',(0,-.04,-.05),(.25,.4),M['wheat_stage7'],(math.pi/2,0,angle),wr,'Props')
 for f,hidden in [(1,True),(49,False),(216,True)]:
  ob.hide_render=hidden;ob.hide_viewport=hidden;ob.keyframe_insert('hide_render',frame=f);ob.keyframe_insert('hide_viewport',frame=f)
for ob in stalks:
 for f,hidden in [(1,False),(49,True)]:
  ob.hide_render=hidden;ob.hide_viewport=hidden;ob.keyframe_insert('hide_render',frame=f);ob.keyframe_insert('hide_viewport',frame=f)
# Closed eyelids clarify death without changing the vanilla skin's geometry or UV.
lidmat=material('Alex_eyelids',color=(.73,.55,.38,1));line=material('Alex_lash',color=(.12,.065,.025,1))
for x in [-.125,.125]:
 for name,z,size,mat in [('lid',.21875,(.13,.005,.064),lidmat),('lash',.21875,(.13,.008,.013),line)]:
  ob=box('Alex_'+name,(x,-.254,z),size,mat,sc.objects['CH1_Alex_Head'],col='Effects')
  for f,hidden in [(1,True),(749,False)]:
   ob.hide_render=hidden;ob.hide_viewport=hidden;ob.keyframe_insert('hide_render',frame=f);ob.keyframe_insert('hide_viewport',frame=f)
# His departure is a brief finite breakup into dark pixel fragments.
mat=material('HB_vanish',color=(.018,.024,.035,1))
for i in range(30):
 x=1.3+math.sin(i*7)*.35;y=.28+math.cos(i*5)*.15;z=.15+(i%10)*.18
 ob=box('HB_departure',(x,y,z),(.10,.10,.10),mat,col='Effects')
 for f,p,scale in [(1,(x,y,z),.0001),(641,(x,y,z),.0001),(650,(x,y,z),1),(664,(x+math.sin(i)*.75,y+.5,z+.6),.0001)]:
  ob.location=p;ob.scale=(scale,)*3;ob.keyframe_insert('location',frame=f);ob.keyframe_insert('scale',frame=f)
# Layered woods behind the fence give the close-ups depth and preserve a clear acting area.
wood=next(m for m in bpy.data.materials if m.name.startswith('CH1_oak_log'))
leaf=next(m for m in bpy.data.materials if m.name.startswith('CH1_oak_leaves'))
for i,(x,y,h) in enumerate([(-1,7.4,4.8),(2,8.2,5.6),(4.5,6.8,5.0),(7,7.8,6.0),(-3,10,6.1)]):
 box('Backdrop_trunk',(x,y,h/2),(.6,.6,h),wood)
 for j in range(3):box('Backdrop_crown',(x+math.sin(i+j)*.3,y,h-.5+j*.55),(3.3-j*.6,3.3-j*.55,1.15),leaf)
# Batch only unanimated scenery. Animated harvest stalks remain separately addressable.
groups={}
for ob in list(COL['Environment'].objects):
 if ob.type=='MESH' and not ob.animation_data and ob.data.materials:groups.setdefault(ob.data.materials[0],[]).append(ob)
for mat,objects in groups.items():
 if len(objects)<2:continue
 bpy.ops.object.select_all(action='DESELECT')
 for ob in objects:ob.select_set(True)
 bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();objects[0].name='CH1_Static_'+mat.name
bpy.ops.object.select_all(action='DESELECT')
sc.render.engine='BLENDER_EEVEE';sc.eevee.taa_render_samples=24
# Scene lit previews use actual sun/sky rather than studio HDRI.
sc.frame_set(553)
for area in bpy.context.screen.areas:
 if area.type=='VIEW_3D':
  area.spaces.active.shading.use_scene_lights=True;area.spaces.active.shading.use_scene_world=True
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/art_source/ch1_intro/ch1_intro.blend'))
import gpu
print('GPU',gpu.platform.renderer_get(),gpu.platform.vendor_get());print('CH1_SET_FINISHED',len(sc.objects))
