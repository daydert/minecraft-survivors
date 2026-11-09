# Графика и воспроизводимость

> Этот документ сохраняет промпты и процесс подготовки **персонажей** версий
> 0.1–0.2. С версии **0.5** эти опоры и риг больше не участвуют в игре:
> персонажи строятся `bake_minecraft_characters.py` из ванильных текстур.
> Старый риг сохранён в `docs/legacy/assemble_sprites_0_4.py.txt`.
> С версии 0.3 предметы,
> окружение и эффекты заменены на оригинальные ресурсы Minecraft; с версии 0.4
> заменены также звук, шрифт и GUI. Текущая карта процессов:
> [AGENT_HANDOFF.md](AGENT_HANDOFF.md).

## Обновление анимаций 0.2

Новые позы собраны из уже принятых **индивидуальных** опорных изображений каждого персонажа и направления. Новых вызовов imagegen в этом обновлении нет. Генератору не поручалась отрисовка атласов. Приведённые ниже запросы описывают происхождение исходных опорных изображений.

`scripts/assemble_sprites.py` вырезает квадратную голову и корпус, строит прямоугольные руки/ноги вокруг целочисленных суставов, переносит вес между опорной и поднятой стопой и запекает отдельные позы. Паук получает восемь двухсегментных ног с чередованием фаз; четыре ноги крипера и разорителя работают диагональными парами. У слизня отдельно запекаются сжатие, растяжение с отрывом от земли и приземление. Шлем и нагрудник элиты прикреплены к тем же частям тела, а не к неподвижной области атласа.

Каждый атлас: три строки `down / up / side`, 22 столбца. Противоположный бок зеркалится в игре. Кадры: 4 idle + 8 walk + 3 windup + 2 attack + 3 recover + 2 hurt. Метаданные, неодинаковые длительности и постоянные точки опоры записываются в `data/animations.json` и `docs/ASSET_MANIFEST.json`. При движении во время атаки рендерер объединяет верх действующей позы и ноги текущего шага, сохраняя походку. Контакт и звук запускаются прежними событиями боя; визуальная подготовка читает оставшуюся перезарядку.

```sh
python scripts/make_assets.py
python scripts/assemble_sprites.py --only steve zombie creeper
# Проверка в настоящей сцене: qa/animation_review.gd --core-only
python scripts/assemble_sprites.py
python scripts/check_atlases.py
```

Pillow нужен только при подготовке. PNG содержат бинарную альфу, прозрачные поля и чёткую сетку; игра использует Nearest. Контрольные листы: `qa/animation_native.png` (1:1), `qa/animation_4x.png`, `qa/animation_directions_live.png` (реальная сцена). До расширения подхода на остальных мобов Стив, зомби и крипер были запущены и просмотрены в игровой сцене.

Официальные анимационные референсы и их применение перечислены в `docs/REFERENCES.md`; загруженные JSON сохранены в `docs/references/animation/`. Из них изучены характер и фазы движений; игровые PNG собираются собственным двумерным ригом. Размеры/урон/интервалы боя взяты из прежней симуляции, а не из референсных файлов.

Использован встроенный imagegen. Исходники всех принятых изображений лежат в `assets/art_source/`. Игровые PNG — в `assets/sprites/`. Атласы собирает `scripts/assemble_sprites.py`: бинарная альфа, Nearest, ограничение палитры, единая опора стоп, детерминированные фазы движения. В первоначальной версии иконки, окружение и эффекты были нарисованы для проекта кодом; в текущей версии их заменяет импорт оригинальных ресурсов, описанный в [MINECRAFT_TEXTURES.md](MINECRAFT_TEXTURES.md).

## Опорный Стив — полный запрос

Create ONE single original pixel-art Steve character anchor sprite for a Minecraft-inspired 2D top-down survivors game. The attached sheet contains official Mojang reference textures ONLY as reference for character identity, never copy raw texture blocks or layouts. Steve is the brown-haired human with light brown skin, turquoise short sleeved shirt, indigo trousers, gray shoes, square large head and rectangular limbs. Full body facing downward toward the viewer, seen slightly from above so the top of his square head is visible. Straight orthographic 2D videogame pixel art, NOT isometric and NOT 3D render. Calm neutral pose. Precisely aligned large hard square pixels, a 32 by 32 logical pixel sprite represented enlarged, about 18 logical pixels wide and 28 high, limited palette, restrained 2-tone shading, dark colored thin outline. One character centered, no weapon, no shadow, no backdrop, no lettering or other objects. Actual transparent background. This single sprite is a style anchor for a coherent game asset pipeline.

## Остальные опорные кадры — общий префикс

Create ONE full-body original pixel-art anchor sprite for a 2D top-down Minecraft-inspired survivors game. Image 1 is the style anchor Steve: match its square pixel density, rectangular proportions, dark colored outline, restrained hard 2-tone shading and slightly elevated FRONT view. Image 2 contains official Mojang textures solely as identity references, NOT an atlas to copy. One isolated character only, facing DOWN toward viewer; the top of its head is visible. 32x32 logical pixel aesthetic enlarged with very crisp hard square pixels. Orthographic, no isometric grid, no 3D render, no text, no ground, no shadow, generous transparent margin, actual transparent background. Subject:

Затем к нему добавлялось одно описание:

- zombie: Minecraft zombie: square green head, dark green eyes and broad flat mouth, turquoise torn shirt, purple trousers, rectangular green arms held forward, gray dark shoes. Same apparent scale as Steve.
- creeper: Minecraft creeper: large square mottled green head, iconic black creeper face with two square eyes and hanging frown, tall rectangular narrow green torso and four stubby splayed feet. Green mottled skin, no arms. Same height as Steve.
- skeleton: Minecraft skeleton archer: square bone-white skull with black square eye sockets, tiny black mouth, visibly open bony rib cage, thin rectangular bone arms and legs, brown simple bow held at its side. Same height as Steve.
- spider: Minecraft spider: very low wide charcoal rectangular abdomen, smaller square head in front, eight segmented angular short black legs spread to sides, eight vivid red eye pixels in front, top surfaces visible. Wide silhouette fits logical 48x32 pixels. Match Steve style.
- slime: Minecraft slime: a single simple bright green translucent-looking CUBE, square frontal face with two dark green square eyes and broad small dark mouth, brighter green top surface visible, small darker inner green cube suggested inside. No arms or legs. Fits logical 24x24 pixels. Match Steve pixel style.
- ravager: Minecraft ravager boss: broad huge gray-brown rectangular bull-like quadruped, pale gray blocky face with dark unibrow, two thick short white horns, long dark rectangular villager nose, four stocky legs, dark brown leather harness across back with iron-gray buckles. Facing down seen from above, powerful wide silhouette, enlarged logical 64x64 pixels. Match Steve hard pixel art style.

## Направления

Для каждого из семи персонажей получены отдельные кадры `up` и `side`. Референс — `qa/anchors.png`, по одному персонажу на вызов; полный атлас генератору не поручался.

Шаблон запроса:

Generate ONE matching pixel-art game character sprite for the following character shown in the attached lineup. The lineup is a visual identity and style reference, not a layout to recreate. Character: {description} Desired direction: {direction} Match the reference's original proportions, palette, hard square pixels, thin dark outline, and slightly elevated top-down perspective exactly. Full-body neutral standing pose. A single character centered only. No other creatures, no text, no background, no ground, no shadow. Actual transparent background. For humanoids retain feet and rectangular hands. For spider spread all eight legs. Render a 32x32 logical pixel aesthetic enlarged, or 64x64 for ravager, 48x32 for spider. This will be used as another direction in the same videogame animation.

`direction`:

- up: BACK view, facing away toward the TOP of the image. Show the back of head and back of body, NO FACE visible.
- side: SIDE view facing exactly RIGHT. Show a right profile with just the visible side eye if appropriate.

`description`:

- steve: Steve, brown hair, teal short sleeve shirt, purple pants, skin colored square hands.
- zombie: Minecraft zombie, mottled green skin, teal shirt, purple pants, green square hands.
- creeper: Minecraft creeper, mottled green square head and tall narrow body, four stubby feet, no arms.
- skeleton: Minecraft skeleton, bone-white square skull, thin open rib cage, bone limbs, small bow at side.
- spider: Minecraft spider, charcoal wide low rectangular body, eight angular legs and small head.
- slime: Minecraft slime, green cube with smaller darker cube inside, no limbs.
- ravager: Minecraft ravager, broad gray blocky bull quadruped, two pale horns, rectangular villager nose, dark leather harness with silver buckles.

Броня элиты запекается на голову и корпус каждой позы зомби; размер увеличен в игре в 1,25 раза. Маленький слизень использует те же фазы прыжка с масштабом 1/2. Взмахи, клыки, взрывы, огонь и молния анимируются игровым рендерером по часам симуляции.
