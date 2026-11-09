"""Import original local Minecraft OGG bytes for Chapter IV stage A."""
from pathlib import Path
import hashlib
import json
from import_minecraft_assets import ROOT, find_client


def generate():
    prism = Path.home() / '.local/share/PrismLauncher'
    version, client, _ = find_client(prism)
    meta = json.loads((prism / f'meta/net.minecraft/{version}.json').read_text())
    index = json.loads((prism / f"assets/indexes/{meta['assetIndex']['id']}.json").read_text())['objects']

    def raw(name):
        sha = index['minecraft/' + name]['hash']
        content = (prism / f'assets/objects/{sha[:2]}/{sha}').read_bytes()
        assert hashlib.sha1(content).hexdigest() == sha, name
        return content

    sounds = json.loads(raw('sounds.json'))
    mapping, manifest = {}, {}

    def variants(event):
        for value in sounds[event]['sounds']:
            value = {'name': value} if isinstance(value, str) else value
            name = value['name'].replace('minecraft:', '')
            if value.get('type') == 'event':
                yield from variants(name)
            else:
                yield value | {'name': name}

    events = {
        'ch4_despair': ('ambient.soul_sand_valley.mood', .3),
        'ch4_rage': ('block.bell.resonate', .45),
        'ch4_note': ('item.book.page_turn', .6),
        'ch4_charge': ('block.sculk_shrieker.shriek', .18),
        'ch4_pulse': ('block.slime_block.hit', .5),
        'ch4_hand': ('entity.warden.tendril_clicks', .4),
        'ch4_break': ('block.sculk.break', .6),
    }
    output = ROOT / 'assets/audio/chapter_four'
    output.mkdir(exist_ok=True)
    for ident, (event, gain) in events.items():
        clips = []
        for v in list(variants(event))[:3]:
            name = v['name']
            content = raw('sounds/' + name + '.ogg')
            filename = name.replace('/', '_') + '.ogg'
            (output / filename).write_bytes(content)
            clips.append(dict(path='res://assets/audio/chapter_four/' + filename, volume=v.get('volume', 1), pitch=v.get('pitch', 1)))
            manifest[filename] = dict(source='minecraft/sounds/' + name + '.ogg', sha256=hashlib.sha256(content).hexdigest())
        assert clips, event
        mapping[ident] = dict(minecraft_event=event, gain=gain, variants=clips)
    track = next(variants('music.overworld.deep_dark'))
    content = raw('sounds/' + track['name'] + '.ogg')
    (output / 'ancestry.ogg').write_bytes(content)
    manifest['ancestry.ogg'] = dict(source='minecraft/sounds/' + track['name'] + '.ogg', sha256=hashlib.sha256(content).hexdigest())
    (ROOT / 'data/chapter_four_audio.json').write_text(json.dumps(mapping, indent=2) + '\n')
    (ROOT / 'docs/CHAPTER_FOUR_AUDIO_MANIFEST.json').write_text(json.dumps(dict(version=version, files=manifest), indent=2) + '\n')
    print('Chapter IV audio:', len(manifest), 'original OGG files')


if __name__ == '__main__':
    generate()
