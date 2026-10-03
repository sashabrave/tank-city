class_name CombatStats
extends RefCounted
## Shared calculations for actors, workshop/tablet values and card previews.
static func class_weapon_multiplier(id:String)->float:
	if Game.selected_class=="heavy" and id=="shotgun" and ClassCatalog.perk_on("heavy",0):return 1.1
	if Game.selected_class=="marksman" and id=="sniper" and ClassCatalog.perk_on("marksman",0):return 1.15
	return 1.0
## Every class level adds health (ClassCatalog.hp_per_level, T-098) and the class's own stats (ClassCatalog.GROWTH).
static func initial_health()->float:return Balance.CONFIG.combat.hero_health+Game.health_upgrade_bonus()+Game.class_health_bonus()+Game.class_level()*ClassCatalog.hp_per_level(Game.selected_class)
static func initial_speed_multiplier()->float:return Game.mobility_multiplier()*(.95 if Game.selected_class=="heavy" else 1.0)
static func soldier_speed(run=null,extra:float=0.0)->float:
	var multiplier=initial_speed_multiplier() if run==null else run.speed_multiplier
	return minf(Balance.speed_cap(),Balance.CONFIG.combat.hero_speed*(minf(Balance.speed_multiplier_cap(),multiplier+extra) if extra>0 else multiplier))
static func weapon(arena=null,id:String="",changes:Dictionary={})->Dictionary:
	if id=="":id=Game.selected_weapon if arena==null else arena.run.weapon
	var data=Game.LOOT.WEAPONS[id]
	var run=arena.run if arena!=null else null
	var mods={"damage":0.0,"interval":1.0,"intercept":0.0} if run==null else run.weapon_mods[id]
	var bonus=(0.0 if run==null else run.damage_bonus)+changes.get("damage_bonus",0.0)
	var damage=class_weapon_multiplier(id)*data.damage*Game.weapon_factor(id)*(1+Game.damage_level*.05+bonus*.3+mods.damage+changes.get("weapon_damage",0.0))
	var interval=maxf(Balance.CONFIG.combat.minimum_fire_interval,data.interval*(1.0 if run==null else run.fire_multiplier)*mods.interval*changes.get("fire",1.0)*changes.get("weapon_fire",1.0))
	# Rolled stats of the gun in hand (weapon crate items, 2026-10-03): +damage share and +fire-rate share.
	var rolled:Dictionary=changes.get("item_stats",run.weapon_stats if run!=null and id==str(run.weapon) else {})
	damage*=1.0+float(rolled.get("damage",0.0))
	interval=maxf(Balance.CONFIG.combat.minimum_fire_interval,interval/(1.0+float(rolled.get("fire",0.0))))
	return {"damage":damage,"interval":interval,"rate":float(data.get("burst",1))/interval,"range":data.range*(1.0 if run==null else run.range_multiplier),"intercept":probability(arena,"soldier",id)*100}
static func probability(arena=null,kind:String="soldier",weapon_id:String="",origin:String="owned")->float:
	if kind in GarageCatalog.VEHICLES and origin=="captured":return .35
	if weapon_id=="":weapon_id=Game.selected_weapon if arena==null else arena.run.weapon
	var run=arena.run if arena!=null else null
	var bonus=0.0 if run==null else run.intercept_chance-.70+run.weapon_mods[weapon_id].intercept
	var chance=clampf((Game.LOOT.WEAPONS[weapon_id].intercept*Balance.CONFIG.combat.interception_base_scale if kind=="soldier" else .35)+bonus+Game.class_pressure_bonus()+Game.shell_pressure_bonus(),Balance.CONFIG.combat.interception_floor,Balance.CONFIG.combat.interception_cap)
	if arena!=null and arena.room.pressure_time>0:
		var odds=chance/(1-chance)*(2.0+arena.effective_bonus_level("pressure")*.3)
		return odds/(1+odds)
	return chance

static func shell_preview(id:String)->Dictionary:
	# Class stat bonuses come from ClassCatalog start modifiers and unlocked perks; only flat HP shows here.
	var extra_hp=0.0
	var modifiers=ClassCatalog.info(id).modifiers.duplicate()
	var perks=ClassCatalog.PERKS.get(id,[])
	for n in range(perks.size()):
		if ClassCatalog.perk_on(id,n):modifiers+=perks[n][1]
	for modifier in modifiers:
		if modifier.stat=="soldier_max_hp":extra_hp+=float(modifier.value)
	var weapon_id=Game.selected_weapon
	var factor=1.1 if id=="heavy" and weapon_id=="shotgun" and ClassCatalog.perk_on(id,0) else 1.15 if id=="marksman" and weapon_id=="sniper" and ClassCatalog.perk_on(id,0) else 1.0
	return {
		"health":Balance.CONFIG.combat.hero_health+Game.health_upgrade_bonus()+(ClassCatalog.level(id)-1)*ClassCatalog.hp_per_level(id)+extra_hp,
		"speed":minf(Balance.speed_cap(),Balance.CONFIG.combat.hero_speed*Game.mobility_multiplier()*(.95 if id=="heavy" else 1.0)),
		"damage":weapon().damage/class_weapon_multiplier(weapon_id)*factor,
		"pressure":clampf(Game.LOOT.WEAPONS[weapon_id].intercept*Balance.CONFIG.combat.interception_base_scale+Game.shell_pressure_bonus(),Balance.CONFIG.combat.interception_floor,Balance.CONFIG.combat.interception_cap)*100
	}
