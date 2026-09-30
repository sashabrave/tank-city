extends RefCounted
## Auto-fed encyclopedia: articles built from the registries (cards, characteristics, classes, bosses, vehicles).
## Adding a card .tres, a stat .tres or a boss variant adds its article without editing encyclopedia.json.
## Text is assembled from translatable fragments ("Семейство:", card titles, details), so English works too.
const CATEGORY="Справочник"
static var cache:Array=[]
const PREVIEW_NAMES={"hp":"Здоровье","speed":"Скорость","rate":"Темп","damage":"Урон","intercept":"Напор","range":"Дальность","healing":"Лечение","device_power":"Сила способности","device_cooldown":"Перезарядка способности"}

static func articles()->Array:
	if cache.is_empty():cache=build()
	return cache

static func refresh():cache.clear()

static func article(id:String,section:String,title:String,lines:Array,icon:String="")->Dictionary:
	var image=""
	if icon!="":
		var texture=UiKit.icon_texture(icon)
		if texture!=null and texture.resource_path!="":image=texture.resource_path
	return {"id":"auto_"+id,"category":CATEGORY,"section":section,"title":title,"text":"\n".join(lines.filter(func(line):return str(line)!="")),"image":image,"term":"","auto":true}

static func build()->Array:
	var result=[]
	for def in UpgradeRegistry.all():
		if def.weight<=0:continue
		var lines=["Семейство: "+RunUpgrades.FAMILIES.get(def.family,def.family),"Минимальная редкость: "+RunUpgrades.TIER_NAMES[clampi(def.min_tier,0,3)]]
		var changes=[]
		if def.preview!="" and PREVIEW_NAMES.has(def.preview):changes.append(PREVIEW_NAMES[def.preview])
		for modifier in def.modifiers:
			var stat=StatRegistry.all().filter(func(d):return d.run_field==str(modifier.get("stat","")))
			if not stat.is_empty() and stat[0].title not in changes:changes.append(stat[0].title)
		if not changes.is_empty():lines.append("Меняет: "+", ".join(changes).to_lower())
		if def.max_stacks>0:lines.append("Лимит в вылазке: %d" % def.max_stacks)
		if def.flag:lines.append("Меняет поведение боя: один раз за вылазку.")
		if def.detail!="":lines.append(def.detail.replace("{{","").replace("}}",""))
		result.append(article("card_"+def.id,"Карточки",def.title,lines,"upgrades/"+def.id))
	for def in StatRegistry.all():
		var lines=["Семейство: "+RunUpgrades.FAMILIES.get(def.family,def.family)]
		if def.description!="":lines.append(def.description)
		if def.cap>0:lines.append("Предел в бою: "+StatRegistry.text(def,def.cap))
		if def.step>0 and def.meta_field=="":lines.append("Станция: +%s за уровень, уровней: %d, цена от %d ◈." % [StatRegistry.text(def,def.step),def.max_level,def.cost_base])
		result.append(article("stat_"+def.id,"Характеристики",def.title,lines,"stats/"+def.id))
	for id in ClassCatalog.ROSTER:
		var data=Game.CLASSES.get(id,{});var info=ClassCatalog.info(id)
		var lines=["Роль: "+str(info.role),"Семейство карточек: "+RunUpgrades.FAMILIES.get(info.family,info.family)]
		for line in ClassCatalog.modifier_lines(id):lines.append(line)
		if not info.unlock.is_empty():lines.append("Открытие: "+str(info.unlock.text))
		result.append(article("class_"+id,"Классы",str(data.get("name",id)),lines,"fighter"))
	for concept in ClassCatalog.CONCEPTS:
		result.append(article("concept_"+str(concept[0]),"Классы",str(concept[0]),["В разработке: "+str(concept[1]),str(concept[2]),str(concept[3])]))
	for id in BossCatalog.DATA:
		var data=BossCatalog.DATA[id]
		var lines=["Корпус: %d×%d, машин: %d." % [data.footprint,data.footprint,data.count],"Атаки: "+", ".join(data.patterns.map(func(p):return {"salvo":"прицельный залп","fan":"веер","mortar":"миномёт"}.get(p,p)))]
		lines.append("Щит: четыре генератора на 80, 60, 40 и 20% здоровья." if id=="giga" else "Щит: два генератора на флангах, на 60 и 30% здоровья.")
		result.append(article("boss_"+id,"Боссы",str(data.name),lines,"star"))
	for kind in GarageCatalog.VEHICLES:
		var v=GarageCatalog.VEHICLES[kind];var tuning=Balance.CONFIG.enemy(kind)
		var armor=tuning.health*GarageCatalog.PLAYER_ARMOR.get(kind,1.0)
		var lines=["Цена: %d ◈." % v.price,"Броня: %s · урон: %s · темп: %s /с · скорость: %s" % [UiKit.number(armor),UiKit.number(tuning.damage),UiKit.number(1.0/tuning.fire_interval),UiKit.number(tuning.player_speed)]]
		if v.previous!="":lines.append("Сначала купи: "+str(GarageCatalog.VEHICLES[v.previous].name))
		lines.append("Трофейная машина врага даёт 85% этих значений.")
		result.append(article("vehicle_"+kind,"Техника",str(v.name),lines,kind))
	return result
