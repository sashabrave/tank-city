extends Control
signal closed
signal shell_requested
const IDS=["recruit","gunner","driver","heavy","marksman","engineer"]
const SNAPSHOT=preload("res://scripts/ui/stat_snapshot.gd")
var tab="shell"
var viewed=""
var catalog=false
var stats_open=false
var notice=""
var rebuilding=false
var body:Control
var content_width=0.0

static func texture(id:String,mini=false)->AtlasTexture:
	var index=IDS.find(id);var atlas=AtlasTexture.new();atlas.atlas=Illustrations.texture("res://assets/portraits/v16/"+("miniatures.png" if mini else "portraits.png"));var size=atlas.atlas.get_size()/Vector2(3,2)
	var cell=Rect2(Vector2(index%3,floori(index/3.0))*size,size)
	# Interface portraits are chest-up: a centred square over the helmet and chest of the full-figure art.
	if not mini:cell=Rect2(cell.position+size*Vector2(PORTRAIT_CROP.x,PORTRAIT_CROP.y),size*PORTRAIT_CROP.z)
	atlas.region=cell;return atlas
## Chest-up crop inside a portrait cell: left, top, side (fractions of the cell).
const PORTRAIT_CROP=Vector3(.17,.03,.66)
func picture(parent,id,pos,dimensions,mini=false):
	var image=TextureRect.new();parent.add_child(image);image.texture=texture(id,mini);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.position=pos;image.size=dimensions;image.mouse_filter=Control.MOUSE_FILTER_IGNORE;UiKit.locked_preview(image,id not in Game.class_unlocks)
func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_to_group("selection_scope")
	viewed=Game.selected_class
	resized.connect(schedule_refresh);Texts.changed.connect(schedule_refresh);Settings.changed.connect(schedule_refresh)
	refresh()
func schedule_refresh():
	if rebuilding:return
	rebuilding=true;call_deferred("refresh")
func label(parent,text:String,pos:Vector2,dimensions:Vector2,font_size=16,muted=false):
	var node=UiKit.label(parent,text,pos,dimensions,font_size,UiKit.MUTED if muted else UiKit.INK)
	node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;return node
func action(parent,title:String,pos:Vector2,dimensions:Vector2,callback:Callable,id:String,enabled=true,primary=false):
	var node=UiKit.button(parent,title,pos,dimensions,callback,primary);node.name=id;node.add_theme_font_size_override("font_size",16);node.disabled=not enabled
	if not enabled:UiKit.muted_locked_button(node)
	return node
func refresh():
	rebuilding=false
	if not is_inside_tree():return
	for node in get_children():remove_child(node);node.queue_free()
	var shade=ColorRect.new();add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,.5)
	var area=get_viewport_rect().size;var dimensions=Vector2(minf(1120,area.x-24),minf(740,area.y-24))
	var panel=UiKit.glass(self,(area-dimensions)*.5,dimensions);panel.name="PrinterPanel"
	label(panel,"Принтер бойца",Vector2(24,14),Vector2(dimensions.x-110,26),UiKit.PAGE_TITLE_SIZE)
	action(panel,"×",Vector2(dimensions.x-66,10),Vector2(44,36),func():closed.emit(),"Close")
	var width=(dimensions.x-60)*.5
	for i in range(2):
		var key=["shell","base"][i]
		var button=action(panel,["Класс","Общие улучшения"][i],Vector2(24+i*(width+12),52),Vector2(width,42),func():tab=key;catalog=false;viewed=Game.selected_class;notice="";refresh(),"ShellTab" if i==0 else "CommonTab")
		if tab==key:button.add_theme_stylebox_override("normal",UiKit.style(Color("584a2c"),8,UiKit.ORANGE))
	var scroll=ScrollContainer.new();scroll.name="PrinterScroll";panel.add_child(scroll);scroll.position=Vector2(24,94+UiKit.TAB_CONTENT_GAP);scroll.size=Vector2(dimensions.x-48,dimensions.y-174);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	body=Control.new();scroll.add_child(body);content_width=dimensions.x-68;body.custom_minimum_size=Vector2(content_width,0)
	var height=build_common() if tab=="base" else build_catalog() if catalog else build_shell()
	body.custom_minimum_size.y=height
	label(panel,notice,Vector2(24,dimensions.y-43),Vector2(dimensions.x-48,35),14,true)
func detail(id:String):
	viewed=id;catalog=false;stats_open=false;notice="";refresh()
func show_catalog():catalog=true;notice="";refresh()
func buy_first():
	if Game.buy_first_class_skill(viewed):notice="Способность открыта · Q — использовать" if viewed==Game.selected_class else "Способность открыта для этого класса"
	refresh()
func buy_second():
	if Game.buy_class_slot(viewed):notice="Вторая способность открыта · 1 — использовать" if viewed==Game.selected_class else "Способность открыта для этого класса"
	refresh()
func equip():
	if Game.select_class(viewed):notice="Класс выбран"
	refresh()
func upgrade():
	if Game.upgrade_class(viewed,false):notice="Улучшен только этот класс"
	refresh()
func shell_purchase_text(id:String)->String:
	if id==Game.selected_class:return "Надета"
	if id in Game.class_unlocks:return "Надеть"
	if not Campaign.unlocked(Game.class_world(id)):return "Откроется в мире %d" % Game.class_world(id)
	return "Купить и надеть · %d ◈" % Game.class_price(id)
func build_shell()->float:
	var owned=viewed in Game.class_unlocks;var level=int(Game.class_levels.get(viewed,0));var wide=content_width>=800
	var left=280.0 if wide else content_width
	picture(body,viewed,Vector2.ZERO,Vector2(left,205) if wide else Vector2(88,100))
	var y=214.0 if wide else 0.0;var x=0.0 if wide else 104.0
	label(body,Game.CLASSES[viewed].name,Vector2(x,y),Vector2(left-x,40),27)
	label(body,("Надета · ур. %d / 10" if viewed==Game.selected_class else "Класс · ур. %d / 10") % level,Vector2(x,y+44),Vector2(left-x,32),15,true)
	y=302 if wide else 4
	if wide:
		label(body,"Особенности класса",Vector2(0,y),Vector2(left,28),17)
		label(body,Game.CLASSES[viewed].desc,Vector2(0,y+32),Vector2(left,82),16,true)
	else:label(body,Game.CLASSES[viewed].desc,Vector2(104,78),Vector2(left-104,46),14,true)
	if viewed==Game.selected_class:action(body,"Сменить класс",Vector2(0,y+124),Vector2(left,44),show_catalog,"ChangeShell")
	else:
		action(body,shell_purchase_text(viewed),Vector2(0,y+124),Vector2(left,44),equip,"EquipShell",Game.can_select_class(viewed),owned or Game.can_select_class(viewed))
		action(body,"← Все классы",Vector2(0,y+178),Vector2(left,40),show_catalog,"AllShells")
	var origin=Vector2(308,0) if wide else Vector2(0,y+(232 if viewed!=Game.selected_class else 186))
	var width=content_width-origin.x
	label(body,"Способности класса",origin,Vector2(width,26),20)
	label(body,"Первая способность ещё не куплена. Открой её здесь." if owned and viewed not in Game.class_first_slots else "Способности закреплены за этим классом." if owned else "Открой класс, чтобы получить его способности.",origin+Vector2(0,32),Vector2(width,42),15,true)
	var offset=origin.y+80
	for slot in range(2):
		var height=ability_card(Vector2(origin.x,offset),width,slot)
		offset+=height+12
	var price=Game.class_upgrade_cost(viewed,false)
	label(body,"Развитие этого класса",Vector2(origin.x,offset+7),Vector2(width,28),18)
	label(body,"+0,5 HP, урон +0,2%, скорость +0,1% за уровень",Vector2(origin.x,offset+40),Vector2(width,38),14,true)
	var upgrade_button=action(body,"Максимальный уровень" if level>=10 else "Улучшить · %d ◈" % price,Vector2(origin.x,offset+84),Vector2(width,42),upgrade,"UpgradeShell",owned and level<10 and Game.credits>=price)
	if level<5:upgrade_button.tooltip_text=Texts.render("Вторая способность доступна с уровня класса 5")
	offset+=140
	action(body,"Скрыть характеристики" if stats_open else "Итоговые характеристики ▾",Vector2(origin.x,offset),Vector2(width,40),func():stats_open=not stats_open;refresh(),"ToggleStats")
	offset+=52
	if stats_open:
		label(body,"Общие улучшения + класс + надетое оружие",Vector2(origin.x,offset),Vector2(width,38),14,true);offset+=44
		var stats=CombatStats.shell_preview(viewed);var rows=[]
		for spec in [["health","Максимум здоровья",""],["speed","Скорость пешком"," м/с"],["damage","Урон",""],["pressure","Напор","%"]]:rows.append(SNAPSHOT.row(spec[1],stats[spec[0]],stats[spec[0]],spec[2]))
		var bars=SNAPSHOT.add_bars(body,Vector2(origin.x,offset),width,rows,52,true);offset+=bars.size.y+12
	return maxf(offset,y+232)
func ability_card(pos:Vector2,width:float,slot:int)->float:
	var skill=(Game.CLASS_SKILLS if slot==0 else Game.CLASS_SECOND)[viewed];var info=AbilityCatalog.DATA[skill]
	var owned=viewed in Game.class_unlocks;var unlocked=viewed in (Game.class_first_slots if slot==0 else Game.class_second_slots)
	var level=int(Game.class_levels.get(viewed,0));var height=(174.0 if width>=470 else 210.0)-(44.0 if unlocked else 0.0)
	var card=UiKit.panel(body,pos,Vector2(width,height),Color("30382f"));card.name="Ability"+str(slot+1)
	if slot==0 and owned and not unlocked:card.add_theme_stylebox_override("panel",UiKit.style(Color("30382f"),12,UiKit.ORANGE))
	UiKit.icon(card,"abilities/"+skill,Vector2(14,16),Vector2(48,48))
	label(card,info.name,Vector2(76,10),Vector2(width-90,28),18)
	label(card,"Готова к бою · Q" if slot==0 and unlocked else "Готова к бою · 1" if unlocked else "Первая способность · Q" if slot==0 else "Вторая способность · 1",Vector2(76,40),Vector2(width-90,25),13,true)
	label(card,info.description,Vector2(14,75),Vector2(width-28,height-(80 if unlocked else 124)),14,true)
	var title="";var enabled=false
	if unlocked:return height
	if not owned:title="Сначала открой класс"
	elif slot==0:title="Купить способность · 30 ◈" if Game.credits>=30 else "Не хватает %d ◈" % (30-Game.credits);enabled=Game.credits>=30
	elif level<5:title="Уровень класса 5 · 2500 ◈"
	elif viewed not in Game.class_first_slots:title="Сначала открой первую способность"
	else:title="Купить способность · 2500 ◈" if Game.credits>=2500 else "Не хватает %d ◈" % (2500-Game.credits);enabled=Game.credits>=2500
	action(card,title,Vector2(14,height-52),Vector2(width-28,40),buy_first if slot==0 else buy_second,"BuyFirst" if slot==0 else "BuySecond",enabled,slot==0 and enabled)
	return height
func build_catalog()->float:
	action(body,"← К текущему классу",Vector2.ZERO,Vector2(minf(content_width,300),40),func():detail(Game.selected_class),"BackToEquipped")
	label(body,"Выбрать класс",Vector2(0,58),Vector2(content_width,32),25)
	label(body,"У каждой свои особенности, уровень и две способности.",Vector2(0,100),Vector2(content_width,42),15,true)
	var columns=3 if content_width>=900 else 2 if content_width>=570 else 1;var width=(content_width-16*(columns-1))/columns
	for i in range(IDS.size()):
		var id=IDS[i];var card=UiKit.panel(body,Vector2((i%columns)*(width+16),154+floori(float(i)/columns)*212),Vector2(width,196),Color("30382f"))
		picture(card,id,Vector2(10,10),Vector2(78,110),true)
		label(card,Game.CLASSES[id].name,Vector2(100,12),Vector2(width-114,30),22)
		label(card,"Надета" if id==Game.selected_class else "Открыта" if id in Game.class_unlocks else "%d ◈" % Game.class_price(id),Vector2(100,47),Vector2(width-114,24),14,true)
		label(card,Game.CLASSES[id].desc,Vector2(100,78),Vector2(width-114,63),14,true)
		action(card,"Класс и способности",Vector2(12,148),Vector2(width-24,36),func():detail(id),"Shell_"+id)
	return 154+ceili(float(IDS.size())/columns)*212
func build_common()->float:
	label(body,"Сильнее в любом классе",Vector2.ZERO,Vector2(content_width,40),25)
	label(body,"Эти улучшения действуют всегда, даже после смены класса.",Vector2(0,48),Vector2(content_width,48),16,true)
	var rows=[["health","Здоровье","+2 HP за уровень"],["damage","Сила","+5% базового урона за уровень"],["mobility","Скорость","Прирост уменьшается с каждым уровнем"],["pressure","Напор","Определяет, чей снаряд переживёт столкновение."]]
	var wide=content_width>=610;var height=94 if wide else 140
	for i in range(rows.size()):
		var row=rows[i];var id=row[0];var y=108+i*height
		label(body,"%s · ур. %d" % [Texts.render(row[1]),Game.level(id)],Vector2(0,y),Vector2(content_width-(260 if wide else 0),28),20)
		label(body,row[2],Vector2(0,y+33),Vector2(content_width-(260 if wide else 0),44),15,true)
		action(body,"Улучшить · %d ◈" % Game.cost(id),Vector2(content_width-245,y+12) if wide else Vector2(0,y+84),Vector2(245 if wide else content_width,42),func():Game.purchase(id);notice="Улучшение действует на все классы";refresh(),"Common_"+id,Game.credits>=Game.cost(id))
	var y=108+rows.size()*height
	label(body,"Бесплатный сброс возвращает все вложенные в эти характеристики ресурсы.",Vector2(0,y+8),Vector2(content_width,46),14,true)
	action(body,"Сбросить · вернуть %d ◈" % Game.shell_refund(),Vector2(0,y+64),Vector2(content_width,42),func():Game.reset_shell();notice="Общие улучшения сброшены. Классы сохранены.";refresh(),"ResetCommon",Game.character_level()>0)
	return y+122
