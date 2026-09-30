extends RefCounted
## Minimal low-poly ordnance in the game's toy-military style: hand grenade, mortar round, drone bomb
## and RPG rocket. Team reads by the band colour; enemy ordnance carries a blinking red light.
## Visual only: collision, timers and damage stay in grenade.gd, bomb.gd and projectile.gd.
const FRIENDLY_BAND=Color("efb943")
const ENEMY_BAND=Color("d8452f")
const OLIVE=Color("5d6a43")
const STEEL=Color("59605f")
const DARK=Color("3b3f36")
static var cache:={}

static func mesh(key:String)->Mesh:
	if cache.has(key):return cache[key]
	var m:Mesh
	match key:
		"capsule":m=CapsuleMesh.new();m.radius=.5;m.height=2.0;m.radial_segments=12;m.rings=4
		"cylinder":m=CylinderMesh.new();m.top_radius=.5;m.bottom_radius=.5;m.height=1.0;m.radial_segments=12
		"cone":m=CylinderMesh.new();m.top_radius=.02;m.bottom_radius=.5;m.height=1.0;m.radial_segments=12
		"box":m=BoxMesh.new();m.size=Vector3.ONE
	cache[key]=m;return m

static func part(root:Node3D,key:String,pos:Vector3,size:Vector3,color:Color,rotation:=Vector3.ZERO,emissive:=false)->MeshInstance3D:
	var node=MeshInstance3D.new();node.mesh=mesh(key);node.position=pos;node.scale=size;node.rotation=rotation
	node.material_override=Visuals.material(color,emissive)
	if emissive:node.material_override.emission_energy_multiplier=2.2
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(node)
	return node

static func blink(root:Node3D,pos:Vector3,rate:=6.0,size:=.05)->Node3D:
	var holder=Node3D.new();holder.name="Blink";holder.set_script(preload("res://scripts/fx_motion.gd"));holder.blink_rate=rate;root.add_child(holder)
	part(holder,"box",pos,Vector3.ONE*size,Color("ff3b2a"),Vector3.ZERO,true)
	return holder

## Hand grenade: ribbed olive body, fuse head, safety lever, team band. Tumbles in flight.
static func grenade(parent:Node3D,friendly:bool,name:="GrenadeModel")->Node3D:
	var root=Node3D.new();root.name=name;root.set_script(preload("res://scripts/fx_motion.gd"));root.spin=Vector3(5.0,0,3.0);parent.add_child(root)
	part(root,"capsule",Vector3.ZERO,Vector3(.16,.1,.16),OLIVE)
	part(root,"cylinder",Vector3.ZERO,Vector3(.17,.035,.17),FRIENDLY_BAND if friendly else ENEMY_BAND)
	part(root,"cylinder",Vector3(0,.12,0),Vector3(.07,.06,.07),STEEL)
	part(root,"box",Vector3(.045,.08,0),Vector3(.02,.12,.035),STEEL,Vector3(0,0,-.35))
	if not friendly:blink(root,Vector3(0,.16,0),7.0,.04)
	return root

## Mortar round: teardrop body, tail tube and four fins; nose-first along its flight.
static func mortar_round(parent:Node3D,friendly:bool,name:="GrenadeModel")->Node3D:
	var root=Node3D.new();root.name=name;root.set_script(preload("res://scripts/fx_motion.gd"));root.align_to_velocity=true;parent.add_child(root)
	part(root,"capsule",Vector3(0,.03,0),Vector3(.13,.12,.13),STEEL.darkened(.1))
	part(root,"cylinder",Vector3(0,.04,0),Vector3(.135,.03,.135),FRIENDLY_BAND if friendly else ENEMY_BAND)
	part(root,"cylinder",Vector3(0,-.14,0),Vector3(.05,.14,.05),DARK)
	for i in range(4):part(root,"box",Vector3(0,-.18,0),Vector3(.2,.08,.012),DARK,Vector3(0,i*PI*.5,0))
	if not friendly:blink(root,Vector3(0,.16,0),7.0,.04)
	return root

## Drone bomb lying on the ground: finned body, yellow safety stripe, red light blinking faster to zero.
static func drone_bomb(parent:Node3D)->Node3D:
	var root=Node3D.new();root.name="BombModel";parent.add_child(root)
	part(root,"capsule",Vector3(0,.13,0),Vector3(.24,.19,.24),DARK,Vector3(0,0,PI*.5))
	part(root,"cone",Vector3(.3,.13,0),Vector3(.2,.14,.2),DARK.darkened(.15),Vector3(0,0,-PI*.5))
	part(root,"cylinder",Vector3(-.04,.13,0),Vector3(.25,.05,.25),FRIENDLY_BAND,Vector3(0,0,PI*.5))
	part(root,"cylinder",Vector3(-.3,.13,0),Vector3(.13,.04,.13),STEEL,Vector3(0,0,PI*.5))
	for i in range(4):part(root,"box",Vector3(-.3,.13,0),Vector3(.1,.2,.01),STEEL,Vector3(i*PI*.5+PI*.25,0,0))
	blink(root,Vector3(.05,.27,0),3.0,.06)
	return root

## RPG rocket body for the projectile visual: tube, warhead cone and tail fins; faces -Z.
static func rocket(parent:Node3D,friendly:bool)->Node3D:
	var root=Node3D.new();root.name="RocketBody";parent.add_child(root)
	part(root,"cylinder",Vector3(0,0,-.12),Vector3(.07,.26,.07),OLIVE,Vector3(PI*.5,0,0))
	part(root,"cone",Vector3(0,0,-.32),Vector3(.12,.16,.12),OLIVE.darkened(.2),Vector3(-PI*.5,0,0))
	part(root,"cylinder",Vector3(0,0,-.22),Vector3(.125,.05,.125),FRIENDLY_BAND if friendly else ENEMY_BAND,Vector3(PI*.5,0,0))
	for i in range(4):part(root,"box",Vector3(0,0,.02),Vector3(.16,.012,.08),DARK,Vector3(0,0,i*PI*.5))
	return root
