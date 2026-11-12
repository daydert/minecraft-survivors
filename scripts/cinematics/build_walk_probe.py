"""Execute via Blender MCP, not with --background: 2s rigid Minecraft walk."""
import bpy
import math
from mathutils import Vector
from pathlib import Path

ROOT = Path('/home/daydert/MinecraftSurvivors2')
OUT = ROOT / 'qa/cinematics'
OUT.mkdir(parents=True, exist_ok=True)
scene = bpy.context.scene
# The probe owns a separate scene; do not clear the user's existing scenes.
if 'MS_Walk_Probe' in bpy.data.scenes:
    raise RuntimeError('Probe scene already exists; inspect before replacing it')
scene = bpy.data.scenes.new('MS_Walk_Probe')
bpy.context.window.scene = scene
scene.render.fps = 24
scene.render.fps_base = 1
scene.frame_start = 1
scene.frame_end = 48
scene.render.resolution_x = 960
scene.render.resolution_y = 540
scene.render.resolution_percentage = 100
scene.render.engine = 'CYCLES'
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.cycles.device = 'CPU'
scene.render.film_transparent = False
scene.view_settings.view_transform = 'Standard'


def empty(name, location, parent=None):
    obj = bpy.data.objects.new(name, None)
    scene.collection.objects.link(obj)
    obj.parent = parent
    obj.location = location
    return obj


def material(name, texture=None, color=(1, 1, 1, 1)):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color
    mat.use_nodes = True
    shader = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    shader.inputs['Base Color'].default_value = color
    shader.inputs['Roughness'].default_value = .87
    if texture:
        image = bpy.data.images.load(str(ROOT / 'assets/minecraft/textures' / texture), check_existing=True)
        image.pack()
        tex = mat.node_tree.nodes.new('ShaderNodeTexImage')
        tex.image = image
        tex.interpolation = 'Closest'
        mat.node_tree.links.new(tex.outputs['Color'], shader.inputs['Base Color'])
    return mat


skin = material('MAT_Vanilla_Steve', 'entity/player/wide/steve.png')
stone = material('MAT_Native_Stone', 'block/stone_bricks.png')
earth = material('MAT_Native_Earth', 'block/coarse_dirt.png')
wood = material('MAT_Native_Log', 'block/dark_oak_log.png')


def box(name, center, size, mat, parent=None, skin_uv=None):
    x, y, z = (s / 2 for s in size)
    verts = [(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),
             (-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]
    faces = [(0,1,5,4),(2,3,7,6),(1,2,6,5),(3,0,4,7),(4,5,6,7),(3,2,1,0)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(mat)
    layer = mesh.uv_layers.new(name='UVMap')
    if skin_uv:
        u, v, w, h, d = skin_uv
        rects = [(u+d,v+d,w,h),(u+2*d+w,v+d,w,h),
                 (u+d+w,v+d,d,h),(u,v+d,d,h),
                 (u+d,v,w,d),(u+d+w,v,w,d)]
    else:
        rects = [(0,0,16,16)] * 6
    denom = 64 if skin_uv else 16
    for face, (u,v,w,h) in zip(mesh.polygons, rects):
        coords = [(u,v+h),(u+w,v+h),(u+w,v),(u,v)]
        for loop, (s,t) in zip(face.loop_indices, coords):
            layer.data[loop].uv = (s/denom, 1-t/denom)
    obj = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(obj)
    obj.parent = parent
    obj.location = center
    return obj


rig = empty('RIG_Steve', (0,0,0))
rig['rig_profile'] = 'Vanilla proportions; six rigid parts; no deforming weights'
rig['intent_ru'] = 'Стив спокойно и собранно идёт вперёд. Проверка походки и камеры.'
torso = empty('CTRL_Torso', (0,0,.75), rig)
box('SM_Torso', (0,0,.375), (.5,.25,.75), skin, torso, (16,16,8,12,4))
head = empty('CTRL_Head', (0,0,.75), torso)
box('SM_Head', (0,0,.25), (.5,.5,.5), skin, head, (0,0,8,8,8))
arms, legs = {}, {}
for side, sign in [('Right',-1),('Left',1)]:
    arms[side] = empty('CTRL_Arm_'+side, (sign*.375,0,.625), torso)
    uv = (40,16,4,12,4) if sign < 0 else (32,48,4,12,4)
    box('SM_Arm_'+side, (0,0,-.25), (.25,.25,.75), skin, arms[side], uv)
    legs[side] = empty('CTRL_Leg_'+side, (sign*.125,0,.75), rig)
    uv = (0,16,4,12,4) if sign < 0 else (16,48,4,12,4)
    box('SM_Leg_'+side, (0,0,-.375), (.25,.25,.75), skin, legs[side], uv)

# A small set with native 16px stone, readable sole contacts, no asset services.
box('SM_Earth_Base', (0,-.8,-.35), (7,8,.56), earth)
for x in range(-3,4):
    for y in range(-4,4):
        box('SM_Paving_%d_%d' % (x,y), (x,y, -.035), (.995,.995,.07), stone)
for x,y,h in [(-2.6,2.6,2.4),(2.7,2.8,3.1),(-3.1,.6,1.7)]:
    box('SM_Bare_Trunk', (x,y,h/2), (.42,.42,h), wood)

world = bpy.data.worlds.new('WORLD_Dusk')
scene.world = world
world.use_nodes = True
bg = next(n for n in world.node_tree.nodes if n.type == 'BACKGROUND')
bg.inputs['Color'].default_value = (.055,.085,.13,1)
bg.inputs['Strength'].default_value = .5


def light(name, kind, location, energy, color, size):
    data = bpy.data.lights.new(name, kind)
    data.energy = energy
    data.color = color
    if kind == 'AREA':
        data.shape = 'DISK'
        data.size = size
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (Vector((0,-.8,1))-obj.location).to_track_quat('-Z','Y').to_euler()
    return obj


light('LGT_Key_Sunset', 'AREA', (-3,-4,6), 550, (1,.77,.53), 4)
light('LGT_Fill_Sky', 'AREA', (3,-2,4), 280, (.5,.7,1), 5)
light('LGT_Rim_LastSun', 'AREA', (-1,3,4), 650, (1,.56,.28), 3)
target = empty('EMPTY_CamTarget_Walk', (0,0,1))
data = bpy.data.cameras.new('CAM_Walk_PushIn')
cam = bpy.data.objects.new(data.name, data)
scene.collection.objects.link(cam)
cam.data.lens = 38
cam.data.sensor_width = 36
cam.data.clip_start = .05
cam.data.clip_end = 200
track = cam.constraints.new('TRACK_TO')
track.target = target
track.track_axis = 'TRACK_NEGATIVE_Z'
track.up_axis = 'UP_Y'
scene.camera = cam
for frame, position in [(1,(3.4,-6.7,2.9)),(49,(2.4,-6.1,2.5))]:
    cam.location = position
    cam.keyframe_insert('location', frame=frame)

# Support foot rolls from heel to toe as a rigid box. Stance travel is derived
# from the contacting edge rather than an unrelated sliding root curve.
a, length, halfdepth = .30, .75, .125
stride = 2*(length*math.sin(a)+halfdepth*(1-math.cos(a)))
for frame in range(1,50):
    halfstep = (frame-1)/12
    k = min(int(halfstep),3)
    p = halfstep-k
    theta = -a+2*a*p
    swing = a*math.cos(math.pi*p)
    sy = -1 if theta >= 0 else 1
    y = -stride/2-k*stride-length*math.sin(theta)+sy*halfdepth*(1-math.cos(theta))
    height = max(length*math.cos(q)+halfdepth*abs(math.sin(q)) for q in (theta,swing))
    rig.location = (0,y,height-.75+.002)
    rig.keyframe_insert('location', frame=frame)
    right = theta if k%2 == 0 else swing
    left = swing if k%2 == 0 else theta
    for side, angle in [('Right',right),('Left',left)]:
        legs[side].rotation_euler.x = angle
        legs[side].keyframe_insert('rotation_euler', frame=frame)
        arms[side].rotation_euler.x = -angle*.78
        arms[side].keyframe_insert('rotation_euler', frame=frame)
    torso.rotation_euler.z = .025*math.sin((frame-1)*math.tau/24)
    torso.keyframe_insert('rotation_euler', frame=frame)
    head.rotation_euler.z = .055*math.sin((frame-1)*math.pi/48)
    head.keyframe_insert('rotation_euler', frame=frame)
    target.location = (0,y,1.0)
    target.keyframe_insert('location', frame=frame)

for obj in (rig,torso,head,*arms.values(),*legs.values(),target,cam):
    action = obj.animation_data.action
    action.name = 'AN_Steve_Walk_'+obj.name
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    for key in fc.keyframe_points:
                        key.interpolation = 'BEZIER' if obj == cam else 'LINEAR'
                        key.handle_left_type = key.handle_right_type = 'AUTO_CLAMPED'

for frame in [1,13,25,37]:
    scene.timeline_markers.new('Contact_%02d' % frame, frame=frame)
scene['delivery'] = '48 frames / 24 fps = 2.000s; headless final render only'
scene['sources'] = 'Local Minecraft Java 1.21.11 textures; no downloaded rigs/assets'
scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT')
for area in bpy.context.screen.areas:
    if area.type == 'VIEW_3D':
        area.spaces.active.region_3d.view_perspective = 'CAMERA'
        area.spaces.active.overlay.show_overlays = False
        area.spaces.active.shading.type = 'MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'minecraft_walk.blend'))
print('PROBE_CREATED', len(scene.objects), scene.frame_start, scene.frame_end, scene.render.fps)
