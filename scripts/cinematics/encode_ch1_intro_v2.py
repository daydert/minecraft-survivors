"""Encode the reworked chapter-I prologue: frames + SFX stem + Russian subtitle -> MP4 master, Theora for Godot."""
import subprocess, json, re, shutil
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]; OUT = ROOT / 'qa/cinematics/ch1_intro_v2'; REC = ROOT / 'qa/recordings'
FPS = 24; FRAMES = 1272; LEN = FRAMES / FPS
AUD = ROOT / 'assets/audio'
REC.mkdir(exist_ok=True)
assert all((OUT / 'frames' / f'{f:04d}.png').is_file() for f in range(1, FRAMES + 1)), 'Incomplete sequence'

def snd(name):
    for d in ('minecraft', 'chapter_four', 'end_ext', 'ch5_sfx', ''):
        p = AUD / d / f'{name}.ogg'
        if p.is_file(): return p
    raise FileNotFoundError(name)

# Event sheet shared with build_ch1_intro_v2.py timings (HIT=16.92, stop 21.2-25.35, vanish 25.45).
cues = [
    (1.2, 'step_grass2', .10), (2.4, 'step_grass4', .08), (6.05, 'entity_player_attack_sweep1', .18), (6.62, 'step_grass1', .22),
    (9.82, 'ambient_weather_thunder1', .95), (9.84, 'random_explode1', .35), (10.95, 'ambient_weather_thunder2', .55),
    (11.0, 'ambient_nether_soulsand_valley_mood1', .55),
    (13.0, 'mob_endermen_portal', .45), (13.6, 'mob_warden_heartbeat_1', .7), (14.55, 'mob_warden_heartbeat_2', .75), (15.45, 'mob_warden_heartbeat_3', .8),
    (16.72, 'mob_breeze_wind_burst1', .35),
    (16.92, 'entity_player_attack_strong5', .85), (16.92, 'block_honeyblock_break1', .9), (16.93, 'mob_irongolem_hit1', .55), (16.95, 'damage_hit2', .5),
    (18.6, 'mob_warden_heartbeat_1', .8), (19.5, 'mob_warden_heartbeat_2', .7),
    (21.2, 'block_bell_resonate', .55), (21.25, 'mob_wither_shoot', .12),
    (25.35, 'entity_wind_charge_wind_burst1', .6), (25.42, 'entity_player_attack_sweep3', .45), (25.45, 'mob_endermen_portal2', .6),
    (26.3, 'block_deepslate_step1', .35), (26.6, 'block_deepslate_step2', .3),
    (34.5, 'step_grass3', .3), (38.9, 'mob_warden_heartbeat_3', .8), (39.8, 'mob_warden_heartbeat_1', .85), (40.7, 'mob_warden_heartbeat_2', .9),
    (42.6, 'block_chest_open', .6), (43.7, 'entity_player_attack_sweep2', .3), (44.85, 'block_end_portal_eyeplace1', .5), (44.86, 'block_bell_bell_use01', .25),
    (48.2, 'ambient_cave_cave10', .5),
]
for a, b, step in [(19.85, 21.2, .28), (46.9, 53.0, .52)]:
    t = a; i = 0
    while t < b:
        cues.append((round(t, 3), 'step_grass' + str(1 + i % 6), .26 if a < 30 else .2)); t += step; i += 1

args = ['ffmpeg', '-y', '-v', 'error']; graph = ''; labels = []; ledger = []
for i, (at, name, gain) in enumerate(cues):
    p = snd(name); args += ['-i', str(p)]; ms = round(at * 1000)
    graph += f'[{i}:a]aformat=sample_rates=48000:channel_layouts=stereo,volume={gain},adelay={ms}|{ms}[s{i}];'; labels.append(f'[s{i}]')
    ledger.append({'time': at, 'source': str(p.relative_to(ROOT)), 'gain': gain})
graph += ''.join(labels) + f'amix=inputs={len(labels)}:normalize=0,alimiter=limit=0.9,afade=t=out:st={LEN - 1.5}:d=1.5,apad=whole_dur={LEN},atrim=0:{LEN}[a]'
sfx = OUT / 'sfx.wav'
subprocess.run(args + ['-filter_complex', graph, '-map', '[a]', '-ar', '48000', '-ac', '2', str(sfx)], check=True)
# Preview mix also carries the menu theme for the first 9.5 s like the game owner does.
mix = OUT / 'mix.wav'
subprocess.run(['ffmpeg', '-y', '-v', 'error', '-i', str(AUD / 'music.ogg'), '-i', str(sfx), '-filter_complex',
                f'[0:a]atrim=0:9.5,volume=0.13,afade=t=in:d=1,afade=t=out:st=8.7:d=0.8,apad=whole_dur={LEN}[m];[m][1:a]amix=inputs=2:normalize=0,atrim=0:{LEN}[a]',
                '-map', '[a]', '-ar', '48000', '-ac', '2', str(mix)], check=True)

# Subtitle in the vanilla pixel font (same renderer as the previous prologue).
fontpath = ROOT / 'assets/fonts/minecraft/minecraft_regular.fnt'; ft = fontpath.read_text(); pages = {}; chars = {}
for line in ft.splitlines():
    if line.startswith('page '):
        pages[int(re.search(r'id=(\d+)', line)[1])] = Image.open(fontpath.parent / re.search(r'file="([^"]+)"', line)[1]).convert('RGBA')
    if line.startswith('char '):
        d = {k: int(v) for k, v in re.findall(r'(\w+)=(-?\d+)', line)}; chars[d['id']] = d
sub = Image.new('RGBA', (640, 360))
for li, text in enumerate(['Присоединишься к вечеринке', 'после рассвета?']):
    width = sum(chars[ord(c)]['xadvance'] * 2 for c in text); x = (640 - width) // 2; y = 302 + li * 21
    for c in text:
        d = chars[ord(c)]; g = pages[d['page']].crop((d['x'], d['y'], d['x'] + d['width'], d['y'] + d['height']))
        g = g.resize((g.width * 2, g.height * 2), Image.Resampling.NEAREST); al = g.getchannel('A')
        white = Image.new('RGBA', g.size, (255, 235, 235, 255)); white.putalpha(al); sh = Image.new('RGBA', g.size, (40, 0, 0, 255)); sh.putalpha(al)
        sub.alpha_composite(sh, (x + d['xoffset'] * 2 + 2, y + d['yoffset'] * 2 + 2)); sub.alpha_composite(white, (x + d['xoffset'] * 2, y + d['yoffset'] * 2)); x += d['xadvance'] * 2
sub.resize((1280, 720), Image.Resampling.NEAREST).save(OUT / 'subtitle.png')

shutil.copyfile(OUT / 'frames/0001.png', ROOT / 'assets/cinematics/ch1_intro_poster.png')
master = REC / 'chapter_one_prologue.mp4'
vf = (f"[0:v]vignette=angle=0.55,noise=alls=5:allf=t,fade=t=out:st={LEN - 1.4}:d=1.4[g];"
      f"[g][2:v]overlay=0:0:enable='between(t,21.75,25.3)'[v]")
subprocess.run(['ffmpeg', '-y', '-v', 'error', '-framerate', str(FPS), '-i', str(OUT / 'frames/%04d.png'), '-i', str(mix), '-i', str(OUT / 'subtitle.png'),
                '-filter_complex', vf, '-map', '[v]', '-map', '1:a', '-c:v', 'libx264', '-crf', '16', '-preset', 'slow', '-pix_fmt', 'yuv420p',
                '-c:a', 'aac', '-b:a', '192k', '-t', str(LEN), '-movflags', '+faststart', str(master)], check=True)
subprocess.run(['ffmpeg', '-y', '-v', 'error', '-i', str(master), '-an', '-vf', 'scale=960:540:flags=lanczos', '-c:v', 'libtheora', '-g', '1', '-q:v', '8',
                str(ROOT / 'assets/cinematics/ch1_intro.ogv')], check=True)
subprocess.run(['ffmpeg', '-y', '-v', 'error', '-i', str(sfx), '-c:a', 'libvorbis', '-q:a', '5', str(ROOT / 'assets/cinematics/ch1_intro_sfx.ogg')], check=True)
(OUT / 'sound_events.json').write_text(json.dumps(sorted(ledger, key=lambda e: e['time']), indent=2, ensure_ascii=False) + '\n')
probe = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-count_frames', '-show_streams', '-of', 'json', str(master)]))
v = next(s for s in probe['streams'] if s['codec_type'] == 'video')
assert int(v['nb_read_frames']) == FRAMES, v['nb_read_frames']
print(master, v['nb_read_frames'])
