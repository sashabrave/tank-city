extends Node3D
## Medkit vending machine (RoomLayout «machine» spot): full heal of the soldier for a few run tokens.
const PRICE:=3
var room:Node3D
var arena
var prompt
var sign:Label3D
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
	sign=Visuals.label3d(self,"Аптечка · %d жетона · E" % PRICE,Vector3(0,2.1,0),Color("f6c5bc"),24)
	prompt=preload("res://scripts/interaction_prompt.gd").attach(self,room,status(),Vector3.ZERO,1.4)
	# The world sign fades while the prompt shows, so it doesn't stack with the weapon crate's sign (T-213).
	prompt.twin=sign;prompt.twin_searched=true
func _process(_delta):
	if prompt:prompt.caption=status()
## What a press does now (T-213): the prompt says it before the press, not only after it.
func status()->String:
	var reason=refusal()
	if reason!="":return Texts.render("Аптечка")+" · "+reason
	return Texts.render("Аптечка · полное лечение за %d жетона") % PRICE
## Why the machine cannot heal right now, "" when it can.
func refusal()->String:
	if not is_instance_valid(arena) or not "run" in arena:return ""
	var run=arena.run
	if run.soldier_hp>=run.soldier_max_hp:return Texts.render("здоровье полное")
	if run.tokens<PRICE:return Texts.render("нужно %d жетона, есть %d") % [PRICE,run.tokens]
	return ""
func near(avatar:Node3D)->bool:return avatar.global_position.distance_to(global_position)<1.4
## Full heal for PRICE tokens; returns false when it cannot (already healthy, not enough tokens).
func buy()->bool:
	var run=arena.run
	if run.soldier_hp>=run.soldier_max_hp:
		Game.sound("ui_denied",self);arena.toast(Texts.render("Здоровье и так полное"));say("Здоровье и так полное");return false
	if run.tokens<PRICE:
		Game.sound("ui_denied",self);arena.toast(Texts.render("Аптечке нужно %d жетона") % PRICE);say(Texts.render("Нужно %d жетона, есть %d") % [PRICE,run.tokens]);return false
	run.tokens-=PRICE;run.soldier_hp=run.soldier_max_hp
	if is_instance_valid(arena.room.player) and arena.room.player.kind=="soldier":arena.room.player.hp=run.soldier_hp;arena.room.player.refresh_health()
	Game.sound("upgrade",self);arena.toast(Texts.render("Полное лечение"));say("Полное лечение");return true
func say(text:String):
	if prompt:prompt.flash(Texts.render(text))
func use(_root:Control,done:Callable):
	buy();done.call()
