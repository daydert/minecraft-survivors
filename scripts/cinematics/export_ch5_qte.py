"""blender --background --python this.py : writes the QTE exchange tracks and the finisher of
data/chapter_five_cinema.json from ch5_qte_fight (local Godot transforms, same contract as portals)."""
import sys, json, importlib
from pathlib import Path
ROOT = Path('/home/daydert/MinecraftSurvivors2'); sys.path.insert(0, str(ROOT / 'scripts/cinematics'))
import ch5_motion as M, ch5_qte_fight as F
from mathutils import Quaternion
path = ROOT / 'data/chapter_five_cinema.json'; data = json.loads(path.read_text())
for name, length in [('qte_' + k, 2.4) for k in ['jab', 'cross', 'hook', 'uppercut', 'slip', 'parry', 'guard', 'roll', 'miss']] + [('finisher', 3.6)]:
    fn = getattr(F, name); frames = []
    for f in range(round(length * 30) + 1):
        pose = fn(f / 30); entry = {}
        for who in ('steve', 'notch'):
            entry[who] = {}
            for k in M.PARTS:
                d = pose[who][k]; p = d.get('p', M.REST.get(k, (0, 0, 0)))
                q = Quaternion((d['q'][3], *d['q'][:3])) if 'q' in d else M.rotation(d['r']).to_quaternion()
                entry[who][k] = [round(v, 6) for v in (*p, q.x, q.y, q.z, q.w)]
        c = pose['cam']; entry['cam'] = [*[round(v, 6) for v in c['p']], *[round(v, 6) for v in c['to']], round(c['fov'], 5)]
        frames.append(entry)
    data['tracks'][name] = {'fps': 30, 'length': length, 'frames': frames}
path.write_text(json.dumps(data, separators=(',', ':')))
print('CH5_QTE_EXPORTED')
