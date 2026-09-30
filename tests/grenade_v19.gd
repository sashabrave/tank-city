extends Node3D
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades();Campaign.configure(1)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=88;add_child(arena);arena.set_physics_process(false);arena.auto_pause_enabled=false;arena.phase="combat";arena.player.set_physics_process(false)
	for wall in arena.walls.values():wall.node.queue_free()
	arena.walls.clear();arena.player.position=arena.world_pos(Vector2i(5,8));arena.player.facing=Vector2i.UP
	var enemy=arena.spawn_actor("soldier",Vector2i(5,3),false);enemy.set_physics_process(false)
	enemy.hp=100;enemy.max_hp=100
	arena.abilities.select("grenade");assert(arena.abilities.cast())
	var grenade=arena.grenades[0];grenade.set_physics_process(false)
	assert(grenade.friendly and is_instance_valid(grenade.marker))
	assert(is_equal_approx(grenade.marker.get_meta("blast_radius"),arena.abilities.radius()))
	assert(grenade.target==arena.world_pos(Vector2i(5,3)))
	assert(not grenade.marker.visible and is_equal_approx(Balance.CONFIG.combat.grenade_radius,1.5))
	grenade._physics_process(.3);assert(not grenade.marker.visible)
	grenade._physics_process(.36);assert(grenade.marker.visible)
	var before=enemy.hp
	grenade._physics_process(grenade.flight_time+grenade.fuse+.01)
	assert(grenade.spent and enemy.hp<before)
	assert(arena.grenades.is_empty() and arena.find_children("GrenadeShockwave","Node3D",true,false).size()==1)
	arena.queue_free();await get_tree().process_frame
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub);hub.set_physics_process(false)
	var effect=load("res://scripts/hub_ability_effect.gd").new();effect.hub=hub;effect.kind="grenade";hub.add_child(effect);effect.set_process(false)
	assert(is_instance_valid(effect.grenade_marker));effect._process(effect.duration+.01)
	assert(hub.find_children("GrenadeShockwave","Node3D",true,false).size()==1)
	hub.queue_free();await get_tree().process_frame
	var motion_script=load("res://scripts/grenade_motion.gd")
	var motion=motion_script.new(Vector3(0,.8,0),Vector3(0,0,-5),.65,func(_cell):return false)
	motion.advance(.65)
	assert(absf(motion.position.z+5)<.04)
	motion.advance(2)
	assert(motion.position.z>=-5.5 and motion.position.z<=-5)
	assert(is_equal_approx(motion.position.y,.14) and motion.velocity.length()<.001)
	for fps in [30,60,120]:
		var bounce=motion_script.new(Vector3(0,.8,0),Vector3(0,0,-5),.65,func(probe):return Vector2i(roundi(probe.x),roundi(probe.z))==Vector2i(0,-2))
		for frame in range(fps*3):bounce.advance(1.0/fps)
		assert(bounce.collided and bounce.landed)
		assert(bounce.position.z> -1.36 and bounce.position.z< -0.86)
		assert(is_equal_approx(bounce.position.y,.14))
	print("PASS grenade: actual ability radius, impact damage, shared explosion, marker cleanup, hub preview")
	get_tree().quit()
