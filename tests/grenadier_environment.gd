extends Node3D
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Game.reset_upgrades()
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false);arena.phase="combat"
	var center=arena.base_cell
	var near=center+Vector2i.LEFT;var far=center+Vector2i(3,0);var solid=center+Vector2i.RIGHT
	for cell in [near,far,solid]:
		if arena.walls.has(cell):arena.walls[cell].node.queue_free();arena.walls.erase(cell)
	arena.add_wall(near,10);arena.add_wall(far,10);arena.add_wall(solid,-1)
	var enemy=arena.spawn_actor("grenadier",Vector2i(3,3),false);enemy.set_physics_process(false)
	var amount=enemy.damage;assert(amount>0)
	var hp=arena.base_hp
	arena.throw_grenade(enemy,arena.world_pos(center))
	var grenade=arena.grenades.back();grenade.set_physics_process(false)
	assert(is_equal_approx(grenade.damage,amount) and not grenade.friendly)
	grenade._physics_process(grenade.flight_time+.01)
	assert(grenade.spent)
	assert(is_equal_approx(arena.base_hp,hp-amount))
	assert(is_equal_approx(arena.walls[near].hp,10-amount))
	assert(arena.walls[far].hp==10 and arena.walls[solid].hp==-1)
	grenade._physics_process(1);assert(is_equal_approx(arena.base_hp,hp-amount))
	print("GRENADIER PASS: normal grenade damage to base and nearby destructible block; distant and solid blocks untouched; no duplicate explosion")
	get_tree().quit()
