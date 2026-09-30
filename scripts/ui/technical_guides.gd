extends Control
const DEFAULT_ROOT="res://guides"
var root_path=DEFAULT_ROOT
var tree:Tree
var body:RichTextLabel
var heading:Label
var status:Label
var selected_path=""
var documents:Array=[]
const MEMORY=preload("res://scripts/ui/tablet_memory.gd")
var positions:Dictionary={}
var collapsed:Dictionary={}
var current_scroll=0.0
func _ready():
	var saved=MEMORY.read().get("technical",{})
	selected_path=saved.get("selected","");positions=saved.get("positions",{}).duplicate();collapsed=saved.get("collapsed",{}).duplicate()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiKit.label(self,"Тех. информация",Vector2(22,14),Vector2(470,38),25)
	var refresh_button=UiKit.button(self,"Обновить",Vector2.ZERO,Vector2(150,40),reload);refresh_button.name="Reload"
	tree=Tree.new();add_child(tree);tree.hide_root=true;tree.add_theme_font_size_override("font_size",15);tree.item_selected.connect(select_document)
	body=RichTextLabel.new();add_child(body);body.name="DocumentBody";body.set_meta("text_editor",true);body.bbcode_enabled=false;body.selection_enabled=true;body.scroll_active=true;body.add_theme_font_size_override("normal_font_size",17);body.add_theme_color_override("default_color",UiKit.INK)
	body.get_v_scroll_bar().value_changed.connect(func(value):
		if selected_path!="":positions[selected_path]=value;remember())
	tree.item_collapsed.connect(func(item):
		if item.has_meta("folder"):collapsed[item.get_meta("folder")]=item.collapsed;remember())
	heading=UiKit.label(self,"",Vector2.ZERO,Vector2.ZERO,20);heading.set_meta("text_editor",true)
	status=UiKit.label(self,"",Vector2.ZERO,Vector2.ZERO,12,UiKit.MUTED)
	resized.connect(layout);layout();reload()
func layout():
	get_node("Reload").position=Vector2(size.x-174,16)
	tree.position=Vector2(18,72);tree.size=Vector2(210,size.y-112)
	heading.position=Vector2(246,74);heading.size=Vector2(size.x-268,34)
	body.position=Vector2(246,120);body.size=Vector2(size.x-268,size.y-158)
	status.position=Vector2(20,size.y-32);status.size=Vector2(size.x-40,22)
func reload():
	remember()
	root_path="user://guides" if DirAccess.dir_exists_absolute("user://guides") else DEFAULT_ROOT
	documents.clear();tree.clear();var root=tree.create_item();scan(root_path,root,0)
	Texts.set_text(status,"Документов: %d · %s" % [documents.size(),root_path])
	if documents.is_empty():heading.text="";selected_path="";body.clear();body.append_text(Texts.render("В папке пока нет Markdown-документов."));return
	var chosen=documents.filter(func(entry):return entry.path==selected_path)
	var entry=documents[0] if chosen.is_empty() else chosen[0]
	tree.set_block_signals(true);entry.item.select(0);tree.set_block_signals(false);open_document(entry.path)
func scan(folder:String,parent:TreeItem,depth:int):
	if depth>8:return
	var directories=DirAccess.get_directories_at(folder);directories.sort()
	for directory in directories:
		if directory.begins_with("."):continue
		var item=tree.create_item(parent);item.set_text(0,display_name(directory));item.set_selectable(0,false);item.set_meta("folder",folder.path_join(directory));item.collapsed=collapsed.get(folder.path_join(directory),false)
		scan(folder.path_join(directory),item,depth+1)
	var files=DirAccess.get_files_at(folder);files.sort()
	for filename in files:
		if filename.get_extension().to_lower()!="md":continue
		var path=folder.path_join(filename);var title=document_title(path)
		var item=tree.create_item(parent);item.set_text(0,title);item.set_tooltip_text(0,path);item.set_metadata(0,path)
		documents.append({"path":path,"item":item})
func display_name(value:String)->String:
	var names={"00_start":"Начать здесь","01_design":"Геймдизайн","02_development":"Разработка","03_release":"Альфа и проверки"}
	return Texts.render(names.get(value,value.replace("_"," ")))
func document_title(path:String)->String:
	var file=FileAccess.open(path,FileAccess.READ)
	if file:
		for i in range(8):
			var line=file.get_line()
			if line.begins_with("# "):return line.substr(2).strip_edges()
	return path.get_file().get_basename()
func select_document():
	var item=tree.get_selected()
	if item and item.get_metadata(0)!=null:open_document(item.get_metadata(0))
func open_document(path:String):
	var scroll=float(positions.get(path,0))
	selected_path=path;heading.text=document_title(path);body.clear()
	var file=FileAccess.open(path,FileAccess.READ)
	if file==null:body.append_text(Texts.render("Документ недоступен. Нажми «Обновить»."));return
	if file.get_length()>1048576:body.append_text(Texts.render("Документ слишком большой для просмотра."));return
	var code=false
	for line in file.get_as_text().split("\n"):
		if line.begins_with("```"):code=not code;continue
		if line=="# "+heading.text and not code:continue
		var title=line.begins_with("#") and not code
		if title:
			var level=0
			while level<line.length() and line[level]=="#":level+=1
			body.push_font_size(25 if level==1 else 21);body.push_bold();body.append_text(line.substr(level).strip_edges()+"\n");body.pop();body.pop()
		else:
			var text=line if code else line.replace("**","").replace("`","")
			if text.begins_with("- "):text="• "+text.substr(2)
			body.append_text(text+"\n")
	body.get_v_scroll_bar().set_deferred("value",scroll)
	remember()

func remember():
	MEMORY.read()["technical"]={"selected":selected_path,"positions":positions.duplicate(),"collapsed":collapsed.duplicate()}
