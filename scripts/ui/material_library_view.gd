extends CanvasLayer
## Tester tool «Материалы» (Инструменты → Материалы, 2026-10-03): the material library on a side panel while
## the game stays visible. Every surface has sliders (metal, roughness, lacquer) and a brushed switch; palette
## parts (gun, steel, brass…) pick their surface. Changes apply to the scene at once; «Сохранить» writes
## data/materials.json (from the editor) or the player override, «Сбросить» returns to the saved values.
const WIDTH:=440.0
const PALETTE_PARTS=["gun","gun_light","steel","gold","bronze","black","glass","hull","hull_light","hull_dark","rubber","wood","furniture","hazard","lamp","canvas","strap","vest"]
const PART_TITLES={"gun":"Оружие: корпус","gun_light":"Оружие: светлые детали","steel":"Сталь (детали)","gold":"Золото","bronze":"Бронза","black":"Чёрные детали","glass":"Стекло","hull":"Корпус техники","hull_light":"Корпус: светлые панели","hull_dark":"Корпус: тёмные панели","rubber":"Резина","wood":"Дерево","furniture":"Приклад, ложе","hazard":"Предупреждающая окраска","lamp":"Фонари","canvas":"Брезент","strap":"Ремни","vest":"Жилет"}
var panel:Panel
var status:Label
var pending:=false
static func open(tree:SceneTree):
	if tree.root.has_node("MaterialLibraryView"):return
	var view=load("res://scripts/ui/material_library_view.gd").new();view.name="MaterialLibraryView";tree.root.add_child(view)
func _ready():
	layer=115;process_mode=Node.PROCESS_MODE_ALWAYS
	var screen=get_viewport().get_visible_rect().size
	panel=Panel.new()
	add_child(panel);panel.name="Panel";panel.position=Vector2(screen.x-WIDTH-16,16);panel.size=Vector2(WIDTH,screen.y-32)
	panel.add_theme_stylebox_override("panel",UiKit.style(Color("1f2722"),14,Color(1,1,1,.12)))
	panel.add_to_group("selection_scope")
	UiKit.accent(UiKit.label(panel,"Материалы",Vector2(18,12),Vector2(WIDTH-90,34),22))
	UiKit.button(panel,"×",Vector2(WIDTH-58,12),Vector2(42,38),queue_free).name="Close"
	UiKit.label(panel,"Меняется сразу в игре. Сохранить — в data/materials.json",Vector2(18,46),Vector2(WIDTH-36,20),12,UiKit.MUTED)
	var scroll=ScrollContainer.new();panel.add_child(scroll);scroll.position=Vector2(12,74);scroll.size=Vector2(WIDTH-24,panel.size.y-74-70)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	var list=VBoxContainer.new();scroll.add_child(list);list.name="List";list.custom_minimum_size.x=WIDTH-40;list.add_theme_constant_override("separation",6)
	build(list)
	var reset=UiKit.button(panel,"Сбросить",Vector2(18,panel.size.y-58),Vector2((WIDTH-48)*.5,44),func():
		MaterialLibrary.reset();MaterialLibrary.apply_live(get_tree());rebuild();say("Вернулось к сохранённому"));reset.name="Reset"
	var save=UiKit.button(panel,"Сохранить",Vector2(30+(WIDTH-48)*.5,panel.size.y-58),Vector2((WIDTH-48)*.5,44),func():
		say("Сохранено" if MaterialLibrary.save() else "Не удалось сохранить"),true);save.name="Save"
	status=UiKit.label(panel,"",Vector2(18,panel.size.y-80),Vector2(WIDTH-36,20),12,Color("8fe895"));status.name="Status"
func rebuild():
	var list=panel.find_child("List",true,false)
	for child in list.get_children():child.queue_free()
	build(list)
func say(text:String):Texts.set_text(status,text)
func heading(list:VBoxContainer,text:String):
	var l=Label.new();list.add_child(l);Texts.set_text(l,text);l.add_theme_font_size_override("font_size",16);l.add_theme_color_override("font_color",UiKit.ORANGE);l.custom_minimum_size=Vector2(0,30)
func build(list:VBoxContainer):
	heading(list,"Поверхности")
	var surfaces=MaterialLibrary.surfaces()
	for kind in surfaces:
		var spec:Dictionary=surfaces[kind]
		var box=VBoxContainer.new();list.add_child(box);box.name="Surface_"+kind;box.add_theme_constant_override("separation",2)
		var title=Label.new();box.add_child(title);Texts.set_text(title,str(spec.get("title",kind)));title.add_theme_font_size_override("font_size",15)
		for param in [["metallic","Металл"],["roughness","Шероховатость"],["clearcoat","Лак"]]:slider(box,spec,param[0],param[1])
		var brushed=CheckBox.new();box.add_child(brushed);Texts.set_text(brushed,"Шлифовка (полосы)");brushed.button_pressed=bool(spec.get("brushed",false));brushed.add_theme_font_size_override("font_size",13)
		brushed.toggled.connect(func(on):spec["brushed"]=on;changed())
	heading(list,"Детали палитры (оружие, бойцы, лампы)")
	var kinds=["—"]+surfaces.keys()
	for part in PALETTE_PARTS:
		var row=HBoxContainer.new();list.add_child(row);row.name="Part_"+part
		var name=Label.new();row.add_child(name);Texts.set_text(name,PART_TITLES.get(part,part));name.custom_minimum_size=Vector2(200,0);name.add_theme_font_size_override("font_size",13)
		var pick=OptionButton.new();row.add_child(pick);pick.size_flags_horizontal=Control.SIZE_EXPAND_FILL;pick.add_theme_font_size_override("font_size",13)
		for k in kinds:pick.add_item(Texts.render(str(surfaces[k].get("title",k))) if k in surfaces else "—")
		pick.select(maxi(0,kinds.find(MaterialLibrary.palette_surface(part))))
		var cell=part
		pick.item_selected.connect(func(i):
			if i==0:MaterialLibrary.data.palette.erase(cell)
			else:MaterialLibrary.data.palette[cell]=kinds[i]
			changed())
func slider(box:VBoxContainer,spec:Dictionary,key:String,title:String):
	var row=HBoxContainer.new();box.add_child(row)
	var name=Label.new();row.add_child(name);Texts.set_text(name,title);name.custom_minimum_size=Vector2(130,0);name.add_theme_font_size_override("font_size",13);name.add_theme_color_override("font_color",UiKit.MUTED)
	var bar=HSlider.new();row.add_child(bar);bar.min_value=0;bar.max_value=1;bar.step=.01;bar.value=float(spec.get(key,0.0));bar.size_flags_horizontal=Control.SIZE_EXPAND_FILL;bar.name="Slider_"+key
	var value=Label.new();row.add_child(value);value.text="%.2f" % bar.value;value.custom_minimum_size=Vector2(44,0);value.add_theme_font_size_override("font_size",13)
	bar.value_changed.connect(func(v):spec[key]=snappedf(v,.01);value.text="%.2f" % v;changed())
## Re-apply at most once per frame while a slider is dragged.
func changed():
	if pending:return
	pending=true
	(func():pending=false;MaterialLibrary.apply_live(get_tree());say("Не сохранено")).call_deferred()
func _input(event):
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:get_viewport().set_input_as_handled();queue_free()
