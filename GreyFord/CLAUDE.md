# Серый Брод — вертикальный срез

Godot **4.6+** (не 3.x), GDScript со строгой типизацией. Проект лежит в `GreyFord/`
(корень репозитория содержит другой, не связанный проект).

## Игра

Тёмное средневековье, чумная деревня Серый Брод, сумерки. Тон мрачный, тихий, без пафоса.
Героиня — Мара, странствующая травница. Цель среза: убедить стражника у ворот открыть их
до наступления ночи.

Сюжет («Пятно»): Мара пришла лечить, а утром нашла у себя на запястье чумное пятно.
Ей нужно к отшельнику-лекарю за рекой; на закате ворота заложат до утра. Хельга (старая
повитуха) догадывается и молчит; Томаш (молодой стражник, мать умерла от мора) боится
выпустить заразу. Убеждая его, Мара лжёт, что здорова.

- **Локация:** одна деревня — 5 домов, церковь с колокольней, костёр в центре, лес по краям,
  частокол и запертые ворота. Дома и церковь собираются `KitBuilder` из модулей Medieval
  Village MegaKit, лес и трава — Stylized Nature MegaKit (Quaternius, CC0), земля —
  `Terrain` (рельеф кодом, текстуры Poly Haven CC0). Костёр, частокол, ворота — примитивы.
- **Персонажи:** модульные модели Quaternius (CC0, `resources/models/characters/`, источники
  в `SOURCES.md`). `CharacterModel` собирает тело + наряд + причёску на общий скелет,
  обрезает базовое тело до головы, берёт анимации из UAL1/UAL2 (`Idle`, `Walk`,
  `Idle_Talking`, `Sitting_Idle`, `Idle_FoldArms`, `Idle_Torch`, ...).
  Только CC0/свободные ассеты. Скачанные архивы перед использованием проверять
  (листинг без распаковки, без исполняемых файлов и скриптов), в проект брать только
  модели и текстуры; источник и лицензию класть рядом.
  Атмосфера светом: туман, тёплый мерцающий свет костра, холодный направленный свет,
  тени, светящиеся окна.
- **Управление:** вид от третьего лица, WASD (по физическим клавишам — работает в русской
  раскладке), камера следует за героиней, E — взаимодействие в радиусе (Area3D) с подсказкой.
- **Статы** (Resource `CharacterStats`): Наблюдательность, Убеждение, Сила, Лекарское дело.
  Значения только в `resources/*.tres`, не в коде.
- **Диалоги:** аддон Dialogue Manager (nathanhoad), файлы `dialogues/*.dialogue` на русском,
  короткие реплики, 2–4 варианта ответа.
  - Хельга у костра: знает, что стражник боится заразы; даёт подсказку при правильных вопросах.
  - Томаш у ворот: убедить (d20 + Убеждение против 12), показать лекарские навыки
    (d20 + Лекарское дело, только если `talked_helga`), или уйти.
  - Флаги: `talked_helga`, `gate_open`, `tomash_refused` (уговоры — одна попытка;
    лекарское дело можно повторять, чтобы не было тупика). Бросок — `DialogueRunner.roll_check`,
    результат показывает HUD.
- **Катсцены:** вступление (камера от церкви к костру и героине, 2–3 строки субтитров),
  финал (ворота открываются, затемнение, «Конец первой главы»). Анимация — Tween/код.

## Структура

```
GreyFord/
  project.godot
  addons/        сторонние аддоны (dialogue_manager)
  scenes/        .tscn (текстовые, создаются вручную/кодом, не в редакторе)
  scripts/       .gd; scripts/autoload/ — синглтоны
  dialogues/     .dialogue
  resources/     .tres, .gdshader, прочие ресурсы; resources/models/ — сторонние модели
```

Автолоады: `GameState` (флаги, статы, блокировка управления), `DialogueRunner` (запуск
диалогов, проверки навыков), `Transition` (затемнения), `DebugMenu` (F3).

## Архитектура

- `GameState` — флаги (`talked_helga`, `gate_open`), статы, счётчик блокировки управления.
- `DialogueRunner.start_dialogue(resource, cue, speaker)` — открывает `DialogueBalloon`
  (субтитры без подложки), блокирует управление; сигналы `dialogue_started/finished`.
- `Interactable` (Area3D, физ. слой 4 «interact») ← `InteractionDetector` у Мары (E).
  `Inspectable` — объект с коротким диалогом; `npc.gd` — NPC с диалогом и анимацией речи.
- `Terrain` — рельеф, коллизия HeightMapShape3D, `height_at()` для расстановки;
  `KitBuilder` — дома/церковь из модулей (сетка 2 м, фасад смотрит в +Z).
- `CutsceneDirector` (узел в main) — вступление (пропуск E/Esc) и финал по флагу
  `gate_open`; своя камера и оверлей. `godot -- --skip-intro` начинает сразу с игры.
- `Effects` — частицы (пламя, искры, дым, дымка; CPUParticles3D, с прогревом `preprocess`);
  `ProceduralSound` — звуковые заглушки, синтезируемые кодом (костёр, ветер, шаги, скрип).
- `CharacterModel` — модульный персонаж Quaternius; `UiStyle` — шрифт и обводка текста
  (Cormorant Garamond, OFL, `resources/fonts/`).

## Три дня (шаги 2–4 второй части)

- `GameState`: день, слоты (`spend_slot`, `slots_left`), фаза DAY/NIGHT, травы, лекарство,
  здоровье больных (`sick_health`), поимки, флаги (`has_flag/set_flag`), сохранение
  JSON в начале каждого дня (`user://greyford_save.json`). Числа — `resources/game_config.tres`.
- Действия за слот: лес (`ForestZone`, лаз за церковью), котёл (`cauldron.gd`), визит к
  больному (`SickHouse` + `dialogues/sick.dialogue`). Ходьба по деревне бесплатна.
- `DayDirector`: конец дня → ночь → утро; день 3 → финал. `WorldLighting` — свет по времени.
- `Guard` — стелс-ИИ (конус зрения + луч, Patrol/Suspicious/Chase/Search), `HideZone` — укрытия.
- `Transition` (автолоад) — затемнения и титры. `main_menu.tscn` — стартовая сцена.

## Бой (третья часть, шаг 1)

- `PlayerCombat` — дочерний узел `Combat` у игрока; если он есть, `player.gd` отдаёт ему
  движение (`drive()`). Удар/блок/перекат/стамина/захват цели/смерть. Числа —
  `resources/combat/hero_combat.tres` (`HeroCombatData`).
- `Hitbox` / `Hurtbox` (физ. слой 5) обмениваются `HitInfo`; получатель пишет `result`.
- `CombatBody` — база для целей (здоровье из `EnemyData`, вспышка, цифры урона, группа
  `lock_target`, слой 2). `TrainingDummy`, `SparringPartner` — цели арены.
- `HitFeel` — hitstop через `Engine.time_scale` и тряска камеры (группа `camera_rig`).
- `RespawnPoint` у костра запоминает `GameState.respawn_point`; монеты — `GameState.coins`.
- Тестовая арена `scenes/test/combat_arena.tscn`, автотест `tools/tests/combat_test.gd`.

## Мобы (шаг 2)

- `Enemy` (extends `CombatBody`) — враги: `StealthSense` (общий с `Guard`: конус + луч +
  шкала тревоги) и состояния PATROL/SUSPICIOUS/CHASE/SEARCH/ATTACK/STAGGER/RETREAT/
  PARLEY/CALM/DEAD; путь через `NavigationAgent3D` (без навмеша — по прямой).
- `EnemyData` (.tres) — здоровье, скорости, зрение, стойкость, `attacks: Array[EnemyAttack]`,
  ночные множители, вторая фаза, подкуп/убеждение, `LootTable`.
- `EnemyAttack` — клип и момент удара, урон, окна windup/active/recovery, хитбокс, цвет
  телеграфа (светится оружие или сам зверь), отскок.
- Сцены `scenes/enemies/` (wolf, bandit, infected, bandit_chief). `AnimatedModel` — общий
  API анимаций для `CharacterModel` и `AnimalModel` (Quaternius-животные).
- Разбойник при первой встрече запускает `dialogues/bandit.dialogue`;
  `GameState.resolve_parley()` пишет флаг `<id>_<исход>`. Лут — `LootDrop` → `GameState.add_loot()`.
- Автотест `tools/tests/enemy_test.gd`.

## Экономика (шаг 3)

- `Item` / `ItemCatalog` (`resources/items/catalog.tres`) — все предметы, травы и отвар тоже.
  `GameState.count/give/take/bag()` — единая сумка (травы и отвар в своих счётчиках),
  `equipment` (weapon/shield/armor), `equip/unequip`, сигнал `equipment_changed`.
- `MerchantData` (`resources/merchants/*.tres`) — ассортимент и множители цен от доверия.
  `GameState.buy/sell/buy_price/sell_price/stock`; запас пополняется в `begin_day()`.
- Диалог торговца вызывает `GameState.open_trade(id)` → `TradeWindow` (после диалога).
  `InventoryWindow` — сумка по I. Оба — `GameWindow` в HUD, блокируют управление.
- `PlayerCombat.attack_damage()`, броня и щит из экипировки; H — `use_item` лучшего бинта.
- Таблица баланса — `docs/economy.md`. Автотест `tools/tests/trade_test.gd`.

## Интеграция (шаг 4)

- В `main.tscn`: `Player/Combat` (бой везде), `Campfire/RespawnPoint`, `Encounters`
  (волки и разбойники в лесу по дням, заражённые ночью; числа в `game_config.tres`,
  убитые по флагу `<id>_killed` не появляются), `Market` (торговцы днём).
- Сохранение v2: `coins`, `items`, `equipment`, `hero_health`. `PlayerCombat` держит
  `GameState.hero_health` в синхроне; сон даёт `sleep_heal`.
- Автотест `tools/tests/world_test.gd` (с `-- --skip-intro`).

## Отладка (шаг 5)

- Автолоад `DebugMenu` (`scripts/autoload/debug_menu.gd`), F3 ловится в `_input` (работает
  и во время диалогов). Пропуск дня — `DayDirector.debug_skip()` (группа `day_director`).

## Правила

- Только Godot 4 API. Никаких `yield`, `onready var` без `@`, `KinematicBody` и т.п.
- Строгая типизация: у каждой переменной, параметра и возврата есть тип
  (`untyped_declaration` = ошибка в настройках проекта). `:=` допустимо.
- Никакой ручной работы в редакторе: узлы создаются кодом или в текстовых `.tscn`.
- Связь через сигналы. Не использовать жёсткие пути к узлам (`get_node("../../X")`,
  `$"/root/..."`). Допустимо: дочерние узлы своей сцены, группы, `@export`-ссылки,
  сигналы автолоадов.
- Числа баланса (статы, сложности) — в `.tres`, не в коде.
- Не добавлять то, чего нет в задаче; идеи вне плана — в `docs/ideas.md`.
- Тексты для игрока — на русском.

## Проверка

После каждого шага:

```
cd GreyFord
godot --headless --import   # первый раз / после добавления ресурсов
godot --headless --quit
```

Ошибок в выводе быть не должно. Затем коммит.
Скриншот (есть Xvfb): `xvfb-run -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 ...`.
