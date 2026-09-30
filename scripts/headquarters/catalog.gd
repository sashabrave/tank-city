class_name HQCatalog
extends RefCounted
const DATA={
"hq_medbay":{"name":"Медблок","mode":"auto","rarity":0,"base":1,"score":100,"icon":"heart","description":"Аптечка рядом со штабом каждые 90 с боя. Улучшения сокращают интервал."},
"hq_plating":{"name":"Бронепанели","mode":"passive","rarity":0,"base":1,"score":95,"icon":"vehicle","description":"+3 прочности штаба. Улучшение: ещё +2."},
"hq_regen":{"name":"Ремонтный автомат","mode":"auto","rarity":1,"base":2,"score":65,"icon":"repair","description":"Ремонтирует штаб каждые 14 с. После попадания ждёт 6 с."},
"hq_supply":{"name":"Техснабжение","mode":"auto","rarity":1,"base":2,"score":55,"icon":"vehicle_repair","description":"Ремкомплект для транспорта через 70 с. Один за поле боя."},
"hq_interceptor":{"name":"Активная защита","mode":"auto","rarity":1,"base":3,"score":40,"icon":"pressure","description":"Раз в 14 с уничтожает вражеский снаряд в радиусе 2,5 клетки."},
"hq_tesla":{"name":"Катушка Теслы","mode":"auto","rarity":2,"base":4,"score":20,"icon":"laser","description":"Раз в 18 с бьёт током до трёх врагов в радиусе 2,8 клетки."},
"hq_patch":{"name":"Ремонтный импульс","mode":"active","rarity":0,"base":1,"score":85,"icon":"repair","description":"2: +3 прочности штабу, +1 HP герою рядом. Кулдаун 50 с."},
"hq_field":{"name":"Защитный купол","mode":"active","rarity":1,"base":3,"score":35,"icon":"shield","description":"2: 5 с защиты штаба и героя в радиусе 3 клеток. Кулдаун 55 с."},
"hq_emp":{"name":"Эми-разряд","mode":"active","rarity":2,"base":4,"score":15,"icon":"freeze","description":"2: 4 урона и 2 с оглушения врагам рядом. Кулдаун 45 с."}}
const DEFAULT_UNLOCKS=["hq_medbay","hq_plating","hq_patch"]
static func available(id:String)->bool:return id in Game.hq_unlocks and id in DATA
static func permanent_cost(id:String)->int:return roundi((180+DATA[id].rarity*180)*pow(1.85,int(Game.hq_levels.get(id,0))))
static func cap()->int:return Balance.CONFIG.economy.hq_level_cap
static func interval(id:String,level:float)->float:
	return maxf({"hq_medbay":45.0,"hq_supply":40.0,"hq_regen":8.0,"hq_interceptor":7.0,"hq_tesla":9.0,"hq_patch":25.0,"hq_field":30.0,"hq_emp":24.0}.get(id,1.0),{"hq_medbay":90.0,"hq_supply":70.0,"hq_regen":14.0,"hq_interceptor":14.0,"hq_tesla":18.0,"hq_patch":50.0,"hq_field":55.0,"hq_emp":45.0}.get(id,1.0)-level*{"hq_medbay":8.0,"hq_supply":7.0}.get(id,2.0))
static func stat(id:String,level:float)->String:
	match id:
		"hq_plating":return "Прочность: +"+UiKit.number(3+level*2)
		"hq_medbay":return "Аптечка каждые %s с" % UiKit.number(interval(id,level))
		"hq_supply":return "Доставка: %s с · лимит %d" % [UiKit.number(interval(id,level)),1+int(level/3)]
		"hq_regen":return "Ремонт: %s / %s с" % [UiKit.number(.5+level*.25),UiKit.number(interval(id,level))]
		"hq_interceptor":return "Перехват: %s с · радиус 2,5" % UiKit.number(interval(id,level))
		"hq_tesla":return "Урон: %s · %s с" % [UiKit.number(1.5+level*.35),UiKit.number(interval(id,level))]
		"hq_patch":return "Ремонт: %s · %s с" % [UiKit.number(3+level*.6),UiKit.number(interval(id,level))]
		"hq_field":return "Защита: %s с · откат %s с" % [UiKit.number(minf(8,5+level*.5)),UiKit.number(interval(id,level))]
	return "Урон: %s · %s с" % [UiKit.number(4+level*.6),UiKit.number(interval(id,level))]
