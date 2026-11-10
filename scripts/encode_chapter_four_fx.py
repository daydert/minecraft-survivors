"""Encode the IV impact-pass film with the simulation's own sound events."""
from pathlib import Path
import json, shutil, subprocess, sys
ROOT=Path(__file__).resolve().parent.parent
OUT=ROOT/'qa/recordings'
data=json.loads((OUT/'chapter_four_fx_timeline.json').read_text())
seconds=data['frames']/data['fps']
events={}
for manifest in ['minecraft_audio','nether_audio','chapter_four_audio']:
    events.update(json.loads((ROOT/f'data/{manifest}.json').read_text()))
args=['ffmpeg','-hide_banner','-loglevel','error','-y','-framerate',str(data['fps']),'-i',str(OUT/'chapter_four_fx_frames/%05d.png'),'-i',str(ROOT/'assets/audio/chapter_four/ancestry.ogg')]
graph='[0:v]scale=1280:720:flags=neighbor[v];[1:a]volume=0.25[bg];'
labels=['[bg]'];last={}
cues=[]
for cue in data['sound_events']:
    if cue['id'] not in events or cue['time']-last.get(cue['id'],-9)<.07:continue
    last[cue['id']]=cue['time'];cues.append(cue)
cues=cues[:420]
for n,cue in enumerate(cues):
    spec=events[cue['id']];variant=spec['variants'][0]
    args+=['-i',str(ROOT/variant['path'].removeprefix('res://'))]
    delay=round(cue['time']*1000)
    graph+=f'[{n+2}:a]volume={spec["gain"]*.55*variant.get("volume",1)},adelay={delay}|{delay}[c{n}];'
    labels.append(f'[c{n}]')
graph+=''.join(labels)+f'amix=inputs={len(labels)}:normalize=0,alimiter=limit=0.95,atrim=0:{seconds},afade=t=out:st={seconds-.8}:d=0.8,apad=whole_dur={seconds}[a]'
target=OUT/(sys.argv[1] if len(sys.argv)>1 and sys.argv[1].endswith('.mp4') else 'chapter_four_fx.mp4')
args+=['-filter_complex',graph,'-map','[v]','-map','[a]','-c:v','libx264','-preset','fast','-crf','18','-pix_fmt','yuv420p','-c:a','aac','-b:a','192k','-t',str(seconds),'-movflags','+faststart',str(target)]
subprocess.run(args,check=True)
print(target,seconds)
if '--clean' in sys.argv:shutil.rmtree(OUT/'chapter_four_fx_frames')
