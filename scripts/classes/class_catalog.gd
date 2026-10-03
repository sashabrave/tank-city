class_name ClassCatalog
extends RefCounted
## Playable classes: role, favourite card family, start modifiers (same format as card modifiers, applied
## to the run at start) and how the class opens. Stрелок is there from the start, three open through play,
## Инженер only after the first boss. CONCEPTS are sketches for later: shown in «Казарма» as «В разработке».
const ROSTER=["recruit","heavy","gunner","marksman","engineer"]
const INFO={
	"recruit":{"role":"Универсал · крит","family":"fire","modifiers":[{"stat":"crit_chance","op":"add","value":.05}],"unlock":{}},
	"heavy":{"role":"Штурм · живучесть","family":"survival","modifiers":[{"stat":"soldier_max_hp","op":"add_round","value":1.0},{"stat":"soldier_hp","op":"add_round","value":1.0},{"stat":"guard_bullet","op":"add","value":.10}],
		"unlock":{"event":"armor","goal":25,"text":"Уничтожь 25 единиц техники"}},
	"gunner":{"role":"Подрыв · спецбоеприпасы","family":"ammo","modifiers":[{"stat":"burn_power","op":"add","value":.25},{"stat":"guard_blast","op":"add","value":.15}],
		"unlock":{"event":"barrel_kills","goal":10,"text":"Подорви бочками 10 врагов"}},
	"marksman":{"role":"Разведка · засада","family":"recon","modifiers":[{"stat":"stealth","op":"add","value":.12},{"stat":"crit_damage","op":"add","value":.25}],
		"unlock":{"event":"challenge_any","goal":3,"text":"Пройди 3 испытания"}},
	"engineer":{"role":"Тыл · техника и дроны","family":"logistics","modifiers":[{"stat":"field_repair","op":"add","value":.3},{"stat":"marauder","op":"add","value":.10}],
		"unlock":{"boss":true,"text":"Победи босса мира"}},
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
## Class path (0.8.0, author): levels 1–20. A level costs alloy on a geometric ladder (Game.class_upgrade_cost),
## so the first levels of any class are cheap and the second slot (level 8) comes near the world 1 general.
## No abilities at the very start (author): the first one (Q) at 3, the second ability and second slot at 8,
## the third at 14, a secret one at 20 (in development); the perk at 5, a stronger Q at 10, mastery at 12.
## Every other level is a class upgrade «в разработке». Each level grows health and the class stats (GROWTH).
const MAX_LEVEL=20
const ABILITY_LEVELS=[3,8,14,20]
const TRACK={3:["ability","Первая способность · слот Q"],5:["perk","Перк класса"],8:["ability","Вторая способность · второй слот"],10:["power","Q сильнее"],12:["mastery","Мастерство"],14:["ability","Третья способность"],20:["secret","Секретная способность"]}
## Abilities of a class in unlock order; the fourth (level 20) is a secret still in development.
static func abilities(id:String)->Array:return [Game.CLASS_SKILLS.get(id,"grenade")]+Game.CLASS_CHOICES.get(id,[])
static func ability_level(id:String,ability:String)->int:
	var i=abilities(id).find(ability);return ABILITY_LEVELS[i] if i>=0 else 99
static func unlocked_abilities(id:String)->Array:
	return abilities(id).filter(func(a):return level(id)>=ability_level(id,a))
static func slot_count(id:String)->int:return 2 if level(id)>=ABILITY_LEVELS[1] else 1 if level(id)>=ABILITY_LEVELS[0] else 0
## Growth per level after the first (author, 0.8.0): health for everyone (Штурмовик more) plus the class's own
## stats, same fields as run cards. Shown on the class page and on every row of the class path.
const HP_PER_LEVEL={"heavy":.5}
const GROWTH={
	"recruit":[["crit_chance",.004,"шанс крита"],["crit_damage",.02,"крит-урон"]],
	"heavy":[["guard_bullet",.006,"защита от пуль"]],
	"gunner":[["burn_power",.02,"сила поджога"],["guard_blast",.005,"защита от взрывов"]],
	"marksman":[["crit_damage",.025,"крит-урон"],["stealth",.004,"скрытность"]],
	"engineer":[["field_repair",.02,"полевой ремонт"],["dodge",.003,"уклонение"]]}
static func hp_per_level(id:String)->float:return float(HP_PER_LEVEL.get(id,.3))
## Growth reached at the class's current level: [[field, total, title], …].
static func growth(id:String)->Array:
	var steps=level(id)-1
	return GROWTH.get(id,[]).map(func(g):return [g[0],float(g[1])*steps,g[2]])
## «+0,3 здоровья · +0,4% шанс крита · …» for one level.
static func growth_line(id:String)->String:
	var parts=["+%s здоровья" % UiKit.number(hp_per_level(id))]
	for g in GROWTH.get(id,[]):parts.append("+%s%% %s" % [UiKit.number(float(g[1])*100),g[2]])
	return " · ".join(parts)
static func track_title(at:int)->String:return str(TRACK[at][1]) if TRACK.has(at) else "Улучшение класса · в разработке"
const PERKS={
	"recruit":[["Шанс крита +5%",[{"stat":"crit_chance","op":"add","value":.05}]],["Урон крита +25%",[{"stat":"crit_damage","op":"add","value":.25}]]],
	"heavy":[["Дробовик ×1,1 урона",[]],["Здоровье +2",[{"stat":"soldier_max_hp","op":"add_round","value":2.0},{"stat":"soldier_hp","op":"add_round","value":2.0}]]],
	"gunner":[["Поджог +25%",[{"stat":"burn_power","op":"add","value":.25}]],["Защита от взрывов +15%",[{"stat":"guard_blast","op":"add","value":.15}]]],
	"marksman":[["Снайперская винтовка ×1,15 урона",[]],["Скрытность +8%",[{"stat":"stealth","op":"add","value":.08}]]],
	"engineer":[["Перезарядка способностей −10%",[{"stat":"ability_cooldown_multiplier","op":"scale","value":-.1}]],["Полевой ремонт +30%",[{"stat":"field_repair","op":"add","value":.3}]]],
}
## « · вторая способность» for a level that opens a track milestone, otherwise empty.
static func milestone_suffix(at:int)->String:
	if not TRACK.has(at):return ""
	var text=Texts.render(TRACK[at][1])
	return " · "+(text if text.begins_with("Q") else text.left(1).to_lower()+text.substr(1))
## Displayed class level 1–20 (stored levels count upgrades bought, from 0).
static func level(id:String)->int:return clampi(1+int(Game.class_levels.get(id,0)),1,MAX_LEVEL)
## n: 0 — the level 5 perk, 1 — the level 12 mastery line.
static func perk_on(id:String,n:int)->bool:return level(id)>=(5 if n==0 else 12)
static func perk_lines(id:String)->Array:
	var result=[]
	var perks=PERKS.get(id,[])
	for n in range(perks.size()):result.append(("Ур. 5 · перк: %s" if n==0 else "Ур. 12 · мастерство: %s") % perks[n][0]+("" if perk_on(id,n) else " (закрыто)"))
	return result
static func apply_start(run):
	for modifier in info(Game.selected_class).modifiers:RunUpgrades.apply_modifier(run,modifier,1.0)
	for g in growth(Game.selected_class):RunUpgrades.apply_modifier(run,{"stat":g[0],"op":"add","value":g[1]},1.0)
	var perks=PERKS.get(Game.selected_class,[])
	for n in range(perks.size()):
		if perk_on(Game.selected_class,n):
			for modifier in perks[n][1]:RunUpgrades.apply_modifier(run,modifier,1.0)
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
