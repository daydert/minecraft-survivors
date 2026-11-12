"""Steam Blender --background ch1_intro.blend --python this.py -- [options]."""
import bpy, argparse, sys, time, json
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--frames');p.add_argument('--engine',default='CYCLES');p.add_argument('--samples',type=int,default=12);p.add_argument('--scale',type=int,default=100);p.add_argument('--resume',action='store_true');p.add_argument('--start',type=int,default=1);p.add_argument('--end',type=int,default=1200);a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
ROOT=Path('/home/daydert/MinecraftSurvivors2');out=ROOT/'qa/cinematics/ch1_intro';out.mkdir(parents=True,exist_ok=True)
sc=bpy.data.scenes['CH1_Garden_Prologue'];bpy.context.window.scene=sc
sc.render.engine=a.engine;sc.render.resolution_percentage=a.scale
sc.cycles.samples=a.samples;sc.cycles.use_denoising=True;sc.cycles.device='CPU'
if a.engine=='CYCLES':sc.render.threads_mode='FIXED';sc.render.threads=12
else:sc.eevee.taa_render_samples=a.samples
sc.render.image_settings.file_format='PNG';sc.render.image_settings.color_mode='RGB';sc.render.image_settings.compression=15
frames=list(map(int,a.frames.split(','))) if a.frames else range(1,1201)
folder=out/('stills_'+a.engine if a.frames else 'frames');folder.mkdir(exist_ok=True)
start=time.monotonic()
if not a.frames and not a.resume:
 sc.frame_start=a.start;sc.frame_end=a.end;sc.render.filepath=str(folder/'')+'/'
 bpy.ops.render.render(animation=True)
 frames=[]
for f in frames:
 path=folder/('%04d.png'%f)
 if a.resume and path.is_file():continue
 sc.frame_set(f);sc.render.filepath=str(path)
 bpy.ops.render.render(write_still=True)
 print('CH1_FRAME',f,'elapsed',round(time.monotonic()-start,2),flush=True)
if not a.frames:
 assert all((folder/('%04d.png'%f)).is_file() for f in range(1,1201))
 (out/'render_verified.json').write_text(json.dumps({'frames':1200,'fps':24,'duration':50,'resolution':[960*a.scale//100,540*a.scale//100],'engine':a.engine,'samples':a.samples,'reopened_source':bpy.data.filepath,'packed_images':all(i.packed_file for i in bpy.data.images if i.source=='FILE')},indent=2)+'\n')
