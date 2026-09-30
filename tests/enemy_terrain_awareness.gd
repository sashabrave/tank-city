extends Node
var errors=0
func check(ok:bool,message:String):
	if not ok:errors+=1;push_error(message)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.auto_pause_enabled=false;add_child(arena);arena.set_physics_process(false);arena.phase="combat"
	arena.walls.clear();arena.trenches.clear();arena.nets.clear();arena.generators.clear();arena.wrecks.clear();arena.terrain.patches.clear();arena.navigation.reset()
	# This scenario tests an explicit waypoint, with no open base firing lane.
	for side in [Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT]:arena.add_wall(arena.base_cell+side,8)
	var player=arena.player;player.set_physics_process(false);player.position=arena.world_pos(Vector2i(8,5));player.cell=Vector2i(8,5);player.invulnerable=0;player.hp=100;player.max_hp=100
	arena.abilities.shield_time=0;arena.abilities.cloak_time=0
	for kind in ["soldier","buggy","apc","tank"]:
		var enemy=arena.spawn_actor(kind,Vector2i(2,5),false);enemy.set_physics_process(false);enemy.enemy_weapon="rifle";enemy.assault_time=0
		for surface in ["vegetation","water","sand","ice"]:
			arena.terrain.patches.clear();arena.terrain.set_cell(Vector2i(5,5),surface);arena.navigation.reset()
			check(arena.enemy_aim(enemy)==Vector2i.RIGHT,"%s sees target through %s" % [kind,surface])
			var before=player.hp
			var bullet=arena.spawn_bullet(enemy,enemy.position,Vector2i.RIGHT,1.0,false);bullet.set_physics_process(false)
			for frame in range(65):
				if bullet.spent:break
				bullet._physics_process(1.0/60.0)
			check(player.hp<before,"%s shot hits through %s" % [kind,surface]);player.invulnerable=0
			if not bullet.spent:bullet.consume()
		enemy.dead=true;enemy.queue_free()
	# A ground enemy chooses a faster dry detour instead of six sand cells.
	arena.terrain.patches.clear()
	for x in range(2,8):arena.terrain.set_cell(Vector2i(x,5),"sand")
	arena.navigation.reset();player.position=arena.world_pos(Vector2i(10,10));player.cell=Vector2i(10,10)
	for kind in ["soldier","tank"]:
		var enemy=arena.spawn_actor(kind,Vector2i(1,5),false);enemy.set_physics_process(false);enemy.route_points=[Vector2i(8,5)];enemy.assault_time=0
		var detoured=false
		for frame in range(220):
			var direction=arena.path_direction(enemy)
			if direction!=Vector2i.ZERO:
				var stride=.25 if enemy.uses_quarter_steps() else 1.0
				enemy.position+=Vector3(direction.x,0,direction.y)*stride;enemy.cell=arena.grid_pos(enemy.position)
				detoured=detoured or enemy.cell.y!=5
			if enemy.cell==Vector2i(8,5):break
			await get_tree().physics_frame
		check(detoured and enemy.cell==Vector2i(8,5),kind+" uses dry detour")
		var ice_cell=Vector2i(5,8);var ice_pos=arena.world_pos(ice_cell)
		arena.terrain.set_cell(ice_cell,"ice");arena.navigation.reset()
		var plain=arena.terrain.navigation_cost(arena.world_pos(Vector2i(4,8)),enemy,Vector2i.RIGHT)
		check(arena.terrain.navigation_cost(ice_pos,enemy,Vector2i.RIGHT)>plain,"AI accounts for ice control loss")
		for surface in ["vegetation","water"]:
			arena.terrain.set_cell(ice_cell,surface);arena.navigation.reset()
			check(not arena.can_stand(ice_pos,enemy) and not arena.can_enter(ice_cell,enemy),kind+" cannot enter "+surface)
		enemy.dead=true;enemy.queue_free()
	arena.queue_free();await get_tree().process_frame
	print("ENEMY TERRAIN AWARENESS failures ",errors);get_tree().quit(1 if errors else 0)
