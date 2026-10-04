extends RefCounted
## One presentation catalog; values always come from combat calculations, not UI copies.
static func row(title:String,base:float,current:float,unit:String="")->Dictionary:
	return {"title":title,"base":base,"current":current,"unit":unit}
static func weapon(arena=null,id:String="")->Array:
	var base=CombatStats.weapon(null,id);var current=CombatStats.weapon(arena,id)
	var result=[]
	for spec in [["damage","Урон",""],["rate","Темп"," /с"],["range","Дальность"," м"],["intercept","Напор","%"]]:
		result.append(row(spec[1],base[spec[0]],current[spec[0]],spec[2]))
	return result
## Rows grouped by what they are about; the dossier hides optional stats that are zero both at base and now.
static func fighter(arena=null)->Array:
	var run=arena.run if is_instance_valid(arena) else null
	var health=row("Максимум здоровья",CombatStats.initial_health(),run.soldier_max_hp if run!=null else CombatStats.initial_health())
	var speed=row("Скорость пешком",CombatStats.soldier_speed(),CombatStats.soldier_speed(run)," м/с")
	var gun=weapon(arena,run.weapon if run!=null else Game.selected_weapon)
	if is_instance_valid(arena) and is_instance_valid(arena.player) and arena.player.kind=="soldier":
		var actor=arena.player
		speed.current=actor.speed;gun[0].current=actor.damage;gun[1].current=1.0/actor.fire_interval*arena.effects.modify("fire_rate",1.0)
	var percent=func(field:String,title:String):return row(title,100,100*float(run.get(field)) if run!=null else 100,"%")
	var groups={"fire":gun.duplicate(),"survival":[health,speed,percent.call("healing_multiplier","Эффективность лечения")],"abilities":[percent.call("ability_power_multiplier","Сила способностей"),percent.call("ability_cooldown_multiplier","Перезарядка способностей")],"ammo":[],"recon":[],"logistics":[]}
	# The gear page is the only place for them now (author, 2026-10-03): every combat stat shows, zero included,
	# and the loaded ammo's own chances count (an ammo box carries its values, not the run).
	var ammo=Ammo.effective(arena) if is_instance_valid(arena) and run!=null else {}
	var from_ammo={"burn_chance":["burn","chance"],"burn_power":["burn","power"],"stun_chance":["stun","chance"],"shock_bonus":["shock","bonus"]}
	for def in StatRegistry.all():
		var item=registry_row(def,arena)
		var link=from_ammo.get(def.run_field,from_ammo.get(def.id,[]))
		if not link.is_empty() and str(ammo.get("type",""))==link[0]:item.current=float(item.current)+float(ammo.get("stats",{}).get(link[1],0.0))*(100.0 if def.format=="percent" else 1.0)
		groups[def.family].append(item)
	if is_instance_valid(arena) and run!=null:
		groups.survival.append(row("Прочность штаба",float(arena.base_max_hp),float(arena.base_hp)))
		groups.logistics.append(row("Перебросы",float(run.rerolls_left),float(run.rerolls_left)))
		groups.logistics.append(row("Ячейки рюкзака",float(Backpack.capacity()),float(Backpack.capacity())))
	var result=[]
	for key in ["fire","survival","abilities","ammo","recon","logistics"]:
		if groups[key].is_empty():continue
		result.append({"group":"Способности" if key=="abilities" else RunUpgrades.FAMILIES[key]})
		result.append_array(groups[key])
	return result
## Every StatRegistry characteristic: base = what a run starts with (hub training included), current = now.
## A new stat file shows up here without UI changes.
static func registry(arena=null)->Array:
	return StatRegistry.all().map(func(def):return registry_row(def,arena))
static func registry_row(def,arena=null)->Dictionary:
	var base=StatRegistry.value(def,null);var current=StatRegistry.value(def,arena if is_instance_valid(arena) else null)
	match def.format:
		"percent":return row(def.title,base*100,current*100,"%")
		"multiplier":return row(def.title,base,current,"×")
	return row(def.title,base,current)
static func add_bars(parent:Control,pos:Vector2,width:float,rows:Array,row_height:float=48,adaptive:bool=false):
	var bars=preload("res://scripts/ui/comparison_bars.gd").new();bars.rows=rows;bars.row_height=row_height;bars.adaptive_columns=adaptive;parent.add_child(bars);bars.position=pos;bars.size=Vector2(width,0);bars.reflow();return bars
static func status(arena=null)->Array:
	var result=["Уровень персонажа: %d · Уровень класса: %d" % [Game.character_level(),Game.class_level()],"Постоянный бонус урона: %s%% · Ячеек рюкзака: %d" % [UiKit.number(Game.damage_level*5),Backpack.capacity()],"Потеря сплава при выбывании: примерно %s%% (±10%%)" % UiKit.number(Game.death_loss_fraction()*100)]
	if not is_instance_valid(arena):return result
	result.append("Здоровье: %s / %s · Прочность штаба: %s" % [UiKit.number(arena.soldier_hp),UiKit.number(arena.soldier_max_hp),UiKit.number(arena.base_hp)])
	result.append("Перебросов: %d · Уничтожено врагов: %d · Сплава за вылазку: %d" % [arena.run.rerolls_left,arena.run.kills,arena.run.earned])
	if is_instance_valid(arena.player) and arena.player.kind!="soldier":
		var actor=arena.player
		result.append("Техника · Броня: %s · Урон: %s · Темп: %s /с · Скорость: %s" % [UiKit.number(actor.hp),UiKit.number(actor.damage),UiKit.number(1.0/actor.fire_interval),UiKit.number(actor.speed)])
	# A separate read-only ability instance uses the same formulas without selecting a live slot.
	for id in arena.abilities.slots:
		var ability=preload("res://scripts/run_ability.gd").new();ability.arena=arena;ability.selected=id
		ability.level=(arena.abilities.level if id==arena.abilities.selected else arena.abilities.states[id].level).duplicate()
		result.append("%s · Сила: %s · Перезарядка: %s с" % [AbilityCatalog.DATA[id].name,UiKit.number(ability.power()),UiKit.number(ability.interval())])
	return result

static func follow_grid(parent:Control,bars:Control):
	var base_height=bars.content_height();var minimum=parent.custom_minimum_size.y;var following=[]
	for child in parent.get_children():
		if child is Control and child!=bars and child.position.y>=bars.position.y+base_height:following.append([child,child.position.y])
	bars.resized.connect(func():
		var shift=bars.content_height()-base_height
		for item in following:
			if is_instance_valid(item[0]):item[0].position.y=item[1]+shift
		parent.custom_minimum_size.y=minimum+shift)

## Hero state for the tablet: live effect timers (the same table as the HUD strip) and the bullet effects of
## this run. [{icon, title, value, remaining}] — remaining 0..1 for a timer, -1 for "active", null for none.
static func state(arena=null)->Array:
	var result=[]
	if not is_instance_valid(arena) or arena.run==null:
		result.append({"icon":"damage","title":"Эффекты пуль","value":"Берутся картами в бою","remaining":null})
		var base=[]
		for id in ["burn_power","shock_power","stun_power"]:
			var def=StatRegistry.get_def(id)
			if def!=null and StatRegistry.level(id)>0:base.append(def.title+" "+StatRegistry.text(def,StatRegistry.base_value(def)))
		if not base.is_empty():result.append({"icon":"upgrades/fire","title":"База из Казармы","value":" · ".join(base),"remaining":null})
		return result
	var strip=preload("res://scripts/ui/status_strip.gd").new();strip.arena=arena
	var entries={};var raw=strip.entries()
	for id in raw:entries[id]=[raw[id][0],float(raw[id][1].call())]
	strip.free()
	# Full timer lengths are known to the live HUD strip (remembered when each effect started).
	var totals={}
	for node in arena.find_children("*","HBoxContainer",true,false):
		if node.get_script()==preload("res://scripts/ui/status_strip.gd"):totals=node.totals
	if totals.is_empty() and arena.is_inside_tree():
		for node in arena.get_tree().root.find_children("*","HBoxContainer",true,false):
			if node.get_script()==preload("res://scripts/ui/status_strip.gd") and node.arena==arena:totals=node.totals
	for id in entries:
		var left=float(entries[id][1])
		if left==0.0:continue
		result.append({"icon":entries[id][0],"title":preload("res://scripts/ui/status_strip.gd").HINTS.get(id,id).get_slice(":",0),"value":"%s с" % UiKit.number(snappedf(left,.1)) if left>0 else "Активно","remaining":-1.0 if left<0 else clampf(left/maxf(left,float(totals.get(id,left))),0,1)})
	var run=arena.run
	# The loaded ammo carries its own chance (T-157: the line read «0%» with stun ammo in the slot).
	var ammo=Ammo.effective(arena)
	var ammo_stat=func(type:String,key:String)->float:return float(ammo.get("stats",{}).get(key,0.0)) if str(ammo.get("type",""))==type else 0.0
	var burn=run.burn_chance+ammo_stat.call("burn","chance");var stun=run.stun_chance+ammo_stat.call("stun","chance")
	if burn>0:
		result.append({"icon":"fire","title":"Поджог","value":"%d%% · урон ×%s · %s с" % [roundi(minf(CombatMods.CAPS.burn_chance,burn)*100),UiKit.number(1.0+run.burn_power+ammo_stat.call("burn","power")),UiKit.number(CombatMods.burn_time(run))]+(" · цепь" if "chain_fire" in run.behavior_cards else ""),"remaining":null})
	if stun>0:
		result.append({"icon":"star","title":"Контузия","value":"%d%% · %s с" % [roundi(minf(CombatMods.CAPS.stun_chance,stun)*100),UiKit.number(CombatMods.stun_time(run,ammo))]+(" · от крита" if "crit_stun" in run.behavior_cards else ""),"remaining":null})
	if run.shock_bonus>0:
		result.append({"icon":"device_power","title":"ЭМИ","value":"+%d%% по технике" % roundi(minf(CombatMods.CAPS.shock_bonus,run.shock_bonus+run.shock_power)*100),"remaining":null})
	if result.is_empty():result.append({"icon":"heart","title":"Без эффектов","value":"Эффекты пуль берутся картами в бою","remaining":null})
	return result
