"""Encode the chapter V bad ending film: frames + SFX stem + subtitle -> MP4 master, Theora for Godot."""
import subprocess, json, re, shutil
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]; OUT = ROOT / 'qa/cinematics/ch5_bad_v2'; REC = ROOT / 'qa/recordings'
FPS = 24; FRAMES = 348; LEN = FRAMES / FPS
AUD = ROOT / 'assets/audio'
REC.mkdir(exist_ok=True)
assert all((OUT / 'frames' / f'{f:04d}.png').is_file() for f in range(1, FRAMES + 1)), 'Incomplete sequence'

def snd(name):
    for d in ('minecraft', 'chapter_four', 'end_ext', 'ch5_sfx', ''):
        p = AUD / d / f'{name}.ogg'
        if p.is_file(): return p
    raise FileNotFoundError(name)

# Event sheet shared with build_ch5_bad_end.py (CATCH 1.55, BREAK 1.95, KNEE 2.2, SLAM 2.85, SNAP 5.45, erase 5.6-8.6, door 11.35/13.1).
cues = [
    (0.0, 'random_breath', .55), (.9, 'random_breath', .5),
    (1.05, 'entity_player_attack_sweep2', .5), (1.2, 'block_deepslate_step1', .35), (1.4, 'block_deepslate_step2', .35),
    (1.55, 'block_iron_door_close1', .5), (1.56, 'entity_player_attack_strong2', .6),
    (1.95, 'random_glass1', .7), (1.96, 'random_break', .5), (2.0, 'mob_slime_big1', .3),
    (2.2, 'entity_player_attack_knockback1', .9), (2.21, 'damage_fallbig', .35),
    (2.4, 'entity_player_attack_sweep4', .35),
    (2.85, 'mob_zombie_woodbreak', .95), (2.86, 'block_bone_block_break1', .8), (2.87, 'mob_slime_big1', .6), (2.9, 'entity_player_attack_knockback1', .6),
    (3.2, 'random_breath', .35),
    (5.45, 'random_click', .9), (5.6, 'mob_guardian_curse', .6), (6.4, 'mob_guardian_curse', .45), (7.3, 'mob_guardian_curse', .4), (8.0, 'random_glass1', .4),
    (8.55, 'mob_guardian_curse', .55),
    (9.4, 'mob_slime_big1', .25),
    (11.35, 'block_iron_door_open1', .8), (13.1, 'block_iron_door_close1', 1.0),
]
for i, t in enumerate([9.75, 10.3, 10.85]):
    cues.append((t, 'block_deepslate_step' + str(1 + i % 3), .4))

args = ['ffmpeg', '-y', '-v', 'error']; graph = ''; labels = []; ledger = []
for i, (at, name, gain) in enumerate(cues):
    p = snd(name); args += ['-i', str(p)]; ms = round(at * 1000)
    graph += f'[{i}:a]aformat=sample_rates=48000:channel_layouts=stereo,volume={gain},adelay={ms}|{ms}[s{i}];'; labels.append(f'[s{i}]')
    ledger.append({'time': at, 'source': str(p.relative_to(ROOT)), 'gain': gain})
graph += ''.join(labels) + f'amix=inputs={len(labels)}:normalize=0,alimiter=limit=0.9,afade=t=out:st={LEN - 1.5}:d=1.5,apad=whole_dur={LEN},atrim=0:{LEN}[a]'
sfx = OUT / 'sfx.wav'
subprocess.run(args + ['-filter_complex', graph, '-map', '[a]', '-ar', '48000', '-ac', '2', str(sfx)], check=True)
mix = sfx

# Subtitle in the vanilla pixel font (same renderer as the previous prologue).
fontpath = ROOT / 'assets/fonts/minecraft/minecraft_regular.fnt'; ft = fontpath.read_text(); pages = {}; chars = {}
for line in ft.splitlines():
    if line.startswith('page '):
        pages[int(re.search(r'id=(\d+)', line)[1])] = Image.open(fontpath.parent / re.search(r'file="([^"]+)"', line)[1]).convert('RGBA')
    if line.startswith('char '):
        d = {k: int(v) for k, v in re.findall(r'(\w+)=(-?\d+)', line)}; chars[d['id']] = d
sub = Image.new('RGBA', (640, 360))
for li, text in enumerate(['Пора бы завязать', 'с тестированием']):
    width = sum(chars[ord(c)]['xadvance'] * 2 for c in text); x = (640 - width) // 2; y = 302 + li * 21
    for c in text:
        d = chars[ord(c)]; g = pages[d['page']].crop((d['x'], d['y'], d['x'] + d['width'], d['y'] + d['height']))
        g = g.resize((g.width * 2, g.height * 2), Image.Resampling.NEAREST); al = g.getchannel('A')
        white = Image.new('RGBA', g.size, (255, 235, 235, 255)); white.putalpha(al); sh = Image.new('RGBA', g.size, (40, 0, 0, 255)); sh.putalpha(al)
        sub.alpha_composite(sh, (x + d['xoffset'] * 2 + 2, y + d['yoffset'] * 2 + 2)); sub.alpha_composite(white, (x + d['xoffset'] * 2, y + d['yoffset'] * 2)); x += d['xadvance'] * 2
sub.resize((1280, 720), Image.Resampling.NEAREST).save(OUT / 'subtitle.png')

master = REC / 'chapter_five_bad_end.mp4'
vf = (f"[0:v]vignette=angle=0.55,noise=alls=5:allf=t,fade=t=in:d=0.3,fade=t=out:st={LEN - 1.3}:d=1.3[g];"
      f"[g][2:v]overlay=0:0:enable='between(t,3.4,6.6)'[v]")
subprocess.run(['ffmpeg', '-y', '-v', 'error', '-framerate', str(FPS), '-i', str(OUT / 'frames/%04d.png'), '-i', str(mix), '-i', str(OUT / 'subtitle.png'),
                '-filter_complex', vf, '-map', '[v]', '-map', '1:a', '-c:v', 'libx264', '-crf', '16', '-preset', 'slow', '-pix_fmt', 'yuv420p',
                '-c:a', 'aac', '-b:a', '192k', '-t', str(LEN), '-movflags', '+faststart', str(master)], check=True)
subprocess.run(['ffmpeg', '-y', '-v', 'error', '-i', str(master), '-an', '-vf', 'scale=960:540:flags=lanczos', '-c:v', 'libtheora', '-g', '1', '-q:v', '8',
                str(ROOT / 'assets/cinematics/ch5_bad_end.ogv')], check=True)
subprocess.run(['ffmpeg', '-y', '-v', 'error', '-i', str(sfx), '-c:a', 'libvorbis', '-q:a', '5', str(ROOT / 'assets/cinematics/ch5_bad_end_sfx.ogg')], check=True)
(OUT / 'sound_events.json').write_text(json.dumps(sorted(ledger, key=lambda e: e['time']), indent=2, ensure_ascii=False) + '\n')
probe = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-count_frames', '-show_streams', '-of', 'json', str(master)]))
v = next(s for s in probe['streams'] if s['codec_type'] == 'video')
assert int(v['nb_read_frames']) == FRAMES, v['nb_read_frames']
print(master, v['nb_read_frames'])
