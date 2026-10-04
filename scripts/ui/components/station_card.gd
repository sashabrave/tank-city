extends PanelContainer
## One station card (scenes/ui/components/station_card.tscn). Layout, sizes, fonts and colours live in the scene,
## so the author edits every station card in the Godot editor; this script only fills data and reports presses.
## The station screen (scripts/ui/station_screen.gd) instantiates the scene once per item, adds it to the grid, then calls setup().
signal action_pressed(action_id:String)
signal info_pressed
## Outline while the action button has keyboard / gamepad focus.
@export var focus_style:StyleBox
## The main action of an item marked primary (buy, upgrade) uses these instead of the plain button styles.
@export var primary_style:StyleBox
@export var primary_hover_style:StyleBox
@export var primary_font_color:=Color("20271f")
## Disabled button text when the price is more than the wallet («Не хватает»).
@export var short_font_color:=Color(0.816,0.439,0.361,.9)
## Progress fill once the item is at its cap (calm, not the accent colour).
@export var max_fill_style:StyleBox
@onready var icon:TextureRect=$Layout/Head/Icon
@onready var title:Label=$Layout/Head/Names/Title
@onready var level:Label=$Layout/Head/Names/Level
@onready var badge:PanelContainer=$Layout/Head/Names/Badges/Badge
@onready var new_badge:PanelContainer=$Layout/Head/Names/Badges/NewBadge
@onready var info:Button=$Layout/Head/Info
@onready var gist:Label=$Layout/Gist
@onready var change:HBoxContainer=$Layout/Change
@onready var action:Button=$Layout/Action
@onready var progress:ProgressBar=$Layout/Progress
var action_id=""
var idle_style:StyleBox
## Title font size from the scene; long single words shrink below it instead of breaking mid-word.
var title_size:=17
const TITLE_MIN_SIZE=12

func _ready():
	info.pressed.connect(func():info_pressed.emit())
	action.pressed.connect(func():if action_id!="":action_pressed.emit(action_id))
	UiKit.press_bounce(info);UiKit.press_bounce(action)
	title.resized.connect(fit_title)
	title_size=title.get_theme_font_size("font_size")
	# A tap on the card itself opens the full card too.
	gui_input.connect(func(e):if e is InputEventMouseButton and e.pressed and e.button_index==MOUSE_BUTTON_LEFT:info_pressed.emit())
	action.focus_entered.connect(func():if focus_style:add_theme_stylebox_override("panel",focus_style))
	action.focus_exited.connect(func():if idle_style:add_theme_stylebox_override("panel",idle_style))
	# Prices («140 ◈») and «было → станет» rows draw the currency icon inline, as UiKit labels do.
	for widget in [action,$Layout/Change/Value,level]:
		var inline=preload("res://scripts/ui/currency_icons.gd").new();widget.add_child(inline)

## item: {id,title,icon,texture?,caption,level?,cap?}; detail: the station's detail(tab,id);
## look: {kind,label,chip,bg,border,tooltip,new_label,new_chip,short} from the station screen's status rules.
func setup(item:Dictionary,detail:Dictionary,look:Dictionary):
	name="Item_"+str(item.id)
	var kind=str(look.get("kind","owned"))
	# Card colour by status; radius, border width and margins stay as set in the scene.
	idle_style=get_theme_stylebox("panel").duplicate()
	if idle_style is StyleBoxFlat:
		idle_style.bg_color=UiKit.surface_color(look.get("bg",idle_style.bg_color));idle_style.border_color=UiKit.surface_border(look.get("border",idle_style.border_color))
	add_theme_stylebox_override("panel",idle_style)
	if focus_style is StyleBoxFlat and idle_style is StyleBoxFlat:
		focus_style=focus_style.duplicate();focus_style.bg_color=idle_style.bg_color
	icon.texture=item.get("texture",UiKit.trimmed(UiKit.icon_texture(str(detail.get("icon",item.get("icon",item.id))))))
	UiKit.locked_preview(icon,kind in ["locked","soon"])
	if kind in ["soon","locked"]:icon.modulate.a=.55 if kind=="soon" else .8
	Texts.set_text(title,str(item.get("title","")))
	fit_title()
	chip(badge,str(look.get("label","")),look.get("chip",Color.WHITE),str(look.get("tooltip","")))
	new_badge.visible=str(look.get("new_label",""))!=""
	if new_badge.visible:chip(new_badge,str(look.new_label),look.get("new_chip",Color.WHITE),Texts.localized("Открыто недавно"))
	var text=str(detail.get("text",""))
	gist.visible=text!=""
	if gist.visible:Texts.set_text(gist,text)
	var row=main_row(detail.get("rows",[]))
	var lines:Array=detail.get("lines",[]).filter(func(l):return str(l)!="")
	change.visible=not row.is_empty() or not lines.is_empty()
	var value:Label=$Layout/Change/Value
	if not row.is_empty():
		Texts.set_text($Layout/Change/Name,str(row[0]));Texts.set_text(value,row_value(row));value.show()
		if str(row[1])==str(row[2]):value.add_theme_color_override("font_color",title.get_theme_color("font_color"))
	elif not lines.is_empty():
		Texts.set_text($Layout/Change/Name,str(lines[0]));value.hide()
	var main=main_action(detail.get("actions",[]));var caption=str(item.get("caption",""))
	if main.is_empty():
		# Nothing to do here: the caption («Нужен чертёж», «Построено») sits in the button's place, not twice.
		level.hide();action_id="";Texts.set_text(action,caption);action.disabled=true
	else:
		# A price in the caption («Открыть · 120 ◈», «90 ◈») is already on the button.
		var priced=func(t:String):return "◈" in t or "док." in t
		Texts.set_text(level,caption);level.visible=caption!="" and not (priced.call(caption) and priced.call(str(main.text)))
		action_id=str(main.id);action.name="Action_"+action_id;Texts.set_text(action,str(main.text))
		var enabled=main.get("enabled",true);action.disabled=not enabled
		if main.get("primary",false) and enabled and primary_style:
			action.add_theme_stylebox_override("normal",primary_style)
			if primary_hover_style:action.add_theme_stylebox_override("hover",primary_hover_style)
			action.add_theme_color_override("font_color",primary_font_color);action.add_theme_color_override("font_hover_color",primary_font_color)
		if not enabled and look.get("short",false):action.add_theme_color_override("font_disabled_color",short_font_color)
	# Upgrade progress: level / cap; empty while locked, full and calm at the cap; none without levels.
	var cap=int(item.get("cap",0))
	progress.modulate.a=1.0 if cap>0 else 0.0
	if cap>0:
		progress.max_value=cap;progress.value=0 if kind in ["locked","soon"] else clampi(int(item.get("level",0)),0,cap)
		if progress.value>=cap and max_fill_style:progress.add_theme_stylebox_override("fill",max_fill_style)
		progress.tooltip_text="%d / %d" % [int(progress.value),cap]

func chip(box:PanelContainer,text:String,color:Color,tooltip:String):
	var style=box.get_theme_stylebox("panel").duplicate()
	if style is StyleBoxFlat:style.bg_color=Color(color,.16);style.border_color=Color(color,.5)
	box.add_theme_stylebox_override("panel",style);box.tooltip_text=tooltip
	var label:Label=box.get_node("Text");Texts.set_text(label,text);label.add_theme_color_override("font_color",color.lightened(.15))

## The main action: the one marked primary, otherwise the first.
static func main_action(actions:Array)->Dictionary:
	for a in actions:
		if a.get("primary",false):return a
	return actions[0] if not actions.is_empty() else {}
## The «было → станет» row worth showing: the first that changes, otherwise the first.
static func main_row(rows:Array)->Array:
	for row in rows:
		if str(row[1])!=str(row[2]):return row
	return rows[0] if not rows.is_empty() else []
static func row_value(row:Array)->String:
	return "%s → %s" % [str(row[1]),str(row[2])] if str(row[1])!=str(row[2]) else str(row[1])
## Two lines at most and never «…» or a word split in the middle: the size goes down until the longest word fits.
func fit_title():
	var width=title.size.x-2
	if width<=0:return
	var font=title.get_theme_font("font");var fs=title_size
	var words=Array(title.text.split(" ",false))
	while fs>TITLE_MIN_SIZE and words.any(func(w):return font.get_string_size(w,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x>width):fs-=1
	if title.get_theme_font_size("font_size")!=fs:title.add_theme_font_size_override("font_size",fs)
