extends Node3D
## One calm trench hint: a fixed-size chip under the trench cell, never over the soldier.
## Near: «E  В окоп». Inside: «E  Выйти   C  Пригнуться» (or «Встать» while crouched).
## Keys are tappable on touch; the chip never scales or jumps — only its words change.
const HEIGHT=28.0
var arena
var cell:=Vector2i.ZERO
var chip:Panel
var row:HBoxContainer
var enter:Panel
var enter_text:Label
var crouch:Panel
var crouch_text:Label
func _ready():
	var canvas=CanvasLayer.new();canvas.layer=4;add_child(canvas)
	chip=Panel.new();chip.name="TrenchHint";canvas.add_child(chip);chip.mouse_filter=Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel",UiKit.style(Color(.16,.21,.18,.82),7))
	row=HBoxContainer.new();chip.add_child(row);row.position=Vector2(5,3);row.add_theme_constant_override("separation",6);row.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var pill=preload("res://scripts/ui/key_pill.gd")
	enter=pill.new();enter.action="interact";enter.side=22;row.add_child(enter)
	enter_text=word()
	crouch=pill.new();crouch.action="hide_trench";crouch.side=22;row.add_child(crouch)
	crouch_text=word()
	chip.hide()
func word()->Label:
	var l=Label.new();row.add_child(l);l.add_theme_font_size_override("font_size",14);l.add_theme_color_override("font_color",Color("f2f1df"));l.custom_minimum_size=Vector2(0,22);l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;l.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return l
func _process(_delta):
	var camera=get_viewport().get_camera_3d()
	var player=arena.player if is_instance_valid(arena) else null
	var soldier=is_instance_valid(player) and player.kind=="soldier" and not player.dead and arena.phase in ["combat","countdown"]
	var inside=soldier and player.occupying_trench and player.cell==cell
	var near=soldier and not player.occupying_trench and Vector2(player.cell-cell).length()<=1.01
	chip.visible=is_instance_valid(camera) and (inside or near)
	if not chip.visible:return
	enter.refresh();crouch.refresh()
	Texts.set_text(enter_text,"Выйти" if inside else "В окоп")
	crouch.visible=inside;crouch_text.visible=inside
	if inside:Texts.set_text(crouch_text,"Встать" if player.hidden_in_trench else "Пригнуться")
	# The crouch word keeps the width of the longer variant, so toggling never resizes the chip.
	var font=crouch_text.get_theme_font("font")
	crouch_text.custom_minimum_size.x=ceilf(maxf(font.get_string_size(Texts.render("Пригнуться"),HORIZONTAL_ALIGNMENT_LEFT,-1,14).x,font.get_string_size(Texts.render("Встать"),HORIZONTAL_ALIGNMENT_LEFT,-1,14).x))
	row.size=row.get_combined_minimum_size()
	chip.size=Vector2(row.size.x+10,HEIGHT)
	var anchor=camera.unproject_position(global_position+Vector3(0,0,.6))
	chip.position=(anchor+Vector2(-chip.size.x*.5,6)).round()
