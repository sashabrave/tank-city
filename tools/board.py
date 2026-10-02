#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Мини-доска задач War Cats (tasks/board.json).

  python3 tools/board.py sync            — забрать входящие из собранной игры (задачи, переносы, скриншоты)
  python3 tools/board.py list [статус]   — показать доску (backlog/doing/review/done), важное сверху
  python3 tools/board.py add "Название" [--note ...] [--type bug|idea|polish|question] [--priority 1|2|3] [--version 0.7.2]
  python3 tools/board.py move T-012 doing

Входящие собранной игры лежат рядом с сохранениями: ~/Library/Application Support/Godot/app_userdata/Рубеж - 13/
(task_inbox.json и task_shots/). Агент запускает `sync` и `list` в начале каждой рабочей сессии.
"""
import json, os, shutil, sys, datetime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BOARD = os.path.join(ROOT, "tasks", "board.json")
SHOTS = os.path.join(ROOT, "tasks", "shots")
USER = os.path.expanduser("~/Library/Application Support/Godot/app_userdata/Рубеж - 13")
STATUSES = ["backlog", "doing", "review", "done"]
NAMES = {"backlog": "Бэклог", "doing": "В работе", "review": "Проверить", "done": "Готово"}
TYPES = {"bug": "баг", "idea": "идея", "polish": "полировка", "question": "вопрос"}

def load():
    with open(BOARD, encoding="utf-8") as f: return json.load(f)
def save(board):
    with open(BOARD, "w", encoding="utf-8") as f: json.dump(board, f, ensure_ascii=False, indent="\t"); f.write("\n")
def next_id(board):
    n = int(board.get("next_id", 1)); board["next_id"] = n + 1; return "T-%03d" % n
def find(board, tid):
    for t in board["tasks"]:
        if t["id"] == tid: return t
    return None

def sync():
    inbox = os.path.join(USER, "task_inbox.json")
    if not os.path.exists(inbox): print("Входящих нет."); return
    with open(inbox, encoding="utf-8") as f: events = json.load(f)
    board = load(); renamed = {}; added = moved = 0
    os.makedirs(SHOTS, exist_ok=True)
    for e in events:
        if e.get("op") == "add":
            t = dict(e["task"]); old = t["id"]; t["id"] = next_id(board); renamed[old] = t["id"]
            shot = t.get("shot", "")
            if shot.startswith("user://"):
                src = os.path.join(USER, shot[len("user://"):])
                if os.path.exists(src):
                    dst = os.path.join(SHOTS, t["id"] + ".png"); shutil.copyfile(src, dst); t["shot"] = "res://tasks/shots/%s.png" % t["id"]
            board["tasks"].append(t); added += 1
        elif e.get("op") == "move":
            t = find(board, renamed.get(e["id"], e["id"]))
            if t and e.get("status") in STATUSES: t["status"] = e["status"]; moved += 1
    save(board)
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    os.rename(inbox, inbox + ".synced-" + stamp)
    print("Забрано: новых задач %d, переносов %d." % (added, moved))

def show(only=None):
    board = load()
    for s in STATUSES:
        if only and s != only: continue
        items = [t for t in board["tasks"] if t.get("status") == s]
        items.sort(key=lambda t: (0 if t.get("type") == "question" else 1, int(t.get("priority", 2)), t["id"]))
        print("\n## %s · %d" % (NAMES[s], len(items)))
        for t in items:
            mark = "!" if int(t.get("priority", 2)) == 1 else " "
            ver = (" [%s]" % t["version"]) if t.get("version") else ""
            print(" %s %s  %s (%s)%s%s" % (mark, t["id"], t["title"], TYPES.get(t.get("type"), "?"), ver, "  📷" if t.get("shot") else ""))

def add(argv):
    title = argv[0]; opts = {"--note": "", "--type": "idea", "--priority": "2", "--version": ""}
    i = 1
    while i < len(argv) - 1:
        if argv[i] in opts: opts[argv[i]] = argv[i + 1]; i += 2
        else: i += 1
    board = load()
    t = {"id": next_id(board), "title": title, "note": opts["--note"], "type": opts["--type"], "priority": int(opts["--priority"]),
         "status": "backlog", "version": opts["--version"], "created": datetime.date.today().isoformat(), "source": "chat", "shot": ""}
    board["tasks"].append(t); save(board); print("Добавлено:", t["id"], title)

def move(tid, status):
    board = load(); t = find(board, tid)
    if not t or status not in STATUSES: sys.exit("Нет задачи %s или статуса %s" % (tid, status))
    t["status"] = status; save(board); print(tid, "→", NAMES[status])

if __name__ == "__main__":
    a = sys.argv[1:]
    if not a or a[0] == "list": show(a[1] if len(a) > 1 else None)
    elif a[0] == "sync": sync()
    elif a[0] == "add": add(a[1:])
    elif a[0] == "move": move(a[1], a[2])
    else: print(__doc__)
