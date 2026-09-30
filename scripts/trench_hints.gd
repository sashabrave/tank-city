extends Node3D
## Trench hints that never cover the field: near the trench — a small E to get in; inside — C under
## the cell (hide / rise) and a smaller E above the head (leave). Hidden in the trench both stay.
var arena
var cell:=Vector2i.ZERO
var enter:Panel
var hide_key:Panel
func _ready():
	var canvas=CanvasLayer.new();canvas.layer=4;add_child(canvas)
	var pill=preload("res://scripts/ui/key_pill.gd")
	enter=pill.new();enter.action="interact";canvas.add_child(enter)
	hide_key=pill.new();hide_key.action="hide_trench";canvas.add_child(hide_key)
func _process(_delta):
	var camera=get_viewport().get_camera_3d()
	var player=arena.player if is_instance_valid(arena) else null
	var soldier=is_instance_valid(player) and player.kind=="soldier" and not player.dead and arena.phase in ["combat","countdown"]
	var inside=soldier and player.occupying_trench and player.cell==cell
	var near=soldier and not player.occupying_trench and Vector2(player.cell-cell).length()<=1.01
	enter.visible=is_instance_valid(camera) and (inside or near);hide_key.visible=is_instance_valid(camera) and inside
	if not enter.visible:return
	enter.refresh();hide_key.refresh()
	if inside:
		# Leave: small E above the head; hide: C under the cell.
		enter.scale=Vector2.ONE*.67
		var head=global_position+Vector3.UP*(.75 if player.hidden_in_trench else 1.25)
		enter.position=camera.unproject_position(head)-enter.size*enter.scale*.5-Vector2(0,10)
		hide_key.position=camera.unproject_position(global_position+Vector3(0,0,.62))-hide_key.size*.5
	else:
		enter.scale=Vector2.ONE*.8
		enter.position=camera.unproject_position(global_position+Vector3(0,.25,0))-enter.size*enter.scale*.5
