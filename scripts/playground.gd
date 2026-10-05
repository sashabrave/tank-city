class_name Playground
extends Node3D
## A playground on the one field engine (guides/02_development/07_one_world.md): the layout, dressing and
## interactables of a place where the hero walks. Everything else is the Arena — the hero Actor (movement, speed,
## collision, animation), shooting (Gun → CombatSystem), abilities (RunAbility), the effects bus, the HUD, the
## inventory and the drop floor. A playground never moves, shoots or heals the hero itself.
## Kinds (field_mode): «service» — a room between fields (service_room.gd, merchant_room.gd); «hub» — the hub on its
## practice-run arena (hub.gd); «battle» — a generated battle field under the playground's own rules (the sandbox,
## sandbox/sandbox_ground.gd). Every one enters through arena.begin_playground (main.enter_playground).
## Towards the arena (arena.begin_playground → scripts/systems/service_field.gd or arena.begin_room):
##   field_mode()     — «service», «hub» or «battle» (above);
##   battle_rules()   — a «battle» playground's overrides for begin_room: {mode, size, difficulty, biome, waves};
##   take_defeat(why) — true when the playground handles the hero's defeat itself (the sandbox respawns);
##   own_look()       — the light, weather and outskirts follow this playground's palette and `index` (the hub);
##   field_size()     — side of the square grid, cells (9: the room floor);
##   solid_cells()    — world cells that block like walls (props, the edges, a closed exit);
##   start_position() — where the hero stands when the room opens;
##   field_ready()    — once the hero is on the field (pickups, practice targets);
##   interact()       — E on the field (the arena's dispatcher calls it);
##   window_open()    — a window of the room holds the field (arena phase «upgrade»), like the battle's cards.
## `index` is where the hero is: the route stage of a room, the hub's visit number (its look), 0 in the sandbox.
## The arena's `room_index` stays the route field (the last field while in a room: its biome and prizes).
## Interactables: world prompts (interaction_prompt.gd) take this node as their context — it exposes `avatar` (the
## arena's hero) and `modal`; RoomLayout spots answer near(avatar) and use(root, done).
signal completed(index:int)
signal hub_requested
var arena
var index:=2
## UI layer of the room (heading, buttons, its windows).
var root:Control
## The room's open window (cards, shop, purchase), null when none.
var modal:Control
## The hero on the field: the arena's own soldier.
var avatar:Node3D:
	get:return arena.player if arena!=null and is_instance_valid(arena.player) else null
## Side of a room floor grid, cells.
const SIZE:=9
const EXIT_CELL:=Vector2i(4,1)

func field_mode()->String:return "service"
func battle_rules()->Dictionary:return {}
func take_defeat(_reason:String)->bool:return false
func own_look()->bool:return false
func field_size()->int:return SIZE
## Back row of the free floor (world z); the floor runs to z = 4 and x = −3…3.
func floor_back()->int:return -2
## Cells of the free floor that the room's own props take (world cells), besides the common spots.
func blocked_floor()->Array:return []
## The common RoomLayout spots (weapon crate, vending machine, «Фортуна») stand on solid cells in every room.
static func spot_cells()->Array:
	return [RoomLayout.WEAPON_CRATE,RoomLayout.MACHINE,RoomLayout.FORTUNE].map(func(p):return Vector2i(roundi(p.x),roundi(p.z)))
func walkable(c:Vector2i)->bool:return absi(c.x)<=3 and c.y>=floor_back() and c.y<=4 and c not in blocked_floor() and c not in spot_cells()
## Every cell of the square that is not free floor; the exit cell too while the exit is closed.
func solid_cells()->Array:
	var result=[];var half=int(SIZE/2.0)
	for x in range(-half,half+1):
		for z in range(-half,half+1):
			var c=Vector2i(x,z)
			if c==EXIT_CELL and exit_open():continue
			if not walkable(c):result.append(c)
	return result
func exit_open()->bool:return false
func start_position()->Vector3:return Vector3(0,0,3)
func field_ready():pass
func interact():pass

## Puts the hero on a spot at once (tests, scripted moves): position, cell and a finished step.
func place_hero(at:Vector3):
	var hero=avatar
	if hero==null:return
	hero.position=Vector3(at.x,0,at.z);hero.moving=false;hero.quarter_destination=hero.position
	hero.cell=arena.grid_pos(hero.position);hero.destination=hero.cell

## Any window of this room (its own, a machine's, a confirmation) — the field holds while one is open.
func window_open()->bool:
	if is_instance_valid(modal):return true
	for node in get_tree().get_nodes_in_group("selection_scope"):
		if is_instance_valid(node) and not node.is_queued_for_deletion() and is_ancestor_of(node) and node is CanvasItem and node.is_visible_in_tree():return true
	return false
func close_window():
	if is_instance_valid(modal):
		if modal.get_parent():modal.get_parent().remove_child(modal)
		modal.queue_free()
	modal=null;Game.reset_input()

## Heading plate (top right, clear of the battle HUD), «Вернуться в хаб» and the continue button.
func build_ui(title:String,subtitle:String,continue_text:String,on_continue:Callable)->Button:
	add_to_group("notification_context")
	var canvas=CanvasLayer.new();canvas.name="RoomUi";add_child(canvas)
	root=Control.new();root.name="Root";canvas.add_child(root);root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var size=get_viewport().get_visible_rect().size
	var plate=UiKit.glass(root,Vector2(size.x-448,20),Vector2(420,104),Color("242d27ed"));plate.name="Heading";plate.mouse_filter=Control.MOUSE_FILTER_IGNORE
	UiKit.accent(UiKit.label(plate,title,Vector2(18,8),Vector2(390,48),28))
	var line=UiKit.label(plate,subtitle,Vector2(18,58),Vector2(390,40),16);line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var hub=UiKit.button(root,"Вернуться в хаб",Vector2(size.x-278,136),Vector2(250,48),func():hub_requested.emit());hub.name="HubButton"
	var go=UiKit.button(root,continue_text,Vector2(size.x-330,size.y-90),Vector2(290,60),on_continue,true);go.name="ContinueButton"
	return go

func _process(_delta):
	# Esc closes a window of the room (the battle pause is the arena's while the field is free).
	if window_open() and Input.is_action_just_pressed("pause"):close_window()
