"""blender --background --python this.py : writes portal_0..4 tracks of data/chapter_five_cinema.json
from ch5_portal_fight.portal(); pose dicts are already local Godot transforms (verified identical
to the Blender round-trip of build_ch5_cinema.py, max error 5e-7)."""
import sys, json
from pathlib import Path
ROOT = Path('/home/daydert/MinecraftSurvivors2'); sys.path.insert(0, str(ROOT / 'scripts/cinematics'))
import ch5_motion as M, ch5_portal_fight as F
from mathutils import Quaternion
path = ROOT / 'data/chapter_five_cinema.json'; data = json.loads(path.read_text())
for i in range(5):
    frames = []
    for f in range(round(4.4 * 30) + 1):
        pose = F.portal(i, f / 30); entry = {}
        for who in ('steve', 'notch'):
            entry[who] = {}
            for k in M.PARTS:
                d = pose[who][k]; p = d.get('p', M.REST.get(k, (0, 0, 0)))
                q = Quaternion((d['q'][3], *d['q'][:3])) if 'q' in d else M.rotation(d['r']).to_quaternion()
                entry[who][k] = [round(v, 6) for v in (*p, q.x, q.y, q.z, q.w)]
        c = pose['cam']; entry['cam'] = [*[round(v, 6) for v in c['p']], *[round(v, 6) for v in c['to']], round(c['fov'], 5)]
        frames.append(entry)
    data['tracks']['portal_%d' % i] = {'fps': 30, 'length': 4.4, 'frames': frames}
path.write_text(json.dumps(data, separators=(',', ':')))
print('CH5_PORTALS_EXPORTED')
