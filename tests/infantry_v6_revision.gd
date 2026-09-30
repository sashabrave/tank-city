extends Node3D
## v6 rifleman: import, budget, clips, rifle grip, one-shots, enemy body, player death.
func _ready():call_deferred("run")
func shot(label:String):
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/r13-infantry-v6-"+label+".png")
func triangles(root:Node)->Vector2i:
	var tris=0;var surfaces=0
	for mesh in root.find_children("*","MeshInstance3D",true,false):
		if not str(mesh.name).ends_with("_body"):continue  # weapon and shield panel are counted separately
		for i in range(mesh.mesh.get_surface_count()):
			surfaces+=1;tris+=mesh.mesh.surface_get_arrays(i)[Mesh.ARRAY_INDEX].size()/3
	return Vector2i(tris,surfaces)
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	var stage=Node3D.new();add_child(stage)
	var cam=Visuals.setup_world(stage,6,Vector3(0,.4,0));cam.position=Vector3(3,4,6);cam.look_at(Vector3(0,.35,0))
	Visuals.box(stage,Vector3(0,-.06,0),Vector3(8,.12,4),Color("747c70"))
	var names=["idle","walk","fire","death"];var models=[]
	for i in range(4):
		var m=Visuals.model("soldier",stage,Vector3((i-1.5)*1.1,0,0));m.rotation.y=PI+.5;m.equip_weapon("rifle");models.append(m)
	var m=models[0]
	assert(m.get_child(0).scene_file_path.ends_with("infantry_v6/soldier.glb"))
	# Runtime palette mirrors the Blender kit palette.
	var exported=JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/infantry_v6/palette.json"))
	assert(exported.names==InfantryPalette.NAMES and exported.colors==InfantryPalette.COLORS)
	for kind in Visuals.INFANTRY:
		var cat=Visuals.model(kind,stage,Vector3(0,0,-3));cat.equip_weapon(EnemyLoadouts.default_for("grenadier" if kind=="rpg_soldier" else kind) if kind!="rpg_soldier" else "rpg")
		assert(cat.skeleton.find_bone("tail.001")>=0 and cat.find_child("Flashlight",true,false)!=null,kind)
		assert(triangles(cat.get_child(0)).x<=2400,kind)
		cat.queue_free()
	for clip in ["hero_idle","hero_walk","hero_fire","hero_hit","hero_death"]:assert(m.player.has_animation(clip),clip)
	assert(m.player.get_animation("hero_walk").loop_mode==Animation.LOOP_LINEAR)
	assert(m.player.get_animation("hero_death").loop_mode==Animation.LOOP_NONE)
	var budget=triangles(m.get_child(0));assert(budget.x<=2100 and budget.y<=3,str(budget))
	models[1].preview_moving=true
	await get_tree().create_timer(.3).timeout
	assert(models[1].player.current_animation=="hero_walk" and m.player.current_animation=="hero_idle")
	# Support hand lands on the rifle's fore grip.
	var hand=m.skeleton.global_transform*m.skeleton.get_bone_global_pose(m.skeleton.find_bone("hand.L")).origin
	var grip_gap=hand.distance_to(m.support_grip.global_position);assert(grip_gap<.03,str(grip_gap))
	# Firing shoulders the weapon as a layer over the clip (running legs keep running).
	models[2].kick();models[1].kick();assert(models[2].aim_timer>0 and models[1].player.current_animation=="hero_walk")
	await get_tree().create_timer(.25).timeout
	assert(models[2].aim_blend>.9 and models[1].aim_blend>.9)
	var forward=-models[2].global_basis.z;var barrel=(models[2].muzzle.global_position-models[2].weapon_socket.global_position).normalized()
	assert(forward.dot(barrel)>.9,str(forward.dot(barrel)))
	models[3].play_death()
	await get_tree().create_timer(.1).timeout;await shot("lineup-a")
	await get_tree().create_timer(.9).timeout
	assert(models[2].player.current_animation=="hero_idle")
	assert(models[3].dying and models[3].player.current_animation in ["","hero_death"])
	var pelvis=models[3].skeleton.global_transform*models[3].skeleton.get_bone_global_pose(models[3].skeleton.find_bone("head")).origin
	assert(pelvis.y<.3,str(pelvis))
	await shot("lineup-b")
	stage.queue_free();await get_tree().process_frame
	# Battle: enemy rifleman leaves a falling body, player death uses the clip.
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.run_seed=42;arena.begin_room(3);arena.phase="combat"
	var enemy=arena.spawn_actor("soldier",Vector2i(arena.grid_size/2,arena.grid_size-6),false,false,1,false,"rifle");enemy.fire_cooldown=9
	await get_tree().create_timer(.3).timeout
	enemy.take_damage(1);assert(enemy.model.player.current_animation in ["hero_hit","hero_walk"])
	var body=enemy.model;enemy.take_damage(9999)
	await get_tree().process_frame
	assert(is_instance_valid(body) and body.get_parent()==arena and body.dying)
	await get_tree().create_timer(.8).timeout;await shot("battle-body")
	await get_tree().create_timer(3.0).timeout;assert(not is_instance_valid(body))
	var finished=[false]
	preload("res://scripts/death_presentation.gd").play(arena,false,func():finished[0]=true)
	var fallen=arena.get_children().filter(func(n):return n.has_method("has_death") and n.dying)
	assert(fallen.size()==1)
	await get_tree().create_timer(.9).timeout;await shot("player-death")
	await get_tree().create_timer(.6).timeout;assert(finished[0])
	print("INFANTRY V6 PASS: %d tris, %d surfaces, grip gap %.3f, clips, enemy body, player death" % [budget.x,budget.y,grip_gap])
	get_tree().quit()
