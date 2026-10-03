# Хендбук · 3. Техническая архитектура

## Слои

```
Автозагрузки (глобальное состояние и сервисы)
  └─ main.gd — поток экранов
       ├─ hub.gd (хаб-база, станции, постройки)
       ├─ route_map.gd (карта маршрута, депо, выбор точки)
       ├─ arena.gd (координатор боя) → systems/* + state/*
       ├─ service_room.gd / merchant_room.gd (сервисные комнаты)
       └─ UI-оверлеи: field_tablet (планшет), station_screen, video_call, loading_veil
Данные: assets/balance/**/*.tres, data/*.json, data/locales/en.tsv
```

## Автозагрузки (`project.godot`)

| Имя | Скрипт | Роль |
|---|---|---|
| `Texts` | `ui/game_texts.gd` | Язык, перевод фрагментами, энциклопедия, `set_text` |
| `Game` | `game.gd` | Профиль: валюты, прокачка, постройки, классы, скины, чекпоинт забега, сохранение |
| `Settings` | `settings.gd` | Настройки, окно, VSync, MSAA, масштаб 3D (`render_scale`), клавиши |
| `InterfaceTheme` | `ui/interface_theme.gd` | Тема и акцентный цвет |
| `CardNavigation` | `card_navigation.gd` | Навигация по карточкам клавиатурой и геймпадом |
| `NumberDisplay`, `ResourceStrip` | `ui/*` | Числа и полоса валют |
| `ProfileMenu` | `ui/profile_menu.gd` | Выбор слота |
| `PerfOverlay` | `ui/perf_overlay.gd` | Номер сборки и FPS |
| `InputScheme` | `input_scheme.gd` | Автоопределение: касание, геймпад, клавиатура |

## Поток экранов (`main.gd`)

`start_run` → `show_map(0)` → `enter_room(i)`: либо бой (создаётся или переиспользуется `run_arena`), либо сервис (`show_node_service`). `run_arena` живёт весь забег и уходит из дерева, пока открыта карта. `resume_run` восстанавливает забег из `Game.run_checkpoint`: при продолжении в карту поле боя не строится (`Arena.defer_room`), переход идёт под `loading_veil`. `show_sandbox` — отдельная арена с админ-панелью, прогресс в песочнице не сохраняется.

## Бой: координатор и системы

`arena.gd` — тонкий координатор: держит ссылки, делегирует системам и хранит свойства-прокси на `room`/`run`.

| Система | Ответственность |
|---|---|
| `flow_system` | Фазы (countdown, combat, upgrade, map, result), волны, флаг выхода, завершение забега |
| `combat_system` | Пули, попадания, взрывы, урон штабу, гибель актёров, трофеи |
| `enemy_system` | Поведение врагов, миномёты, дроны, бомбы |
| `reward_system` | Добыча, бонусы на парашюте, карточки, сундуки, серия убийств |
| `vehicle_system` | Посадка и высадка, корпуса, доставка техники |
| `boss_system` | Боссы, генераторы щита, командиры |
| `board_system` | Стены из секций, бочки, окопы, укрепления |
| `terrain_system` | Покрытия (вода, лёд, песок, растительность), пакетная отрисовка MultiMesh |
| `navigation_cache` | Инкрементальный A* и кэш линий огня |
| `surprise_system`, `challenge_rooms` | Внезапные атаки, испытания |
| `weather`, `terrain_ambience`, `vegetation_ambience`, `block_decor` | Только визуал |

**Состояние:** `RunState` (весь забег: характеристики, карточки, сплав, генератор `combat_rng`, флаги сглаживания), `RoomState` (текущее поле: стены, актёры, снаряды, штаб, генераторы, волны). Чекпоинт (`profile/run_checkpoint.gd`) сохраняет `RUN_KEYS` плюс все поля реестра характеристик автоматически.

**Боевые модификаторы:** `combat/combat_mods.gd` — единственное место расчёта исходящего и входящего урона игрока: синергии, крит с перетоком, статусы, уклонение, защита по источнику. Пределы — `CAPS`.

## Реестры данных (добавляй файл — получаешь фичу)

| Реестр | Файлы | Потребители |
|---|---|---|
| `UpgradeRegistry` / `UpgradeDef` | `assets/balance/upgrades/*.tres` | Выдача карточек, превью, справочник |
| `StatRegistry` / `StatDef` | `assets/balance/stats/*.tres` | Досье, чекпоинт, песочница, справочник |
| `Balance.CONFIG` | `game_balance.tres` → combat, economy, campaign, enemies, weapons, abilities | Все системы |
| `ClassCatalog` | `scripts/classes/class_catalog.gd` | Казарма, выдача карточек, старт забега |
| `BossCatalog` | `scripts/boss_catalog.gd` | Боссы, превью, справочник |
| `GarageCatalog` | `scripts/garage/catalog.gd` | Стоянка, техника игрока |
| `BiomeCatalog` | `scripts/biome_catalog.gd` | Палитра, покрытия, звук окружения |

## Сохранения

Папка данных задана жёстко: `config/custom_user_dir_name="Godot/app_userdata/Рубеж - 13"` в `project.godot`. Она не зависит от названия игры (Tank City → War Cats не сдвинуло сохранения). **Никогда не менять это значение** без переноса файлов: у игроков пропадут профили.

`profile/slots.gd` — 3 слота (`progress_v1.json`, `profile_2.json`, `profile_3.json`, индекс `profiles.json` в `user://`). `profile/store.gd` пишет безопасно: временный файл → проверка → замена, с `.bak`. `profile/schema.gd` (версия 12) валидирует и мигрирует. Прогресс-ачивки, виденные вызовы и уведомления — в `Game.progression` (`base_progression.gd`).

## Интерфейс

- **UiKit** (`scripts/ui_kit.gd`): стиль, кнопки, иконки (`icon_texture` с цепочкой запасных наборов), стекло (`glass`, шейдер `shaders/ui/glass.gdshader`), бейджи, `tab_row`, ритм планшета (`PAGE_TITLE_SIZE` 20, `PAGE_PADDING` 24, `PAGE_CONTENT_TOP` 64).
- **Станции хаба:** один шаблон `ui/station_screen.gd` + провайдеры `ui/stations/*` (items / detail / act). Статус карточки выводится централизованно (`status()`).
- **Планшет** (`ui/field_tablet.gd` + `tablet_pages.gd`): Снаряжение, Вылазка (отчёт о забеге, `ui/sortie_report.gd`), Задачи, Лента, Радио, Настройки, Энциклопедия, Об игре (changelog по версиям), Тех. информация (эти гайды).
- **HUD боя:** `hud.gd` + `hud.tscn`, полоска эффектов `ui/status_strip.gd`, точки этапов `pip_strip`.

## Визуал

`visuals.gd` — фабрика моделей (`model`, `kit_model` для пехоты и техники v6), материалы, кольца, подписи. `kit_model.gd` — анимации и окраска по состоянию (`set_paint`: свой, враг, трофей, взрыв). Свет — `world_lighting.gd` (стили, момент суток, бюджет ламп, поле), атмосфера и облака — `world_atmosphere.gd`, тилт-шифт и дымка — полноэкранные шейдеры. Постановка боя — `battle_stage.gd`, камера — `battle_presentation.gd` (орбита и подлёты), наклон — `camera_tilt.gd`. Статусы на моделях — `status_fx.gd`, боеприпасы — `ordnance.gd`, `fx_motion.gd`.

## Звук и музыка

`audio_controller.gd` (события с громкостью и пространством), `music_controller.gd` (темы дня и ночи из `assets/audio/music/themes.json`, радио, переходы через тишину). Генераторы звука и музыки — `tools/build_*audio*.py`, `tools/build_music_*.py`. Музыкой занимается отдельная сессия: её файлы при слиянии брать из `main`.

## Производительность

- Главная нагрузка — полноэкранные эффекты при большом разрешении. `Settings.render_scale()`: авто держит около 2,4 Мп 3D (FSR 1), интерфейс в родном разрешении. SSAO в половинном разрешении.
- Настройки экрана (0.7.2): `Settings.DISPLAY_KEYS` (режим, разрешение окна, Retina, VSync, разрешение 3D, MSAA, лимит кадров) ждут в `Settings.pending` кнопки «Применить» (`apply_pending`) или «Сохранить» (`save_all`); страница показывает `Settings.shown(key)`. Остальные настройки применяются сразу. `apply_display()` трогает режим окна, размер и VSync только при смене их собственных значений — переключение других опций не сбрасывает полный экран и размер. Retina выключена — 3D рисуется с плотностью 1/`screen_get_scale()`. Разрешения окна — в точках (как показывает система), окну передаётся точки × `pixel_ratio()`. После «Применить»/«Сохранить» экранных настроек — окно «Оставить эти настройки?» на 15 с; без ответа `revert_display()` возвращает прежние значения. В углу рядом с FPS — число фризов (кадры дольше 50 мс за 10 с).
- Не использовать `light_projector` (cookie) у ламп: в Godot 4.7 текстура, созданная в коде, полностью гасила свет и роняла FPS.
- Отрисовок 1100–1600 за кадр. Резерв — MultiMesh для пола и стен, запекание декора хаба.
- Навигация — инкрементальный A* с бюджетом; генерация покрытий ~4 мс.
- Продолжение забега: 73–113 мс синхронно, под экраном загрузки.
