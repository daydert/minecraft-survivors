# Minecraft Survivors — заметки для сессий Claude

Общие правила проекта (история решений, устройство глав) — в `AGENTS.md` и `docs/AGENT_HANDOFF.md`.
Здесь — как работать с 3D, спрайтами, скиллами и проверками, чтобы не изобретать заново.

## Godot
- Движок: `.tools/Godot_v4.7.2-stable_linux.x86_64`. Все прогоны — с `--audio-driver Dummy` (звук мешает пользователю).
- После добавления/замены любых ассетов (png, ogg) — `--headless --path . --import`, иначе игра грузит старую версию.
- Тесты: `qa/test_*.gd` (`-s qa/test_x.gd`), печатают `*_RESULT N checks; M failures`.
  `qa/test_determinism.gd -- --record` перезаписывает отпечаток после намеренных изменений геймплея.
- Ролики: Movie Maker `--write-movie out.avi --fixed-fps 30 --disable-vsync` (без `--disable-vsync` фоновое окно
  душится до 1 к/с), затем ffmpeg в mp4. Шаблоны: `qa/ch5_reel_record.gd`, `qa/chapters_review_reel.gd`.
- Билд: `scripts/build.sh`; Windows-пресет экспортирует в `~/Downloads/Telegram Desktop/` — копировать в `builds/windows/` и паковать zip.
- Не использовать `pkill -f <шаблон>`, если шаблон есть в своей же команде (убивает собственный шелл).

## 3D-фильмы (Blender)
- Steam Blender 5.3: `/home/daydert/.local/share/Steam/steamapps/common/Blender/blender --background --python <script>`.
- Пролог I: `scripts/cinematics/build_ch1_intro_v2.py` → `render_ch1_intro_v2.py` (`--frames/--start/--end/--samples/--scale/--scene`) →
  `encode_ch1_intro_v2.py`. Концовки V: `build_ch5_bad_end.py`, `build_ch5_kill.py` (+ `encode_ch5_*.py`), общие риги — `_ch5bad_base.py`.
- Позы проверять пробными рендерами (`--samples 6 --scale 50 --frames …`) и смотреть кадры; `look` MCP у Steam-Blender картинку не отдаёт.
- QTE/порталы/бросок меча V — питоновские треки поз в `data/chapter_five_cinema.json`
  (`ch5_motion.py`, `ch5_qte_fight.py`, `ch5_erase_throw.py`; экспорт `export_ch5_*.py` через Blender).

## 2D-спрайты из 3D-модели игрока
- `scripts/import_minecraft_assets.py` (`find_client`, `Importer`, `bake`, `box`) берёт текстуры из локального клиента PrismLauncher.
- Позы: `scripts/bake_chapter_four_finale.py` (`figure`, `POSES`, `atlas`) — тот же приём для трона I (`scripts/bake_ch1_throne_v2.py`).
  Блоки собирать «texel-true» (грани не больше блока, без растяжения).

## Скиллы
- Пользовательские скиллы (`rig-motion-skill`, `blender-animation`, `blender-camera-cinematography`, `blender-lighting`,
  `blender-rendering`, `blockbench-animation`, `minecraft-modding`) подключены в Claude Code; вызывать через Skill при работе с ригами/камерой/светом.

## Стиль
- Предупреждения атак — только `scripts/chapter_four_tells.gd` (трещины/кольца точек на земле), без полупрозрачных зон.
- Полоса босса — `scripts/ui/boss_bar.gd`. Описания предметов: без точки в конце, перечисления через « · », клавиша — «E — …», «Пробел — …».
- Тексты пользователя: опечатки чинить, кавычки оставлять, без точки в конце.
