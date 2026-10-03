class_name RunUpgrades
extends RefCounted
## Applies UpgradeDef cards to a run and derives card text and previews from the same modifiers.
const PREVIEW_LABELS={"hp":["HP",""],"speed":["Скорость",""],"rate":["Темп"," /с"],"damage":["Урон",""],"intercept":["Перехват","%"],"range":["Дальность","%"],"healing":["Лечение","%"],"device_power":["Сила способностей","%"],"device_cooldown":["Перезарядка","%"],
	"crit_chance":["Крит","%"],"crit_damage":["Крит-урон","%"],"dodge":["Уклонение","%"],"guard_bullet":["Защита от пуль","%"],"guard_blast":["Защита от взрывов","%"],"guard_vehicle":["Защита от техники","%"],
	"pierce":["Пробитие",""],"burn":["Поджог","%"],"burn_power":["Урон горения","%"],"burn_time":["Горение"," с"],"stun_time":["Оглушение"," с"],"shock":["По технике","%"],"stun":["Оглушение","%"],"stealth":["Маскировка","%"],"marauder":["Добыча","%"],"field_repair":["Ремонт за убийство",""],"luck":["Удача",""],"safe_slots":["Сейф рюкзака",""]}
const FAMILIES={"fire":"Огневая мощь","survival":"Живучесть","ammo":"Спецпатроны","recon":"Разведка","logistics":"Тыл"}
const TIER_NAMES=["Обычное","Редкое","Эпическое","Легендарное"]
## Chance of rare / epic / legendary per stage band (progress index 0-1, 2-3, 4-5, 6+). Rarer cards appear
## rarely at the start; ★★ rooms and bosses use the next band; luck multiplies all three.
const TIER_BANDS=[[.07,.012,.001],[.16,.04,.004],[.26,.08,.012],[.32,.12,.025],[.36,.16,.04]]

static func stacks(arena,id:String)->int:
	return arena.run.upgrade_history.filter(func(entry):return entry.get("id","")==id).size()

static func eligible(arena,def:UpgradeDef,tier:int=3)->bool:
	if def.weight<=0 or def.min_tier>tier:return false
	# Ammo (T-109): a base ammo card is offered while that type is not loaded (it can come back after being
	# swapped out); its improvements only while it is loaded.
	# Ammo items (T-112) fit the weapon's ammo class and can drop again with a better roll.
	if def.id in Ammo.TYPES:
		if not Ammo.fits(def.id,str(arena.weapon)):return false
	elif def.max_stacks>0 and stacks(arena,def.id)>=def.max_stacks:return false
	if (def.effect!=null or def.flag) and def.id in arena.run.behavior_cards:return false
	if "abilities" in def.requires and arena.abilities.slots.is_empty():return false
	# Enhancements of an effect appear only after its base card: requires "card:burn".
	for need in def.requires:
		if need.begins_with("card:") and need.trim_prefix("card:") in Ammo.TYPES and not Ammo.loaded(arena.run,need.trim_prefix("card:")):return false
		if need.begins_with("card:") and stacks(arena,need.trim_prefix("card:"))==0:return false
	# A capped stat that would not move is not offered (speed and interception limits).
	if def.preview!="" and is_instance_valid(arena.player):
		var change=measure_change(arena,def,Balance.tier_power(0))
		if is_equal_approx(change[0],change[1]):return false
	return true

## Rarity of one card: stage band, room difficulty and luck. Uses the shared combat RNG.
static func roll_tier(arena)->int:
	var stage=Campaign.progress_index(arena.room_index) if arena.room_index>=0 else 0
	var band=0 if stage<2 else 1 if stage<4 else 2 if stage<6 else 3
	if Campaign.endless:band=mini(4,3+Campaign.cycle)
	if arena.room.boss_room or int(arena.room.difficulty)>=1:band=mini(TIER_BANDS.size()-1,band+1)
	var chances=TIER_BANDS[band];var factor=1.0+CombatMods.luck(arena)*.04
	var value=arena.run.combat_rng.randf()
	if value<chances[2]*factor:return 3
	if value<(chances[2]+chances[1])*factor:return 2
	if value<(chances[2]+chances[1]+chances[0])*factor:return 1
	return 0
static func family_counts(arena)->Dictionary:
	var counts={}
	for entry in arena.run.upgrade_history:
		var def=UpgradeRegistry.get_def(str(entry.get("id","")))
		if def!=null:counts[def.family]=int(counts.get(def.family,0))+1
	return counts
## Weight after build attraction: every taken card of a family makes the family 35% likelier (up to ×3),
## the shell's favourite family ×1.5.
static func attracted_weight(arena,def:UpgradeDef,counts:Dictionary)->float:
	var weight=float(def.weight)*minf(3.0,1.0+.35*int(counts.get(def.family,0)))
	if ClassCatalog.info(Game.selected_class).family==def.family:weight*=1.5
	return weight
## Offers {id, tier}: each card rolls its own rarity, then a card that exists at that rarity is drawn
## without replacement. The first offer of a run holds a card of the shell's favourite family.
static func roll_offers(arena,count:int)->Array:
	var counts=family_counts(arena);var result=[];var taken=[]
	var favourite=ClassCatalog.info(Game.selected_class).family
	for slot in range(count):
		var tier=roll_tier(arena)
		if slot==0 and arena.run.dry_offers>=2:tier=maxi(tier,1)
		var pool=UpgradeRegistry.all().filter(func(def):return def.id not in taken and eligible(arena,def,tier))
		if slot==0 and arena.run.upgrade_history.is_empty():
			var themed=pool.filter(func(def):return def.family==favourite)
			if not themed.is_empty():pool=themed
		if pool.is_empty():continue
		var total=0.0
		for def in pool:total+=attracted_weight(arena,def,counts)
		var pick=arena.run.combat_rng.randf()*total
		var chosen=pool.back()
		for def in pool:
			pick-=attracted_weight(arena,def,counts)
			if pick<0:chosen=def;break
		taken.append(chosen.id);result.append({"id":chosen.id,"tier":maxi(tier,chosen.min_tier)})
	arena.run.dry_offers=0 if result.any(func(offer):return offer.tier>=1) else arena.run.dry_offers+1
	return result
static func roll(arena,count:int)->Array:return roll_offers(arena,count).map(func(offer):return offer.id)

static func apply(arena,id:String,tier:int,record:bool=true)->bool:
	var def=UpgradeRegistry.get_def(id)
	if def==null:push_error("Unknown upgrade: "+id);return false
	# An ammo card is an item with its own rolled values (T-112): it goes into a slot; the card's stat
	# modifiers are not applied — the item carries the values.
	if id in Ammo.TYPES:
		Ammo.ensure(arena.run,str(arena.weapon))
		var item=Ammo.roll(id,tier,Ammo.seed_for(arena,id,tier))
		var old=Ammo.load_item(arena.run,item)
		if not old.is_empty():
			# No room in the backpack: the replaced ammo waits on the field in a sack (nothing is lost).
			if Backpack.full(arena.run) and Backpack.can_drop(arena):arena.reward.place_sack(arena.grid_pos(arena.room.player.position),{"recipes":[],"ammo":[old]})
			else:arena.run.ammo_bag.append(old)
		if record:arena.run.upgrade_history.append({"id":id,"tier":tier})
		refresh_player(arena)
		if is_instance_valid(arena.hud):arena.hud.refresh_ammo()
		return true
	if record:arena.run.upgrade_history.append({"id":id,"tier":tier})
	apply_power(arena,def,Balance.tier_power(tier))
	if record:
		if def.effect!=null or def.flag:Game.progression.event("behavior_cards")
		Game.progression.event("card_stack",stacks(arena,id),true)
	return true

static func apply_power(arena,def:UpgradeDef,power:float):
	for modifier in def.modifiers:apply_modifier(arena.run,modifier,power)
	arena.run.soldier_hp=minf(arena.run.soldier_hp,arena.run.soldier_max_hp)
	if (def.effect!=null or def.flag) and def.id not in arena.run.behavior_cards:arena.run.behavior_cards.append(def.id)
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
		"crit_chance":return CombatMods.crit_chance(arena)*100
		"crit_damage":return arena.run.crit_damage*100
		"dodge":return minf(CombatMods.CAPS.dodge,arena.run.dodge)*100
		"guard_bullet":return minf(CombatMods.CAPS.guard,arena.run.guard_bullet)*100
		"guard_blast":return minf(CombatMods.CAPS.guard,arena.run.guard_blast)*100
		"guard_vehicle":return minf(CombatMods.CAPS.guard,arena.run.guard_vehicle)*100
		"pierce":return float(arena.run.pierce)
		"burn":return minf(CombatMods.CAPS.burn_chance,arena.run.burn_chance)*100
		"burn_power":return (1.0+arena.run.burn_power)*100
		"burn_time":return CombatMods.burn_time(arena.run)
		"stun_time":return CombatMods.stun_time(arena.run)
		"shock":return arena.run.shock_bonus*100
		"stun":return minf(CombatMods.CAPS.stun_chance,arena.run.stun_chance)*100
		"stealth":return minf(CombatMods.CAPS.stealth,arena.run.stealth)*100
		"marauder":return arena.run.marauder*100
		"field_repair":return arena.run.field_repair
		"luck":return float(CombatMods.luck(arena))
		"safe_slots":return float(arena.run.safe_slots)
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
	if label[1]=="%":change=[roundf(change[0]),roundf(change[1])]
	return UiKit.change_text(label[0],change[0],change[1],label[1])

## Rows of a card: [change, parameter, before, after] — the change in large type, then the parameter with its
## old (struck through) and resulting value.
static func card_rows(arena,def:UpgradeDef,tier:int)->Array:
	if def.preview=="" or not is_instance_valid(arena.room.player):return []
	var change=measure_change(arena,def,Balance.tier_power(tier))
	var label=PREVIEW_LABELS.get(def.preview,[def.title,""]);var delta=float(change[1])-float(change[0])
	if is_zero_approx(delta):return []
	var unit=str(label[1]).strip_edges()
	# T-060: whole numbers for health, percents and other counts; one decimal only where it matters
	# (rate per second, metres, seconds) and the change would vanish when rounded.
	var fine=unit in ["/с","м","с"] or label[0] in ["Урон","Скорость"] or absf(delta)<.95
	var step=.1 if fine else 1.0
	var value=("+" if delta>0 else "−")+UiKit.number(absf(snappedf(delta,step)))+(unit if unit=="%" else (" "+unit if unit!="" else ""))
	var shown=func(v:float)->String:return UiKit.number(snappedf(v,step))+(unit if unit=="%" else (" "+unit if unit!="" else ""))
	return [[value,str(label[0]).to_lower() if label[0]!="HP" else "HP",shown.call(float(change[0])),shown.call(float(change[1]))]]
## First sentence of a card description: the card stays short, the full text is in the tooltip.
static func short_detail(text:String)->String:
	var cut=text.find(". ")
	return text if cut<0 else text.substr(0,cut+1)
static func card(arena,offer:Dictionary)->Dictionary:
	var def=UpgradeRegistry.get_def(offer.id);var tier=int(offer.tier)
	var rows=card_rows(arena,def,tier)
	var detail=preview_text(arena,offer.id,tier)
	if def.detail!="":detail=def.detail if detail=="" else detail+"\n"+def.detail
	tier=clampi(tier,0,TIER_NAMES.size()-1)
	# The card says what it does to the ammo slots (T-109).
	var short=short_detail(def.detail)
	if def.id in Ammo.TYPES:
		# The rolled item and how it compares with the ammo it replaces (or the same type already loaded).
		Ammo.ensure(arena.run,str(arena.weapon))
		var item=Ammo.roll(def.id,tier,Ammo.seed_for(arena,def.id,tier))
		var out=Ammo.replacing(arena.run)
		var same=arena.run.ammo_slots.filter(func(s):return s is Dictionary and s.type==def.id)
		rows=Ammo.compare_rows(item,same[0] if not same.is_empty() else out)
		var rank=func(r:int)->String:return Texts.render(Ammo.RARITY_NAMES[clampi(r,0,3)]).to_lower()
		if not same.is_empty():short=Texts.render("Улучшит")+": "+rank.call(int(same[0].rarity))+" → "+rank.call(int(item.rarity))
		elif not out.is_empty():short=Texts.render("Заменит")+": "+Texts.render(Ammo.NAMES[out.type])+" → "+Texts.render(Ammo.NAMES[def.id])
		else:short=Texts.render("Зарядит")+": "+Texts.render(Ammo.NAMES[def.id])
		if float(item.damage)>0:short+=" · "+Texts.render("урон пули")+" +%d%%" % roundi(item.damage*100)
		if item.twist:short+=". "+Texts.render(Ammo.TWISTS[def.id])
		detail=Ammo.describe(item)+"\n"+def.detail
	var art="upgrades/"+def.id
	if def.id in Ammo.ART:art=Ammo.ART[def.id]
	return {"rows":rows,"short":short,"category":FAMILIES.get(def.family,def.category),"title":def.title,"detail":detail,"icon":def.icon if def.icon!="" else def.id,"art_key":art if def.id in Ammo.TYPES else "upgrades/"+def.id,"heading":TIER_NAMES[tier],"color":Color(arena.LOOT.RARITY_COLORS[tier]),"disabled":false,"button":"Выбрать","family":def.family,"tier":tier,"stacks":stacks(arena,def.id)}
