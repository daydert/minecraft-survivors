"""Encode the chapter V bad ending film: frames + SFX stem + subtitle -> MP4 master, Theora for Godot."""
import subprocess, json, re, shutil
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]; OUT = ROOT / 'qa/cinematics/ch5_bad_v2'; REC = ROOT / 'qa/recordings'
FPS = 24; FRAMES = 792; LEN = FRAMES / FPS
AUD = ROOT / 'assets/audio'
REC.mkdir(exist_ok=True)
assert all((OUT / 'frames' / f'{f:04d}.png').is_file() for f in range(1, FRAMES + 1)), 'Incomplete sequence'

def snd(name):
    for d in ('minecraft', 'chapter_four', 'end_ext', 'ch5_sfx', ''):
        p = AUD / d / f'{name}.ogg'
        if p.is_file(): return p
    raise FileNotFoundError(name)

# Event sheet shared with build_ch5_bad_end.py (v3: RUN0 2.7, CATCH 4.05, BREAK 4.75, KNEE 5.05, SLAM 5.75, line 6.4-10.2,
# SNAP 9.9, erase 10.05-13.4, rise 13.8, fridge 19.5/20.1/20.8, pop 21.75, drink 22.1-24.1, door 28.85/31.5).
cues = [
    (0.0, 'random_breath', .55), (.9, 'random_breath', .5), (1.9, 'random_breath', .6),
    (2.45, 'entity_player_attack_sweep1', .3), (2.9, 'block_deepslate_step1', .45), (3.2, 'block_deepslate_step2', .45), (3.48, 'block_deepslate_step3', .5),
    (3.55, 'entity_player_attack_sweep2', .55), (3.9, 'entity_player_attack_sweep5', .7),
    (4.05, 'entity_player_attack_strong2', .9), (4.06, 'block_iron_door_close1', .55), (4.08, 'mob_slime_big1', .45),
    (4.75, 'random_glass1', .75), (4.76, 'random_break', .55),
    (5.05, 'entity_player_attack_knockback1', .9), (5.06, 'damage_fallbig', .35), (5.3, 'entity_player_attack_sweep4', .35),
    (5.75, 'mob_zombie_woodbreak', .95), (5.76, 'block_bone_block_break1', .8), (5.77, 'mob_slime_big1', .6), (5.8, 'entity_player_attack_knockback1', .6),
    (6.1, 'random_breath', .35),
    (9.9, 'random_click', .9), (10.05, 'mob_guardian_curse', .6), (10.9, 'mob_guardian_curse', .45), (11.8, 'mob_guardian_curse', .4), (12.5, 'random_glass1', .4),
    (13.35, 'mob_guardian_curse', .55),
    (13.9, 'random_breath', .55), (14.7, 'random_breath', .6), (15.45, 'mob_slime_big1', .22),
    (19.5, 'block_chest_open', .55), (20.1, 'random_glass2', .25), (20.8, 'block_iron_door_close1', .3),
    (21.75, 'random_pop', .8), (22.25, 'random_drink', .8), (22.85, 'random_drink', .75), (23.45, 'random_drink', .7), (24.4, 'random_breath', .7),
    (28.85, 'block_iron_door_open1', .8), (31.5, 'block_iron_door_close1', 1.0),
]
# limping steps: the hurt right foot lands softer
for k, t in enumerate([16.25, 16.95, 17.5, 18.2, 18.75, 19.25, 25.2, 25.9, 26.45, 27.15, 27.7, 28.3, 29.4, 30.1, 30.7]):
    cues.append((t, 'block_deepslate_step' + str(1 + k % 3), .42 if k % 2 else .25))

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
vf = (f"[0:v]vignette=angle=0.55,noise=alls=5:allf=t,fade=t=in:d=0.8,fade=t=out:st={LEN - 1.3}:d=1.3[g];"
      f"[g][2:v]overlay=0:0:enable='between(t,6.4,10.2)'[v]")
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
