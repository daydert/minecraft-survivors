"""Final native-set detail and independent source save, executed through MCP."""
import bpy,math,json
from pathlib import Path
ROOT=Path('/home/daydert/MinecraftSurvivors2');SRC=ROOT/'assets/art_source/ch1_intro';sc=bpy.data.scenes['CH1_Garden_Prologue'];bpy.context.window.scene=sc
source=(ROOT/'scripts/cinematics/build_ch1_intro.py').read_text()
COL={n:next(c for c in sc.collection.children if c.name.startswith('CH1_'+n)) for n in ['Environment','Characters','Props','Effects']}
exec(source[source.index('def link('):source.index('MAT={n:')])
exec(source[source.index('def box('):source.index('# Ground tiles')])
def mat(prefix):return next(o.data.materials[0] for o in sc.objects if o.type=='MESH' and o.data.materials and o.data.materials[0].name.startswith('CH1_'+prefix))
# Continue the same terrain well beyond the camera frustum; UV repeats at one block.
ob=plane('Distant_ground',(0,0,-.007),(140,140),mat('grass_block_top'),(-math.pi/2,0,0))
for v in ob.data.vertices:v.co.z-=70
for uv in ob.data.uv_layers.active.data:uv.uv*=140
# Timber frame, recessed dark window and shutter volumes.
wood=mat('oak_log');plank=mat('oak_planks');black=mat('wound')
for x in [-8.46,-4.54]:box('Cottage_beam',(x,6.5,1.75),(.15,3.9,.18),wood)
for y in [6.1,6.9]:box('Window_pane',(-4.49,y,1.98),(.018,.70,.76),black)
box('Window_cross',(-4.47,6.5,1.98),(.025,1.65,.075),plank)
box('Window_cross_v',(-4.46,6.5,1.98),(.025,.075,.90),plank)
# Low block ridges behind the tree layer close the distant horizon.
for x,y,w,h in [(-9,17,10,1.1),(3,19,14,1.6),(14,24,10,2.0),(-17,-18,9,1.4)]:
 ob=box('Distant_ridge',(x,y,h/2-.1),(w,6,h),mat('grass_block_top'))
 for uv in ob.data.uv_layers.active.data:uv.uv*=3
sc.render.engine='BLENDER_EEVEE';sc.eevee.taa_render_samples=24
sc.render.resolution_x=960;sc.render.resolution_y=540
# No random camera shake or repeated placeholders; only the sky event has a finite impulse.
sc['revision']='Final mechanics, contacts, native UVs, twelve editorial shots'
sc.frame_set(1)
for im in bpy.data.images:
 if im.source=='FILE' and im.users:im.pack()
# Save a source containing the owned scene and its dependencies, preserving other open scenes.
bpy.data.libraries.write(str(SRC/'ch1_intro.blend'),{sc},fake_user=True,compress=True)
print('CH1_SOURCE_SAVED',len(sc.objects),len([i for i in bpy.data.images if i.packed_file]))
