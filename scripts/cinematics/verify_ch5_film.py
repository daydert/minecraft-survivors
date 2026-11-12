"""Verify the final Godot film, including the audible fade/quiet/sting boundary."""
import json,subprocess,hashlib,math,argparse
from pathlib import Path
import numpy as np
R=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser();parser.add_argument('--video',type=Path,default=R/'qa/recordings/chapter_five_cinematic_polish.mp4');parser.add_argument('--timeline',type=Path,default=R/'qa/recordings/chapter_five_cinematic_polish_timeline.json');parser.add_argument('--report',type=Path,default=R/'qa/ch5_cinema/video_verification.json');args=parser.parse_args()
video=args.video.resolve();timeline=json.loads(args.timeline.read_text())
info=json.loads(subprocess.check_output(['ffprobe','-v','error','-count_frames','-show_entries','stream=codec_type,codec_name,width,height,r_frame_rate,nb_read_frames,duration:format=duration','-of','json',str(video)],text=True))
v=next(s for s in info['streams'] if s['codec_type']=='video');a=next(s for s in info['streams'] if s['codec_type']=='audio')
assert v['r_frame_rate']=='30/1' and int(v['nb_read_frames'])==timeline['frames']
assert v['width']==1280 and v['height']==720 and a['codec_name']=='aac'
assert abs(float(v['duration'])-timeline['frames']/30)<.002
subprocess.run(['ffmpeg','-v','error','-i',str(video),'-f','null','-'],check=True)
pcm=np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',str(video),'-vn','-ac','2','-ar','48000','-f','f32le','-']),dtype=np.float32).reshape(-1,2)
cue={c['id']:c['time'] for c in timeline['sound_events'] if c['id'].startswith('ch5_ending')}
def rms(start,end):
 x=pcm[round(start*48000):round(end*48000)].astype(np.float64)
 return float(np.sqrt(np.mean(x*x)))
fade=cue['ch5_ending_fade'];sting=cue['ch5_ending_sting']
windows={'before_fade':(fade-1.5,fade-.2),'fade_tail':(fade+3.15,fade+3.4),'quiet_before_sting':(sting-1.0,sting-.2),'sting_attack':(sting,sting+.6)}
levels={k:{'window':win,'rms':rms(*win)} for k,win in windows.items()}
assert levels['fade_tail']['rms']<levels['before_fade']['rms']*.2,levels
assert levels['quiet_before_sting']['rms']<.004,levels
assert levels['sting_attack']['rms']>.01,levels
assert levels['sting_attack']['rms']>max(.00001,levels['quiet_before_sting']['rms'])*10
report={'status':'pass','video':str(video.relative_to(R)),'sha256':hashlib.sha256(video.read_bytes()).hexdigest(),'probe':info,'ending_cues':cue,'audio':levels,'decoded_peak':float(np.max(np.abs(pcm))),'source_sha256':{p:hashlib.sha256((R/p).read_bytes()).hexdigest() for p in ['data/chapter_five_cinema.json','assets/art_source/ch5_finale/ch5_cinema.blend','assets/audio/chapter_five/ending_theme.ogg','assets/audio/chapter_five/ending_sting.ogg']}}
args.report.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
