extends Node3D
## The floor of a walk-in room (T-202, one inventory everywhere): what the hero throws away in an upgrade room or
## at the merchant lies here exactly like on the battle field — one item as itself with its E / C card
## (scripts/ui/drop_prompt.gd), several as an army sack picked up by walking over it. Backpack.floor_of finds it
## through the group «item_floor». Left behind when the hero leaves the room, it is gone — like on the field.
var arena
var room:Node3D
## Pickup entries {node, visual, kind, content, blocked} (reward_system.dress_pile).
var piles:Array=[]

static func attach(room_node:Node3D,context)->Node3D:
	var ground=load("res://scripts/room_floor.gd").new();ground.name="ItemFloor";ground.room=room_node;ground.arena=context
	room_node.add_child(ground);return ground
func _enter_tree():add_to_group("item_floor")
func hero()->Node3D:
	var avatar=room.get("avatar") if is_instance_valid(room) else null
	return avatar if is_instance_valid(avatar) else null
## No picking up while the room shows a window (cards, a crate, the vending machine).
func can_pick()->bool:return is_instance_valid(room) and not is_instance_valid(room.get("modal"))
## Backpack.put_down: at the hero's feet.
func drop_items(content:Dictionary):
	var h=hero()
	place(content,h.position if h else Vector3.ZERO)
	Game.sound("inv_drop",self)
func place(content:Dictionary,at:Vector3):
	var node=Node3D.new();add_child(node)
	node.position=Vector3(at.x+arena.reward.look.randf_range(-.15,.15),0,at.z+arena.reward.look.randf_range(-.15,.15))
	piles.append(arena.reward.dress_pile(node,content,self))
func take_away(entry:Dictionary):
	piles.erase(entry)
	if is_instance_valid(entry.node):preload("res://scripts/battle_stage.gd").vanish(entry.node)
## A sack comes back when the hero walks over it again (it was dropped under the hero: step off first).
func _process(_delta):
	var h=hero()
	if h==null or not can_pick():return
	for entry in piles.duplicate():
		if entry.kind!="sack" or not is_instance_valid(entry.node):continue
		var d=Vector2(h.position.x-entry.node.position.x,h.position.z-entry.node.position.z).length()
		if d>.6:entry.blocked=false
		elif not entry.blocked:
			if Backpack.pick_sack(arena,entry.content):take_away(entry);Game.sound("inv_drop",self);arena.toast(Texts.render("Мешок подобран"))
			else:entry.blocked=true
