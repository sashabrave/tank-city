extends RefCounted
const NAMES={"field_repair":"Полевой ремонт","comrade":"Товарищ","barrier":"Противотанковый ёж","grenade":"Граната","laser":"Лазер","gas":"Газ","ally_drone":"Дрон","mine":"Мина","airstrike":"Авиаудар","cloak":"Маскировка","shield":"Щит"}
var slots:Array=[]
var states:Dictionary={}
var cooldown_totals:Dictionary={}
var barriers:Array=[]
var mines:Array=[]
var shield_hits=0
var shield_time=0.0
var shield_timer=0.0
var shield_bonus=0.0
var cloak_time=0.0
var cloak_ghost=false
var actions=preload("res://scripts/systems/ability_actions.gd").new()
var arena
var selected=""
var cooldown=0.0
var level={"cooldown":0.0,"power":0.0,"utility":0.0}
func setup():
	slots=Game.hero_loadout()
	for id in slots:states[id]={"cooldown":0.0,"level":{"cooldown":0.0,"power":0.0,"utility":0.0}}
	if not slots.is_empty():select(slots[0])
	shield_hits=0
func select(id:String):
	if selected in states:states[selected]={"cooldown":cooldown,"level":level}
	selected=id
	if id not in states:states[id]={"cooldown":0.0,"level":{"cooldown":0.0,"power":0.0,"utility":0.0}}
	cooldown=states[id].cooldown;level=states[id].level
func tick(delta):
	if cooldown>0 and cooldown<=delta:Game.sound("ability_ready",arena)
	if cloak_time>0 and cloak_time<=delta:Game.sound("cloak",arena)
	if shield_time>0 and shield_time<=delta:Game.sound("shield_break",arena)
	cooldown=maxf(0,cooldown-delta)
	for id in states:
		if id!=selected:states[id].cooldown=maxf(0,states[id].cooldown-delta)
	cloak_time=maxf(0,cloak_time-delta)
	shield_time=maxf(0,shield_time-delta)
func shield_interval()->float:return AbilityCatalog.DATA.shield.cooldown
func block_hit()->bool:return shield_time>0
func shield_duration()->float:return minf(8.0,power()+level.utility*.5)
func cast_slot(index:int)->bool:
	if index<0 or index>=slots.size():return false
	select(slots[index]);return cast()
func interval() -> float:
	return maxf(Balance.CONFIG.combat.minimum_ability_cooldown,AbilityCatalog.DATA.get(selected,AbilityCatalog.DATA.barrier).cooldown*arena.run.ability_cooldown_multiplier*pow(Balance.CONFIG.combat.ability_cooldown_multiplier,level.cooldown)*(.9-Game.class_specialization()*.01 if Game.selected_class=="engineer" else 1.0))
func power() -> float:return AbilityCatalog.DATA.get(selected,AbilityCatalog.DATA.barrier).power*arena.run.ability_power_multiplier*(1+level.power*Balance.CONFIG.combat.ability_power_step)
func barrier_count() -> int:return mini(4,1+int(level.utility))
func laser_walls() -> int:return mini(4,1+int(level.utility))
func radius() -> float:return Balance.CONFIG.combat.grenade_radius+minf(1.0,level.utility*.25)
func upgrade(id: String,tier: int):
	if id not in level:return
	arena.run.upgrade_history.append({"id":selected,"detail":{"cooldown":"Перезарядка","power":"Мощность","utility":"Эффективность"}.get(id,id),"tier":tier})
	level[id]+=[1.0,1.5,2.0][mini(tier,2)]
func description(id: String,tier: int) -> String:
	var n=[1.0,1.5,2.0][mini(tier,2)]
	if id=="cooldown":return "Кулдаун %.1f → %.1f с" % [interval(),maxf(5,interval()*pow(Balance.CONFIG.combat.ability_cooldown_multiplier,n))]
	if id=="power":return "Сила / HP / длительность %.1f → %.1f" % [power(),power()+AbilityCatalog.DATA[selected].power*Balance.CONFIG.combat.ability_power_step*n]
	return {"barrier":"Лимит блоков %d → %d" % [barrier_count(),mini(4,barrier_count()+int(n))],"grenade":"Радиус +0,25 клетки; запал короче","laser":"Пробивает ещё один бетон (до 4)","gas":"Больше площадь облака","ally_drone":"Лимит помощников +1 (до 3)","mine":"Дальность креста и лимит мин +1","airstrike":"Больше залпов; уровень 3 — ракеты","cloak":"Дольше невидимость; уровень 3 — пули насквозь","comrade":"Быстрее высадка и движение товарища","shield":"Неуязвимость +0,5 с (до 8 с)"}.get(selected,"")
func cast() -> bool:
	return actions.execute(self)

func active_seconds(id:String)->float:
	if id=="shield":return shield_time
	if id=="cloak":return cloak_time
	if id in ["gas","airstrike"] and is_instance_valid(arena):
		var remaining=0.0
		for effect in arena.get_children():
			if effect.get_script()==preload("res://scripts/ability_effect.gd") and effect.kind==id:remaining=maxf(remaining,(effect.power if id=="gas" else 6+effect.utility)-effect.age)
		return remaining
	return 0.0
