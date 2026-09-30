extends RefCounted
static func build(parent:Control):
	var panel=UiKit.panel(parent,Vector2.ZERO,Vector2(700,236),Color("242d27"))
	UiKit.label(panel,"Оформление и освещение",Vector2(16,10),Vector2(665,32),21)
	var art=TextureRect.new();panel.add_child(art);art.position=Vector2(16,52);art.size=Vector2(174,174);art.texture=preload("res://assets/ui/illustrations/day-night.tres");art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;art.mouse_filter=Control.MOUSE_FILTER_IGNORE
	UiKit.label(panel,"Тема интерфейса",Vector2(210,54),Vector2(440,25),17)
	option(panel,Vector2(210,82),"ui_theme",["Тёмная","Светлая"],["dark","light"])
	UiKit.label(panel,"Время суток в игре",Vector2(210,132),Vector2(440,25),17)
	option(panel,Vector2(210,160),"world_lighting",["День","Ночь"],["day","night"])
	UiKit.label(panel,"Настройки независимы · слева ночь, справа день",Vector2(210,205),Vector2(470,22),12,UiKit.MUTED)
static func option(parent:Control,pos:Vector2,key:String,labels:Array,values:Array):
	var item=OptionButton.new();parent.add_child(item);item.position=pos;item.size=Vector2(466,38)
	item.set_meta("setting_key",key);item.set_meta("setting_values",values)
	for label in labels:item.add_item(label)
	item.select(values.find(Settings.values[key]));item.item_selected.connect(func(index):Settings.change(key,values[index]))
