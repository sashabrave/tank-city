class_name GarageCatalog
extends RefCounted
const VEHICLES={"buggy":{"name":"Багги","price":450,"base":1,"stage":2,"last":6,"world":1,"previous":""},"apc":{"name":"БТР","price":1800,"base":3,"stage":7,"last":15,"world":2,"previous":"buggy"},"tank":{"name":"Танк","price":5200,"base":5,"stage":16,"last":22,"world":3,"previous":"apc"}}
const BRANCHES={"armor":{"name":"Бронекомплект","stat":"Броня","step":.03},"gun":{"name":"Орудие","stat":"Урон","step":.03},"loader":{"name":"Механизм подачи","stat":"Темп","step":.02}}
static func recipes()->Dictionary:
	var result={}
	for kind in VEHICLES:
		var v=VEHICLES[kind]
		result["vehicle_"+kind]={"name":v.name,"rarity":0 if kind=="buggy" else 1 if kind=="apc" else 2,"description":"Открывает покупку на стоянке. Мир %d." % v.world}
		for branch in BRANCHES:result[kind+"_"+branch]={"name":v.name+" · "+BRANCHES[branch].name,"rarity":1 if kind=="buggy" else 2,"description":"Открывает улучшение: +%d%% за уровень. Требуется купленный транспорт." % roundi(BRANCHES[branch].step*100)}
	return result
static func weight(id:String,stage:int)->int:
	for kind in VEHICLES:
		var v=VEHICLES[kind]
		# World 1 carries every vehicle; the blueprint tier cap along the route decides when it can drop.
		if Campaign.unified_content():
			if id=="vehicle_"+kind:return 90
			if id.begins_with(kind+"_"):return 45 if kind in Game.garage.owned or "vehicle_"+kind in Game.garage.unlocks else 0
			continue
		if id=="vehicle_"+kind:return 90 if Campaign.recipe_world()==v.world and stage>=v.stage else 0
		if id.begins_with(kind+"_"):return 45 if Campaign.recipe_world()>=v.world and stage>=v.stage and (kind in Game.garage.owned or "vehicle_"+kind in Game.garage.unlocks) else 0
	return 0
## Player vehicles carry more armour than the same enemy hull: each is clearly stronger than the soldier in its
## role (buggy fast scout, APC middle, tank heavy one-shotting infantry). Enemy health is left untouched.
const PLAYER_ARMOR={"buggy":1.4,"apc":1.8,"tank":1.6}
static func stats(kind:String,arena=null,origin:String="owned",zone:int=1,changes:Dictionary={})->Dictionary:
	var t=Balance.CONFIG.enemy(kind)
	if origin=="captured":
		var stock=.85*(1+.04*clampi(zone-1,0,2))
		return {"hp":t.health*PLAYER_ARMOR.get(kind,1.0)*stock,"damage":t.damage*stock,"interval":t.fire_interval,"speed":t.player_speed,"pressure":.35}
	var hp=t.health*PLAYER_ARMOR.get(kind,1.0);var damage=t.damage+Game.meta_damage()*(.25 if kind=="buggy" else 1.0);var interval=t.fire_interval;var speed=t.player_speed*CombatStats.initial_speed_multiplier()
	if arena!=null:
		var mods=arena.run.vehicle_mods[kind];hp+=mods.hp;damage+=mods.damage+(arena.damage_bonus+changes.get("damage_bonus",0.0))*(.25 if kind=="buggy" else 1.0);interval*=arena.fire_multiplier*float(mods.get("rate",1.0));speed=t.player_speed*mods.speed*arena.speed_multiplier
	hp*=1+Game.garage.level(kind,"armor")*.03;damage*=1+Game.garage.level(kind,"gun")*.03;interval/=1+Game.garage.level(kind,"loader")*.02
	if Game.selected_class in ["driver","engineer"]:hp*=1.15+Game.class_specialization()*.01;damage*=1.1+Game.class_specialization()*.01
	return {"hp":hp,"damage":damage,"interval":maxf(Balance.CONFIG.combat.minimum_fire_interval,interval),"speed":minf(speed,Balance.speed_cap()),"pressure":.35}
