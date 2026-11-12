"""blender --background ch1_intro_v2.blend --python this.py -- [--frames 1,2] [--out DIR] [--scale 100] [--samples 32] [--start --end]"""
import bpy, argparse, sys, time
from pathlib import Path
p = argparse.ArgumentParser(); p.add_argument('--frames'); p.add_argument('--out'); p.add_argument('--scale', type=int, default=100)
p.add_argument('--samples', type=int, default=32); p.add_argument('--start', type=int, default=1); p.add_argument('--end', type=int, default=0)
p.add_argument('--resume', action='store_true')
a = p.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
ROOT = Path('/home/daydert/MinecraftSurvivors2')
sc = bpy.data.scenes['CH1_Prologue_v2']; bpy.context.window.scene = sc
sc.render.resolution_percentage = a.scale; sc.eevee.taa_render_samples = a.samples
out = Path(a.out) if a.out else ROOT / 'qa/cinematics/ch1_intro_v2/frames'; out.mkdir(parents=True, exist_ok=True)
frames = [int(x) for x in a.frames.split(',')] if a.frames else range(a.start, (a.end or sc.frame_end) + 1)
t0 = time.monotonic()
for f in frames:
    path = out / ('%04d.png' % f)
    if a.resume and path.is_file(): continue
    sc.frame_set(f); sc.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    print('CH1V2_FRAME', f, round(time.monotonic() - t0, 1), flush=True)
