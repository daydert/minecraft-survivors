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
        'ch4_mob_warn': ('entity.zombie.attack_wooden_door', .24),
        'ch4_bone_shoot': ('entity.skeleton.shoot', .45),
        'ch4_creeper_burst': ('entity.generic.explode', .55),
        'ch4_mob_heal': ('entity.witch.drink', .35),
        'ch4_poison': ('entity.splash_potion.break', .4),
        'ch4_bell_warn': ('block.bell.resonate', .27),
        'ch4_bell': ('block.bell.use', .45),
        'ch4_heartbeat': ('entity.warden.heartbeat', .6),
        'ch4_heavy': ('item.mace.smash_ground_heavy', .6),
        'ch4_shotgun': ('item.crossbow.shoot', .8),
        'ch4_reload': ('item.crossbow.loading_end', .6),
        'ch4_sky_hook': ('entity.fishing_bobber.throw', .65),
        'ch4_drink': ('entity.generic.drink', .5),
        'ch4_bat': ('entity.bat.takeoff', .5),
        'ch4_chain': ('block.chain.hit', .35),
        'ch4_totem': ('item.totem.use', .6),
        'ch4_mirror': ('block.glass.break', .25),
        'ch4_mass_birth': ('entity.warden.emerge', .5),
        'ch4_mass_warn': ('entity.hoglin.angry', .5),
        'ch4_mass_shed': ('block.slime_block.break', .65),
        'ch4_mass_death': ('entity.ravager.death', .65),
        'ch4_flesh_hit': ('entity.slime.hurt', .3),
        'ch4_flesh_shot': ('entity.llama.spit', .4),
        'ch4_growth_rip': ('block.honey_block.break', .6),
        'ch4_golem_strain': ('entity.iron_golem.hurt', .6),
        'ch4_golem_warn': ('entity.iron_golem.damage', .55),
        'ch4_golem_slam': ('entity.iron_golem.attack', .65),
        'ch4_golem_free': ('entity.iron_golem.repair', .8),
        'ch4_guardian_awake': ('block.beacon.activate', .6),
        'ch4_guardian_warn': ('block.beacon.power_select', .55),
        'ch4_guardian_open': ('block.beacon.deactivate', .45),
        'ch4_guardian_death': ('block.respawn_anchor.deplete', .7),
        'ch4_stone_rise': ('block.piston.extend', .6),
        'ch4_stone_hit': ('block.deepslate.hit', .45),
        'ch4_ground_slam': ('entity.iron_golem.attack', .55),
        # Finale: Herobrine, the fistfight, his death and the door.
        'ch4_hb_twitch': ('entity.creaking.twitch', .55),
        'ch4_hb_freeze': ('entity.creaking.freeze', .55),
        'ch4_hb_teleport': ('entity.enderman.teleport', .4),
        'ch4_hb_charge': ('block.respawn_anchor.charge', .45),
        'ch4_hb_lightning': ('entity.lightning_bolt.thunder', .35),
        'ch4_hb_fire': ('item.firecharge.use', .5),
        'ch4_hb_blackhole': ('block.conduit.activate', .65),
        'ch4_hb_collapse': ('entity.generic.explode', .55),
        'ch4_hb_rift': ('block.sculk_catalyst.bloom', .7),
        'ch4_hb_blitz': ('entity.breeze.wind_burst', .55),
        'ch4_hb_rain': ('entity.arrow.shoot', .3),
        'ch4_hb_day': ('block.conduit.ambient', .7),
        'ch4_hb_pulse': ('block.beacon.power_select', .4),
        'ch4_hb_shatter': ('block.glass.break', .75),
        'ch4_hb_glitch': ('entity.elder_guardian.curse', .45),
        'ch4_punch': ('entity.player.attack.strong', .75),
        'ch4_punch_heavy': ('entity.player.attack.knockback', .8),
        'ch4_punch_miss': ('entity.player.attack.nodamage', .55),
        'ch4_hurt': ('entity.player.hurt', .7),
        'ch4_breath': ('entity.player.breath', .55),
        'ch4_body_fall': ('entity.player.big_fall', .7),
        'ch4_bone_crack': ('block.bone_block.break', .8),
        'ch4_head_break': ('entity.zombie.break_wooden_door', .75),
        'ch4_door_open': ('block.iron_door.open', .6),
        'ch4_door_close': ('block.iron_door.close', .85),
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
    track = next(variants('music_disc.5'))
    content = raw('sounds/' + track['name'] + '.ogg')
    (output / 'pyramid_5.ogg').write_bytes(content)
    manifest['pyramid_5.ogg'] = dict(source='minecraft/sounds/' + track['name'] + '.ogg', sha256=hashlib.sha256(content).hexdigest())
    # Finale music from the same client: tense, then relentless, then quiet.
    for disc, filename in [('music_disc.precipice', 'precipice.ogg'), ('music_disc.creator', 'creator.ogg'), ('music_disc.relic', 'relic.ogg')]:
        track = next(variants(disc))
        content = raw('sounds/' + track['name'] + '.ogg')
        (output / filename).write_bytes(content)
        manifest[filename] = dict(source='minecraft/sounds/' + track['name'] + '.ogg', sha256=hashlib.sha256(content).hexdigest())
    (ROOT / 'data/chapter_four_audio.json').write_text(json.dumps(mapping, indent=2) + '\n')
    (ROOT / 'docs/CHAPTER_FOUR_AUDIO_MANIFEST.json').write_text(json.dumps(dict(version=version, files=manifest), indent=2) + '\n')
    print('Chapter IV audio:', len(manifest), 'original OGG files')


if __name__ == '__main__':
    generate()
