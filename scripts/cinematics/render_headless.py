"""Run with Blender --background source.blend --python this.py -- --output DIR."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import bpy

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', required=True, type=Path)
parser.add_argument('--frames', help='Optional comma separated diagnostic still frames')
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:])
scene = bpy.data.scenes['MS_Walk_Probe']
bpy.context.window.scene = scene
out = args.output.resolve()
frames_dir = out/'frames'
frames_dir.mkdir(parents=True, exist_ok=True)
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGB'
scene.render.resolution_percentage = 100
scene.render.use_file_extension = True
if args.frames:
    for frame in map(int,args.frames.split(',')):
        scene.frame_set(frame)
        scene.render.filepath = str(out/f'render_{frame:04d}.png')
        bpy.ops.render.render(write_still=True, scene=scene.name)
else:
    scene.render.filepath = str(frames_dir/'frame_')
    bpy.ops.render.render(animation=True, scene=scene.name)
    expected = [frames_dir/f'frame_{f:04d}.png' for f in range(scene.frame_start,scene.frame_end+1)]
    if not all(p.is_file() and p.stat().st_size for p in expected):
        raise RuntimeError('Incomplete frame sequence; do not encode a partial delivery')
    movie = out/'minecraft_walk.mp4'
    fps = scene.render.fps/scene.render.fps_base
    subprocess.run(['ffmpeg','-y','-v','error','-framerate',str(fps),'-start_number',str(scene.frame_start),
                    '-i',str(frames_dir/'frame_%04d.png'),'-frames:v',str(len(expected)),
                    '-c:v','libx264','-crf','18','-preset','medium','-pix_fmt','yuv420p',
                    '-movflags','+faststart',str(movie)],check=True)
    probe = subprocess.check_output(['ffprobe','-v','error','-count_frames','-select_streams','v:0',
                                    '-show_entries','stream=codec_name,width,height,r_frame_rate,nb_read_frames,duration',
                                    '-of','json',str(movie)],text=True)
    info = json.loads(probe)
    stream = info['streams'][0]
    assert int(stream['nb_read_frames']) == len(expected), stream
    assert abs(float(stream['duration'])-len(expected)/fps) < .001, stream
    (out/'video_verification.json').write_text(json.dumps(info,indent=2)+'\n')
    print('VERIFIED_MP4',movie,probe)
