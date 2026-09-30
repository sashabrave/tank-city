extends Node3D
## Vehicles: kit_v4 geometry with v6 materials. Node contract for kit_model, team paint, metal, lamps, beacons.
func _ready():call_deferred("run")
func shot(label:String):
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/r13-vehicles-v6-"+label+".png")
func triangles(root:Node)->int:
	var tris=0
	for mesh in root.find_children("*","MeshInstance3D",true,false):
		for i in range(mesh.mesh.get_surface_count()):tris+=mesh.mesh.surface_get_arrays(i)[Mesh.ARRAY_INDEX].size()/3
	return tris
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Settings.values.world_lighting="day"
	var stage=Node3D.new();add_child(stage)
	var cam=Visuals.setup_world(stage,7,Vector3(0,.3,0));cam.position=Vector3(0,5,6);cam.look_at(Vector3(0,.2,.3))
	var biome=preload("res://scripts/biome_catalog.gd").ENTRIES[4]
	Visuals.box(stage,Vector3(0,-.06,0),Vector3(16,.12,8),Color(biome.floor))
	var expect={"tank":[1,1,0,0],"apc":[1,1,6,0],"buggy":[1,1,4,0],"drone":[0,0,4,0],"flyer":[1,1,0,4],"boss":[3,3,0,0]}
	var x=-6.0
	for kind in Visuals.VEHICLES:
		for enemy in [false,true]:
			var m=Visuals.model(kind,stage,Vector3(x,0,-1.4 if enemy else 1.4));m.rotation.y=PI+.5
			assert(m.get_child(0).scene_file_path.ends_with("vehicles_v6/"+kind+".glb"),kind)
			var e=expect[kind]
			assert(m.yaws.size()==e[0] and m.pitches.size()==e[1] and m.wheels.size()==e[2] and m.rotors.size()==e[3],"%s %s" % [kind,[m.yaws.size(),m.pitches.size(),m.wheels.size(),m.rotors.size()]])
			assert(m.recoils.size()>=e[1],kind)
			if kind!="drone":assert(m.paint_materials.size()>=1,kind+" team paint surface")
			var metal=m.find_children("*","MeshInstance3D",true,false).any(func(mesh):return range(mesh.mesh.get_surface_count()).any(func(i):return mesh.mesh.surface_get_material(i)!=null and mesh.mesh.surface_get_material(i).resource_name=="V6_metal"))
			assert(metal,kind+" metal surface")
			if kind in ["drone","flyer"]:assert(m.beacons.size()==1,kind+" beacon")
			if kind=="boss":assert(Visuals.named_part(m,"boss_main_yaw")!=null)
			if kind in ["tank","apc","buggy"]:
				assert(m.find_children("*","SpotLight3D",true,false).size()==2,kind+" beams")
			if enemy:m.preview_biome=biome;m.set_paint("enemy",2 if kind=="apc" else 1)
			m.aim(.6,.1);m.preview_moving=true
		x+=2.4
	await get_tree().create_timer(.8).timeout
	await shot("lineup")
	print("VEHICLES V6 PASS: 6 kinds, node contract, paint, lamps, beacons")
	get_tree().quit()
