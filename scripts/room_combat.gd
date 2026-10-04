extends Node3D
## Full hero controls in the rooms between fields (T-158, T-185): shooting with the selected weapon, the
## ability bar and the same ability effects as in the hub — one look and feel in the hub, rooms and battle.
## The node stands in for the hub towards hub_skills.gd, hub_ability_effect.gd and projectile.gd: it exposes
## the fields they read (avatar, facing, cell, moving, dummy…) and mirrors the room's walker every frame.
## The room keeps its own walking, modals and interaction; while a modal is open nothing here reacts.
var room:Node
var avatar:Node3D
var walker
var can_stand:Callable
var facing:=Vector2i.UP
var cell:=Vector2i.ZERO
var moving:=false
var mounted:=false
var training_tank:Node3D=null
var training_barriers:Array=[]
var training_ability_cooldown:=0.0
var projectiles:Array=[]
var fire_cooldown:=0.0
## A hidden aim point a few cells ahead: effects that target the hub's training dummy land there.
var dummy:Node3D
var dummy_label:Label3D
var dummy_hits:=0
var skills:Control
## "combat" while the hero is free, "modal" while a room window is open (hub_skills and projectiles read it).
var phase:String:
	get:return "modal" if room==null or (room.get("modal")!=null and is_instance_valid(room.get("modal"))) else "combat"

static func attach(owner:Node,hero:Node3D,room_walker,stand:Callable,ui_root:Control)->Node3D:
	var node=load("res://scripts/room_combat.gd").new();node.name="RoomCombat";node.room=owner;node.avatar=hero;node.walker=room_walker;node.can_stand=stand
	owner.add_child(node)
	node.skills=preload("res://scripts/ui/hub_skills.gd").new();node.skills.hub=node;node.skills.name="RoomSkills";ui_root.add_child(node.skills)
	return node

func _ready():
	dummy=Node3D.new();dummy.name="AimPoint";add_child(dummy)
	dummy_label=Label3D.new();dummy_label.visible=false;dummy.add_child(dummy_label)

func _physics_process(delta):
	if not is_instance_valid(avatar) or walker==null:return
	facing=walker.facing;cell=walker.cell();moving=walker.moving
	dummy.position=avatar.position+Vector3(facing.x,0,facing.y)*3.0
	fire_cooldown=maxf(0,fire_cooldown-delta)
	# The gun in hand is the run's one (a crate gun, a swap in the backpack), not the hub's choice.
	if avatar.get("weapon_id")!=null and avatar.weapon_id!=weapon_id():Visuals.equip_model(avatar,weapon_id())
	if phase!="combat":return
	for slot in range(Game.hero_loadout().size()):
		if Input.is_action_just_pressed(Game.ability_action(slot)):skills.cast(slot)
	if Game.wants_fire() and walker.turn_timer<=0 and fire_cooldown<=0:shoot()

## The run behind the room (service rooms and the merchant keep the battle arena in `arena`).
func run_arena():
	var owner_arena=room.get("arena") if is_instance_valid(room) else null
	return owner_arena if is_instance_valid(owner_arena) and owner_arena.get("run")!=null else null
func weapon_id()->String:return Gun.weapon_id(self)
## The battle's shot (scripts/combat/gun.gd): the run's gun with its pellets, bursts, lob, blast, range and ammo.
func shoot():fire_cooldown=Gun.trigger(self,avatar)

## The room as a practice field for Gun: no targets yet; rounds stop at the room's walls and at whatever the
## hero cannot walk through, charges burst there with the loaded ammo's extras.
func bullet_hit(bullet)->bool:return Gun.practice_hit(self,bullet)
func rocket_impact(bullet):Gun.practice_blast(self,bullet)
func gun_targets()->Array:return []
func gun_target_hit(_target,_amount:float):pass
func gun_inside(p:Vector3)->bool:return absf(p.x)<=4.6 and p.z>=-3.4 and p.z<=5.0
func gun_blocked(p:Vector3)->bool:
	if not gun_inside(p):return true
	return not can_stand.call(Vector3(snappedf(p.x,.25),0,snappedf(p.z,.25))) and absf(p.x)<3.2 and p.z>-2.2 and p.z<4.2

## Ability effects ask whether a cell is free (barrier placement, grenade flight).
func hub_free(c:Vector2i)->bool:return can_stand.call(Vector3(c.x,0,c.y)) and c not in training_barriers
