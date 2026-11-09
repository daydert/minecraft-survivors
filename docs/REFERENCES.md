# Референсы спрайтов

## Движения: обновление 0.2

Дополнительно изучены и сохранены официальные материалы **Mojang/bedrock-samples**, `resource_pack`, ветка `main`. Точные URL и результаты загрузки: `docs/references/animation/sources.json`. Применение в собственных двумерных позах:

| Официальный источник | Применение |
|---|---|
| [Humanoid](https://github.com/Mojang/bedrock-samples/blob/main/resource_pack/animations/humanoid.animation.json) | Противоположные фазы рук/ног, тихое движение рук в покое, хват лука и подготовка трезубца |
| [Player](https://github.com/Mojang/bedrock-samples/blob/main/resource_pack/animations/player.animation.json) | Читаемое направление тела и позы Стива |
| [Zombie](https://github.com/Mojang/bedrock-samples/blob/main/resource_pack/animations/zombie.animation.json) | Вытянутые руки и тяжёлый шаг зомби и бронированной элиты |
| [Skeleton](https://github.com/Mojang/bedrock-samples/blob/main/resource_pack/animations/skeleton.animation.json) | Раздельные положения плеч/рук при атаке; натяжение и выпуск адаптированы к существующим 0,5 с подготовки |
| [Creeper](https://github.com/Mojang/bedrock-samples/blob/main/resource_pack/animations/creeper.animation.json) | Диагональные пары ног и нарастающее расширение перед детонацией |
| [Spider](https://github.com/Mojang/bedrock-samples/blob/main/resource_pack/animations/spider.animation.json) | Восемь ног, угловые сегменты и фазовые сдвиги четырёх пар |
| [Slime client entity](https://github.com/Mojang/bedrock-samples/blob/main/resource_pack/entity/slime.entity.json) | Обратная связь горизонтального и вертикального масштаба при сжатии и прыжке |
| [Ravager](https://github.com/Mojang/bedrock-samples/blob/main/resource_pack/animations/ravager.animation.json), [Quadruped](https://github.com/Mojang/bedrock-samples/blob/main/resource_pack/animations/quadruped.animation.json) | Тяжёлые диагональные шаги, отдельная работа головы/шеи, оседание после рывка |
| [Meet the Ravager](https://www.minecraft.net/en-us/article/meet-ravager) | Силуэт массивного четвероногого, рога, низкое положение головы |

Отдельного `animations/slime.animation.json` в официальной ветке не оказалось (404); использован сохранённый `entity/slime.entity.json`, где деформация описана непосредственно. Дата изучения и загрузки: 26 октября 2026, часовой пояс Asia/Omsk.

Референсы найдены в официальном репозитории **Mojang/bedrock-samples**, ветка `main`. Локальная папка `docs/references/` содержит референсы Стива, зомби, скелета, крипера, паука, слизня, разорителя, оружия и предметов. Точные URL, статусы скачивания и имена сохранённых файлов перечислены в `docs/references/sources.json`.

- [Официальные материалы Mojang](https://github.com/Mojang/bedrock-samples/tree/main/resource_pack/textures) — цвета, формы, одежда, лица мобов, оружие и предметы.
- [Minecraft: Taking Inventory — Trident](https://www.minecraft.net/en-us/article/taking-inventory--trident) — силуэт и мотивы «Верности»/«Громовержца».
- [Godot 4.7.2 stable](https://godotengine.org/article/maintenance-release-godot-4-7-2/) — выбранная версия движка; реально установлен и запущен `4.7.2.stable.official.ed1daf0bf`.

Официальные текстуры сущностей — развёртки кубических моделей, они использованы только как визуальные референсы. Они не подставляются в Sprite2D и не попадают в игровой экспорт. В отличие от обычного ресурс-пака, готовые игровые персонажи нарисованы как цельные 2D-спрайты в нужном ракурсе.

Подтверждение текущего стиля: `qa/animation_native.png`, `qa/animation_4x.png`. Все позы и направления: `qa/animation_all_poses_native.png`, `qa/animation_directions_live.png`. Исходные сгенерированные кадры — `assets/art_source/`; описание запросов и обработки — `docs/ASSET_PROMPTS.md`.

Сайт minecraft.net открывался через веб-поиск, но прямое скачивание в среде разработки отвечало тайм-аутом. Сами референсные файлы поэтому скачаны из официального репозитория Mojang, который доступен напрямую. Референсы скачиваются повторно скриптом `scripts/fetch_references.py`; обновлённые пути паука, клыков и зелья зафиксированы в sources.json.
