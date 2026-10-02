extends CanvasLayer
## Tester task board over any screen. mode "add": a quick form (F8) with an auto screenshot;
## mode "board": four status columns (F9, or «Задачи» in the hub tools). The game is paused while open.
const COLUMN_W=300.0
var mode="board"
## Board view: "board" (four columns) or "me" (what needs the author).
var view="board"
var shot:Image
var root:Control
var was_paused=false
var title_edit:LineEdit
var note_edit:TextEdit
var type_choice="bug"
var priority_choice=2
var keep_shot:CheckBox
static func open(tree:SceneTree,start_mode:String,screenshot:Image=null):
	if tree.root.has_node("TaskBoardView"):return
	var view=load("res://scripts/ui/task_board_view.gd").new();view.mode=start_mode;view.shot=screenshot
	tree.root.add_child(view)
func _ready():
	name="TaskBoardView";layer=120;process_mode=Node.PROCESS_MODE_ALWAYS
	was_paused=get_tree().paused;get_tree().paused=true
	root=Control.new();add_child(root);root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade=ColorRect.new();root.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,.55)
	build()
func build():
	for child in root.get_children():
		if not child is ColorRect:child.queue_free()
	if mode=="add":build_form()
	else:build_board()
## The area really visible on screen (the window may be narrower than the base resolution).
func screen_size()->Vector2:
	var visible=get_viewport().get_visible_rect().size
	return Vector2(minf(visible.x,root.size.x if root.size.x>0 else visible.x),minf(visible.y,root.size.y if root.size.y>0 else visible.y))
func close():
	get_tree().paused=was_paused;Game.reset_input();queue_free()
func _input(event):
	if event.is_action_pressed("pause") or (event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		if mode=="add" and has_meta("from_board"):mode="board";build()
		else:close()

func build_form():
	var size=Vector2(640,470);var panel=UiKit.glass(root,((screen_size()-size)*.5).round(),size)
	UiKit.label(panel,"Новая задача",Vector2(24,16),Vector2(400,36),24)
	UiKit.label(panel,"Попадёт в бэклог. Скриншот и версия прикладываются сами.",Vector2(24,52),Vector2(590,22),14,UiKit.MUTED)
	title_edit=LineEdit.new();panel.add_child(title_edit);title_edit.position=Vector2(24,86);title_edit.size=Vector2(592,44);title_edit.placeholder_text=Texts.localized("Коротко: что не так или что хочется");title_edit.name="TaskTitle"
	title_edit.text_submitted.connect(func(_t):save())
	note_edit=TextEdit.new();panel.add_child(note_edit);note_edit.position=Vector2(24,140);note_edit.size=Vector2(592,110);note_edit.placeholder_text=Texts.localized("Подробности, если нужно");note_edit.name="TaskNote"
	note_edit.set_meta("text_editor",true);title_edit.set_meta("text_editor",true)
	UiKit.label(panel,"Тип",Vector2(24,262),Vector2(100,24),15,UiKit.MUTED)
	choice_row(panel,Vector2(110,258),TaskBoard.TYPES.map(func(t):return [t,TaskBoard.TYPE_NAMES[t]]),type_choice,func(v):type_choice=v)
	UiKit.label(panel,"Важность",Vector2(24,310),Vector2(100,24),15,UiKit.MUTED)
	choice_row(panel,Vector2(110,306),[[1,"Высокая"],[2,"Обычная"],[3,"Низкая"]],priority_choice,func(v):priority_choice=v)
	keep_shot=CheckBox.new();panel.add_child(keep_shot);keep_shot.position=Vector2(24,352);Texts.set_text(keep_shot,"Приложить скриншот");keep_shot.button_pressed=shot!=null;keep_shot.disabled=shot==null
	UiKit.button(panel,"Отмена",Vector2(300,404),Vector2(150,46),func():
		if has_meta("from_board"):mode="board";build()
		else:close())
	UiKit.button(panel,"Сохранить [Enter]",Vector2(462,404),Vector2(154,46),save,true).name="SaveTask"
	title_edit.call_deferred("grab_focus")
func choice_row(parent:Control,pos:Vector2,options:Array,current,pick:Callable):
	var buttons=[]
	for i in range(options.size()):
		var b=UiKit.button(parent,options[i][1],pos+Vector2(i*128,0),Vector2(120,38),func():pass);b.toggle_mode=true;b.button_pressed=options[i][0]==current;b.add_theme_font_size_override("font_size",14);buttons.append(b)
	for i in range(buttons.size()):
		var value=options[i][0]
		buttons[i].pressed.connect(func():
			pick.call(value)
			for j in range(buttons.size()):buttons[j].set_pressed_no_signal(j==i))
func save():
	if title_edit.text.strip_edges()=="":title_edit.grab_focus();return
	TaskBoard.add(title_edit.text,note_edit.text,type_choice,priority_choice,shot if keep_shot.button_pressed else null)
	if has_meta("from_board"):mode="board";build()
	else:close()

func build_board():
	var screen=screen_size()
	var size=Vector2(minf(screen.x-40,COLUMN_W*4+24*5),screen.y-60);var panel=UiKit.glass(root,((screen-size)*.5).round(),size)
	UiKit.label(panel,"Задачи",Vector2(24,14),Vector2(300,36),24)
	UiKit.label(panel,"F8 — новая задача из любого места игры · Esc — закрыть",Vector2(24,50),Vector2(600,20),13,UiKit.MUTED)
	var add=UiKit.button(panel,"+ Задача",Vector2(size.x-268,16),Vector2(180,42),func():mode="add";set_meta("from_board",true);build(),true);add.name="AddTask"
	var close_b=UiKit.button(panel,"",Vector2(size.x-72,16),Vector2(48,42),close);close_b.icon=UiKit.interface_icon("close");close_b.expand_icon=true;close_b.add_theme_constant_override("icon_max_width",18)
	# Two views: the whole board, or «Для меня» — only what needs the author: decisions and checks.
	var views=[["board","Вся доска"],["me","Для меня · %d" % (TaskBoard.for_me("decide").size()+TaskBoard.for_me("check").size())]]
	for i in range(2):
		var key=views[i][0]
		var t=UiKit.button(panel,views[i][1],Vector2(size.x-620+i*170,16),Vector2(160,42),func():view=key;build(),key==view);t.name="View_"+key;t.add_theme_font_size_override("font_size",15)
	if view=="me":
		build_me(panel,size);return
	var col_w=(size.x-24*5)/4.0
	for i in range(TaskBoard.STATUSES.size()):
		var status=TaskBoard.STATUSES[i];var x=24+i*(col_w+24)
		var items=TaskBoard.column(status)
		UiKit.label(panel,"%s · %d" % [TaskBoard.STATUS_NAMES[status],items.size()],Vector2(x,84),Vector2(col_w,26),17)
		var scroll=ScrollContainer.new();panel.add_child(scroll);scroll.position=Vector2(x,116);scroll.size=Vector2(col_w,size.y-136);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.name="Column_"+status
		var box=VBoxContainer.new();scroll.add_child(box);box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;box.add_theme_constant_override("separation",8)
		for task in items:card(box,task,col_w-12,i)
## «Для меня»: left — decisions (questions to the author), right — done work waiting for the author's check.
func build_me(panel:Panel,size:Vector2):
	var col_w=(size.x-24*3)/2.0
	for i in range(2):
		var kind=["decide","check"][i];var x=24+i*(col_w+24)
		var items=TaskBoard.for_me(kind)
		UiKit.label(panel,"%s · %d" % [["Решить","Проверить в игре"][i],items.size()],Vector2(x,84),Vector2(col_w,26),17)
		var scroll=ScrollContainer.new();panel.add_child(scroll);scroll.position=Vector2(x,116);scroll.size=Vector2(col_w,size.y-136);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.name="Me_"+kind
		var box=VBoxContainer.new();scroll.add_child(box);box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;box.add_theme_constant_override("separation",8)
		for task in items:card(box,task,col_w-12,TaskBoard.STATUSES.find(str(task.get("status","backlog"))))
		if items.is_empty():UiKit.label(box,"Пусто",Vector2.ZERO,Vector2(col_w,30),15,UiKit.MUTED)
func card(box:VBoxContainer,task:Dictionary,width:float,column:int):
	var tint={"bug":Color("5a3a34"),"idea":Color("34485a"),"polish":Color("3c4a36"),"question":Color("5a4a2a")}.get(task.get("type","idea"),Color("3c4a36"))
	var c=Panel.new();box.add_child(c);c.custom_minimum_size=Vector2(width,104);c.name="Task_"+str(task.id)
	var style=StyleBoxFlat.new();style.bg_color=tint;style.set_corner_radius_all(8);style.border_color=UiKit.ORANGE if int(task.get("priority",2))==1 else Color(1,1,1,.08);style.set_border_width_all(2);c.add_theme_stylebox_override("panel",style)
	c.tooltip_text=str(task.get("note",""))+("\n"+str(task.shot) if str(task.get("shot",""))!="" else "")
	# The author's own words: shown exactly as typed (no auto case or translation).
	var title=UiKit.label(c,"",Vector2(10,6),Vector2(width-20,48),15);title.set_meta("text_editor",true);title.text=str(task.title);title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;title.clip_text=true
	UiKit.label(c,"%s · %s · %s%s" % [task.id,TaskBoard.TYPE_NAMES.get(task.get("type",""),""),TaskBoard.PRIORITY_NAMES.get(int(task.get("priority",2)),""),(" · "+str(task.version)) if str(task.get("version",""))!="" else ""],Vector2(10,56),Vector2(width-100,20),12,Color(1,1,1,.62))
	var statuses=TaskBoard.STATUSES
	if column>0:UiKit.button(c,"◀",Vector2(width-90,60),Vector2(38,34),func():TaskBoard.move(task.id,statuses[column-1]);build()).add_theme_font_size_override("font_size",14)
	if column<statuses.size()-1:UiKit.button(c,"▶",Vector2(width-46,60),Vector2(38,34),func():TaskBoard.move(task.id,statuses[column+1]);build()).add_theme_font_size_override("font_size",14)
