"""Diagnostic gameplay montage. Original supplied themes and vanilla sound events.
Audio is composed from event times; this is not a recording of the live mixer.
"""
import argparse,json,subprocess,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent

def encode(clean=False, output="chapter_three"):
 data=json.loads((ROOT/'qa/end_recording.json').read_text());total=data['frames']/data['fps']
 markers={s['mode']:s['at'] for s in data['shots']};a=markers['end_dragon'];b=markers['end_betrayal']
 args=['ffmpeg','-hide_banner','-loglevel','error','-y','-framerate',str(data['fps']),'-i',str(ROOT/'qa/end_film/%06d.png')]
 for theme in ['music','music_dragon','music_endersteve']:args+=['-i',str(ROOT/f'assets/audio/{theme}.ogg')]
 graph='[0:v]scale=1280:720:flags=neighbor[v];'
 for n,(start,length) in enumerate([(0,a),(a,b-a),(b,total-b)]):
  graph+=f'[{n+1}:a]atrim=duration={length},asetpts=PTS-STARTPTS,volume=0.28,afade=t=in:d=0.3,afade=t=out:st={max(0,length-.4)}:d=0.4[s{n}];'
 graph+='[s0][s1][s2]concat=n=3:v=0:a=1[bg];';labels=['[bg]'];events={}
 for name in ['minecraft_audio','nether_audio','duel_audio','ghast_intro_audio','end_audio']:events.update(json.loads((ROOT/f'data/{name}.json').read_text()))
 cues=[e for e in data.get('sound_events',[]) if e['id'] in events]
 important={'dragon_death','portal_open','portal_ignite','portal_travel','mace_smash','rocket_launch','end_teleport','explosion','shield_block'}
 chosen=[e for e in cues if e['id'] in important];chosen+= [e for e in cues if e['id'] not in important][::max(1,len(cues)//45)]
 chosen=sorted(chosen,key=lambda e:e['time'])[:110]
 for n,e in enumerate(chosen):
  spec=events[e['id']];var=spec['variants'][0];args+=['-i',str(ROOT/var['path'].removeprefix('res://'))]
  delay=round(e['time']*1000);graph+=f'[{n+4}:a]volume={spec["gain"]*.45*var.get("volume",1)},adelay={delay}|{delay}[c{n}];';labels.append(f'[c{n}]')
 graph+=''.join(labels)+f'amix=inputs={len(labels)}:normalize=0,alimiter=limit=0.95,apad=whole_dur={total}[a]'
 target=ROOT/f'qa/recordings/{output}.mp4';target.parent.mkdir(exist_ok=True)
 args+=['-filter_complex_threads','1','-filter_complex',graph,'-map','[v]','-map','[a]','-c:v','libx264','-threads','2','-preset','fast','-crf','18','-pix_fmt','yuv420p','-c:a','aac','-b:a','192k','-t',str(total),'-movflags','+faststart',str(target)]
 subprocess.run(args,check=True);(target.parent/f'{output}_timeline.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
 if clean:shutil.rmtree(ROOT/'qa/end_film')
 print(target.relative_to(ROOT),round(total,2),'seconds; diagnostic montage',flush=True)
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--clean',action='store_true');p.add_argument('--output',default='chapter_three');args=p.parse_args();encode(args.clean,args.output)
