extends RefCounted
const NAMES={"field_repair":"Полевой ремонт","comrade":"Товарищ","barrier":"Противотанковый ёж","grenade":"Граната","laser":"Лазер","gas":"Газ","ally_drone":"Дрон","mine":"Мина","dynamite":"Динамит","airstrike":"Авиаудар","cloak":"Маскировка","shield":"Щит"}
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
func block_hit()->bool:return shield_time>0
func shield_duration()->float:return minf(8.0,power()+level.utility*.5)
## Key of a slot by what stands in it: the Arsenal gadget — F, any other ability — Q. The HUD tile label and the
## battle input both use it (the sandbox fills slots after the HUD is built; Game.ability_action only knew the class).
func action_for(index:int)->String:
	if index<slots.size():return "ability" if str(slots[index])==str(Game.gadget) and str(slots[index]) not in Game.class_loadout() else "class_ability"
	return Game.ability_action(index)
func cast_slot(index:int)->bool:
	if index<0 or index>=slots.size():return false
	select(slots[index])
	var ok=cast()
	# A soft, low thud when the ability is not ready (T-021); never on a successful cast.
	if not ok and is_instance_valid(arena.player) and not arena.player.dead:Game.sound("ability_denied",arena)
	return ok
func interval() -> float:
	# «Перезарядка Q» of the class path speeds up only the ability on Q, not the gadget.
	var own=1.0-minf(.5,float(arena.run.class_cooldown)) if selected in Game.class_loadout() else 1.0
	return maxf(Balance.CONFIG.combat.minimum_ability_cooldown,AbilityCatalog.DATA.get(selected,AbilityCatalog.DATA.barrier).cooldown*arena.run.ability_cooldown_multiplier*own*pow(Balance.CONFIG.combat.ability_cooldown_multiplier,level.cooldown))
func power() -> float:return AbilityCatalog.DATA.get(selected,AbilityCatalog.DATA.barrier).power*arena.run.ability_power_multiplier*(1+level.power*Balance.CONFIG.combat.ability_power_step)
func barrier_count() -> int:return mini(4,1+int(level.utility))
func laser_walls() -> int:return mini(4,1+int(level.utility))
func radius() -> float:return Balance.CONFIG.combat.grenade_radius+minf(1.0,level.utility*.25)
func upgrade(id: String,tier: int):
	if id not in level:return
	arena.run.upgrade_history.append({"id":selected,"detail":{"cooldown":"Перезарядка","power":"Мощность","utility":"Эффективность"}.get(id,id),"tier":tier})
	level[id]+=Balance.tier_power(tier)
## What «Прочность / урон» means for each ability (T-283).
const POWER_LABELS={"grenade":"Урон гранаты","laser":"Урон лазера","comrade":"Сила товарища","shield":"Неуязвимость","cloak":"Невидимость","ally_drone":"Прочность дрона","barrier":"Прочность ежа","mine":"Урон мины","gas":"Сон в облаке","dynamite":"Урон взрыва","airstrike":"Урон удара"}
const POWER_UNITS={"cloak":" с","gas":" с"}
func description(id: String,tier: int) -> String:
	var n=Balance.tier_power(tier)
	if id=="cooldown":return "Кулдаун %.1f → %.1f с" % [interval(),maxf(5,interval()*pow(Balance.CONFIG.combat.ability_cooldown_multiplier,n))]
	if id=="power":
		# The parameter this ability's power really drives (T-283), not a generic «сила / HP / длительность».
		var after=power()+AbilityCatalog.DATA[selected].power*Balance.CONFIG.combat.ability_power_step*n
		var label=POWER_LABELS.get(selected,"Сила")
		if selected=="shield":return UiKit.change_text(label,shield_duration(),minf(8.0,after+level.utility*.5)," с")
		if selected=="field_repair":return "%s %s → %s · %s %s → %s" % [Texts.render("Броня машины"),UiKit.number(snappedf(power(),.1)),UiKit.number(snappedf(after,.1)),Texts.render("здоровье пешком"),UiKit.number(snappedf(power()/3,.1)),UiKit.number(snappedf(after/3,.1))]
		return UiKit.change_text(label,snappedf(power(),.1),snappedf(after,.1),POWER_UNITS.get(selected,""))
	return {"barrier":"Лимит блоков %d → %d" % [barrier_count(),mini(4,barrier_count()+int(n))],"grenade":"Радиус +0,25 клетки; запал короче","laser":"Пробивает ещё один бетон (до 4)","gas":"Больше площадь облака","ally_drone":"Лимит помощников +1 (до 3)","mine":"Дальность креста и лимит мин +1","dynamite":"Дальность взрыва +1 клетка (до 6)","airstrike":"Больше залпов; уровень 3 — ракеты","cloak":"Дольше невидимость; уровень 3 — пули насквозь","comrade":"Быстрее высадка и движение товарища","shield":"Неуязвимость +0,5 с (до 8 с)"}.get(selected,"")
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
