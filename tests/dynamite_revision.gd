extends Node3D
## Dynamite (Подрывник's first ability): fuse, then a cross that breaks brick lines through to concrete,
## hits enemies on the lines and spares the soldier. Range grows with utility.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades();Campaign.configure(1)
	check(ClassCatalog.abilities("gunner").slice(0,2)==["dynamite","gas"],"Подрывник: dynamite first, gas second")
	check(AbilityCatalog.DATA.has("dynamite"),"dynamite is in the ability catalog")
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=3;add_child(arena);arena.auto_pause_enabled=false
	await get_tree().process_frame;arena.set_physics_process(false);arena.phase="combat"
	var origin=Vector2i(arena.grid_size/2,arena.grid_size/2)
	for cell in [origin+Vector2i(1,0),origin+Vector2i(2,0),origin+Vector2i(-1,0),origin+Vector2i(-2,0),origin+Vector2i(0,1),origin+Vector2i(0,-1),origin+Vector2i(0,-2)]:
		if arena.walls.has(cell):arena.damage_wall(cell,999)
	arena.place_wall(origin+Vector2i(1,0),"brick") if arena.has_method("place_wall") else null
	var enemy=arena.spawn_actor("soldier",origin+Vector2i(0,-2),false);enemy.set_physics_process(false);enemy.hp=50;enemy.max_hp=50
	var player=arena.player;player.position=arena.world_pos(origin+Vector2i(-1,0));var hp=player.hp
	var bomb=load("res://scripts/ability_effect.gd").new();bomb.arena=arena;bomb.kind="dynamite";bomb.power=6;bomb.utility=0;bomb.position=arena.world_pos(origin);arena.add_child(bomb)
	bomb._physics_process(1.0)
	check(is_instance_valid(bomb) and not bomb.is_queued_for_deletion(),"nothing before the fuse burns down")
	bomb._physics_process(.6)
	check(enemy.hp<50,"enemy on the line is hit")
	check(is_equal_approx(player.hp,hp),"the soldier is spared")
	print("DYNAMITE: %d failures" % failures);get_tree().quit(1 if failures else 0)
