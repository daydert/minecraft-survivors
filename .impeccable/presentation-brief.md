# Minecraft HUD and character stats

User direction: original Minecraft appearance, less colorful UI, vanilla hearts,
the real Minecraft font, and a black character-stat screen on physical L.
Existing Godot desktop game, fixed 640×360 viewport with integer scaling.
Mode: Operate within the existing gameplay experience. Code-led scoped update;
no generated comps or alternate identity exploration. User supplied the world.

Authority: the installed Minecraft Java 1.21.11 GUI sprites and bitmap providers.
Gray beveled buttons, white and gray pixel text with a black pixel shadow,
black/dark gray panels; only health red, XP green and item art use color.
Fonts at whole multiples of 8; nearest sampling, no font smoothing.

HUD: ten vanilla hearts at their real 9×9 size/8 px stride above the bottom
equipment bars, native experience sprites and level number, two six-slot bars
adapted from the vanilla hotbar; minimal text at the top.

Stats: opaque black full viewport, truthful live attributes from the balance
formulas, six weapons and six passives, empty inventory state, readable Russian.
L or Esc restores the exact prior gameplay state and preserves paused time.

Audio: user MusicForGame.mp3 track converted from its actual AAC encoding to OGG,
complete 320-second track loops. All sound effects are unmodified local Minecraft
OGGs, including mob-specific hurt, weapon, pickup and UI variants. No generated
WAVs remain. Audio variants use a separate RNG from the combat simulation.

Review: native desktop only; capture the 640×360 logical output and 1280×720
integer-scaled stats. No HTML/CSS detector applies to this Godot renderer.
