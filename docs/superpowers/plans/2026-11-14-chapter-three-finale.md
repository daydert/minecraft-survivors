# Финал главы III — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Переделать финальный бой с ЭндерСтивом (две фазы, Проекция, часы, перехват, адаптация, скейл от скорости) и концовку III (размен, QTE за меч, плохая концовка, пощада), а также поменять местами реплики эха №5 и разрушения портала.

**Architecture:** ИИ боя переезжает из `end_encounter.gd::endersteve()` в новый `scripts/end_steve_boss.gd` (RefCounted, состояние в словаре моба `m`, фазы — строки `m.phase`, как во всём проекте). Состояние дуэли между фазами (фаза, адаптация, стиль игры, чекпоинты) хранится в `w.duel: Dictionary` в `end_world.gd`. Сюжетные стадии остаются в `end_encounter.gd::story()`. Новая отрисовка — в `scripts/end_steve_view.gd`, вызывается из `end_renderer.gd`.

**Tech Stack:** Godot 4.7.2 (GDScript, headless-тесты `-s qa/*.gd`), Python + PIL-растеризатор проекта (`import_minecraft_assets.bake`) для поз, ffmpeg для аудио и роликов.

**Spec:** `docs/superpowers/specs/2026-11-14-chapter-three-finale-design.md`

## Global Constraints

- Godot: `.tools/Godot_v4.7.2-stable_linux.x86_64`, всегда `--audio-driver Dummy`; после новых png/ogg — `--headless --path . --import`.
- Тесты печатают `*_RESULT N checks; M failures` (стиль `qa/test_end_revision.gd`: `check(ok,label)`).
- Не использовать `pkill -f <шаблон>`, если шаблон есть в своей же команде.
- ЭндерСтив одного роста с игроком: запекание 0,86, runtime ×1, радиус тела 6.
- Предупреждения атак — только `scripts/chapter_four_tells.gd` (трещины/кольца точек), без полупрозрачных зон.
- Полоса босса — `scripts/ui/boss_bar.gd`.
- Звуки — только локальные ванильные и файл пользователя `~/Downloads/return-by-death.mp3`.
- Тексты: опечатки чинить, кавычки оставлять, без точки в конце.
- Вспышки уважают `g.settings.flashes`, тряска — `g.settings.shake`.
- Кооп, главы I/II/IV/V, бой с драконом и `qa/end_frozen_files.json` (замороженные файлы) не меняются.
- Числа стартовые: фаза 1 и фаза 2 — по 5200 HP; обычный удар 4, клинок 3, сокрушительный 9; перед фазой 1 игроку +6 HP, перед фазой 2 +4.
- Скейл `k = clamp(базовая скорость без временных эффектов / db.data.player_speed, 1.0, 1.6)`; скорости ×k, замахи и предупреждения ÷√k.
- Коммитить только когда пользователь попросит (правило репозитория). Шаги «Commit» означают: подготовить список файлов и сообщение коммита в отчёте задачи.

## Review Focus

1. Пауза или меню во время «кадра», часов или QTE — после выхода всё продолжается с того же момента (таймеры идут только в `step`). → тест в Task 3 и Task 8.
2. Игрок одновременно «в кадре» и в падении с острова или в полёте элитр — кадр снимает полёт, падения нет. → тест в Task 3.
3. Смерть ровно в тот кадр, когда ЭндерСтив умирает (оба HP ≤ 0) — побеждает смерть игрока, чекпоинт без дублей босса. → тест в Task 6.
4. Повтор с чекпоинта, когда в сборке нет ни одного держимого оружия — размен использует меч. → тест в Task 8.
5. Откат часов во время Проекции или в момент смерти фазы — откат не воскрешает после 0 HP, смерть важнее. → тест в Task 5.

---

### Task 1: Реплики эха №5 и разрушения портала

**Files:**
- Modify: `scripts/end_world.gd:68` (`ECHO_LINES`)
- Modify: `scripts/end_encounter.gd:3-9` (`BETRAYAL_IMPACT`, `BETRAYAL_END`, `BETRAYAL_LINES`)
- Test: `qa/test_ch3_finale.gd` (новый, общий для всего плана; `fresh()` как в `test_end_revision.gd`)

**Interfaces:**
- Produces: `end_encounter.BETRAYAL_LINES: Array` из `[at, text, life]`; `BETRAYAL_IMPACT` = момент крика «НАЧНЁМ!».

- [ ] **Step 1: Тесты**
  - `ECHO_LINES[4]=="Стой\nТуда нельзя\nНе заставляй меня"`.
  - Тексты `BETRAYAL_LINES` по порядку: «Ладно...», «У меня нет другого выбора...», «Ты ничем не отличаешься от остальных...», «НАЧНЁМ!».
  - Прогон стадии `betrayal` с шагом 1/60: строка «НАЧНЁМ!» становится видимой (`age>=0`) в пределах ±0,05 с от `BETRAYAL_IMPACT`, и `portal_lit` гаснет в тот же кадр. Никакие две фразы не накладываются.
- [ ] **Step 2: Запуск** `--headless --path . -s qa/test_ch3_finale.gd` → FAIL.
- [ ] **Step 3: Реализация.** Поменять тексты; `BETRAYAL_IMPACT` ≈ 8,4, `BETRAYAL_END` ≈ 12,5. Тайминги фраз считать через `timeline()`/`part_life()` так, чтобы последняя фраза начиналась на ударе. Позы в `end_renderer.betrayal()` растянуть: замах начинается после третьей фразы, а не на 2,6 с.
- [ ] **Step 4: Запуск** → PASS; `qa/test_end_revision.gd` и `qa/test_end.gd` → 0 failures.
- [ ] **Step 5: Commit** «Глава III: реплики эха и разрушения портала на своих местах».

### Task 2: Каркас босса, правило удара по воздуху, окна урона, скейл скорости

**Files:**
- Create: `scripts/end_steve_boss.gd`
- Modify: `scripts/end_world.gd` (`hurt`, `spawn`, `damage_player` override, новые функции), `scripts/end_encounter.gd` (`step` → новый босс; `endersteve()`, `strafe()`, `SEQUENCE` переезжают), `data/end_balance.json` (`endersteve_final.hp` 5200, `damage` 4)
- Test: `qa/test_ch3_finale.gd`, обновить `qa/test_end_revision.gd`, если он ссылается на `end_boss.SEQUENCE`

**Interfaces:**
- Produces в `end_world.gd`:
  - `func boss_strike(source: Vector2, damage: float, unblockable: bool=false) -> bool` — урон от ЭндерСтива: игнорирует неуязвимость прыжка булавы и полёта элитр и порог высоты; уважает `hit_grace` (0,65 с после полученного урона), `blink_grace` (0,3 с после телепорта жемчугом), `dash_left>0`, `fall_age>=0`; щит блокирует, если не `unblockable`.
  - `var hit_grace := 0.0`, `var blink_grace := 0.0` (выставляются в `damage_player` и `teleport_to`).
  - `func speed_scale() -> float` — k из Global Constraints (сахар учитывается; `slow_time` и `flight` — нет).
  - `var duel: Dictionary` — `{"fight":1, "adapt":{}, "style":{}, "checkpoint":{}, "phase_start":{}}`, сбрасывается в `reset()`.
- Produces в `end_steve_boss.gd`: `func step(w, m: Dictionary, dt: float) -> void`, `func on_hurt(w, m: Dictionary, amount: float) -> float` (возвращает итоговый урон с окнами и адаптацией или 0 при уворот-блинке), `const OPENINGS := ["recover","pose","winded","clock_broken"]`.

- [ ] **Step 1: Тесты**
  - Игрок в прыжке булавы (`jump_age=.4`, `invulnerable=.06`): `boss_strike(p,4)` → true, HP −4.
  - Игрок в полёте элитр: то же. Игрок сразу после урона (`hit_grace>0`): false. В рывке копья: false.
  - `hurt(steve,100)` в фазе `recover` → −100; в фазе `rush` → −50.
  - `items.sugar=5` → `speed_scale()` ≈ 1,4; при `slow_time>0` значение то же.
  - Единственность: `spawn("endersteve_final")` при живом возвращает false; во время `last_duel` 600 с прогона на каждом кадре живых `endersteve*` ≤ 1.
- [ ] **Step 2: Запуск** → FAIL.
- [ ] **Step 3: Реализация.** Перенести текущие приёмы (рывок, тысяча порезов, падение, отражения, касты) в `end_steve_boss.gd`. Все попадания ЭндерСтива перевести на `boss_strike`. Его зоны `end_cut` и его клинки тоже идут через `boss_strike` (пометка `h.steve=true` / `b.steve=true`), а прочие зоны и мобы остаются на `contact_hit`. Множитель 0,35 заменить на 0,5. Уворот-блинк с контратакой (замах 0,35 с, если игрок ближе 90 px). Скорости ×k, замахи ÷√k через одну функцию `boss.tempo(w, seconds) -> float`.
- [ ] **Step 4: Запуск** → PASS; `qa/test_end*.gd` → 0 failures.
- [ ] **Step 5: Commit** «Глава III: новый каркас ЭндерСтива, удары по воздуху, скейл скорости».

### Task 3: Проекция, «кадр» и сокрушительный удар

**Files:**
- Modify: `scripts/end_steve_boss.gd`, `scripts/end_world.gd` (`step`: заморозка игрока; `active_item`: запрет при кадре)
- Test: `qa/test_ch3_finale.gd`

**Interfaces:**
- Produces: `m.phase` значения `"projection_stance"`, `"projection"`, `"framed_strike"`, `"winded"`; `m.path: Array[Vector2]` (4 точки текущего круга), `m.lap: int` (0..2), `m.preview: float`.
- Produces в `end_world.gd`: `var framed := 0.0` (> 0 — игрок в кадре: движение, предметы, атаки оружием заморожены; полёт, прыжок и левитация сбрасываются); `var frame_pos: Vector2`.

- [ ] **Step 1: Тесты**
  - Скорости кругов при k=1: 320/480/700 (±1). Предупреждения 0,45/0,35/0,25. При k=1,4 скорость ×1,4, предупреждение ÷√1,4.
  - Игрок стоит на пути → `framed>0`, позиция не меняется при движении, `active_item("ender_pearl")` → false; через ≤ 1,1+0,55 с HP −9 и `framed==0`.
  - Игрок в прыжке булавы на пути → тоже в кадр; `jump_age==-1` после захвата, падения с острова нет.
  - Игрок сошёл с пути до круга → без урона; после 3-го круга `m.phase=="winded"` на 1,3 с, и `hurt` даёт 100%.
  - Пауза: `state="PAUSED"`, 100 вызовов `step` → `framed` не изменился.
- [ ] **Step 2: Запуск** → FAIL.
- [ ] **Step 3: Реализация.** Путь — 4 точки вокруг упреждённой позиции игрока (`player+tracked_velocity*.3`), с ограничением арены `END_ARENA` и `free_at`. Касание — расстояние тела до игрока < 14 во время `projection`. Сокрушительный удар: телепорт за спину, замах `tempo(.55)`, `boss_strike(...,9,true)`, `hitstop=.2`, `shake=.8`, `fx.quake`, отброс 160.
- [ ] **Step 4: Запуск** → PASS.
- [ ] **Step 5: Commit** «Глава III: Проекция и сокрушительный удар».

### Task 4: Перехват прыжка и посадки

**Files:**
- Modify: `scripts/end_steve_boss.gd`, `scripts/end_world.gd` (сигналы начала прыжка и конца полёта: `var air_event := ""`, `var air_land := Vector2.ZERO`)
- Test: `qa/test_ch3_finale.gd`

**Interfaces:**
- Consumes: `boss_strike`, `tempo`.
- Produces: `m.phase=="intercept"`, `m.mark` — точка удара; `func intercept_chance(w) -> float` (0,6 в фазе 1; 1,0 при адаптации к булаве).

- [ ] **Step 1: Тесты** (rng с фиксированным seed, шанс принудительно 1):
  - Прыжок булавы на месте ближе 160 px → в высшей точке HP −4.
  - Прыжок со смещением в воздухе ≥ 30 px от точки → без урона.
  - Конец полёта элитр ближе 160 px → удар в момент посадки.
  - Босс занят приёмом (не `walk`/`recover`) → перехвата нет.
- [ ] **Step 2–4:** FAIL → реализация → PASS.
- [ ] **Step 5: Commit** «Глава III: перехват булавы и элитр».

### Task 5: Часы — откат, адаптация, поломка

**Files:**
- Modify: `scripts/end_steve_boss.gd`, `scripts/end_world.gd` (учёт урона по боссу за окно: в `hurt` для `endersteve_final` копить `m.clock.dealt[damage_owner]`)
- Test: `qa/test_ch3_finale.gd`

**Interfaces:**
- Produces: `m.clock: Dictionary` = `{"state":"idle|running|rewind|broken", "age":float, "hp0":float, "p0":Vector2, "trail":Array, "dealt":Dictionary}`; `w.duel.adapt: Dictionary` оружие → множитель (0,6; минимум 0,4); `const CLOCK_TIME := 9.0`, `const REWIND_TIME := 1.4`, `const REWIND_SHARE := .12`.
- Пороги: фаза 1 — 60% HP; фаза 2 — 70% и 35%.

- [ ] **Step 1: Тесты**
  - HP падает ниже 60% → `clock.state=="running"`.
  - Урон булавой ≥ 12% max HP за окно → `rewind`; через 1,4 с HP == `hp0`, `duel.adapt.mace==.6`, следующий удар булавой ×0,6. Повторный откат той же булавой → 0,4.
  - Урон < 12% за 9 с → `broken`; 2,5 с удар ×1,5.
  - Удар, который бы довёл HP до ≤ 0 во время `running`: босс умирает, откат не запускается (Review Focus 5).
- [ ] **Step 2–4:** FAIL → реализация → PASS.
- [ ] **Step 5: Commit** «Глава III: часы с откатом времени».

### Task 6: Перерождение, фаза 2, адаптация, Петля, чекпоинты

**Files:**
- Modify: `scripts/end_steve_boss.gd`, `scripts/end_encounter.gd` (стадии `rebirth`, `fallen`), `scripts/end_world.gd` (`resolve_deaths`, `damage_player`, `save_duel_checkpoint`, `restore_duel_checkpoint`), `scripts/main.gd` (кнопки `end_retry`), `data/end_audio.json`
- Create: `assets/audio/end_ext/return_by_death.ogg` (ffmpeg из `~/Downloads/return-by-death.mp3`, `loudnorm`), запись в `docs/END_EXTERNAL_AUDIO.json` с пометкой «файл пользователя»
- Test: `qa/test_ch3_finale.gd`

**Interfaces:**
- Produces в `end_world.gd`: `func save_duel_checkpoint(kind: String) -> void` (`"fight1"` при разрушении портала, `"fight2"` в начале фазы 2: `build`, `items`, `evolved`, `hp` (≥ 12), `cooldowns`, `damage_by`, `duel.adapt`, `duel.style`); `func restore_duel_checkpoint(kind: String) -> void` (ставит стадию `last_arrival` и спавнит единственного босса нужной фазы).
- Produces: `duel.fight: int`, `duel.style: Dictionary` = `{"avg_dist", "framed", "glides", "pearls", "top_weapon"}`; `func rebirth_line(w) -> String` с текстами из спека.
- Стадия `rebirth` (~5,5 с): звук `return_by_death` на 0,3 с. Стадия `fallen`: карточка «Вы погибли», кнопки «Повторить бой с ЭндерСтивом» (`end_retry`) и «В меню».
- Фаза 2: замахи ×0,85, кулдаун блинка 1,2, приём `"loop"` (3 отражения повторяют последние 3 приёма из `m.history`; Проекция исключена; это эффекты, не мобы); адаптация к оружию по таблице спека и к стилю игры (дистанция, попадания в кадр, полёты, жемчуг — веса приёмов и реакции по спеку).

- [ ] **Step 1: Тесты**
  - Фаза 1 до 0 HP → стадия `rebirth` → звук `return_by_death` в `w.sounds` → стадия `last_duel`, `duel.fight==2`, живой ровно один, HP 5200. Ни на одном кадре стадии `rebirth` нет двух живых.
  - Урон фазы 1 в основном булавой → `rebirth_line` = строка булавы, `intercept_chance==1`.
  - Смерть игрока в фазе 1 → `fallen`; `end_retry` → фаза 1, сборка из снимка. Смерть в фазе 2 → фаза 2 с той же `duel.adapt`.
  - HP игрока и босса ≤ 0 в одном кадре → `fallen`, не `rebirth` (Review Focus 3).
  - Петля в фазе 2 никогда не создаёт `projection` и не ставит `framed`.
- [ ] **Step 2–4:** FAIL → реализация (`--import` после ogg) → PASS.
- [ ] **Step 5: Commit** «Глава III: перерождение, вторая фаза и чекпоинты».

### Task 7: Запекание поз, атласы оружия, часы

**Files:**
- Modify: `scripts/bake_chapter_three_brawl.py`
- Create: `scripts/bake_ch3_clock.py` → `assets/sprites/ch3_clock_face.png`, `ch3_clock_hands.png`
- Output: `assets/sprites/ch3_brawl_*.png`, `data/chapter_three_brawl.json`, `qa/chapter_three_brawl_poses.png`

**Interfaces:**
- Produces в `chapter_three_brawl.json`: `"sprites"`, `"weapons": {"<id>": "ch3_brawl_steve_<id>"}` для `sword, axe, hoe, spear, mace, knockback_stick, shield, bow, crossbow, fishing`; позы: прежние плюс `stance`, `run`, `slide_grab`, `kneel_wait`, `lie_wait`, `raise_over`, `lower`, `turn_away`, `bad_raise`, `bad_strike`, `steve_kneel`.
- Клинок ЭндерСтива — `item/netherite_sword` в его атласе (как в бою), вместо `iron_sword`. Атласы оружия Стива содержат только `guard`, `stance`, `windup`, `strike`, `clang`, `thrown`.

- [ ] **Step 1:** Добавить позы и параметр предмета; запустить `python scripts/bake_chapter_three_brawl.py`. Ожидаемо: `CH3_BRAWL <n> frames`, PNG на месте.
- [ ] **Step 2:** Просмотреть `qa/chapter_three_brawl_poses.png` и по кадру каждой новой позы через Read. Проверить: модель связная, рука держит рукоять, рост как у игрока. Исправлять, пока не годно.
- [ ] **Step 3:** Часы: циферблат 96×96, золото + фиолетовая эмаль, шестерни, пиксельная выборка; стрелки отдельно. Просмотреть PNG.
- [ ] **Step 4:** `--headless --path . --import`; добавить спрайты в `data/end_assets.json`; `python scripts/check_end_assets.py` → OK.
- [ ] **Step 5: Commit** «Глава III: позы финала, атласы оружия и часы».

### Task 8: Концовка — стойка, размен, бег за мечом (QTE), плохая концовка, пощада, разговор у портала

**Files:**
- Modify: `scripts/end_encounter.gd` (стадии `standoff`, `clash`, `sword_race`, `bad_end`, `bad_card`, `mercy`, `down`, `talk`, `restore`; удалить `to_edge`, `sit`, `seats()`), `scripts/end_world.gd` (`top_held_weapon()`, `sword_race`), `scripts/main.gd` (ввод QTE в III: A/D/Пробел/ЛКМ; кнопки карточки), `scripts/end_renderer.gd`
- Create: `scripts/end_sword_race.gd` (QTE, по образцу `chapter_five_qte.gd`)
- Test: `qa/test_ch3_finale.gd`

**Interfaces:**
- Produces: `func top_held_weapon() -> String` в `end_world.gd` (максимум `damage_by` за забег среди держимых, иначе `"sword"`); `end_sword_race.gd`: `reset(seed:int)`, `press(action:String)`, `step(dt)`, `beat:int`, `fails:int`, `result:"" | "won" | "lost"`, `events:Array`, такты `mash` (1,8 с), `dodge` (направление A/D из seed, окно 0,6 с), `grab` (окно 0,18 с), проигрыш при `fails>=2`.
- Тексты (без точки в конце): пощада — «Давай. Мне терять нечего» / «В следующей итерации я всё равно тебя достану», «...Почему?» (ender), «Квиты» (steve), затем `DOWN_SCRIPT[0]`; разговор — `SIT_SCRIPT` без похода к краю, подарок «Держи Око Края, оно тебе пригодится»; плохая концовка — «В этой итерации — моя».
- Плохая концовка: `victory=false`, `end_complete=false`, глава не засчитывается; кнопки `end_retry` (фаза 1 из чекпоинта `fight1`) и `menu`.
- После пощады `build.sword=1` (меч из QTE), `keepsake` выдаётся в разговоре.

- [ ] **Step 1: Тесты**
  - `damage_by={"mace":900,"end_crystal":5000,"sword":100}` → `top_held_weapon()=="mace"`; без держимых → `"sword"` (Review Focus 4).
  - QTE: правильные нажатия → `won`, стадии `mercy` → `down` → `talk` → `restore` → `portal_ready`, `build.sword==1`, `keepsake`, `end_complete` после прыжка.
  - QTE без нажатий → `lost` → `bad_end` → `bad_card`; `end_complete==false`, `victory==false`; `end_retry` → фаза 1, сборка из снимка `fight1`.
  - Ни одна стадия финала не переходит в `to_edge` или `sit`; NPC за весь финал отходит от портала не дальше 140 px.
  - Пауза во время QTE: 100 вызовов `step` в `PAUSED` → `age` такта не изменился (Review Focus 1).
- [ ] **Step 2–4:** FAIL → реализация → PASS.
- [ ] **Step 5: Commit** «Глава III: новая концовка с QTE за меч».

### Task 9: Отрисовка и звук — кадр, часы, Проекция, перерождение, финал

**Files:**
- Create: `scripts/end_steve_view.gd`
- Modify: `scripts/end_renderer.gd` (вызовы view, `hud`: полоса фазы 2 и значок адаптации, камера крупных планов финала), `scripts/end_world.gd` (`camera()`: отъезд при Проекции, наезд при кадре), `data/end_audio.json` (новые id: `ch3_clock_tick`, `ch3_clock_chime`, `ch3_rewind`, `ch3_frame_shutter`, `ch3_speed_boom`, `ch3_crush`, `return_by_death` — из ванильных файлов в `assets/audio/minecraft` и `end_ext`)
- Test: `qa/test_ch3_finale_visual.gd` (снимки PNG в `qa/ch3_finale_*.png`)

**Interfaces:**
- Consumes: всё состояние из Task 3–8.
- Produces: `static func draw_world(g, offset: Vector2)` (пути Проекции контурами кадров, послеобразы, кольца ускорения, часы, откат), `static func draw_screen(g)` (рамка кадра, золото-фиолетовый тон отката, карточки), `static func draw_finale(g, a: float)` (крупные планы финала на атласах Task 7).

- [ ] **Step 1:** Визуальный тест: снять кадры `projection` (каждый круг), `framed`, `framed_strike`, `clock running`, `rewind`, `rebirth`, `phase2 hud`, `standoff`, `clash` с булавой и с мечом, `sword_race` (каждый такт), `bad_end`, `mercy raise`, `mercy lower`, `talk`. Тест падает, пока view нет.
- [ ] **Step 2:** Реализовать view и звуки. Предупреждения — только `Tells.lane` / `Tells.ring`.
- [ ] **Step 3:** Прогнать тест, просмотреть каждый PNG через Read. Проверить: читаемость на 640×360, нет полупрозрачных зон, текст не обрезан, оружие в руке то, что надо. Исправлять, пока не годно.
- [ ] **Step 4:** Ролик через Movie Maker (`--write-movie … --fixed-fps 30 --disable-vsync`, сценарий по образцу `qa/end_finale_record.gd`) → ffmpeg mp4 в `qa/recordings/ch3_finale.mp4`. Просмотреть ключевые кадры.
- [ ] **Step 5: Commit** «Глава III: отрисовка и звук нового финала».

### Task 10: Баланс, регрессии, билд

**Files:**
- Modify: `qa/end_boss_runs.gd` (бот обходит пути Проекции и точки перехвата, во время часов играет от уворотов; режим `--naive` без уклонения; сборки + «сахар 5»), `data/end_balance.json`, константы в `end_steve_boss.gd`
- Modify: `AGENTS.md`, `docs/AGENT_HANDOFF.md` (раздел «Глава III — финал 14.11»)

- [ ] **Step 1:** `-s qa/end_boss_runs.gd` → умный бот выигрывает хотя бы на 2 из 4 сборок, `minimum_hp` ≤ 8; наивный бот (и булава, и сахар 5) проигрывает на всех. Подкручивать цифры, пока не выполнится.
- [ ] **Step 2:** Все `qa/test_end*.gd`, `qa/test_ch3_finale*.gd` → 0 failures; `qa/test_determinism.gd -- --record`, затем без `--record` → OK.
- [ ] **Step 3:** `scripts/build.sh`; скопировать Windows-сборку в `builds/windows/`, упаковать zip.
- [ ] **Step 4:** Обновить `AGENTS.md` / `docs/AGENT_HANDOFF.md`.
- [ ] **Step 5: Commit** «Глава III: баланс финала, документация, сборки».
