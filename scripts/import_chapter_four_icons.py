"""Package the saved chapter IV imagegen items as transparent pixel sprites.

This only replaces inventory artwork. Held meshes, combat textures and balance
are left to the chapter's existing bakers. No generator is called by a build.
"""
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets/art_source/ch4_icons"
OUT = ROOT / "assets/sprites"
QA = ROOT / "qa/ch4_icons"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def pack_sprite(path):
    image = Image.open(path).convert("RGBA")
    if image.getchannel("A").getextrema() != (0, 255):
        raise ValueError("The saved sprite must have a transparent background: " + str(path))
    bounds = image.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError("Empty generated sprite: " + str(path))
    image = image.crop(bounds)
    image.thumbnail((28, 28), Image.Resampling.NEAREST)
    alpha = image.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
    # Palette reduction and integer pixels keep the small item close to the
    # existing Minecraft inventory art. No smoothing or added painted details.
    image = image.quantize(colors=24, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).convert("RGBA")
    image.putalpha(alpha)
    result = Image.new("RGBA", (32, 32))
    result.alpha_composite(image, ((32-image.width)//2, (32-image.height)//2))
    return result


def generate_icons():
    prompts = json.loads((SOURCE / "prompts.json").read_text())
    missing = [e["id"] for e in prompts["items"] if not (SOURCE / (e["id"]+".png")).is_file()]
    if missing:
        raise FileNotFoundError("Missing saved icon sources: " + ", ".join(missing))
    equipment_path = ROOT / "data/chapter_four_equipment.json"
    manifest_path = ROOT / "docs/CHAPTER_FOUR_EQUIPMENT_MANIFEST.json"
    equipment = json.loads(equipment_path.read_text())
    manifest = json.loads(manifest_path.read_text())
    derived = {}
    sources = {}
    for entry in prompts["items"]:
        key = "icon_ch4_" + entry["id"]
        source = SOURCE / (entry["id"]+".png")
        path = OUT / (key+".png")
        image = pack_sprite(source)
        image.save(path)
        derived[key] = {
            "sources": [str(source.relative_to(ROOT))], "size": [32, 32],
            "sha256": digest(path), "origin": "Built-in image_gen.imagegen; vanilla Minecraft inventory reference; nearest pixels, 24-color palette, transparent alpha.",
        }
        sources[entry["id"]] = {"path": str(source.relative_to(ROOT)), "sha256": digest(source)}
    # The minecart is a vanilla item, and its exact sprite already exists.
    # IV resolves a chapter-specific icon name, so it needs that same native art.
    cart = ROOT / "assets/sprites/icon_minecart.png"
    target = OUT / "icon_ch4_minecart.png"
    target.write_bytes(cart.read_bytes())
    derived["icon_ch4_minecart"] = {
        "sources": ["assets/sprites/icon_minecart.png"], "size": [16, 16], "sha256": digest(target),
        "origin": "Unmodified vanilla Minecraft Java minecart item; MINECART_ICON_MANIFEST.json.",
    }
    manifest["derived"].update(derived)
    manifest["inventory_art"] = "docs/CHAPTER_FOUR_ICON_MANIFEST.json"
    equipment["sprites"] = list(dict.fromkeys(equipment["sprites"]+list(derived)))
    equipment_path.write_text(json.dumps(equipment, ensure_ascii=False, indent=2)+"\n")
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+"\n")
    art_manifest = {
        "tool": "image_gen.imagegen", "model": "Not exposed by the built-in tool",
        "prompt_set": "assets/art_source/ch4_icons/prompts.json", "style_reference": prompts["style_reference"],
        "edits": "assets/art_source/ch4_icons/edits.json",
        "sources": sources, "derived": derived, "generated_count": len(sources),
        "notes": "Generated inventory art requested by the user. Native world models and their textures are unchanged. Minecart remains vanilla.",
    }
    (ROOT / "docs/CHAPTER_FOUR_ICON_MANIFEST.json").write_text(json.dumps(art_manifest, ensure_ascii=False, indent=2)+"\n")
    QA.mkdir(exist_ok=True)
    arsenal = json.loads((ROOT / "data/chapter_four_arsenal.json").read_text())
    names = {key: value["name"] for group in ["weapons", "passives"] for key, value in arsenal[group].items()}
    names.update({value["icon"].removeprefix("ch4_"): value["name"] for value in arsenal["recipes"].values()})
    names["potion"] = "Зелья"
    font = ImageFont.truetype("/usr/share/fonts/TTF/DejaVuSans.ttf", 11)
    preview = Image.new("RGB", (780, ((len(derived)+4)//5)*120), (36, 36, 36))
    draw = ImageDraw.Draw(preview)
    for i, key in enumerate(derived):
        image = Image.open(OUT / (key+".png")).convert("RGBA")
        x, y = i % 5 * 156, i // 5 * 120
        large = image.resize((64, 64), Image.Resampling.NEAREST)
        preview.paste(large, (x+44, y+5), large)
        small = image.resize((16, 16), Image.Resampling.NEAREST)
        preview.paste(small, (x+16, y+51), small)
        label = names.get(key.removeprefix("icon_ch4_"), key.removeprefix("icon_ch4_"))
        words = label.split();lines = [""]
        for word in words:
            if draw.textlength((lines[-1]+" "+word).strip(),font=font)>148:lines.append(word)
            else:lines[-1]=(lines[-1]+" "+word).strip()
        draw.multiline_text((x+4,y+76),"\n".join(lines),font=font,fill="white",spacing=2)
    preview.save(QA / "icons.png")
    print("CH4_INVENTORY_ICONS", len(sources), "generated + vanilla minecart")


if __name__ == "__main__":
    generate_icons()
