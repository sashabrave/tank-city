"""Icon catalog: every drawn icon and interface glyph with its id, name, group and where it shows up.

Writes data/icon_catalog.json (read by the in-game icon inspector: right click on a picture) and
guides/02_development/09_icon_catalog.md (the same list for people, also in the tablet's tech info).
Run after adding icons:  python3 tools/art/build_icon_catalog.py
"""
import json
import re
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
KIT = ROOT / "assets/ui/icon_kit/symbols"
GPT = ROOT / "assets/illustrations/gpt_image_2_5/icons"


def tres_names(folder, field):
	names = {}
	for path in (ROOT / folder).glob("*.tres"):
		text = path.read_text(encoding="utf-8")
		key = re.search(r'^id = "(.+?)"', text, re.M)
		name = re.search(rf'^{field} = "(.+?)"', text, re.M)
		if key and name:
			names[key.group(1)] = name.group(1)
	return names


def dict_names(path, const):
	text = (ROOT / path).read_text(encoding="utf-8")
	block = text[text.index(f"const {const}"):]
	block = block[:block.index("\n}") if "\n}" in block[:4000] else block.index("}}") + 2]
	return dict(re.findall(r'"([a-z_0-9]+)":\{"name":"([^"]+)"', block))


UPGRADES = tres_names("assets/balance/upgrades", "title")
STATS = tres_names("assets/balance/stats", "title")
ABILITIES = tres_names("assets/balance/abilities", "name")
WEAPONS = tres_names("assets/balance/weapons", "name")
HQ = dict(re.findall(r'"(hq_[a-z]+)":\{[^}]*?"name":"([^"]+)"', (ROOT / "scripts/headquarters/catalog.gd").read_text(encoding="utf-8")))
BONUSES = dict_names("scripts/loot_catalog.gd", "BONUSES")
VEHICLES = dict(re.findall(r'"(buggy|apc|tank)":\{"name":"([^"]+)"', (ROOT / "scripts/garage/catalog.gd").read_text(encoding="utf-8")))
BRANCHES = dict(re.findall(r'"(armor|gun|loader)":\{"name":"([^"]+)"', (ROOT / "scripts/garage/catalog.gd").read_text(encoding="utf-8")))
WORKSHOPS = dict(re.findall(r'"([a-z_]+)":\{"name":"([^"]+)"', (ROOT / "scripts/game.gd").read_text(encoding="utf-8").split("const RESEARCH=")[1].split("\n")[0]))
WORKSHOPS.update({"command": "Командный центр", "mechanic": "Механик", "merchant": "Торговец", "recycling": "Переработка", "roadmap": "Развитие заставы", "wardrobe": "Гардероб", "yard": "Двор"})
RESOURCES = {"alloy": "Сплав", "token": "Жетон", "documents": "Документы", "core": "Документы (ядро)", "recipe": "Рецепт", "blueprint": "Чертёж"}

GROUPS = {
	"upgrades": ("Карточки забега", "Окно «Выбери усиление» между волнами; энциклопедия; сводка забега"),
	"stats": ("Прокачка бойца", "Казарма → прокачка, принтер бойца; энциклопедия"),
	"abilities": ("Способности", "Кнопки способностей в бою (Q/E); арсенал и карточки классов; навыки в хабе"),
	"headquarters": ("Технологии штаба", "Штаб в хабе; панель штаба в бою; чертежи"),
	"garage": ("Ветки техники", "Стоянка → улучшения багги, БТР и танка; чертежи"),
	"pickups": ("Бонусы поля", "Бонусы, выпадающие на поле; подсказки HUD; энциклопедия"),
	"building": ("Верстаки хаба", "Меню строительства, карточки верстаков, доска «Развитие заставы»"),
	"resource": ("Ресурсы", "Счётчик валют сверху, награды, итоги вылазки, торговец"),
	"category": ("Категории наград", "Значок категории в углу карточки награды (сундуки, чертежи, торговец)"),
	"ammo": ("Патроны", "Рюкзак и слоты патронов в планшете → Снаряжение; карточки патронов между волнами"),
	"blueprint": ("Чертежи", "Чертежи в рюкзаке (планшет → Снаряжение): один планшет, силуэт — категория"),
	"sender": ("Отправители сообщений", "Аватар в ленте заданий планшета: Штаб усов, Институт, Оперштаб"),
}


def name_for(group, key):
	if group == "upgrades":
		return UPGRADES.get(key, key)
	if group == "stats":
		return STATS.get(key, key)
	if group == "abilities":
		return ABILITIES.get(key, "Полевой ремонт" if key == "field_repair" else key)
	if group == "headquarters":
		return HQ.get(key, key)
	if group == "garage":
		kind, branch = key.split("_", 1)
		return f"{VEHICLES.get(kind, kind)} · {BRANCHES.get(branch, branch)}"
	if group == "pickups":
		return BONUSES.get(key, key)
	if group == "building":
		return WORKSHOPS.get(key, key)
	if group == "category":
		return {"hero": "Герой", "ability": "Способность", "hq": "Штаб", "bonus": "Бонус", "weapon": "Оружие", "vehicle": "Транспорт", "blueprint": "Чертёж", "trophy": "Трофей"}.get(key, key)
	if group == "ammo":
		return {"standard": "Обычные", "burn": "Зажигательные", "stun": "Контузящие", "shock": "ЭМИ", "explosive": "Разрывные", "ap": "Бронебойные", "ricochet": "Рикошет", "cryo": "Криогенные", "cluster": "Кассетные", "napalm": "Напалм"}.get(key, key)
	if group == "blueprint":
		return {"weapon": "Чертёж оружия", "garage": "Чертёж техники", "hq": "Чертёж штаба", "ability": "Чертёж способности", "bonus": "Чертёж бонуса", "research": "Чертёж постройки"}.get(key, key)
	if group == "sender":
		return {"quests": "Штаб усов", "guide": "Институт", "notifications": "Оперштаб"}.get(key, key)
	return RESOURCES.get(key, key)


entries = {}


def add(path, group, context, ids, name, note=""):
	rel = "res://" + str(path.relative_to(ROOT))
	entry = entries.setdefault(rel, {"path": rel, "group": group, "context": context, "ids": [], "names": [], "note": note})
	for i, n in zip(ids, name if isinstance(name, list) else [name] * len(ids)):
		if i not in entry["ids"]:
			entry["ids"].append(i)
			entry["names"].append(n)


# Drawn symbols mapped in data/icon_kit.json
kit = json.loads((ROOT / "data/icon_kit.json").read_text(encoding="utf-8"))["icons"]
by_symbol = defaultdict(list)
for icon_id, symbol in kit.items():
	by_symbol[symbol].append(icon_id)
for symbol, ids in sorted(by_symbol.items()):
	path = KIT / f"{symbol}.png"
	if not path.exists():
		continue
	first = ids[0]
	group = first.split("/")[0] if "/" in first else "resource"
	title, context = GROUPS[group]
	names = [name_for(i.split("/")[0] if "/" in i else "resource", i.split("/")[-1]) for i in ids]
	if len({i.split("/")[0] for i in ids}) > 1:
		parts = []
		for i in ids:
			for part in GROUPS[i.split("/")[0] if "/" in i else "resource"][1].split("; "):
				if part not in parts:
					parts.append(part)
		context = "; ".join(parts)
	add(path, title, context, ids, names, f"Символ «{symbol}»")
for path in sorted(KIT.glob("*.png")):
	if "res://" + str(path.relative_to(ROOT)) not in entries:
		add(path, "Запас символов", "Нарисован, пока нигде не подключён", [path.stem], path.stem)

# Drawn GPT pictures that are still used directly
for path in sorted((GPT / "weapons").glob("*.png")):
	add(path, "Оружие", "HUD (текущее оружие), арсенал, планшет → Снаряжение, торговец", [path.stem], WEAPONS.get(path.stem, path.stem))
for path in sorted((GPT / "upgrades").glob("legend_*.png")):
	add(path, "Легендарные правила", "Карточки «Захваченный КП» и их место в энциклопедии", ["upgrades/" + path.stem], UPGRADES.get(path.stem, path.stem))
for folder, group, context in [
	("assets/ui/slot", "Игровой автомат", "Окно автомата у торговца: символы барабанов"),
	("assets/ui/roadmap", "Развитие заставы", "Доска «Развитие заставы» в хабе: шаги целей"),
	("assets/ui/buildings", "Здания (иллюстрации)", "Крупные картинки зданий в окнах станций"),
	("assets/ui/icon_frames", "Рамки и шевроны", "Шевроны «уже взято» на карточке забега"),
	("assets/icons/v1", "Старый набор v1", "Запасной вариант, если для id нет нового символа"),
]:
	for path in sorted((ROOT / folder).glob("*.png")):
		add(path, group, context, [path.stem], path.stem)
add(ROOT / "assets/portraits/major.png", "Портреты", "Видеосвязь с майором Мурлыкиным", ["major"], "Майор Мурлыкин")

# Line glyphs (SVG): where each one is used, from the code
SCREENS = {"hud.gd": "HUD боя", "field_tablet.gd": "Планшет", "station_screen.gd": "Окна станций (вкладки)", "hub.gd": "Хаб",
	"merchant_room.gd": "Торговец", "weapon_locker.gd": "Оружейный шкаф", "music_mini_player.gd": "Мини-плеер музыки",
	"task_board_view.gd": "Доска задач", "world_select.gd": "Выбор мира", "incoming_call.gd": "Входящий вызов",
	"choice_card.gd": "Карточки наград (категория)", "ui_kit.gd": "Запасной вариант иконок"}
uses = defaultdict(set)
for script in (ROOT / "scripts").rglob("*.gd"):
	text = script.read_text(encoding="utf-8")
	for glyph in re.findall(r'interface_icon\("([a-z_]+)"', text) + re.findall(r'"([a-z_]+)" if [^)]*interface_icon', text):
		uses[glyph].add(SCREENS.get(script.name, script.stem))
for folder, group in [("assets/icons/interface_straight", "Линейные значки"), ("assets/ui/reward_categories", "Категории наград (линейные)"), ("assets/icons/current", "Линейные заглушки")]:
	for path in sorted((ROOT / folder).glob("*.svg")):
		where = ", ".join(sorted(uses.get(path.stem, []))) or "Через общий поиск иконок или пока не используется"
		if folder.endswith("reward_categories"):
			where = "Значок категории в углу карточки награды (сундуки, чертежи, торговец)"
		add(path, group, where, [path.stem], path.stem, "Векторный, растрируется в 3×")

out = sorted(entries.values(), key=lambda e: (e["group"], e["path"]))
(ROOT / "data/icon_catalog.json").write_text(json.dumps({"_about": "Generated by tools/art/build_icon_catalog.py", "icons": out}, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")

lines = ["# Каталог иконок", "", "Создано `tools/art/build_icon_catalog.py` — не править вручную. В игре: правый клик по любой картинке интерфейса открывает её карточку (id, название, где используется) и кнопку «На доску задач».", "", "Чтобы попросить новую картинку, назовите группу и id из этого списка и опишите, что нарисовать.", ""]
for group in sorted({e["group"] for e in out}):
	items = [e for e in out if e["group"] == group]
	lines += [f"## {group} ({len(items)})", "", f"Где: {items[0]['context']}", "", "| Файл | id | Название |", "|---|---|---|"]
	for e in items:
		file = e["path"].split("/")[-1]
		lines.append(f"| {file} | {', '.join(e['ids'])} | {', '.join(dict.fromkeys(e['names']))} |")
	lines.append("")
(ROOT / "guides/02_development/09_icon_catalog.md").write_text("\n".join(lines), encoding="utf-8")
print(len(out), "entries")
