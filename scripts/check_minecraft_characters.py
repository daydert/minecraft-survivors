"""Verify the new vanilla sources and their complete runtime atlas coverage."""
import hashlib
import json
from pathlib import Path

from PIL import Image
import numpy as np

from bake_minecraft_characters import SOURCES, actor_frame

ROOT=Path(__file__).resolve().parent.parent
manifest=json.loads((ROOT/'docs/MINECRAFT_CHARACTER_MANIFEST.json').read_text())
actors=json.loads((ROOT/'data/animations.json').read_text())['actors']
checks=0
for name,entry in manifest['raw_files'].items():
    p=ROOT/'assets/minecraft'/name
    assert hashlib.sha256(p.read_bytes()).hexdigest()==entry['sha256'],name
    checks+=1
for name,entry in manifest['derived'].items():
    p=ROOT/'assets/sprites'/(name+'.png')
    assert hashlib.sha256(p.read_bytes()).hexdigest()==entry['sha256'],name
    checks+=1
for name,spec in actors.items():
    assert 'generated_anchor' not in spec and 'source_texture' in spec,name
    assert (ROOT/spec['source_texture']).exists(),name
    assert (ROOT/f'assets/sprites/{name}_atlas.png').exists(),name
    checks+=3
    atlas=Image.open(ROOT/f'assets/sprites/{name}_atlas.png').convert('RGBA')
    w,h=spec['frame_size']
    for row in range(3):
        # All six states and all directions retain visible model pixels.
        for state,clip in spec['states'].items():
            for f in range(len(clip['durations'])):
                im=atlas.crop(((clip['start']+f)*w,row*h,(clip['start']+f+1)*w,(row+1)*h))
                assert im.getbbox(),(name,row,state,f)
                checks+=1
    # Front and back use actual different faces of the same model.
    assert atlas.crop((0,0,w,h)).tobytes()!=atlas.crop((0,h,w,2*h)).tobytes() or name=='slime',name
    checks+=1
# Real face pixels, independently of the camera constants: mark each model's
# front-head UVs in a diagnostic skin and verify the baked face points right.
# The diagnostic textures never replace or ship as the game's skins.
class FacingProbe:
    def __init__(self,name):self.name=name
    def tex(self,source):
        im=Image.open(ROOT/'assets/minecraft/textures'/(source+'.png')).convert('RGBA')
        alpha=im.getchannel('A')
        im.paste((70,70,70,255),(0,0,*im.size))
        from PIL import ImageDraw
        uv=(40,12,48,20) if self.name=='spider' else (16,16,32,36) if self.name=='ravager' else (8,8,16,18) if self.name=='vindicator' else (8,8,16,16)
        if source in [SOURCES[self.name],'entity/equipment/humanoid/iron']:
            ImageDraw.Draw(im).rectangle((uv[0],uv[1],uv[2]-1,uv[3]-1),fill=(255,0,255,255))
        im.putalpha(alpha)
        return im

for name in SOURCES:
    a=np.asarray(actor_frame(FacingProbe(name),name,'walk',1,8,'side'))
    marker=(a[:,:,0]>90)&(a[:,:,1]<20)&(a[:,:,2]>90)&(a[:,:,3]>0)
    ys,xs=np.where(marker)
    assert len(xs)>0 and xs.mean()>a.shape[1]/2,(name,'Side sprite must face screen right',xs.tolist())
    checks+=1

# Both the white sclera and the original purple pupil must remain present in
# every front/side Steve frame, including attack and hurt, not just idle.
spec=actors['steve'];w,h=spec['frame_size']
atlas=Image.open(ROOT/'assets/sprites/steve_atlas.png').convert('RGBA')
for row in [0,2]:
    for state,clip in spec['states'].items():
        for f in range(len(clip['durations'])):
            x=(clip['start']+f)*w
            a=np.asarray(atlas.crop((x,row*h,x+w,row*h+14)))
            rgb=a[:,:,:3].astype(float);alpha=a[:,:,3]>0
            white=alpha&(rgb.min(axis=2)>160)
            pupil=alpha&(rgb[:,:,2]>rgb[:,:,0]*1.15)&(rgb[:,:,2]>rgb[:,:,1]*1.4)
            assert white.any() and pupil.any(),('Steve eyes disappeared',row,state,f)
            checks+=1
assert len(manifest['throne']['fire_sockets'])==2
checks+=1
throne=Image.open(ROOT/'assets/sprites/herobrine_throne.png').convert('RGBA')
shirt=throne.crop((72,94,120,128))
pixels=shirt.load()
cyan=sum(1 for y in range(shirt.height) for x in range(shirt.width)
         if (lambda c:c[3]>0 and c[1]>70 and c[2]>70 and c[1]>c[0]*1.8 and c[2]>c[0]*1.8)(pixels[x,y]))
assert cyan>=180,('Herobrine torso is hidden or incorrectly positioned',cyan)
checks+=1
for variant in range(3):
    stem=Image.open(ROOT/f'assets/sprites/tree_dead_{variant}.png').convert('RGBA')
    bounds=stem.getbbox()
    assert bounds and bounds[2]-bounds[0]<=14 and bounds[3]-bounds[1]>35,('Herobrine trees must be bare vertical trunks without branches',variant,bounds)
    checks+=1
result={'checks':checks,'failures':[],'actors':list(actors),'minecraft_version':manifest['version']}
(ROOT/'qa/character_asset_results.json').write_text(json.dumps(result,indent=2)+'\n')
print(f'CHARACTER_ASSETS_RESULT {checks} checks passed; {len(actors)} vanilla-textured actors')
