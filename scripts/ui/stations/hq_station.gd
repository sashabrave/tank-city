extends RefCounted
## «Штаб» (HQ blueprint): support technologies, base defence, insurance and the other buildings.
const DEFENCE=[["base","Прочность базы","upgrade/base"],["turret","Союзные турели","upgrade/turret"]]
const BUILDINGS=["weapons","yard","garage","range"]
## Short card texts (T-254): what the technology does; its numbers are the card rows, not repeated here.
const GIST={"hq_medbay":"Кладёт аптечку у штаба во время боя","hq_plating":"Дополнительная прочность штаба","hq_regen":"Сам чинит штаб. После попадания ждёт 6 с",
	"hq_supply":"Привозит ремкомплект для транспорта","hq_interceptor":"Сбивает вражеский снаряд рядом со штабом","hq_tesla":"Бьёт током до трёх врагов рядом со штабом",
	"hq_patch":"Клавиша 2: чинит штаб и лечит героя рядом","hq_field":"Клавиша 2: защищает штаб и героя рядом","hq_emp":"Клавиша 2: бьёт током и оглушает врагов рядом"}
func title()->String:return "Штаб"
func subtitle()->String:return "Поддержка, оборона, страховка, постройки."
func tabs()->Array:return [["tech","Технологии","base"],["defence","Оборона","repair"],["insurance","Страховка","alloy"],["build","Постройки","settings"]]
func items(tab:String)->Array:
	var result=[]
	match tab:
		"tech":
			for id in HQCatalog.DATA:
				var info=HQCatalog.DATA[id];var known=HQCatalog.available(id);var level=int(Game.hq_levels.get(id,0))
				result.append({"id":id,"title":info.name,"icon":"headquarters/"+id,"caption":"Нужен чертёж" if not known else ("Выбрана · " if id in Game.hq_loadout() else "")+"ур. %d / %d" % [level,HQCatalog.cap()],"state":"locked" if not known else "active" if id in Game.hq_loadout() else "owned" if id in Game.purchased_hq else "ready","level":level,"cap":HQCatalog.cap()})
		"defence":
			for row in DEFENCE:
				var unlocked=Game.branch_unlocked(row[0])
				result.append({"id":row[0],"title":row[1],"icon":row[2],"caption":"ур. %d / %d" % [Game.level(row[0]),Game.upgrade_cap(row[0])] if unlocked else "Открыть · %d ◈" % Game.UNLOCK_COSTS[row[0]],"state":"owned" if unlocked else "ready","level":Game.level(row[0]) if unlocked else 0,"cap":Game.upgrade_cap(row[0])})
		"insurance":
			result.append({"id":"alloy","title":"Страховка сплава","icon":"upgrade/insurance_alloy","caption":"%d / %d" % [Game.progression.insurance,Balance.CONFIG.economy.insurance_cap],"state":"owned","level":Game.progression.insurance,"cap":Balance.CONFIG.economy.insurance_cap})
			result.append({"id":"rescue","title":"Страховка чертежей","icon":"upgrade/insurance_blueprint","caption":"%d / 10" % Game.rescue_level if "rescue" in Game.research_unlocks else "Нужен чертёж","state":"owned" if "rescue" in Game.research_unlocks else "locked","level":Game.rescue_level,"cap":10})
		"build":
			for id in BUILDINGS:
				var built=id in Game.built_workshops;var known=Game.building_known(id);var blocker=Game.building_blocker(id)
				result.append({"id":id,"group":"Площадка снаружи" if id in ["yard","garage","range"] else "Ангар","title":building_name(id),"icon":"building/"+id,"caption":"Построено" if built else ("Нужна площадка" if blocker!="" else "%d ◈" % Game.building_cost(id)) if known else "Нужен чертёж","state":"active" if built else "ready" if known and blocker=="" else "locked"})
	return result
static func building_name(id:String)->String:return {"weapons":"Арсенал","yard":"Площадка","garage":"Стоянка","range":"Полигон","headquarters":"Штаб"}.get(id,id)
func detail(tab:String,id:String)->Dictionary:
	match tab:
		"tech":
			var info=HQCatalog.DATA[id];var known=HQCatalog.available(id);var level=int(Game.hq_levels.get(id,0));var bought=id in Game.purchased_hq
			var actions=[]
			if known and id not in Game.hq_loadout():actions.append({"id":"equip","text":"Выбрать" if bought else "Купить и выбрать · %d ◈" % Game.hq_purchase_cost(id),"enabled":bought or Game.credits>=Game.hq_purchase_cost(id),"primary":true})
			if known:actions.append({"id":"level","text":"Максимум" if level>=HQCatalog.cap() else "Уровень %d · %d ◈" % [level+1,HQCatalog.permanent_cost(id)],"enabled":level<HQCatalog.cap() and Game.credits>=HQCatalog.permanent_cost(id)})
			var mode={"active":"Активная · клавиша 2","auto":"Автоматическая","passive":"Пассивная"}.get(info.mode,"")
			var next=mini(level+1,HQCatalog.cap())
			return {"title":info.name,"icon":"headquarters/"+id,"text":GIST.get(id,info.description) if known else "Чертёж технологии выпадает в сундуках.","rows":[["Уровень",level,next]]+HQCatalog.rows(id,level,next),"lines":[mode],"actions":actions}
		"defence":
			var row=DEFENCE.filter(func(r):return r[0]==id)[0];var unlocked=Game.branch_unlocked(id);var level=Game.level(id);var cap=Game.upgrade_cap(id)
			var next=mini(level+1,cap);var economy=Balance.CONFIG.economy
			var text="Прочность базы во всех вылазках" if id=="base" else "Урон союзных турелей"
			var param=["Прочность",str(Balance.CONFIG.combat.base_health+level),str(Balance.CONFIG.combat.base_health+next)] if id=="base" else ["Урон",UiKit.number(snappedf(economy.turret_damage+level*economy.turret_damage_per_level,.01)),UiKit.number(snappedf(economy.turret_damage+next*economy.turret_damage_per_level,.01))]
			return {"title":row[1],"icon":row[2],"text":text,"rows":[["Уровень",level,next],param],"actions":[{"id":"buy","text":("Максимум" if level>=cap else "Улучшить · %d ◈" % Game.cost(id)) if unlocked else "Открыть · %d ◈" % Game.UNLOCK_COSTS[id],"enabled":(level<cap and Game.credits>=Game.cost(id)) if unlocked else Game.credits>=Game.UNLOCK_COSTS[id],"primary":true}]}
		"insurance":
			if id=="alloy":
				var cap=Balance.CONFIG.economy.insurance_cap;var n=Game.progression.insurance
				return {"title":"Страховка сплава","icon":"upgrade/insurance_alloy","text":"Меньше потерь добытого сплава при выбывании.","rows":[["Уровень",n,mini(n+1,cap)],["Потеря при выбывании","≈%d%%" % roundi(Game.death_loss_fraction()*100),"≈%d%%" % roundi(Game.death_loss_fraction(mini(n+1,cap))*100)]],"lines":["Каждый раз разброс ±10% от этого значения."],"actions":[{"id":"buy","text":"Максимум" if n>=cap else "Улучшить · %d ◈" % Game.insurance_cost(),"enabled":n<cap and Game.credits>=Game.insurance_cost(),"primary":true}]}
			var known="rescue" in Game.research_unlocks;var price=Game.special_cost("rescue")
			return {"title":"Страховка чертежей","icon":"upgrade/insurance_blueprint","text":"Шанс сохранить чертежи из рюкзака при выбывании." if known else "Нужен чертёж страховки.","rows":[["Уровень",Game.rescue_level,mini(Game.rescue_level+1,10)],["Шанс","%d%%" % (Game.rescue_level*6),"%d%%" % (mini(Game.rescue_level+1,10)*6)]],"actions":[{"id":"buy","text":("Нужен чертёж" if not known else "Максимум" if price<0 else "Улучшить · %d ◈" % price),"enabled":known and price>=0 and Game.credits>=price,"primary":true}]}
		"build":
			var built=id in Game.built_workshops;var known=Game.building_known(id);var blocker=Game.building_blocker(id)
			var text=preload("res://scripts/ui/build_catalog.gd").INFO.get(id,["",""])[1]
			if blocker!="":text+=" Сначала купи площадку."
			return {"title":building_name(id),"icon":"building/"+id,"text":text if known else "Чертёж постройки выпадает в вылазках.","actions":[] if built else [{"id":"build","text":("Купить · %d ◈" if id=="yard" else "Построить · %d ◈") % Game.building_cost(id),"enabled":known and blocker=="" and Game.credits>=Game.building_cost(id),"primary":true}]}
	return {}
func act(tab:String,id:String,action:String)->String:
	match [tab,action]:
		["tech","equip"]:return "Технология выбрана" if Game.equip_hq(id,0) else ""
		["tech","level"]:return "Технология улучшена" if Game.upgrade_hq(id) else ""
		["defence","buy"]:return "Улучшено" if (Game.purchase(id) if Game.branch_unlocked(id) else Game.unlock_branch(id)) else ""
		["insurance","buy"]:return "Страховка улучшена" if (Game.buy_insurance() if id=="alloy" else Game.buy_special("rescue")) else ""
		["build","build"]:return "Построено: "+building_name(id) if Game.build_workshop(id) else ""
	return ""
