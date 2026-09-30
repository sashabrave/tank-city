extends Node3D
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false
	var stage=Node3D.new();add_child(stage)
	var cam=Visuals.setup_world(stage,14,Vector3(0,.5,1));cam.position=Vector3(2,12,16);cam.look_at(Vector3(0,.4,1))
	Visuals.box(stage,Vector3(0,-.09,1),Vector3(15,.15,10),Color("747c70"))
	for x in range(-7,8):Visuals.box(stage,Vector3(x,0,1),Vector3(.012,.005,10),Color("a6ad9a"))
	for z in range(-4,7):Visuals.box(stage,Vector3(0,0,z),Vector3(15,.005,.012),Color("a6ad9a"))
	var modes=["friendly","enemy","enemy","capture","explode"]
	for i in range(5):
		var x=(i-2)*2.55
		var vehicle=Visuals.model("apc",stage,Vector3(x,0,-2));vehicle.rotation.y=PI+.3
		vehicle.set_paint(modes[i],2 if i==2 else 1);vehicle.clock=0;vehicle.set_process(false);vehicle._process(.1)
		var man=Visuals.model("shield" if i==3 else "sniper" if i==4 else "soldier",stage,Vector3(x,0,0));man.rotation.y=PI+.2;man.equip_weapon("shotgun" if i==3 else "sniper" if i==4 else "rifle");man.set_paint("friendly" if i==0 else "enemy",2 if i>=2 else 1);man.set_process(false);man._process(.1)
		Visuals.label3d(stage,["PLAYER","ENEMY I","ENEMY II","CAPTURE","DESTRUCT"][i],Vector3(x,.03,-3.3),Color.WHITE,22)
	var kinds=["buggy","tank","drone","flyer"]
	for i in range(4):
		var m=Visuals.model(kinds[i],stage,Vector3((i-1.5)*2.7,.5 if kinds[i]=="flyer" else 0,2.5));m.rotation.y=PI+.3
	for i in range(7):
		var parent=Node3D.new();stage.add_child(parent);parent.position=Vector3((i-3)*1.5,0,4.5)
		var id=["heart","repair","wall","vehicle_repair","turret","vehicle","star"][i]
		LootCatalog.visual(parent,id)
	await get_tree().create_timer(.3).timeout
	RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("res://art_demo/game_update_v6/paint_sizes_bonuses.png")
	stage.queue_free();await get_tree().process_frame
	Game.equipped_abilities=["shield"];Game.ability_slots=1
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.run_seed=42;arena.begin_room(12);arena.phase="combat";arena.set_physics_process(false)
	for actor in arena.actors:actor.set_physics_process(false)
	for i in range(4):
		var actor=arena.spawn_actor(["soldier","grenadier","shield","sniper"][i],Vector2i(9+i*2,arena.grid_size-6),false,false,2,false,["smg","rpg","shotgun","sniper"][i]);actor.set_physics_process(false)
	arena.abilities.cast_slot(0)
	await get_tree().create_timer(.3).timeout
	RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("res://art_demo/game_update_v6/battle_shield.png")
	get_tree().quit()
