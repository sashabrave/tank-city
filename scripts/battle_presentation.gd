extends CanvasLayer
## Presentation only: no damage, roster or input mutation.
var arena
var heading:Label
var caption:Label
var text_tween:Tween
var pulse=0.0
var last_phase=""
var departing=false
func _ready():
	layer=30
	heading=Label.new();heading.set_meta("keep_theme_colors",true);add_child(heading);heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	heading.mouse_filter=Control.MOUSE_FILTER_IGNORE;heading.add_theme_color_override("font_color",Color.WHITE)
	heading.add_theme_color_override("font_shadow_color",Color(0,0,0,.35));heading.add_theme_constant_override("shadow_offset_y",3)
	caption=Label.new();caption.set_meta("keep_theme_colors",true);add_child(caption);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
	caption.add_theme_color_override("font_color",Color.WHITE)
	caption.add_theme_color_override("font_shadow_color",Color(0,0,0,.7));caption.add_theme_constant_override("shadow_offset_y",2)
	layout();get_viewport().size_changed.connect(layout);heading.modulate.a=0;caption.modulate.a=0
func layout():
	var size=get_viewport().get_visible_rect().size
	heading.size=Vector2(size.x*.88,140);heading.pivot_offset=heading.size*.5
	heading.position=Vector2(size.x*.06,size.y*.25);heading.scale=Vector2(.72,1.18)
	heading.add_theme_font_size_override("font_size",clampi(roundi(size.x*.049),40,130))
	caption.size=Vector2(size.x*.9,50);caption.position=Vector2(size.x*.05,size.y*.25+115)
	caption.add_theme_font_size_override("font_size",clampi(roundi(size.x*.014),18,38))
func announce(title:String,subtitle:String="",hold:float=.7):
	if text_tween and text_tween.is_valid():text_tween.kill()
	Texts.set_text(heading,title);Texts.set_text(caption,subtitle);heading.modulate.a=0;caption.modulate.a=0
	text_tween=create_tween().set_parallel(true)
	text_tween.tween_property(heading,"modulate:a",1.0,.16);text_tween.tween_property(caption,"modulate:a",1.0,.16)
	text_tween.chain().tween_interval(hold)
	text_tween.chain().tween_property(heading,"modulate:a",0.0,.3)
	text_tween.parallel().tween_property(caption,"modulate:a",0.0,.3)
func fade_in():
	var shade=ColorRect.new();add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color.BLACK;shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var tween=create_tween();tween.tween_property(shade,"color:a",0.0,.5);tween.tween_callback(shade.queue_free)
func prepare_wave(index:int):
	departing=false;pulse=0;last_phase="countdown"
	if index==0:fade_in()
	arena.camera.size=(arena.grid_size+5.0)*(1.25 if index==0 else 1.14)
	announce("Последний бой" if Campaign.is_final(arena.room_index) else "Бой С генералом" if arena.boss_room else "Старт боя" if index==0 else "Волна %d / 3" % (index+1),WaveDirector.wave_title(index)+" · "+WaveDirector.wave_hint(index) if not arena.boss_room else "Приготовься",1.0)
func miniboss(difficulty:int):
	last_phase="combat";pulse=.75;announce("Командир "+EncounterRules.STARS[difficulty], EncounterRules.reward_text(difficulty),.9)
func _process(delta):
	if not is_instance_valid(arena) or not arena.is_inside_tree() or not is_instance_valid(arena.camera):return
	var phase=arena.phase;var base=arena.grid_size+5.0
	heading.visible=phase!="paused";caption.visible=phase!="paused"
	if phase=="paused":return
	var overview=phase in ["upgrade","map","result"] or (phase=="countdown" and arena.countdown>.85)
	var target=base*(1.14 if overview else 1.0)
	if pulse>0:pulse=maxf(0,pulse-delta);target=base*.97
	arena.camera.size=lerpf(arena.camera.size,target,minf(1,delta*4.5))
	var offset=Vector3(0,24,11) if overview else Vector3(0,19,14)
	arena.camera.position=arena.camera.position.lerp(offset.rotated(Vector3.UP,deg_to_rad(10)),minf(1,delta*3.5));arena.camera.look_at(Vector3.ZERO)
	if phase=="combat" and last_phase=="countdown":announce("Контакт", "Волна %d / 3" % (arena.wave+1) if not arena.boss_room else "Уничтожь командира",.4)
	last_phase=phase
