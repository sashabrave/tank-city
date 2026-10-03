extends RefCounted

## Development summary for the command centre (T-038): big icons with progress bars for what is built and
## collected, then the lifetime record of the profile (time played, sorties, enemies by type, events).
## What the summary showed last time (this session): grown numbers animate in green on the next visit (T-190).
static var seen:={}
static func render(tablet):
	var p=Game.progression
	var scroll=ScrollContainer.new();tablet.content.add_child(scroll);scroll.position=Vector2(22,16);scroll.size=Vector2(731,550);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	var body=VBoxContainer.new();scroll.add_child(body);body.name="Summary";body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",14)
	UiKit.label(body,"Сводка",Vector2.ZERO,Vector2(0,40),25)
	var built=["weapons","headquarters","garage","range"].filter(func(id):return id in Game.built_workshops).size()+1
	var progress=[
		["base","Станции",built,5],
		["fighter","Классы",Game.class_unlocks.size(),ClassCatalog.ROSTER.size()],
		["rifle","Оружие",Game.weapon_unlocks.size(),Game.LOOT.gun_ids().size()],
		["vehicle","Техника",Game.garage.owned.size(),GarageCatalog.VEHICLES.size()],
		["blueprint","Бонусы",Game.bonus_unlocks.size(),Game.LOOT.BONUSES.size()],
		["quests","Задания сданы",p.claimed.size(),preload("res://scripts/progression/quest_catalog.gd").STORY.size()+preload("res://scripts/progression/quest_catalog.gd").INSTITUTE.size()+preload("res://scripts/progression/quest_catalog.gd").BRIEFINGS.size()],
	]
	var grid=GridContainer.new();grid.columns=2;body.add_child(grid);grid.add_theme_constant_override("h_separation",12);grid.add_theme_constant_override("v_separation",12)
	for row in progress:
		var card=Panel.new();grid.add_child(card);card.custom_minimum_size=Vector2(353,86);card.add_theme_stylebox_override("panel",UiKit.style(Color("2c352e"),10))
		var picture=UiKit.icon(card,row[0],Vector2(12,13),Vector2(60,60))
		if picture.texture and picture.texture.resource_path.ends_with(".svg"):picture.modulate=UiKit.INK
		UiKit.label(card,row[1],Vector2(86,10),Vector2(180,26),18)
		var value=UiKit.label(card,"%d / %d" % [row[2],row[3]],Vector2(250,10),Vector2(90,26),18);value.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		var track=ColorRect.new();card.add_child(track);track.position=Vector2(86,50);track.size=Vector2(254,10);track.color=Color(1,1,1,.08)
		var share=func(n):return 254*clampf(float(n)/maxf(1,row[3]),0,1)
		var before=int(seen.get(row[1],row[2]));seen[row[1]]=row[2]
		var fill=ColorRect.new();track.add_child(fill);fill.size=Vector2(share.call(mini(before,row[2])),10);fill.color=UiKit.ORANGE
		if before<row[2]:
			# The new part grows in green, then settles into the bar; a «+N» tells how much.
			var gain=ColorRect.new();track.add_child(gain);gain.position.x=fill.size.x;gain.size=Vector2(0,10);gain.color=Color("8fe895");gain.name="Gain"
			var plus=UiKit.label(card,"+%d" % (row[2]-before),Vector2(196,12),Vector2(50,22),15,Color("8fe895"));plus.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;plus.name="Plus"
			grow(gain,share.call(row[2])-fill.size.x,value,before,row[2],"%d / "+str(row[3]))
	# Lifetime record.
	UiKit.label(body,"За всё время",Vector2.ZERO,Vector2(0,34),20)
	var c=func(key:String)->int:return int(p.counters.get(key,0))
	var minutes=int(float(p.counters.get("play_seconds",0.0))/60.0)
	var stats=[
		["Время в игре","%d ч %02d мин" % [minutes/60,minutes%60]],["Вылазок",str(c.call("runs"))],["Выбываний",str(c.call("deaths"))],
		["Пехоты уничтожено",str(c.call("infantry"))],["Техники уничтожено",str(c.call("armor"))],["Дронов сбито",str(c.call("drones"))],
		["Волн зачищено",str(c.call("waves"))],["Испытаний пройдено",str(c.call("challenge_any"))],["Миров пройдено",str(p.cleared_worlds.size())],
		["Врагов взорвано бочками",str(c.call("barrel_kills"))],["Игр на автомате",str(c.call("slot_play"))],["Легендарных правил",str(c.call("legend_taken"))],
	]
	var table=GridContainer.new();table.columns=3;body.add_child(table);table.add_theme_constant_override("h_separation",10);table.add_theme_constant_override("v_separation",10)
	for s in stats:
		var cell=Panel.new();table.add_child(cell);cell.custom_minimum_size=Vector2(232,64);cell.add_theme_stylebox_override("panel",UiKit.style(Color("262e28"),8))
		var number=UiKit.label(cell,s[1],Vector2(12,6),Vector2(208,30),22,UiKit.ORANGE)
		if s[1].is_valid_int():
			var was=int(seen.get(s[0],int(s[1])));seen[s[0]]=int(s[1])
			if was<int(s[1]):
				var plus=UiKit.label(cell,"+%d" % (int(s[1])-was),Vector2(120,10),Vector2(100,24),15,Color("8fe895"));plus.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;plus.name="Plus"
				grow(null,0,number,was,int(s[1]),"%d")
		UiKit.label(cell,s[0],Vector2(12,36),Vector2(208,22),13,UiKit.MUTED)
	var tracked=p.quests("tracked")
	if not tracked.is_empty():
		UiKit.label(body,"Отслеживаемые задания",Vector2.ZERO,Vector2(0,32),19)
		for q in tracked.slice(0,3):UiKit.label(body,"•  %s — %d / %d" % [q.text,p.count(q),q.goal],Vector2.ZERO,Vector2(0,26),15)
	UiKit.button(body,"К заданиям",Vector2.ZERO,Vector2(0,44),func():tablet.tab="quests";tablet.refresh(),true).custom_minimum_size=Vector2(0,44)
	UiKit.reveal_list(body)

## Smoothly count a label from `from` to `to` and widen the green gain bar.
static func grow(gain:Control,width:float,label:Label,from:int,to:int,format:String):
	if not UiKit.motion_enabled():
		if gain:gain.size.x=width
		return
	label.text=format % from
	var t=label.create_tween().set_parallel()
	t.tween_interval(.35)
	t.chain().tween_method(func(v:float):label.text=format % roundi(v),float(from),float(to),.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if gain:t.parallel().tween_property(gain,"size:x",width,.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		label.pivot_offset=Vector2(0,15)
		t.parallel().tween_property(label,"modulate",Color("8fe895"),.3)
		t.chain().tween_property(label,"modulate",Color.WHITE,.6)
