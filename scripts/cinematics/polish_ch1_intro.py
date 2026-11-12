"""Apply the latest acting functions to the owned MCP scene without rebuilding sets."""
import bpy,math
from pathlib import Path
from mathutils import Vector,Quaternion,Matrix
ROOT=Path('/home/daydert/MinecraftSurvivors2');SRC=ROOT/'assets/art_source/ch1_intro';FPS=24
sc=bpy.data.scenes['CH1_Garden_Prologue'];bpy.context.window.scene=sc
suffix={'root':'Root','hips':'Hips','torso':'Torso','head':'Head','Rarm':'RShoulder','Larm':'LShoulder','Relbow':'RElbow','Lelbow':'LElbow','Rwrist':'RWrist','Lwrist':'LWrist','Rleg':'RHip','Lleg':'LHip','Rknee':'RKnee','Lknee':'LKnee'}
def rig(prefix):return {k:sc.objects['CH1_'+prefix+'_'+v] for k,v in suffix.items()}
S=rig('Steve');A=rig('Alex');H=rig('Herobrine')
def obj(prefix):return next(o for o in sc.objects if o.name.startswith(prefix))
wound=obj('CH1_Alex_wound');blood=obj('CH1_Alex_blood');smile=obj('CH1_HB_smile');sword=obj('CH1_Sword_grip');lid=obj('CH1_Chest_lid')
sun=obj('LGT_CH1_Sun');fill=obj('LGT_CH1_Sky');bg=sc.world.node_tree.nodes['Background']
fractures=[o for o in sc.objects if o.name.startswith('CH1_sky_fracture')];particles=[o for o in sc.objects if o.name.startswith('CH1_blood_pixel')]
shots=[(0,5,'Garden',35),(5,9,'Together',53),(9,12,'Sky',30),(12,16,'Behind',48),(16,19,'Contact',53),(19,22,'Steve',46),(22,26,'Invitation',65),(26,30,'Catch',42),(30,36,'Loss',53),(36,41,'Decision',53),(41,46,'Sword',46),(46,50,'Forest',35)]
cams={m.name:m.camera for m in sc.timeline_markers}
source=(ROOT/'scripts/cinematics/build_ch1_intro.py').read_text();functions=source[source.index('def clamp(x):'):source.index('# First save a recoverable')]
exec(compile(functions,'CH1_acting','exec'))
for f in range(1,1201):
 pose((f-1)/FPS,f)
 if f%120==0:(ROOT/'qa/cinematics/ch1_intro/build_progress.txt').write_text('polish '+str(f))
# Reproducible camera lens update follows the current shot list.
for a,b,name,lens in shots:cams[name].data.lens=lens
sc.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'ch1_intro.blend'))
print('CH1_POLISHED')
