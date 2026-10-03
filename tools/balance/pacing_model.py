#!/usr/bin/env python3
"""Модель темпа War Cats: забег → сплав → покупки → следующий забег.

Боевые числа — бот tests/balance_pacing (прогон: tools/balance/run_pacing.sh < tmp/pacing/matrix.txt).
Бот не умирает: урон по бойцу и штабу копится за поле. Модель переводит этот «нажим» в шанс гибели человека
двумя коэффициентами (K_SOLDIER, K_BASE), подобранными под якоря (см. calibrate и
guides/03_release/07_balance_pacing.md).

  python3 tools/balance/pacing_model.py aggregate            # tmp/pacing/*.log → tools/balance/pacing_data.json
  python3 tools/balance/pacing_model.py timeline             # хронология покупок, текущие цены
  python3 tools/balance/pacing_model.py timeline --costs old # цены до правки 0.7.2 (для сравнения)

Цены повторяют код (scripts/game.gd, garage/state.gd, headquarters/catalog.gd, assets/balance/economy.tres).
При правке цен в игре поправь COSTS / PRICES ниже. Время — минуты реальной игры (бой + меню + хаб), см. OVERHEAD.
"""
import glob, json, math, os, random, statistics, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DATA = os.path.join(ROOT, "tools", "balance", "pacing_data.json")
FIELDS = 7  # world 1: fields 0–5 + general (6)

# ---------------------------------------------------------------- human assumptions
OVERHEAD = {
    "field": 70,        # s per field: 2 card picks, countdowns, commander chest, route pick, walk to the flag
    "service": 40,      # s per instructor/merchant stop (before fields 2, 4 and the general)
    "hub": 100,         # s per hub visit: dialogue, quests, stations
    "buy": 8,           # s per purchase
    "result": 20,       # s result screen
}
ASSIST_SECONDS = 15     # each bot assist stands for ~20 s of the bot not finding a target; a person needs ~5 s
NOISE = 0.55            # log-normal spread of damage per field (good and bad rooms)
K_SOLDIER = None        # fitted in calibrate()
K_BASE = None
# Economy knobs mirrored from assets/balance/economy.tres: income = kill_alloy_scale / 4.0 (clear and chest rewards
# are a small share and scaled the same way here), loss = death_loss, loss_floor = death_loss_floor.
ECON = {"income": 1.0, "loss": .4, "loss_floor": .2, "boss": 1.0}  # boss = world_boss_health / 700 (campaign.tres)

# ---------------------------------------------------------------- bot data
# Meta states the bot played (tmp/pacing/matrix.txt): health, damage, mobility, pressure, class level.
STATES = {"S0": (0, 0, 0, 0, 0), "S1": (2, 2, 1, 0, 2), "S2": (4, 4, 2, 1, 4), "S3": (6, 6, 3, 2, 7), "S4": (8, 8, 4, 3, 10)}

def exposure(dmg, mob):
    """How long enemies keep shooting, relative to a fresh profile: kill speed (+5% per damage level) and moving
    out of fire (mobility). Damage taken and field time scale with it; aggregate() checks it against the bot."""
    return 1 / (1 + .05 * dmg) * (1 - .03 * mob)

def aggregate():
    rows = []
    # .log.raw: a run still going (or stopped) — its finished fields count too.
    for path in glob.glob(os.path.join(ROOT, "tmp", "pacing", "*.log")) + glob.glob(os.path.join(ROOT, "tmp", "pacing", "*.log.raw")):
        label = os.path.basename(path).split("_")[0]
        for line in open(path, encoding="utf-8"):
            if line.startswith("PACE "):
                row = json.loads(line[5:]); row["state"] = label; rows.append(row)
    pooled = {}
    for row in rows:
        if row["path"] != "mid": continue
        hp, dmg, mob, press, cls = STATES[row["state"]]
        e = exposure(dmg, mob)
        cell = pooled.setdefault(str(row["challenge"]), {}).setdefault(str(row["field"]), {"soldier": [], "base": [], "time": [], "earned": []})
        cell["soldier"].append(row["soldier_dmg"] / e); cell["base"].append(row["base_dmg"] / e)
        cell["time"].append(max(60.0, row["time"] - ASSIST_SECONDS * row["assists"]) / e)
        cell["earned"].append(row["earned"])
    out = {"rows": rows, "pooled": {}}
    for ch, fields in sorted(pooled.items()):
        out["pooled"][ch] = {}
        for f, c in sorted(fields.items(), key=lambda x: int(x[0])):
            out["pooled"][ch][f] = {k: round(statistics.mean(c[k]), 2) for k in ("soldier", "base", "time", "earned")}
            out["pooled"][ch][f]["n"] = len(c["soldier"])
            out["pooled"][ch][f]["soldier_sd"] = round(statistics.pstdev(c["soldier"]), 2)
    json.dump(out, open(DATA, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"{len(rows)} полей → {DATA}")
    for ch, fields in out["pooled"].items():
        print(f"испытание {ch}: " + " | ".join(f'{f}: {v["time"]:.0f}с {v["earned"]:.0f}◈ боец {v["soldier"]:.0f}±{v["soldier_sd"]:.0f} штаб {v["base"]:.0f} (n{v["n"]})' for f, v in fields.items()))
    print("\nПроверка закона «нажим ∝ время под огнём» (испытание 0, весь маршрут, среднее по сидам):")
    for label, (hp, dmg, mob, press, cls) in STATES.items():
        for ch in (0, 1, 2):
            runs = {}
            for r in rows:
                if r["state"] == label and r["challenge"] == ch and r["path"] == "mid": runs.setdefault(r["seed"], []).append(r)
            if not runs: continue
            total = statistics.mean(sum(x["soldier_dmg"] for x in v) for v in runs.values())
            base = statistics.mean(sum(x["base_dmg"] for x in v) for v in runs.values())
            times = statistics.mean(sum(x["time"] for x in v) for v in runs.values())
            earned = statistics.mean(sum(x["earned"] for x in v) for v in runs.values())
            print(f"  {label} испытание {ch}: боец {total:.0f}, штаб {base:.0f}, время {times/60:.0f} мин, сплав {earned:.0f}, прогноз доли от S0 {exposure(dmg, mob):.2f} (сидов {len(runs)})")
    print("\nБиомы (испытание 0, урон по бойцу относительно среднего этого поля):")
    fam = {}
    for r in rows:
        if r["challenge"] != 0 or r["field"] == 6 or r["path"] != "mid": continue
        hp, dmg, mob, press, cls = STATES[r["state"]]
        mean = out["pooled"]["0"][str(r["field"])]["soldier"]
        fam.setdefault(r["biome"], []).append((r["soldier_dmg"] / exposure(dmg, mob) / mean, r["base_dmg"] / exposure(dmg, mob) / max(1, out["pooled"]["0"][str(r["field"])]["base"])))
    for k, v in sorted(fam.items(), key=lambda x: -statistics.mean(a for a, b in x[1])):
        print(f"  {k:8s} боец ×{statistics.mean(a for a, b in v):.2f}, штаб ×{statistics.mean(b for a, b in v):.2f} (полей {len(v)})")

def load():
    return json.load(open(DATA, encoding="utf-8"))

# The bot reached only the first fields on challenge I–II (too few rows, and it ignores enemy aim anyway), so the
# ladder is modelled from the rules: +0.2 professionalism per step (faster aim, more storming) is taken as +25% /
# +50% damage taken; II also removes the breather heal and cuts the HQ by a quarter (Player.base_max / heal).
# Kill and clear alloy are multiplied by Campaign.CHALLENGE_REWARD; chests are not.
CHALLENGE_PRESSURE = [1.0, 1.25, 1.5]
CHALLENGE_REWARD = [1.0, 1.25, 1.5]

def field_stats(data, dmg, mob, challenge, field):
    """Pooled bot numbers for a field (normal difficulty), scaled to the player's kill speed and the ladder step."""
    row = data["pooled"]["0"][str(field)]
    e = exposure(dmg, mob) * (ECON["boss"] if field == FIELDS - 1 else 1.0)
    p = CHALLENGE_PRESSURE[challenge]
    return {"time": row["time"] * e, "earned": row["earned"] * CHALLENGE_REWARD[challenge], "soldier_dmg": row["soldier"] * e * p, "base_dmg": row["base"] * e * p}

# ---------------------------------------------------------------- costs (copy of the game)
def shell_cost(branch, level, costs):
    base = costs["shell_base"]["health" if branch == "health" else "other"]
    return math.ceil(round(base * (1 + level) ** costs["shell_power"]) * 1.2)

def class_cost(level):
    return math.ceil((1 + level // 3) * 1.2) * 40

COSTS = {
    "shell_base": {"health": 24, "other": 16}, "shell_power": 1.8,
    "yard": 150, "weapons": 120, "headquarters": 240, "garage": 120, "range": 72,
    "buggy": 450, "apc": 1800, "tank": 5200,
    "insurance": [180, 270, 405, 608],
    "backpack": [72, 144, 288, 576],
    "supplies_unlock": 120, "supplies": [72, 144, 288],
    "hq_tech": [60, 90, 90],             # medbay, plating, patch (no blueprint needed)
    "hq_level": [180, 333, 616],         # rarity-0 tech levels 1–3
    "weapon_level": [350, 578, 953, 1572, 2594],
    "buggy_equipment": [240, 432, 778],
    "gadget_mine": 100,
    "bonus": [96, 168, 240],
    "rescue": [144, 264, 384, 504],
    "apc_equipment": [650, 1170, 2106],
}
PRICES = {"current": COSTS}

# ---------------------------------------------------------------- player
class Player:
    def __init__(self, rng, costs):
        self.rng = rng; self.costs = costs
        self.alloy = 0; self.minutes = 0.0
        self.hp = self.dmg = self.mob = self.press = 0; self.cls = 0
        self.insurance = 0; self.backpack = 1; self.supplies = -1; self.rescue = 0
        self.built = set(); self.blueprints = set(); self.owned = set(); self.hq_tech = 0; self.hq_level = 0
        self.weapon_level = 0; self.equipment = 0; self.bonus = 0; self.mine = False; self.apc_equipment = 0
        self.best_depth = 0; self.boss = False; self.ladder = 0; self.runs = 0; self.deaths = 0
        self.log = []; self.quests_done = set(); self.briefings = 0; self.spent = 0
        # ★ commander chests hand out research first (EncounterRules.recipe), then tier-0/1 gear; ★★ from field 2 on
        # gives tier 2–3 gear (vehicle_apc, sniper, freeze...).
        self.research_queue = ["weapons", "headquarters", "garage", "vehicle_buggy", "smg", "rifle", "rescue", "reroll", "shotgun", "mine", "hq_regen", "bonus_repair", "buggy_armor"]
        self.rare_queue = ["vehicle_apc", "sniper", "hq_interceptor", "bonus_freeze", "grenade_launcher", "vehicle_tank", "laser"]

    def mitigation(self):
        """Things the bot did not have, as a multiplier on damage taken (documented guesses)."""
        m = 1.0
        if self.cls >= 3: m *= .93   # second ability
        if self.cls >= 5: m *= .97   # perk
        if self.cls >= 7: m *= .96   # stronger Q
        if "smg" in self.blueprints or "rifle" in self.blueprints: m *= .9  # better gun than the pistol
        if "buggy" in self.owned: m *= .92  # vehicle soaks hits
        if "apc" in self.owned: m *= .92
        if self.mine: m *= .97
        m *= 1 - .012 * self.weapon_level
        m *= 1 - .02 * self.press
        m *= 1 - .015 * (self.equipment + self.apc_equipment)
        m *= 1 - .03 * self.bonus
        return max(.4, m)

    def base_max(self, challenge):
        base = 5 + self.hp // 5
        if challenge >= 2: base = max(1, round(base * .75))
        return base + (3 if self.hq_tech >= 2 else 0) + 2 * min(self.hq_level, 3)

    def heal_per_field(self, challenge):
        heal = 0 if challenge >= 2 else 1.0
        heal += .5  # hearts a person picks up
        if self.hq_tech >= 1: heal += .3
        return heal

    def buy(self, item, price):
        self.alloy -= price; self.spent += price; self.minutes += OVERHEAD["buy"] / 60
        self.log.append((self.minutes, item, price))

    # Wish list. Each entry: (name, price or None if not available now, apply).
    def wishes(self):
        c = self.costs; w = []
        add = lambda name, price, fn: w.append((name, price, fn))
        def inc(attr, n=1):
            def f(): setattr(self, attr, getattr(self, attr) + n)
            return f
        add("Площадка", c["yard"] if "yard" not in self.built and ("garage" in self.blueprints or self.runs >= 3) else None, lambda: self.built.add("yard"))
        for b in ("weapons", "headquarters", "garage", "range"):
            ok = b in self.blueprints or b == "range" and "garage" in self.built
            if b in ("garage", "range") and "yard" not in self.built: ok = False
            add({"weapons": "Арсенал", "headquarters": "Штаб", "garage": "Стоянка", "range": "Полигон"}[b], c[b] if ok and b not in self.built else None, lambda b=b: self.built.add(b))
        add("Багги", c["buggy"] if "garage" in self.built and "vehicle_buggy" in self.blueprints and "buggy" not in self.owned else None, lambda: self.owned.add("buggy"))
        add("БТР", c["apc"] if "buggy" in self.owned and "vehicle_apc" in self.blueprints and "apc" not in self.owned else None, lambda: self.owned.add("apc"))
        # Health and damage stay within one level of each other.
        if self.hp <= self.dmg: add(f"Здоровье {self.hp+1}", shell_cost("health", self.hp, c), inc("hp"))
        else: add(f"Урон {self.dmg+1}", shell_cost("damage", self.dmg, c), inc("dmg"))
        if self.cls < 10: add(f"Класс {self.cls+1}", class_cost(self.cls), inc("cls"))
        if self.insurance < 4: add(f"Страховка {self.insurance+1}", c["insurance"][self.insurance], inc("insurance"))
        if self.backpack < 4: add(f"Рюкзак {self.backpack+1}", c["backpack"][self.backpack-1], inc("backpack"))
        if "headquarters" in self.built and self.hq_tech < 3: add(f"Технология штаба {self.hq_tech+1}", c["hq_tech"][self.hq_tech], inc("hq_tech"))
        if self.mob < 4: add(f"Скорость {self.mob+1}", shell_cost("mobility", self.mob, c), inc("mob"))
        if self.press < 3: add(f"Напор {self.press+1}", shell_cost("pressure", self.press, c), inc("press"))
        if self.supplies < 3:
            add("Снабжение" if self.supplies < 0 else f"Аптечки передышки {self.supplies+1}", c["supplies_unlock"] if self.supplies < 0 else c["supplies"][self.supplies], inc("supplies"))
        if "mine" in self.blueprints and "weapons" in self.built and not self.mine: add("Мина", c["gadget_mine"], lambda: setattr(self, "mine", True))
        if "weapons" in self.built and self.bonus < 3: add(f"Бонус боя {self.bonus+1}", c["bonus"][self.bonus], inc("bonus"))
        if self.hq_tech >= 3 and self.hq_level < 3: add(f"Уровень технологии штаба {self.hq_level+1}", c["hq_level"][self.hq_level], inc("hq_level"))
        if "buggy" in self.owned and self.equipment < 3: add(f"Оборудование багги {self.equipment+1}", c["buggy_equipment"][self.equipment], inc("equipment"))
        if "apc" in self.owned and self.apc_equipment < 3: add(f"Оборудование БТР {self.apc_equipment+1}", c["apc_equipment"][self.apc_equipment], inc("apc_equipment"))
        if "weapons" in self.built and self.weapon_level < 5: add(f"Уровень оружия {self.weapon_level+1}", c["weapon_level"][self.weapon_level], inc("weapon_level"))
        if "rescue" in self.blueprints and self.rescue < 4: add(f"Страховка чертежей {self.rescue+1}", c["rescue"][self.rescue], inc("rescue"))
        return [x for x in w if x[1] is not None]

    def shop(self):
        """Cheapest wish first while affordable: a person spends what they have on the next visible step."""
        for _ in range(40):
            options = [x for x in self.wishes() if x[1] <= self.alloy]
            if not options: break
            name, price, fn = min(options, key=lambda x: x[1])
            fn(); self.buy(name, price)

    def quests(self):
        """Story, institute and briefing rewards (quest_catalog.gd), triggered by the matching state."""
        q = []
        def once(id, cond, alloy):
            if id not in self.quests_done and cond: self.quests_done.add(id); q.append(alloy)
        once("first_alloy", self.runs >= 1, 30); once("bench", self.best_depth >= 1, 40)
        once("health", self.hp >= 1, 45); once("rooms3", self.best_depth >= 3, 70)
        once("first_challenge", self.runs >= 3, 100); once("first_trade", self.best_depth >= 2, 50)
        once("rooms5", self.best_depth >= 5, 100); once("general1", self.boss, 240)
        once("arsenal", "weapons" in self.built, 50); once("shield", self.runs >= 2, 80)
        once("supply", self.supplies >= 1, 65); once("hq_bench", "headquarters" in self.built, 100)
        once("hq_equip", self.hq_tech >= 1, 80); once("hq_support", self.hq_tech >= 1 and self.runs >= 3, 110)
        once("weapon_tune", self.weapon_level >= 1, 100)
        once("garage_build", "garage" in self.built, 70); once("garage_buggy", "buggy" in self.owned, 100)
        once("hq_upgrade", self.hq_level >= 1, 120); once("garage_equipment", self.equipment >= 1, 100)
        once("garage_apc", "apc" in self.owned, 240)
        # Briefings (≈2460 ◈ over 18) and adaptive orders (37–90 ◈): about one of each per hub visit.
        if self.best_depth >= 1 and self.briefings < 18: self.briefings += 1; q.append(85)
        q.append(55)
        return sum(q)

    def run(self, data, challenge):
        rng = self.rng; self.runs += 1
        earned = 0; carried = []; mercy = True; t = 0.0; won = False; depth = 0; dead = False
        stars = [1, 1, 1, 1, 1, 2, 2] if challenge == 0 else [1, 1, 1, 2, 2, 2, 2]
        cap = self.backpack + 3
        max_hp = 3 + 2 * self.hp + .5 * self.cls; hp = max_hp
        m = self.mitigation()
        for f in range(FIELDS):
            s = field_stats(data, self.dmg, self.mob, challenge, f)
            if f in (2, 4, 6): t += OVERHEAD["service"]
            t += s["time"] + OVERHEAD["field"]
            hit = K_SOLDIER * s["soldier_dmg"] * m * math.exp(rng.gauss(0, NOISE) - NOISE ** 2 / 2)
            base_hit = K_BASE * s["base_dmg"] * m * math.exp(rng.gauss(0, NOISE) - NOISE ** 2 / 2)
            if hp - hit <= 0:
                if mercy and hp > 1: mercy = False; hp = 1
                else: dead = True
            else: hp -= hit
            if base_hit >= self.base_max(challenge): dead = True
            if dead:
                part = rng.random(); t -= (1 - part) * s["time"]; earned += part * s["earned"] * ECON["income"]
                break
            earned += s["earned"] * ECON["income"]; depth = f + 1
            if stars[f] >= 1 and len(carried) < cap:
                queue = self.rare_queue if stars[f] == 2 and f >= 2 else self.research_queue
                if queue: carried.append(queue.pop(0))
            max_hp += .6  # run cards add health along the route (bot's soldier_max grows about this much)
            hp = min(max_hp, hp + self.heal_per_field(challenge) + (1 if self.supplies >= 1 and f in (1, 3, 5) else 0))
            if f == FIELDS - 1: won = True; break
            # Voluntary return («В хаб» on the route map): carrying blueprints and the next field looks deadly
            # (expected hit at least 70% of the health left). Once the general fell, a person plays for the ladder.
            nxt = field_stats(data, self.dmg, self.mob, challenge, f + 1)
            if carried and K_SOLDIER * nxt["soldier_dmg"] * m >= .7 * hp and challenge == self.ladder: break
        self.best_depth = max(self.best_depth, depth)
        t += OVERHEAD["result"]
        if dead:
            self.deaths += 1
            earned *= 1 - max(ECON["loss_floor"], ECON["loss"] - .05 * self.insurance)
            kept = [b for b in carried if rng.random() < min(.6, self.rescue * .06)]
            lost = [b for b in carried if b not in kept]
            for b in lost: (self.rare_queue if b in RARE else self.research_queue).insert(0, b)
            carried = kept
        elif won: earned += 20 + 40 + 100  # win bonus, general's alloy drop, general kill
        self.blueprints.update(carried)
        if won and not self.boss:
            self.boss = True; self.log.append((self.minutes + t / 60, "★ Генерал мира 1 побеждён", 0))
        if won and challenge > self.ladder:
            self.ladder = challenge; self.log.append((self.minutes + t / 60, f"★ Испытание {'I' * challenge} пройдено", 0))
        self.alloy += round(earned); self.minutes += t / 60
        return won

    def visit_hub(self):
        self.minutes += OVERHEAD["hub"] / 60
        self.alloy += self.quests()
        self.shop()

RARE = {"vehicle_apc", "sniper", "hq_interceptor", "bonus_freeze", "grenade_launcher", "vehicle_tank", "laser"}

def play(data, rng, costs, limit=420):
    p = Player(rng, costs); first = {}
    while p.minutes < limit:
        challenge = min(2, p.ladder + 1) if p.boss else 0
        p.run(data, challenge)
        for name, ok in (("boss", p.boss), ("c1", p.ladder >= 1), ("c2", p.ladder >= 2)):
            if ok and name not in first: first[name] = (p.minutes, p.spent, p.runs, p.deaths)
        if "c2" in first: break
        p.visit_hub()
    return p, first

def first_run_depth(data, ks, kb, rng, players=400):
    depths = []; base_deaths = deaths = 0
    for _ in range(players):
        hp = 3.0; max_hp = 3.0; d = 0; mercy = True
        for f in range(FIELDS):
            s = field_stats(data, 0, 0, 0, f)
            hit = ks * s["soldier_dmg"] * math.exp(rng.gauss(0, NOISE) - NOISE ** 2 / 2)
            bh = kb * s["base_dmg"] * math.exp(rng.gauss(0, NOISE) - NOISE ** 2 / 2)
            if bh >= 5: base_deaths += 1; deaths += 1; break
            if hp - hit <= 0:
                if mercy and hp > 1: mercy = False; hp = 1
                else: deaths += 1; break
            else: hp -= hit
            d = f + 1; max_hp += .6; hp = min(max_hp, hp + 1.5)
        depths.append(d)
    return statistics.mean(depths), base_deaths / max(1, deaths)

ANCHOR_DEPTH = 2.3   # a fresh player's first run ends on field 2–3
ANCHOR_BASE = 1 / 3  # the HQ falls in about a third of early deaths

def calibrate(data):
    global K_SOLDIER, K_BASE
    best = None
    for ks in [x / 1000 for x in range(10, 200, 5)]:
        for kb in [x / 10000 for x in range(20, 400, 10)]:
            depth, share = first_run_depth(data, ks, kb, random.Random(7), 200)
            score = abs(depth - ANCHOR_DEPTH) + abs(share - ANCHOR_BASE)
            if best is None or score < best[0]: best = (score, ks, kb, depth, share)
    _, K_SOLDIER, K_BASE, depth, share = best
    return depth, share

def timeline(args):
    data = load()
    costs = PRICES[args.get("--costs", "current")]
    ECON["income"] = float(args.get("--income", ECON["income"])); ECON["loss"] = float(args.get("--loss", ECON["loss"])); ECON["loss_floor"] = float(args.get("--floor", ECON["loss_floor"])); ECON["boss"] = float(args.get("--boss", ECON["boss"]))
    depth, share = calibrate(data)
    players = int(args.get("--players", 300)); rng = random.Random(int(args.get("--seed", 1)))
    results = [play(data, rng, costs) for _ in range(players)]
    q = lambda xs, p: sorted(xs)[min(len(xs) - 1, int(len(xs) * p))] if xs else float("nan")
    print(f"Калибровка: K_SOLDIER={K_SOLDIER} K_BASE={K_BASE}: первый забег новичка — в среднем {depth:.1f} поля, штаб — {share:.0%} гибелей")
    for name, title in (("boss", "Генерал мира 1"), ("c1", "Испытание I"), ("c2", "Испытание II")):
        xs = [r[1][name][0] for r in results if name in r[1]]
        spent = [r[1][name][1] for r in results if name in r[1]]
        runs = [r[1][name][2] for r in results if name in r[1]]
        print(f"{title}: медиана {q(xs,.5):.0f} мин (25–75%: {q(xs,.25):.0f}–{q(xs,.75):.0f}), потрачено к этому ≈{q(spent,.5):.0f} ◈, забегов {q(runs,.5)}, дошли {len(xs)}/{players}")
    boss = q([r[1]["boss"][0] for r in results if "boss" in r[1]], .5)
    c2 = q([r[1]["c2"][0] for r in results if "c2" in r[1]], .5)
    median = min(results, key=lambda r: abs(r[1].get("boss", (999,))[0] - boss) + .5 * abs(r[1].get("c2", (999,))[0] - c2))[0]
    print(f"\nХронология типичного игрока (забегов {median.runs}, гибелей {median.deaths}):")
    for minute, item, price in median.log:
        print(f"  {minute:6.1f} мин  {item}" + (f" — {price} ◈" if price else ""))
    gaps = []; last = 0.0
    for minute, item, price in median.log:
        if price: gaps.append((minute - last, last, minute)); last = minute
    if gaps:
        g = max(gaps); print(f"\nСамый долгий промежуток без покупки: {g[0]:.0f} мин ({g[1]:.0f}–{g[2]:.0f})")
    buckets = {}
    for minute, item, price in median.log:
        if price: buckets[int(minute // 30)] = buckets.get(int(minute // 30), 0) + 1
    print("Покупок по получасам: " + ", ".join(f"{b*30}–{b*30+30}: {buckets.get(b,0)}" for b in range(0, int(median.minutes // 30) + 1)))
    # Population view of dead stretches between 90 and 240 minutes.
    long_gaps = []
    for p, first in results:
        last = 0.0; worst = 0.0
        for minute, item, price in p.log:
            if price and 90 <= minute <= 240: worst = max(worst, minute - last)
            if price: last = minute
        long_gaps.append(worst)
    print(f"Самая долгая пауза без покупок в 1,5–4 ч по всем игрокам: медиана {q(long_gaps,.5):.0f} мин, 90-й процентиль {q(long_gaps,.9):.0f} мин")

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "timeline"
    args = {sys.argv[i]: sys.argv[i + 1] for i in range(2, len(sys.argv) - 1, 2)}
    if cmd == "aggregate": aggregate()
    else: timeline(args)
