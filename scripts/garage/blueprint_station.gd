extends RefCounted
## Test blueprint shop on the station template: every group of DevUnlocks as a tab, blueprints as cards,
## grant/revoke on the right. The «Профиль» tab holds the global switches.
var screen
const BASE={"hq":"@hq","weapon":"pistol","bonus":"heart","research":"character","ability":"barrier","classes":"recruit"}
func title()->String:return "Чертежи · тест"
func subtitle()->String:return "Открывай и закрывай чертежи и покупки, чтобы проверить игру."
func tabs()->Array:
	var result=[]
	var icons={"research":"base","weapon":"damage","classes":"fighter","ability":"device_power","hq":"base","bonus":"heart","garage":"vehicle"}
	for group in DevUnlocks.GROUPS:
		var total=DevUnlocks.catalog(group).size();var count=DevUnlocks.catalog(group).keys().filter(func(id):return DevUnlocks.owned(group,id)).size()
		result.append([group,"%s · %d/%d" % [DevUnlocks.GROUPS[group],count,total],icons.get(group,"blueprint")])
	result.append(["profile","Профиль","settings"])
	return result
func base(group:String,id:String)->bool:
	return (group=="hq" and id in HQCatalog.DEFAULT_UNLOCKS) or BASE.get(group,"")==id
func ids(group:String)->Array:
	if group!="garage":return DevUnlocks.catalog(group).keys()
	var result=[]
	for kind in GarageCatalog.VEHICLES:result.append("vehicle_"+kind)
	for kind in GarageCatalog.VEHICLES:
		for branch in GarageCatalog.BRANCHES:result.append(kind+"_"+branch)
	return result
func group_of(id:String)->String:
	if not id.begins_with("vehicle_"):
		for kind in GarageCatalog.VEHICLES:
			if id.begins_with(kind+"_"):return "Оборудование · "+GarageCatalog.VEHICLES[kind].name
	return "Машины"
func items(tab:String)->Array:
	var result=[]
	if tab=="profile":
		for row in [["all_on","Все чертежи +","blueprint"],["all_off","Все чертежи −","lock"],["reset","Обнулить профиль","delete"]]:
			result.append({"id":row[0],"title":row[1],"icon":row[2],"caption":"","state":"owned"})
		return result
	for id in ids(tab):
		var owned=DevUnlocks.owned(tab,id);var name=DevUnlocks.catalog(tab).get(id,{}).get("name",id)
		var item={"id":id,"title":name,"icon":id,"caption":"Стартовый" if base(tab,id) else "Открыт" if owned else "Закрыт","state":"active" if owned else "locked"}
		if tab=="garage":item.group=group_of(id)
		result.append(item)
	return result
func purchasable(group:String,id:String)->bool:
	return group in ["ability","hq","classes"] or (group=="research" and id in Game.BUILD_COST) or (group=="garage" and id.begins_with("vehicle_"))
func detail(tab:String,id:String)->Dictionary:
	if tab=="profile":
		var texts={"all_on":"Открыть все чертежи во всех группах.","all_off":"Закрыть все чертежи, кроме стартовых.","reset":"Обнулить прогресс текущего мира: сплав, чертежи, станции и прокачку."}
		return {"title":{"all_on":"Все чертежи +","all_off":"Все чертежи −","reset":"Обнулить профиль"}[id],"icon":"settings","text":texts[id],"actions":[{"id":"run","text":"Выполнить","enabled":true,"primary":id!="reset"}]}
	var owned=DevUnlocks.owned(tab,id);var name=DevUnlocks.catalog(tab).get(id,{}).get("name",id)
	var actions=[{"id":"toggle","text":"Закрыть чертёж" if owned else "Открыть чертёж","enabled":not base(tab,id),"primary":not owned}]
	if purchasable(tab,id):
		var bought=DevUnlocks.purchased(tab,id)
		var label="Навык 1" if tab=="classes" else "Постройка" if tab=="research" else "Покупка"
		actions.append({"id":"purchase","text":label+(": отменить" if bought else ": выдать бесплатно"),"enabled":true})
	if tab=="classes":
		var second=ClassCatalog.level(id)>=8
		actions.append({"id":"second","text":"Навык 2: закрыть" if second else "Навык 2: выдать","enabled":true})
	actions.append({"id":"group_on","text":"Открыть всю группу","enabled":true});actions.append({"id":"group_off","text":"Закрыть всю группу","enabled":true})
	return {"title":name,"icon":id,"text":"Стартовый чертёж — есть всегда." if base(tab,id) else "Чертёж открыт." if owned else "Чертёж закрыт.","actions":actions}
func act(tab:String,id:String,action:String)->String:
	match action:
		"run":
			match id:
				"all_on":Game.set_all_recipes(true);return "Все чертежи открыты"
				"all_off":Game.set_all_recipes(false);return "Чертежи закрыты"
				"reset":
					if screen:screen.reset_requested.emit()
					return "Профиль обнулён"
		"toggle":DevUnlocks.toggle(tab,id,not DevUnlocks.owned(tab,id));return "Готово"
		"purchase":DevUnlocks.set_purchase(tab,id,not DevUnlocks.purchased(tab,id));return "Готово"
		"second":DevUnlocks.second_skill(id,ClassCatalog.level(id)<8);return "Готово"
		"group_on","group_off":
			for key in DevUnlocks.catalog(tab):DevUnlocks.toggle(tab,key,action=="group_on")
			return "Группа обновлена"
	return ""
