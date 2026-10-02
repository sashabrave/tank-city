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
static func apply_start(run):
	for modifier in info(Game.selected_class).modifiers:RunUpgrades.apply_modifier(run,modifier,1.0)
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
