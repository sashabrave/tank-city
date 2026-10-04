extends Node
signal changed
const PATH="user://settings.cfg"
const DEFAULT_KEYS={"north":KEY_W,"south":KEY_S,"west":KEY_A,"east":KEY_D,"fire":KEY_SPACE,"interact":KEY_E,"hide_trench":KEY_C,"ability":KEY_F,"class_ability":KEY_Q,"ammo_switch":KEY_R}
const DEFAULT_VALUES={"fullscreen":false,"vsync":true,"quality":1,"fps":60,"master":1.0,"music":0.8,"music_mood":"main","effects":0.8,"screen_controls":true,"biome_info":true,"language":"ru","ui_theme":"dark","shaders":true,"world_lighting":"day","light_budget":10,"atmosphere":true,"tilt_shift":true,"shader_style":"pastel","soft_shadows":true,"ambient_occlusion":true,"glow":true,"haze":true,"rim_light":true,"shiny_metal":true,"depth_light":true,"cinematic_light":true,"graphics_preset":"standard","sun_day":"random","sun_night":"random","weather":"random","ui_motion":true,"show_fps":true,"ui_glass":true,"ui_accent":"apricot","illustration_set":"gpt_image_2_5","input_scheme":"auto","render_scale":"auto","resolution":"auto","retina":true,"dev_worlds":false}
const SHADER_STYLES=["pastel","cozy","golden","overcast"]
const SHADER_OPTIONS=["soft_shadows","ambient_occlusion","glow","haze","rim_light","shiny_metal","depth_light","cinematic_light"]
var values=DEFAULT_VALUES.duplicate()
var keys=DEFAULT_KEYS.duplicate()
var menu: CanvasLayer
var content: Control
var waiting=""
var was_paused=false
var tab=0
var persistence_enabled=true
## Screen settings wait for «Применить» / «Сохранить» (standard video options): chosen values sit in pending.
const DISPLAY_KEYS=["fullscreen","resolution","retina","vsync","render_scale","quality","fps"]
var pending:={}
## What the window was last set to, so other settings never touch fullscreen or the window size.
var applied_display:={}
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
		keys["class_ability"]=KEY_Q;keys["ability"]=KEY_F
	for bus in ["TankCityMusic","TankCityEffects"]:
		if AudioServer.get_bus_index(bus)<0:
			AudioServer.add_bus();AudioServer.set_bus_name(AudioServer.bus_count-1,bus)
	apply()
func apply():
	if values.get("ui_theme","dark") not in ["dark","light"]:values.ui_theme="dark"
	if int(values.light_budget) not in [6,10,12,14]:values.light_budget=10
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
	if str(values.get("render_scale","")) not in RENDER_SCALES:values.render_scale="auto"
	if str(values.get("ui_accent","")) not in ["apricot","coral","mint","lemon","sky","lavender"]:values.ui_accent="apricot"
	if str(values.get("resolution","auto"))!="auto" and str(values.resolution) not in resolutions():values.resolution="auto"
	values.retina=bool(values.get("retina",true))
	if DisplayServer.get_name()!="headless":apply_display()
	Engine.max_fps=int(values.fps)
	get_viewport().msaa_3d=[Viewport.MSAA_DISABLED,Viewport.MSAA_2X,Viewport.MSAA_4X][values.quality]
	apply_render_scale()
	if not get_viewport().size_changed.is_connected(apply_render_scale):get_viewport().size_changed.connect(apply_render_scale)
	if not get_viewport().size_changed.is_connected(remember_window_mode):get_viewport().size_changed.connect(remember_window_mode)
	# Ambient occlusion at half resolution: nearly the same soft contact shadows for a third of the cost.
	RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_MEDIUM,true,.5,2,50.0,300.0)
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
## 3D resolution. "auto" keeps about 2.4 megapixels of 3D on big and retina screens (fullscreen 3420×2146
## would otherwise render 7.3 MP with every post effect); the interface always stays at native sharpness.
const RENDER_SCALES=["auto","100","75","50"]
const AUTO_3D_PIXELS=2400000.0
func render_scale()->float:
	var mode=str(values.get("render_scale","auto"))
	# Retina off: the 3D world renders at standard density — half the pixels per side on a 2× display.
	var density=1.0 if bool(values.get("retina",true)) or DisplayServer.get_name()=="headless" else 1.0/maxf(1.0,DisplayServer.screen_get_scale())
	if mode!="auto":return float(mode)/100.0*density
	var size=Vector2(DisplayServer.window_get_size()) if DisplayServer.get_name()!="headless" else Vector2(1280,720)
	return clampf(sqrt(AUTO_3D_PIXELS/maxf(1.0,size.x*size.y)),.5,1.0)*density
func apply_render_scale():
	var viewport=get_viewport();var scale=render_scale()
	viewport.scaling_3d_mode=Viewport.SCALING_3D_MODE_FSR if scale<.99 else Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale=scale if scale<.99 else 1.0
	viewport.fsr_sharpness=.6  # 0 is the sharpest; .35 rang around thin rain streaks
## Window mode, size and VSync change only when their own values change (or the window mode drifted from the
## value, e.g. after the system shortcut), so switching any other option keeps fullscreen and the resolution.
func apply_display():
	var full=bool(values.fullscreen);var mode=DisplayServer.window_get_mode()
	var is_full=mode in [DisplayServer.WINDOW_MODE_FULLSCREEN,DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	if applied_display.get("fullscreen")!=full:
		if full!=is_full:DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if full else DisplayServer.WINDOW_MODE_WINDOWED)
		applied_display.fullscreen=full;applied_display.erase("resolution")
	var res=str(values.get("resolution","auto"))
	if not full and applied_display.get("resolution")!=res:
		applied_display.resolution=res
		if res!="auto":
			# Sizes are in points, as the system shows them; on a 2× (Retina) screen the window gets twice
			# the pixels, otherwise «1920 × 1080» opened a half-size window (T-096).
			var parts=res.split("x");var size=Vector2i(Vector2(int(parts[0]),int(parts[1]))*pixel_ratio())
			DisplayServer.window_set_size(size)
			var screen=DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
			DisplayServer.window_set_position(screen.position+(screen.size-size)/2)
	if applied_display.get("vsync")!=bool(values.vsync):
		applied_display.vsync=bool(values.vsync)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values.vsync else DisplayServer.VSYNC_DISABLED)
## Fullscreen switched by the system (green window button, Ctrl+Cmd+F) is remembered too: the next launch
## opens the same way (T-259 — the game kept starting in a small window).
func remember_window_mode():
	if DisplayServer.get_name()=="headless" or not applied_display.has("fullscreen"):return
	var mode=DisplayServer.window_get_mode()
	var is_full=mode in [DisplayServer.WINDOW_MODE_FULLSCREEN,DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	if is_full==bool(values.fullscreen):return
	values.fullscreen=is_full;applied_display.fullscreen=is_full;pending.erase("fullscreen");save();changed.emit()
## Pixels per point of the current screen (2 on Retina).
func pixel_ratio()->float:
	return maxf(1.0,DisplayServer.screen_get_scale(DisplayServer.window_get_current_screen())) if DisplayServer.get_name()!="headless" else 1.0
## Window sizes in points that fit this display, largest first, as "W x H" keys ("1920x1080").
func resolutions()->Array:
	if DisplayServer.get_name()=="headless":return ["1920x1080","1600x900","1280x720"]
	var screen=Vector2i(Vector2(DisplayServer.screen_get_size(DisplayServer.window_get_current_screen()))/pixel_ratio())
	var result=[]
	for size in [screen,Vector2i(3840,2160),Vector2i(3456,2234),Vector2i(3024,1964),Vector2i(2880,1800),Vector2i(2560,1600),Vector2i(2560,1440),Vector2i(1920,1200),Vector2i(1920,1080),Vector2i(1680,1050),Vector2i(1600,900),Vector2i(1440,900),Vector2i(1280,800),Vector2i(1280,720)]:
		var key="%dx%d" % [size.x,size.y]
		if size.x<=screen.x and size.y<=screen.y and key not in result:result.append(key)
	return result
## Value as the settings page should show it: a chosen-but-not-applied screen option wins.
func shown(key:String):return pending.get(key,values.get(key))
var before_apply:={}
func apply_pending():
	before_apply={}
	for key in pending:before_apply[key]=values.get(key)
	for key in pending:values[key]=pending[key]
	pending.clear();apply()
## «Оставить?» prompt timed out or was declined: the screen goes back to what worked.
func revert_display():
	for key in before_apply:values[key]=before_apply[key]
	before_apply={};apply()
func save_all():
	apply_pending();save()
func save():
	if not persistence_enabled:return
	var config=ConfigFile.new()
	for key in values:config.set_value("settings",key,values[key])
	for action in keys:config.set_value("keys",action,keys[action])
	config.save(PATH)
## Graphics presets (T-049): one choice sets every lighting/effect switch; each can still be changed alone.
const GRAPHICS_PRESETS={
	"eco":{"shaders":true,"soft_shadows":false,"ambient_occlusion":false,"glow":false,"haze":false,"rim_light":false,"shiny_metal":false,"depth_light":true,"cinematic_light":false,"atmosphere":false,"tilt_shift":false,"light_budget":6,"render_scale":"50"},
	"standard":{"shaders":true,"soft_shadows":true,"ambient_occlusion":true,"glow":true,"haze":true,"rim_light":true,"shiny_metal":true,"depth_light":true,"cinematic_light":true,"atmosphere":true,"tilt_shift":true,"light_budget":10,"render_scale":"auto"},
	"cinema":{"shaders":true,"soft_shadows":true,"ambient_occlusion":true,"glow":true,"haze":true,"rim_light":true,"shiny_metal":true,"depth_light":true,"cinematic_light":true,"atmosphere":true,"tilt_shift":true,"light_budget":12,"render_scale":"100"},
}
func change(key,value):
	var before=Illustrations.current()
	if key=="graphics_preset" and GRAPHICS_PRESETS.has(value):values.merge(GRAPHICS_PRESETS[value],true)
	if key in DISPLAY_KEYS:
		if values.get(key)==value:pending.erase(key)
		else:pending[key]=value
		changed.emit();return
	values[key]=value;apply();save()
	# Illustration set: swap pictures already on screen, rebuild cached handbook images, redraw wave icons.
	if key=="illustration_set" and before!=Illustrations.current():
		Illustrations.swap_tree(get_tree().root,before,Illustrations.current())
		preload("res://scripts/ui/encyclopedia_feed.gd").refresh()
		for node in get_tree().root.find_children("*","CanvasItem",true,false):
			if node.get_script()==preload("res://scripts/ui/enemy_type_icon.gd"):node.queue_redraw()
func open():
	if is_instance_valid(menu):return
	was_paused=get_tree().paused;get_tree().paused=true;Game.reset_input()
	menu=CanvasLayer.new();menu.layer=100;add_child(menu)
	var shade=ColorRect.new();shade.color=Color(0,0,0,.45);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);menu.add_child(shade)
	var panel=UiKit.panel(menu,(get_viewport().get_visible_rect().size-Vector2(900,696))/2,Vector2(900,696));panel.add_to_group("selection_scope")
	UiKit.accent(UiKit.label(panel,"Настройки",Vector2(30,22),Vector2(700,45),UiKit.PAGE_TITLE_SIZE))
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
		choice("Музыкальная тема","music_mood",["Главная","Ночная","Дневная","Авто"],["main","night","day","auto"],i*95)
	elif tab==3:
		choice("Язык / Language","language",["Русский","English"],["ru","en"],0)
	else:
		var names={"north":"Вверх / карта вперёд","south":"Вниз / карта назад","west":"Влево","east":"Вправо","fire":"Стрелять","interact":"Выбрать / взаимодействовать","ability":"Гаджет","class_ability":"Навык класса"}
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
