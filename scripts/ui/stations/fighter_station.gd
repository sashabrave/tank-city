extends RefCounted
## «Казарма» (always available): classes and their abilities, general upgrades,
## field supply, backpack and rerolls. Class levels follow the class path (ClassCatalog.PATHS).
## [id, title, short card text]. The numbers live in the card rows (T-254), not in the text.
const GENERAL=[["health","Здоровье","Больше здоровья у всех классов"],["damage","Сила","Сильнее оружие и лапы у всех классов"],["mobility","Скорость","Быстрее бег; каждый уровень даёт чуть меньше"],["pressure","Напор","Шанс, что твой снаряд переживёт столкновение"]]
const SUPPLY=[["heal","Сила лечения","upgrade/heal"],["supplies","Аптечки в передышках","upgrade/supplies"],["luck","Удача","upgrade/luck"]]
func title()->String:return "Казарма"
func subtitle()->String:return "Классы, улучшения, снабжение — на все вылазки."
## Main tabs run along the top; «Классы» keeps its own class list on the left (T-220).
func tabs_on_top()->bool:return true
func tabs()->Array:return [["shells","Классы","fighter"],["general","Улучшения","health"],["supply","Снабжение","heart"],["kit","Рюкзак","inventory"]]
## «Классы» is one page of its own (scripts/ui/class_page.gd); the other tabs use cards + detail.
func page_for(tab:String)->Control:return preload("res://scripts/ui/class_page.gd").new() if tab=="shells" else null
func items(tab:String)->Array:
	var result=[]
	match tab:
		"shells":
			for id in ClassCatalog.ROSTER:
				var owned=id in Game.class_unlocks
				var caption="Выбран" if id==Game.selected_class else "ур. %d / 20" % ClassCatalog.level(id) if owned else "Можно открыть" if Game.can_select_class(id) else "%d / %d" % ClassCatalog.progress(id)
				result.append({"id":id,"title":Game.CLASSES[id].name,"icon":id,"group":"Классы","texture":preload("res://scripts/ui/class_gallery.gd").texture(id,true),"caption":caption,"state":"active" if id==Game.selected_class else "owned" if owned else "ready" if Game.can_select_class(id) else "locked"})
			for i in range(ClassCatalog.CONCEPTS.size()):
				var concept=ClassCatalog.CONCEPTS[i]
				result.append({"id":"concept_%d" % i,"title":concept[0],"icon":"fighter","group":"В разработке","caption":concept[1],"state":"locked"})
		"general":
			for row in GENERAL:result.append({"id":row[0],"title":row[1],"icon":"upgrade/"+row[0],"caption":"ур. %d" % Game.level(row[0]),"state":"owned"})
		"supply":
			for row in SUPPLY:
				var unlocked=Game.branch_unlocked(row[0])
				result.append({"id":row[0],"title":row[1],"icon":row[2],"caption":"ур. %d / %d" % [Game.level(row[0]),Game.upgrade_cap(row[0])] if unlocked else "Открыть · %d ◈" % Game.UNLOCK_COSTS[row[0]],"state":"owned" if unlocked else "ready","level":Game.level(row[0]) if unlocked else 0,"cap":Game.upgrade_cap(row[0])})
		"kit":
			result.append({"id":"backpack","title":"Рюкзак","icon":"inventory","caption":"%d / %d ячеек" % [Backpack.capacity(),Backpack.CELLS],"state":"max" if Game.backpack_slots>=Backpack.MAX_BOUGHT else "owned","level":Game.backpack_slots,"cap":Backpack.MAX_BOUGHT})
			result.append({"id":"reroll","title":"Перебросы","icon":"reroll","caption":"+%d за забег" % Game.reroll_level if "reroll" in Game.research_unlocks else "Нужен чертёж","state":"locked" if "reroll" not in Game.research_unlocks else "owned","level":Game.reroll_level,"cap":5})
	return result
func detail(tab:String,id:String)->Dictionary:
	match tab:
		"shells":
			if id.begins_with("concept_"):
				var concept=ClassCatalog.CONCEPTS[int(id.trim_prefix("concept_"))]
				return {"title":concept[0],"icon":"fighter","text":"«%s». В разработке." % concept[1],"lines":[concept[2],concept[3]],"actions":[]}
			# The «Классы» tab is drawn by scripts/ui/class_page.gd; this summary only feeds notices and old callers.
			var owned=id in Game.class_unlocks;var level=ClassCatalog.level(id)
			var actions=[]
			if id!=Game.selected_class:actions.append({"id":"equip","text":"Выбрать" if owned else "Открыть и выбрать","enabled":Game.can_select_class(id),"primary":true})
			if owned:actions.append({"id":"level","text":"Максимум" if level>=ClassCatalog.MAX_LEVEL else "Уровень %d · %d ◈" % [level+1,Game.class_upgrade_cost(id,false)],"enabled":level<ClassCatalog.MAX_LEVEL and Game.credits>=Game.class_upgrade_cost(id,false)})
			return {"title":Game.CLASSES[id].name,"icon":id,"text":"%s. %s" % [ClassCatalog.info(id).role,Game.CLASSES[id].desc],"lines":ClassCatalog.perk_lines(id),"actions":actions}
		"general":
			var row=GENERAL.filter(func(r):return r[0]==id)[0]
			# Milestone (author, 4 Oct 2026): every MILESTONE_EVERY levels of a branch — +1 card reroll per sortie.
			var next_mark=(Game.level(id)/Game.MILESTONE_EVERY+1)*Game.MILESTONE_EVERY
			var milestone=Texts.render("Каждые %d уровней — +1 переброс карточек на вылазку. Следующая веха — ур. %d") % [Game.MILESTONE_EVERY,next_mark]
			return {"title":row[1],"icon":"upgrade/"+id,"text":Texts.render(row[2])+". "+milestone+".","rows":[["Уровень",Game.level(id),Game.level(id)+1],general_row(id,Game.level(id),Game.level(id)+1)],"actions":[{"id":"buy","text":"Улучшить · %d ◈" % Game.cost(id),"enabled":Game.credits>=Game.cost(id),"primary":true},{"id":"reset","text":"Сбросить · вернуть %d ◈" % Game.shell_refund(),"enabled":Game.shell_refund()>0}]}
		"supply":
			var row=SUPPLY.filter(func(r):return r[0]==id)[0];var unlocked=Game.branch_unlocked(id);var level=Game.level(id);var cap=Game.upgrade_cap(id)
			var action={"id":"buy","text":("Максимум" if level>=cap else "Улучшить · %d ◈" % Game.cost(id)) if unlocked else "Открыть · %d ◈" % Game.UNLOCK_COSTS[id],"enabled":(level<cap and Game.credits>=Game.cost(id)) if unlocked else Game.credits>=Game.UNLOCK_COSTS[id],"primary":true}
			return {"title":row[1],"icon":row[2],"text":supply_text(id),"rows":[["Уровень",level,mini(level+1,cap)]]+supply_rows(id,level,mini(level+1,cap)),"actions":[action]}
		"kit":
			if id=="backpack":return {"title":"Рюкзак","icon":"inventory","text":"Больше места для добычи в вылазке.","rows":[["Уровень",Game.backpack_slots,mini(Game.backpack_slots+1,Backpack.MAX_BOUGHT)],["Ячейки",Backpack.capacity(),mini(Backpack.capacity()+1,Backpack.CELLS)]],"actions":[{"id":"buy","text":"Максимум" if Game.backpack_slots>=Backpack.MAX_BOUGHT else "Ячейка · %d ◈" % Game.bag_cost(),"enabled":Game.backpack_slots<Backpack.MAX_BOUGHT and Game.credits>=Game.bag_cost(),"primary":true}]}
			var known="reroll" in Game.research_unlocks
			return {"title":"Перебросы","icon":"reroll","text":"Можно переиграть выбор карточек в забеге." if known else "Нужен чертёж.","rows":[["Уровень",Game.reroll_level,mini(Game.reroll_level+1,5)],["За забег",3+Game.reroll_level,3+mini(Game.reroll_level+1,5)]],"actions":[{"id":"buy","text":"Максимум" if Game.reroll_level>=5 else "+1 · %d ◈" % Game.reroll_cost(),"enabled":known and Game.reroll_level<5 and Game.credits>=Game.reroll_cost(),"primary":true}]}
	return {}
func supply_text(id:String)->String:
	match id:
		"heal":return "Сильнее лечат сердца и ремонт брони."
		"supplies":return "Аптечки у механика и на передышках."
		"luck":return "Чаще редкие карточки и награды, больше дропа, чуть выше крит."
	return ""
## The parameter a general upgrade improves at levels a → b (card rows, T-254).
static func general_row(id:String,a:int,b:int)->Array:
	match id:
		"health":return ["Здоровье","+%d HP" % (a*Game.HEALTH_PER_LEVEL),"+%d HP" % (b*Game.HEALTH_PER_LEVEL)]
		"damage":return ["Урон","+%d%%" % roundi(a*Game.DAMAGE_PER_LEVEL*100),"+%d%%" % roundi(b*Game.DAMAGE_PER_LEVEL*100)]
		"mobility":return ["Скорость","+"+UiKit.number(snappedf(35.0*a/(70.0+a),.1))+"%","+"+UiKit.number(snappedf(35.0*b/(70.0+b),.1))+"%"]
		"pressure":return ["Напор","+"+UiKit.number(snappedf(20.0*a/(20.0+a),.1))+"%","+"+UiKit.number(snappedf(20.0*b/(20.0+b),.1))+"%"]
	return []
static func supply_rows(id:String,a:int,b:int)->Array:
	var e=Balance.CONFIG.economy
	match id:
		"heal":return [["Сердце",UiKit.number(snappedf(e.heal_amount+a*e.heal_per_level,.01)),UiKit.number(snappedf(e.heal_amount+b*e.heal_per_level,.01))],["Броня",UiKit.number(snappedf(3+a*.15,.01)),UiKit.number(snappedf(3+b*.15,.01))]]
		"supplies":return [["Аптечки",str(a),str(b)]]
		"luck":
			var extra=Game.heart_chance()-(e.heart_chance+Game.luck_level*e.luck_per_level)
			return [["Шанс сердца",UiKit.number(snappedf((e.heart_chance+a*e.luck_per_level+extra)*100,.1))+"%",UiKit.number(snappedf((e.heart_chance+b*e.luck_per_level+extra)*100,.1))+"%"]]
	return []
func act(tab:String,id:String,action:String)->String:
	match [tab,action]:
		["shells","equip"]:return "Класс выбран" if Game.select_class(id) else ""
		["shells","level"]:return "Класс улучшен" if Game.upgrade_class(id,false) else ""
		["general","buy"]:return "Улучшено для всех классов" if Game.purchase(id) else ""
		["general","reset"]:Game.reset_shell();return "Общие улучшения сброшены"
		["supply","buy"]:return "Улучшено" if (Game.purchase(id) if Game.branch_unlocked(id) else Game.unlock_branch(id)) else ""
		["kit","buy"]:return "Готово" if (Game.upgrade_backpack() if id=="backpack" else Game.upgrade_rerolls()) else ""
	return ""
