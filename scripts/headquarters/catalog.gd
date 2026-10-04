class_name HQCatalog
extends RefCounted
## HQ modules (author, 4 Oct 2026): the HQ acts on its own by the rule of each module — no key, no active
## support. «score» is the blueprint availability (scripts/progression/recipe_tiers.gd: 100…75 common … 24…0 exceptional).
## «auto» modules fire by their rule (scripts/headquarters/run_support.gd), «passive» ones just add numbers.
const DATA={
"hq_medbay":{"name":"Аптечка","mode":"auto","rarity":0,"score":100,"icon":"heart","description":"Аптечка рядом со штабом каждые 90 с боя. Лежит одна; следующая — как только её подберут."},
"hq_plating":{"name":"Броня","mode":"passive","rarity":0,"score":95,"icon":"vehicle","description":"+3 прочности штаба. Улучшение: ещё +2."},
"hq_regen":{"name":"Ремонт","mode":"auto","rarity":1,"score":65,"icon":"repair","description":"Штаб без попаданий 5 с — чинится по шагам. Чинит и твою машину в 2 клетках от штаба."},
"hq_medpost":{"name":"Медпункт","mode":"auto","rarity":1,"score":55,"icon":"heart","description":"Лечит героя в 3 клетках от штаба по 1 здоровью из запаса. Запас кончился — перезарядка."},
"hq_tesla":{"name":"Оборона","mode":"auto","rarity":2,"score":20,"icon":"laser","description":"Враг в 3 клетках от штаба — разряд: урон и оглушение всем рядом, сбивает снаряды. Затем перезарядка."},
"hq_field":{"name":"Купол","mode":"auto","rarity":1,"score":35,"icon":"shield","description":"После попадания в штаб купол на 5 с: штаб не получает урона. Затем перезарядка."}}
const DEFAULT_UNLOCKS=["hq_medbay","hq_plating","hq_regen"]
## Retired ids (before 4 Oct 2026) → the module that absorbed them. Profiles, run snapshots and blueprints go through it.
const MERGED={"hq_patch":"hq_regen","hq_supply":"hq_regen","hq_emp":"hq_tesla","hq_interceptor":"hq_tesla"}
## Rule constants: radii in cells, seconds.
const QUIET:=5.0            # Ремонт: seconds without hits before the HQ repairs
const VEHICLE_REACH:=2.0    # Ремонт: the player's vehicle within this many cells is repaired too
const MEDPOST_REACH:=3.0
const MEDPOST_PORTION:=1.0
const MEDPOST_STEP:=.6
const DEFENCE_REACH:=3.0
static func current(id:String)->String:return MERGED.get(id,id)
## Old and new ids → current ids, known ones only, without repeats, order kept.
static func migrate_ids(ids:Array)->Array:
	var result=[]
	for id in ids:
		var next=current(str(id))
		if next in DATA and next not in result:result.append(next)
	return result
## Levels of merged modules: the new module keeps the highest of them.
static func migrate_levels(levels:Dictionary)->Dictionary:
	var result={}
	for id in levels:
		var next=current(str(id))
		if next in DATA:result[next]=maxf(float(result.get(next,0.0)),float(levels[id]))
	return result
static func available(id:String)->bool:return id in Game.hq_unlocks and id in DATA
static func permanent_cost(id:String)->int:return Game.nice_price(roundi((180+DATA[id].rarity*180)*pow(1.85,int(Game.hq_levels.get(id,0)))))
static func cap()->int:return Balance.CONFIG.economy.hq_level_cap
## Seconds of the module's timer: delivery interval, repair step, or the recharge after it fired.
static func interval(id:String,level:float)->float:
	match id:
		"hq_medbay":return maxf(45.0,90.0-level*8.0)
		"hq_regen":return maxf(3.0,6.0-level*.5)
		"hq_medpost":return maxf(20.0,45.0-level*4.0)
		"hq_tesla":return maxf(10.0,20.0-level*2.0)
		"hq_field":return maxf(15.0,35.0-level*2.5)
	return 1.0
static func repair_amount(level:float)->float:return 1.0+level*.25
static func medpost_stock(level:float)->float:return 6.0+floorf(level)
static func defence_damage(level:float)->float:return 3.0+level*.5
static func defence_stun(level:float)->float:return 1.5+level*.1
static func dome_time(level:float)->float:return minf(8.0,5.0+level*.5)
static func stat(id:String,level:float)->String:
	match id:
		"hq_plating":return "Прочность: +"+UiKit.number(3+level*2)
		"hq_medbay":return "Аптечка каждые %s с" % UiKit.number(interval(id,level))
		"hq_regen":return "Ремонт: +%s каждые %s с" % [UiKit.number(repair_amount(level)),UiKit.number(interval(id,level))]
		"hq_medpost":return "Запас: %s · перезарядка %s с" % [UiKit.number(medpost_stock(level)),UiKit.number(interval(id,level))]
		"hq_tesla":return "Урон: %s · оглушение %s с · %s с" % [UiKit.number(defence_damage(level)),UiKit.number(defence_stun(level)),UiKit.number(interval(id,level))]
		"hq_field":return "Купол: %s с · перезарядка %s с" % [UiKit.number(dome_time(level)),UiKit.number(interval(id,level))]
	return ""
## Station card rows (T-254): the parameters a level improves, [name, at level a, at level b].
static func rows(id:String,a:float,b:float)->Array:
	var sec=func(v):return UiKit.number(v)+" с"
	var cooldown=["Перезарядка",sec.call(interval(id,a)),sec.call(interval(id,b))]
	match id:
		"hq_plating":return [["Прочность штаба","+"+UiKit.number(3+a*2),"+"+UiKit.number(3+b*2)]]
		"hq_medbay":return [["Интервал",sec.call(interval(id,a)),sec.call(interval(id,b))]]
		"hq_regen":return [["Ремонт за шаг","+"+UiKit.number(repair_amount(a)),"+"+UiKit.number(repair_amount(b))],["Шаг",sec.call(interval(id,a)),sec.call(interval(id,b))]]
		"hq_medpost":return [["Запас здоровья",UiKit.number(medpost_stock(a)),UiKit.number(medpost_stock(b))],cooldown]
		"hq_tesla":return [["Урон",UiKit.number(defence_damage(a)),UiKit.number(defence_damage(b))],["Оглушение",sec.call(defence_stun(a)),sec.call(defence_stun(b))],cooldown]
		"hq_field":return [["Купол",sec.call(dome_time(a)),sec.call(dome_time(b))],cooldown]
	return []
