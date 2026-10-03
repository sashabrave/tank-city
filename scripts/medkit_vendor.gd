extends Node3D
## Medkit vending machine (RoomLayout «machine» spot): full heal of the soldier for a few run tokens.
const PRICE:=3
var room:Node3D
var arena
static func place(parent:Node3D,context,at:Vector3)->Node3D:
	var vendor=load("res://scripts/medkit_vendor.gd").new();vendor.room=parent;vendor.arena=context;vendor.position=at;parent.add_child(vendor);return vendor
func _ready():
	name="MedkitVendor"
	if not preload("res://scripts/machine_model.gd").attach(self,"res://assets/models/route/machine_medkit.glb",Color("ffc9b8"),1.4):
		var white=Color("e8e4d8");var red=Color("c8372b")
		Visuals.box(self,Vector3(0,.85,0),Vector3(.8,1.7,.6),white,"paint")
		Visuals.box(self,Vector3(0,1.25,.31),Vector3(.6,.6,.03),Color("1d2326"),"glass")
		Visuals.box(self,Vector3(0,1.25,.33),Vector3(.38,.12,.02),red);Visuals.box(self,Vector3(0,1.25,.33),Vector3(.12,.38,.02),red)
		Visuals.box(self,Vector3(0,.55,.32),Vector3(.5,.14,.04),Color("2a3033"),"gunmetal")
		Visuals.box(self,Vector3(0,1.76,0),Vector3(.86,.12,.66),red,"paint")
	Visuals.label3d(self,"Аптечка · %d жетона · E" % PRICE,Vector3(0,2.1,0),Color("f6c5bc"),24)
	preload("res://scripts/interaction_prompt.gd").attach(self,room,"Аптечка",Vector3.ZERO,1.4)
func near(avatar:Node3D)->bool:return avatar.global_position.distance_to(global_position)<1.4
## Full heal for PRICE tokens; returns false when it cannot (already healthy, not enough tokens).
func buy()->bool:
	var run=arena.run
	if run.soldier_hp>=run.soldier_max_hp:arena.toast(Texts.render("Здоровье и так полное"));return false
	if run.tokens<PRICE:Game.sound("ui_denied",self);arena.toast(Texts.render("Аптечке нужно %d жетона") % PRICE);return false
	run.tokens-=PRICE;run.soldier_hp=run.soldier_max_hp
	if is_instance_valid(arena.room.player) and arena.room.player.kind=="soldier":arena.room.player.hp=run.soldier_hp;arena.room.player.refresh_health()
	Game.sound("upgrade",self);arena.toast(Texts.render("Полное лечение"));return true
func use(_root:Control,done:Callable):
	buy();done.call()
