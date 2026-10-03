extends Node3D
## Weapon locker (T-011) in every service room and at the merchant: an olive cabinet; E opens a short list of
## every unlocked weapon, and taking another one costs a little alloy. The swap lasts for the rest of the run.
const PRICE=30
var room:Node3D
var arena
var modal:Control
static func place(parent:Node3D,context,at:Vector3)->Node3D:
	var locker=load("res://scripts/weapon_locker.gd").new();locker.room=parent;locker.arena=context;locker.position=at;parent.add_child(locker);return locker
func _ready():
	name="WeaponLocker"
	var olive=Color("59603f")
	Visuals.box(self,Vector3(0,.8,0),Vector3(.9,1.6,.5),olive,"paint")
	Visuals.box(self,Vector3(0,.8,.26),Vector3(.8,1.45,.03),olive.darkened(.2),"paint")
	for i in range(3):
		var rack=Visuals.model("weapon_"+["rifle","shotgun","smg"][i],self,Vector3(-.25+i*.25,.95,.3));rack.rotation=Vector3(0,0,PI*.5);rack.scale=Vector3.ONE*.7
	Visuals.label3d(self,"Оружие · E",Vector3(0,1.9,0),Color("fff0ce"),24)
	preload("res://scripts/interaction_prompt.gd").attach(self,room,"Оружие",Vector3.ZERO,1.4)
func near(avatar:Node3D)->bool:return avatar.global_position.distance_to(global_position)<1.4
func open(ui_root:Control,done:Callable):
	modal=Control.new();modal.name="WeaponLockerMenu";ui_root.add_child(modal);modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);modal.add_to_group("selection_scope")
	var shade=ColorRect.new();modal.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,.5)
	var owned=Game.LOOT.WEAPONS.keys().filter(func(id):return id in Game.weapon_unlocks)
	var size=Vector2(560,130+owned.size()*64);var panel=UiKit.glass(modal,((ui_root.get_viewport_rect().size-size)*.5).round(),size)
	UiKit.label(panel,"Оружейный шкаф",Vector2(24,16),Vector2(400,34),24)
	UiKit.label(panel,"Сменить оружие до конца вылазки · %d ◈" % PRICE,Vector2(24,52),Vector2(500,22),14,UiKit.MUTED)
	var close=func():
		if is_instance_valid(modal):modal.queue_free()
		modal=null;done.call()
	for i in range(owned.size()):
		var id=owned[i];var current=id==arena.run.weapon
		var b=UiKit.button(panel,Game.LOOT.WEAPONS[id].name+("  · в руках" if current else ""),Vector2(24,88+i*64),Vector2(size.x-48,54),func():
			if Game.credits<PRICE:return
			Game.credits-=PRICE;Game.save_progress();arena.run.weapon=id;RunUpgrades.refresh_player(arena);Game.sound("weapon_equip",room);close.call())
		b.icon=UiKit.trimmed(UiKit.icon_texture(id));b.expand_icon=true;b.add_theme_constant_override("icon_max_width",72);b.alignment=HORIZONTAL_ALIGNMENT_LEFT
		b.disabled=current or Game.credits<PRICE
	var x=UiKit.button(panel,"",Vector2(size.x-66,14),Vector2(44,40),close);x.icon=UiKit.interface_icon("close");x.expand_icon=true;x.add_theme_constant_override("icon_max_width",18)
