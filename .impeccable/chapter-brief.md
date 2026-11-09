# Chapter I — user-directed native Minecraft update

Mode: Experience (gameplay/ending), Operate (minimal menu). Existing Godot desktop
world and Minecraft UI are retained; this is a code-led extension with original
vanilla textures, not a new visual identity. No generated comp.

User requirements:

- Start menu: only the name **Minecraft Survivors**, plus functional controls;
  remove taglines, subtitle, promotional text and demo badge.
- Replace Steve and all mobs with original Minecraft appearance and animations.
- Add a vindicator (поборник), including an axe and a readable melee attack.
- Surviving to the end of location one starts Herobrine's unavoidable defeat
  scene at the center of the map. He sits on a throne with Steve heads and two
  burning netherrack pillars, in a relaxed seated/crossed-leg pose like the
  supplied reference. White eyes, visible complete torso, head and limbs.
- Lightning attacks the map; trees lose their foliage; overwhelming fire waves
  consume the location. Player must lose. Portal opens under the defeated
  player; he falls into the Nether as a future-location teaser.
- User clarified that Herobrine trees are **only bare vertical trunks**, with
  no branches at all. The branch geometry has been removed from every variant.
- Boss music is the supplied /home/daydert/Downloads/audio_2026-10-27_17-30-49.ogg:
  original 79.962-second Vorbis bytes copied unchanged. A separate player fades
  this track in at Herobrine arrival; normal music returns on menu/new run.

The user noticed a missing-looking torso during work. Root cause was moving
only four mesh faces instead of all faces of the head/body in the seated pose.
This is fixed, with an image-level torso visibility regression check.

Implementation: original local Minecraft 1.21.11 UV textures on cuboid meshes,
baked by scripts/bake_minecraft_characters.py into the existing 3x22 atlases.
Herobrine uses Steve with white-eye pixels and a custom seated pose. Four Steve
heads and two flame sockets are baked into herobrine_throne.png. New model art
keeps nearest sampling and whole pixels; slime retains a translucent shell.

Timeline after 12:00: arrival 0–4s; storm 4–13s; inferno 13–24s; collapse at 24s;
portal 26–29s; fall 29–34s; chapter-end Nether teaser. Player can move and attack
during storm/inferno. Pause/L freeze this clock. Armor or debug invulnerability
cannot bypass scripted defeat. Earlier ordinary deaths retain normal retry.

Review the native 640x360 captures under .impeccable/review/chapter_*.png,
chapter_arrival_2x.png (actual 1280x720 framebuffer), and
herobrine_throne_4x.png (explicit nearest enlargement for inspecting the torso).
Native Godot/GDScript only; HTML/CSS detector and browser/mobile rules do not apply.
