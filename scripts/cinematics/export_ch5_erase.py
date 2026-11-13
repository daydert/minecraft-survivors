"""blender --background --python this.py : writes the erase_throw track (v2) into data/chapter_five_cinema.json."""
import sys, json
from pathlib import Path
ROOT = Path('/home/daydert/MinecraftSurvivors2'); sys.path.insert(0, str(ROOT / 'scripts/cinematics'))
import ch5_motion as M, ch5_erase_throw as E
from mathutils import Quaternion
path = ROOT / 'data/chapter_five_cinema.json'; data = json.loads(path.read_text())
frames = []
for f in range(round(E.LENGTH * 30) + 1):
    pose = E.erase_throw(f / 30); entry = {}
    for who in ('steve', 'notch'):
        entry[who] = {}
        for k in M.PARTS:
            d = pose[who][k]; p = d.get('p', M.REST.get(k, (0, 0, 0)))
            q = Quaternion((d['q'][3], *d['q'][:3])) if 'q' in d else M.rotation(d['r']).to_quaternion()
            entry[who][k] = [round(v, 6) for v in (*p, q.x, q.y, q.z, q.w)]
    c = pose['cam']; entry['cam'] = [*[round(v, 6) for v in c['p']], *[round(v, 6) for v in c['to']], round(c['fov'], 5)]
    frames.append(entry)
data['tracks']['erase_throw'] = {'fps': 30, 'length': E.LENGTH, 'frames': frames}
path.write_text(json.dumps(data, separators=(',', ':')))
print('CH5_ERASE_EXPORTED', len(frames))
