class_name ClassCatalog
extends RefCounted
## Playable classes: role, favourite card family, start modifiers (same format as card modifiers, applied
## to the run at start) and how the class opens. Stрелок is there from the start, three open through play,
## Инженер only after the first boss. CONCEPTS are sketches for later: shown in «Казарма» as «В разработке».
const ROSTER=["recruit","heavy","gunner","marksman","engineer"]
const INFO={
	"recruit":{"role":"Универсал · крит","family":"fire","modifiers":[{"stat":"crit_chance","op":"add","value":.05}],"unlock":{}},
	"heavy":{"role":"Штурм · живучесть","family":"survival","modifiers":[{"stat":"soldier_max_hp","op":"add_round","value":1.0},{"stat":"soldier_hp","op":"add_round","value":1.0},{"stat":"guard_bullet","op":"add","value":.10}],
		"unlock":{"event":"field_reached","goal":3,"text":"Дойди до поля 3 в вылазке"}},
	"gunner":{"role":"Подрыв · спецбоеприпасы","family":"ammo","modifiers":[{"stat":"burn_power","op":"add","value":.25},{"stat":"guard_blast","op":"add","value":.15}],
		"unlock":{"event":"barrel_kills","goal":10,"text":"Подорви бочками 10 врагов"}},
	"marksman":{"role":"Разведка · засада","family":"recon","modifiers":[{"stat":"stealth","op":"add","value":.12},{"stat":"crit_damage","op":"add","value":.25}],
		"unlock":{"event":"challenge_any","goal":3,"text":"Пройди 3 испытания"}},
	"engineer":{"role":"Тыл · техника и дроны","family":"logistics","modifiers":[{"stat":"field_repair","op":"add","value":.3},{"stat":"marauder","op":"add","value":.10}],
		"unlock":{"event":"field_reached","goal":5,"text":"Дойди до поля 5 в вылазке"}},
}
## Sketches, not balanced: two words, numbers and the abilities they would get.
const CONCEPTS=[
	["Медик","Полевой хирург","HP +1 · лечение +30%","Q Аптечка-дрон · 1 Реанимация"],
	["Связист","Корректировщик огня","Дальность +15%","Q Артналёт · 1 Радиоперехват"],
	["Огнемётчик","Жаркий денёк","Поджог +25% · дальность −30%","Q Огнемёт · 1 Горячая лужа"],
	["Пулемётчик","Шквал огня","Темп +25% · скорость −10%","Q Сошки · 1 Шквал из миски"],
	["Мышелов","Верная мышь","Маскировка +10%","Q Мышь-разведчик · 1 Команда «Кусь»"],
	["Минёр","Тихий сапёр","Защита от взрывов +20%","Q Растяжка · 1 Разминирование"],
	["Десантник","С неба в бой","Уклонение +10% · скорость +10%","Q Прыжок через стену · 1 Сигнальный дым"],
	["Охотник","Одна пуля","Крит +15% · темп −30%","Q Прицельный выстрел · 1 Ложная позиция"],
]
## Barracks blurb under the doll (author, 0.8.0): two sentences of backstory in the cozy-trench tone, then
## what the class is good and bad at in play. [story, strengths, weaknesses].
const BIO={
	"recruit":["Пришёл на заставу за пайком, а остался за компанию. Стреляет так, будто от этого зависит обед — и обычно зависит.","Метко бьёт и часто критует, граната выручает в любой каше.","Без брони и фокусов: в окружении долго не продержится."],
	"heavy":["Бывший грузчик полевой кухни: носил котлы, теперь носит щит. Говорит мало, стоит долго.","Держит пули и удар, дробовик в упор — его разговор.","Медленный, а вдали от врагов почти бесполезен."],
	"gunner":["Считает, что любой спор решается бочкой. Пока ни разу не проиграл — ни спор, ни бочку.","Взрывы, поджог, толпы врагов разом; не боится собственных подрывов.","Против одиночной цели и техники без бочек рядом — так себе."],
	"marksman":["Сидел в кустах так долго, что его оформили как куст. Видит всё, а его — никто.","Первый выстрел из засады и снайперская винтовка решают бой до его начала.","Хрупкий: в лоб и на ближней дистанции быстро сдаётся."],
	"engineer":["Чинит всё, что сломали, и немного то, что ещё работало. Дрон собрал из чайника — летает.","Техника и дроны служат дольше, полевой ремонт и быстрые способности.","Сам по себе стреляет средне: сила в том, что рядом."]}
static func info(id:String)->Dictionary:return INFO.get(id,INFO.recruit)
static func progress(id:String)->Array:
	var unlock=info(id).unlock
	if unlock.is_empty():return [1,1]
	if unlock.get("boss",false):return [mini(1,Game.progression.boss_classes.size()),1]
	return [mini(int(unlock.goal),int(Game.progression.counters.get(unlock.event,0))),int(unlock.goal)]
static func goal_met(id:String)->bool:var p=progress(id);return p[0]>=p[1]
static func unlock_text(id:String)->String:
	var unlock=info(id).unlock;var p=progress(id)
	return "" if unlock.is_empty() else "%s · %d / %d" % [unlock.text,p[0],p[1]]
## Class path (author, 4 Oct 2026; guides/01_design/10_abilities_proposal.md): levels 1–20 on a geometric alloy
## ladder (Game.class_upgrade_cost). ONE ability slot, Q: the class ability at 3; at 8 the second class ability opens
## and the player picks which one sits on Q (free in the Barracks); at 14 the third joins the choice (Q
## modifications come later). Every level after the first grows health and one of the class's own stats; levels
## 4, 10 and 18 are a «рывок» — one stat by a big step. Perks at 5, 11, 16, 20 are permanent class passives.
const MAX_LEVEL=20
const ABILITY_LEVELS=[3,8,14]
const PERK_LEVELS=[5,11,16,20]
const BURST_LEVELS=[4,10,18]
## Stats a class path can grow. field: the RunState field; op: how the run gets it (add / rate: faster fire through
## fire_multiplier / cap: speed with its cap); unit: the value of the matching run card — the power budget of a
## path is counted in these «card units» (tests/class_path.gd keeps it near the old 0.8.0 totals).
const STATS={
	"health":{"title":"здоровье","chip":"здоровья","icon":"health"},
	"crit_chance":{"field":"crit_chance","title":"шанс крита","unit":.07,"icon":"stats/crit_chance"},
	"crit_damage":{"field":"crit_damage","title":"крит-урон","unit":.3,"icon":"stats/crit_damage"},
	"fire_rate":{"field":"fire_multiplier","op":"rate","title":"темп огня","unit":.15,"icon":"upgrades/fire"},
	"range":{"field":"range_multiplier","title":"дальность","unit":.12,"icon":"upgrades/range"},
	"guard_bullet":{"field":"guard_bullet","title":"защита от пуль","unit":.12,"icon":"stats/guard_bullet"},
	"guard_blast":{"field":"guard_blast","title":"защита от взрывов","unit":.15,"icon":"stats/guard_blast"},
	"close_damage":{"field":"close_damage","title":"урон вблизи","unit":.18,"icon":"shotgun"},
	"speed":{"field":"speed_multiplier","op":"cap","title":"скорость","unit":.04,"icon":"upgrades/speed"},
	"field_repair":{"field":"field_repair","title":"полевой ремонт","unit":.25,"icon":"stats/field_repair"},
	"dodge":{"field":"dodge","title":"уклонение","unit":.08,"icon":"stats/dodge"},
	"q_cooldown":{"field":"class_cooldown","title":"перезарядка Q","unit":.1,"minus":true,"icon":"upgrades/device_cooldown"},
	"vehicle_armor":{"field":"vehicle_armor","title":"броня техники","unit":.15,"icon":"vehicle"},
	"burn_power":{"field":"burn_power","title":"жар","unit":.5,"icon":"stats/burn_power"},
	"ability_power":{"field":"ability_power_multiplier","title":"сила способностей","unit":.15,"icon":"upgrades/device_power"},
	"stealth":{"field":"stealth","title":"скрытность","unit":.1,"icon":"stats/stealth"},
}
## One path per class. stats: the five stats (health first); step: the usual growth of each; order: which stat the
## ordinary levels raise, in turn; bursts: level → [stat, amount]; perks: levels 5, 11, 16, 20. A perk that reuses a
## run card names it in «card» (its modifiers or behaviour switch become permanent; the card then never drops for
## this class); a new one names its RunEffect script; «excludes» keeps a same-named card out of the class's runs.
## Подрывник and Разведчик are out of the demo: their paths are drafts built from existing cards.
const PATHS={
	"recruit":{"motto":"ловит момент","stats":["health","crit_chance","crit_damage","fire_rate","range"],
		"step":{"crit_chance":.01,"crit_damage":.05,"fire_rate":.025,"range":.02},"order":["crit_chance","crit_damage","fire_rate","range"],
		"bursts":{4:["crit_damage",.15],10:["crit_chance",.03],18:["fire_rate",.075]},
		"perks":[
			{"level":5,"id":"opening_shot","title":"Выдержка","text":"После 1,5 с без стрельбы следующий выстрел +40% урона.","card":"opening_shot"},
			{"level":11,"id":"sharp_eye","title":"Глаз-алмаз","text":"Каждый 5-й выстрел — гарантированный крит.","effect":"res://scripts/classes/perks/sharp_eye.gd","icon":"upgrades/crit_chance"},
			{"level":16,"id":"courage","title":"Кураж","text":"Убийство критом: темп огня +15% на 3 с.","effect":"res://scripts/classes/perks/courage.gd","icon":"upgrades/legend_fury"},
			{"level":20,"id":"last_line","title":"Последний рубеж","text":"При здоровье 25% и ниже все выстрелы критуют.","effect":"res://scripts/classes/perks/last_line.gd","excludes":["last_stand"],"icon":"upgrades/last_stand"}]},
	"heavy":{"motto":"принимает удар","stats":["health","guard_bullet","guard_blast","close_damage","speed"],
		"step":{"guard_bullet":.015,"guard_blast":.015,"close_damage":.03,"speed":.005},"order":["guard_bullet","close_damage","guard_blast","speed"],
		"bursts":{4:["guard_bullet",.05],10:["close_damage",.1],18:["guard_blast",.05]},
		"perks":[
			{"level":5,"id":"guard_bullet","title":"Бронежилет","text":"Защита от пуль +12%.","card":"guard_bullet"},
			{"level":11,"id":"fortress","title":"Крепость","text":"Защита от пуль, взрывов и техники +12%.","card":"fortress"},
			{"level":16,"id":"recoil","title":"Отдача","text":"Попадание по бойцу оглушает пехоту в 1,5 клетки на 1 с. Раз в 4 с.","effect":"res://scripts/classes/perks/recoil.gd","icon":"upgrades/crit_stun"},
			{"level":20,"id":"legend_second_wind","title":"Второе дыхание","text":"Раз за поле смертельный удар оставляет 1 здоровья и 2 с неуязвимости.","card":"legend_second_wind"}]},
	"engineer":{"motto":"держит технику в строю","stats":["health","field_repair","dodge","q_cooldown","vehicle_armor"],
		"step":{"field_repair":.04,"dodge":.008,"q_cooldown":.02,"vehicle_armor":.03},"order":["field_repair","q_cooldown","dodge","vehicle_armor"],
		"bursts":{4:["field_repair",.12],10:["q_cooldown",.06],18:["vehicle_armor",.09]},
		"perks":[
			{"level":5,"id":"field_repair","title":"Ремонт на ходу","text":"Каждое убийство чинит штаб и твою технику: полевой ремонт +25%.","card":"field_repair"},
			{"level":11,"id":"marauder","title":"Запасливый","text":"Больше сплава и жетонов с врагов: +20%.","card":"marauder"},
			{"level":16,"id":"boarding","title":"Абордаж","text":"Захваченная машина сразу чинится полностью, её выстрелы +30%.","card":"boarding"},
			{"level":20,"id":"legend_field_workshop","title":"Мастерская на колёсах","text":"Техника чинит 1 брони каждые 3 с.","card":"legend_field_workshop"}]},
	"gunner":{"motto":"площадь","draft":true,"stats":["health","burn_power","guard_blast","ability_power","range"],
		"step":{"burn_power":.04,"guard_blast":.01,"ability_power":.02,"range":.02},"order":["burn_power","ability_power","guard_blast","range"],
		"bursts":{4:["burn_power",.12],10:["ability_power",.06],18:["guard_blast",.04]},
		"perks":[
			{"level":5,"id":"burn_heat","title":"Жар","text":"Горение жжёт сильнее: жар +50%.","card":"burn_heat"},
			{"level":11,"id":"chain_fire","title":"Цепная реакция","text":"Горящие враги поджигают соседей, а погибая, вспыхивают.","card":"chain_fire"},
			{"level":16,"id":"guard_blast","title":"Сапёрный костюм","text":"Защита от взрывов +15%.","card":"guard_blast"},
			{"level":20,"id":"legend_detonator","title":"Детонатор","text":"Убитые враги взрываются: 1,5 урона соседям рядом.","card":"legend_detonator"}]},
	"marksman":{"motto":"засада","draft":true,"stats":["health","crit_damage","stealth","range","crit_chance"],
		"step":{"crit_damage":.05,"stealth":.015,"range":.02,"crit_chance":.01},"order":["crit_damage","stealth","range","crit_chance"],
		"bursts":{4:["stealth",.045],10:["crit_damage",.15],18:["range",.06]},
		"perks":[
			{"level":5,"id":"stealth","title":"Маскхалат","text":"Враги замечают ближе; первый удар по целому врагу сильнее: скрытность +10%.","card":"stealth"},
			{"level":11,"id":"exit_dash","title":"Смена позиции","text":"После выхода из машины: +25% скорости на 3 с. Откат 8 с.","card":"exit_dash"},
			{"level":16,"id":"ghost","title":"Призрак","text":"Уклонение и скрытность +10%.","card":"ghost"},
			{"level":20,"id":"legend_ricochet","title":"Шальная пуля","text":"Каждое третье попадание отскакивает в ближайшего врага: 60% урона.","card":"legend_ricochet"}]},
}
static func path(id:String)->Dictionary:return PATHS.get(id,PATHS.recruit)
static func motto(id:String)->String:return str(path(id).motto)
static func draft(id:String)->bool:return bool(path(id).get("draft",false))
## Abilities of a class in unlock order: [Q, opens at 8, opens at 14].
static func abilities(id:String)->Array:return [Game.CLASS_SKILLS.get(id,"grenade")]+Game.CLASS_CHOICES.get(id,[])
static func ability_level(id:String,ability:String)->int:
	var i=abilities(id).find(ability);return ABILITY_LEVELS[i] if i>=0 and i<ABILITY_LEVELS.size() else 99
static func unlocked_abilities(id:String)->Array:
	return abilities(id).filter(func(a):return level(id)>=ability_level(id,a))
## One slot (Q) from level 3, none before.
static func slot_count(id:String)->int:return 1 if level(id)>=ABILITY_LEVELS[0] else 0
## Health per level stays as in 0.8.0: +0.3, Штурмовик +0.5.
const HP_PER_LEVEL={"heavy":.5}
static func hp_per_level(id:String)->float:return float(HP_PER_LEVEL.get(id,.3))
static func burst(id:String,n:int)->bool:return path(id).bursts.has(n)
## What level n adds: {stat: amount}, health included; level 1 is the start and adds nothing.
static func level_gain(id:String,n:int)->Dictionary:
	if n<2 or n>MAX_LEVEL:return {}
	var p=path(id);var gain={"health":hp_per_level(id)}
	if p.bursts.has(n):gain[p.bursts[n][0]]=float(p.bursts[n][1]);return gain
	# Ordinary levels take the stats in turn, skipping the bursts.
	var k=0
	for at in range(2,n):
		if not p.bursts.has(at):k+=1
	var stat=str(p.order[k%p.order.size()]);gain[stat]=float(p.step[stat])
	return gain
## Sum of the growth from level 2 up to `upto` (the current level by default): {stat: total}.
static func totals(id:String,upto:int=-1)->Dictionary:
	if upto<0:upto=level(id)
	var result={}
	for stat in path(id).stats:result[stat]=0.0
	for n in range(2,upto+1):
		var gain=level_gain(id,n)
		for stat in gain:result[stat]=float(result.get(stat,0.0))+float(gain[stat])
	return result
## Growth reached at the class's current level, as [[stat, total, title], …] without health.
static func growth(id:String)->Array:
	var t=totals(id);var result=[]
	for stat in path(id).stats:
		if stat!="health":result.append([stat,float(t[stat]),str(STATS[stat].title)])
	return result
## The path's power in run-card units (health left out: it grows as before).
static func power_units(id:String,upto:int=MAX_LEVEL)->float:
	var t=totals(id,upto);var sum=0.0
	for stat in t:
		if stat!="health":sum+=float(t[stat])/float(STATS[stat].unit)
	return sum
## «+0,5% шанс крита», «+0,3 здоровья», «−2% перезарядка Q».
static func stat_chip(stat:String,amount:float)->String:
	var def=STATS[stat]
	if stat=="health":return "+%s %s" % [UiKit.number(snappedf(amount,.01)),def.chip]
	return "%s%s%% %s" % ["−" if def.get("minus",false) else "+",UiKit.number(snappedf(amount*100,.1)),def.title]
## Stat value as a number with its unit, for «сейчас → к 20» («5,7», «12%»).
static func stat_amount(stat:String,amount:float)->String:
	if stat=="health":return "+"+UiKit.number(snappedf(amount,.1))
	return ("−" if STATS[stat].get("minus",false) else "+")+UiKit.number(snappedf(amount*100,.1))+"%"
static func stat_title(stat:String)->String:var t=str(STATS[stat].title);return t.left(1).to_upper()+t.substr(1)
## Level n's growth in one line: «+0,3 здоровья · +1% шанс крита»; a burst leads with its stat.
static func level_line(id:String,n:int)->String:
	var gain=level_gain(id,n);var parts=[]
	for stat in gain:
		if stat!="health":parts.append(stat_chip(stat,gain[stat]))
	if gain.has("health"):parts.append(stat_chip("health",gain.health))
	return ("Рывок · " if burst(id,n) else "")+" · ".join(parts)
## Kept for older callers: the growth of an ordinary level.
static func growth_line(id:String)->String:return level_line(id,2)
## The four perks of a class.
static func perks(id:String)->Array:return path(id).perks
static func perk_at(id:String,n:int)->Dictionary:
	for perk in perks(id):
		if int(perk.level)==n:return perk
	return {}
static func perk_on(id:String,index:int)->bool:
	var list=perks(id);return index>=0 and index<list.size() and level(id)>=int(list[index].level)
static func unlocked_perks(id:String)->Array:return perks(id).filter(func(p):return level(id)>=int(p.level))
static func perk_icon(perk:Dictionary)->String:
	if perk.has("icon"):return str(perk.icon)
	return "upgrades/"+str(perk.get("card",perk.id))
## A milestone of level n: {kind: "ability"|"perk"|"", title, text, icon}.
static func milestone(id:String,n:int)->Dictionary:
	var index=ABILITY_LEVELS.find(n)
	if index>=0:
		var list=abilities(id)
		if index>=list.size():return {}
		var info=AbilityCatalog.DATA.get(list[index],{});var name=str(info.get("name",list[index]))
		var title=["Способность Q · %s","Выбор для Q · %s","Выбор для Q · %s"][index] % name
		var text=str(info.get("description",""))
		if index==1:text="Открывается вторая способность класса. На Q ставишь любую из открытых, менять — в Казарме."
		elif index==2:text="Третья способность тоже встаёт на Q на выбор. Модификация Q — позже."
		return {"kind":"ability","title":title,"text":text,"icon":"abilities/"+str(list[index]),"ability":list[index]}
	var perk=perk_at(id,n)
	if not perk.is_empty():return {"kind":"perk","title":"Перк · "+str(perk.title),"text":str(perk.text),"icon":perk_icon(perk),"perk":perk.id}
	return {}
static func track_title(at:int,id:String="recruit")->String:
	var m=milestone(id,at);return str(m.title) if not m.is_empty() else level_line(id,at)
## Displayed class level 1–20 (stored levels count upgrades bought, from 0).
static func level(id:String)->int:return clampi(1+int(Game.class_levels.get(id,0)),1,MAX_LEVEL)
## Dossier lines: «Ур. 5 · Выдержка: …», «(закрыто)» until reached.
static func perk_lines(id:String)->Array:
	var result=[]
	for perk in perks(id):result.append("Ур. %d · %s: %s" % [int(perk.level),perk.title,perk.text]+("" if level(id)>=int(perk.level) else " (закрыто)"))
	return result
## Run cards that never drop for the selected class: the cards its unlocked perks already give for good.
static func excluded_cards(id:String)->Array:
	var result=[]
	for perk in unlocked_perks(id):
		if perk.has("card"):result.append(str(perk.card))
		for other in perk.get("excludes",[]):result.append(str(other))
	return result
## RunEffect scripts of the unlocked new perks (scripts/classes/perks), read by RunEffects.
static func perk_effects(id:String)->Array:
	var result=[]
	for perk in unlocked_perks(id):
		if perk.has("effect"):result.append([str(perk.id),load(str(perk.effect))])
	return result
## Behaviour switches (flag or effect cards) of the unlocked perks; idempotent, also after a checkpoint restore.
static func add_perk_cards(run,id:String=""):
	if id=="":id=Game.selected_class
	for perk in unlocked_perks(id):
		var def=UpgradeRegistry.get_def(str(perk.get("card","")))
		if def!=null and (def.flag or def.effect!=null) and def.id not in run.behavior_cards:run.behavior_cards.append(def.id)
## Turns one stat total into run modifiers.
static func stat_modifiers(stat:String,total:float)->Array:
	var def=STATS.get(stat,{})
	if not def.has("field") or is_zero_approx(total):return []
	match str(def.get("op","add")):
		"rate":return [{"stat":def.field,"op":"scale","value":1.0/(1.0+total)-1.0}]
		"cap":return [{"stat":def.field,"op":"add","value":total,"cap":"speed_multiplier_cap"}]
	return [{"stat":def.field,"op":"add","value":total}]
static func apply_start(run):
	var id=Game.selected_class
	for modifier in info(id).modifiers:RunUpgrades.apply_modifier(run,modifier,1.0)
	var t=totals(id)
	for stat in t:
		for modifier in stat_modifiers(stat,float(t[stat])):RunUpgrades.apply_modifier(run,modifier,1.0)
	# Perks that reuse a card: its modifiers at the base rarity, its behaviour switch for good.
	for perk in unlocked_perks(id):
		var def=UpgradeRegistry.get_def(str(perk.get("card","")))
		if def==null:continue
		for modifier in def.modifiers:RunUpgrades.apply_modifier(run,modifier,Balance.tier_power(0))
	add_perk_cards(run,id)
	run.soldier_hp=minf(run.soldier_hp,run.soldier_max_hp)
## Start bonuses as dossier lines, formatted by the stat registry ("Шанс крита +5%").
static func modifier_lines(id:String)->Array:
	var result=[]
	for modifier in info(id).modifiers:
		var def=StatRegistry.all().filter(func(d):return d.run_field==modifier.stat)
		if def.is_empty():continue
		var amount=float(modifier.value)
		result.append("%s +%s" % [def[0].title,StatRegistry.text(def[0],amount) if def[0].format!="multiplier" else UiKit.number(amount)])
	return result
