"""2Fort's visible exterior from Valve's SDK brush geometry, not an invented arena.
Run with Blender --background --python scripts/blender_mill_yard.py.
Claude: user explicitly approved native assets for this local crossover.
Project permission is not a redistribution license; see
docs/CHAPTER_FIVE_VISUAL_SOURCES.md. Source units / 40.
The VMF, including its original texture axes, is retained compressed. Meshes
are batched by material; invisible tools and underground rooms are omitted.
"""
import gzip, math, re, sys, json
from pathlib import Path
from collections import defaultdict
import bpy
from mathutils import Vector, Matrix
sys.path.insert(0,str(Path(__file__).resolve().parent))
import blender_lib as L
from blender_lib import box,cylinder,gable,beam_between,sphere,quad,mat,group
ROOT=L.ROOT
NATIVE=ROOT/"assets/art_source/ch5_finale/tf2"
MATERIALS=json.loads((NATIVE/"materials.json").read_text()) if (NATIVE/"materials.json").exists() else {}
TEXTURE_SIZES={}

def vmf():
    tokens=iter(re.findall(r'"(?:\\.|[^"\\])*"|[{}]|[^\s{}"]+',gzip.decompress((ROOT/'assets/art_source/ch5_finale/sdk_ctf_2fort.vmf.gz').read_bytes()).decode()))
    def block():
        result=[]
        for k in tokens:
            if k=='}':break
            v=next(tokens)
            result.append((k.strip('"'),block() if v=='{' else v.strip('"')))
        return result
    return block()

def vec(s):return Vector(tuple(map(float,s.split())))
def numbers(s):return list(map(float,re.findall(r'-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?',s)))
def coord(v):return (v.x/40,-v.y/40,v.z/40) # native Blender Z-up

def faces(sides):
    planes=[]
    for s in sides:
        v=numbers(s['plane']);a,b,c=[Vector(v[i:i+3]) for i in (0,3,6)]
        n=(c-a).cross(b-a).normalized();planes.append((n,n.dot(a)))
    for k,(n,d) in enumerate(planes):
        u=n.cross(Vector((0,0,1)) if abs(n.z)<.9 else Vector((0,1,0))).normalized();v=n.cross(u)
        poly=[n*d+u*x*30000+v*y*30000 for x,y in [(-1,-1),(1,-1),(1,1),(-1,1)]]
        for j,(nn,dd) in enumerate(planes):
            if j==k:continue
            clipped=[]
            for a,b in zip(poly,poly[1:]+poly[:1]):
                da=nn.dot(a)-dd;db=nn.dot(b)-dd
                if da<=.001:clipped.append(a)
                if (da<0)!=(db<0):clipped.append(a+(b-a)*(da/(da-db)))
            poly=clipped
            if len(poly)<3:break
        if len(poly)>=3:yield sides[k],poly

def texture(name):
    n=name.lower()
    if 'tools/' in n or 'trigger' in n or 'nodraw' in n:return None
    spec=MATERIALS.get(n,{})
    native=NATIVE/'png'/(spec.get('basetexture','missing')+'.png')
    if native.exists():
        key='native_'+n.replace('/','_')
        existing=bpy.data.materials.get(key)
        if existing:return existing
        m=bpy.data.materials.new(key);m.use_nodes=True
        b=m.node_tree.nodes.get('Principled BSDF');b.inputs['Roughness'].default_value=.95
        tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(native),check_existing=True)
        m.node_tree.links.new(tex.outputs['Color'],b.inputs['Base Color'])
        if spec.get('alpha'):m.node_tree.links.new(tex.outputs['Alpha'],b.inputs['Alpha'])
        TEXTURE_SIZES[n]=tuple(spec.get('size',tex.image.size))
        return m
    if 'water' in n:return mat('water_source', 'ch5w_tf2_water',rough=.28)
    if 'glass' in n or 'window' in n:return mat('window_source','ch5w_tf2_window',rough=.7)
    if 'roof' in n or 'metal' in n or 'ibeam' in n:return mat('metal_source','ch5w_tf2_roof',rough=.92)
    if 'wood' in n:
        if 'grain_elevator_facade' in n:return mat('red_facade','ch5w_tf2_red_siding',rough=1)
        t='ch5w_tf2_red_wood' if any(x in n for x in ['003','005','006','red']) else 'ch5w_tf2_bridge'
        return mat('wood_'+t,t,rough=.98)
    if 'brick' in n:return mat('brick_source','ch5w_tf2_red_siding' if 'red' in n or '001' in n else 'ch5w_tf2_blu_concrete',rough=1)
    if 'nature' in n or 'ground' in n or 'blend' in n:return mat('earth_source','ch5w_tf2_ground',rough=1)
    return mat('concrete_source','ch5w_tf2_concrete',rough=1)

def build():
    L.reset();root=vmf();batches={};count=0
    for typ,body in root:
        if typ not in ('world','entity'):continue
        ent=dict(body)
        if typ=='entity' and ent.get('classname') not in ('func_detail','func_brush','func_illusionary'):continue
        for tag,solid in body:
            if tag!='solid':continue
            sides=[dict(x) for k,x in solid if k=='side']
            for s,p in faces(sides):
                # Keep the open-air play space and silhouettes behind both fronts.
                center=sum(p,Vector())/len(p)
                sky_part=center.x < -3300
                if not sky_part and (abs(center.x)>3000 or abs(center.y)>2300 or center.z < -260):continue
                m=texture(s['material'])
                if m is None:continue
                key=m.name
                if key not in batches:batches[key]=[m,[],[],[]]
                _,verts,polys,uvs=batches[key];start=len(verts)
                ua=numbers(s['uaxis']);va=numbers(s['vaxis']);tw,th=TEXTURE_SIZES.get(s["material"].lower(),(512.0,512.0))
                verts.extend(coord((v-Vector((-4544,256,48)))*16) if sky_part else coord(v) for v in p);polys.append(tuple(reversed(range(start,start+len(p)))))
                uvs.extend(((Vector(ua[:3]).dot(v)/ua[4]+ua[3])/tw,1-(Vector(va[:3]).dot(v)/va[4]+va[3])/th) for v in p);count+=1
    for name,(m,verts,polys,uvs) in batches.items():
        mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],polys);mesh.materials.append(m);mesh.update()
        uv=mesh.uv_layers.new()
        for p in mesh.polygons:
            for li in p.loop_indices:uv.data[li].uv=uvs[mesh.loops[li].vertex_index]
        ob=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(ob)
    # Original MDL props, prepared once with SourceIO and retained editable.
    # This includes the exact bridge canopy, silo clusters, conveyors and towers.
    with bpy.data.libraries.load(str(ROOT/'assets/art_source/ch5_finale/tf2_props.blend'),link=False) as (src,dst):
        dst.collections=list(src.collections)
    collections={c.name:c for c in dst.collections if c is not None}
    reflection=Matrix.Diagonal((1,-1,1,1))
    prop_count=0
    for typ,body in root:
        if typ!='entity':continue
        e=dict(body);model=e.get('model','').lower();col=collections.get(model)
        if col is None:continue
        p=vec(e.get('origin','0 0 0'))
        if abs(p.x)>3000 or abs(p.y)>2300 or p.z< -128:continue
        pitch,yaw,roll=[math.radians(x) for x in map(float,e.get('angles','0 0 0').split())]
        transform=Matrix.Translation(Vector(coord(p))) @ reflection @ Matrix.Rotation(yaw,4,'Z') @ Matrix.Rotation(pitch,4,'Y') @ Matrix.Rotation(roll,4,'X')
        for original in col.objects:
            if original.type!='MESH':continue
            ob=original.copy();ob.data=original.data.copy();ob.parent=None;ob.matrix_world=transform
            bpy.context.scene.collection.objects.link(ob)
            for i,m in enumerate(list(ob.data.materials)):
                full=m.get('full_path',m.name)
                replacement=texture(full)
                if replacement:ob.data.materials[i]=replacement
            prop_count+=1
    print('ORIGINAL PROPS',prop_count)
    # Source water is a shader; use a bounded surface at its original waterline.
    # Native water polygons already have the exact outline and -180 HU level.
    print('SOURCE BRUSH FACES',count,'BATCHES',len(batches))
    L.export(ROOT/'assets/models/ch5_mill_yard.glb')
if __name__=='__main__':build()
