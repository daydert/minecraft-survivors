---
name: "Minecraft Survivors — До рассвета: game interface"
description: "Native Minecraft bitmap text, restrained gray controls, vanilla HUD sprites, and a black character sheet."
colors:
  text: "#ffffff"
  text-muted: "#aaaaaa"
  text-soft: "#dddddd"
  text-bright: "#eeeeee"
  black: "#000000"
  charcoal: "rgb(14% 14% 14%)"
  frame: "#777777"
  divider: "#555555"
  divider-dark: "#333333"
  icon-well: "#151515"
  experience-level: "#80ff20"
  heart-fill: "#ff1313"
typography:
  display:
    fontFamily: "Minecraft bold"
    fontSize: "32px"
    fontWeight: 700
  headline:
    fontFamily: "Minecraft bold"
    fontSize: "24px"
    fontWeight: 700
  title:
    fontFamily: "Minecraft bold"
    fontSize: "16px"
    fontWeight: 700
  body:
    fontFamily: "Minecraft regular"
    fontSize: "8px"
    fontWeight: 400
  label-bold:
    fontFamily: "Minecraft bold"
    fontSize: "8px"
    fontWeight: 700
rounded:
  square: "0px"
spacing:
  frame-stroke: "1px"
  texture-margin: "2px"
  heart-step: "8px"
  stat-row-step: "15px"
  slot-step: "20px"
  weapon-row-step: "26px"
components:
  button:
    textColor: "{colors.text}"
    typography: "{typography.label-bold}"
    rounded: "{rounded.square}"
    width: "226px"
    height: "25px"
  button-active:
    textColor: "{colors.text}"
    typography: "{typography.label-bold}"
    rounded: "{rounded.square}"
    width: "226px"
    height: "25px"
  window-panel:
    backgroundColor: "{colors.charcoal}"
    rounded: "{rounded.square}"
  health-row:
    width: "81px"
    height: "9px"
  experience-bar:
    width: "256px"
    height: "5px"
  equipment-bar:
    width: "122px"
    height: "22px"
  character-stats:
    backgroundColor: "{colors.black}"
    textColor: "{colors.text}"
    typography: "{typography.body}"
    rounded: "{rounded.square}"
    width: "640px"
    height: "360px"
---

# Design System: Minecraft Survivors — До рассвета

## Overview

**Creative North Star: "The vanilla Minecraft interface"**

This document captures the HUD, typography, shared controls, character sheet, and scoped Chapter I extension (0.5) in the existing native Godot game. The visual authority is the user's requested Minecraft appearance and the local Minecraft Java 1.21.11 textures, GUI sprites, and bitmap providers. It records the shipped implementation, rather than establishing a separate product identity.

Dense pixel information uses white and gray text over charcoal or black. Native hearts, experience, and item art carry their existing color meanings. The character sheet is an opaque black interruption of the arena, with live attributes, equipment, and a direct return to the prior game state.

The start menu contains only “Minecraft Survivors” and three functional buttons. Actors now use vanilla texture UVs on animated cuboids baked into the existing 2D atlas format. Chapter I extends this same world with Herobrine's throne, a burning arena, and a Nether teaser; its dramatic color belongs to the scene rather than the shared interface.

**Key Characteristics:**

- Original Minecraft bitmap glyphs, including Russian text.
- Gray beveled controls and square monochrome frames.
- Native heart, experience, and hotbar-derived equipment sprites.
- A fixed logical viewport with integer scaling and nearest sampling.
- An opaque black character sheet that preserves the interrupted state.
- Vanilla-textured cuboid actors and a deterministic, unavoidable Chapter I ending.

## Colors

The interface palette is neutral; color is concentrated in health, experience, and the existing game art. The frontmatter is normative for extracted values; textures own their additional pixel shades.

### Primary

- **Experience Level Green** (`experience-level`): the small level number above the experience bar. The bar itself uses the original progress texture and its own green shades.
- **Vanilla Heart Red** (`heart-fill`): the main full-heart fill sampled from the original heart sprite. Use the full, half, empty, and blinking assets; this swatch is not a replacement drawing recipe.

### Neutral

- **White** (`text`): primary labels, values, and button text.
- **Muted Gray** (`text-muted`): supporting text, stat names, secondary counters, and frame highlights.
- **Soft Gray** (`text-soft`) and **Bright Gray** (`text-bright`): retained emphasis levels for messages and headings. The legacy source identifiers `GOLD` and `LIME` resolve to these neutral colors.
- **Black** (`black`): the entire character-stat screen, frame edges, text shadows, and dimming overlays.
- **Charcoal** (`charcoal`): shared window interiors; callers may retain an opacity value.
- **Frame Gray**, **Divider Gray**, and **Dark Divider Gray** (`frame`, `divider`, `divider-dark`): square window outlines and character-sheet separators.
- **Icon Well** (`icon-well`): the dark item background within upgrade choices.

**The Semantic Color Rule.** Keep interface chrome neutral. Preserve the original color of health, experience, and item art instead of adding decorative accents to controls or panels.

## Typography

**Body Font:** `Minecraft regular`, loaded from `assets/fonts/minecraft/minecraft_regular.fnt`.

**Heading and Button Font:** `Minecraft bold`, loaded from `assets/fonts/minecraft/minecraft_bold.fnt`. Bold is a prepared bitmap face made from the same native glyph masks, not a smoothed substitute font.

The source atlases and BMFont bearings and advances are authoritative. Both faces have an 8 px base size, 9 px native line metric, and smoothing disabled. `text_at()` rounds the baseline position, draws a black shadow, and then draws the foreground glyphs.

### Hierarchy

- **Display:** the large menu title.
- **Headline:** major overlay headings such as pause, level-up, and result.
- **Title:** the character-sheet heading, timer, and medium emphasis.
- **Body:** HUD counters, Russian descriptions, values, and hints.
- **Bold label:** buttons and small section labels.

`pixel_font_size()` rounds requested sizes to the nearest whole multiple of the 8 px base, with a minimum of 8 px. Actual output sizes are 8, 16, 24, and 32 logical pixels. Wrapped descriptions advance by the actual font size plus 5 logical pixels; character stats and weapon rows use their own fixed baseline steps.

**The Whole Pixel Rule.** Preserve bitmap glyphs and whole base-size multiples. The black shadow offset is one logical pixel per 8 px of text size; use nearest sampling throughout.

## Layout

All interface measurements are logical viewport pixels. `project.godot` fixes the viewport at 640 × 360, with a 1280 × 720 default window, a 640 × 360 minimum, viewport stretching, and integer scale mode. There are no responsive breakpoints or mobile rearrangements in this implementation. A larger window scales the same composition by whole factors.

The start menu centers the title at baseline y = 122. “Играть”, “Настройки”, and “Выход” use 242 × 29 buttons beginning at (199, 179), with a 40 px vertical step, over the dimmed arena. This surface has no subtitle, tagline, promotional copy, or demo badge.

The HUD keeps counters in the upper left, the timer centered at the top, and the pause hint in the upper right. Bottom equipment uses two separate six-slot bars, one for weapons and one for passives, beginning at (192, 332) and (326, 332). Icons are 16 × 16 with a 20 px slot step. Ten heart containers begin at (192, 310), using native 9 × 9 sprites on an 8 px step. The experience track begins at (192, 323), spans 256 × 5, and has a centered level number above it.

The character sheet occupies the full viewport. Its header uses a 22 px left inset and a top-right close button. A divider at y = 59 separates the header. Character identity and eight attribute rows occupy the left; up to six weapon rows occupy the right, separated by a vertical rule at x = 282. Attribute baselines advance by 15 px and weapon rows by 26 px. A rule at y = 272 separates the six passive-item positions, spaced 100 px apart. The return hint sits at the bottom. These are measured surface placements, not a general-purpose spacing scale for new screens.

## Elevation & Depth

Depth is pixel-based: black outer edges, a gray inner frame, a light top edge, and the original beveled button textures. Text uses a hard black offset shadow. Shared overlays dim the still-visible arena; the stats screen replaces it with opaque black. There are no soft interface shadows, blur, or animated elevation transitions.

## Shapes

Panels, dividers, wells, and controls have square corners and hard pixel edges. `panel()` draws a black rectangle, an inset charcoal fill, a one-pixel gray outline, and a short top highlight. Legacy color and border arguments do not change this monochrome frame. Buttons use the original `gui_button` / `gui_button_active` textures through a `StyleBoxTexture` with 2 px texture margins on every edge.

## Components

### Buttons

Tactile gray Minecraft bevels with centered white bitmap labels. Rectangles vary by screen; the frontmatter records the pause-menu size as a representative used variant. The active texture represents the current `selected` index, shared by mouse hover and keyboard navigation. Arrow keys and Tab move selection; Enter or Space activates it. State changes are immediate. There is no separate pressed animation or disabled style in this update.

### Window panels and upgrade choices

Shared panels retain a consistent monochrome frame across menu, settings, pause, reward, and result screens. Upgrade choices use that frame around a native item icon, small state label, title, and wrapped description. Their selected state adds the bright gray bottom strip. Arena dimming and occasional panel opacity preserve scene context.

### Health row

Ten original heart containers represent the 20 HP capacity. Each slot overlays a full or half heart according to clamped `ceil(hp) - slot * 2`. Empty slots remain visible. While invulnerable, full and half hearts use their original blinking variants when flashes are enabled; the blink reads the simulation clock.

### Experience bar

The original background and progress sprites are rendered across the HUD's wider track. Progress is `clamp(xp / required_xp(level), 0, 1)`, with integer fill width. The green level label remains separate from the texture. Experience required is supplied by `GameData.required_xp()`.

### Equipment bars

Two six-slot bars are adapted from the original hotbar. Weapons and passives remain separate collections. Native 16 px item icons and white level numbers sit within the slots; the weapon matching `player_visual.weapon` gets the original selection frame. Evolved item art retains the existing enchantment animation. The bars are inventory displays, without click-to-equip behavior.

### Character stats

Physical L, the HUD's stats hit area, or the pause-menu button opens the black sheet from running, paused, level-up, chest, or finale state. Opening records the exact prior world state and pauses the simulation, including the finale clock. L, Esc, or “Готово (L)” closes it and restores that state. Stats are not available from the main menu or result screen.

The left column reads health, movement speed, damage bonus, attack interval reduction, attack size bonus, protection, experience pickup radius, and current experience. `character_stats()` reads the same values used by the simulation: sugar adds 8% movement speed per level; blaze adds 10% damage; redstone reduces intervals by 6%; amethyst adds 10% attack radius; armor subtracts 0.2 HP per hit with a minimum of 1 HP damage; hopper adds 30% to the base 24 px pickup radius. Keep these tied to balance data and combat formulas when changing the game.

Each owned weapon displays its real level, evolved name/icon when applicable, and damage, interval, and radius from `GameData.stats()`. The passive row shows owned items and their levels out of five; an empty collection displays “Пока нет предметов”. In-run item animation reads the paused simulation clock. This sheet presents the current build rather than projected upgrade values.

### Actors and Chapter I scenery

`scripts/bake_minecraft_characters.py` projects cuboid models with original local Minecraft 1.21.11 UV textures into the established three-direction, 22-frame atlases. Steve and every mob use this path, including the vindicator (поборник) with an axe and visible attack preparation. Earlier imagegen anchors remain historical sources and do not supply the current actor atlases. Keep whole-pixel output, nearest sampling, readable attack poses, and the slime's translucent shell.

Herobrine uses Steve's skin with custom white eyes and a relaxed seated, crossed-leg pose. The throne contains four Steve heads and two burning netherrack pillars. Head, complete torso, arms, and legs must remain visible; seated transforms move every face of each affected cuboid. Every scorched tree variant is a single bare vertical trunk, without foliage or branches.

### Chapter I ending and music

Surviving to 12:00 starts a 34-second scene at the map center: arrival (0–4 s), lightning storm (4–13 s), fire waves (13–24 s), collapse (24–26 s), portal (26–29 s), and fall (29–34 s), followed by the Nether chapter-end screen. The camera establishes the throne before following the player. Movement and attacks remain available during storm and inferno; collapse is an authored defeat that armor and invulnerability cannot prevent. Pause and the character sheet freeze the scene clock and animations. Keep this scene deterministic without consuming combat RNG.

The ending uses the supplied OGG copied unchanged as `assets/audio/music_herobrine.ogg`. A separate audio player crossfades from the normal track over 0.9 seconds at Herobrine's arrival; menu and retry restore normal music. Music continues independently of the paused simulation. The Nether screen uses the existing neutral typography and gray “Начать заново” / “В меню” buttons.

## Do's and Don'ts

### Do:

- **Do** reuse the original GUI sprites and prepared Minecraft bitmap fonts.
- **Do** keep all layout coordinates in the 640 × 360 logical viewport and preserve integer scaling.
- **Do** use white and gray for interface chrome while retaining semantic health, experience, and item colors.
- **Do** derive displayed attributes and weapon values from the same data and formulas as combat.
- **Do** preserve the exact interrupted state and frozen run time when opening and closing character stats.
- **Do** preserve the complete seated Herobrine silhouette and use only branchless vertical trunks for the scorched trees.

### Don't:

- **Don't** replace native hearts or bitmap text with emoji, vector approximations, or smoothed substitute fonts in the game.
- **Don't** introduce colorful panel themes, rounded cards, gradients, or soft interface shadows into this scoped system.
- **Don't** treat legacy `GOLD`, `LIME`, or panel color arguments as permission to restore colored interface chrome.
- **Don't** stretch the viewport or font glyphs by fractional display factors.
- **Don't** hard-code example stats or advance the simulation while the character sheet is open.
- **Don't** mix historical imagegen actor anchors into the current vanilla-textured atlas pipeline.
# Кооп 0.6.1

В главном меню четыре одинаковые серые Minecraft-кнопки: «Играть»,
«Мультиплеер», «Настройки», «Выход». Экран мультиплеера использует тот же
пиксельный шрифт и кнопки; поля «Ник» и «IP ZeroTier» чёрные с серой рамкой.
В комнате до четырёх ников, счётчик мест, статус и необходимые кнопки. Дополнительных
лозунгов и декоративных панелей нет. Ники в мире — белый Minecraft-текст
на небольшой полупрозрачной чёрной подложке над головой.

Кооп на 2–4 игроков, один ведущий, фиксированный двойной спавн и одна жизнь на героя. После
смерти — наблюдение за выжившим. Общая пауза сохраняет смысл Esc, L,
улучшений и сундуков. Полные правила и сетевой контракт: docs/COOP_UPDATE.md.
Три строки товарищей в HUD не перекрываются; начальные и сюжетные позиции
разнесены для четырёх героев. Начать можно с любого числа участников от двух
до четырёх. Никаких новых лозунгов или дополнительных панелей.


## Chapter II solo extension (0.7.0)

The existing fonts, gray buttons, square panels, native hearts and experience
remain authoritative. Play now opens chapter selection; the main menu retains
exactly four controls. Solo equipment uses six weapon and eight passive slots,
centered as 122 + 12 + 162 px bars, with a 296 px XP bar. Coop retains its
previous six/six display. I opens an opaque black inventory with delete actions,
level counts and a recipe book; I/Esc restores the exact interrupted state.

Material tools display iron at I–III, diamond at IV–VII and netherite at VIII;
armor uses I–II / III–IV / V. Nether terrain and nine new actors are vanilla
texture projections using the existing CPU pipeline. Neutral piglins display
the native golden-boots icon. Fire, marked blast circles, boss aim lines,
spinning hoes and placed explosives read only paused simulation time.

Volume controls are gray minus/plus buttons, in ten-percent increments over
0–100%. The chapter-two ending enters a native end-stone scene with Steve,
“Край” and “Продолжение следует”. Full rules and validation are recorded in
[CHAPTER_TWO_UPDATE.md](docs/CHAPTER_TWO_UPDATE.md).

## User revisions, 0.7.1

Use concise functional text. Remove instructional footers, pause explanations,
material-tier announcements and defeat slogans. The pause menu contains only
its title and four actions. Recipe cards show effects beneath the icon equation.
Do not repeat the passive ingredient's name as its card description.

Do not draw radius guides for ordinary weapons, magma, beds or common mobs.
Boss cues may mark a future attack so the player can dodge. The Wither has
larger native-textured geometry, unique casting/dashing/roaring/death poses,
predictive attacks and soul effects. Cinematics communicate the arena change,
pearl throw, frame activation, jump and arrival in the End without tutorials.
The active portal is distinguished by its revealed star field and moving motes.

## Boss duels, 0.8.0

Solo Herobrine has an ordinary damageable first stage. Two physical gaps in
each fire ring match the rendered openings. A second stage follows the win:
articulated rise, teleport, kneeling and a crimson gravitational distortion,
then darkness and the established Nether fall. The throne retains four heads,
two fire pillars and the visible torso. The Compatibility screen shader uses
simulation time, freezes on pause and returns to the same frame on resume.
Legacy coop rendering and its compulsory timed finale remain separate.

The Wither's denser second phase uses curved volleys with escape lanes.
Its dash has sound and body animation as cues, without a drawn direction.
Predicted soul-fire marks are brief; three staggered ignitions precede a line
of three. Camera framing holds the midpoint with a dead zone, yielding toward
the player only at long range. The portal ingredient is the native Eye of Ender.

Gold boots retain piglin neutrality and reduce the actual soul-sand movement
penalty. Exactly half the healing containers are preselected at generation,
using a separate random stream. Boss wins play the supplied stinger followed
by the looping victory song; location and menu changes clear that context.

## Boss polish, 0.8.1

Both outcomes of solo Herobrine's optional first stage lead through the story
portal into the Nether. Winning reveals the full second-stage ritual. Its
blood distortion expands beyond the viewport, then a black radial wave from
the same center clears it smoothly. Shader and clearing wave share simulation
time and retain the exact paused frame. Herobrine's theme continues through
both routes; only the true Wither win plays the victory stinger and music.

Fishing uses actual pull movement followed by stun, including bosses. Bosses
have brief resistance against repeated control. Withering is shown by original
Minecraft withered hearts, and magma cream reduces both status damage types.
The Wither launches four orbital heads every four seconds. Crossing streams
replace permanent safe sectors; fire receives an extra 150 ms warning.

Arena walls and floor use a shared unscaled 16px tile grid, all four edges
complete. The bed rotates the original 16x16x6 UV geometry into a mattress.
The hidden DAVIS/Enter selector uses existing black panels, fonts, item icons
and gray buttons. It pauses and restores the current state on cancellation,
offers four top builds per boss, and is unavailable in coop.

## Ghast reveal and explosive weapons, 0.9.0

The Nether boss intro presents a large native-textured Ghast with its own
voice, hovering tentacles, charging face and a fake health bar. Soul light
builds inside it before the shell breaks into 17 independently moving parts.
The Wither materializes in the opening. Debris rotates, bounces and fades on
simulation time using a separate visual random stream. Existing boss rules
begin after the 10.2-second arrival. No interactive prompts accompany the scene.

Beds use 1.5 times their previous final blast radius. TNT deploys one charge
at a time, 0.32 seconds apart; movement direction controls each later charge's
position around the detonator and thus its flight. Evolved satellites split
into three smaller primed charges each, providing a second explosion wave.
Arcs and shadows communicate motion without radius guides. On Eye pickup,
the arena camera smoothly biases toward the portal and retains that anchor
through ignition and the jump.

## Chapter III, 0.10.0

The End preserves the same 640×360 bitmap interface, gray controls, native hearts,
XP and equipment bars. New weapon cooldowns use the vanilla white slot overlay
only in solo play. Eye choices expand the existing cards to four/five and retain
functional Russian descriptions. Active equipment labels fit to the left of the
existing bars. Pure cinematics hide the ordinary HUD.

Crystals stand directly on obsidian on the ground. There are no pseudo-towers
or staircase height mechanics. Gold boots and magma cream are absent from End
rewards. Bed, fishing and dragon breath use obtainable replacement ingredients
in this chapter; Nether recipes remain unchanged.

Dragon frames render the complete articulated 3D hierarchy through a shared
z-buffer, including wings, neck, tail, legs and jaw. Equipment and EnderSteve's
sword attach to shoulder/palm/wrist transforms. Elytra use native wing geometry
on Steve's back. Do not reconstruct these from detached 2D inventory icons.

The final scene uses paused simulation time for teleport afterimages, articulated
sword poses, the Compatibility distortion, portal fragments and reconstruction.
The chapter IV teaser displays the glitched Russian title «Обычный мир» over
scorched Overworld terrain. See docs/CHAPTER_THREE_UPDATE.md for rules and QA.

## End polish, 0.10.1

The post-victory state machine restores player movement at the hand, on the
return to the portal and after ignition. Only a deliberate entry starts the jump.
Bosses retain ordinary damage rules: dragon HP 8200, seven distinct final-duel
patterns, visible preparations and recovery windows. EnderSteve stays player-sized.
Column collision and navigation agree; high-speed movement uses short substeps.
The selected Eye reward freezes for 0.55 seconds before being granted, with a
0.21-second cycling interval. Pause freezes both clocks.
New native-textured finale poses and opaque bloody teaser terrain come from
bake_end_finale.py. The title uses existing bitmap glyphs with brief sliced offsets.
Axe changes apply to solo II/III only: connected grip, stronger sweep, and a damaging
return on evolution. See docs/END_POLISH_UPDATE.md.

## Achievements, 0.11.0

Twelve solo achievements use the existing gray Minecraft controls, native bitmap
Cyrillic and 32px badges composed from local vanilla textures. The book lives in
chapter selection and solo pause; the main menu retains its four buttons. It has
difficulty filters, two pages, concealed secret details and a compact queued toast.
The slot badge is a complete native chest model, never a raw UV sheet.

Every run still starts with sword I. For the bow challenge, the untouched initial
sword is allowed until the first bow is obtained; retire it within three active
seconds after that. Other weapons cannot be upgraded or retained beyond three
seconds. Bow development is allowed. No starting weapon selector. Reward skipping
is solo only and yields nothing. The view's descriptions remain concise and omit
story-damage exceptions and unnecessary future-condition explanations.

Run history tracks actual damage, consumed healing, evolution and peak equipment
slots. Removal cannot erase restrictions. Local unlocks persist separately from
settings, with backup recovery; diagnostic modes and coop never grant them.
The End teaser retains red ground, darkness and bare trunks without rubble/flesh
props. End island top and side thickness share one pixel transform. Final
EnderSteve defeat selects the victory stinger and song ahead of the boss theme.
See docs/ACHIEVEMENTS_UPDATE.md for rules, sources and reproducible validation.
