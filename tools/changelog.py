#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Добавить строку в data/changelog.json (верхняя запись — текущая версия).

  python3 tools/changelog.py "строка по-русски" "line in English"
  python3 tools/changelog.py --new 0.7.2 "Заголовок" "Title"   — начать запись новой версии
"""
import json, os, sys, datetime
p = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data", "changelog.json")
d = json.load(open(p, encoding="utf-8"))
a = sys.argv[1:]
if a and a[0] == "--new":
    d["entries"].insert(0, {"date": datetime.date.today().isoformat(), "version": a[1], "ru": {"title": a[2], "items": []}, "en": {"title": a[3], "items": []}})
elif len(a) == 2:
    d["entries"][0]["ru"]["items"].append(a[0]); d["entries"][0]["en"]["items"].append(a[1])
else:
    sys.exit(__doc__)
open(p, "w", encoding="utf-8").write(json.dumps(d, ensure_ascii=False, indent="\t") + "\n")
print(d["entries"][0]["version"], len(d["entries"][0]["ru"]["items"]))
