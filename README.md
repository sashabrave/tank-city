# War Cats

Изометрический экшен-роглайт на Godot 4.7.2: кот-боец держит мобильный штаб, угоняет технику врага, собирает билд из карточек и развивает заставу между вылазками. Альфа 0.8.0 «Демо» — мир 1 и бесконечный режим.

## С чего начать

1. [AGENTS.md](AGENTS.md) — правила для агентов.
2. [guides/00_start/01_project.md](guides/00_start/01_project.md) — проект, запуск, карта документации.
3. [guides/00_start/02_agent_handoff.md](guides/00_start/02_agent_handoff.md) — текущее состояние, задачи, решения автора.
4. [guides/04_handbook/01_handoff.md](guides/04_handbook/01_handoff.md) — правила, быстрый старт, где что лежит.

## Запуск

```
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import   # один раз на свежей копии
/Applications/Godot.app/Contents/MacOS/Godot --path .                        # игра
tools/run_tests.sh quick                                                     # быстрые проверки
python3 tools/board.py list                                                  # доска задач
```

## Папки

| Путь | Что |
|---|---|
| `scripts/`, `scenes/`, `shaders/` | Код и сцены игры |
| `assets/` | Модели, текстуры, звук, баланс (`assets/balance/**/*.tres`) |
| `data/` | Changelog, энциклопедия, локаль, материалы, иконки |
| `guides/` | Актуальная документация; её же показывает планшет → Тех. информация |
| `tests/` | Сцены проверок, наборы в `tests/suites` |
| `tools/` | Сборка, тесты, доска задач, генераторы моделей, арта и музыки |
| `tasks/` | Доска задач и скриншоты к ним |
| `art_requests/`, `assets_src/` | Исходники арта: листы GPT Image, Blender-скрипты |
| `docs/` | История прошлых версий, не актуальна |
