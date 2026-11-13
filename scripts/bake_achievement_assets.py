"""Package the saved imagegen achievement atlas on the game's 32px pixel grid.

Generation is never repeated by a build. The reviewed source, cell order and
prompt are checked in. Native Minecraft audio and its provenance are retained.
"""
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'assets/art_source/achievements_v2'
ATLAS = SOURCE / 'atlas.png'
# Fixed source coordinates: catalog reordering must never swap the badge art.
ORDER = [
    'chapter_one', 'first_evolution', 'full_inventory', 'sword_only', 'two_weapons', 'no_evolutions',
    'chapter_two', 'chapter_three', 'bow_only', 'untouched', 'no_healing', 'herobrine',
    'blood_moon', 'end_city', 'witch_hunter', 'phantom_slayer', 'bastion', 'windswept',
    'fatality', 'bad_ending', 'trailblazer', 'boss_angler', 'void_bouncer', 'shell_rescue',
    'read_note', 'free_golem', 'cart_rider', 'healing_undead', 'chapter_four', 'terminal_original',
    'break_loop', 'own_controls', 'first_compile', 'heart_whole', 'chapter_five', 'unknown',
]
ORIGIN = 'Imagegen atlas, guided by local vanilla Minecraft icons; nearest 32px export and a shared gray pixel frame.'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def render_badge(name, sheet=None):
    sheet = sheet if sheet is not None else Image.open(ATLAS).convert('RGBA')
    assert sheet.width % 6 == 0 and sheet.height % 6 == 0
    index = ORDER.index(name)
    x, y = index % 6, index // 6
    w, h = sheet.width // 6, sheet.height // 6
    override = SOURCE / (name+'.png')
    cell = Image.open(override).convert('RGBA') if override.is_file() else sheet.crop((x*w, y*h, (x+1)*w, (y+1)*h))
    image = cell.resize((32, 32), Image.Resampling.NEAREST)
    # One UI frame for all cells, including the hidden badge.
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 0, 31, 31), outline=(24, 24, 24, 255))
    draw.rectangle((1, 1, 30, 30), outline=(117, 117, 117, 255))
    draw.line((2, 2, 29, 2), fill=(176, 176, 176, 255))
    draw.line((2, 29, 29, 29), fill=(57, 57, 57, 255))
    return image


def generate():
    catalog = json.loads((ROOT / 'data/achievements.json').read_text())
    assert {e['icon'] for e in catalog} | {'unknown'} == set(ORDER)
    legacy = json.loads((SOURCE / 'legacy_manifest.json').read_text())
    sheet = Image.open(ATLAS).convert('RGBA')
    derived = {}
    preview = Image.new('RGBA', (6*32, 6*32), (24, 24, 24, 255))
    for i, name in enumerate(ORDER):
        image = render_badge(name, sheet)
        target = ROOT / f'assets/sprites/achievement_{name}.png'
        image.save(target)
        derived['achievement_'+name] = {
            'sources': [str((SOURCE / (name+'.png') if (SOURCE / (name+'.png')).is_file() else ATLAS).relative_to(ROOT))], 'size': [32, 32],
            'sha256': sha(target), 'cell': [i % 6, i // 6], 'origin': ORIGIN,
        }
        preview.alpha_composite(image, (i % 6 * 32, i // 6 * 32))
    (ROOT / 'data/achievement_assets.json').write_text(json.dumps({'sprites': list(derived)}, indent=2)+'\n')
    manifest = {
        'version': legacy['version'], 'raw_files': legacy['raw_files'],
        'derived': derived, 'sound_files': legacy['sound_files'], 'font': legacy['font'],
        'art': {
            'tool': 'image_gen.imagegen', 'model': 'Not exposed by the built-in tool',
            'requested_model': 'ChatGPT Image 2.5', 'source': str(ATLAS.relative_to(ROOT)),
            'sha256': sha(ATLAS), 'grid': [6, 6], 'cell_order': ORDER,
            'prompt': 'docs/ACHIEVEMENT_ART_PROMPT.txt',
            'native_reference': str((SOURCE / 'native_reference.png').relative_to(ROOT)),
            'overrides': {str(p.relative_to(ROOT)): sha(p) for p in SOURCE.glob('*.png') if p.name not in ['atlas.png','native_reference.png']},
        },
        'notes': "Achievement artwork uses imagegen at the user's request. It is not byte-identical Mojang artwork. Native audio is unchanged.",
    }
    (ROOT / 'docs/MINECRAFT_ACHIEVEMENTS_MANIFEST.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n')
    # V2's manifest also lists six of these sprites. Keep their hashes in sync.
    v2_path = ROOT / 'docs/V2_ASSET_MANIFEST.json'
    v2 = json.loads(v2_path.read_text())
    for name in v2['derived'].keys() & derived.keys():v2['derived'][name] = derived[name]
    v2_path.write_text(json.dumps(v2, ensure_ascii=False, indent=2)+'\n')
    preview.resize((768, 768), Image.Resampling.NEAREST).save(ROOT / 'qa/achievement_badges.png')
    preview.save(ROOT / 'qa/achievements_v2/atlas_32px.png')
    print('ACHIEVEMENT_BAKE', len(derived), 'badges from the saved atlas')


if __name__ == '__main__':
    generate()
