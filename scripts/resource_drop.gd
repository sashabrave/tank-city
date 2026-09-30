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
static func split(value:int)->Array:
	var result=[]
	for unit in [50,20,5]:
		while value>=unit:result.append({"amount":unit,"denomination":unit});value-=unit
	if value>0:result.append({"amount":value,"denomination":5})
	return result
static func spawn(context,pos:Vector3,value:int,kind:String="alloy",blast:Vector3=Vector3.ZERO):
	pos=context.reward.safe_drop_position(pos)
	var entries=split(value) if kind=="alloy" else [{"amount":value,"denomination":1}]
	var rng=RandomNumberGenerator.new();rng.randomize()
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
		var radius=.12 if denomination==5 else .18 if denomination==20 else .25
		floor_height=radius*1.4+.025
		var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for side in range(4):
			var a=Vector3(cos(side*PI*.5),0,sin(side*PI*.5))*radius
			var b=Vector3(cos((side+1)*PI*.5),0,sin((side+1)*PI*.5))*radius
			for point in [Vector3.UP*radius*1.4,b,a,Vector3.DOWN*radius*1.4,a,b]:surface.add_vertex(point)
		surface.generate_normals()
		var mesh=MeshInstance3D.new();mesh.mesh=surface.commit();var gold=Visuals.material(Color("ffc948"));gold.set_meta("cozy_original",Vector2(1.0,.16));gold.metallic_specular=.9;gold.cull_mode=BaseMaterial3D.CULL_DISABLED
		# Faint warm self-light keeps gold bright even when the sky reflection is dim.
		gold.emission_enabled=true;gold.emission=Color("ffb42e");gold.emission_energy_multiplier=.18
		Visuals.cozy_material(gold);mesh.material_override=gold;visual.add_child(mesh)
		if denomination>=20:
			# Large tokens drop a small glint on the floor; shares the nearest-four pickup light budget.
			var glint=OmniLight3D.new();glint.light_color=Color("ffcf6a");glint.light_energy=.6;glint.omni_range=1.1;glint.omni_attenuation=1.6;glint.shadow_enabled=false;glint.light_volumetric_fog_energy=0;glint.position.y=-floor_height*.4;glint.add_to_group("pickup_lights");add_child(glint)
	else:
		Visuals.box(visual,Vector3.ZERO,Vector3(.24,.025,.31),Color("f0ead4"))
		for z in [-.07,0,.07]:Visuals.box(visual,Vector3(0,.017,z),Vector3(.13,.006,.015),Color("728577"))
func _physics_process(delta):
	if collected or not is_instance_valid(arena) or arena.phase not in ["combat","countdown"]:return
	age+=delta
	if velocity.length()>.04:
		velocity.y-=9*delta
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
	if age>.3 and is_instance_valid(arena.player) and not arena.player.dead and arena.flat_distance(position,arena.player.position)<1.1 and arena.clear_shot(arena.player.position,position,.05):collect()
func collect():
	if collected:return
	collected=true;arena.room.resource_drops.erase(self)
	if currency=="alloy":arena.run.earned+=amount;Game.earn(amount)
	else:Game.cores+=amount;Game.save_progress()
	Game.sound("collect_alloy" if currency=="alloy" else "collect_document",Game)
	var camera=get_viewport().get_camera_3d()
	if camera and not camera.is_position_behind(global_position):ResourceStrip.fly_pickup(currency,camera.unproject_position(global_position))
	queue_free()
