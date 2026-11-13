"""Validate all shipped badges, source provenance, hidden story entries and glyphs."""
import hashlib
import json
import re
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
manifest = json.loads((ROOT/'docs/MINECRAFT_ACHIEVEMENTS_MANIFEST.json').read_text())
catalog = json.loads((ROOT/'data/achievements.json').read_text())
loaded = json.loads((ROOT/'data/achievement_assets.json').read_text())['sprites']
checks = 0


def check(ok, label):
    global checks
    assert ok, label
    checks += 1


check(len(catalog) == len({e['id'] for e in catalog}) == 35, '35 unique achievements')
check(set(loaded) == {'achievement_'+e['icon'] for e in catalog} | {'achievement_unknown'}, 'Every badge and the hidden icon load in the game')
font = (ROOT/'assets/fonts/minecraft/minecraft_regular.fnt').read_text()
glyphs = {int(i) for i in re.findall(r'^char id=(\d+)', font, re.M)}
for entry in catalog:
    check(bool(entry['name']) and bool(entry['description']), 'Name and condition: '+entry['id'])
    check(all(ord(c) in glyphs for c in entry['name']+entry['description']), 'Native font glyphs: '+entry['id'])
    check('achievement_'+entry['icon'] in manifest['derived'], 'Dedicated badge: '+entry['id'])
    if entry['tier'] == 'secret':check(entry.get('secret'), 'Secret tier is also hidden: '+entry['id'])
for story in ['chapter_one','chapter_two','chapter_three','chapter_four','chapter_five','herobrine','fatality','bad_ending','boss_angler','read_note','free_golem','terminal_original','break_loop','own_controls','first_compile','heart_whole']:
    check(next(e for e in catalog if e['id'] == story).get('secret'), 'Story remains hidden: '+story)
for name, spec in manifest['derived'].items():
    path = ROOT/'assets/sprites'/f'{name}.png'
    im = Image.open(path).convert('RGBA')
    check(im.size == (32, 32), name+' pixel dimensions')
    check(hashlib.sha256(path.read_bytes()).hexdigest() == spec['sha256'], name+' hash')
    check(im.getextrema()[3] == (255, 255), name+' opaque badge')
    check(len(set(im.get_flattened_data())) > 8, name+' textured art')
    edge = [(x, 0) for x in range(32)] + [(0, y) for y in range(32)] + [(31, y) for y in range(32)] + [(x, 31) for x in range(32)]
    check(all(im.getpixel(p) == (24,24,24,255) for p in edge), name+' common gray frame')
art = manifest['art']
check(hashlib.sha256((ROOT/art['source']).read_bytes()).hexdigest() == art['sha256'], 'Saved imagegen source hash')
check((ROOT/art['prompt']).is_file(), 'Generation prompt is preserved')
for path, digest in art.get('overrides', {}).items():
    check(hashlib.sha256((ROOT/path).read_bytes()).hexdigest() == digest, 'Saved targeted edit hash: '+path)
for name, spec in manifest['raw_files'].items():
    check(hashlib.sha256((ROOT/'assets/minecraft'/name).read_bytes()).hexdigest() == spec['sha256'], name+' native reference bytes')
for name, spec in manifest['sound_files'].items():
    check(hashlib.sha256((ROOT/'assets/audio/minecraft'/name).read_bytes()).hexdigest() == spec['sha256'], name+' unchanged native audio')
print('ACHIEVEMENT_ASSETS_RESULT', checks, 'checks passed')
