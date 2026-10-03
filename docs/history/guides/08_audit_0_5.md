# Технический аудит 0.5 (1 октября 2026)

Два прохода: мёртвый код и ассеты; «цепочки» параметров, которые задаются, но не доходят до игры. Ниже — что исправлено сразу и что оставлено с причиной.

## Исправлено
- Сохранения: схема отклоняла собственный снимок профиля (списки в viewed_updates). Подробно в 02_rules_saves.md.
- Продолжение забега теряло одноразовое спасение от смертельного удара (mercy_used) и счётчик гарантии редкой карты (dry_offers). Оба добавлены в RunCheckpoint.RUN_KEYS.
- Прогноз награды в карточке поля на карте считал +4 + 2×этап, а игра платит clear_reward + progress_index × clear_reward_per_room. Карточка теперь берёт ту же формулу.
- Энциклопедия описывала «Последний рубеж» как +25% темпа пехоты; карта и код дают +30% урона пешком и в технике. Текст и теги карты исправлены.
- Таймеры HUD «Десант», «Выдержка», «Рывок» оставались на экране навсегда (отрицательный остаток читался как «активно»).
- Удалено без ссылок: scripts/ui/guide_tree.gd и его сломанный тест, четыре старые сцены интерфейса (upgrade_row, ability_card, inventory_slot, pause_screen), семейства моделей kit_v4 и infantry_v5 с тестами, корневые glb врагов (их заменили *_v6), assets/audio/v2 и четыре старых wav, мёртвые функции в hud/hub/game/run_ability/wave_director/build_catalog/fighter_station.
- audio_demo и screenshots получили .gdignore: редактор больше не импортирует 150 лишних файлов.

## Оставлено, нужен отдельный шаг
- **Старые экраны верстаков хаба** (open_workshop, show_garage, show_hq_workshop, show_classes, сцены character/weapon/bonus_workshop, weapon/bonus_card, garage/hq workbench). Игра открывает станции через station_screen, но 11+ тестов ещё водят старые экраны, а узел CharacterWorkshop держит label status для interact(). Удалять вместе с переводом этих тестов и переносом status.
- **Мёртвые поля баланса.** campaign_tuning: room_sizes, late_zone_one_scale, zone_two_*, drone_surprise_chance, extra_soldier_chance, vehicle_first_room, machine_weights; wave_counts/wave_budgets/active_enemy_caps читаются только тестами. Волны собирает WaveDirector.build с числами в коде, лимит активных — Campaign.active_cap. combat_tuning: first/second/superboss_health дублируют Campaign.WORLDS[*].boss_hp. docs/EDITING_GUIDE.md учит править мёртвые поля. Нужно либо перенести реальные числа в эти ресурсы, либо удалить поля и обновить редакторский инструмент.
- **Числа в коде вместо баланса:** перезарядка снайпера 4.0 (в ресурсе 5.5), РПГ 4.8, мины-растяжки, ранг 3 (HP ×2.1, урон ×1.55), цены техники 240/650/1400, вторая ячейка способности 2500 (ресурс говорит 15 документов).
- **Списки-копии, которые сломаются на новом контенте:** список пехоты встречается 9 раз, списки техники — 27 раз в 18 вариантах; словари вида dict[kind] без get (EncounterRules.KILL_ALLOY, commander_name, GameBalance.wave_costs). Новый тип врага или машины нужно будет прописать во всех местах — стоит завести EnemyCatalog.infantry()/vehicles() и брать награду за убийство из EnemyBalance.
- **Миры зашиты как 1..3:** clampi(id,1,3), world==3 особые случаи, проверка контрольной точки [1,2,3]. Для 4-го мира нужен список миров из данных.
- **Сигналы без слушателей или без отправителя:** route_map.enter_requested, route_map.test_requested, class_gallery.shell_requested, FlowSystem.changed, InputScheme.changed.
- **Крупные ассеты:** assets/audio/music 618 МБ wav (boss_variation_1/2 не используются); nano_banana 19 МБ уходит в сборку как второй набор иллюстраций; assets/models/cozy 3,2 МБ почти наверняка мёртв.
- **Устаревшие тесты:** editor_workflow, update_v05/v06/v08, campaign_v09 (boss_lasers), refactor_contract (нет tmp/refactor-before), визуальные тесты пишут в несуществующий art_demo. Падали и до этой сессии: reinforced_brick «Placement follows the route», printer_revision, route_map_v8.

## Сделано в 0.6.0
- Старые экраны верстаков удалены: панели CharacterWorkshop/WeaponWorkshop/BonusWorkshop в hub_screen.tscn, их сцены и карточки, garage/hq workbench, model_preview, прослойка ui/fighter_station.gd и функции hub.gd вокруг них. Статус взаимодействия — скрытая метка StatusLabel. 12 исторических тестов старого интерфейса удалены, 7 переведены на open_station.
- CampaignTuning переписан: только читаемые игрой поля (миры, рост по полям, размер волны, лимит активных, дроны). Campaign.hp_scale/damage_scale/boss_health/active_cap, WaveDirector.wave_size и SurpriseSystem берут числа оттуда; значения по умолчанию равны прежним. Мёртвые поля и дубли здоровья боссов в combat_tuning удалены. Перезарядка снайпера читается из sniper.tres (4,0 с).
- UnitKinds (scripts/combat/unit_kinds.gd) — семейства пехоты, техники и летающих. Копии списков в actor, arena, visuals, status_fx, ability_effect, combat/reward/enemy systems заменены. Словари по типу (награда за убийство, имя командира, паузы перебежек) берут значение по умолчанию для нового типа. GameBalance.wave_costs добавляет новых врагов из ресурсов после прежнего порядка.
- Остаются: списки миров 1..3 в контрольной точке и Campaign.configure, белый список гаджетов, цены техники в garage/state.gd.
