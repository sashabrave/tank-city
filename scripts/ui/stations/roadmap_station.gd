extends RefCounted
## «Развитие заставы»: the meta goal at a glance. Each tab is a track; steps are done, the next goal
## (one per track, highlighted) or later; every step says where it is done. A reached step pays alloy, claimed in its detail.
## A step: [id, title, done(bool), hint]. Adding a goal is adding a row to steps().
func title()->String:return "Развитие заставы"
func subtitle()->String:return "Что уже сделано и куда идти дальше"
func tabs()->Array:return [["story","Поход","quests"],["ladder","Испытания","rare"],["base","Застава","build"],["army","Армия","fighter"],["arsenal","Арсенал","damage"]]
func counter(key:String)->int:return int(Game.progression.counters.get(key,0))
## Alloy for reaching a step (T-148, 0.8.0), claimed by hand in the detail panel. Trophies and a collectibles
## cabinet are planned on top of this later (board).
const REWARDS={"depth1":40,"depth3":80,"depth5":150,"general1":400,"endless":300,"general2":500,"general3":800,
	"w1_1":150,"w1_2":250,"w1_3":400,"maze":150,"hard":200,
	"weapons":60,"headquarters":80,"garage":100,"range":100,"all_built":250,
	"class2":100,"class_all":400,"buggy":120,"apc":200,"tank":300,
	"second_weapon":60,"tune":60,"half":150,"all":400}
func reward(id:String)->int:return int(REWARDS.get(id,0))
func claimed(id:String)->bool:return "roadmap_reward:"+id in Game.progression.seen
## A tab is lit while a reached step on it still has its reward waiting (T-164).
func tab_dot(tab:String)->bool:return steps(tab).any(func(s):return s[2] and reward(str(s[0]))>0 and not claimed(str(s[0])))
## Reached steps whose alloy is still waiting.
func unclaimed()->Array:
	var result=[]
	for tab in tabs():
		for step in steps(tab[0]):
			if step[2] and reward(str(step[0]))>0 and not claimed(str(step[0])):result.append(step[0])
	return result
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
			["general2","Мир 2",2 in p.cleared_worlds,"Открывается после мира 1. Новые биомы и враги." if Campaign.in_demo(2) else "В полной версии игры: новые биомы и враги."],
			["general3","Гигабосс",3 in p.cleared_worlds,"Мир 3 и его гигабосс — вершина похода." if Campaign.in_demo(3) else "В полной версии игры: мир 3 и его гигабосс."]]
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
			["range","Полигон","range" in Game.built_workshops,"Стройка во дворе: нужны Площадка и чертёж Полигона."],
			["all_built","Все постройки",["weapons","headquarters","garage","range"].all(func(id):return id in Game.built_workshops),"Арсенал, Штаб, Стоянка и Полигон стоят в хабе."]]
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
			var all=Game.LOOT.gun_ids();var owned=all.filter(func(id):return id in Game.weapon_unlocks).size()
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
		var gift=reward(str(step[0]))
		var caption={"done":"Готово","goal":"Следующая цель","later":"Позже"}[status]
		if gift>0 and status=="done" and not claimed(str(step[0])):caption+=" · награда ждёт"
		var item={"id":step[0],"title":step[1],"icon":icon,"caption":caption,"status":status,"reward":gift,"claimable":status=="done" and gift>0 and not claimed(str(step[0]))}
		# Drawn step art (assets/ui/roadmap/<step id>.png) when present.
		var art="res://assets/ui/roadmap/%s.png" % step[0]
		if ResourceLoader.exists(art):item["texture"]=load(art)
		result.append(item)
	return result
func detail(tab:String,id:String)->Dictionary:
	for item in items(tab):
		if item.id!=id:continue
		var step=steps(tab).filter(func(s):return s[0]==id)[0]
		var gift=reward(id);var actions=[]
		if step[2] and gift>0 and not claimed(id):actions.append({"id":"claim","text":"Забрать %d ◈" % gift,"enabled":true,"primary":true})
		# Words, not ◈: the coin icon overlay misplaced itself in wrapped detail text.
		var tail="" if gift<=0 else (" Награда получена: %d сплава." % gift if step[2] and claimed(id) else " Награда: %d сплава." % gift)
		return {"title":step[1],"icon":item.icon,"text":("Готово. " if step[2] else "")+step[3]+tail,"actions":actions}
	return {"title":"","text":"","actions":[]}
func act(tab:String,id:String,action:String)->String:
	if action!="claim" or claimed(id) or reward(id)<=0:return ""
	if not steps(tab).any(func(s):return str(s[0])==id and s[2]):return ""
	Game.progression.seen.append("roadmap_reward:"+id);Game.earn(reward(id))
	return "Получено %d ◈" % reward(id)
## The station screen draws these steps as a vertical path (T-124).
func path_layout()->bool:return true
