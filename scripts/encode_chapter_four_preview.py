"""Encode the stage A review film, including actual simulation sound events."""
from pathlib import Path
import argparse
import json
import shutil
import subprocess
ROOT=Path(__file__).resolve().parent.parent
OUT=ROOT/'qa/recordings'

def encode(clean=False,stage="a"):
    stem="chapter_four" if stage=="a" else "chapter_four_b"
    data=json.loads((OUT/(stem+'_timeline.json')).read_text())
    seconds=data['frames']/data['fps']
    frames=OUT/(stem+'_frames')
    args=['ffmpeg','-hide_banner','-loglevel','error','-y','-framerate',str(data['fps']),'-i',str(frames/'%05d.png'),'-i',str(ROOT/'assets/audio/chapter_four/ancestry.ogg')]
    graph='[0:v]scale=1280:720:flags=neighbor[v];[1:a]volume=0.3[bg];'
    labels=['[bg]']
    events={}
    for manifest in ['minecraft_audio','nether_audio','chapter_four_audio']:
        events.update(json.loads((ROOT/f'data/{manifest}.json').read_text()))
    cues=[e for e in data['sound_events'] if e['id'] in events]
    for n,cue in enumerate(cues):
        spec=events[cue['id']];variant=spec['variants'][0]
        args+=['-i',str(ROOT/variant['path'].removeprefix('res://'))]
        delay=round(cue['time']*1000)
        graph+=f'[{n+2}:a]volume={spec["gain"]*.6*variant.get("volume",1)},adelay={delay}|{delay}[cue{n}];'
        labels.append(f'[cue{n}]')
    graph+=''.join(labels)+f'amix=inputs={len(labels)}:normalize=0,alimiter=limit=0.95,atrim=0:{seconds},afade=t=out:st={seconds-.8}:d=0.8,apad=whole_dur={seconds}[a]'
    target=OUT/('chapter_four_stage_'+stage+'.mp4')
    args+=['-filter_complex',graph,'-map','[v]','-map','[a]','-c:v','libx264','-preset','fast','-crf','18','-pix_fmt','yuv420p','-c:a','aac','-b:a','192k','-t',str(seconds),'-movflags','+faststart',str(target)]
    subprocess.run(args,check=True)
    print(target,seconds,'seconds; diagnostic camera cuts, ordinary HP')
    if clean:shutil.rmtree(frames)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--clean',action='store_true');parser.add_argument('--stage',choices=['a','b'],default='a')
    opt=parser.parse_args();encode(opt.clean,opt.stage)
