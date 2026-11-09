"""Import the vanilla resources used by this game from the newest local Prism client.

Flat item PNGs and .mcmeta files are copied byte for byte. Entity/block UV maps
are baked with nearest-neighbour sampling for the game's orthographic 2D view.
No network access, launcher accounts, mods or resource packs are needed.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import math
import re
import zipfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "assets/minecraft"
OUT = ROOT / "assets/sprites"
PREFIX = "assets/minecraft/"
ITEMS = {
    "sword": "iron_sword", "bow": "bow", "trident": "trident",
    "fire": "fire_charge", "blaze": "blaze_powder", "redstone": "redstone",
    "amethyst": "amethyst_shard", "sugar": "sugar", "armor": "iron_chestplate",
    "hopper": "hopper", "apple": "apple", "emerald": "emerald",
    "netherite": "netherite_sword", "flamebow": "bow", "channeling": "trident",
}


def find_client(prism: Path) -> tuple[str, Path, list[str]]:
    """Use installed instance component versions, not a remote 'latest' version."""
    candidates = {}
    for pack in (prism / "instances").glob("*/mmc-pack.json"):
        for part in json.loads(pack.read_text())["components"]:
            version = part.get("version", "")
            if part["uid"] == "net.minecraft" and re.fullmatch(r"\d+(?:\.\d+)+", version):
                jar = prism / f"libraries/com/mojang/minecraft/{version}/minecraft-{version}-client.jar"
                if jar.is_file():
                    entry = candidates.setdefault(version, (jar, []))
                    entry[1].append(pack.parent.name)
    if not candidates:
        raise FileNotFoundError(f"No installed vanilla release client in {prism}")
    version = max(candidates, key=lambda v: tuple(map(int, v.split("."))))
    jar, instances = candidates[version]
    return version, jar, sorted(instances)


class Importer:
    def __init__(self, jar: Path):
        self.jar = zipfile.ZipFile(jar)
        self.files = {}
        self.images = {}
        self.derived = {}
        self.clips = {}

    def extract(self, relative: str) -> Path:
        path = RAW / relative
        if relative not in self.files:
            data = self.jar.read(PREFIX + relative)
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
            self.files[relative] = {"sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data)}
            if PREFIX + relative + ".mcmeta" in self.jar.namelist():
                self.extract(relative + ".mcmeta")
        return path

    def tex(self, relative: str) -> Image.Image:
        relative = "textures/" + relative + ".png"
        if relative not in self.images:
            self.images[relative] = Image.open(self.extract(relative)).convert("RGBA")
        return self.images[relative]

    def save(self, image: Image.Image, name: str, sources: list[str], origin: str | None = None):
        path = OUT / (name + ".png")
        from PIL.PngImagePlugin import PngInfo
        metadata=PngInfo()
        if origin:metadata.add_text("impeccable:prompt",origin)
        image.save(path,pnginfo=metadata)
        self.derived[name] = {"sources": sources, "size": list(image.size),
                              "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}

    def copy_item(self, game_id: str, vanilla_id: str):
        source = self.extract(f"textures/item/{vanilla_id}.png")
        target = OUT / f"icon_{game_id}.png"
        target.write_bytes(source.read_bytes())
        self.derived["icon_" + game_id] = {"sources": [f"item/{vanilla_id}"],
            "size": list(self.tex("item/" + vanilla_id).size),
            "sha256": hashlib.sha256(target.read_bytes()).hexdigest(), "byte_identical": True}

    def strip(self, name: str, sources: list[str], duration: float = 0.05):
        images = [self.tex(s) for s in sources]
        w, h = images[0].size
        out = Image.new("RGBA", (w * len(images), h))
        for i, im in enumerate(images):
            out.paste(im, (w * i, 0))
        self.save(out, name, sources)
        self.clips[name] = {"frame_size": [w, h], "frames": list(range(len(images))),
                            "durations": [duration] * len(images)}

    def native_strip(self, name: str, source: str):
        image = self.tex(source)
        meta = json.loads((RAW / ("textures/" + source + ".png.mcmeta")).read_text())["animation"]
        w = meta.get("width", image.width)
        h = meta.get("height", w)
        count = image.height // h
        out = Image.new("RGBA", (count * w, h))
        for i in range(count):
            out.paste(image.crop((0, i*h, w, (i+1)*h)), (i*w, 0))
        sequence = meta.get("frames", list(range(count)))
        self.save(out, name, [source])
        self.clips[name] = {"frame_size": [w, h],
            "frames": [f["index"] if isinstance(f, dict) else f for f in sequence],
            "durations": [(f.get("time", meta.get("frametime", 1)) if isinstance(f, dict)
                            else meta.get("frametime", 1)) / 20 for f in sequence]}


def box(texture, origin, size, uv=(0, 0), rotate=None, faces=None):
    """Vanilla ModelPart box UV unwrap. World axes are X/right, Y/up, Z/back."""
    x, y, z = origin
    w, h, d = size
    u, v = uv
    # Vertex order is top-left, top-right, bottom-right, bottom-left per face.
    points = {
        "north": [(x+w,y+h,z),(x,y+h,z),(x,y,z),(x+w,y,z)],
        "south": [(x,y+h,z+d),(x+w,y+h,z+d),(x+w,y,z+d),(x,y,z+d)],
        "east": [(x+w,y+h,z+d),(x+w,y+h,z),(x+w,y,z),(x+w,y,z+d)],
        "west": [(x,y+h,z),(x,y+h,z+d),(x,y,z+d),(x,y,z)],
        "up": [(x,y+h,z),(x+w,y+h,z),(x+w,y+h,z+d),(x,y+h,z+d)],
        "down": [(x,y,z+d),(x+w,y,z+d),(x+w,y,z),(x,y,z)],
    }
    rects = {"west": (u,v+d,d,h), "north": (u+d,v+d,w,h),
             "east": (u+d+w,v+d,d,h), "south": (u+d+w+d,v+d,w,h),
             "up": (u+d,v,w,d), "down": (u+d+w,v,w,d)}
    result = []
    for name, verts in points.items():
        if faces and name not in faces:
            continue
        tex, rect = (faces[name] if faces else (texture, rects[name]))
        verts = np.array(verts, dtype=float)
        if rotate:
            axis, angle, pivot = rotate
            c, s = math.cos(angle), math.sin(angle)
            matrix = (np.array([[1,0,0],[0,c,-s],[0,s,c]]) if axis == "x" else
                      np.array([[c,-s,0],[s,c,0],[0,0,1]]))
            verts = (verts - pivot) @ matrix.T + pivot
        result.append((verts, tex, rect, {"up":1.0,"north":0.86,"east":0.7,
                                         "south":0.8,"west":0.68,"down":0.55}[name]))
    return result


def bake(mesh, size=(32, 32), scale=1.25, center=(16, 27), yaw=30, elevation=25):
    """Small orthographic, z-buffered texture rasterizer; no smoothing or paint."""
    yaw, elevation = math.radians(yaw), math.radians(elevation)
    right = np.array([math.cos(yaw), 0, math.sin(yaw)])
    up = np.array([-math.sin(yaw)*math.sin(elevation), math.cos(elevation), math.cos(yaw)*math.sin(elevation)])
    view = np.cross(up, right)
    output = np.zeros((size[1], size[0], 4), dtype=np.uint8)
    depth = np.full((size[1], size[0]), -np.inf)
    for verts, texture, rect, shade in mesh:
        # Normal convention varies between unwrap faces: rasterize both sides.
        projected = np.column_stack((verts @ right * scale + center[0],
                                     -verts @ up * scale + center[1], verts @ view))
        u, v, w, h = rect
        uv = np.array([[u,v],[u+w,v],[u+w,v+h],[u,v+h]], dtype=float)
        tex = np.asarray(texture)
        for indices in [(0,1,2), (0,2,3)]:
            tri = projected[list(indices)]
            tuv = uv[list(indices)]
            lo = np.maximum(np.floor(tri[:,:2].min(axis=0)).astype(int), [0,0])
            hi = np.minimum(np.ceil(tri[:,:2].max(axis=0)).astype(int), [size[0]-1,size[1]-1])
            if np.any(hi < lo):
                continue
            a, b, c = tri[:,:2]
            det = (b-a)[0]*(c-a)[1] - (b-a)[1]*(c-a)[0]
            if abs(det) < 1e-7:
                continue
            yy, xx = np.mgrid[lo[1]:hi[1]+1,lo[0]:hi[0]+1]
            q = np.stack((xx+0.5, yy+0.5), axis=-1)-a
            b1 = (q[...,0]*(c-a)[1]-q[...,1]*(c-a)[0])/det
            b2 = ((b-a)[0]*q[...,1]-(b-a)[1]*q[...,0])/det
            b0 = 1-b1-b2
            inside = (b0 >= -1e-6)&(b1 >= -1e-6)&(b2 >= -1e-6)
            z = b0*tri[0,2]+b1*tri[1,2]+b2*tri[2,2]
            coords = b0[...,None]*tuv[0]+b1[...,None]*tuv[1]+b2[...,None]*tuv[2]
            tx = np.clip(np.floor(coords[...,0]).astype(int), 0, tex.shape[1]-1)
            ty = np.clip(np.floor(coords[...,1]).astype(int), 0, tex.shape[0]-1)
            pixels = tex[ty,tx].copy()
            pixels[:,:,:3] = (pixels[:,:,:3]*shade).astype(np.uint8)
            region = depth[lo[1]:hi[1]+1,lo[0]:hi[0]+1]
            mask = inside & (z > region) & (pixels[:,:,3] > 0)
            region[mask] = z[mask]
            output[yy[mask],xx[mask]] = pixels[mask]
    return Image.fromarray(output)


def chest_mesh(texture, opening=0.0):
    pivot = np.array([0,10,7])
    rotation = ("x", opening*math.pi/2, pivot)
    return (box(texture,(-7,0,-7),(14,10,14),(0,19)) +
            box(texture,(-7,10,-7),(14,5,14),(0,0),rotation) +
            box(texture,(-1,8,-8),(2,4,1),(0,0),rotation))


def tinted(image, color):
    return ImageChops.multiply(image, Image.new("RGBA", image.size, (*color,255)))


def import_assets(prism: Path, explicit_jar: Path | None = None):
    version, jar, instances = find_client(prism) if explicit_jar is None else ("custom", explicit_jar, [])
    OUT.mkdir(parents=True, exist_ok=True)
    imp = Importer(jar)
    for game_id, vanilla_id in ITEMS.items():
        imp.copy_item(game_id, vanilla_id)
    for i in range(3):
        source = imp.extract(f"textures/item/bow_pulling_{i}.png")
        (OUT / f"bow_pulling_{i}.png").write_bytes(source.read_bytes())
    imp.strip("bow_draw", ["item/bow"]+[f"item/bow_pulling_{i}" for i in range(3)], 0.06)
    imp.copy_item("arrow", "arrow")
    # The bottle consists of the vanilla generated-item layers, tinted as POISON
    # in this client's MobEffects class (8889187 = 0x87A363).
    overlay = tinted(imp.tex("item/potion_overlay"), (135,163,99))
    for name, source in [("potion","potion"), ("splash_potion","splash_potion")]:
        im = overlay.copy()
        im.alpha_composite(imp.tex("item/"+source))
        imp.save(im,"icon_"+name,["item/potion_overlay","item/"+source])
    for name, source in [("heart","full"),("heart_half","half"),("heart_empty","container")]:
        path = imp.extract(f"textures/gui/sprites/hud/heart/{source}.png")
        (OUT / (name+".png")).write_bytes(path.read_bytes())
    glint = imp.tex("misc/enchanted_glint_item")
    # Bake the moving vanilla glint into alpha-masked item frames. This permits
    # independent item glints in Node2D draw commands without tinting the world.
    for game_id in ["netherite", "flamebow", "channeling"]:
        base = imp.tex("item/"+ITEMS[game_id])
        frames = Image.new("RGBA",(16*32,16))
        for frame in range(32):
            im = base.copy()
            for y in range(16):
                for x in range(16):
                    r,g,b,a = im.getpixel((x,y))
                    if a:
                        value = glint.getpixel(((x*3+y+frame*4)%128,(y*3-x+frame*2)%128))[0]/255
                        im.putpixel((x,y),(min(255,r+int(value*105)),min(255,g+int(value*45)),min(255,b+int(value*165)),a))
            frames.paste(im,(16*frame,0))
        imp.save(frames,game_id+"_enchanted",["item/"+ITEMS[game_id],"misc/enchanted_glint_item"])
        imp.clips[game_id+"_enchanted"] = {"frame_size":[16,16],"frames":list(range(32)),"durations":[0.06]*32}
    bow_draw = Image.new("RGBA",(16*32,16*4))
    for stage, source in enumerate(["item/bow"]+[f"item/bow_pulling_{i}" for i in range(3)]):
        base = imp.tex(source)
        for frame in range(32):
            im = base.copy()
            for y in range(16):
                for x in range(16):
                    r,g,b,a = im.getpixel((x,y))
                    if a:
                        value = glint.getpixel(((x*3+y+frame*4)%128,(y*3-x+frame*2)%128))[0]/255
                        im.putpixel((x,y),(min(255,r+int(value*105)),min(255,g+int(value*45)),min(255,b+int(value*165)),a))
            bow_draw.paste(im,(16*frame,16*stage))
    imp.save(bow_draw,"flamebow_draw",["item/bow"]+[f"item/bow_pulling_{i}" for i in range(3)]+["misc/enchanted_glint_item"])
    imp.tex("entity/projectiles/arrow")
    imp.native_strip("fire_animation", "block/fire_0")
    imp.strip("poison_animation", [f"particle/effect_{i}" for i in range(8)], 0.08)
    imp.strip("sweep_animation", [f"particle/sweep_{i}" for i in range(8)], 0.025)
    imp.strip("explosion_animation", [f"particle/explosion_{i}" for i in range(16)], 0.025)
    imp.tex("particle/flame")
    xp = imp.tex("entity/experience_orb")
    imp.save(xp,"experience_orb",["entity/experience_orb"])
    chest = imp.tex("entity/chest/normal")
    imp.save(bake(chest_mesh(chest), (16,16), 0.7, (8,13)),"icon_chest",["entity/chest/normal"])
    chest_strip = Image.new("RGBA",(32*8,32))
    for i in range(8):
        frame = bake(chest_mesh(chest, 1-(1-i/7)**3))
        chest_strip.paste(frame,(32*i,0))
    imp.save(chest_strip,"chest_open",["entity/chest/normal"])
    imp.clips["chest_open"] = {"frame_size":[32,32],"frames":list(range(8)),"durations":[0.07]*8}
    fangs = imp.tex("entity/illager/evoker_fangs")
    fangs_strip = Image.new("RGBA",(32*8,32))
    for i in range(8):
        # Geometry and jaw curves checked against this client's hcy.class:
        # 10x12x10 base, 4x14x8 jaws, UVs (0,0)/(40,0), +/-0.35*pi.
        progress = 0.05 + i/7*0.75
        opening = 1 - min(progress*2,1)**3
        base_y = 3
        mesh = box(fangs,(-5,base_y-12,-5),(10,12,10),(0,0))
        for sign in [-1,1]:
            jaw = box(fangs,(0,-14,0),(4,14,8),(40,0))
            angle = -(math.pi-sign*opening*0.35*math.pi)
            c,s = math.cos(angle),math.sin(angle)
            rz = np.array([[c,-s,0],[s,c,0],[0,0,1]])
            ry = np.diag([-1,1,-1]) if sign<0 else np.eye(3)
            offset = np.array([sign*1.5,base_y,-sign*4])
            mesh += [(verts @ ry.T @ rz.T + offset,tex,rect,shade)
                     for verts,tex,rect,shade in jaw]
        frame = bake(mesh, (32,32), 1.1, (16,28), yaw=15)
        fangs_strip.paste(frame,(32*i,0))
    imp.save(fangs_strip,"fangs_animation",["entity/illager/evoker_fangs"])
    imp.save(fangs_strip.crop((96,0,128,32)).resize((16,16),Image.Resampling.NEAREST),
             "icon_fangs",["entity/illager/evoker_fangs"])
    imp.clips["fangs_animation"] = {"frame_size":[32,32],"frames":list(range(8)),"durations":[0.09]*8}
    import_environment(imp)
    manifest = {"version":version,"client_jar":str(jar),"instances":instances,
        "client_sha256":hashlib.sha256(jar.read_bytes()).hexdigest(),
        "source":"Local Prism Launcher vanilla client; no resource-pack overrides",
        "raw_files":imp.files,"derived":imp.derived,
        "notes":{"potion_color":"#87a363", "chest_fangs":"2D projections of vanilla entity textures; no vanilla flat item icon exists",
                 "evolutions":"Original bow/trident with moving vanilla enchantment glint"}}
    (ROOT/"docs/MINECRAFT_ASSET_MANIFEST.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n")
    (ROOT/"data/minecraft_assets.json").write_text(json.dumps({"version":version,"clips":imp.clips},indent=2)+"\n")
    contact_sheet(imp)
    print(f"Minecraft {version}: {len(imp.files)} original resources, {len(imp.derived)} game sprites, {len(imp.clips)} animation clips")


def import_environment(imp):
    # Same collision layout and deterministic paths; replace the pixel sources.
    grass = tinted(imp.tex("block/grass_block_top"),(145,189,89))
    dirt = imp.tex("block/dirt_path_top")
    stone = imp.tex("block/stone")
    for i in range(6):
        imp.save(grass if i<4 else (dirt if i==4 else stone),f"tile_{i}",
                 ["block/grass_block_top" if i<4 else ("block/dirt_path_top" if i==4 else "block/stone")])
    import random
    r = random.Random(153)
    ground = Image.new("RGB",(2048,2048))
    for y in range(128):
        for x in range(128):
            kind=r.randrange(4)
            path=abs(y-(61+5*math.sin(x*.095)))<1.1 or abs(x-(69+4*math.sin(y*.12)))<.8
            if path and r.random()<.8:kind=4
            if ((x-59)**2+(y-55)**2<22 or (x-88)**2+(y-81)**2<16) and r.random()<.8:kind=5
            ground.paste(grass if kind<4 else (dirt if kind==4 else stone),(x*16,y*16))
    imp.save(ground,"ground",["block/grass_block_top","block/dirt_path_top","block/stone"])
    def cube_sides(top,side,bottom=None):
        return {face:(top if face=="up" else (bottom if face=="down" and bottom else side),(0,0,16,16))
                for face in ["north","south","east","west","up","down"]}
    imp.save(bake(box(stone,(-8,0,-8),(16,16,16),faces=cube_sides(stone,stone)),
                  (32,32),1.2,(16,27)),"rock",["block/stone"])
    pumpkin = imp.tex("block/pumpkin_side")
    top = imp.tex("block/pumpkin_top")
    imp.save(bake(box(pumpkin,(-8,0,-8),(16,16,16),faces=cube_sides(top,pumpkin)),
                  (24,24),0.92,(12,21)),"pumpkin",["block/pumpkin_top","block/pumpkin_side"])
    log = imp.tex("block/oak_log")
    logtop = imp.tex("block/oak_log_top")
    imp.save(bake(box(log,(-7,0,-7),(14,9,14),faces=cube_sides(logtop,log)),
                  (24,24),0.95,(12,21)),"stump",["block/oak_log_top","block/oak_log"])
    imp.save(imp.tex("block/dandelion"),"flowers",["block/dandelion"])
    leaves = tinted(imp.tex("block/oak_leaves"),(119,171,47))
    for variant in range(3):
        mesh = box(log,(-3,0,-3),(6,28,6),faces=cube_sides(logtop,log))
        for origin,sz in [((-14,22,-12),(28,8,24)),((-12,30,-10),(24,8,20)),((-8,38,-7),(16,7,14))]:
            mesh += box(leaves,origin,sz,faces=cube_sides(leaves,leaves))
        imp.save(bake(mesh,(64,72),1.28,(32,65),yaw=25+variant*5,elevation=22),
                 f"tree_{variant}",["block/oak_log","block/oak_log_top","block/oak_leaves"])


def contact_sheet(imp):
    labels = list(ITEMS)+["potion","fangs","chest"]
    out = Image.new("RGB",(720,440),(25,35,31))
    draw = ImageDraw.Draw(out)
    font = ImageFont.truetype(str(ROOT/"assets/fonts/DejaVuSans.ttf"),12)
    draw.text((20,12),"MINECRAFT JAVA / ORIGINAL PRISM LAUNCHER ASSETS",font=font,fill=(190,213,167))
    for i,name in enumerate(labels):
        x,y=20+(i%6)*117,48+(i//6)*110
        im=Image.open(OUT/f"icon_{name}.png").convert("RGBA").resize((64,64),Image.Resampling.NEAREST)
        out.paste(im,(x+15,y),im)
        draw.text((x,y+73),name,font=font,fill=(230,230,210))
    out.save(ROOT/"qa/minecraft_items.png")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prism",type=Path,default=Path.home()/".local/share/PrismLauncher")
    parser.add_argument("--jar",type=Path,help="Use an explicit local vanilla client instead")
    args=parser.parse_args()
    import_assets(args.prism,args.jar)
