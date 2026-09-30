class_name RunUpgrades
extends RefCounted
## Applies UpgradeDef cards to a run and derives card text and previews from the same modifiers.
const PREVIEW_LABELS={"hp":["HP",""],"speed":["Скорость",""],"rate":["Темп"," /с"],"damage":["Урон",""],"intercept":["Перехват","%"],"range":["Дальность","%"],"healing":["Лечение","%"],"device_power":["Мощность","%"],"device_cooldown":["Кулдаун","%"]}

static func stacks(arena,id:String)->int:
	return arena.run.upgrade_history.filter(func(entry):return entry.get("id","")==id).size()

static func eligible(arena,def:UpgradeDef)->bool:
	if def.weight<=0:return false
	if def.max_stacks>0 and stacks(arena,def.id)>=def.max_stacks:return false
	if def.effect!=null and def.id in arena.run.behavior_cards:return false
	if "abilities" in def.requires and arena.abilities.slots.is_empty():return false
	# A capped stat that would not move is not offered (speed and interception limits).
	if def.preview!="" and is_instance_valid(arena.player):
		var change=measure_change(arena,def,Balance.tier_power(0))
		if is_equal_approx(change[0],change[1]):return false
	return true

## Weighted draw without replacement from the shared combat RNG.
static func roll(arena,count:int)->Array:
	var pool=UpgradeRegistry.all().filter(func(def):return eligible(arena,def))
	var result=[]
	while result.size()<count and not pool.is_empty():
		var total=0
		for def in pool:total+=def.weight
		var pick=arena.run.combat_rng.randi_range(0,total-1)
		for i in range(pool.size()):
			pick-=pool[i].weight
			if pick<0:result.append(pool[i].id);pool.remove_at(i);break
	return result

static func apply(arena,id:String,tier:int,record:bool=true)->bool:
	var def=UpgradeRegistry.get_def(id)
	if def==null:push_error("Unknown upgrade: "+id);return false
	if record:arena.run.upgrade_history.append({"id":id,"tier":tier})
	apply_power(arena,def,Balance.tier_power(tier))
	if record:
		if def.effect!=null:Game.progression.event("behavior_cards")
		Game.progression.event("card_stack",stacks(arena,id),true)
	return true

static func apply_power(arena,def:UpgradeDef,power:float):
	for modifier in def.modifiers:apply_modifier(arena.run,modifier,power)
	arena.run.soldier_hp=minf(arena.run.soldier_hp,arena.run.soldier_max_hp)
	if def.effect!=null and def.id not in arena.run.behavior_cards:arena.run.behavior_cards.append(def.id)
	refresh_player(arena)

static func apply_modifier(run,modifier:Dictionary,power:float):
	var path=resolve(run,str(modifier.stat))
	var current=float(path[0].get(path[1]))
	var value=float(modifier.get("value",0.0))*power
	var next=current
	match str(modifier.get("op","add")):
		"add":next=current+value
		"add_round":next=current+roundi(value)
		"scale":next=current*(1.0+value)
		"pow":next=current*pow(float(modifier.get("value",1.0)),power)
		_:push_error("Unknown upgrade op: "+str(modifier.get("op")))
	if modifier.has("cap"):next=minf(next,cap_value(modifier.cap))
	path[0].set(path[1],int(round(next)) if typeof(path[0].get(path[1]))==TYPE_INT else next)

static func cap_value(cap)->float:
	if cap is String:return float(Balance.CONFIG.combat.get(cap))
	return float(cap)

## Returns [container, key]: a RunState object or a weapon_mods dictionary.
static func resolve(run,stat:String)->Array:
	if stat.begins_with("weapon_mods."):
		var parts=stat.split(".")
		var weapon=run.weapon if parts[1]=="@weapon" else parts[1]
		return [run.weapon_mods[weapon],parts[2]]
	return [run,stat]

## Sync the live actor after run stats changed; vehicles re-derive from GarageCatalog.
static func refresh_player(arena):
	var player=arena.room.player
	if not is_instance_valid(player):return
	if player.kind=="soldier":
		player.apply_weapon();player.max_hp=arena.run.soldier_max_hp;player.hp=arena.run.soldier_hp;player.refresh_health()
	elif player.kind in GarageCatalog.VEHICLES:
		var stats=GarageCatalog.stats(player.kind,arena,player.vehicle_origin,player.vehicle_zone)
		player.damage=stats.damage;player.fire_interval=stats.interval;player.speed=stats.speed

static func measure(arena,kind:String)->float:
	var player=arena.room.player
	var vehicle=is_instance_valid(player) and player.kind in GarageCatalog.VEHICLES
	var vehicle_stats=GarageCatalog.stats(player.kind,arena,player.vehicle_origin,player.vehicle_zone) if vehicle else {}
	match kind:
		"hp":return float(arena.run.soldier_max_hp)
		"speed":return vehicle_stats.speed if vehicle else CombatStats.soldier_speed(arena.run)
		"rate":return 1.0/(vehicle_stats.interval if vehicle else CombatStats.weapon(arena).interval)
		"damage":return vehicle_stats.damage if vehicle else CombatStats.weapon(arena).damage
		"intercept":return CombatStats.probability(arena,player.kind if is_instance_valid(player) else "soldier",arena.run.weapon,player.vehicle_origin if vehicle else "owned")*100
		"range":return arena.run.range_multiplier*100
		"healing":return arena.run.healing_multiplier*100
		"device_power":return arena.run.ability_power_multiplier*100
		"device_cooldown":return arena.run.ability_cooldown_multiplier*100
	return 0.0

## Before/after of the card's preview value, computed by applying the real modifiers and restoring the run.
static func measure_change(arena,def:UpgradeDef,power:float)->Array:
	var backup=[]
	for modifier in def.modifiers:
		var path=resolve(arena.run,str(modifier.stat));backup.append([path[0],path[1],path[0].get(path[1])])
	backup.append([arena.run,"soldier_hp",arena.run.soldier_hp])
	var before=measure(arena,def.preview)
	for modifier in def.modifiers:apply_modifier(arena.run,modifier,power)
	var after=measure(arena,def.preview)
	for i in range(backup.size()-1,-1,-1):backup[i][0].set(backup[i][1],backup[i][2])
	return [before,after]

static func preview_text(arena,id:String,tier:int)->String:
	var def=UpgradeRegistry.get_def(id)
	if def==null or def.preview=="" or not is_instance_valid(arena.room.player):return ""
	var change=measure_change(arena,def,Balance.tier_power(tier))
	var label=PREVIEW_LABELS.get(def.preview,[def.title,""])
	return UiKit.change_text(label[0],change[0],change[1],label[1])

static func card(arena,offer:Dictionary)->Dictionary:
	var def=UpgradeRegistry.get_def(offer.id);var tier=int(offer.tier)
	var detail=preview_text(arena,offer.id,tier)
	if def.detail!="":detail=def.detail if detail=="" else detail+"\n"+def.detail
	return {"category":def.category,"title":def.title,"detail":detail,"icon":def.icon if def.icon!="" else def.id,"heading":arena.LOOT.RARITY_NAMES[tier],"color":Color(arena.LOOT.RARITY_COLORS[tier]),"disabled":false,"button":"Выбрать"}
