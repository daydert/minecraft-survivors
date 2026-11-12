"""Execute through MCP to sample actual evaluated geometry and camera framing."""
import bpy
import json
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

scene = bpy.data.scenes['MS_Walk_Probe']
current = scene.frame_current
meshes = [o for o in scene.objects if o.name.startswith('SM_') and
          any(o.name.startswith('SM_'+part) for part in ('Head','Torso','Arm_','Leg_'))]
rows = []
for frame in range(1,49):
    scene.frame_set(frame)
    points = [o.matrix_world @ Vector(v) for o in meshes for v in o.bound_box]
    uv = [world_to_camera_view(scene,scene.camera,p) for p in points]
    feet = {}
    for side in ('Right','Left'):
        obj = scene.objects['SM_Leg_'+side]
        feet[side] = min((obj.matrix_world @ Vector(v)).z for v in obj.bound_box)
    rows.append({'frame':frame,'feet_min_z':feet,
                 'screen_bounds':[min(p.x for p in uv),min(p.y for p in uv),
                                  max(p.x for p in uv),max(p.y for p in uv)],
                 'camera_distance':(scene.camera.matrix_world.translation-
                                    scene.objects['EMPTY_CamTarget_Walk'].matrix_world.translation).length})
assert all(min(r['feet_min_z'].values()) >= -.0001 for r in rows), 'Floor penetration'
assert all(all(.025 < v < .975 for v in r['screen_bounds']) for r in rows), 'Cropped silhouette'
assert rows[-1]['camera_distance'] < rows[0]['camera_distance'], 'No dolly approach'
assert scene.frame_end-scene.frame_start+1 == 48 and scene.render.fps == 24
assert all(o.parent for o in meshes), 'Detached mesh'
report = {'status':'pass','scope':'48 evaluated poses: floor clearance, full body framing, hierarchy, camera approach and duration',
          'samples':rows,'packed_textures':[{ 'name':i.name,'packed':bool(i.packed_file)}
                                          for i in bpy.data.images if i.source == 'FILE']}
Path('/home/daydert/MinecraftSurvivors2/qa/cinematics/motion_verification.json').write_text(json.dumps(report,indent=2)+'\n')
scene.frame_set(current)
print('CHECKS_PASSED', len(rows), 'poses;', 'camera distance', rows[0]['camera_distance'], 'to', rows[-1]['camera_distance'])
