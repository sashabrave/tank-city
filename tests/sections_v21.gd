extends Node3D
func _ready():call_deferred("run_test")
func run_test():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.apply_profile(Game.fresh_profile.duplicate(true));Campaign.configure(1)
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.set_physics_process(false);arena.auto_pause_enabled=false;arena.phase="combat"
	for wall in arena.walls.values():wall.node.queue_free()
	arena.walls.clear()
	for actor in arena.actors:actor.set_physics_process(false)
	var cell=Vector2i(6,6);var origin=arena.world_pos(cell);arena.add_wall(cell,4)
	var wall=arena.walls[cell];assert(wall.sections.size()==16)
	arena.board.damage_wall(cell,1,origin+Vector3(0,0,1),Vector3.FORWARD,.5)
	assert(wall.sections.filter(func(hp):return hp<=0).size()==2)
	assert(wall.sections[13]==0 and wall.sections[14]==0)
	for i in range(3):arena.board.damage_wall(cell,1,origin+Vector3(0,0,1),Vector3.FORWARD,.5)
	assert(wall.sections.filter(func(hp):return hp<=0).size()==8)
	assert(arena.clear_shot(origin+Vector3(0,0,2),origin+Vector3(0,0,-2),.5))
	assert(not arena.clear_shot(origin+Vector3(0,0,2),origin+Vector3(0,0,-2),1.0))
	var player=arena.player;player.position=origin+Vector3(0,0,1);player.cell=arena.grid_pos(player.position);player.facing=Vector2i.UP
	assert(arena.can_stand(origin,player))
	for i in range(4):
		player.try_move(Vector2i.UP);assert(player.moving)
		player.position=player.quarter_destination;player.cell=player.destination;player.moving=false
	assert(player.position.is_equal_approx(origin))
	player.kind="tank";assert(not arena.can_stand(origin,player));player.kind="soldier"
	# Enemy can aim and shoot through the half-cell slit, without touching its edges.
	player.position=origin+Vector3(0,0,2)
	var enemy=arena.spawn_actor("soldier",Vector2i(6,4),false);enemy.set_physics_process(false)
	assert(arena.enemy_aim(enemy)==Vector2i.DOWN)
	var shot=arena.spawn_bullet(enemy,enemy.position,Vector2i.DOWN,1,false);shot.position=origin
	assert(not arena.bullet_hit(shot));shot.consume()
	# Infantry navigation and locomotion use the same open half-cell passage.
	player.position=arena.world_pos(Vector2i(1,1))
	enemy.position=origin+Vector3(0,0,-1);enemy.cell=arena.grid_pos(enemy.position)
	enemy.route_points=[cell+Vector2i.DOWN];enemy.movement_pause=0
	for step in range(8):
		var direction=Vector2i.ZERO
		for attempt in range(120):
			direction=arena.path_direction(enemy)
			if direction!=Vector2i.ZERO:break
			await get_tree().physics_frame
		assert(direction==Vector2i.DOWN,"infantry should route through the slit")
		enemy.try_move(direction);assert(enemy.moving)
		enemy.position=enemy.quarter_destination;enemy.cell=enemy.destination;enemy.moving=false
	assert(enemy.position.is_equal_approx(origin+Vector3(0,0,1)))
	# A single quarter-wide opening cannot fit the half-cell infantry body.
	var narrow=wall.sections.duplicate()
	for row in range(4):wall.sections[row*4+1]=1.0
	assert(not arena.can_stand(origin+Vector3(.125,0,0),enemy))
	wall.sections=narrow
	# From the left, vehicle fire removes exactly one four-section column.
	var other=Vector2i(9,6);arena.add_wall(other,4);var center=arena.world_pos(other)
	arena.board.damage_wall(other,1,center-Vector3.RIGHT,Vector3.RIGHT,1)
	assert(arena.walls[other].sections.filter(func(hp):return hp<=0).size()==4)
	for row in range(4):assert(arena.walls[other].sections[row*4]==0)
	assert(arena.walls[other].node.find_child("DamageCracks",true,false)==null)
	# A wide shot straddling cells contacts both blocks.
	arena.add_wall(other+Vector2i.RIGHT,4)
	assert(arena.wall_contacts(center+Vector3(.5,0,.5),Vector3.FORWARD,1).size()==2)
	# Firing left from inside a slit must never damage the right-hand sections.
	var before=wall.sections.duplicate()
	arena.board.damage_wall(cell,10,origin+Vector3(-.3,0,0),Vector3.LEFT,.5)
	for row in range(4):assert(wall.sections[row*4+3]==before[row*4+3])
	assert(wall.sections[4]==0 and wall.sections[8]==0)
	for side in range(4):
		var halfcell=Vector2i(2+side,9);arena.add_wall(halfcell,-1 if side%2 else 4);arena.board.shape_wall(halfcell,side)
		assert(arena.walls[halfcell].sections.filter(func(hp):return hp>0).size()==8)
	if DisplayServer.get_name()!="headless":
		Settings.values.fullscreen=false;Settings.apply();arena.show();arena.camera.current=true;arena.hud.hide()
		arena.set_process(false);arena.hud.set_process(false)
		arena.camera.position=origin+Vector3(4,6,7);arena.camera.look_at(origin);arena.camera.size=6
		await get_tree().create_timer(.3).timeout;arena.hud.hide();RenderingServer.force_draw()
		get_viewport().get_texture().get_image().save_png("/tmp/tank-v21-bricks.png")
	arena.queue_free();await get_tree().process_frame
	print("PASS sections: directional 4x4 damage, half-width slit, quarter movement, tank blocked, enemy aim/projectile through hole, boundary hit")
	get_tree().quit()
