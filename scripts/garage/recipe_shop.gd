extends Control
signal closed
signal changed
signal reset_requested
var category="research"
const GROUPS=DevUnlocks.GROUPS
func _ready():add_to_group("selection_scope");set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);refresh()
func refresh():
	for child in get_children():remove_child(child);child.queue_free()
	var shade=ColorRect.new();add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,.5)
	var panel=UiKit.panel(self,(get_viewport_rect().size-Vector2(960,650))*.5,Vector2(960,650))
	UiKit.label(panel,"Чертежи / тест",Vector2(24,15),Vector2(800,40),26)
	UiKit.button(panel,"×",Vector2(883,12),Vector2(52,44),func():closed.emit())
	var i=0
	for group in GROUPS:
		var total=DevUnlocks.catalog(group).size();var count=DevUnlocks.catalog(group).keys().filter(func(id):return DevUnlocks.owned(group,id)).size()
		var tab=UiKit.button(panel,("● " if category==group else "")+GROUPS[group]+"  %d/%d" % [count,total],Vector2(24,78+i*58),Vector2(220,52),func():category=group;refresh());tab.add_theme_font_size_override("font_size",17);i+=1
	var scroll=ScrollContainer.new();panel.add_child(scroll);scroll.position=Vector2(268,78);scroll.size=Vector2(667,460);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	var list=VBoxContainer.new();scroll.add_child(list);list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list.add_theme_constant_override("separation",8)
	if category=="garage":
		add_heading(list,"Машины")
		for kind in GarageCatalog.VEHICLES:add_recipe(list,"vehicle_"+kind)
		for kind in GarageCatalog.VEHICLES:
			add_heading(list,"Оборудование / "+GarageCatalog.VEHICLES[kind].name)
			for branch in GarageCatalog.BRANCHES:add_recipe(list,kind+"_"+branch)
	else:
		for id in DevUnlocks.catalog(category):add_recipe(list,id)
	for j in range(2):
		UiKit.button(panel,"Открыть группу" if j==0 else "Закрыть группу",Vector2(268+j*340,553),Vector2(326,38),func():
			for id in DevUnlocks.catalog(category):DevUnlocks.toggle(category,id,j==0)
			changed.emit();refresh()).add_theme_font_size_override("font_size",16)
	UiKit.button(panel,"Все чертежи +",Vector2(24,601),Vector2(285,35),func():Game.set_all_recipes(true);changed.emit();refresh()).add_theme_font_size_override("font_size",15)
	UiKit.button(panel,"Все чертежи −",Vector2(337,601),Vector2(285,35),func():Game.set_all_recipes(false);changed.emit();refresh()).add_theme_font_size_override("font_size",15)
	UiKit.button(panel,"Обнулить профиль",Vector2(650,601),Vector2(285,35),func():reset_requested.emit()).add_theme_font_size_override("font_size",15)
func add_heading(list:VBoxContainer,text:String):
	var label=Label.new();list.add_child(label);Texts.set_text(label,text);label.add_theme_font_size_override("font_size",14);label.add_theme_color_override("font_color",UiKit.MUTED)
func add_recipe(list:VBoxContainer,id:String):
	var owned=DevUnlocks.owned(category,id)
	var base=(category=="hq" and id in HQCatalog.DEFAULT_UNLOCKS) or (category=="weapon" and id=="pistol") or (category=="bonus" and id=="heart") or (category=="research" and id=="character") or (category=="ability" and id=="barrier") or (category=="classes" and id=="recruit")
	var row=VBoxContainer.new();list.add_child(row)
	var button=UiKit.button(row,("✓ " if owned else "🔒 ")+DevUnlocks.catalog(category)[id].name+(" · стартовый чертёж" if base and category!="classes" else ""),Vector2.ZERO,Vector2(630,45),func():DevUnlocks.toggle(category,id,not owned);changed.emit();refresh())
	button.custom_minimum_size=Vector2(630,45);button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.add_theme_font_size_override("font_size",16);button.disabled=base;UiKit.muted_locked_button(button)
	var can_purchase=category in ["ability","hq","classes"] or (category=="research" and id in Game.BUILD_COST) or (category=="garage" and id.begins_with("vehicle_"))
	if can_purchase:
		var bought=DevUnlocks.purchased(category,id)
		var label="Навык 1" if category=="classes" else "Постройка" if category=="research" else "Покупка"
		var toggle=UiKit.button(row,label+": "+("✓ отменить" if bought else "выдать бесплатно"),Vector2.ZERO,Vector2(630,38),func():DevUnlocks.set_purchase(category,id,not bought);changed.emit();refresh());toggle.custom_minimum_size=Vector2(630,38);toggle.add_theme_font_size_override("font_size",14)
	if category=="classes":
		var second=id in Game.class_second_slots
		var toggle=UiKit.button(row,"Навык 2: "+("✓ закрыть" if second else "выдать · класс до ур. 5"),Vector2.ZERO,Vector2(630,38),func():DevUnlocks.second_skill(id,not second);changed.emit();refresh());toggle.custom_minimum_size=Vector2(630,38);toggle.add_theme_font_size_override("font_size",14)
