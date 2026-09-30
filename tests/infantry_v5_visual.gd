extends Node3D
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false
	var stage=Node3D.new();add_child(stage)
	var cam=Visuals.setup_world(stage,11,Vector3(0,.65,0));cam.position=Vector3(5,6,10);cam.look_at(Vector3(0,.65,0))
	Visuals.box(stage,Vector3(0,-.07,0),Vector3(12,.12,4),Color("747c70"))
	for x in range(-6,7):Visuals.box(stage,Vector3(x,0,0),Vector3(.012,.006,4),Color("b6bcaa"))
	for z in range(-2,3):Visuals.box(stage,Vector3(0,0,z),Vector3(12,.006,.012),Color("b6bcaa"))
	var entries=[["soldier","pistol"],["soldier","smg"],["soldier","rifle"],["soldier","shotgun"],["grenadier","grenade_launcher"],["shield","shotgun"],["sniper","sniper"],["rpg_soldier","rpg"]]
	for i in range(entries.size()):
		var e=entries[i];var m=Visuals.model(e[0],stage,Vector3((i-3.5)*1.22,0,0));m.rotation.y=PI+.13;m.equip_weapon(e[1]);m.preview_moving=false
		Visuals.label3d(stage,e[1],m.position+Vector3(0,.03,.9),Color.WHITE,20)
	await get_tree().create_timer(.35).timeout
	RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("res://art_demo/infantry_v5/godot_infantry.png")
	stage.queue_free();await get_tree().process_frame
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.run_seed=42;arena.begin_room(12);arena.phase="combat"
	for i in range(4):
		var actor=arena.spawn_actor(["soldier","grenadier","shield","sniper"][i],Vector2i(9+i*2,arena.grid_size-6),false,false,1,false,["smg","rpg","shotgun","sniper"][i]);actor.fire_cooldown=3
	await get_tree().create_timer(.7).timeout
	RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("res://art_demo/infantry_v5/godot_battle.png")
	print("INFANTRY VISUAL CAPTURED");get_tree().quit()
