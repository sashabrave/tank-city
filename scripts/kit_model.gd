extends Node3D
## Rigid vehicle articulation; static tracks. Authored +Y becomes Godot -Z.
var kind=""
var wheels:Array[Node3D]=[]
var rotors:Array[Node3D]=[]
var recoils:Array[Node3D]=[]
var homes:Array[Vector3]=[]
var yaws:Array[Node3D]=[]
var pitches:Array[Node3D]=[]
var beacons:Array[StandardMaterial3D]=[]
var skeleton:Skeleton3D
var player:AnimationPlayer
var clock=0.0
var recoil=0.0
var aim_yaw=0.0
var aim_pitch=0.0
var preview_moving=false
var preview_speed=1.0
var weapon_socket:Node3D
var equipped_weapon:Node3D
var weapon_id=""
var support_grip:Node3D
var muzzle:Node3D
var protection:MeshInstance3D
var preview_biome:Dictionary={}
var beacon_phase=0.0
var aim_timer=0.0  # seconds the rifle stays shouldered after the last shot
var aim_blend=0.0  # camo source outside an arena (galleries, tests)
var oneshot=""  # clip playing once over locomotion (fire, hit, death)
var dying=false
var last_moving=false
func _ready():
	for node in find_children("*","Node3D",true,false):
		var title=str(node.name).to_lower()
		if "_wheel_" in title:wheels.append(node)
		if "_rotor_" in title:rotors.append(node)
		if "recoil" in title:recoils.append(node);homes.append(node.position)
		if title.ends_with("yaw"):yaws.append(node)
		if title.ends_with("pitch"):pitches.append(node)
		if node is Skeleton3D:skeleton=node
		if title.begins_with("weaponsocket"):weapon_socket=node
		if title.ends_with("_beacon") and node is MeshInstance3D:
			var mat=StandardMaterial3D.new();mat.albedo_color=Color("681e18");mat.emission_enabled=true;mat.emission=Color("ff2412");mat.emission_energy_multiplier=0
			node.material_override=mat;beacons.append(mat)
	beacon_phase=fmod(absf(float(hash(get_instance_id()))),5200.0)/1000.0
	if kind in ["drone","flyer"] and beacons.is_empty():
		var indicator=Visuals.box(self,Vector3(0,.68,0),Vector3(.09,.07,.09),Color("661921"))
		var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.emission_enabled=true;mat.emission=Color("ff2038");indicator.material_override=mat;beacons.append(mat)
	for node in find_children("*","AnimationPlayer",true,false):player=node
	if player:
		player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for animation in player.get_animation_list():
			if "idle" in animation or "walk" in animation:player.get_animation(animation).loop_mode=Animation.LOOP_LINEAR
	Visuals.refresh_cozy_materials(self)
	set_paint("friendly")
	var actor=get_parent()
	if actor is CombatActor and actor.player_owned:
		protection=MeshInstance3D.new();var sphere=SphereMesh.new()
		sphere.radius=.7 if kind=="soldier" else .9;sphere.height=sphere.radius*2
		protection.mesh=sphere;add_child(protection);protection.position.y=.7
		var material=StandardMaterial3D.new();material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color=Color(.25,.8,1,.15);material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		protection.material_override=material;protection.hide()
func aim(world_yaw:float,pitch:float=0.0):
	aim_yaw=wrapf(world_yaw-global_rotation.y,-PI,PI);aim_pitch=clampf(pitch,-.35,.35)
func _process(delta):
	var actor=get_parent()
	if protection and is_instance_valid(actor.arena):protection.visible=actor.arena.abilities.shield_time>0
	if actor is CombatActor:
		if actor.dead:return
		if is_instance_valid(actor.arena):
			if actor.arena.phase not in ["combat","countdown"]:return
			if not actor.player_owned and not actor.allied and (actor.stun_time>0 or actor.arena.freeze_time>0):return
	clock+=delta
	if paint_mode in ["capture","explode"]:
		for mat in paint_materials:mat.set_shader_parameter("flash",0.65 if fmod(clock,.8)<.3 else 0.0)
	var moving=actor.moving if actor is CombatActor else preview_moving
	var speed=actor.speed if actor is CombatActor else preview_speed
	if moving:
		for wheel in wheels:
			var radius=maxf(wheel.get_aabb().size.y*.5*wheel.global_basis.get_scale().y,.02)
			wheel.rotation.x-=delta*speed/radius
	for i in range(rotors.size()):rotors[i].rotation.y+=delta*28*(1 if i%2==0 else -1)
	for yaw in yaws:yaw.rotation.y=rotate_toward(yaw.rotation.y,aim_yaw,delta*2.8)
	for pitch in pitches:pitch.rotation.x=lerpf(pitch.rotation.x,aim_pitch,minf(1,delta*8))
	recoil=maxf(0,recoil-delta*6)
	for i in range(recoils.size()):recoils[i].position=homes[i]+Vector3(0,0,recoil*(.012 if kind=="flyer" else .025))
	# Rare, sharp double strobe; each drone keeps its own phase (visual only).
	var strobe=fmod(clock+beacon_phase,5.2)
	var on=strobe<.06 or (strobe>.15 and strobe<.21)
	for mat in beacons:
		mat.emission_energy_multiplier=6.0 if on else 0.0;mat.albedo_color=Color("ff263f") if on else Color("571c25")
	last_moving=moving
	if player:
		if oneshot!="" and not dying and player.current_animation!=oneshot:oneshot=""
		if oneshot=="":
			var clip="hero_walk" if moving else "hero_idle"
			if player.has_animation(clip) and player.current_animation!=clip:player.play(clip,.12)
		player.advance(delta)
	# Small additive shoulder kick keeps locomotion continuous while firing.
	if skeleton:
		var bone=skeleton.find_bone("spine")
		if bone>=0:skeleton.set_bone_pose_rotation(bone,skeleton.get_bone_pose_rotation(bone)*Quaternion(Vector3.RIGHT,-recoil*.055))
	if skeleton and not dying and kind in Visuals.INFANTRY:aim_weapon(delta)
	elif skeleton and support_grip and kind!="shield":fit_support_hand()
func kick():
	recoil=1.0;aim_timer=1.1
func flinch():
	if not last_moving:play_once("hero_hit")
func play_once(clip:String)->bool:
	if dying or not player or not player.has_animation(clip):return false
	oneshot=clip;player.play(clip,.06);return true
func has_death()->bool:return player!=null and player.has_animation("hero_death")
func play_death()->bool:
	if not has_death():return false
	dying=true;oneshot="hero_death";player.play("hero_death",.08);return true

func equip_weapon(id:String):
	if not is_instance_valid(weapon_socket):return
	var path="res://assets/models/infantry_v6/weapon_"+id+".glb"
	if not ResourceLoader.exists(path):return
	for child in weapon_socket.get_children():
		weapon_socket.remove_child(child);child.queue_free()
	equipped_weapon=load(path).instantiate();weapon_socket.add_child(equipped_weapon);weapon_id=id
	support_grip=Visuals.named_part(equipped_weapon,"SupportGrip")
	muzzle=Visuals.named_part(equipped_weapon,"Muzzle")

func rotate_bone_toward(index:int,child_index:int,target:Vector3):
	var pose=skeleton.get_bone_global_pose(index)
	var direction=skeleton.get_bone_global_pose(child_index).origin-pose.origin
	var desired=target-pose.origin
	if direction.length_squared()<.000001 or desired.length_squared()<.000001:return
	var rotation=Quaternion(direction.normalized(),desired.normalized())
	var parent=skeleton.get_bone_parent(index)
	var parent_basis=skeleton.get_bone_global_pose(parent).basis if parent>=0 else Basis.IDENTITY
	var local_basis=parent_basis.inverse()*Basis(rotation)*pose.basis
	skeleton.set_bone_pose_rotation(index,local_basis.get_rotation_quaternion())

## Shoulder the weapon toward the shot: a layer over any clip (legs keep running).
## Blends the weapon bone from its carried pose to a forward aim with recoil, then solves both arms onto it.
func aim_weapon(delta:float):
	var bone=skeleton.find_bone("weapon")
	if bone<0:return
	aim_timer=maxf(0,aim_timer-delta)
	aim_blend=move_toward(aim_blend,1.0 if aim_timer>0 else 0.0,delta*(9.0 if aim_timer>0 else 2.5))
	var weapon_pose=skeleton.get_bone_global_pose(bone)
	if aim_blend>0:
		var aimed=skeleton.get_bone_global_rest(bone)  # rest pose points straight ahead at the hip
		var forward=aimed.basis.y.normalized();var up=aimed.basis.z.normalized()
		# Two-handed guns come to the chest centre; the shield hand keeps the gun on the right.
		aimed.origin+=up*.075-aimed.basis.x.normalized()*(0.0 if kind=="shield" else .03)+forward*.02-forward*.035*recoil
		aimed.basis=Basis(aimed.basis.x.normalized(),recoil*.14)*aimed.basis
		weapon_pose=weapon_pose.interpolate_with(aimed,aim_blend)
		var local=skeleton.get_bone_global_pose(skeleton.get_bone_parent(bone)).affine_inverse()*weapon_pose
		skeleton.set_bone_pose_position(bone,local.origin);skeleton.set_bone_pose_rotation(bone,local.basis.get_rotation_quaternion())
		fit_arm("R",weapon_pose.origin-weapon_pose.basis.y.normalized()*.03-weapon_pose.basis.z.normalized()*.01,Vector3(1,-.4,.2))
	if kind=="shield" or not support_grip:return
	var support=weapon_pose*(weapon_socket.transform*weapon_socket.to_local(support_grip.global_position))
	fit_arm("L",support,Vector3(-1,-.4,.2))

func fit_arm(side:String,target:Vector3,pole:Vector3):
	var upper=skeleton.find_bone("upper_arm."+side);var forearm=skeleton.find_bone("forearm."+side);var hand=skeleton.find_bone("hand."+side)
	if upper<0 or forearm<0 or hand<0:return
	var shoulder=skeleton.get_bone_global_pose(upper).origin
	var elbow=skeleton.get_bone_global_pose(forearm).origin
	var palm=skeleton.get_bone_global_pose(hand).origin
	var length_a=shoulder.distance_to(elbow);var length_b=elbow.distance_to(palm)
	var direction=(target-shoulder).normalized()
	var distance=clampf(shoulder.distance_to(target),absf(length_a-length_b)+.0001,length_a+length_b-.0001)
	var along=(length_a*length_a-length_b*length_b+distance*distance)/(2*distance)
	var height=sqrt(maxf(0,length_a*length_a-along*along))
	var bend=(pole-direction*pole.dot(direction)).normalized()
	rotate_bone_toward(upper,forearm,shoulder+direction*along+bend*height)
	rotate_bone_toward(forearm,hand,target)

func fit_support_hand():
	# Analytic two-bone support arm: only three bones, no physics or full-body IK.
	var upper=skeleton.find_bone("upper_arm.L");var forearm=skeleton.find_bone("forearm.L");var hand=skeleton.find_bone("hand.L")
	if upper<0 or forearm<0 or hand<0:return
	var shoulder=skeleton.get_bone_global_pose(upper).origin
	var elbow=skeleton.get_bone_global_pose(forearm).origin
	var palm=skeleton.get_bone_global_pose(hand).origin
	var target=skeleton.to_local(support_grip.global_position)
	var length_a=shoulder.distance_to(elbow);var length_b=elbow.distance_to(palm)
	var direction=(target-shoulder).normalized()
	var distance=clampf(shoulder.distance_to(target),absf(length_a-length_b)+.0001,length_a+length_b-.0001)
	var along=(length_a*length_a-length_b*length_b+distance*distance)/(2*distance)
	var height=sqrt(maxf(0,length_a*length_a-along*along))
	var pole=Vector3(-1,-.4,.2);var bend=(pole-direction*pole.dot(direction)).normalized()
	rotate_bone_toward(upper,forearm,shoulder+direction*along+bend*height)
	rotate_bone_toward(forearm,hand,target)


var paint_materials:Array[ShaderMaterial]=[]
var paint_mode="friendly"
var paint_rank=1
## Fur per unit (player is always the ginger cat), camo from the room biome for enemies.
func apply_palette():
	if kind not in Visuals.INFANTRY and kind not in Visuals.VEHICLES:return
	var actor=get_parent()
	var camo={}
	if paint_mode=="enemy" and actor is CombatActor and is_instance_valid(actor.arena):camo=InfantryPalette.biome_camo(actor.arena.room_palette())
	elif paint_mode=="enemy":camo=InfantryPalette.biome_camo(preview_biome)
	var fur=0 if (actor is CombatActor and actor.player_owned) or not actor is CombatActor else 1+posmod(hash(get_instance_id()),InfantryPalette.FURS.size()-1)
	for mesh in find_children("*","MeshInstance3D",true,false):
		if weapon_socket and weapon_socket.is_ancestor_of(mesh):continue
		for index in range(mesh.mesh.get_surface_count()):
			var source=mesh.mesh.surface_get_material(index)
			if source is StandardMaterial3D and source.resource_name==InfantryPalette.SOURCE_MATERIAL:
				mesh.set_surface_override_material(index,InfantryPalette.material(source,fur,camo))
func set_paint(mode:String,rank:int=1):
	paint_mode=mode;paint_rank=rank
	apply_palette()
	if paint_materials.is_empty():
		for mesh in find_children("*","MeshInstance3D",true,false):
			if mesh.material_override!=null:continue
			for index in range(mesh.mesh.get_surface_count()):
				var source=mesh.get_active_material(index)
				if not source is StandardMaterial3D:continue
				var title=source.resource_name
				var is_atlas="KIT4_Game_Atlas" in title
				if not is_atlas and title not in ["Hero_warm_ivory","V2_ivory_marking","V2_light_sage","V6_hull_paint"]:continue
				var mat=ShaderMaterial.new();mat.shader=preload("res://assets/shaders/team_paint.gdshader")
				mat.set_shader_parameter("atlas",is_atlas)
				mat.set_shader_parameter("base_color",source.albedo_color)
				mat.set_shader_parameter("surface_roughness",source.roughness)
				if is_atlas:
					mat.set_shader_parameter("color_texture",source.albedo_texture)
					mat.set_shader_parameter("signal_texture",source.emission_texture)
				var barrel="barrel" in str(mesh.name) or "aux_" in str(mesh.name) and "gun" in str(mesh.name) or str(mesh.name) in ["buggy_mg","flyer_gun"]
				mat.set_meta("barrel",barrel)
				mat.set_shader_parameter("barrel_end",mesh.get_aabb().position.z+mesh.get_aabb().size.z*(.5 if str(mesh.name)=="buggy_mg" else 1.01))
				mesh.set_surface_override_material(index,mat);paint_materials.append(mat)
	var color={"friendly":Color("82956b") if kind in ["tank","boss","apc","buggy","flyer","drone"] else Color("ddd9c5"),"enemy":Color("191e1c") if rank==3 else Color("702d2b"),"capture":Color("259642"),"explode":Color("af231b")}.get(mode,Color.WHITE)
	for mat in paint_materials:
		mat.set_shader_parameter("paint_color",color)
		mat.set_shader_parameter("barrel_white",mode=="friendly" and mat.get_meta("barrel",false))
		mat.set_shader_parameter("striped",mode=="enemy" and rank==2)
		mat.set_shader_parameter("flash",0.0)
