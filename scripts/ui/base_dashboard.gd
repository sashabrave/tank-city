extends RefCounted

## Compact development summary for the command centre: what is built and collected, and the next goals.
static func render(tablet):
	var p=Game.progression
	var scroll=ScrollContainer.new();tablet.content.add_child(scroll);scroll.position=Vector2(22,16);scroll.size=Vector2(731,550);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	var body=VBoxContainer.new();scroll.add_child(body);body.name="Summary";body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",10)
	UiKit.label(body,"Сводка",Vector2.ZERO,Vector2(0,40),25)
	var stations=[["Казарма",true],["Арсенал","weapons" in Game.built_workshops],["Штаб","headquarters" in Game.built_workshops],["Стоянка","garage" in Game.built_workshops]]
	var rows=[
		["base","Станции","  ·  ".join(stations.map(func(s):return ("✓ " if s[1] else "🔒 ")+s[0]))],
		["comrade","Классы","%d / %d" % [Game.class_unlocks.size(),Game.CLASSES.size()]],
		["rifle","Оружие","%d / %d" % [Game.weapon_unlocks.size(),Game.LOOT.WEAPONS.size()]],
		["vehicle","Техника","%d / %d" % [Game.garage.owned.size(),GarageCatalog.VEHICLES.size()]],
		["blueprint","Бонусы и гаджеты","Бонусы: %d · гаджеты: %d" % [Game.bonus_unlocks.size(),Game.ability_unlocks.size()]],
		["alloy","Сохранение добычи","%d%% сплава при выбывании" % roundi((1.0-Game.death_loss_fraction())*100)],
		["recipe","Задания","%d сдано · %d в работе" % [p.claimed.size(),p.quests("active").size()]],
	]
	for row in rows:
		var line=Panel.new();body.add_child(line);line.custom_minimum_size=Vector2(0,58);line.add_theme_stylebox_override("panel",UiKit.style(Color("2c352e"),8))
		# Coloured artwork for every row (line icons only where no art exists, tinted to the text colour).
		var picture=UiKit.icon(line,row[0],Vector2(10,9),Vector2(40,40))
		if picture.texture and picture.texture.resource_path.ends_with(".svg"):picture.modulate=UiKit.INK
		UiKit.label(line,row[1],Vector2(58,6),Vector2(300,24),17);UiKit.label(line,row[2],Vector2(58,30),Vector2(640,24),14,UiKit.MUTED)
	var tracked=p.quests("tracked")
	if not tracked.is_empty():
		UiKit.label(body,"Отслеживаемые задания",Vector2.ZERO,Vector2(0,32),19)
		for q in tracked.slice(0,3):UiKit.label(body,"•  %s — %d / %d" % [q.text,p.count(q),q.goal],Vector2.ZERO,Vector2(0,26),15)
	UiKit.button(body,"К заданиям",Vector2.ZERO,Vector2(0,44),func():tablet.tab="quests";tablet.refresh(),true).custom_minimum_size=Vector2(0,44)
	UiKit.reveal_list(body)
