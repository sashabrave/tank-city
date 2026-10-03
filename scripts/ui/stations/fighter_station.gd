extends RefCounted
## «Казарма» (always available): classes and their abilities, general upgrades, the stat tree («Выучка»),
## field supply, backpack and rerolls. The stat tree is built from StatRegistry.
const GENERAL=[["health","Здоровье","+2 HP за уровень"],["damage","Сила","+5% базового урона за уровень"],["mobility","Скорость","Прирост уменьшается с каждым уровнем"],["pressure","Напор","Шанс, что твой снаряд переживёт столкновение"]]
const SUPPLY=[["heal","Сила лечения","upgrade/heal"],["supplies","Аптечки в передышках","upgrade/supplies"],["luck","Удача","upgrade/luck"]]
func title()->String:return "Казарма"
func subtitle()->String:return "Классы, выучка, снабжение — на все вылазки."
func tabs()->Array:return [["shells","Классы","fighter"],["general","Общие улучшения","health"],["training","Выучка","rare"],["supply","Снабжение","heart"],["kit","Рюкзак и перебросы","inventory"]]
func items(tab:String)->Array:
	var result=[]
	match tab:
		"shells":
			for id in ClassCatalog.ROSTER:
				var owned=id in Game.class_unlocks
				var caption="Выбран" if id==Game.selected_class else "ур. %d / 10" % int(Game.class_levels.get(id,0)) if owned else "Можно открыть" if Game.can_select_class(id) else "%d / %d" % ClassCatalog.progress(id)
				result.append({"id":id,"title":Game.CLASSES[id].name,"icon":id,"group":"Классы","texture":preload("res://scripts/ui/class_gallery.gd").texture(id,true),"caption":caption,"state":"active" if id==Game.selected_class else "owned" if owned else "ready" if Game.can_select_class(id) else "locked"})
			for i in range(ClassCatalog.CONCEPTS.size()):
				var concept=ClassCatalog.CONCEPTS[i]
				result.append({"id":"concept_%d" % i,"title":concept[0],"icon":"fighter","group":"В разработке","caption":concept[1],"state":"locked"})
		"general":
			for row in GENERAL:result.append({"id":row[0],"title":row[1],"icon":"upgrade/"+row[0],"caption":"ур. %d" % Game.level(row[0]),"state":"owned"})
		"supply":
			for row in SUPPLY:
				var unlocked=Game.branch_unlocked(row[0])
				result.append({"id":row[0],"title":row[1],"icon":row[2],"caption":"ур. %d / %d" % [Game.level(row[0]),Game.upgrade_cap(row[0])] if unlocked else "Открыть · %d ◈" % Game.UNLOCK_COSTS[row[0]],"state":"owned" if unlocked else "ready"})
		"training":
			for def in StatRegistry.all():
				if def.step<=0 or def.meta_field!="":continue
				var level=StatRegistry.level(def.id);var open=StatRegistry.unlocked(def.id)
				var state="max" if level>=def.max_level else "ready" if StatRegistry.can_buy(def.id) else "owned" if open else "locked"
				result.append({"id":def.id,"title":def.title,"icon":"stats/"+def.id,"group":RunUpgrades.FAMILIES[def.family],"caption":"ур. %d / %d" % [level,def.max_level] if open else "Нужно: %s %d" % [StatRegistry.get_def(def.requires).title,def.requires_level],"state":state})
		"kit":
			result.append({"id":"backpack","title":"Рюкзак","icon":"inventory","caption":"%d / %d ячеек" % [Backpack.capacity(),Backpack.CELLS],"state":"max" if Game.backpack_slots>=Backpack.MAX_BOUGHT else "owned"})
			result.append({"id":"reroll","title":"Перебросы","icon":"reroll","caption":"+%d за забег" % Game.reroll_level if "reroll" in Game.research_unlocks else "Нужен чертёж","state":"locked" if "reroll" not in Game.research_unlocks else "owned"})
	return result
func detail(tab:String,id:String)->Dictionary:
	match tab:
		"shells":
			if id.begins_with("concept_"):
				var concept=ClassCatalog.CONCEPTS[int(id.trim_prefix("concept_"))]
				return {"title":concept[0],"icon":"fighter","text":"«%s». Класс в разработке: цифры и способности — набросок." % concept[1],"lines":[concept[2],concept[3]],"actions":[]}
			var owned=id in Game.class_unlocks;var level=int(Game.class_levels.get(id,0))
			var now=CombatStats.shell_preview(Game.selected_class);var then=CombatStats.shell_preview(id)
			var first=Game.CLASS_SKILLS[id];var second=Game.class_second(id);var other=Game.CLASS_CHOICES[id].filter(func(a):return a!=second)[0]
			var actions=[]
			if id!=Game.selected_class:actions.append({"id":"equip","text":"Выбрать" if owned else "Открыть и выбрать" if Game.can_select_class(id) else ClassCatalog.unlock_text(id),"enabled":Game.can_select_class(id),"primary":true})
			if owned and id not in Game.class_first_slots:actions.append({"id":"first","text":"%s · 30 ◈" % AbilityCatalog.DATA[first].name,"enabled":Game.credits>=30})
			if owned and id in Game.class_first_slots and id not in Game.class_second_slots:actions.append({"id":"second","text":"%s · 2500 ◈" % AbilityCatalog.DATA[second].name if level>=5 else "Вторая способность · ур. 5","enabled":level>=5 and Game.credits>=2500})
			# Meta stage 3: slot «1» holds one of two class abilities; switching is free in the hub.
			if owned:actions.append({"id":"pick","text":"Слот 1: взять «%s»" % AbilityCatalog.DATA[other].name,"enabled":true})
			if owned:actions.append({"id":"level","text":"Максимум" if level>=10 else "Уровень %d · %d ◈" % [level+1,Game.class_upgrade_cost(id,false)],"enabled":level<10 and Game.credits>=Game.class_upgrade_cost(id,false)})
			return {"title":Game.CLASSES[id].name,"icon":id,"texture":preload("res://scripts/ui/class_gallery.gd").texture(id),"text":"%s. %s%s" % [ClassCatalog.info(id).role,Game.CLASSES[id].desc,("" if owned or ClassCatalog.unlock_text(id)=="" else "\nОткрытие: "+ClassCatalog.unlock_text(id))]+"\nЛюбимая семья карточек: "+RunUpgrades.FAMILIES[ClassCatalog.info(id).family],"rows":[["Здоровье",UiKit.number(now.health),UiKit.number(then.health)],["Урон",UiKit.number(now.damage),UiKit.number(then.damage)],["Скорость",UiKit.number(now.speed),UiKit.number(then.speed)],["Напор",UiKit.number(now.pressure)+"%",UiKit.number(then.pressure)+"%"]],
				"lines":ClassCatalog.modifier_lines(id)+["Q · %s%s" % [AbilityCatalog.DATA[first].name," ✓" if id in Game.class_first_slots else ""],"1 · %s%s (или %s)" % [AbilityCatalog.DATA[second].name," ✓" if id in Game.class_second_slots else "",AbilityCatalog.DATA[other].name]],"actions":actions}
		"general":
			var row=GENERAL.filter(func(r):return r[0]==id)[0]
			return {"title":row[1],"icon":"upgrade/"+id,"text":row[2]+". Действует во всех классах; бесплатный сброс возвращает всё вложенное.","rows":[["Уровень",Game.level(id),Game.level(id)+1]],"actions":[{"id":"buy","text":"Улучшить · %d ◈" % Game.cost(id),"enabled":Game.credits>=Game.cost(id),"primary":true},{"id":"reset","text":"Сбросить · вернуть %d ◈" % Game.shell_refund(),"enabled":Game.shell_refund()>0}]}
		"training":
			var def=StatRegistry.get_def(id);var level=StatRegistry.level(id)
			var now=StatRegistry.base_value(def);var then=now+(def.step if level<def.max_level else 0.0)
			var open=StatRegistry.unlocked(id)
			var action={"id":"buy","text":"Максимум" if level>=def.max_level else ("Улучшить · %d ◈" % StatRegistry.cost(id) if open else "Нужно: %s %d" % [StatRegistry.get_def(def.requires).title,def.requires_level]),"enabled":StatRegistry.can_buy(id),"primary":true}
			return {"title":def.title,"icon":"stats/"+def.id,"text":def.description,"rows":[["Уровень",level,mini(level+1,def.max_level)],["В начале забега",StatRegistry.text(def,now),StatRegistry.text(def,then)]],"lines":["Ветка: "+RunUpgrades.FAMILIES[def.family],"Карточки забега прибавляются сверху."],"actions":[action]}
		"supply":
			var row=SUPPLY.filter(func(r):return r[0]==id)[0];var unlocked=Game.branch_unlocked(id);var level=Game.level(id);var cap=Game.upgrade_cap(id)
			var action={"id":"buy","text":("Максимум" if level>=cap else "Улучшить · %d ◈" % Game.cost(id)) if unlocked else "Открыть · %d ◈" % Game.UNLOCK_COSTS[id],"enabled":(level<cap and Game.credits>=Game.cost(id)) if unlocked else Game.credits>=Game.UNLOCK_COSTS[id],"primary":true}
			return {"title":row[1],"icon":row[2],"text":supply_text(id),"rows":[["Уровень",level,mini(level+1,cap)]],"actions":[action]}
		"kit":
			if id=="backpack":return {"title":"Рюкзак","icon":"inventory","text":"Ячейки рюкзака для чертежей и патронов в вылазке.","rows":[["Ячейки",Backpack.capacity(),mini(Backpack.capacity()+1,Backpack.CELLS)]],"actions":[{"id":"buy","text":"Максимум" if Game.backpack_slots>=Backpack.MAX_BOUGHT else "Ячейка · %d ◈" % Game.bag_cost(),"enabled":Game.backpack_slots<Backpack.MAX_BOUGHT and Game.credits>=Game.bag_cost(),"primary":true}]}
			var known="reroll" in Game.research_unlocks
			return {"title":"Перебросы","icon":"reroll","text":"Дополнительные перебросы карт на каждый забег." if known else "Нужен чертёж перебросов.","rows":[["За забег",3+Game.reroll_level,3+mini(Game.reroll_level+1,5)]],"actions":[{"id":"buy","text":"Максимум" if Game.reroll_level>=5 else "+1 · %d ◈" % Game.reroll_cost(),"enabled":known and Game.reroll_level<5 and Game.credits>=Game.reroll_cost(),"primary":true}]}
	return {}
func supply_text(id:String)->String:
	match id:
		"heal":return "Сердце %.2f · броня %.2f; +0,15 за уровень." % [Game.heal_amount(),3+Game.heal_level*.15]
		"supplies":return "%d аптечек у механика и на передышках." % Game.camp_level
		"luck":return "Чаще редкие карточки и награды, больше дропа, чуть выше крит. Сердце %.1f%% · бонус %.1f%% с врага." % [Game.heart_chance()*100,Game.bonus_chance()*100]
	return ""
func act(tab:String,id:String,action:String)->String:
	match [tab,action]:
		["shells","equip"]:return "Класс выбран" if Game.select_class(id) else ""
		["shells","first"]:return "Первая способность открыта · Q" if Game.buy_first_class_skill(id) else ""
		["shells","second"]:return "Вторая способность открыта · 1" if Game.buy_class_slot(id) else ""
		["shells","pick"]:
			var other=Game.CLASS_CHOICES[id].filter(func(a):return a!=Game.class_second(id))[0]
			return "Слот 1 · %s" % AbilityCatalog.DATA[other].name if Game.choose_class_second(id,other) else ""
		["shells","level"]:return "Класс улучшен" if Game.upgrade_class(id,false) else ""
		["general","buy"]:return "Улучшено для всех классов" if Game.purchase(id) else ""
		["training","buy"]:return "Выучка улучшена" if StatRegistry.buy(id) else ""
		["general","reset"]:Game.reset_shell();return "Общие улучшения сброшены"
		["supply","buy"]:return "Улучшено" if (Game.purchase(id) if Game.branch_unlocked(id) else Game.unlock_branch(id)) else ""
		["kit","buy"]:return "Готово" if (Game.upgrade_backpack() if id=="backpack" else Game.upgrade_rerolls()) else ""
	return ""
