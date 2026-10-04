extends Node3D
## Full hero controls in the rooms between fields (T-158, T-185): shooting with the selected weapon, the
## ability bar and the same ability effects as in the hub — one look and feel in the hub, rooms and battle.
## The node stands in for the hub towards hub_skills.gd, hub_ability_effect.gd and projectile.gd: it exposes
## the fields they read (avatar, facing, cell, moving, dummy…) and mirrors the room's walker every frame.
## The room keeps its own walking, modals and interaction; while a modal is open nothing here reacts.
const LOOT=preload("res://scripts/loot_catalog.gd")
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
	if Input.is_action_just_pressed("melee"):Melee.swipe(avatar,self,weapon_id()==LootCatalog.PAWS,facing)

## The run behind the room (service rooms and the merchant keep the battle arena in `arena`).
func run_arena():
	var owner_arena=room.get("arena") if is_instance_valid(room) else null
	return owner_arena if is_instance_valid(owner_arena) and owner_arena.get("run")!=null else null
func weapon_id()->String:
	var a=run_arena()
	var id=str(a.run.weapon) if a!=null else Game.selected_weapon
	return id if id in LOOT.WEAPONS else "pistol"
## The battle's shot: the gun in hand with its pellets, speed, range and damage (rarity and crate stats too).
func shoot():
	var id=weapon_id();var data=LOOT.WEAPONS[id]
	# Empty hands: the paws scratch the air instead of a shot.
	if id==LootCatalog.PAWS:fire_cooldown=data.interval;Melee.swipe(avatar,self,true,facing);return
	var stats=CombatStats.weapon(run_arena(),id) if run_arena()!=null else {"damage":data.damage*Game.weapon_factor(id),"interval":data.interval}
	if avatar.has_method("kick"):avatar.kick()
	fire_cooldown=stats.interval
	for i in range(data.pellets):
		var bullet=load("res://scenes/projectile.tscn").instantiate()
		bullet.sniper_visual=id=="sniper"
		bullet.arena=self;bullet.friendly=true;bullet.speed=data.speed;bullet.damage=stats.damage
		bullet.travel_direction=Vector3(facing.x,0,facing.y).rotated(Vector3.UP,(i-(data.pellets-1)*.5)*.1)
		var muzzle=avatar.get("muzzle")
		var height=muzzle.global_position.y-avatar.position.y if muzzle is Node3D and is_instance_valid(muzzle) else .55
		bullet.position=avatar.position+bullet.travel_direction*.45+Vector3.UP*height
		bullet.lifetime=data.range/data.speed
		add_child(bullet);projectiles.append(bullet)
	Game.fire_sound(str(id),avatar)

## Bullets stop at the room's walls and at whatever the hero cannot walk through.
func bullet_hit(bullet)->bool:
	var p=bullet.position
	if absf(p.x)>4.6 or p.z< -3.4 or p.z>5.0:return true
	return not can_stand.call(Vector3(snappedf(p.x,.25),0,snappedf(p.z,.25))) and absf(p.x)<3.2 and p.z>-2.2 and p.z<4.2

## Ability effects ask whether a cell is free (barrier placement, grenade flight).
func hub_free(c:Vector2i)->bool:return can_stand.call(Vector3(c.x,0,c.y)) and c not in training_barriers
