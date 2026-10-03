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
	"gunner":{"role":"Подрыв · спецпатроны","family":"ammo","modifiers":[{"stat":"burn_power","op":"add","value":.25},{"stat":"guard_blast","op":"add","value":.15}],
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
## Meta stage 4: class level milestones. 3 — second ability (Game.class_loadout), 5 — perk, 7 — Q +1 power
## (RunAbility.setup), 10 — mastery. Perks use the card modifier format; weapon multipliers that used to be
## hidden (shotgun, sniper) are part of the level 5 perk now (CombatStats.class_weapon_multiplier).
const MILESTONES=[[3,"Вторая способность"],[5,"Перк класса"],[7,"Q сильнее"],[10,"Мастерство"]]
const PERKS={
	"recruit":[["Шанс крита +5%",[{"stat":"crit_chance","op":"add","value":.05}]],["Урон крита +25%",[{"stat":"crit_damage","op":"add","value":.25}]]],
	"heavy":[["Дробовик ×1,1 урона",[]],["Здоровье +2",[{"stat":"soldier_max_hp","op":"add_round","value":2.0},{"stat":"soldier_hp","op":"add_round","value":2.0}]]],
	"gunner":[["Поджог +25%",[{"stat":"burn_power","op":"add","value":.25}]],["Защита от взрывов +15%",[{"stat":"guard_blast","op":"add","value":.15}]]],
	"marksman":[["Снайперская винтовка ×1,15 урона",[]],["Скрытность +8%",[{"stat":"stealth","op":"add","value":.08}]]],
	"engineer":[["Перезарядка способностей −10%",[{"stat":"ability_cooldown_multiplier","op":"scale","value":-.1}]],["Полевой ремонт +30%",[{"stat":"field_repair","op":"add","value":.3}]]],
}
## « · вторая способность» for a level that opens a milestone, otherwise empty.
static func milestone_suffix(at:int)->String:
	for m in MILESTONES:
		if m[0]==at:return " · "+Texts.render(m[1]).to_lower()
	return ""
static func level(id:String)->int:return clampi(int(Game.class_levels.get(id,0)),0,10)
## n: 0 — the level 5 perk, 1 — the level 10 mastery line.
static func perk_on(id:String,n:int)->bool:return level(id)>=(5 if n==0 else 10)
static func perk_lines(id:String)->Array:
	var result=[]
	var perks=PERKS.get(id,[])
	for n in range(perks.size()):result.append(("Ур. 5 · перк: %s" if n==0 else "Ур. 10 · мастерство: %s") % perks[n][0]+("" if perk_on(id,n) else " (закрыто)"))
	return result
static func apply_start(run):
	for modifier in info(Game.selected_class).modifiers:RunUpgrades.apply_modifier(run,modifier,1.0)
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
