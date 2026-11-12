"""Separate CPU process only. Contact/light proof; delivery is the Godot film."""
import bpy
from pathlib import Path
out=Path('/home/daydert/MinecraftSurvivors2/qa/ch5_cinema/blender_proof');out.mkdir(parents=True,exist_ok=True)
sc=bpy.data.scenes['CH5_chair'];bpy.context.window.scene=sc
assert all(im.packed_file for im in bpy.data.images if im.source=='FILE' and im.users), 'Unpacked source image'
sc.render.engine='CYCLES';sc.cycles.device='CPU';sc.cycles.samples=8;sc.cycles.use_denoising=True
sc.render.resolution_x=640;sc.render.resolution_y=360;sc.render.resolution_percentage=100
sc.render.threads_mode='FIXED';sc.render.threads=4
for f in [1,501,961,981,991,1045]:
 sc.frame_set(f);sc.render.filepath=str(out/f'chair_{f:04d}.png');bpy.ops.render.render(write_still=True,scene=sc.name)
print('CH5_PROOF_SAVED',out)
