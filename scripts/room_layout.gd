class_name RoomLayout
extends RefCounted
## One layout for every upgrade room and the merchant (author, 2026-10-03): the main station at the back, the weapon
## crate on the left, a vending machine at the front left, the «Фортуна» spot at the front right and the exit on the
## right. Rooms differ by their own dressing; the places stay the same, so the player always knows where to go.
const MAIN:=Vector3(0,0,-1)
const WEAPON_CRATE:=Vector3(-3.4,0,0.5)
const MACHINE:=Vector3(-3.4,0,2.4)
const FORTUNE:=Vector3(3.4,0,2.9)
const EXIT:=Vector3(4,0,1)
## Machines for the vending spot; the fortune spot holds a slot machine or an ammo loot box with this chance
## (the merchant always has its slot machine there), otherwise a closed fortune booth.
const MACHINES:=["medkit","lootbox"]
const FORTUNE_CHANCE:=.55

## What stands where in this room. Seeded by the run and the room only (own generator): the same room shows the
## same machines after a reload, and the combat RNG is not touched.
static func plan(run_seed:int,index:int,merchant:bool)->Dictionary:
	var rng=RandomNumberGenerator.new();rng.seed=hash([run_seed,index,"room_layout"])
	var machine:String=MACHINES[rng.randi_range(0,MACHINES.size()-1)]
	var fortune="slot" if merchant else "closed"
	if not merchant and rng.randf()<FORTUNE_CHANCE:
		fortune="slot" if machine=="lootbox" or rng.randf()<.5 else "lootbox"
	return {"machine":machine,"fortune":fortune}

## Places the weapon crate, the vending machine and the fortune spot; returns them as {crate, machine, fortune}.
## Every placed node answers near(avatar) and use(room_root, done) so a room only loops over them.
static func furnish(room:Node3D,arena,index:int,merchant:bool)->Dictionary:
	var layout=plan(int(arena.run_seed),index,merchant)
	var nodes={"crate":preload("res://scripts/weapon_locker.gd").place(room,arena,WEAPON_CRATE)}
	nodes.machine=place_machine(room,arena,str(layout.machine),MACHINE)
	nodes.fortune=place_machine(room,arena,str(layout.fortune),FORTUNE,true)
	nodes.layout=layout
	return nodes

static func place_machine(room:Node3D,arena,kind:String,at:Vector3,fortune:=false)->Node3D:
	var node:Node3D
	match kind:
		"lootbox":node=preload("res://scripts/ammo_vendor.gd").place(room,arena,at)
		"slot":node=preload("res://scripts/slot_machine.gd").place(room,arena,at)
		"medkit":node=preload("res://scripts/medkit_vendor.gd").place(room,arena,at)
		_:node=closed_fortune(room,at)
	if fortune:
		node.set_meta("fortune",true)
		# The sign over the spot says what this place is, so a closed booth still reads as «luck lives here».
		Visuals.label3d(node,"Фортуна",Vector3(0,2.55,0),Color("ffd27a"),26).name="FortuneSign"
	return node

## A shuttered booth with a lamp: the fortune is closed in this room.
static func closed_fortune(room:Node3D,at:Vector3)->Node3D:
	var booth=Node3D.new();booth.name="FortuneClosed";booth.set_script(preload("res://scripts/room_fortune_closed.gd"));room.add_child(booth);booth.position=at
	return booth

## Index of the placed node the avatar stands next to, "" when none.
static func near(nodes:Dictionary,avatar:Node3D)->Node3D:
	for key in ["crate","machine","fortune"]:
		var node=nodes.get(key)
		if is_instance_valid(node) and node.has_method("near") and node.near(avatar):return node
	return null
