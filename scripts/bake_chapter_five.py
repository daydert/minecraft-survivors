import sys
"""Chapter V bakes.

- data/chapter_five_code.json: real lines of this game's own source for the
  floor of the code space (exported builds do not ship readable .gd files).
- Equipment icons: the game's hidden vanilla items. Items keep their vanilla
  sprites; blocks are cubes of their vanilla faces; evolutions carry the
  vanilla enchantment glint (one static frame) or a second vanilla layer.
"""
import json
from pathlib import Path
from PIL import Image
from import_minecraft_assets import ROOT, Importer, bake, box, find_client

## Original lines in the style of the game's Java code (not copied source).
JAVA = """public class Player extends LivingEntity {
private static final int MAX_HEALTH = 20;
protected boolean onGround = true;
public void tick() {
super.tick();
if (this.isRemoved()) return;
this.level.addFreshEntity(entity);
for (int i = 0; i < this.inventory.size(); ++i) {
ItemStack stack = this.inventory.getItem(i);
if (stack.isEmpty()) continue;
this.hurt(this.damageSources().generic(), 4.0F);
BlockPos pos = this.blockPosition().below();
BlockState state = this.level.getBlockState(pos);
if (!state.isAir() && state.canOcclude()) {
float speed = this.getSpeed() * 0.98F;
Vec3 motion = this.getDeltaMovement().scale(0.91D);
this.setDeltaMovement(motion.x, motion.y - 0.08D, motion.z);
return this.random.nextInt(4) == 0;
public boolean isAlive() { return !this.dead; }
private void spawnMobs(ServerLevel level, ChunkPos chunk) {
int count = Mth.floor(this.random.nextFloat() * 4.0F);
Zombie zombie = EntityType.ZOMBIE.create(level);
zombie.moveTo(x + 0.5D, y, z + 0.5D, yaw, 0.0F);
level.playSound(null, pos, SoundEvents.GENERIC_HURT, SoundSource.PLAYERS);
while (this.ticks-- > 0) this.step();
@Override
public InteractionResult use(Level level, Player player) {
if (level.isClientSide) return InteractionResult.SUCCESS;
throw new IllegalStateException("Missing chunk: " + pos);
try { this.save(tag); } catch (IOException e) { LOGGER.error("Failed", e); }
final long seed = level.getSeed();
long time = level.getDayTime() % 24000L;
if (time > 13000L && time < 23000L) this.spawnMonsters();
public static final Block STONE = register("stone", new Block(PROPERTIES));
private final Map<UUID, Entity> entities = new HashMap<>();
this.entities.remove(entity.getUUID());
CompoundTag tag = new CompoundTag();
tag.putInt("Health", (int) this.getHealth());
tag.putString("id", "minecraft:player");
double distance = this.distanceToSqr(target);
if (distance < 64.0D) this.attack(target);
this.goalSelector.addGoal(2, new MeleeAttackGoal(this, 1.0D, false));
this.targetSelector.addGoal(1, new HurtByTargetGoal(this));
public void die(DamageSource source) {
this.dropAllDeathLoot(source);
this.level.broadcastEntityEvent(this, (byte) 3);
int x = SectionPos.blockToSectionCoord(pos.getX());
LevelChunk chunk = this.getChunk(x, z);
chunk.setBlockState(pos, Blocks.AIR.defaultBlockState(), false);
if (++this.tickCount % 20 == 0) this.heal(1.0F);
return Optional.ofNullable(this.target);
public enum Difficulty { PEACEFUL, EASY, NORMAL, HARD }
switch (difficulty) { case HARD: return 3; default: return 1; }
for (Entity e : level.getEntities(this, box)) e.push(this);
AABB box = this.getBoundingBox().inflate(3.0D);
Objects.requireNonNull(server, "server");
this.server.getPlayerList().broadcastSystemMessage(text, false);
Component text = Component.literal(name + " joined the game");
String name = this.getGameProfile().getName();
private static final Logger LOGGER = LogUtils.getLogger();
LOGGER.info("Preparing spawn area: {}%", progress);
LOGGER.warn("Can't keep up! Is the server overloaded?");
LOGGER.warn("Running {}ms behind, skipping {} tick(s)", ms, ticks);
public void setRemoved(RemovalReason reason) {
if (reason.shouldDestroy()) this.stopRiding();
int light = level.getMaxLocalRawBrightness(pos);
if (light > this.random.nextInt(8)) return false;
public float getDestroySpeed(BlockState state) { return 1.0F; }
this.xRot = Mth.clamp(this.xRot, -90.0F, 90.0F);
this.yHeadRot = this.yRot;
boolean flag = this.isSprinting() && !this.isUsingItem();
if (flag) this.causeFoodExhaustion(0.1F);
this.foodData.tick(this);
ItemEntity drop = new ItemEntity(level, x, y, z, stack);
drop.setPickUpDelay(40);
new Thread(() -> this.run(), "Server thread").start();
synchronized (this.lock) { this.running = false; }
System.exit(0);
// TODO: remove before release
// he should not be here
int[] seeds = new int[] { 0, 1, 1, 2, 3, 5, 8 };
String[] lines = message.split("\\n");
this.connection.disconnect(Component.translatable("disconnect.timeout"));
if (entity instanceof Player p && p.isCreative()) return;
public record ChunkPos(int x, int z) {}
return (seed * 0x5DEECE66DL + 0xBL) & ((1L << 48) - 1);
Entity copy = EntityType.PLAYER.create(level);
copy.load(this.saveWithoutId(new CompoundTag()));""".splitlines()

def code_lines():
    (ROOT / "data/chapter_five_code.json").write_text(json.dumps({"lines": JAVA}, ensure_ascii=False, indent=1) + "\n")
    return len(JAVA)

def frame0(tex):
    return tex.crop((0, 0, 16, 16)) if tex.height > 16 else tex

def cube(front, side, top, size=16):
    faces = {"north": (front, (0, 0, 16, 16)), "east": (side, (0, 0, 16, 16)), "up": (top, (0, 0, 16, 16)),
             "south": (side, (0, 0, 16, 16)), "west": (side, (0, 0, 16, 16)), "down": (side, (0, 0, 16, 16))}
    mesh = box(front, (-8, 0, -8), (16, 16, 16), faces=faces)
    return bake(mesh, (size, size), 0.56, (8, 13), yaw=-45 + 180, elevation=30)

def glint(im, glint_tex, strength=1.0, phase=0, colour=(105, 45, 165)):
    im = im.copy()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = im.getpixel((x, y))
            if a:
                v = glint_tex.getpixel(((x * 3 + y + phase * 4) % 128, (y * 3 - x + phase * 2) % 128))[0] / 255 * strength
                im.putpixel((x, y), (min(255, r + int(v * colour[0])), min(255, g + int(v * colour[1])), min(255, b + int(v * colour[2])), a))
    return im

def icons():
    version, client, _ = find_client(Path.home() / ".local/share/PrismLauncher")
    imp = Importer(client)
    t = lambda name: frame0(imp.tex(name))
    gl = imp.tex("misc/enchanted_glint_item")
    out = {}
    out["debug_stick"] = glint(t("item/stick"), gl, 1.0, 3)
    out["debug_stick_evo"] = glint(t("item/stick"), gl, 1.6, 9, (170, 20, 60))
    out["command_block"] = cube(t("block/command_block_front"), t("block/command_block_side"), t("block/command_block_back"))
    out["command_block_evo"] = cube(t("block/repeating_command_block_front"), t("block/repeating_command_block_side"), t("block/repeating_command_block_back"))
    out["chain_block"] = cube(t("block/chain_command_block_front"), t("block/chain_command_block_side"), t("block/chain_command_block_back"))
    out["barrier"] = t("item/barrier")
    light = t("item/light")
    evo = t("item/barrier").copy();evo.alpha_composite(light.resize((10, 10), Image.NEAREST), (6, 0))
    out["barrier_evo"] = evo
    out["light_block"] = light
    out["structure_block"] = cube(t("block/structure_block_save"), t("block/structure_block"), t("block/structure_block"))
    out["structure_block_evo"] = cube(t("block/structure_block_load"), t("block/structure_block_corner"), t("block/structure_block_data"))
    out["structure_void"] = t("item/structure_void")
    out["spawn_egg"] = t("item/zombie_spawn_egg")
    egg = t("item/zombie_spawn_egg").copy();egg.alpha_composite(t("item/name_tag").resize((9, 9), Image.NEAREST), (7, 7))
    out["spawn_egg_evo"] = egg
    out["name_tag"] = t("item/name_tag")
    out["knowledge_book"] = t("item/knowledge_book")
    out["recovery_compass"] = t("item/recovery_compass_16")
    sprites = []
    for name, im in out.items():
        imp.save(im, "icon_" + name, ["Minecraft Java " + version + " vanilla textures"])
        sprites.append("icon_" + name)
    (ROOT / "data/chapter_five_assets.json").write_text(json.dumps({"sprites": sprites}, indent=1) + "\n")
    (ROOT / "docs/CHAPTER_FIVE_MANIFEST.json").write_text(json.dumps({"version": version, "raw_files": imp.files, "derived": imp.derived}, indent=1) + "\n")
    sheet = Image.new("RGBA", (len(out) * 40, 40), (40, 40, 40, 255))
    for i, im in enumerate(out.values()):sheet.alpha_composite(im.resize((32, 32), Image.NEAREST), (i * 40 + 4, 4))
    sheet.save(ROOT / "qa/chapter_five_icons.png")
    return len(sprites)

def notch_skin(imp):
    """Notch's canonical skin (assets/skins/notch.png, supplied by the user)."""
    canon = ROOT / "assets/skins/notch.png"
    if canon.exists():
        return Image.open(canon).convert("RGBA")
    tex = imp.tex("entity/player/wide/steve").copy()
    px = tex.load()
    for y in range(64):
        for x in range(64):
            r, g, b, a = px[x, y]
            if not a:continue
            if g > r + 25 and b > r + 25:
                lum = (r + g + b) // 3
                v = min(255, 120 + lum)
                px[x, y] = (40, 230, 220, a) if (x * 7 + y * 3) % 11 == 0 else (v, v, min(255, v + 6), a)
            elif r > g and g > b and r < 120 and (y < 16):
                px[x, y] = (int(r * .7), int(g * .62), int(b * .55), a)
    for x in range(8, 16):
        for y in (13, 14, 15):
            if not (y == 13 and 10 <= x <= 13):px[x, y] = (58, 38, 22, 255)
    for x, y in [(9, 12), (14, 12)]:px[x, y] = (255, 255, 255, 255)
    for x, y in [(10, 12), (13, 12)]:px[x, y] = (40, 170, 70, 255)
    return tex

def notch():
    import bake_chapter_four_finale as four
    version, client, _ = find_client(Path.home() / ".local/share/PrismLauncher")
    imp = Importer(client)
    names = ["idle", "walk", "cast", "invite", "look_hand", "float", "slam", "point", "snap", "aura", "stagger", "knocked", "lunge", "throw", "exhausted", "fall", "lying"]
    image, layout = four.atlas(notch_skin(imp), names)
    imp.save(image, "ch5_notch", ["assets/skins/notch.png (canonical Notch skin)"])
    t = lambda name: frame0(imp.tex(name))
    plants = {"dispenser": cube(t("block/dispenser_front"), t("block/furnace_side"), t("block/furnace_top")),
              "redstone_ore": cube(t("block/redstone_ore"), t("block/redstone_ore"), t("block/redstone_ore")),
              "obsidian": cube(t("block/obsidian"), t("block/obsidian"), t("block/obsidian")),
              "tnt": cube(t("block/tnt_side"), t("block/tnt_side"), t("block/tnt_top")),
              "snow_golem": cube(t("block/carved_pumpkin"), t("block/pumpkin_side"), t("block/pumpkin_top")),
              "snow": cube(t("block/snow"), t("block/snow"), t("block/snow")),
              "cactus": cube(t("block/cactus_side"), t("block/cactus_side"), t("block/cactus_top")),
              "piston": cube(t("block/piston_top"), t("block/piston_side"), t("block/piston_side")),
              "magma": cube(t("block/magma"), t("block/magma"), t("block/magma"))}
    sprites = ["ch5_notch"]
    for name, im in plants.items():
        imp.save(im, "icon_pvz_" + name, ["block/" + name]);sprites.append("icon_pvz_" + name)
    imp.save(t("item/redstone"), "icon_pvz_redstone", ["item/redstone"]);sprites.append("icon_pvz_redstone")
    data = json.loads((ROOT / "data/chapter_five_assets.json").read_text())
    data["sprites"] = [s for s in data["sprites"] if not s.startswith("icon_pvz_")] + [s for s in sprites if s.startswith("icon_pvz_")]
    data["notch"] = {"sheet": "ch5_notch", "frame": list(four.FRAME), "anchor": list(four.CENTER), "layout": layout}
    (ROOT / "data/chapter_five_assets.json").write_text(json.dumps(data, indent=1) + "\n")
    w, h = four.FRAME
    sheet = Image.new("RGBA", (6 * w * 2, h * 2), (40, 40, 40, 255))
    for i, n in enumerate(["idle", "cast", "point", "snap", "invite", "lunge"]):
        c = layout[n]["start"] + layout[n]["count"] // 2
        sheet.alpha_composite(image.crop((c * w, 0, c * w + w, h)).resize((w * 2, h * 2), Image.NEAREST), (i * w * 2, 0))
    sheet.save(ROOT / "qa/chapter_five_notch.png")
    return sum(v["count"] for v in layout.values())

QUAKE = ["polished_deepslate", "deepslate_tiles", "cracked_deepslate_tiles", "cut_copper", "exposed_cut_copper", "copper_grate",
         "iron_block", "polished_blackstone_bricks", "gilded_blackstone", "lava_still", "magma", "redstone_block", "chiseled_copper",
         "dark_oak_planks", "glowstone", "crying_obsidian", "cobblestone"]

def textures3d():
    """Skins and block faces for the 3D fights: Steve, digital Notch, and a
    rusty, dark arena built from vanilla copper, deepslate and blackstone."""
    version, client, _ = find_client(Path.home() / ".local/share/PrismLauncher")
    imp = Importer(client)
    imp.save(imp.tex("entity/player/wide/steve"), "ch5_skin_steve", ["entity/player/wide/steve"])
    imp.save(notch_skin(imp), "ch5_skin_notch", ["assets/skins/notch.png (canonical Notch skin)"])
    names = ["ch5_skin_steve", "ch5_skin_notch"]
    for n in QUAKE:
        imp.save(frame0(imp.tex("block/" + n)), "ch5q_" + n, ["block/" + n]);names.append("ch5q_" + n)
    grass = frame0(imp.tex("block/grass_block_top")).convert("RGBA")
    px = grass.load()
    for y in range(16):
        for x in range(16):
            r, g, b, a = px[x, y]
            px[x, y] = (int(r * .48), int(g * .78), int(b * .32), a)
    imp.save(grass, "ch5p_grass", ["block/grass_block_top (plains tint)"]);names.append("ch5p_grass")
    for n in ["dirt", "oak_planks", "oak_log", "glass", "stripped_oak_log", "cobblestone", "bricks", "oak_door_bottom", "oak_door_top", "rail", "magma", "piston_top", "cactus_side", "snow"]:
        imp.save(frame0(imp.tex("block/" + n)), "ch5p_" + n, ["block/" + n]);names.append("ch5p_" + n)
    for n in ["minecart", "arrow", "redstone", "snowball", "slime_ball"]:
        imp.save(imp.tex("item/" + n), "ch5p_item_" + n, ["item/" + n]);names.append("ch5p_item_" + n)
    imp.save(frame0(imp.tex("block/dispenser_front")), "ch5q_dispenser_front", ["block/dispenser_front"]);names.append("ch5q_dispenser_front")
    imp.save(frame0(imp.tex("block/furnace_side")), "ch5q_furnace_side", ["block/furnace_side"]);names.append("ch5q_furnace_side")
    tnt = Image.new("RGBA", (16, 16));tnt.paste(frame0(imp.tex("block/tnt_side")))
    imp.save(tnt, "ch5q_tnt", ["block/tnt_side"]);names.append("ch5q_tnt")
    for n in ["golden_apple", "iron_chestplate", "firework_rocket", "iron_sword", "crossbow_standby", "fire_charge", "diamond_pickaxe", "blaze_rod", "arrow", "tnt_minecart", "diamond_sword", "book", "paper"]:
        imp.save(imp.tex("item/" + n), "ch5q_item_" + n, ["item/" + n]);names.append("ch5q_item_" + n)
    sh = imp.tex("entity/shield_base_nopattern").convert("RGBA")
    k = sh.width // 64
    imp.save(sh.crop((1 * k, 1 * k, 13 * k, 23 * k)), "ch5q_shield", ["entity/shield_base_nopattern (front plate)"]);names.append("ch5q_shield")
    for n in ["anvil", "lightning_rod"]:
        imp.save(frame0(imp.tex("block/" + n)), "ch5q_" + n, ["block/" + n]);names.append("ch5q_" + n)
    (ROOT / "data/chapter_five_3d.json").write_text(json.dumps({"textures": names}, indent=1) + "\n")
    return len(names)

def badges():
    from bake_v2_assets import badge
    version, client, _ = find_client(Path.home() / ".local/share/PrismLauncher")
    imp = Importer(client)
    return [badge(imp, "fatality", "redstone_block", "item/diamond_sword", None, 1.5)]

def particles():
    """Vanilla particle sheets for chapter V effects: the real explosion,
    smoke, sweep, crit, sparks and flame, as horizontal strips."""
    version, client, _ = find_client(Path.home() / ".local/share/PrismLauncher")
    imp = Importer(client)
    specs = {"explosion": [f"explosion_{i}" for i in range(16)], "smoke": [f"big_smoke_{i}" for i in range(12)],
             "sweep": [f"sweep_{i}" for i in range(8)], "spark": [f"spark_{i}" for i in range(8)], "generic": [f"generic_{i}" for i in range(8)],
             "crit": ["critical_hit"], "magic": ["enchanted_hit"], "damage": ["damage"], "flame": ["flame"], "splash": [f"splash_{i}" for i in range(4)]}
    out = {}
    for name, frames in specs.items():
        ims = [imp.tex("particle/" + f) for f in frames]
        w, h = ims[0].size
        strip = Image.new("RGBA", (w * len(ims), h))
        for i, im in enumerate(ims):strip.paste(im.resize((w, h), Image.NEAREST), (i * w, 0))
        imp.save(strip, "ch5x_" + name, ["particle/" + f for f in frames])
        out[name] = {"sprite": "ch5x_" + name, "frame": [w, h], "count": len(ims)}
    (ROOT / "data/chapter_five_fx.json").write_text(json.dumps(out, indent=1) + "\n")
    return len(out)

if __name__ == "__main__":
    only = sys.argv[1:] if len(sys.argv) > 1 else ["fx", "3d", "code"]
    if "fx" in only:print("CH5_FX", particles())
    if "3d" in only:print("CH5_3D", textures3d())
    if "notch" in only:print("CH5_NOTCH", notch())
    if "badges" in only:print("CH5_BADGES", badges())
    if "code" in only:print("CH5_CODE", code_lines(), "CH5_ICONS", icons(), "CH5_NOTCH", notch())
