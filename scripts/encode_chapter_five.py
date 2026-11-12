"""Mix Chapter V's recorded gameplay cues with the runtime music contract.
Optional --timeline / --frames / --output keep previous films for comparison.
The user's ending theme is faded at the recorded fade event, not played to EOF.
"""
from pathlib import Path
import argparse,json,shutil,subprocess
ROOT=Path(__file__).resolve().parent.parent
OUT=ROOT/'qa/recordings'

def encode(timeline,frames,target):
    data=json.loads(timeline.read_text());seconds=data['frames']/data['fps']
    music_gain=data.get('music_volume',.45);fx_gain=data.get('effects_volume',.65)
    tracks={'music':'music.ogg','herobrine':'music_herobrine.ogg',
        'ch5_ambient':'ch5_music/wastes_ambient.ogg','ch5_talk':'ch5_music/wastes_ambient.ogg',
        'ch5_notch':'ch5_music/battle_theme.ogg','ch5_fighter':'ch5_music/fight_phase2.ogg',
        'ch5_quake':'ch5_music/fight_phase1.ogg','ch5_brawl':'ch5_music/fight_final.ogg',
        'ch5_chair':'ch5_music/chair_tension.ogg','ch5_flight':'ch5_music/flight_space.ogg'}
    events={}
    for m in ['minecraft_audio','nether_audio','end_audio','chapter_four_audio','chapter_four_external_audio','end_external_audio','v2_audio','duel_audio','chapter_one_audio','chapter_five_audio']:
        p=ROOT/f'data/{m}.json'
        if p.exists():events.update(json.loads(p.read_text()))
    args=['ffmpeg','-hide_banner','-loglevel','error','-y','-framerate',str(data['fps']),'-i',str(frames/'%05d.png')]
    graph=['[0:v]scale=1280:720:flags=neighbor[v]'];labels=[];n=1
    def track(file,start,gain,filters='',loop=False):
        nonlocal n
        if loop:args.extend(['-stream_loop','-1'])
        args.extend(['-i',str(ROOT/'assets/audio'/file)])
        delay=round(start*1000)
        graph.append(f'[{n}:a]{filters}volume={gain},adelay={delay}|{delay}[a{n}]')
        labels.append(f'[a{n}]');n+=1
    music=data.get('music',[])
    for i,cue in enumerate(music):
        name=cue['track'].removeprefix('chapter_four_end:')
        if name not in tracks:continue
        end=music[i+1]['time'] if i+1<len(music) else seconds
        length=max(.01,end-cue['time'])
        track(tracks[name],cue['time'],music_gain,f'atrim=0:{length},afade=t=in:d=0.9,afade=t=out:st={max(0,length-.4)}:d=0.4,',True)
    last={};cue_list=data['sound_events']
    for cue in cue_list:
        name=cue['id'];time=cue['time']
        if time-last.get(name,-9)<.07:continue
        last[name]=time
        if name=='ch5_ending_theme':
            fade=next((c['time'] for c in cue_list if c['id']=='ch5_ending_fade' and c['time']>=time),seconds)
            duration=max(0,fade-time)
            track('chapter_five/ending_theme.ogg',time,music_gain*1.6,
                  # Godot tweens volume_db linearly to -60 dB in 3.5 seconds.
                  f"atrim=0:{duration+3.5},volume='if(lt(t,{duration}),1,exp(log({.001/max(.001,music_gain*1.6)})*min(1,(t-{duration})/3.5)))':eval=frame,")
        elif name=='ch5_ending_sting':track('chapter_five/ending_sting.ogg',time,fx_gain)
        elif name=='ch5_credits':track('ch5_music/flight_space.ogg',time,music_gain,'afade=t=in:d=3.0,')
        elif name in events:
            spec=events[name];variant=spec['variants'][0]
            # Variant choice is cosmetic; no combat RNG is used by the capture.
            file=variant['path'].removeprefix('res://assets/audio/')
            track(file,time,spec['gain']*fx_gain*variant.get('volume',1))
    if not labels:
        graph.append(f'anullsrc=r=48000:cl=stereo,atrim=0:{seconds}[a]')
    else:
        graph.append(''.join(labels)+f'amix=inputs={len(labels)}:normalize=0,alimiter=limit=0.9:latency=1,atrim=0:{seconds},apad=whole_dur={seconds}[a]')
    args+=['-filter_complex_threads','1','-filter_complex',';'.join(graph),'-map','[v]','-map','[a]',
           '-c:v','libx264','-threads','4','-preset','fast','-crf','18','-pix_fmt','yuv420p',
           '-c:a','aac','-b:a','192k','-t',str(seconds),'-movflags','+faststart',str(target)]
    subprocess.run(args,check=True);print(target,seconds)

if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--timeline',type=Path,default=OUT/'chapter_five_timeline.json');ap.add_argument('--frames',type=Path,default=OUT/'chapter_five_frames');ap.add_argument('--output',type=Path,default=OUT/'chapter_five_rework.mp4');ap.add_argument('--clean',action='store_true');a=ap.parse_args()
    encode(a.timeline,a.frames,a.output)
    if a.clean:shutil.rmtree(a.frames)
