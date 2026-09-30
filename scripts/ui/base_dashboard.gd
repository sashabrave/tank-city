extends RefCounted

static func next_level(level:int)->Array:
	var result=[]
	for row in [["Улучшения поддержки",mini(20,level*3),mini(20,(level+1)*3)],["Оружие",mini(10,level),mini(10,level+1)],["Модули штаба",mini(5,level),mini(5,level+1)],["Усиления и снабжение",mini(3,level),mini(3,level+1)],["Страховка сплава",mini(6,level*2),mini(6,(level+1)*2)]]:
		if row[2]>row[1]:result.append("%s: предел %d → %d" % row)
	for id in HQCatalog.DATA:
		if HQCatalog.DATA[id].base==level+1:result.append("Штаб: %s · нужен чертёж" % HQCatalog.DATA[id].name)
	if result.is_empty():result.append("Основные пределы улучшений уже открыты.")
	return result

static func render(tablet):
	var p=Game.progression
	var scroll=ScrollContainer.new();tablet.content.add_child(scroll);scroll.position=Vector2(22,16);scroll.size=Vector2(731,550);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	var body=Control.new();scroll.add_child(body);body.custom_minimum_size=Vector2(711,1000)
	UiKit.icon(body,"base",Vector2(0,4),Vector2(52,52))
	UiKit.label(body,"Развитие базы · уровень %d" % p.level,Vector2(68,0),Vector2(640,40),25)
	UiKit.label(body,"Опыт за задания открывает новые пределы улучшений",Vector2(68,43),Vector2(640,28),15,UiKit.MUTED)
	UiKit.label(body,"Опыт · %d / %d" % [p.xp,p.required_xp()],Vector2(0,88),Vector2(711,30),18)
	var bar=ProgressBar.new();body.add_child(bar);bar.position=Vector2(0,127);bar.size=Vector2(711,12);bar.max_value=p.required_xp();bar.value=p.xp;bar.show_percentage=false
	var bg=StyleBoxFlat.new();bg.bg_color=Color("414b40");bg.set_corner_radius_all(6);bar.add_theme_stylebox_override("background",bg)
	var fill=bg.duplicate();fill.bg_color=UiKit.ORANGE;bar.add_theme_stylebox_override("fill",fill)
	var missing=maxi(0,p.required_xp()-p.xp)
	UiKit.label(body,"До следующего уровня: %d опыта" % missing if missing>0 else "Опыт накоплен · можно повысить уровень",Vector2(0,158),Vector2(711,28),16,UiKit.MUTED)
	var button=UiKit.button(body,"Повысить до %d · %d ◈" % [p.level+1,p.level_cost()],Vector2(0,189),Vector2(711,44),func():p.upgrade();tablet.refresh())
	button.disabled=missing>0 or Game.credits<p.level_cost();UiKit.muted_locked_button(button)
	if Game.credits<p.level_cost():UiKit.label(body,"Не хватает %d сплава" % (p.level_cost()-Game.credits),Vector2(0,239),Vector2(711,25),14,UiKit.MUTED)
	UiKit.label(body,"На уровне %d" % (p.level+1),Vector2(0,280),Vector2(711,34),22)
	var y=326.0
	for line in next_level(p.level):
		UiKit.label(body,line,Vector2(16,y),Vector2(685,30),16,UiKit.MUTED);y+=34
	y+=20
	UiKit.label(body,"База сейчас",Vector2(0,y),Vector2(711,34),22);y+=48
	for row in [["settings","Постройки","%d / %d построено" % [Game.built_workshops.size(),Game.BUILD_COST.size()]],["alloy","Сохранение добычи","%d%% сплава при гибели · улучшение в «Прокачке базы»" % roundi((1-Game.death_loss_fraction())*100)],["heart","Снабжение","%d аптечек передышки · лечение %s HP" % [Game.camp_level,UiKit.number(Game.heal_amount())]]]:
		UiKit.icon(body,row[0],Vector2(10,y+8),Vector2(32,32));UiKit.label(body,row[1],Vector2(58,y),Vector2(640,27),18);UiKit.label(body,row[2],Vector2(58,y+30),Vector2(640,30),14,UiKit.MUTED);y+=78
	UiKit.label(body,"Штаб · выбранная поддержка",Vector2(0,y),Vector2(711,34),22);y+=48
	var loadout=Game.hq_loadout()
	if loadout.is_empty():UiKit.label(body,"Модуль не выбран. Настрой поддержку на верстаке штаба.",Vector2(0,y),Vector2(711,36),16,UiKit.MUTED);y+=44
	for id in loadout:
		if id not in HQCatalog.DATA:continue
		var info=HQCatalog.DATA[id];UiKit.icon(body,info.icon,Vector2(10,y+8),Vector2(40,40))
		UiKit.label(body,info.name,Vector2(68,y),Vector2(635,30),19)
		UiKit.label(body,HQCatalog.stat(id,int(Game.hq_levels.get(id,0))),Vector2(68,y+34),Vector2(635,34),15,UiKit.MUTED);y+=86
	UiKit.button(body,"К заданиям · получить опыт",Vector2(0,y+12),Vector2(711,42),func():tablet.tab="quests";tablet.refresh())
	body.custom_minimum_size.y=y+68
