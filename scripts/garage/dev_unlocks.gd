class_name DevUnlocks
extends RefCounted
const GROUPS={"research":"Постройки","weapon":"Оружие","classes":"Классы","ability":"Гаджеты","hq":"Штаб","bonus":"Бонусы","garage":"Транспорт"}
const GADGETS=["barrier","mine","laser","airstrike"]
static func catalog(group:String)->Dictionary:
	if group=="classes":return Game.CLASSES
	var result=Game.recipe_catalog(group).duplicate()
	if group=="ability":
		for id in result.keys():
			if id not in GADGETS:result.erase(id)
	return result
static func owned(group:String,id:String)->bool:return id in Game.class_unlocks if group=="classes" else id in Game.recipe_owned(group)
static func toggle(group:String,id:String,value:bool):
	if group=="classes":
		if id=="recruit":return
		if value and id not in Game.class_unlocks:Game.class_unlocks.append(id)
		if not value:
			Game.class_unlocks.erase(id);Game.class_first_slots.erase(id);Game.class_second_slots.erase(id)
			if Game.selected_class==id:Game.selected_class="recruit"
	else:Game.set_recipe_unlocked(group,id,value)
	Game.save_progress()
static func purchased(group:String,id:String)->bool:
	match group:
		"research":return id in Game.built_workshops
		"ability":return id in Game.purchased_gadgets
		"hq":return id in Game.purchased_hq
		"garage":return id.trim_prefix("vehicle_") in Game.garage.owned if id.begins_with("vehicle_") else false
		"classes":return id in Game.class_first_slots
	return false
static func set_purchase(group:String,id:String,value:bool):
	if value and not owned(group,id):toggle(group,id,true)
	var target:Array=[]
	match group:
		"research":
			if id not in Game.BUILD_COST:return
			target=Game.built_workshops
		"ability":target=Game.purchased_gadgets
		"hq":target=Game.purchased_hq
		"classes":target=Game.class_first_slots
		"garage":
			if not id.begins_with("vehicle_"):return
			id=id.trim_prefix("vehicle_");target=Game.garage.owned
		_:return
	if value and id not in target:target.append(id)
	if not value:
		target.erase(id)
		if group=="classes":Game.class_second_slots.erase(id)
		if group=="ability" and Game.gadget==id:Game.gadget=""
		if group=="hq":
			Game.hq_modules.erase(id)
			if Game.hq_active==id:Game.hq_active=""
		if group=="garage" and Game.garage.selected==id:Game.garage.selected=""
	Game.save_progress()
static func second_skill(id:String,value:bool):
	if value:
		set_purchase("classes",id,true);Game.class_levels[id]=maxi(7,int(Game.class_levels.get(id,0)))  # level 8: second slot
	else:Game.class_levels[id]=mini(6,int(Game.class_levels.get(id,0)))
	Game.save_progress()
