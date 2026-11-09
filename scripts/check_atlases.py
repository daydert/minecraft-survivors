"""Check the baked resources used by the renderer, including limb-pose changes."""
from pathlib import Path
from PIL import Image
import json

ROOT=Path(__file__).resolve().parent.parent
data=json.loads((ROOT/'data/animations.json').read_text())
checks=0
for name,spec in data['actors'].items():
    atlas=Image.open(ROOT/f'assets/sprites/{name}_atlas.png').convert('RGBA')
    w,h=spec['frame_size']
    assert atlas.size==(w*spec['columns'],h*3),name
    if spec.get('alpha_mode')!='translucent':
        assert set(atlas.getchannel('A').tobytes()) <= {0,255},name+' alpha'
    else:
        assert any(0<a<255 for a in atlas.getchannel('A').tobytes()),name+' translucent shell'
    checks+=2
    for row in range(3):
        clip=spec['states']['walk']; frames=[]
        for f in range(len(clip['durations'])):
            x=(clip['start']+f)*w
            tile=atlas.crop((x,row*h,x+w,(row+1)*h))
            assert tile.getbbox(),(name,row,f)
            frames.append(tile.tobytes())
            if name in ['steve','zombie','elite','skeleton','creeper']:
                assert h-6<=tile.getbbox()[3]<=h,(name,'ground-space bounds',f)
        if name not in ['slime','ravager']:
            assert len(set(frames))>=5,(name,'insufficient distinct poses',len(set(frames)))
        # Every meaningful action has a silhouette distinct from the idle pose.
        for state in ['windup','attack','recover','hurt']:
            if name=='spider' and state!='hurt': continue
            start=spec['states'][state]['start']*w
            action=atlas.crop((start,row*h,start+w,(row+1)*h)).tobytes()
            idle=atlas.crop((0,row*h,w,(row+1)*h)).tobytes()
            if name not in ['creeper','ravager']: assert action!=idle,(name,state,row)
        checks+=1
print(f'ATLAS_RESULT {checks} resource/direction checks passed')
(ROOT/'qa/atlas_results.json').write_text(json.dumps({'checks':checks,'failures':[]},indent=2)+'\n')
