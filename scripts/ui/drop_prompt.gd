extends Node3D
## A single dropped item on the field (author, 2026-10-03): when the soldier comes close a small card pops
## up over it — picture, name in its rarity colour, its numbers next to what is in hand — and two keys:
## E — use it now (take the gun / load the ammo / heal; what was in hand drops here instead),
## C — put it in the backpack, or «Нет места» when the backpack is full.
## Several items at once still drop as a sack that is picked up by walking over it.
const REACH:=1.15
var arena
var pickup:Dictionary={}
var chip:Panel
var picture:TextureRect
var title:Label
var stats:Label
var use_key
var use_text:Label
var bag_key
var bag_text:Label
func _ready():
	var canvas=CanvasLayer.new();canvas.layer=5;add_child(canvas)
	chip=Panel.new();chip.name="DropCard";canvas.add_child(chip);chip.mouse_filter=Control.MOUSE_FILTER_IGNORE;chip.size=Vector2(250,104)
	chip.add_theme_stylebox_override("panel",UiKit.style(Color(.1,.13,.11,.88),10,Color(1,1,1,.14)))
	picture=TextureRect.new();chip.add_child(picture);picture.position=Vector2(8,8);picture.size=Vector2(52,52);picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
	title=UiKit.label(chip,"",Vector2(68,6),Vector2(176,22),15);title.clip_text=true;title.mouse_filter=Control.MOUSE_FILTER_IGNORE
	stats=UiKit.label(chip,"",Vector2(68,28),Vector2(176,34),11,UiKit.MUTED);stats.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;stats.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var pill=preload("res://scripts/ui/key_pill.gd")
	use_key=pill.new();use_key.action="interact";use_key.side=22;chip.add_child(use_key);use_key.position=Vector2(8,72)
	use_text=UiKit.label(chip,"",Vector2(36,72),Vector2(96,22),12);use_text.mouse_filter=Control.MOUSE_FILTER_IGNORE
	bag_key=pill.new();bag_key.action="hide_trench";bag_key.side=22;chip.add_child(bag_key);bag_key.position=Vector2(130,72)
	bag_text=UiKit.label(chip,"",Vector2(158,72),Vector2(88,22),12);bag_text.mouse_filter=Control.MOUSE_FILTER_IGNORE
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
	var it=item();var tier=0
	match kind():
		"weapon":
			var id=str(it.get("id","pistol"));tier=int(it.get("rarity",0))
			picture.texture=UiKit.trimmed(UiKit.icon_texture(id));Texts.set_text(title,Game.LOOT.WEAPONS[id].name)
			var now=CombatStats.weapon(arena,str(arena.weapon));var new=CombatStats.weapon(null,id)
			stats.text="%s %s → %s · %s %s → %s /с" % [Texts.render("Урон"),UiKit.number(snappedf(now.damage,.01)),UiKit.number(snappedf(new.damage,.01)),Texts.render("Темп"),UiKit.number(snappedf(now.rate,.01)),UiKit.number(snappedf(new.rate,.01))]
			Texts.set_text(use_text,"Взять в руки")
		"ammo":
			var type=str(it.get("type",""));tier=int(it.get("rarity",0))
			picture.texture=UiKit.trimmed(UiKit.icon_texture("ammo/"+type if IconKit.has("ammo/"+type) else "stats/damage"));Texts.set_text(title,Ammo.NAMES.get(type,type)+" патроны")
			stats.text=Ammo.describe(it);Texts.set_text(use_text,"Зарядить")
		"supply":
			picture.texture=UiKit.trimmed(UiKit.icon_texture("heart"));Texts.set_text(title,"Аптечка")
			stats.text=Texts.render("+%s здоровья") % str(snappedf(float(it.get("heal",1.0)),.1));Texts.set_text(use_text,"Вылечиться")
		_:
			picture.texture=UiKit.trimmed(UiKit.icon_texture("blueprint/"+str(it.get("category","")) if IconKit.has("blueprint/"+str(it.get("category",""))) else "blueprint"))
			Texts.set_text(title,Game.recipe_name(it));stats.text=Texts.render("Чертёж — донеси до хаба, чтобы открыть");Texts.set_text(use_text,"Подобрать")
			tier=Game.TIERS.tier(str(it.get("id","")))
	title.add_theme_color_override("font_color",Color(LootCatalog.RARITY_COLORS[clampi(tier,0,3)]).lightened(.2) if tier>0 else UiKit.INK)

func near()->bool:
	var player=arena.room.player if is_instance_valid(arena) else null
	return is_instance_valid(player) and player.kind=="soldier" and not player.dead and arena.phase in ["combat","countdown"] and arena.flat_distance(player.position,global_position)<REACH and nearest()
## Only the closest dropped item answers the keys.
func nearest()->bool:
	var me=arena.flat_distance(arena.room.player.position,global_position)
	for other in get_tree().get_nodes_in_group("drop_prompts"):
		if other!=self and is_instance_valid(other) and arena.flat_distance(arena.room.player.position,other.global_position)<me-.001:return false
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
	chip.position=(anchor-Vector2(chip.size.x*.5,chip.size.y)).round()
	if Input.is_action_just_pressed("interact"):use()
	elif Input.is_action_just_pressed("hide_trench"):stash()

## E: use it now; what it replaces lies down here instead.
func use():
	var run=arena.run;var it=item()
	match kind():
		"weapon":
			var old={"id":str(run.weapon)}
			run.weapon=str(it.id);Ammo.ensure(run,run.weapon);RunUpgrades.refresh_player(arena)
			replace({"recipes":[],"ammo":[],"weapons":[old]});Game.sound("weapon_equip",arena);arena.toast(Texts.render("Оружие в руках"))
		"ammo":
			Ammo.ensure(run,str(arena.weapon))
			if not Ammo.fits(str(it.type),str(arena.weapon)):arena.toast(Texts.render("Эти патроны не подходят к оружию"));return
			var out=Ammo.load_item(run,it);Backpack.refresh(arena)
			if out.is_empty():remove()
			else:replace({"recipes":[],"ammo":[out]})
			Game.sound("weapon_equip",arena);arena.toast(Texts.render("Патроны заряжены"))
		"supply":
			run.supplies.append(it)
			if Backpack.use_medkit(arena,run.supplies.size()-1):remove()
			else:run.supplies.pop_back()
		_:stash()
## C: into the backpack, when there is room.
func stash():
	if Backpack.full(arena.run):arena.toast(Texts.render("Рюкзак полон"));Game.sound("ui_denied",arena);return
	if Backpack.pick_sack(arena,pickup.content):Game.sound("pickup",arena);remove()
func remove():
	arena.room.pickups.erase(pickup);preload("res://scripts/battle_stage.gd").vanish(pickup.node)
## The item swaps with what was in hand: the old one now lies here.
func replace(content:Dictionary):
	var at=arena.grid_pos(pickup.node.position)
	remove();arena.reward.place_sack(at,content)
