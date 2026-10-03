extends CanvasLayer
## Sandbox admin: build the field, call enemies, bonuses and the boss, hand out cards, vehicles, weapons,
## shells and challenges. Opens with the «Админ» button or F2; the game pauses while it is open.
## First step towards a map editor: every action only drives the arena's public API.
signal exit_requested
const ENEMIES=[["soldier","Стрелок"],["grenadier","Гранатомётчик"],["shield","Щитовой"],["sniper","Снайпер"],["buggy","Багги"],["apc","БТР"],["tank","Танк"],["mortar","Миномёт"],["drone","Дрон"],["flyer","Летающий"]]
const SIZES=[13,15,17,19,21,23,25]
const TABS=[["field","Поле"],["enemies","Враги"],["bonuses","Бонусы"],["cards","Карты"],["stats","Статы"],["kit","Снаряжение"],["gear","Техника"],["challenges","Испытания"]]
var ability_slot=0  # sandbox «Снаряжение»: which slot (Q, 1, F) an ability button fills
var arena
var tab="field"
var rank=1
var count=1
var tier=0
var panel:Panel
var body:Control
var toggle:Button
func _ready():
	layer=105;process_mode=Node.PROCESS_MODE_ALWAYS
	var holder=Control.new();add_child(holder);holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);holder.mouse_filter=Control.MOUSE_FILTER_IGNORE
	toggle=UiKit.button(holder,"Админ [F2]",Vector2.ZERO,Vector2(170,46),open_panel);toggle.name="AdminToggle";place_toggle()
	get_viewport().size_changed.connect(place_toggle)
func place_toggle():
	if is_instance_valid(toggle):toggle.position=Vector2(get_viewport().get_visible_rect().size.x-420,20)
func _input(event):
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_F2:
		if is_instance_valid(panel):close_panel()
		else:open_panel()
		get_viewport().set_input_as_handled()
func open_panel():
	if is_instance_valid(panel):return
	get_tree().paused=true;Game.reset_input()
	var size=get_viewport().get_visible_rect().size;var width=minf(1000,size.x-40);var height=minf(640,size.y-40)
	var shade=ColorRect.new();shade.name="AdminShade";add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,.45)
	panel=UiKit.panel(shade,(size-Vector2(width,height))*.5,Vector2(width,height));panel.name="AdminPanel";shade.add_to_group("selection_scope")
	UiKit.label(panel,"Песочница · админ",Vector2(24,16),Vector2(width-300,40),26)
	UiKit.button(panel,"Закрыть",Vector2(width-160,16),Vector2(136,40),close_panel)
	for i in range(TABS.size()):
		var key=TABS[i][0]
		var b=UiKit.button(panel,TABS[i][1],Vector2(24,72+i*50),Vector2(190,42),func():tab=key;render(),key==tab);b.name="Tab_"+key
	var leave=UiKit.button(panel,"Выйти",Vector2(24,height-62),Vector2(190,44),func():close_panel();exit_requested.emit());leave.name="ExitSandbox";leave.tooltip_text="Выйти из песочницы в хаб"
	var scroll=ScrollContainer.new();panel.add_child(scroll);scroll.position=Vector2(234,72);scroll.size=Vector2(width-258,height-96);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	body=VBoxContainer.new();scroll.add_child(body);body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	render()
func close_panel():
	if is_instance_valid(panel):panel.get_parent().queue_free()
	panel=null;get_tree().paused=false;Game.reset_input()
func render():
	if not is_instance_valid(body):return
	for child in body.get_children():child.queue_free()
	for child in panel.get_children():
		if child.name.begins_with("Tab_"):child.add_theme_stylebox_override("normal",UiKit.style(Color("584a2c") if child.name=="Tab_"+tab else Color("2c352e"),6))
	var grid=GridContainer.new();body.add_child(grid);grid.columns=3;grid.add_theme_constant_override("h_separation",10);grid.add_theme_constant_override("v_separation",10)
	match tab:
		"field":
			header(grid,"Размер поля")
			for value in SIZES:action(grid,"%d × %d" % [value,value],func():rebuild({"size":value}),arena.sandbox_size==value)
			header(grid,"Генерация")
			action(grid,"Новая генерация",func():rebuild({"seed":randi()}))
			action(grid,"Обычная волна",func():rebuild({"waves":true}))
			action(grid,"Пустое поле",func():rebuild({"waves":false,"mode":"battle"}))
			action(grid,"Бой с боссом",func():boss())
			header(grid,"Время суток")
			action(grid,"День",func():lighting("day"),Settings.values.world_lighting=="day")
			action(grid,"Ночь",func():lighting("night"),Settings.values.world_lighting=="night")
			header(grid,"Биом")
			for i in range(arena.BIOMES.ENTRIES.size()):
				var index=i;action(grid,arena.BIOMES.ENTRIES[i].name,func():rebuild({"biome":index}),arena.sandbox_biome==i)
		"enemies":
			header(grid,"Ранг и количество")
			for r in [1,2,3]:
				var value=r;action(grid,"Ранг %d" % r,func():rank=value;render(),rank==r)
			for c in [1,3,5]:
				var value=c;action(grid,"× %d" % c,func():count=value;render(),count==c)
			header(grid,"Вызвать")
			for entry in ENEMIES:
				var kind=entry[0];action(grid,entry[1],func():spawn_enemies(kind))
			action(grid,"Командир",func():spawn_enemies("soldier",true))
			action(grid,"Убрать врагов",clear_enemies)
		"bonuses":
			for id in arena.LOOT.BONUSES:
				var kind=id;action(grid,arena.LOOT.BONUSES[id].name,func():arena.drop_pickup(arena.player.cell,kind))
			action(grid,"+10 жетонов",func():arena.run.tokens+=10)
		"cards":
			header(grid,"Редкость")
			for t in range(RunUpgrades.TIER_NAMES.size()):
				var value=t;action(grid,RunUpgrades.TIER_NAMES[t],func():tier=value;render(),tier==t)
			header(grid,"Карты улучшений")
			for def in UpgradeRegistry.all():
				var id=def.id;action(grid,def.title+(" ×%d" % RunUpgrades.stacks(arena,id) if RunUpgrades.stacks(arena,id)>0 else ""),func():RunUpgrades.apply(arena,id,tier);render())
		"stats":
			# Every registry stat, built from assets/balance/stats: a new stat file appears here by itself.
			for def in StatRegistry.all():
				var stat=def;var nudge={"percent":.05,"multiplier":.25,"integer":1.0,"number":.25}[def.format]
				var label=Label.new();grid.add_child(label);label.custom_minimum_size=Vector2(230,40);label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
				Texts.set_text(label,"%s · %s" % [def.title,StatRegistry.text(def,StatRegistry.value(def,arena))])
				action(grid,"−",func():nudge_stat(stat,-nudge))
				action(grid,"+",func():nudge_stat(stat,nudge))
		"kit":
			# 0.7.2 features: rolled ammo items, the backpack and sacks, any ability in any slot, class milestones.
			header(grid,"Редкость патронов")
			for t in range(Ammo.RARITY_NAMES.size()):
				var value=t;action(grid,Ammo.RARITY_NAMES[t],func():tier=value;render(),tier==t)
			header(grid,"Зарядить (в оружие сейчас: %s)" % Game.LOOT.WEAPONS[arena.run.weapon].name)
			for type in Ammo.TYPES:
				var kind=type;action(grid,Ammo.NAMES[type]+("" if Ammo.fits(type,arena.run.weapon) else " · не подходит"),func():load_ammo(kind))
			header(grid,"Рюкзак · %d / %d" % [Backpack.used(arena.run),Backpack.capacity()])
			action(grid,"Патроны в рюкзак",func():to_bag({"ammo":[Ammo.roll(Ammo.TYPES[randi()%Ammo.TYPES.size()],tier,randi())]}))
			action(grid,"Аптечка в рюкзак",func():to_bag({"supplies":[{"type":"medkit","heal":3.0}]}))
			action(grid,"Мешок рядом",drop_sack)
			action(grid,"Очистить рюкзак",func():arena.run.ammo_bag.clear();arena.run.supplies.clear();Backpack.refresh(arena);render())
			header(grid,"Способность в слот")
			for s in range(3):
				var value=s;action(grid,["Слот Q","Слот 1","Слот F"][s],func():ability_slot=value;render(),ability_slot==s)
			for id in AbilityCatalog.DATA:
				var ability=id;action(grid,AbilityCatalog.DATA[id].name+(" ✓" if id in arena.abilities.slots else ""),func():set_ability(ability))
			action(grid,"Сила способности +1",func():arena.abilities.level.power+=1.0;arena.toast("Сила: +%d" % int(arena.abilities.level.power)))
			header(grid,"Уровень класса (%s · %d)" % [Game.CLASSES[Game.selected_class].name,ClassCatalog.level(Game.selected_class)])
			for lv in [1,3,5,8,10,14,20]:
				var value=lv;action(grid,"Уровень %d" % lv,func():class_level(value),ClassCatalog.level(Game.selected_class)==lv)
		"gear":
			header(grid,"Техника рядом")
			for kind in GarageCatalog.VEHICLES:
				var id=kind;action(grid,GarageCatalog.VEHICLES[kind].name,func():vehicle(id))
			header(grid,"Оружие")
			for id in Game.LOOT.WEAPONS:
				var weapon=id;action(grid,Game.LOOT.WEAPONS[id].name,func():arena.run.weapon=weapon;RunUpgrades.refresh_player(arena);render(),arena.run.weapon==id)
			header(grid,"Класс (возрождение)")
			for id in Game.CLASSES:
				var shell=id;action(grid,Game.CLASSES[id].name,func():Game.selected_class=shell;respawn();render(),Game.selected_class==id)
		"challenges":
			header(grid,"Звёзды")
			for d in range(3):
				var value=d;action(grid,["Без звёзд","★","★★"][d],func():arena.sandbox_difficulty=value;render(),arena.sandbox_difficulty==d)
			header(grid,"Запустить")
			for mode in RoutePlan.CHALLENGES:
				var id=mode;action(grid,ChallengeRooms.TITLES.get(mode,mode),func():rebuild({"mode":id}))
func load_ammo(type:String):
	Ammo.ensure(arena.run,arena.run.weapon)
	var old=Ammo.load_item(arena.run,Ammo.roll(type,tier,randi()))
	if not old.is_empty() and not Backpack.full(arena.run):arena.run.ammo_bag.append(old)
	Backpack.refresh(arena);arena.toast(Texts.render("Патроны")+": "+Texts.render(Ammo.NAMES[type]));render()
func to_bag(content:Dictionary):
	if Backpack.full(arena.run):arena.toast("Рюкзак полон");return
	arena.run.ammo_bag.append_array(content.get("ammo",[]));arena.run.supplies.append_array(content.get("supplies",[]))
	Backpack.refresh(arena);render()
func drop_sack():
	var content={"recipes":[],"ammo":[Ammo.roll(Ammo.TYPES[randi()%Ammo.TYPES.size()],tier,randi())],"supplies":[{"type":"medkit","heal":3.0}]}
	arena.reward.place_sack(arena.find_free_near(arena.player.cell+Vector2i(1,0)),content);arena.toast("Мешок рядом")
func set_ability(id:String):
	var slots:Array=arena.abilities.slots
	while slots.size()<=ability_slot:slots.append(id)
	slots[ability_slot]=id;arena.abilities.select(id)
	refresh_skill_icons();render()
func refresh_skill_icons():
	if not is_instance_valid(arena.hud):return
	for i in range(arena.hud.skill_buttons.size()):
		var button=arena.hud.skill_buttons[i];button.visible=i<arena.abilities.slots.size()
		if button.visible:button.get_node("Icon").texture=UiKit.trimmed(UiKit.icon_texture("abilities/"+str(arena.abilities.slots[i])))
## Class level for milestone checks: abilities (second slot, Q +1 at 7) rebuild now; perks need a new run.
func class_level(level:int):
	Game.class_levels[Game.selected_class]=level-1  # displayed level 1–20
	arena.abilities.setup();refresh_skill_icons()
	arena.toast("Уровень класса %d · перки — с нового забега" % level);render()
func nudge_stat(def:StatDef,amount:float):
	var current=float(arena.run.get(def.run_field))
	var next=maxf(0.0,current+amount)
	arena.run.set(def.run_field,int(round(next)) if typeof(arena.run.get(def.run_field))==TYPE_INT else next)
	render()
func header(grid:GridContainer,text:String):
	for i in range(grid.get_child_count()%grid.columns,grid.columns if grid.get_child_count()%grid.columns else 0):grid.add_child(Control.new())
	var label=Label.new();grid.add_child(label);Texts.set_text(label,text);label.add_theme_color_override("font_color",UiKit.MUTED);label.custom_minimum_size=Vector2(230,28)
	for i in range(grid.columns-1):grid.add_child(Control.new())
func action(grid:GridContainer,text:String,callback:Callable,selected:bool=false)->Button:
	var b=UiKit.button(grid,text,Vector2.ZERO,Vector2(0,40),callback,selected);b.custom_minimum_size=Vector2(230,40)
	b.add_theme_font_size_override("font_size",15);b.clip_text=true
	return b

## Rebuilds the room with new overrides; the soldier keeps the run's upgrades.
func rebuild(changes:Dictionary):
	if changes.has("size"):arena.sandbox_size=changes.size
	if changes.has("seed"):arena.run_seed=changes.seed
	if changes.has("biome"):arena.sandbox_biome=changes.biome
	if changes.has("waves"):arena.sandbox_waves=changes.waves
	if changes.has("mode"):arena.sandbox_mode=changes.mode;arena.sandbox_waves=false if changes.mode!="battle" else arena.sandbox_waves
	else:arena.sandbox_mode="battle" if changes.has("waves") else arena.sandbox_mode
	close_panel();arena.begin_room(0)
func boss():
	arena.sandbox_mode="battle";arena.sandbox_waves=true;arena.run_seed=randi()
	close_panel();arena.begin_room(Campaign.BOSSES[0])
func lighting(value:String):
	Settings.values.world_lighting=value;Settings.apply();rebuild({})
func free_cells(row_limit:int)->Array:
	var result=[]
	for y in range(1,row_limit):
		for x in range(1,arena.grid_size-1):
			var cell=Vector2i(x,y)
			if arena.can_enter(cell):result.append(cell)
	return result
func spawn_enemies(kind:String,commander:=false):
	var cells=free_cells(maxi(3,int(arena.grid_size/2)))
	for i in range(count):
		if cells.is_empty():break
		var cell=cells.pop_at(randi()%cells.size())
		var enemy=arena.spawn_actor(kind,cell,false,false,rank)
		if commander:enemy.elite=true;enemy.commander_elite=true
	arena.phase="combat"
func clear_enemies():
	for actor in arena.room.actors.duplicate():
		if is_instance_valid(actor) and not actor.player_owned and not actor.allied:actor.dead=true;arena.room.actors.erase(actor);actor.queue_free()
	arena.room.spawn_queue.clear()
func vehicle(kind:String):
	var cell=arena.find_free_near(arena.player.cell+Vector2i(2,0))
	arena.make_wreck(kind,cell,Vector2i.UP,false,arena.vehicle.player_armor(kind))
	arena.toast("Техника рядом · E, чтобы сесть")
func respawn():
	if is_instance_valid(arena.room.player):
		var old=arena.room.player;arena.room.actors.erase(old);old.dead=true;old.queue_free()
	arena.run.soldier_max_hp=roundi(CombatStats.initial_health());arena.run.soldier_hp=arena.run.soldier_max_hp
	arena.room.player=arena.spawn_actor("soldier",arena.find_free_near(Vector2i(arena.room.base_cell.x,arena.grid_size-3)),true)
