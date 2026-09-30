extends RefCounted
## UI reference, not a gameplay cap: full hub/class + a strong, attainable late-run build.
## 8 epic hero damage picks, 6 epic weapon damage picks, 4 epic weapon rate picks,
## and 2 weapon secrets. Extra choices may exceed the reference.
static func weapon(id:String)->Dictionary:
	var data=preload("res://scripts/weapon_catalog.gd").DATA[id]
	var specialization=1.25 if id in ["shotgun","smg","rifle"] else 1.30 if id=="sniper" else 1.0
	var damage=data.damage*1.15*1.10*specialization*(1+Game.MAX_LEVEL*.05+8*.3+6*.36+2*.75)
	return {"damage":damage,"rate":1.0/(data.interval*pow(.7,4)),"range":maximum_range(),"intercept":90.0}
static func vehicle(kind:String)->Dictionary:
	var data=Balance.CONFIG.enemy(kind)
	var stops={"buggy":1,"apc":1,"tank":5}.get(kind,0)
	var chassis_bonus={"buggy":2,"apc":4,"tank":30}.get(kind,0)
	var damage=(data.damage+(Game.MAX_LEVEL*.25+8)*(.25 if kind=="buggy" else 1.0)+stops*(.3 if kind=="buggy" else 2.0))*1.25
	return {"damage":damage,"rate":1.0/(data.fire_interval*pow(.7,4)),"hp":(data.health+chassis_bonus+stops*6)*1.3,"speed":minf(Balance.speed_cap(),data.player_speed*Balance.speed_multiplier_cap()*1.25),"intercept":90.0}
static func current_weapon(arena)->Dictionary:
	var stats=CombatStats.weapon(arena)
	stats.rate*=arena.effects.modify("fire_rate",1.0)
	return stats

static func hint(id:String)->String:
	var values=weapon(id)
	return "Ориентир сильной сборки: %s урона / %s выстр./с. Полный хаб и класс; 8 эпических усилений атаки, 6 урона оружия, 4 темпа, 2 оружейных секрета. Это не предел: число может расти выше полной шкалы." % [UiKit.number(values.damage),UiKit.number(values.rate)]

static func maximum_range()->float:
	var maximum=0.0
	for data in preload("res://scripts/weapon_catalog.gd").DATA.values():maximum=maxf(maximum,data.range)
	return maximum
