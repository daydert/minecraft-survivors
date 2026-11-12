"""Encode the complete film, original local SFX and Russian dialogue subtitle."""
import subprocess,json,math,shutil
from pathlib import Path
from PIL import Image
import re
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'qa/cinematics/ch1_intro';REC=ROOT/'qa/recordings'
REC.mkdir(exist_ok=True)
shutil.copyfile(OUT/'frames/0001.png',ROOT/'assets/cinematics/ch1_intro_poster.png')
assert all((OUT/'frames'/f'{f:04d}.png').is_file() for f in range(1,1201)), 'Incomplete sequence'
# Audio cues are shared by the editorial event sheet and the sound mix.
cues=[(2.0,'minecraft/step_grass2',.08),(31.6,'chapter_four/random_breath',.15),(10.35,'minecraft/ambient_weather_thunder1',.47),(12.6,'minecraft/mob_endermen_portal2',.32),(16.94,'minecraft/entity_player_attack_sweep2',.48),(17.13,'minecraft/entity_player_attack_strong5',.62),(17.16,'minecraft/damage_hit2',.26),(26.23,'minecraft/entity_player_attack_sweep1',.18),(26.76,'minecraft/mob_endermen_portal',.28),(29.52,'minecraft/step_grass3',.28),(31.35,'minecraft/step_grass1',.23),(42.66,'minecraft/block_chest_open',.48),(43.8,'minecraft/entity_player_attack_sweep1',.12)]
for a,b,step in [(19.1,20.6,.225),(41,42.5,.325),(46,50,.325)]:
 t=a
 while t<b:
  cues.append((t,'minecraft/step_grass'+str(1+round(t*10)%5),.27));t+=step
args=['ffmpeg','-y','-v','error','-i',str(ROOT/'assets/audio/music.ogg')]
graph='[0:a]atrim=0:9.5,volume=0.13,afade=t=in:d=1,afade=t=out:st=8.7:d=0.8,apad=whole_dur=50[music];';labels=['[music]'];ledger=[]
for at,name,gain in cues:
 p=ROOT/'assets/audio'/f'{name}.ogg'
 if not p.is_file():raise FileNotFoundError(p)
 i=len(ledger)+1;args+=['-i',str(p)];label='s'+str(i)
 graph+=f'[{i}:a]volume={gain},adelay={round(at*1000)}|{round(at*1000)}[{label}];';labels.append('['+label+']');ledger.append({'time':at,'source':str(p.relative_to(ROOT)),'gain':gain})
graph+=''.join(labels)+f'amix=inputs={len(labels)}:normalize=0,alimiter=limit=0.90,atrim=0:50[a]'
mix=OUT/'mix.wav'
# Separate SFX stem lets the game obey music/effects volume independently.
sfxgraph=graph[graph.index(';')+1:].replace('[music]','').replace('amix=inputs='+str(len(labels)), 'amix=inputs='+str(len(labels)-1))
subprocess.run(args+['-filter_complex',sfxgraph,'-map','[a]','-ar','48000','-ac','2',str(OUT/'sfx.wav')],check=True)
subprocess.run(args+['-filter_complex',graph,'-map','[a]','-ar','48000','-ac','2',str(mix)],check=True)
# Draw vanilla pixel glyphs at 1:1 layout, then nearest-scale for the 960px master.
fontpath=ROOT/'assets/fonts/minecraft/minecraft_regular.fnt'
fonttext=fontpath.read_text();pages={}
for line in fonttext.splitlines():
 if line.startswith('page '):
  page=int(re.search(r'id=(\d+)',line)[1]);file=re.search(r'file="([^"]+)"',line)[1];pages[page]=Image.open(fontpath.parent/file).convert('RGBA')
chars={}
for line in fonttext.splitlines():
 if line.startswith('char '):
  d={k:int(v) for k,v in re.findall(r'(\w+)=(-?\d+)',line)};chars[d['id']]=d
subtitle=Image.new('RGBA',(640,360));textlines=['Присоединишься к вечеринке','после рассвета?']
for li,text in enumerate(textlines):
 width=sum(chars[ord(c)]['xadvance']*2 for c in text);x=(640-width)//2;y=307+li*21
 for c in text:
  d=chars[ord(c)];glyph=pages[d['page']].crop((d['x'],d['y'],d['x']+d['width'],d['y']+d['height']))
  glyph=glyph.resize((glyph.width*2,glyph.height*2),Image.Resampling.NEAREST)
  alpha=glyph.getchannel('A');white=Image.new('RGBA',glyph.size,'white');white.putalpha(alpha)
  shadow=Image.new('RGBA',glyph.size,(0,0,0,255));shadow.putalpha(alpha)
  subtitle.alpha_composite(shadow,(x+d['xoffset']*2+1,y+d['yoffset']*2+1));subtitle.alpha_composite(white,(x+d['xoffset']*2,y+d['yoffset']*2));x+=d['xadvance']*2
subtitle=subtitle.resize((960,540),Image.Resampling.NEAREST);subtitle.save(OUT/'subtitle.png')
master=REC/'chapter_one_prologue.mp4'
subprocess.run(['ffmpeg','-y','-v','error','-framerate','24','-i',str(OUT/'frames/%04d.png'),'-i',str(mix),'-i',str(OUT/'subtitle.png'),'-filter_complex',"[0:v][2:v]overlay=0:0:enable='between(t,22,25.85)'[v]",'-map','[v]','-map','1:a','-c:v','libx264','-crf','17','-preset','medium','-pix_fmt','yuv420p','-c:a','aac','-b:a','192k','-t','50','-movflags','+faststart',str(master)],check=True)
subprocess.run(['ffmpeg','-y','-v','error','-i',str(master),'-an','-c:v','libtheora','-g','1','-q:v','9',str(ROOT/'assets/cinematics/ch1_intro.ogv')],check=True)
subprocess.run(['ffmpeg','-y','-v','error','-i',str(OUT/'sfx.wav'),'-c:a','libvorbis','-q:a','5',str(ROOT/'assets/cinematics/ch1_intro_sfx.ogg')],check=True)
(OUT/'sound_events.json').write_text(json.dumps(ledger,indent=2)+'\n')
probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-count_frames','-show_streams','-of','json',str(master)]))
v=next(s for s in probe['streams'] if s['codec_type']=='video');assert int(v['nb_read_frames'])==1200 and abs(float(v['duration'])-50)<.01
(OUT/'encoded_verified.json').write_text(json.dumps(probe,indent=2)+'\n')
print(master)
