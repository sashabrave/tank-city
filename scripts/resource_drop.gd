extends Node3D
## Lightweight ballistic motion, separate visual RNG; exact currency values live on each token.
var arena
var currency="alloy"
var amount=1
var denomination=5
var velocity=Vector3.ZERO
var age=0.0
var floor_height=.03
var collected=false
var visual:Node3D
## Alloy falls as gold bars of 1, 5 and 10 (T-105) in a random mix that adds up exactly; big sums lean on
## big bars so a chest does not spill a hundred pieces. Visual RNG only — the amount never changes.
const BARS=[10,5,1]
static func split(value:int,rng:RandomNumberGenerator=null)->Array:
	if rng==null:rng=RandomNumberGenerator.new();rng.randomize()
	var result=[]
	while value>0:
		# Mostly the biggest bar that fits, sometimes one size down; small bars only for the remainder.
		var unit=10 if value>=40 else (10 if rng.randf()<.6 else 5) if value>=10 else 5 if value>=5 else 1
		result.append({"amount":unit,"denomination":unit});value-=unit
	return result
static func spawn(context,pos:Vector3,value:int,kind:String="alloy",blast:Vector3=Vector3.ZERO):
	pos=context.reward.safe_drop_position(pos)
	var rng=RandomNumberGenerator.new();rng.randomize()
	var entries=split(value,rng) if kind=="alloy" else [{"amount":value,"denomination":1}]
	for entry in entries:
		var token=load("res://scripts/resource_drop.gd").new();token.arena=context;token.currency=kind;token.amount=entry.amount;token.denomination=entry.denomination
		token.position=pos+Vector3.UP*.4
		var direction=Vector3(cos(rng.randf()*TAU),0,sin(rng.randf()*TAU)).normalized()
		if blast.length()>.01:direction=(blast.normalized()+direction*.35).normalized()
		token.velocity=direction*(rng.randf_range(2.4,4.0) if blast.length()>.01 else rng.randf_range(.5,1.3))+Vector3.UP*rng.randf_range(2,3)
		context.add_child(token);context.room.resource_drops.append(token)
func _ready():
	visual=Node3D.new();add_child(visual)
	if currency=="alloy":
		# A soft-bevelled gold bar (tools/art/build_ingot.py), sized by its value: 1 small, 5 medium, 10 large.
		# 30% smaller since T-293 (were .9 / 1.2 / 1.55).
		var size={1:.63,5:.84,10:1.085}.get(denomination,.84)
		var bar=preload("res://assets/models/pickups/ingot.glb").instantiate();bar.scale=Vector3.ONE*size;visual.add_child(bar)
		var gold=Visuals.material(Color("ffc948"));gold.set_meta("cozy_original",Vector2(1.0,.16));gold.metallic_specular=.9
		gold.emission_enabled=true;gold.emission=Color("ffb42e");gold.emission_energy_multiplier=.18
		Visuals.cozy_material(gold)
		for mesh in bar.find_children("*","MeshInstance3D",true,false):mesh.material_override=gold
		visual.rotation.y=randf()*TAU
		floor_height=.012
		if denomination>=10:
			# Large bars drop a small glint on the floor; shares the nearest-four pickup light budget.
			var glint=OmniLight3D.new();glint.light_color=Color("ffcf6a");glint.light_energy=.6;glint.omni_range=1.1;glint.omni_attenuation=1.6;glint.shadow_enabled=false;glint.light_volumetric_fog_energy=0;glint.position.y=.1;glint.add_to_group("pickup_lights");add_child(glint)
	elif currency=="tokens":
		# Token (T-025): a bright paw coin that pops high, falls slowly with a tumble, glows and sparkles.
		var coin=MeshInstance3D.new();var disc=CylinderMesh.new();disc.top_radius=.17;disc.bottom_radius=.17;disc.height=.045;disc.radial_segments=20;coin.mesh=disc
		# Bright silver paw coin, matching the token icon (T-100); alloy stays gold.
		var brass=Visuals.material(Color("e4ebf2"));brass.metallic=.95;brass.roughness=.18;brass.emission_enabled=true;brass.emission=Color("c9d6e6");brass.emission_energy_multiplier=.35
		coin.material_override=brass;coin.rotation.x=PI*.5;visual.add_child(coin)
		var paw=Visuals.box(visual,Vector3(0,0,.026),Vector3(.11,.1,.008),Color("7d8a99"));paw.rotation.x=0
		for x in [-.05,0.0,.05]:Visuals.box(visual,Vector3(x,.075,.026),Vector3(.035,.035,.008),Color("7d8a99"))
		var glow=OmniLight3D.new();glow.light_color=Color("dfe8ff");glow.light_energy=.9;glow.omni_range=1.2;glow.shadow_enabled=false;visual.add_child(glow);glow.add_to_group("pickup_lights")
		var sparkle=CPUParticles3D.new();visual.add_child(sparkle);sparkle.amount=6;sparkle.lifetime=.7;sparkle.emission_shape=CPUParticles3D.EMISSION_SHAPE_SPHERE;sparkle.emission_sphere_radius=.18
		sparkle.gravity=Vector3(0,.4,0);sparkle.initial_velocity_min=.1;sparkle.initial_velocity_max=.3;var dot=BoxMesh.new();dot.size=Vector3.ONE*.03;sparkle.mesh=dot
		var spark_mat=StandardMaterial3D.new();spark_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;spark_mat.albedo_color=Color("f2f7ff");dot.material=spark_mat
		floor_height=.2;velocity.y*=1.35
	else:
		Visuals.box(visual,Vector3.ZERO,Vector3(.24,.025,.31),Color("f0ead4"))
		for z in [-.07,0,.07]:Visuals.box(visual,Vector3(0,.017,z),Vector3(.13,.006,.015),Color("728577"))
func _physics_process(delta):
	if collected or not is_instance_valid(arena) or arena.phase not in ["combat","countdown"]:return
	age+=delta
	if velocity.length()>.04:
		# Tokens float down: lighter gravity and a slow tumble while in the air (T-025).
		velocity.y-=(4.5 if currency=="tokens" else 9.0)*delta
		if currency=="tokens":visual.rotation.x+=delta*5.0
		position+=velocity*delta
		var extent=(arena.grid_size-1)*.5
		position.x=clampf(position.x,-extent,extent);position.z=clampf(position.z,-extent,extent)
		if position.y<floor_height:
			position.y=floor_height;velocity.y=absf(velocity.y)*.28;velocity.x*=.5;velocity.z*=.5
			if velocity.length()<.3:
				velocity=Vector3.ZERO
				if not arena.reward.drop_cell_open(arena.grid_pos(position)):
					position=arena.reward.safe_drop_position(position);position.y=floor_height
		visual.rotation.y+=delta*2
	if currency=="tokens" and velocity.length()<=.04:
		# Resting token stands up and turns slowly like a coin on display, with a gentle bob.
		visual.rotation.x=lerpf(visual.rotation.x,0.0,minf(1.0,delta*6.0));visual.position.y=sin(age*3.0)*.04
	if age>.3 and is_instance_valid(arena.player) and not arena.player.dead and arena.flat_distance(position,arena.player.position)<1.1 and arena.clear_shot(arena.player.position,position,.05):collect()
func collect():
	if collected:return
	collected=true;arena.room.resource_drops.erase(self)
	if currency=="alloy":arena.run.earned+=amount;Game.earn(amount)
	elif currency=="tokens":arena.run.tokens+=amount;Game.progression.event("tokens",amount)
	else:arena.run.earned+=amount*Game.DOC_ALLOY;Game.earn(amount*Game.DOC_ALLOY)
	Game.sound("collect_token" if currency=="tokens" else "collect_alloy" if currency=="alloy" else "collect_document",Game)
	var camera=get_viewport().get_camera_3d()
	if camera and not camera.is_position_behind(global_position):ResourceStrip.fly_pickup(currency,camera.unproject_position(global_position))
	queue_free()
