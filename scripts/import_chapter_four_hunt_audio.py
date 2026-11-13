"""Original local Minecraft OGGs for the Chapter IV hunt (13.11): butcher,
pillar rescue, torn villagers, marksmen, ambushes and the raid surges.
Merges into data/chapter_four_audio.json without touching existing cues."""
from pathlib import Path
import hashlib
import json
from import_minecraft_assets import ROOT, find_client

EVENTS = {
    'ch4_butcher_roar': ('entity.ravager.roar', .55),
    'ch4_butcher_grunt': ('entity.vindicator.ambient', .5),
    'ch4_butcher_swing': ('entity.player.attack.sweep', .7),
    'ch4_butcher_step': ('entity.ravager.step', .35),
    'ch4_butcher_leave': ('entity.zombie_villager.converted', .45),
    'ch4_rescue_cut': ('entity.sheep.shear', .7),
    'ch4_rescue_body': ('entity.villager.death', .45),
    'ch4_rescue_reward': ('block.beacon.power_select', .4),
    'ch4_stir': ('entity.zombie_villager.ambient', .55),
    'ch4_tear': ('entity.zombie.break_wooden_door', .55),
    'ch4_sniper_aim': ('item.crossbow.loading_middle', .45),
    'ch4_sniper_shot': ('item.crossbow.shoot', .6),
    'ch4_surge': ('event.raid.horn', .55),
    'ch4_ambush': ('block.rooted_dirt.break', .8),
    'ch4_affix': ('block.respawn_anchor.charge', .4),
}


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

    def variants(event):
        for value in sounds[event]['sounds']:
            value = {'name': value} if isinstance(value, str) else value
            name = value['name'].replace('minecraft:', '')
            if value.get('type') == 'event':
                yield from variants(name)
            else:
                yield value | {'name': name}

    path = ROOT / 'data/chapter_four_audio.json'
    mapping = json.loads(path.read_text())
    manifest_path = ROOT / 'docs/CHAPTER_FOUR_AUDIO_MANIFEST.json'
    manifest = json.loads(manifest_path.read_text())
    output = ROOT / 'assets/audio/chapter_four'
    for ident, (event, gain) in EVENTS.items():
        clips = []
        for v in list(variants(event))[:3]:
            name = v['name']
            content = raw('sounds/' + name + '.ogg')
            filename = name.replace('/', '_') + '.ogg'
            (output / filename).write_bytes(content)
            clips.append(dict(path='res://assets/audio/chapter_four/' + filename, volume=v.get('volume', 1), pitch=v.get('pitch', 1)))
            manifest['files'][filename] = dict(source='minecraft/sounds/' + name + '.ogg', sha256=hashlib.sha256(content).hexdigest())
        assert clips, event
        mapping[ident] = dict(minecraft_event=event, gain=gain, variants=clips)
    path.write_text(json.dumps(mapping, indent=2) + '\n')
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
    print('Chapter IV hunt audio:', len(EVENTS), 'cues')


if __name__ == '__main__':
    generate()
