extends Control
## HQ modules in battle (author, 4 Oct 2026): no HQ button and no key. The modules are ROUND icons at the very end
## of the hero's ability row at the bottom of the HUD (T-299): a readiness ring on each, Медпункт also shows its
## health stock as a small bar under the circle. Every trigger pops a small icon with a caption over the HQ
## («Купол», «Медпункт +1», «Ремонт +1,5»). Visual only.
var arena
## Diameter of a round module icon and the gap before it (the hero tiles are 76 px with a 12 px gap).
const ROUND:=60.0
const GAP:=12.0
## Top-left of the first round icon and the height of the ability row, set by the HUD every refresh.
var strip_origin:=Vector2.ZERO
var strip_height:=76.0
var popups:Array=[]
func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_preset(Control.PRESET_FULL_RECT)
## Modules shown in the ability row: none while the HQ is off the field (the final boss room).
static func shown_modules(context)->Array:
	if not is_instance_valid(context) or context.headquarters==null or context.hq_off_field():return []
	return context.headquarters.modules
## Width the round icons add to the ability row; `after_tiles` — hero tiles stand before them (one gap between).
static func strip_width(context,after_tiles:bool)->float:
	var count=shown_modules(context).size()
	if count==0:return 0.0
	return count*ROUND+(count-1)*GAP+(GAP if after_tiles else 0.0)
func anchor_point():
	var camera=get_viewport().get_camera_3d()
	if camera==null or not is_instance_valid(arena) or arena.hq_off_field():return null
	var world=arena.world_pos(arena.base_cell)+Vector3.UP*2.45
	if camera.is_position_behind(world):return null
	return camera.unproject_position(world)
func _process(_delta):
	var hq=arena.headquarters
	while not hq.events.is_empty():pop(hq.events.pop_front())
	var at=anchor_point()
	for popup in popups.duplicate():
		if not is_instance_valid(popup.node):popups.erase(popup);continue
		popup.node.visible=at!=null and arena.phase in ["combat","countdown","paused"]
		if at!=null:popup.node.position=at+Vector2(-popup.node.size.x*.5,-74-popup.slot*24-popup.lift)
	queue_redraw()
func _draw():
	var hq=arena.headquarters;var modules=shown_modules(arena)
	for i in range(modules.size()):
		var id=modules[i];var center=strip_origin+Vector2(i*(ROUND+GAP)+ROUND*.5,strip_height*.5);var radius=ROUND*.5
		var ready=hq.readiness(id);var dome=id=="hq_field" and hq.shield_time>0
		# Same plate as the hero tiles (dark glass with a thin light rim), only round.
		draw_circle(center,radius,Color(0.14,0.175,0.15,.96))
		draw_arc(center,radius-.5,0,TAU,48,Color(0.43,0.46,0.41,1),1.0,true)
		var texture=UiKit.trimmed(UiKit.icon_texture("headquarters/"+id))
		var art=Rect2(center-Vector2.ONE*radius*.62,Vector2.ONE*radius*1.24)
		if texture:draw_texture_rect(texture,art,false,Color(1,1,1,1.0 if ready>=1 else .5))
		if ready<1:
			draw_circle(center,radius-3,Color(0,0,0,.28))
			draw_arc(center,radius-2,-PI/2,-PI/2+TAU*ready,48,Color(1,1,1,.85),3.0,true)
		else:draw_arc(center,radius-2,0,TAU,48,Color("8fd4f0") if dome else Color("a6d98f"),3.0,true)
		if id=="hq_medpost":
			var full=HQCatalog.medpost_stock(hq.level(id));var bar=Rect2(center+Vector2(-radius+10,radius+6),Vector2(ROUND-20,6))
			draw_rect(bar,Color(.08,.1,.09,.85));draw_rect(Rect2(bar.position,Vector2(bar.size.x*clampf(hq.medpost_stock/maxf(full,1),0,1),bar.size.y)),Color("7ed37a"))
## One trigger: the module icon and a short caption rise over the HQ and fade.
func pop(event:Dictionary):
	var box=HBoxContainer.new();box.mouse_filter=Control.MOUSE_FILTER_IGNORE;box.add_theme_constant_override("separation",4);add_child(box)
	var picture=TextureRect.new();picture.texture=UiKit.trimmed(UiKit.icon_texture("headquarters/"+str(event.id)));picture.custom_minimum_size=Vector2(22,22)
	picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;box.add_child(picture)
	var label=Label.new();Texts.set_text(label,str(event.text));label.add_theme_font_size_override("font_size",15);label.add_theme_color_override("font_color",Color("e9f3d8"))
	label.add_theme_color_override("font_outline_color",Color("25302a"));label.add_theme_constant_override("outline_size",5);box.add_child(label)
	box.reset_size()
	# The newest caption sits right over the icons, older ones step up; a repeat of the same module replaces its own.
	for other in popups.duplicate():
		if not is_instance_valid(other.node):popups.erase(other)
		elif other.id==str(event.id):other.node.queue_free();popups.erase(other)
	for other in popups:other.slot+=1
	var entry={"node":box,"id":str(event.id),"slot":0,"lift":0.0};popups.append(entry)
	var t=box.create_tween().set_parallel(true)  # bound to the caption: a replaced one takes its tween along
	t.tween_method(func(v):entry.lift=v,0.0,18.0,1.3)
	t.tween_property(box,"modulate:a",0.0,.45).set_delay(.85)
	t.chain().tween_callback(box.queue_free)
