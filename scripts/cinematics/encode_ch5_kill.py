"""Encode the chapter V kill film (chair 30-44 s): frames + SFX stem + subtitle -> MP4 master, Theora for Godot."""
import subprocess, json, re, shutil
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]; OUT = ROOT / 'qa/cinematics/ch5_kill_v2'; REC = ROOT / 'qa/recordings'
FPS = 24; FRAMES = 336; LEN = FRAMES / FPS
AUD = ROOT / 'assets/audio'
REC.mkdir(exist_ok=True)
assert all((OUT / 'frames' / f'{f:04d}.png').is_file() for f in range(1, FRAMES + 1)), 'Incomplete sequence'

def snd(name):
    for d in ('minecraft', 'chapter_four', 'end_ext', 'ch5_sfx', ''):
        p = AUD / d / f'{name}.ogg'
        if p.is_file(): return p
    raise FileNotFoundError(name)

# Event sheet shared with build_ch5_kill.py (shouts .65/1.7, raise 2.2, STAB 3.0, TWIST 4.2, PULL 5.45, DROP 9.6).
cues = [
    (0.05, 'entity_player_attack_sweep1', .35), (2.3, 'random_breath', .5),
    (2.25, 'entity_player_attack_sweep3', .45), (2.95, 'entity_player_attack_sweep5', .5),
    (3.0, 'entity_player_attack_strong2', .9), (3.0, 'mob_slime_big1', .8), (3.01, 'block_bone_block_break1', .85), (3.02, 'mob_zombie_woodbreak', .7), (3.05, 'entity_player_attack_knockback1', .7),
    (3.4, 'mob_warden_heartbeat_1', .9), (4.2, 'mob_slime_big1', .7), (4.21, 'block_bone_block_break2', .6), (4.6, 'mob_warden_heartbeat_2', .7),
    (5.45, 'entity_player_attack_sweep2', .6), (5.46, 'mob_slime_big1', .75), (6.3, 'random_breath', .55), (7.6, 'random_breath', .45),
    (9.6, 'block_chain_step2', .9), (9.65, 'random_glass1', .25),
]
for i, t in enumerate([.75, 1.0, 1.25, 1.75, 2.05, 2.4]):
    cues.append((t, 'block_chain_step' + str(1 + i % 3), .45))
for i, t in enumerate([10.5, 11.1, 11.7, 12.3, 12.9, 13.5]):
    cues.append((t, 'block_deepslate_step' + str(1 + i % 3), .35))

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

master = REC / 'chapter_five_kill.mp4'
vf = (f"[0:v]vignette=angle=0.55,noise=alls=5:allf=t,fade=t=out:st={LEN - 0.8}:d=0.8[g];"
      f"[g]null[v]")
subprocess.run(['ffmpeg', '-y', '-v', 'error', '-framerate', str(FPS), '-i', str(OUT / 'frames/%04d.png'), '-i', str(mix), '-i', str(OUT / 'subtitle.png'),
                '-filter_complex', vf, '-map', '[v]', '-map', '1:a', '-c:v', 'libx264', '-crf', '16', '-preset', 'slow', '-pix_fmt', 'yuv420p',
                '-c:a', 'aac', '-b:a', '192k', '-t', str(LEN), '-movflags', '+faststart', str(master)], check=True)
subprocess.run(['ffmpeg', '-y', '-v', 'error', '-i', str(master), '-an', '-vf', 'scale=960:540:flags=lanczos', '-c:v', 'libtheora', '-g', '1', '-q:v', '8',
                str(ROOT / 'assets/cinematics/ch5_kill.ogv')], check=True)
subprocess.run(['ffmpeg', '-y', '-v', 'error', '-i', str(sfx), '-c:a', 'libvorbis', '-q:a', '5', str(ROOT / 'assets/cinematics/ch5_kill_sfx.ogg')], check=True)
(OUT / 'sound_events.json').write_text(json.dumps(sorted(ledger, key=lambda e: e['time']), indent=2, ensure_ascii=False) + '\n')
probe = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-count_frames', '-show_streams', '-of', 'json', str(master)]))
v = next(s for s in probe['streams'] if s['codec_type'] == 'video')
assert int(v['nb_read_frames']) == FRAMES, v['nb_read_frames']
print(master, v['nb_read_frames'])
