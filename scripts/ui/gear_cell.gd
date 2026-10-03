class_name GearCell
extends Button
## One cell of the gear screen (T-113): shows an item, can be selected (tap / E), activated (double tap / E on
## the selected cell), dragged onto another cell or the discard zone, and dropped with a right click.
## The page owns the rules; the cell only reports gestures through callables.
var key:=""            # "slot:0", "bag:3", "ability:0", "weapon", …
var item_kind:=""      # "ammo", "recipe", "" for fixed cells
var draggable:=false
var on_select:Callable
var on_activate:Callable
var on_drop:Callable   # (from_key:String, to_key:String)
var on_discard:Callable
var last_press:=-1000
const DOUBLE_MS:=350

func _ready():
	focus_mode=Control.FOCUS_ALL
	gui_input.connect(_cell_input)
func _cell_input(event:InputEvent):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_RIGHT:
			if on_discard.is_valid():on_discard.call(key)
			accept_event();return
		if event.button_index==MOUSE_BUTTON_LEFT:
			var now=Time.get_ticks_msec()
			if event.double_click or now-last_press<DOUBLE_MS:
				last_press=-1000
				if on_activate.is_valid():on_activate.call(key)
			else:
				last_press=now
				if on_select.is_valid():on_select.call(key)
	if event is InputEventScreenTouch and event.pressed and event.double_tap:
		if on_activate.is_valid():on_activate.call(key)
## The dragged item is the same cell, same size, lifted a little with an orange outline and a soft shadow;
## the cell it left stays as a faint trace until the drop (author, 2026-10-03).
func _get_drag_data(_at:Vector2):
	if not draggable:return null
	var holder=Control.new()
	var lifted=Panel.new();holder.add_child(lifted);lifted.size=size;lifted.position=-size*.5+Vector2(0,-8)
	var frame=get_theme_stylebox("normal").duplicate() if get_theme_stylebox("normal") is StyleBoxFlat else StyleBoxFlat.new()
	frame.border_color=UiKit.ORANGE;frame.set_border_width_all(3);frame.shadow_color=Color(0,0,0,.45);frame.shadow_size=12;frame.shadow_offset=Vector2(0,8)
	lifted.add_theme_stylebox_override("panel",frame)
	for child in get_children():
		if child is TextureRect or child is Label:lifted.add_child(child.duplicate())
	set_drag_preview(holder)
	modulate.a=.35
	return {"gear_key":key}
func _notification(what):
	if what==NOTIFICATION_DRAG_END:modulate.a=1.0
func _can_drop_data(_at:Vector2,data)->bool:return data is Dictionary and data.has("gear_key") and data.gear_key!=key and on_drop.is_valid()
func _drop_data(_at:Vector2,data):on_drop.call(str(data.gear_key),key)
func icon_texture()->Texture2D:
	var picture=get_node_or_null("Art")
	return picture.texture if picture is TextureRect else null
