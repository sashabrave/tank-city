extends RefCounted
var unlocks:Array=[]
var owned:Array=[]
var selected=""
var levels:Dictionary={}
func serialize()->Dictionary:return {"unlocks":unlocks,"owned":owned,"selected":selected,"levels":levels}
func restore(data:Dictionary):
	unlocks=[];owned=[];levels={}
	for id in data.get("unlocks",[]):
		if id in GarageCatalog.recipes() and id not in unlocks:unlocks.append(id)
	for kind in data.get("owned",[]):
		if kind in GarageCatalog.VEHICLES and kind not in owned:owned.append(kind)
	selected=str(data.get("selected",""));selected=selected if selected in owned else ""
	for kind in GarageCatalog.VEHICLES:
		for branch in GarageCatalog.BRANCHES:
			var id=kind+"_"+branch;levels[id]=clampi(int(data.get("levels",{}).get(id,0)),0,5)
func level(kind:String,branch:String)->int:return int(levels.get(kind+"_"+branch,0))
func cap(kind:String)->int:return clampi(Game.progression.level-int(GarageCatalog.VEHICLES[kind].base)+1,0,5)
func cost(kind:String,branch:String)->int:return roundi((240 if kind=="buggy" else 650 if kind=="apc" else 1400)*pow(1.8,level(kind,branch)))
func can_buy(kind:String)->bool:
	if kind not in GarageCatalog.VEHICLES or "garage" not in Game.built_workshops:return false
	var v=GarageCatalog.VEHICLES[kind]
	return kind not in owned and "vehicle_"+kind in unlocks and Game.progression.level>=v.base and (v.previous=="" or v.previous in owned) and Game.credits>=v.price
func buy(kind:String)->bool:
	if not can_buy(kind):return false
	Game.credits-=GarageCatalog.VEHICLES[kind].price;owned.append(kind);selected=kind
	Game.progression.event("own_"+kind,1,true)
	if Game.progression.telegram.is_empty():Game.progression.telegram_options.clear()
	Game.save_progress();return true
func choose(kind:String)->bool:
	if "garage" not in Game.built_workshops or (kind!="" and kind not in owned):return false
	selected=kind;Game.save_progress();return true
func upgrade(kind:String,branch:String)->bool:
	if kind not in owned or branch not in GarageCatalog.BRANCHES or kind+"_"+branch not in unlocks or "garage" not in Game.built_workshops:return false
	if level(kind,branch)>=cap(kind) or Game.credits<cost(kind,branch):return false
	Game.credits-=cost(kind,branch);levels[kind+"_"+branch]=level(kind,branch)+1;Game.progression.event("vehicle_equipment");Game.save_progress();return true
func starting_vehicle()->String:return selected if "garage" in Game.built_workshops and selected in owned else ""
