extends RefCounted
## «Развитие заставы»: the meta goal at a glance. Each tab is a track; steps are done, the next goal
## (one per track, highlighted) or later. Reading only — every step says where it is done.
## A step: [id, title, done(bool), hint]. Adding a goal is adding a row to steps().
func title()->String:return "Развитие заставы"
func subtitle()->String:return "Что уже сделано и куда идти дальше"
func tabs()->Array:return [["story","Поход","quests"],["ladder","Испытания","rare"],["base","Застава","build"],["army","Бойцы и техника","fighter"],["arsenal","Арсенал","damage"]]
func counter(key:String)->int:return int(Game.progression.counters.get(key,0))
## Reached goals the player has not looked at yet (T-088): the hub board lights up until the station is opened.
func unseen_done()->Array:
	var result=[]
	for tab in tabs():
		for step in steps(tab[0]):
			if step[2] and "roadmap:"+str(step[0]) not in Game.progression.seen:result.append(step[0])
	return result
func mark_seen():
	for id in unseen_done():Game.progression.seen.append("roadmap:"+str(id))
	Game.save_progress()
func steps(tab:String)->Array:
	var p=Game.progression
	match tab:
		"story":return [
			["depth1","Первое поле",counter("world_depth_1")>=1,"«В бой» → мир 1. Зачисти три волны и командира."],
			["depth3","Третье поле",counter("world_depth_1")>=3,"Пройди три поля за одну вылазку. Сервисные точки по пути помогают."],
			["depth5","Пять полей",counter("world_depth_1")>=5,"Пять полей мира 1. Захвати КП ради легендарного правила."],
			["general1","Генерал мира 1",1 in p.cleared_worlds,"Финал мира 1. Разбей генератор щита на фланге."],
			["endless","Бесконечный рубеж",counter("endless_cycle")>=2,"После генерала — рубеж: дойди до второго сектора."],
			["general2","Мир 2",2 in p.cleared_worlds,"Открывается после мира 1. Новые биомы и враги."],
			["general3","Гигабосс",3 in p.cleared_worlds,"Мир 3 и его гигабосс — вершина похода."]]
		"ladder":return [
			["w1_1","Испытание I · мир 1",counter("challenge_w1")>=1,"На карточке мира выбери I: враги опытнее, награда ×1,25."],
			["w1_2","Испытание II · мир 1",counter("challenge_w1")>=2,"Без лечения между полями, здоровье ниже. Награда ×1,5."],
			["w1_3","Испытание III · мир 1",counter("challenge_w1")>=3,"Командиры — элита, волны больше. Награда ×2."],
			["maze","Тёмный лабиринт",counter("challenge_maze")>=1,"Особая точка на карте мира 1. Дойди до зелёного флага в темноте."],
			["hard","Три испытания ★★",counter("challenge_hard")>=3,"Особые точки со звёздами ★★."]]
		"base":return [
			["weapons","Арсенал","weapons" in Game.built_workshops,"Донеси чертёж Арсенала и построй его."],
			["headquarters","Штаб","headquarters" in Game.built_workshops,"Чертёж Штаба выпадает с командиров."],
			["garage","Стоянка","garage" in Game.built_workshops,"Чертёж Стоянки — во второй половине пути."],
			["range","Полигон","range" in Game.built_workshops,"Стройка во дворе, когда откроется Стоянка."],
			["level3","Уровень базы 3",p.level>=3,"Опыт за задания поднимает уровень базы в командном центре."]]
		"army":
			var classes=ClassCatalog.ROSTER.filter(func(id):return id in Game.CLASSES)
			var opened=classes.filter(func(id):return id in Game.class_unlocks).size()
			return [
				["class2","Второй класс",opened>=2,"Казарма → Классы. Каждый класс открывается своей целью."],
				["class_all","Все классы · %d / %d" % [opened,classes.size()],opened>=classes.size(),"Открой всех бойцов в Казарме."],
				["buggy","Свой багги","buggy" in Game.garage.owned,"Чертёж багги и покупка на Стоянке."],
				["apc","Свой БТР","apc" in Game.garage.owned,"Чертёж БТР — во второй половине пути мира 1."],
				["tank","Свой танк","tank" in Game.garage.owned,"Самый редкий чертёж: сложные точки у генерала."]]
		"arsenal":
			var all=Game.LOOT.WEAPONS.keys();var owned=all.filter(func(id):return id in Game.weapon_unlocks).size()
			var tuned=p.weapon_levels.values().filter(func(v):return int(v)>=1).size()
			return [
				["second_weapon","Второе оружие",owned>=2,"Чертежи оружия носят командиры и сундуки ★."],
				["tune","Доводка оружия",tuned>=1,"Арсенал: первый уровень открытого оружия."],
				["half","Половина арсенала · %d / %d" % [owned,all.size()],owned*2>=all.size(),"Открой половину оружия."],
				["all","Весь арсенал",owned>=all.size(),"Каждое оружие — свой стиль. Смена — в Арсенале."]]
	return []
func items(tab:String)->Array:
	var result=[];var next_found=false
	var icon=tabs().filter(func(t):return t[0]==tab)[0][2]
	for step in steps(tab):
		var status="done" if step[2] else ("goal" if not next_found else "later")
		if status=="goal":next_found=true
		var item={"id":step[0],"title":step[1],"icon":icon,"caption":{"done":"Готово","goal":"Следующая цель","later":"Позже"}[status],"status":status}
		# Drawn step art (assets/ui/roadmap/<step id>.png) when present.
		var art="res://assets/ui/roadmap/%s.png" % step[0]
		if ResourceLoader.exists(art):item["texture"]=load(art)
		result.append(item)
	return result
func detail(tab:String,id:String)->Dictionary:
	for item in items(tab):
		if item.id!=id:continue
		var step=steps(tab).filter(func(s):return s[0]==id)[0]
		return {"title":step[1],"icon":item.icon,"text":("Готово. " if step[2] else "")+step[3],"actions":[]}
	return {"title":"","text":"","actions":[]}
func act(_tab:String,_id:String,_action:String)->String:return ""
