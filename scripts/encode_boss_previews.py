"""Encode rendered QA frames with supplied music aligned to simulation events.

Run qa/herobrine_record.gd and qa/wither_record.gd before this script.
The films use diagnostic phase selection, not artificial passability evidence.
"""
import argparse,json,subprocess,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
OUT=ROOT/'qa/recordings'
def add_cues(args,graph,labels,cues,start_index):
 events={}
 for file in ['minecraft_audio','nether_audio','duel_audio','ghast_intro_audio']:events.update(json.loads((ROOT/f'data/{file}.json').read_text()))
 for n,event in enumerate(cues):
  spec=events[event['id']];variant=spec['variants'][0];path=ROOT/variant['path'].removeprefix('res://')
  args+=['-i',str(path)];label='cue'+str(n);delay=round(event['time']*1000)
  graph+=f'[{n+start_index}:a]volume={spec["gain"]*.6*variant.get("volume",1)},adelay={delay}|{delay}[{label}];';labels.append('['+label+']')
 return graph
def duration(path):
 return float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','default=noprint_wrappers=1:nokey=1',str(path)]))
def encode(name,suffix='polish'):
 data=json.loads((OUT/f'{name}_timeline.json').read_text())
 total=data['frames']/data['fps'];frames=OUT/f'{name}_frames'
 theme='music' if name=='tnt' else 'music_'+name
 args=['ffmpeg','-hide_banner','-loglevel','error','-y','-framerate',str(data['fps']),'-i',str(frames/'%05d.png'),'-i',str(ROOT/f'assets/audio/{theme}.ogg')]
 video='[0:v]scale=1280:720:flags=neighbor[v];'
 if name=='herobrine':
  end=data['phase_start_seconds']['end']
  graph=video+f'[1:a]atrim=0:{end},afade=t=out:st={end-.8}:d=0.8,apad=whole_dur={total}[a]'
 elif name=='tnt':
  graph=video+f'[1:a]atrim=0:{total},volume=0.2[bg];';labels=['[bg]']
  graph=add_cues(args,graph,labels,data.get('sound_events',[]),2)
  graph+=''.join(labels)+f'amix=inputs={len(labels)}:normalize=0,alimiter=limit=0.95,apad=whole_dur={total}[a]'
 else:
  win=data['events']['victory'];cross=data['events']['crossing']
  cue=duration(ROOT/'assets/audio/boss_win.ogg');song=max(.1,cross-win-cue)
  args+=['-i',str(ROOT/'assets/audio/boss_win.ogg'),'-stream_loop','-1','-i',str(ROOT/'assets/audio/music_victory.ogg')]
  graph=video+f'[1:a]atrim=0:{win},volume=0.45,afade=t=out:st={win-.4}:d=0.4[a0];[2:a]volume=0.6,adelay={round(win*1000)}|{round(win*1000)}[a1];[3:a]atrim=0:{song},volume=0.45,afade=t=in:st=0:d=0.4,afade=t=out:st={max(0,song-.4)}:d=0.4,adelay={round((win+cue)*1000)}|{round((win+cue)*1000)}[a2];'
  labels=['[a0]','[a1]','[a2]']
  graph=add_cues(args,graph,labels,data.get('sound_events',[]),4)
  graph+=''.join(labels)+f'amix=inputs={len(labels)}:normalize=0,alimiter=limit=0.95,apad=whole_dur={total}[a]'
 target=OUT/f'{name}_{suffix}.mp4'
 args+=['-filter_complex',graph,'-map','[v]','-map','[a]','-c:v','libx264','-preset','fast','-crf','18','-pix_fmt','yuv420p','-c:a','aac','-b:a','192k','-t',str(total),'-movflags','+faststart',str(target)]
 subprocess.run(args,check=True)
 assert abs(duration(target)-total)<.1
 print(target.relative_to(ROOT),round(total,2),'seconds',flush=True)
 return frames
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--clean',action='store_true');parser.add_argument('--only',choices=['herobrine','wither','tnt']);parser.add_argument('--suffix',default='polish');opt=parser.parse_args()
 assert opt.suffix.replace('_','').isalnum()
 for name in [opt.only] if opt.only else ['herobrine','wither']:
  frames=encode(name,opt.suffix)
  if opt.clean:
   assert frames.parent==OUT and frames.name in ['herobrine_frames','wither_frames','tnt_frames']
   shutil.rmtree(frames)
