extends RefCounted
## «Арсенал» (weapons blueprint): weapons to take and level up, combat bonuses, gadgets.
const GADGETS=["barrier","mine","laser","airstrike"]
func title()->String:return "Арсенал"
func subtitle()->String:return "Оружие, бонусы боя и гаджеты. Открываются чертежами, развиваются сплавом."
func tabs()->Array:return [["weapons","Оружие","inventory"],["bonuses","Бонусы","heart"],["gadgets","Гаджеты","mine"]]
func items(tab:String)->Array:
	var result=[]
	match tab:
		"weapons":
			for id in Game.LOOT.WEAPONS:
				var owned=id in Game.weapon_unlocks;var level=Game.weapon_level(id)
				var state="locked" if not owned else "active" if id==Game.selected_weapon else "max" if level>=Balance.CONFIG.economy.weapon_level_cap else "owned"
				result.append({"id":id,"title":Game.LOOT.WEAPONS[id].name,"icon":Game.LOOT.WEAPONS[id].icon,"caption":"Нужен чертёж" if not owned else ("В бою · " if id==Game.selected_weapon else "")+"ур. %d / %d" % [level,Balance.CONFIG.economy.weapon_level_cap],"state":state})
		"bonuses":
			for id in Game.LOOT.BONUSES:
				var owned=id in Game.bonus_unlocks;var level=Game.bonus_level(id)
				result.append({"id":id,"title":Game.LOOT.BONUSES[id].name,"icon":id,"caption":"Нужен чертёж" if not owned else "ур. %d / %d" % [level,Balance.CONFIG.economy.bonus_level_cap],"state":"locked" if not owned else "max" if level>=Balance.CONFIG.economy.bonus_level_cap else "owned"})
		"gadgets":
			for id in GADGETS:
				var known=id in Game.ability_unlocks;var bought=id in Game.purchased_gadgets
				result.append({"id":id,"title":AbilityCatalog.DATA[id].name,"icon":id,"caption":"Нужен чертёж" if not known else "Выбран" if Game.gadget==id else "Куплен" if bought else "%d ◈" % Game.gadget_cost(id),"state":"locked" if not known else "active" if Game.gadget==id else "owned" if bought else "ready"})
	return result
func detail(tab:String,id:String)->Dictionary:
	match tab:
		"weapons":
			var info=Game.LOOT.WEAPONS[id];var owned=id in Game.weapon_unlocks;var level=Game.weapon_level(id);var cap=Balance.CONFIG.economy.weapon_level_cap
			var factor=1.0+level*.015;var next=1.0+mini(level+1,cap)*.015
			var actions=[]
			if owned and id!=Game.selected_weapon:actions.append({"id":"take","text":"Взять в бой","primary":true})
			if owned:actions.append({"id":"level","text":"Максимум" if level>=cap else "Уровень %d · %d ◈" % [level+1,Game.weapon_upgrade_cost(id)],"enabled":level<cap and Game.credits>=Game.weapon_upgrade_cost(id)})
			return {"title":info.name,"icon":info.icon,"text":info.role if owned else "Найди чертёж в вылазке и донеси до хаба.","rows":[["Уровень",level,mini(level+1,cap)],["Урон",UiKit.number(info.damage*factor),UiKit.number(info.damage*next)],["Выстрелов в с",UiKit.number(1.0/info.interval),UiKit.number(1.0/info.interval)],["Дальность",UiKit.number(info.range),UiKit.number(info.range)]],"actions":actions}
		"bonuses":
			var info=Game.LOOT.BONUSES[id];var owned=id in Game.bonus_unlocks;var level=Game.bonus_level(id);var cap=Balance.CONFIG.economy.bonus_level_cap
			return {"title":info.name,"icon":id,"text":info.effect if owned else "Найди чертёж бонуса в сундуке.","rows":[["Уровень",level,mini(level+1,cap)],["Сила","×"+UiKit.number(Game.bonus_power(id)),"×"+UiKit.number(1.0+mini(level+1,cap)*.1)]],"actions":[{"id":"level","text":"Максимум" if level>=cap else "Улучшить · %d ◈" % Game.bonus_cost(id),"enabled":owned and level<cap and Game.credits>=Game.bonus_cost(id),"primary":true}] if owned else []}
		"gadgets":
			var info=AbilityCatalog.DATA[id];var known=id in Game.ability_unlocks;var bought=id in Game.purchased_gadgets
			var text="Выбрать" if bought else "Купить и выбрать · %d ◈" % Game.gadget_cost(id)
			return {"title":info.name,"icon":id,"text":info.description if known else "Чертёж гаджета выпадает в вылазках.","lines":["Клавиша F в бою"],"actions":[{"id":"equip","text":"Выбран" if Game.gadget==id else text,"enabled":Game.gadget!=id and (bought or Game.credits>=Game.gadget_cost(id)),"primary":true}] if known else []}
	return {}
func act(tab:String,id:String,action:String)->String:
	match [tab,action]:
		["weapons","take"]:return "Оружие взято в бой" if Game.equip_weapon(id) else ""
		["weapons","level"]:return "Оружие улучшено" if Game.upgrade_weapon(id) else ""
		["bonuses","level"]:return "Бонус улучшен" if Game.upgrade_bonus(id) else ""
		["gadgets","equip"]:return "Гаджет выбран" if Game.unlock_or_equip_ability(id) else ""
	return ""
