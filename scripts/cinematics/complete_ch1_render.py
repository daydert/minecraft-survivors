"""Finish the scheduled headless tail after the reviewed camera/contact revision.
Usage: python complete_ch1_render.py PID. No Blender scene editing here.
"""
import sys,time,os,signal,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'qa/cinematics/ch1_intro';pid=int(sys.argv[1])
log=OUT/'render_resume.log'
while "0924.png'" not in log.read_text(errors='replace'):
 os.kill(pid,0)
 time.sleep(2)
os.kill(pid,signal.SIGTERM)
print('RENDERING_REVIEWED_TAIL_925_1200',flush=True)
with (OUT/'render_tail.log').open('w') as f:
 subprocess.run(['/home/daydert/.local/share/Steam/steamapps/common/Blender/blender','--background',str(ROOT/'assets/art_source/ch1_intro/ch1_intro.blend'),'--python',str(ROOT/'scripts/cinematics/render_ch1_intro.py'),'--','--engine','BLENDER_EEVEE','--samples','24','--start','925'],stdout=f,stderr=subprocess.STDOUT,check=True,cwd=ROOT)
# The final lightning review affects only these twelve images.
with (OUT/'render_sky.log').open('w') as f:
 subprocess.run(['/home/daydert/.local/share/Steam/steamapps/common/Blender/blender','--background',str(ROOT/'assets/art_source/ch1_intro/ch1_intro.blend'),'--python',str(ROOT/'scripts/cinematics/render_ch1_intro.py'),'--','--engine','BLENDER_EEVEE','--samples','24','--frames',','.join(map(str,range(250,261))))],stdout=f,stderr=subprocess.STDOUT,check=True,cwd=ROOT)
for frame in range(250,261):
 import shutil
 shutil.copyfile(OUT/'stills_BLENDER_EEVEE'/f'{frame:04d}.png',OUT/'frames'/f'{frame:04d}.png')
subprocess.run([sys.executable,str(ROOT/'scripts/cinematics/encode_ch1_intro.py')],check=True,cwd=ROOT)
print('CH1_RENDER_AND_ENCODE_COMPLETE',flush=True)
