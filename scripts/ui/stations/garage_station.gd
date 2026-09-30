extends RefCounted
## «Стоянка» (garage blueprint): buy and choose vehicles, buy their equipment.
func title()->String:return "Стоянка"
func subtitle()->String:return "Техника к старту вылазки: багги → БТР → танк."
func tabs()->Array:return [["vehicles","Техника","vehicle"],["equipment","Оборудование","settings"]]
func items(tab:String)->Array:
	var result=[];var g=Game.garage
	if tab=="vehicles":
		for kind in GarageCatalog.VEHICLES:
			var v=GarageCatalog.VEHICLES[kind];var owned=kind in g.owned;var known="vehicle_"+kind in g.unlocks
			result.append({"id":kind,"title":v.name,"icon":kind,"caption":"Выбрана" if g.selected==kind else "В гараже" if owned else "%d ◈" % v.price if known else "Нужен чертёж","state":"active" if g.selected==kind else "owned" if owned else "ready" if g.can_buy(kind) else "locked"})
	else:
		for kind in GarageCatalog.VEHICLES:
			for branch in GarageCatalog.BRANCHES:
				var id=kind+"_"+branch;var unlocked=id in g.unlocks
				result.append({"id":id,"title":GarageCatalog.BRANCHES[branch].name,"group":GarageCatalog.VEHICLES[kind].name,"icon":"garage/"+id,"caption":"ур. %d / %d" % [g.level(kind,branch),g.cap(kind)] if unlocked else "Нужен чертёж","state":"owned" if unlocked and kind in g.owned else "locked"})
	return result
func detail(tab:String,id:String)->Dictionary:
	var g=Game.garage
	if tab=="vehicles":
		var v=GarageCatalog.VEHICLES[id];var owned=id in g.owned;var stats=GarageCatalog.stats(id)
		var actions=[]
		if owned and g.selected!=id:actions.append({"id":"choose","text":"Взять на вылазку","primary":true})
		if owned and g.selected==id:actions.append({"id":"clear","text":"Идти пешком"})
		if not owned:actions.append({"id":"buy","text":"Купить · %d ◈" % v.price,"enabled":g.can_buy(id),"primary":true})
		var need=[] if owned or v.previous=="" or v.previous in g.owned else ["Сначала купи: "+GarageCatalog.VEHICLES[v.previous].name]
		return {"title":v.name,"icon":id,"text":"Машина ждёт у старта каждой вылазки." if owned else "Чертёж машины выпадает в вылазках мира 1.","rows":[["Броня",UiKit.number(stats.hp),UiKit.number(stats.hp)],["Урон",UiKit.number(stats.damage),UiKit.number(stats.damage)],["Скорость",UiKit.number(stats.speed),UiKit.number(stats.speed)]],"lines":need,"actions":actions}
	var parts=id.split("_");var kind=parts[0];var branch=parts[1];var info=GarageCatalog.BRANCHES[branch];var level=g.level(kind,branch);var unlocked=id in g.unlocks
	return {"title":GarageCatalog.VEHICLES[kind].name+" · "+info.name,"icon":"garage/"+kind+"_"+branch,"text":("%s: +%d%% за уровень." % [info.stat,roundi(info.step*100)]) if unlocked else "Чертёж оборудования выпадает в сундуках.","rows":[["Уровень",level,mini(level+1,g.cap(kind))],[info.stat,"+%d%%" % roundi(level*info.step*100),"+%d%%" % roundi(mini(level+1,g.cap(kind))*info.step*100)]],"lines":[] if kind in g.owned else ["Сначала купи машину"],"actions":[{"id":"level","text":"Максимум" if level>=g.cap(kind) else "Улучшить · %d ◈" % g.cost(kind,branch),"enabled":unlocked and kind in g.owned and level<g.cap(kind) and Game.credits>=g.cost(kind,branch),"primary":true}]}
func act(tab:String,id:String,action:String)->String:
	var g=Game.garage
	match [tab,action]:
		["vehicles","buy"]:return "Машина куплена" if g.buy(id) else ""
		["vehicles","choose"]:return "Машина ждёт у старта" if g.choose(id) else ""
		["vehicles","clear"]:return "Вылазка пешком" if g.choose("") else ""
		["equipment","level"]:
			var parts=id.split("_");return "Оборудование улучшено" if g.upgrade(parts[0],parts[1]) else ""
	return ""
