"""Import local vanilla sounds, GUI sprites and the real Minecraft bitmap font."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import subprocess
import zipfile
from io import BytesIO
from pathlib import Path

from PIL import Image

from import_minecraft_assets import ROOT, find_client

EVENTS = {
    "swing": ("entity.player.attack.sweep", .65),
    "arrow": ("entity.arrow.shoot", .55),
    "trident": ("item.trident.throw", .6),
    "fire": ("entity.blaze.shoot", .45),
    "potion_throw": ("entity.splash_potion.throw", .5),
    "hit": ("entity.player.attack.strong", .5),
    "hurt": ("entity.player.hurt", .7),
    "explosion": ("entity.generic.explode", .4),
    "hiss": ("entity.creeper.primed", .45),
    "xp": ("entity.experience_orb.pickup", .55),
    "pickup": ("entity.item.pickup", .6),
    "level": ("entity.player.levelup", .7),
    "chest": ("block.chest.open", .7),
    "potion": ("entity.splash_potion.break", .55),
    "fangs": ("entity.evoker_fangs.attack", .55),
    "lightning": ("entity.lightning_bolt.thunder", .28),
    "warning": ("entity.ravager.roar", .4),
    "death": ("entity.player.death", .7),
    "select": ("ui.button.click", .75),
    "break": ("block.wood.break", .55),
    "herobrine": ("entity.wither.spawn", .35),
    "fire_wave": ("entity.blaze.shoot", .6),
    "portal_open": ("block.portal.trigger", .55),
    "portal_travel": ("block.portal.travel", .6),
}
for mob in ["zombie", "skeleton", "spider", "creeper", "slime", "ravager", "vindicator"]:
    EVENTS["hurt_"+mob] = (f"entity.{mob}.hurt", .45)

GUI = {
    "hud_hotbar": "hud/hotbar", "hud_selection": "hud/hotbar_selection",
    "hud_xp_empty": "hud/experience_bar_background", "hud_xp_full": "hud/experience_bar_progress",
    "gui_button": "widget/button", "gui_button_active": "widget/button_highlighted",
    "heart": "hud/heart/full", "heart_half": "hud/heart/half", "heart_empty": "hud/heart/container",
    "heart_blink": "hud/heart/full_blinking", "heart_half_blink": "hud/heart/half_blinking",
}


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def build_font(jar, manifest):
    """BMFont retains the exact vanilla glyph masks, bearings and advances."""
    out = ROOT/"assets/fonts/minecraft"
    out.mkdir(parents=True,exist_ok=True)
    providers = json.loads(jar.read("assets/minecraft/font/include/default.json"))["providers"]
    glyphs, pages = {}, []
    for provider in providers:
        if provider["type"] != "bitmap":
            continue
        file = provider["file"].replace("minecraft:", "assets/minecraft/textures/")
        raw = jar.read(file)
        image = Image.open(BytesIO(raw)).convert("RGBA")
        page = len(pages)
        filename = Path(file).name
        (out/filename).write_bytes(raw)
        manifest["font_sources"][file] = sha256(raw)
        rows = provider["chars"]
        cw, ch = image.width//len(rows[0]), image.height//len(rows)
        scale = provider.get("height",8)/ch
        # All installed providers are pixel-sized; catch a future incompatible
        # font before emitting scaled or blurred glyphs.
        assert scale == 1, (filename, scale)
        for y,row in enumerate(rows):
            for x,char in enumerate(row):
                if char == "\0" or ord(char) in glyphs:
                    continue
                rect = (x*cw,y*ch,(x+1)*cw,(y+1)*ch)
                bounds = image.crop(rect).getchannel("A").getbbox()
                if not bounds:
                    continue
                width = bounds[2]
                glyphs[ord(char)] = {"id":ord(char),"x":x*cw,"y":y*ch,
                    "width":width,"height":ch,"xoffset":0,"yoffset":7-provider["ascent"],
                    "xadvance":math.floor(width*scale+.5)+1,"page":page,"chnl":15}
        pages.append((filename,image))
    glyphs[32] = dict(id=32,x=0,y=0,width=0,height=0,xoffset=0,yoffset=0,xadvance=4,page=0,chnl=15)
    glyphs[0x200c] = dict(glyphs[32], id=0x200c,xadvance=0)
    # Minecraft bold paints a second copy one pixel to the right. Keep its
    # texture inside each cell and its one-pixel extra advance.
    bold_pages = []
    for page,(name,image) in enumerate(pages):
        bold = Image.new("RGBA",image.size)
        for glyph in glyphs.values():
            if glyph["page"] != page or glyph["width"] == 0:
                continue
            x,y,w,h = (glyph[k] for k in ["x","y","width","height"])
            im = image.crop((x,y,x+w,y+h))
            bold.alpha_composite(im,(x,y))
            bold.alpha_composite(im,(x+1,y))
        bold_name = "bold_"+name
        bold.save(out/bold_name)
        bold_pages.append((bold_name,bold))
    for name, atlas_pages, is_bold in [("regular",pages,False),("bold",bold_pages,True)]:
        lines = [f'info face="Minecraft {name}" size=8 bold={int(is_bold)} italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=0,0',
                 f'common lineHeight=9 base=7 scaleW=128 scaleH=128 pages={len(atlas_pages)} packed=0']
        for i,(file,_) in enumerate(atlas_pages):
            lines.append(f'page id={i} file="{file}"')
        lines.append(f'chars count={len(glyphs)}')
        for glyph in sorted(glyphs.values(),key=lambda g:g["id"]):
            g = dict(glyph)
            if is_bold and g["width"]:
                g["width"]+=1
                g["xadvance"]+=1
            lines.append("char "+" ".join(f"{k}={v}" for k,v in g.items()))
        (out/f"minecraft_{name}.fnt").write_text("\n".join(lines)+"\n")
    manifest["glyphs"] = len(glyphs)


def import_presentation(prism: Path, music: Path, boss_music: Path | None = None):
    version,client,_ = find_client(prism)
    meta = json.loads((prism/f"meta/net.minecraft/{version}.json").read_text())
    index_id = meta["assetIndex"]["id"]
    index = json.loads((prism/f"assets/indexes/{index_id}.json").read_text())["objects"]
    manifest = {"version":version,"asset_index":index_id,"sound_files":{},"font_sources":{},"gui_sources":{}}

    def object_bytes(name):
        entry = index["minecraft/"+name]
        h = entry["hash"]
        raw = (prism/f"assets/objects/{h[:2]}/{h}").read_bytes()
        assert hashlib.sha1(raw).hexdigest() == h, name
        return raw,h

    sounds_raw,_ = object_bytes("sounds.json")
    sounds = json.loads(sounds_raw)
    out = ROOT/"assets/audio/minecraft"
    out.mkdir(parents=True,exist_ok=True)
    sound_map = {}
    for game_id,(event,gain) in EVENTS.items():
        variants = []
        for variant in sounds[event]["sounds"]:
            entry = {"name":variant} if isinstance(variant,str) else variant
            assert entry.get("type","file") == "file", event
            name = entry["name"].replace("minecraft:","")
            data,h = object_bytes("sounds/"+name+".ogg")
            filename = name.replace("/","_")+".ogg"
            (out/filename).write_bytes(data)
            manifest["sound_files"][filename] = {"source":"minecraft/sounds/"+name+".ogg", "sha1":h, "sha256":sha256(data)}
            variants.append({"path":"res://assets/audio/minecraft/"+filename,
                             "volume":entry.get("volume",1.0),"pitch":entry.get("pitch",1.0)})
        sound_map[game_id] = {"minecraft_event":event,"gain":gain,"variants":variants}
    with zipfile.ZipFile(client) as jar:
        build_font(jar,manifest)
        for name,source in GUI.items():
            path = "assets/minecraft/textures/gui/sprites/"+source+".png"
            data = jar.read(path)
            (ROOT/f"assets/sprites/{name}.png").write_bytes(data)
            manifest["gui_sources"][name] = {"source":path,"sha256":sha256(data)}
        # Preserve the exact slot interiors and frame pixels while adapting the
        # nine-slot vanilla bar to the two independent six-slot inventories.
        hotbar = Image.open(BytesIO(jar.read("assets/minecraft/textures/gui/sprites/hud/hotbar.png"))).convert("RGBA")
        bar = Image.new("RGBA",(122,22))
        bar.paste(hotbar.crop((0,0,121,22)),(0,0))
        bar.paste(hotbar.crop((181,0,182,22)),(121,0))
        bar.save(ROOT/"assets/sprites/hud_six_slots.png")
    music_out = ROOT/"assets/audio/music.ogg"
    subprocess.run(["ffmpeg","-y","-loglevel","error","-i",str(music),"-map","0:a:0","-vn",
                    "-c:a","libvorbis","-q:a","6","-map_metadata","-1",str(music_out)],check=True)
    manifest["music"] = {"source":str(music),"source_sha256":sha256(music.read_bytes()),
                          "output":"assets/audio/music.ogg","sha256":sha256(music_out.read_bytes()),
                          "conversion":"Original source contains AAC despite .mp3 extension; decoded to Ogg Vorbis q6 for Godot"}
    if boss_music is not None:
        boss_out=ROOT/"assets/audio/music_herobrine.ogg"
        probe=subprocess.run(["ffprobe","-v","error","-select_streams","a:0","-show_entries","stream=codec_name","-of","json",str(boss_music)],capture_output=True,text=True,check=True)
        codec=json.loads(probe.stdout)["streams"][0]["codec_name"]
        if codec=="vorbis":
            boss_out.write_bytes(boss_music.read_bytes())
        else:
            subprocess.run(["ffmpeg","-y","-loglevel","error","-i",str(boss_music),"-map","0:a:0","-vn","-c:a","libvorbis","-q:a","6","-map_metadata","-1",str(boss_out)],check=True)
        manifest["boss_music"]={"source":str(boss_music),"source_sha256":sha256(boss_music.read_bytes()),
            "output":"assets/audio/music_herobrine.ogg","sha256":sha256(boss_out.read_bytes()),
            "conversion":"Original Vorbis bytes copied unchanged" if codec=="vorbis" else f"Original {codec} decoded to Ogg Vorbis q6 for Godot"}
    elif (ROOT/"docs/MINECRAFT_PRESENTATION_MANIFEST.json").exists():
        previous=json.loads((ROOT/"docs/MINECRAFT_PRESENTATION_MANIFEST.json").read_text())
        if "boss_music" in previous:manifest["boss_music"]=previous["boss_music"]
    (ROOT/"data/minecraft_audio.json").write_text(json.dumps(sound_map,ensure_ascii=False,indent=2)+"\n")
    (ROOT/"docs/MINECRAFT_PRESENTATION_MANIFEST.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n")
    print(f"Minecraft {version}: {len(manifest['sound_files'])} original sounds, {len(sound_map)} events, {manifest['glyphs']} bitmap glyphs; user music converted")


if __name__ == "__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prism",type=Path,default=Path.home()/".local/share/PrismLauncher")
    parser.add_argument("--music",type=Path,default=Path.home()/"Downloads/Telegram Desktop/MusicForGame.mp3")
    parser.add_argument("--boss-music",type=Path,default=Path.home()/"Downloads/audio_2026-10-27_17-30-49.ogg")
    args=parser.parse_args()
    import_presentation(args.prism,args.music,args.boss_music)
