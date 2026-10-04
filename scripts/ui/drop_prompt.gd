extends Node3D
## A single dropped item on the field (author, 2026-10-03): when the soldier comes close a small card pops
## up over it — picture, name in its rarity colour, its numbers next to what is in hand — and two keys:
## E — use it now (take the gun / load the ammo / heal; what was in hand drops here instead),
## C — put it in the backpack, or «Нет места» when the backpack is full.
## Several items at once still drop as a sack that is picked up by walking over it.
const REACH:=1.15
var arena
## The room floor this item lies on (scripts/room_floor.gd, T-202); null — the battle field.
var ground=null
var pickup:Dictionary={}
var chip:PanelContainer
var use_key
var use_text:Label
var bag_key
var bag_text:Label
func _ready():
	var canvas=CanvasLayer.new();canvas.layer=5;add_child(canvas)
	chip=PanelContainer.new();chip.name="DropCard";canvas.add_child(chip);chip.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style=UiKit.style(Color(.1,.13,.11,.9),10,Color(1,1,1,.14));style.content_margin_left=12;style.content_margin_right=12;style.content_margin_top=10;style.content_margin_bottom=10
	chip.add_theme_stylebox_override("panel",style)
	var column=VBoxContainer.new();chip.add_child(column);column.name="Column";column.add_theme_constant_override("separation",8);column.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var keys=HBoxContainer.new();column.add_child(keys);keys.name="Keys";keys.add_theme_constant_override("separation",6);keys.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var pill=preload("res://scripts/ui/key_pill.gd")
	use_key=pill.new();use_key.action="interact";use_key.side=22;keys.add_child(use_key)
	use_text=Label.new();keys.add_child(use_text);use_text.add_theme_font_size_override("font_size",12);use_text.custom_minimum_size.x=100
	bag_key=pill.new();bag_key.action="hide_trench";bag_key.side=22;keys.add_child(bag_key)
	bag_text=Label.new();keys.add_child(bag_text);bag_text.add_theme_font_size_override("font_size",12)
	chip.hide();refresh_card.call_deferred()  # the pickup entry is set right after add_child

func kind()->String:
	var c:Dictionary=pickup.content
	if not c.get("weapons",[]).is_empty():return "weapon"
	if not c.get("ammo",[]).is_empty():return "ammo"
	if not c.get("supplies",[]).is_empty():return "supply"
	return "recipe"
func item()->Dictionary:
	var c:Dictionary=pickup.content
	var list:Array={"weapon":c.get("weapons",[]),"ammo":c.get("ammo",[]),"supply":c.get("supplies",[]),"recipe":c.get("recipes",[])}[kind()]
	return list[0] if not list.is_empty() else {}
func refresh_card():
	if pickup.is_empty():return
	var column=chip.get_node("Column")
	var old=column.get_node_or_null("ItemCard")
	if old:old.free()
	var card=preload("res://scripts/ui/item_info.gd").card(preload("res://scripts/ui/item_info.gd").of(kind(),item(),arena),236)
	column.add_child(card);column.move_child(card,0)
	Texts.set_text(use_text,{"weapon":"Взять в руки","ammo":"Зарядить","supply":"Вылечиться"}.get(kind(),"Подобрать"))

## The hero who can pick it up: the soldier on the field, or the room's walking hero.
func hero()->Node3D:
	if ground!=null:return ground.hero() if is_instance_valid(ground) else null
	return arena.room.player if is_instance_valid(arena) else null
static func flat(a:Vector3,b:Vector3)->float:return Vector2(a.x-b.x,a.z-b.z).length()
func near()->bool:
	var player=hero()
	if not is_instance_valid(player):return false
	if ground!=null:
		if not ground.can_pick():return false
	elif not (player.kind=="soldier" and not player.dead and arena.phase in ["combat","countdown"]):return false
	return flat(player.global_position,global_position)<REACH and nearest()
## A dropped item's card is open: the room's own E (mechanic, crate, exit) waits (T-202).
static func engaged(node:Node)->bool:
	return node.get_tree().get_nodes_in_group("drop_prompts").any(func(p):return is_instance_valid(p) and is_instance_valid(p.chip) and p.chip.visible)
## Only the closest dropped item answers the keys.
func nearest()->bool:
	var player=hero();var me=flat(player.global_position,global_position)
	for other in get_tree().get_nodes_in_group("drop_prompts"):
		if other!=self and is_instance_valid(other) and other.is_visible_in_tree() and flat(player.global_position,other.global_position)<me-.001:return false
	return true
func _enter_tree():add_to_group("drop_prompts")
func _process(_d):
	if pickup.is_empty():return
	var camera=get_viewport().get_camera_3d()
	var show=is_instance_valid(camera) and near()
	chip.visible=show
	if not show:return
	use_key.refresh();bag_key.refresh()
	var room=not Backpack.full(arena.run)
	Texts.set_text(bag_text,"В рюкзак" if room else "Нет места");bag_text.add_theme_color_override("font_color",UiKit.INK if room else Color("e0806b"))
	var anchor=camera.unproject_position(global_position+Vector3(0,.9,0))
	chip.reset_size();chip.position=(anchor-Vector2(chip.size.x*.5,chip.size.y)).round()
	if Input.is_action_just_pressed("interact"):use()
	elif Input.is_action_just_pressed("hide_trench"):stash()

## E: use it now; what it replaces lies down here instead.
func use():
	var run=arena.run;var it=item()
	match kind():
		"weapon":
			var old={"id":str(run.weapon),"rarity":int(run.weapon_rarity),"stats":run.weapon_stats.duplicate()}
			run.weapon=str(it.id);run.weapon_rarity=int(it.get("rarity",0));run.weapon_stats=it.get("stats",{}).duplicate()
			# Second-slot ammo a one-slot gun cannot hold lies down here with the old gun (audit: never deleted).
			var spilled=Ammo.ensure(run,run.weapon);RunUpgrades.refresh_player(arena)
			# Bare paws are not an item (T-201): with empty hands nothing is left lying here.
			var guns=[old] if LootCatalog.is_gun(str(old.id)) else []
			if guns.is_empty() and spilled.is_empty():remove()
			else:replace({"recipes":[],"ammo":spilled,"weapons":guns})
			Game.sound("inv_weapon",arena);arena.toast(Texts.render("Оружие в руках"))
		"ammo":
			Ammo.ensure(run,str(arena.weapon))
			if not Ammo.fits(str(it.type),str(arena.weapon)):arena.toast(Texts.render("Эти боеприпасы не подходят к оружию"));return
			var out=Ammo.load_item(run,it);Backpack.refresh(arena)
			if out.is_empty():remove()
			else:replace({"recipes":[],"ammo":[out]})
			Game.sound("inv_ammo",arena);arena.toast(Texts.render("Боеприпасы заряжены"))
		"supply":
			run.supplies.append(it)
			if Backpack.use_medkit(arena,run.supplies.size()-1):remove()
			else:run.supplies.pop_back()
		_:stash()
## C: into the backpack, when there is room.
func stash():
	if Backpack.full(arena.run):arena.toast(Texts.render("Рюкзак полон"));Game.sound("ui_denied",arena);return
	if Backpack.pick_sack(arena,pickup.content):Game.sound(GearCell.click_for(kind()),arena);remove()
func remove():
	if ground!=null:ground.take_away(pickup);return
	arena.room.pickups.erase(pickup);preload("res://scripts/battle_stage.gd").vanish(pickup.node)
## The item swaps with what was in hand: the old one now lies here.
func replace(content:Dictionary):
	content["weapons"]=content.get("weapons",[]).filter(func(w):return LootCatalog.is_gun(str(w.get("id",""))))
	if ground!=null:
		var spot=pickup.node.position;remove();ground.place(content,spot);return
	var at=arena.grid_pos(pickup.node.position)
	remove();arena.reward.place_sack(at,content)
