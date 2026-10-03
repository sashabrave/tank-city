extends CanvasLayer
## Tester tool, everywhere in the game: right click on any interface picture opens its card — file, id, name,
## group, where else it is used (data/icon_catalog.json, built by tools/art/build_icon_catalog.py) — with a field
## «what to draw» and a button that files it on the task board together with a screenshot of the moment.
const CATALOG:="res://data/icon_catalog.json"
var catalog:Dictionary={}
var root:Control
var shot:Image
var was_paused:=false
var note_edit:TextEdit
var picked:Dictionary={}

func _ready():
	layer=121;process_mode=Node.PROCESS_MODE_ALWAYS;name="IconInspector"

func _input(event):
	if root:
		if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:get_viewport().set_input_as_handled();close()
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT):return
	if get_tree().root.has_node("TaskBoardView"):return
	var hit=picture_at(event.position)
	if hit.is_empty():return
	get_viewport().set_input_as_handled()
	if DisplayServer.get_name()!="headless":shot=get_viewport().get_texture().get_image()
	open(hit)

## The topmost visible picture under the point: TextureRect, TextureButton or a Button icon.
func picture_at(point:Vector2)->Dictionary:
	var best:={};var best_key:=[-INF,-1]
	var order:=[0]
	walk(get_tree().root,point,order,best_key,best)
	return best

func walk(node:Node,point:Vector2,order:Array,best_key:Array,best:Dictionary):
	if node==self:return
	if node is CanvasItem and not node.visible:return
	if node is Control:
		order[0]+=1
		var texture:Texture2D=null
		if node is TextureRect:texture=node.texture
		elif node is TextureButton:texture=node.texture_normal
		elif node is Button:texture=node.icon
		if texture and node.modulate.a>.05 and node.get_global_rect().has_point(point - layer_offset(node)):
			var key=[layer_of(node),order[0]]
			if key[0]>best_key[0] or (key[0]==best_key[0] and key[1]>best_key[1]):
				best_key[0]=key[0];best_key[1]=key[1]
				best.clear();best.merge({"node":node,"texture":texture})
	for child in node.get_children():walk(child,point,order,best_key,best)

func layer_of(node:Node)->int:
	var parent=node
	while parent:
		if parent is CanvasLayer:return parent.layer
		parent=parent.get_parent()
	return 0

func layer_offset(node:Node)->Vector2:
	var parent=node
	while parent:
		if parent is CanvasLayer:return parent.offset
		parent=parent.get_parent()
	return Vector2.ZERO

static func source_path(texture:Texture2D)->String:
	if texture==null:return ""
	if texture.has_meta("trim_source"):return str(texture.get_meta("trim_source"))
	if texture is AtlasTexture and texture.atlas:return source_path(texture.atlas)
	return texture.resource_path

func entry_for(path:String)->Dictionary:
	if catalog.is_empty():
		var file=FileAccess.open(CATALOG,FileAccess.READ)
		var parsed=JSON.parse_string(file.get_as_text()) if file else null
		catalog={}
		if parsed is Dictionary:
			for item in parsed.get("icons",[]):catalog[item.path]=item
	return catalog.get(path,{})

func open(hit:Dictionary):
	was_paused=get_tree().paused;get_tree().paused=true
	var path=source_path(hit.texture)
	var info=entry_for(path)
	picked={"path":path,"info":info,"node_path":str(hit.node.get_path())}
	root=Control.new();add_child(root);root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade=ColorRect.new();root.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,.5)
	shade.gui_input.connect(func(e):if e is InputEventMouseButton and e.pressed:close())
	var visible=get_viewport().get_visible_rect().size
	var size=Vector2(720,520);var panel=UiKit.glass(root,((visible-size)*.5).round(),size)
	var preview=TextureRect.new();preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	panel.add_child(preview);preview.texture=hit.texture;preview.position=Vector2(24,24);preview.size=Vector2(150,150);preview.clip_contents=true
	var names:Array=info.get("names",[])
	var title=", ".join(PackedStringArray(unique(names))) if not names.is_empty() else Texts.localized("Нет в каталоге")
	var heading=UiKit.label(panel,title,Vector2(196,22),Vector2(500,34),22);heading.clip_text=true
	UiKit.label(panel,str(info.get("group","")),Vector2(196,58),Vector2(500,22),15,UiKit.MUTED)
	var lines=[]
	if info.has("ids"):lines.append("id: "+", ".join(PackedStringArray(info.ids)))
	lines.append(Texts.localized("Где:")+" "+str(info.get("context",Texts.localized("неизвестно"))))
	if info.get("note","")!="":lines.append(str(info.note))
	lines.append(Texts.localized("Файл:")+" "+(path if path!="" else Texts.localized("картинка собрана в коде")))
	var body=Label.new();body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.clip_text=true;body.custom_minimum_size=Vector2(500,0)
	body.add_theme_font_size_override("font_size",14);body.add_theme_color_override("font_color",UiKit.MUTED.lightened(.3))
	panel.add_child(body);body.text="\n".join(PackedStringArray(lines));body.position=Vector2(196,88);body.size=Vector2(500,150)
	note_edit=TextEdit.new();panel.add_child(note_edit);note_edit.position=Vector2(24,252);note_edit.size=Vector2(672,170);note_edit.name="IconNote"
	note_edit.placeholder_text=Texts.localized("Что здесь должно быть нарисовано?");note_edit.set_meta("text_editor",true);note_edit.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY
	UiKit.button(panel,"Копировать id",Vector2(24,446),Vector2(170,48),func():DisplayServer.clipboard_set(", ".join(PackedStringArray(info.get("ids",[path])))))
	UiKit.button(panel,"Закрыть",Vector2(366,446),Vector2(140,48),close)
	UiKit.button(panel,"На доску задач",Vector2(518,446),Vector2(178,48),send,true).name="SendIcon"
	note_edit.call_deferred("grab_focus")

static func unique(items:Array)->Array:
	var out=[]
	for item in items:
		if item not in out:out.append(item)
	return out

func send():
	var info:Dictionary=picked.info
	var names:Array=unique(info.get("names",[]))
	var label=", ".join(PackedStringArray(names.slice(0,2))) if not names.is_empty() else picked.path.get_file()
	var comment=note_edit.text.strip_edges()
	var details=["Картинка: "+picked.path,"Группа: "+str(info.get("group","—")),"id: "+", ".join(PackedStringArray(info.get("ids",[]))),"Где: "+str(info.get("context","—")),"Узел: "+picked.node_path]
	TaskBoard.add("Арт: "+label,(comment+"\n\n" if comment!="" else "")+"\n".join(PackedStringArray(details)),"polish",2,shot)
	close()

func close():
	if root:root.queue_free();root=null
	get_tree().paused=was_paused;Game.reset_input()
