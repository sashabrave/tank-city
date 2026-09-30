extends Node
func snapshot(name: String):
	await get_tree().create_timer(.25).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://screenshots/"+name+".png")
func _ready():
	Game.save_enabled=false;Game.sound_enabled=false;Game.health_level=0;Game.damage_level=0
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub)
	await snapshot("hub")
	hub.avatar.position=Vector3(0,0,0);hub.cell=Vector2i(0,0);hub.interact()
	await snapshot("workshop")
	hub.close_station()
	hub.free()
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena)
	arena.auto_pause_enabled=false;arena.set_physics_process(false);arena.run_seed=130925
	var maps=[]
	for room in range(6):
		arena.begin_room(room);arena.start_wave(2 if room<5 else 0);arena.phase="combat"
		arena.player.set_physics_process(false)
		maps.append(arena.current_layout.duplicate())
		if room<5:
			var enemy=arena.spawn_actor("soldier" if room==0 else "tank",Vector2i(1,0),false);enemy.set_physics_process(false)
			if room==1:
				var shield=arena.spawn_actor("shield",arena.find_free_near(Vector2i(6,5)),false);shield.set_physics_process(false);shield.shield_phase="active";shield.shield_visual.rotation.x=0
			if room==2:
				for entry in [["grenadier",Vector2i(5,4)],["buggy",Vector2i(8,5)],["mortar",Vector2i(11,2)]]:
					var unit=arena.spawn_actor(entry[0],arena.find_free_near(entry[1]),false);unit.set_physics_process(false)
				arena.install_turret();arena.install_turret()
				arena.throw_grenade(arena.actors.back(),Vector3.ZERO)
			if room>0:
				var drone=arena.spawn_actor("drone",Vector2i(0,arena.grid_size-4),false);drone.set_physics_process(false)
			arena.make_wreck("apc" if room==0 else "tank",Vector2i(arena.base_cell.x-2,arena.grid_size-3),Vector2i.UP,false,5 if room==0 else 9)
			arena.toast("%d × %d · кирпич / бетон / маскировочная сетка" % [arena.grid_size,arena.grid_size])
		else:
			var boss=arena.spawn_actor("boss",Vector2i(arena.base_cell.x-2,2),false);boss.set_physics_process(false)
			arena.toast("Командир 4×4 · вращающаяся башня и круговой залп")
			arena.boss_step(boss,.3)
			boss.radial_timer=0;arena.boss_step(boss,.01)
			await snapshot("boss_warning")
			boss.warning_ring.visible=false;boss.attack_label.visible=false
			arena.boss_radial_attack(boss)
		await snapshot("room_"+str(room+1))
		if room==0:
			arena.phase="upgrade";arena.hud.show_upgrades();await snapshot("upgrades")
	var file=FileAccess.open("res://docs/sample_maps.json",FileAccess.WRITE);file.store_string(JSON.stringify(maps))
	arena.free();print("R13 screenshots saved");get_tree().quit()
