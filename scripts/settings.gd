extends Node
signal changed
const PATH="user://settings.cfg"
const DEFAULT_KEYS={"north":KEY_W,"south":KEY_S,"west":KEY_A,"east":KEY_D,"fire":KEY_SPACE,"interact":KEY_E,"hide_trench":KEY_C,"ability":KEY_F,"skill_1":KEY_1,"skill_2":KEY_NONE,"hq_ability":KEY_2,"class_ability":KEY_Q}
const DEFAULT_VALUES={"fullscreen":false,"vsync":true,"quality":1,"fps":60,"master":1.0,"music":0.8,"effects":0.8,"music_mood":"auto","screen_controls":true,"biome_info":true,"language":"ru","ui_theme":"dark","shaders":true,"world_lighting":"day","light_budget":10,"atmosphere":true,"tilt_shift":true,"shader_style":"pastel","soft_shadows":true,"ambient_occlusion":true,"glow":true,"haze":true,"rim_light":true,"shiny_metal":true,"sun_day":"random","sun_night":"random","weather":"random","ui_motion":true,"show_fps":true,"ui_glass":true,"ui_accent":"apricot","input_scheme":"auto"}
const SHADER_STYLES=["pastel","cozy","golden","overcast"]
const SHADER_OPTIONS=["soft_shadows","ambient_occlusion","glow","haze","rim_light","shiny_metal"]
var values=DEFAULT_VALUES.duplicate()
var keys=DEFAULT_KEYS.duplicate()
var menu: CanvasLayer
var content: Control
var waiting=""
var was_paused=false
var tab=0
var persistence_enabled=true
func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	var config=ConfigFile.new()
	if config.load(PATH)==OK:
		for key in values:values[key]=config.get_value("settings",key,values[key])
		for action in keys:
			var code=int(config.get_value("keys",action,keys[action]))
			if code>0 and code!=KEY_ESCAPE:keys[action]=code
	# Migrate the previous F/2/Q layout once; keep later custom bindings.
	if not config.has_section_key("keys","class_ability"):
		keys["class_ability"]=KEY_Q;keys["hq_ability"]=KEY_2;keys["ability"]=KEY_F;keys["skill_1"]=KEY_1;keys["skill_2"]=KEY_NONE
	for bus in ["TankCityMusic","TankCityEffects"]:
		if AudioServer.get_bus_index(bus)<0:
			AudioServer.add_bus();AudioServer.set_bus_name(AudioServer.bus_count-1,bus)
	apply()
func apply():
	if values.get("ui_theme","dark") not in ["dark","light"]:values.ui_theme="dark"
	if int(values.light_budget) not in [6,10,14]:values.light_budget=10
	if values.language not in ["ru","en"]:values.language="ru"
	if values.world_lighting not in ["day","night"]:values.world_lighting="day"
	if values.get("shader_style","") not in SHADER_STYLES:values.shader_style="pastel"
	for key in SHADER_OPTIONS:values[key]=bool(values.get(key,true))
	if values.get("sun_day","") not in ["random","dawn","morning","noon","golden","sunset"]:values.sun_day="random"
	if values.get("weather","") not in ["random","clear","rain","snow","fog","sandstorm"]:values.weather="random"
	if values.get("sun_night","") not in ["random","dusk","moon","predawn"]:values.sun_night="random"
	for key in ["master","music","effects"]:values[key]=clampf(float(values[key]),0,1)
	values.quality=clampi(int(values.quality),0,2)
	if int(values.fps) not in [0,30,60,120]:values.fps=60
	if str(values.get("input_scheme","")) not in ["auto","keyboard","gamepad","touch"]:values.input_scheme="auto"
	if str(values.get("ui_accent","")) not in ["apricot","coral","mint","lemon","sky","lavender"]:values.ui_accent="apricot"
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if values.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values.vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=int(values.fps)
	get_viewport().msaa_3d=[Viewport.MSAA_DISABLED,Viewport.MSAA_2X,Viewport.MSAA_4X][values.quality]
	for entry in [["Master","master"],["TankCityMusic","music"],["TankCityEffects","effects"]]:
		var index=AudioServer.get_bus_index(entry[0]);AudioServer.set_bus_volume_db(index,linear_to_db(maxf(.0001,values[entry[1]])));AudioServer.set_bus_mute(index,values[entry[1]]==0)
	for action in keys:
		if not InputMap.has_action(action):InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var event=InputEventKey.new();event.physical_keycode=keys[action];InputMap.action_add_event(action,event)
		var arrows={"north":KEY_UP,"south":KEY_DOWN,"west":KEY_LEFT,"east":KEY_RIGHT}
		if action in arrows and keys[action]==DEFAULT_KEYS[action] and arrows[action] not in keys.values():
			var arrow=InputEventKey.new();arrow.physical_keycode=arrows[action];InputMap.action_add_event(action,arrow)
		preload("res://scripts/input_scheme.gd").add_pad_events(action)
	Game.reset_input()
	Texts.set_language(values.language)
	EffectLighting.refresh_projectile_halos()
	var cozy=bool(values.get("shaders",true))
	RenderingServer.global_shader_parameter_set("cozy_enabled",cozy)
	RenderingServer.global_shader_parameter_set("cozy_rim",.45 if cozy and values.rim_light else 0.0)
	RenderingServer.global_shader_parameter_set("cozy_shiny",cozy and values.shiny_metal)
	changed.emit()
func save():
	if not persistence_enabled:return
	var config=ConfigFile.new()
	for key in values:config.set_value("settings",key,values[key])
	for action in keys:config.set_value("keys",action,keys[action])
	config.save(PATH)
func change(key,value):values[key]=value;apply();save()
func open():
	if is_instance_valid(menu):return
	was_paused=get_tree().paused;get_tree().paused=true;Game.reset_input()
	menu=CanvasLayer.new();menu.layer=100;add_child(menu)
	var shade=ColorRect.new();shade.color=Color(0,0,0,.45);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);menu.add_child(shade)
	var panel=UiKit.panel(menu,(get_viewport().get_visible_rect().size-Vector2(900,696))/2,Vector2(900,696));panel.add_to_group("selection_scope")
	UiKit.label(panel,"Настройки",Vector2(30,22),Vector2(700,45),UiKit.PAGE_TITLE_SIZE)
	UiKit.button(panel,"×",Vector2(815,18),Vector2(55,48),close)
	for i in range(4):UiKit.button(panel,["Видео","Звук","Управление","Интерфейс"][i],Vector2(30+i*213,85),Vector2(201,48),func():tab=i;draw())
	content=Control.new();panel.add_child(content);content.position=Vector2(30,133+UiKit.TAB_CONTENT_GAP)
	UiKit.button(panel,"Сбросить настройки",Vector2(30,626),Vector2(300,48),reset_defaults)
	UiKit.button(panel,"Готово",Vector2(580,626),Vector2(290,48),close,true)
	var music=preload("res://scenes/ui/music_mini_player.tscn").instantiate();panel.add_child(music);music.position=Vector2(30,535);music.size=Vector2(840,70)
	draw()
func close():
	waiting="";menu.queue_free();menu=null;Game.reset_input();get_tree().paused=was_paused
func reset_defaults():
	values=DEFAULT_VALUES.duplicate();keys=DEFAULT_KEYS.duplicate();apply();save();draw()
func draw():
	waiting=""
	for child in content.get_children():content.remove_child(child);child.queue_free()
	if tab==0:
		choice("Экран","fullscreen",["Окно","Полный экран"],[false,true],0)
		choice("Вертикальная синхронизация","vsync",["Выключена","Включена"],[false,true],55)
		choice("Сглаживание","quality",["Без сглаживания","2×","4×"],[0,1,2],110)
		choice("Ограничение кадров","fps",["30 FPS","60 FPS","120 FPS","Без ограничения"],[30,60,120,0],165)
		choice("Освещение поля","world_lighting",["День","Ночь"],["day","night"],220)
		choice("Тема интерфейса","ui_theme",["Тёмная","Светлая"],["dark","light"],270)
		var toggle=CheckButton.new();content.add_child(toggle);Texts.set_text(toggle,"Шейдеры · уютный свет и металл");toggle.position=Vector2(0,322);toggle.button_pressed=values.shaders;toggle.toggled.connect(func(enabled):change("shaders",enabled))
		UiKit.label(content,"Настройки применяются сразу и сохраняются автоматически.",Vector2(0,355),Vector2(830,24),17,UiKit.MUTED)
	elif tab==1:
		var names={"master":"Общая громкость","music":"Музыка","effects":"Эффекты"}
		var i=0
		for key in names:
			UiKit.label(content,names[key],Vector2(0,i*95),Vector2(350,40),22)
			var label=UiKit.label(content,str(roundi(values[key]*100))+"%",Vector2(750,i*95),Vector2(90,40),20)
			var slider=HSlider.new();content.add_child(slider);slider.position=Vector2(355,i*95+8);slider.size=Vector2(370,35);slider.min_value=0;slider.max_value=100;slider.value=values[key]*100
			slider.value_changed.connect(func(value):change(key,value/100.0);Texts.set_text(label,str(roundi(value))+"%"))
			i+=1
		choice("Музыкальная тема","music_mood",["Авто","День","Ночь"],["auto","day","night"],i*95)
	elif tab==3:
		choice("Язык / Language","language",["Русский","English"],["ru","en"],0)
	else:
		var names={"north":"Вверх / карта вперёд","south":"Вниз / карта назад","west":"Влево","east":"Вправо","fire":"Стрелять","interact":"Выбрать / взаимодействовать","ability":"Гаджет","class_ability":"Навык класса","skill_1":"Второй навык класса","hq_ability":"Гаджет штаба"}
		var i=0
		for action in names:
			var x=(i%2)*430;var y=int(i/2.0)*58
			UiKit.label(content,names[action],Vector2(x,y),Vector2(255,38),17)
			var button=UiKit.button(content,OS.get_keycode_string(keys[action]),Vector2(x+260,y),Vector2(145,42),func():waiting=action;draw_wait(action))
			button.name=action;i+=1
		UiKit.label(content,"Esc — пауза / отмена. Перетаскивание мышью — карта.\nНажми на клавишу, затем новую. Занятые клавиши меняются местами.",Vector2(0,375),Vector2(835,60),17,UiKit.MUTED)
func draw_wait(action):
	for child in content.get_children():
		if child is Button:Texts.set_text(child,"Нажми…" if child.name==action else OS.get_keycode_string(keys[str(child.name)]))
func choice(title,key,labels,options,y):
	UiKit.label(content,title,Vector2(0,y),Vector2(420,45),21)
	var button=OptionButton.new();content.add_child(button);button.position=Vector2(455,y);button.size=Vector2(370,45);button.add_theme_font_size_override("font_size",20)
	for label in labels:button.add_item(label)
	button.select(options.find(values[key]));button.item_selected.connect(func(index):change(key,options[index]))
func _input(event):
	if not is_instance_valid(menu):return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:
			if waiting!="":waiting="";draw()
			else:close()
		elif waiting!="" and event.physical_keycode>0:
			var code=event.physical_keycode;var old=keys[waiting]
			for action in keys:
				if keys[action]==code:keys[action]=old
			keys[waiting]=code;waiting="";apply();save();draw()
		get_viewport().set_input_as_handled()
