"""Reopen packed source, audit evaluated contacts, render CPU proof separately.
Final delivery is the Godot Compatibility recording, not these Blender stills.
"""
import bpy,json,math
from pathlib import Path
from mathutils import Vector
ROOT=Path('/home/daydert/MinecraftSurvivors2');out=ROOT/'qa/ch5_scene_repairs/blender_proof';out.mkdir(parents=True,exist_ok=True)
tracks=json.loads((ROOT/'data/chapter_five_cinema.json').read_text())['tracks']
assert 'MS_Walk_Probe' in bpy.data.scenes
assert all(im.packed_file for im in bpy.data.images if im.source=='FILE' and im.users)
for kind,spec in tracks.items():
 sc=bpy.data.scenes['CH5_'+kind]
 assert sc.frame_end-sc.frame_start+1==len(spec['frames']) and sc.render.fps==30
# Contact checks use evaluated Blender objects from the saved/reopened file.
sc=bpy.data.scenes['CH5_bad_end'];bpy.context.window.scene=sc;sc.frame_set(154)
can=next(ob for ob in sc.objects if ob.name.startswith('Beer_can') and ob.type=='EMPTY')
can_at=can.matrix_world.to_translation();pickup_error=(can_at-Vector((.9,1.85,1.1))).length
assert pickup_error<.015,pickup_error
sc.frame_set(208)
head=next(ob for ob in sc.objects if ob.name.startswith('notch_head') and ob.type=='EMPTY')
mouth=head.matrix_world@Vector((0,-.275,.18));rim=can.matrix_world@Vector((0,0,.174));mouth_error=(rim-mouth).length
assert mouth_error<.025,mouth_error
report={'reopened_blend':str(ROOT/'assets/art_source/ch5_finale/ch5_cinema.blend'),'tracks':len(tracks),'packed_textures':True,'probe_preserved':True,'pickup_error_m':pickup_error,'mouth_error_m':mouth_error,'renders':[]}
for scene,frames in [('CH5_bad_qte',[1,125,168]),('CH5_bad_end',[154,208,410,480])]:
 sc=bpy.data.scenes[scene];bpy.context.window.scene=sc
 sc.render.engine='CYCLES';sc.cycles.device='CPU';sc.cycles.samples=4;sc.cycles.use_denoising=True
 sc.render.resolution_x=640;sc.render.resolution_y=360;sc.render.resolution_percentage=100;sc.render.threads_mode='FIXED';sc.render.threads=4
 for f in frames:
  sc.frame_set(f);path=out/f'{scene}_{f:04d}.png';sc.render.filepath=str(path);bpy.ops.render.render(write_still=True,scene=sc.name);report['renders'].append(str(path.relative_to(ROOT)))
(out/'audit.json').write_text(json.dumps(report,indent=2)+'\n');print('SCENE_REPAIRS_BLENDER_PROOF',report)
