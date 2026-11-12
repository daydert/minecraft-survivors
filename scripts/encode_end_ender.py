"""Encode the Chapter III finale film with its music cues and sound events."""
from pathlib import Path
import json, shutil, subprocess, sys
ROOT=Path(__file__).resolve().parent.parent
OUT=ROOT/'qa/recordings'
data=json.loads((OUT/'end_ender_timeline.json').read_text())
seconds=data['frames']/data['fps']
tracks={"end":"music_3.ogg","dragon":"music_dragon.ogg","endersteve":"music_endersteve.ogg","victory":"music_victory.ogg","relic":"chapter_four/relic.ogg"}
events={}
for m in ['minecraft_audio','nether_audio','end_audio','chapter_four_audio','end_external_audio','v2_audio']:
    p=ROOT/f'data/{m}.json'
    if p.exists():events.update(json.loads(p.read_text()))
args=['ffmpeg','-hide_banner','-loglevel','error','-y','-framerate',str(data['fps']),'-i',str(OUT/'end_ender_frames/%05d.png')]
graph='[0:v]scale=1280:720:flags=neighbor[v];';labels=[];n=1
music=data['music']
for i,cue in enumerate(music):
    if cue['track'] not in tracks:continue
    end=music[i+1]['time'] if i+1<len(music) else seconds
    args+=['-stream_loop','-1','-i',str(ROOT/'assets/audio'/tracks[cue['track']])]
    d=round(cue['time']*1000);length=max(.1,end-cue['time'])
    graph+=f'[{n}:a]atrim=0:{length},afade=t=in:d=0.5,afade=t=out:st={max(0,length-0.4)}:d=0.4,volume=0.35,adelay={d}|{d}[m{n}];';labels.append(f'[m{n}]');n+=1
last={}
for cue in data['sound_events']:
    if cue['id'] not in events or cue['time']-last.get(cue['id'],-9)<.07:continue
    last[cue['id']]=cue['time'];spec=events[cue['id']];var=spec['variants'][0]
    args+=['-i',str(ROOT/var['path'].removeprefix('res://'))];d=round(cue['time']*1000)
    graph+=f'[{n}:a]volume={spec["gain"]*.6*var.get("volume",1)},adelay={d}|{d}[s{n}];';labels.append(f'[s{n}]');n+=1
    if n>480:break
graph+=''.join(labels)+f'amix=inputs={len(labels)}:normalize=0,alimiter=limit=0.95,atrim=0:{seconds},apad=whole_dur={seconds}[a]'
target=OUT/'chapter_three_ender.mp4'
args+=['-filter_complex',graph,'-map','[v]','-map','[a]','-c:v','libx264','-preset','fast','-crf','18','-pix_fmt','yuv420p','-c:a','aac','-b:a','192k','-t',str(seconds),'-movflags','+faststart',str(target)]
subprocess.run(args,check=True);print(target,seconds)
if '--clean' in sys.argv:shutil.rmtree(OUT/'end_ender_frames')
