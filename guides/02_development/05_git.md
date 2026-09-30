# Git и версии

Репозиторий: github.com/sashabrave/rubezh-13 (приватный). Вход по SSH-ключу.

## Ветки

- `main` — всегда рабочая версия. Напрямую в неё не пишем, только слиянием.
- `feature/<кратко>` — новая механика или контент: `feature/printer-shell`, `feature/boss-klesh`.
- `fix/<кратко>` — исправление ошибки: `fix/adaptive-orders-crash`.
- `release/<версия>` — только если нужно довести сборку, пока в `main` уже идёт новая работа.

Одна задача — одна ветка. Ветка живёт дни, не недели.

## Обычный цикл

```bash
git switch main
git pull
git switch -c feature/название
# работа, проверки из 04_testing.md
git add -A
git commit -m "Коротко: что изменилось"
git push -u origin feature/название
```

Дальше на GitHub: Pull request → проверить изменения → Merge → удалить ветку. Локально: `git switch main && git pull`.

## Версии

Формат `alpha-MAJOR.MINOR.PATCH` в BUILD_VERSION.txt и тег `vMAJOR.MINOR.PATCH-alpha`:

- PATCH — только исправления (0.1.0 → 0.1.1);
- MINOR — новые механики, контент, баланс (0.1.1 → 0.2.0);
- MAJOR — выход из альфы / несовместимые сохранения (→ 1.0.0).

Выпуск версии: обновить BUILD_VERSION.txt и export_presets.cfg, закоммитить в `main`, затем

```bash
git tag -a v0.2.0-alpha -m "Альфа 0.2.0"
git push origin v0.2.0-alpha
```

На GitHub в Releases можно создать релиз из тега и приложить архив сборки. Сами сборки (`build/`) в git не хранятся.

## Что не попадает в git

`.godot/`, `build/`, `tmp/`, логи, `.blend1/.blend2`, `.DS_Store`, `export_credentials.cfg` — см. `.gitignore`. Пароли, ключи подписи и сертификаты в репозиторий не добавлять.

## Если что-то пошло не так

- Посмотреть, что изменено: `git status`, `git diff`.
- Отменить незакоммиченные правки в файле: `git restore путь`.
- Вернуться к версии: `git switch --detach v0.1.0-alpha`, назад — `git switch main`.
