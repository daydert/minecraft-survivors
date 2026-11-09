# Происхождение ресурсов

Код игры подготовлен для этого проекта. В версии 0.5 Стив, мобы, броня и топор поборника используют оригинальные текстуры Minecraft Java 1.21.11 на кубических моделях, запечённых в ортографические 2D-атласы. Проекция, анимационные позы и сидячая поза Херобрина подготовлены для игры. Херобрин использует текстуру Стива с изменёнными белыми глазами. Источники и SHA-256: docs/MINECRAFT_CHARACTER_MANIFEST.json. Прежние imagegen-опоры сохранены как исторические материалы и не используются в исполняемых сборках.

Текстуры предметов, блоков, сердца, сферы опыта, частиц, зачарования, сундука и клыков извлечены по запросу пользователя из локального Minecraft Java 1.21.11 в Prism Launcher. Исходные ресурсы принадлежат Mojang/Microsoft; лицензии Godot и кода игры на них не распространяются. Обычные иконки скопированы без изменений. Зелья собраны из слоёв оригинальной модели с цветом отравления #87a363; сундук, клыки и окружение представлены проекциями оригинальных текстур в 2D. Полный список источников и SHA-256: docs/MINECRAFT_ASSET_MANIFEST.json. Сторонние моды и ресурспаки не использованы.

Minecraft, Steve и существа Minecraft относятся к Mojang/Microsoft. Это неофициальная фан-демка, не продукт Mojang. Дополнительные референсы из официального репозитория Mojang находятся в docs/references и исключены из исполняемых сборок.

В архивах готовых сборок манифест ресурсов также находится в licenses/MINECRAFT_ASSET_MANIFEST.json.

Godot Engine: MIT, полный текст GODOT_LICENSE.txt.
Игровой шрифт — оригинальные bitmap-глифы Minecraft (ascii, nonlatin_european, accented), включая кириллицу. Извлечены из того же локального клиента Mojang/Microsoft; для Godot подготовлены BMFont-описания с исходными масками и метриками. Полужирное начертание повторяет однопиксельное смещение Minecraft. Происхождение: docs/MINECRAFT_PRESENTATION_MANIFEST.json.

DejaVu Sans / DejaVu Sans Bold используется только инструментами подготовки старых контактных листов и исключён из исполняемых сборок. Лицензия: DEJAVU_LICENSE.txt.

Все звуковые эффекты — оригинальные OGG из ресурсов Minecraft Java 1.21.11, скопированные без изменений из Prism Launcher (asset index 29). Принадлежат Mojang/Microsoft. В версии 0.5 используются 73 файла и 31 событие, включая поборника, появление босса и портал. В проекте больше нет синтезированных WAV. Таблица событий: data/minecraft_audio.json; источники и SHA-1/SHA-256: docs/MINECRAFT_PRESENTATION_MANIFEST.json.

Фоновая музыка предоставлена пользователем: /home/daydert/Downloads/Telegram Desktop/MusicForGame.mp3. Файл содержит AAC и преобразован в Ogg Vorbis для воспроизведения в Godot; композиция не заменена и не сгенерирована. Источник и контрольные суммы указаны в MINECRAFT_PRESENTATION_MANIFEST.json.

Отдельная музыка Херобрина предоставлена пользователем: /home/daydert/Downloads/audio_2026-10-27_17-30-49.ogg. Исходные Vorbis-байты скопированы в assets/audio/music_herobrine.ogg без изменений; композиция длится 79,962 с. Обе музыкальные темы имеют пользовательское происхождение.

## Chapter II resources (0.7.0)

Nether items, terrain, GUI adaptation, nine character models' texture sources,
bed, decorated pot, TNT, Wither skull and enemy sounds use the same locally
installed Minecraft Java 1.21.11 client / Prism asset objects. Flat icons and
OGG samples retain original bytes. Custom cuboid projection, animation poses,
atlas layout and terrain assembly use the existing importer and rasterizer.
Source and derived hashes: docs/MINECRAFT_NETHER_MANIFEST.json. No new imagegen
art is used for Chapter II. Mojang/Microsoft retain rights to Minecraft assets.

## Additional user music (0.7.1)

Music2.mp3 and Music3.mp3 were supplied by the user and converted to Vorbis.
The supplied audio_2026-10-28_18-28-58.ogg Wither theme is copied byte for byte.
Source, prepared-file hashes and durations: docs/MUSIC_MANIFEST.json.

## Boss duels (0.8.0)

The supplied wineffect.ogg victory stinger and
audio_2026-10-29_00-31-58.ogg victory music are copied byte for byte to
assets/audio/boss_win.ogg and music_victory.ogg. These two recordings are
user-provided audio, not extracted Minecraft sounds. Sources, hashes and
durations are recorded in docs/MUSIC_MANIFEST.json.

The new Herobrine seated/rising/commanding poses and Steve's kneeling poses
use the existing cuboid rasterizer, original Steve UV textures and the same
approved white-eye adaptation. The throne is projected from original block
textures. Teleport and sonic-boom sound samples are unmodified Minecraft
asset objects. Source and derived hashes: docs/MINECRAFT_DUEL_MANIFEST.json.
The blood-distortion screen shader and animation choreography are project code.

## Boss polish (0.8.1)

The corrected bed preserves the original red-bed UV layout on rotated cuboids;
its inventory icon is baked at its own projection scale. The straight arena
uses unscaled polished-blackstone and Nether-brick tiles. Four withered-heart
sprites are original Minecraft HUD textures. Sources and derived hashes are
included in docs/MINECRAFT_NETHER_MANIFEST.json. No generated art replaces them.

## Ghast reveal (0.9.0)

The large Ghast uses the original Minecraft Java 1.21.11 128x64 Ghast and
attacking-Ghast UV textures, projected on animated cuboids with the existing
CPU rasterizer. Eight shell pieces preserve their outer UV regions; inner
surfaces use the original bone-block texture. Nine detached tentacles use
the same Ghast texture. Ghast ambient/charge/death and generic explosion
recordings are copied from the local Prism asset objects without modification.
Provenance and hashes: docs/MINECRAFT_GHAST_MANIFEST.json.

## Глава III — Край (0.10.0)

Дракон, эндермены и маски глаз, шалкеры, эндермиты, элитры, копья, булава,
кристаллы, хорус, блоки и звуки используют оригинальные ресурсы локального
Minecraft Java 1.21.11. Иерархия кубических моделей, ортографическая проекция,
позы, анимации, остров и эффекты подготовлены для этой игры прежним растеризатором.
ЭндерСтив — собственная связная порча ванильной кожи Стива, без стороннего мода.
Источник и SHA-256 каждого исходного и готового файла:
`docs/MINECRAFT_END_MANIFEST.json` (в готовом архиве — `licenses/`).
Музыкальные темы главы повторно используют предоставленные пользователем
записи; новых синтезированных или заимствованных композиций не добавлено.

Уточнённые геометрия перепонок и шарниры крыльев сверены с официальными
образцами Mojang Bedrock Samples, закреплёнными на commit
`a3b394c507a6b11a3c6f61552e778ff5c4b89fd2`. Ссылки, SHA и локальные копии для
воспроизведения находятся в `docs/references/end/`; игровая текстура дракона
остаётся из локального Java-клиента. Эти диагностические референсы не входят
в исполняемый PCK.

## Глава IV — окружение, этап A

Поверхности, разрушенные дома, пирамида, жители на столбах, наросты и рука
запечены существующим кубическим растеризатором из текстур локального
Minecraft Java 1.21.11. Компоновка мира, модели, позы и эффекты авторские.
Трек Ancestry (Lena Raine) и эффекты звука импортированы из того же клиента
без перекодирования. Источник и SHA-256 каждого файла перечислены в
`docs/CHAPTER_FOUR_ASSET_MANIFEST.json` и `docs/CHAPTER_FOUR_AUDIO_MANIFEST.json`.
Эти материалы Minecraft принадлежат соответствующим правообладателям;
лицензия исходного кода не распространяется на них.
