extends RefCounted
## «Боец» (always available): shells and their abilities, general upgrades, field supply, backpack and rerolls.
const GENERAL=[["health","Здоровье","+2 HP за уровень"],["damage","Сила","+5% базового урона за уровень"],["mobility","Скорость","Прирост уменьшается с каждым уровнем"],["pressure","Напор","Шанс, что твой снаряд переживёт столкновение"]]
const SUPPLY=[["heal","Сила лечения","heart"],["supplies","Аптечки в передышках","heart"],["luck","Частота дропа","alloy"],["rarity","Удача улучшений","star"]]
func title()->String:return "Боец"
func subtitle()->String:return "Оболочки, способности и общие улучшения — действуют в каждой вылазке."
func tabs()->Array:return [["shells","Оболочки","fighter"],["general","Общие улучшения","health"],["supply","Снабжение","heart"],["kit","Снаряжение","inventory"]]
func items(tab:String)->Array:
	var result=[]
	match tab:
		"shells":
			for id in Game.CLASSES:
				var owned=id in Game.class_unlocks
				result.append({"id":id,"title":Game.CLASSES[id].name,"icon":id,"texture":preload("res://scripts/ui/class_gallery.gd").texture(id,true),"caption":"Надета" if id==Game.selected_class else "ур. %d / 10" % int(Game.class_levels.get(id,0)) if owned else price_text(id),"state":"active" if id==Game.selected_class else "owned" if owned else "ready" if Game.can_select_class(id) else "locked"})
		"general":
			for row in GENERAL:result.append({"id":row[0],"title":row[1],"icon":row[0] if row[0]!="mobility" else "speed","caption":"ур. %d" % Game.level(row[0]),"state":"owned"})
		"supply":
			for row in SUPPLY:
				var unlocked=Game.branch_unlocked(row[0])
				result.append({"id":row[0],"title":row[1],"icon":row[2],"caption":"ур. %d / %d" % [Game.level(row[0]),Game.upgrade_cap(row[0])] if unlocked else "Открыть · %d ◈" % Game.UNLOCK_COSTS[row[0]],"state":"owned" if unlocked else "ready"})
		"kit":
			result.append({"id":"backpack","title":"Рюкзак","icon":"inventory","caption":"%d / 6 ячеек" % Game.backpack_slots,"state":"max" if Game.backpack_slots>=6 else "owned"})
			result.append({"id":"reroll","title":"Перебросы","icon":"reroll","caption":"+%d за забег" % Game.reroll_level if "reroll" in Game.research_unlocks else "Нужен чертёж","state":"locked" if "reroll" not in Game.research_unlocks else "owned"})
	return result
func price_text(id:String)->String:return ("%d ◈" if id in ["gunner","driver"] else "%d док.") % Game.class_price(id)
func detail(tab:String,id:String)->Dictionary:
	match tab:
		"shells":
			var owned=id in Game.class_unlocks;var level=int(Game.class_levels.get(id,0))
			var now=CombatStats.shell_preview(Game.selected_class);var then=CombatStats.shell_preview(id)
			var first=Game.CLASS_SKILLS[id];var second=Game.CLASS_SECOND[id]
			var actions=[]
			if id!=Game.selected_class:actions.append({"id":"equip","text":"Надеть" if owned else "Купить и надеть · "+price_text(id),"enabled":Game.can_select_class(id),"primary":true})
			if owned and id not in Game.class_first_slots:actions.append({"id":"first","text":"%s · 30 ◈" % AbilityCatalog.DATA[first].name,"enabled":Game.credits>=30})
			if owned and id in Game.class_first_slots and id not in Game.class_second_slots:actions.append({"id":"second","text":"%s · 2500 ◈" % AbilityCatalog.DATA[second].name if level>=5 else "Вторая способность · ур. 5","enabled":level>=5 and Game.credits>=2500})
			if owned:actions.append({"id":"level","text":"Максимум" if level>=10 else "Уровень %d · %d док." % [level+1,Game.class_upgrade_cost(id,false)],"enabled":level<10 and Game.cores>=Game.class_upgrade_cost(id,false)})
			return {"title":Game.CLASSES[id].name,"icon":id,"texture":preload("res://scripts/ui/class_gallery.gd").texture(id),"text":Game.CLASSES[id].desc,"rows":[["Здоровье",UiKit.number(now.health),UiKit.number(then.health)],["Урон",UiKit.number(now.damage),UiKit.number(then.damage)],["Скорость",UiKit.number(now.speed),UiKit.number(then.speed)],["Напор",UiKit.number(now.pressure)+"%",UiKit.number(then.pressure)+"%"]],
				"lines":["Q · %s%s" % [AbilityCatalog.DATA[first].name," ✓" if id in Game.class_first_slots else ""],"1 · %s%s" % [AbilityCatalog.DATA[second].name," ✓" if id in Game.class_second_slots else ""]],"actions":actions}
		"general":
			var row=GENERAL.filter(func(r):return r[0]==id)[0]
			return {"title":row[1],"icon":id if id!="mobility" else "speed","text":row[2]+". Действует во всех оболочках; бесплатный сброс возвращает всё вложенное.","rows":[["Уровень",Game.level(id),Game.level(id)+1]],"actions":[{"id":"buy","text":"Улучшить · %d ◈" % Game.cost(id),"enabled":Game.credits>=Game.cost(id),"primary":true},{"id":"reset","text":"Сбросить · вернуть %d ◈" % Game.shell_refund(),"enabled":Game.shell_refund()>0}]}
		"supply":
			var row=SUPPLY.filter(func(r):return r[0]==id)[0];var unlocked=Game.branch_unlocked(id);var level=Game.level(id);var cap=Game.upgrade_cap(id)
			var action={"id":"buy","text":("Максимум" if level>=cap else "Улучшить · %d ◈" % Game.cost(id)) if unlocked else "Открыть · %d ◈" % Game.UNLOCK_COSTS[id],"enabled":(level<cap and Game.credits>=Game.cost(id)) if unlocked else Game.credits>=Game.UNLOCK_COSTS[id],"primary":true}
			return {"title":row[1],"icon":row[2],"text":supply_text(id),"rows":[["Уровень",level,mini(level+1,cap)]],"actions":[action]}
		"kit":
			if id=="backpack":return {"title":"Рюкзак","icon":"inventory","text":"Сколько чертежей можно нести из вылазки.","rows":[["Ячейки",Game.backpack_slots,mini(Game.backpack_slots+1,6)]],"actions":[{"id":"buy","text":"Максимум" if Game.backpack_slots>=6 else "Ячейка · %d ◈" % Game.bag_cost(),"enabled":Game.backpack_slots<6 and Game.credits>=Game.bag_cost(),"primary":true}]}
			var known="reroll" in Game.research_unlocks
			return {"title":"Перебросы","icon":"reroll","text":"Дополнительные перебросы карт на каждый забег." if known else "Нужен чертёж перебросов.","rows":[["За забег",3+Game.reroll_level,3+mini(Game.reroll_level+1,5)]],"actions":[{"id":"buy","text":"Максимум" if Game.reroll_level>=5 else "+1 · %d ◈" % Game.reroll_cost(),"enabled":known and Game.reroll_level<5 and Game.credits>=Game.reroll_cost(),"primary":true}]}
	return {}
func supply_text(id:String)->String:
	match id:
		"heal":return "Сердце %.2f · броня %.2f; +0,15 за уровень." % [Game.heal_amount(),3+Game.heal_level*.15]
		"supplies":return "%d аптечек у механика и на передышках." % Game.camp_level
		"luck":return "Сердце %.1f%% · бонус %.1f%% с врага." % [Game.heart_chance()*100,Game.bonus_chance()*100]
		"rarity":return "Больше редких и эпических наград в сервисах."
	return ""
func act(tab:String,id:String,action:String)->String:
	match [tab,action]:
		["shells","equip"]:return "Оболочка надета" if Game.select_class(id) else ""
		["shells","first"]:return "Первая способность открыта · Q" if Game.buy_first_class_skill(id) else ""
		["shells","second"]:return "Вторая способность открыта · 1" if Game.buy_class_slot(id) else ""
		["shells","level"]:return "Оболочка улучшена" if Game.upgrade_class(id,false) else ""
		["general","buy"]:return "Улучшено для всех оболочек" if Game.purchase(id) else ""
		["general","reset"]:Game.reset_shell();return "Общие улучшения сброшены"
		["supply","buy"]:return "Улучшено" if (Game.purchase(id) if Game.branch_unlocked(id) else Game.unlock_branch(id)) else ""
		["kit","buy"]:return "Готово" if (Game.upgrade_backpack() if id=="backpack" else Game.upgrade_rerolls()) else ""
	return ""
