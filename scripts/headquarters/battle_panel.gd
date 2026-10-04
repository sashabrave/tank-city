extends Control
## HQ modules over the HQ in battle (author, 4 Oct 2026): no HQ button and no key — small module icons above the
## HQ health bar with a readiness ring (Медпункт also shows its health stock), and every trigger pops a small
## icon with a caption over the HQ («Купол», «Медпункт +1», «Ремонт +1,5»). Visual only.
var arena
const TILE:=34.0
const GAP:=6.0
var popups:Array=[]
func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_preset(Control.PRESET_FULL_RECT)
func anchor_point():
	var camera=get_viewport().get_camera_3d()
	if camera==null or not is_instance_valid(arena) or arena.hq_off_field():return null
	var world=arena.world_pos(arena.base_cell)+Vector3.UP*2.45
	if camera.is_position_behind(world):return null
	return camera.unproject_position(world)
func _process(_delta):
	var hq=arena.headquarters
	visible=arena.phase in ["combat","countdown","paused"] and not hq.modules.is_empty() and anchor_point()!=null
	while not hq.events.is_empty():pop(hq.events.pop_front())
	var at=anchor_point()
	for popup in popups.duplicate():
		if not is_instance_valid(popup.node):popups.erase(popup);continue
		if at!=null:popup.node.position=at+Vector2(-popup.node.size.x*.5,-74-popup.slot*24-popup.lift)
	queue_redraw()
func _draw():
	var at=anchor_point()
	if at==null:return
	var hq=arena.headquarters;var count=hq.modules.size()
	var start=at+Vector2(-(count*TILE+(count-1)*GAP)*.5,-TILE-12)
	for i in range(count):
		var id=hq.modules[i];var rect=Rect2(start+Vector2(i*(TILE+GAP),0),Vector2(TILE,TILE));var center=rect.get_center()
		var ready=hq.readiness(id);var dome=id=="hq_field" and hq.shield_time>0
		draw_circle(center,TILE*.5,Color(.08,.1,.09,.72))
		var texture=UiKit.trimmed(UiKit.icon_texture("headquarters/"+id))
		if texture:draw_texture_rect(texture,rect.grow(-6),false,Color(1,1,1,1.0 if ready>=1 else .55))
		if ready<1:draw_arc(center,TILE*.5-1.5,-PI/2,-PI/2+TAU*ready,40,Color(1,1,1,.85),2.5,true)
		else:draw_arc(center,TILE*.5-1.5,0,TAU,40,Color("8fd4f0") if dome else Color("a6d98f"),2.5,true)
		if id=="hq_medpost":
			var full=HQCatalog.medpost_stock(hq.level(id));var bar=Rect2(rect.position+Vector2(3,TILE+3),Vector2(TILE-6,5))
			draw_rect(bar,Color(.08,.1,.09,.8));draw_rect(Rect2(bar.position,Vector2(bar.size.x*clampf(hq.medpost_stock/maxf(full,1),0,1),bar.size.y)),Color("7ed37a"))
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
