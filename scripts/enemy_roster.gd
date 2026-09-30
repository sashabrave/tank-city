@tool
extends Control
var arena
func _ready():mouse_filter=Control.MOUSE_FILTER_PASS
func _process(_delta):
	if not Engine.is_editor_hint():queue_redraw()
func items()->Array:
	if not Engine.is_editor_hint() and not is_instance_valid(arena):return []
	var visible_items=[{"kind":"soldier","state":"queued"},{"kind":"tank","state":"active"},{"kind":"buggy","state":"queued"}] if Engine.is_editor_hint() else arena.wave_roster.duplicate()
	while visible_items.size()>36:
		var dead_index=visible_items.find_custom(func(item):return item.state=="dead")
		if dead_index<0:break
		visible_items.remove_at(dead_index)
	return visible_items
func content_height()->float:
	return ceilf(items().size()/6.0)*32.0
func _draw():
	var visible_items=items()
	for i in range(visible_items.size()):
		var item=visible_items[i];var p=Vector2(16+(i%6)*31,16+int(i/6.0)*32)
		preload("res://scripts/ui/enemy_type_icon.gd").draw_icon(self,item.kind,p,Color.WHITE,item.get("weapon",""),item.state)
func _get_tooltip(at_position:Vector2)->String:
	var index=int(at_position.y/32)*6+int(at_position.x/31)
	var entries=items()
	if index<0 or index>=entries.size():return ""
	var item=entries[index]
	return preload("res://scripts/ui/enemy_type_icon.gd").title(item.kind,item.get("weapon",""))+" · "+{"queued":"ожидает выхода","active":"на поле","dead":"уничтожен"}.get(item.state,"")
