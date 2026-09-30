extends Node
var errors=0
func check(ok:bool,message:String):
	if not ok:errors+=1;push_error(message)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Engine.physics_ticks_per_second=240
	var arena=load("res://scenes/arena.tscn").instantiate();arena.auto_pause_enabled=false;arena.run_seed=715;add_child(arena);arena.set_physics_process(false)
	# High allied muzzle clears the neighbouring base cover even at maximum range.
	var mortar=arena.spawn_actor("grenadier",arena.base_cell+Vector2i.LEFT,false,true);mortar.set_physics_process(false)
	var origin=mortar.position
	# Only the base cover next to the muzzle stays: tall layout pieces further along the arcs are cleared.
	for cell in arena.room.walls.keys():
		if (cell-mortar.cell).length()>1.5 and (cell.x==mortar.cell.x or cell.y==mortar.cell.y):arena.room.walls[cell].node.queue_free();arena.room.walls.erase(cell)
	for offset in [Vector3(0,0,-6),Vector3(5,0,0),Vector3(0,0,-2)]:  # 5 across: the first field is 11 wide
		arena.throw_grenade(mortar,origin+offset)
		var grenade=arena.grenades.back();grenade.set_physics_process(false)
		for step in range(96):grenade._physics_process(1.0/60.0)
		check(not grenade.motion.collided,"Turret arc clears adjacent cover")
		check(arena.flat_distance(grenade.position,origin+offset)<.15,"Turret reaches aim point")
		grenade.consume()
	# Independent cooldown with no arrival before 30 seconds.
	arena.room.room_cleared=false;arena.room.boss_defeated=false;arena.room.combat_elapsed=0;arena.room.wave=0
	arena.surprises.start_wave();check(arena.room.surprise_timer>=15 and arena.room.surprise_timer<=30,"First surprise arrival delayed")
	arena.phase="combat";arena.room.surprise_timer=0;arena.room.combat_elapsed=14.99
	var count=arena.actors.size();arena.surprises.tick(.01);check(arena.actors.size()==count,"No early drone with expired timer")
	arena.room.combat_elapsed=15.01;arena.surprises.tick(.01);check(arena.actors.size()==count+1,"Drone arrives after time gate")
	var family_seen={};var late=0;var early=0
	for world in range(1,4):
		Campaign.configure(world)
		for room in [0,5]:
			arena.begin_room(room);arena.player.set_physics_process(false)
			check(arena.room.combat_elapsed==0,"Battle clock resets for each room")
			var original=arena.terrain.patches.duplicate();arena.terrain.generate();check(original==arena.terrain.patches,"Deterministic terrain")
			if room==0:early+=original.size()
			else:late+=original.size()
			for cell in arena.terrain.patches:
				var full=Vector2i(cell.x/2,cell.y/2)
				check(not arena.walls.has(full) and not arena.trenches.has(full),"Terrain excludes cover/trenches")
			# Isolate the waypoint test from higher-priority base breach tactics.
			for side in [Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT]:
				var cover=arena.base_cell+side
				if arena.walls.has(cover):arena.walls[cover].node.queue_free();arena.walls.erase(cover)
				arena.add_wall(cover,8)
			# The exact quarter-grid planner must reach a distant waypoint in worlds 2 and 3.
			var soldier=arena.spawn_actor("soldier",Vector2i(int(arena.grid_size/2),0),false);soldier.set_physics_process(false);soldier.route_points=[Vector2i(0,arena.grid_size-4)]
			var moved=0
			for frame in range(360):
				var direction=arena.path_direction(soldier)
				if direction!=Vector2i.ZERO:
					soldier.position+=Vector3(direction.x,0,direction.y)*.25;soldier.cell=arena.grid_pos(soldier.position);moved+=1
				if soldier.cell==Vector2i(0,arena.grid_size-4):break
				await get_tree().physics_frame
			check(soldier.cell==Vector2i(0,arena.grid_size-4),"Distant route reached world %d room %d (%d moves)" % [world,room,moved])
	check(late>early,"Late rooms contain more difficult terrain")
	# All biome families provide VARIANTS importable, rooted, one-cell meshes.
	for biome in arena.BIOMES.ENTRIES:family_seen[biome.vegetation]=true
	check(family_seen.size()==5 and arena.BIOMES.ENTRIES.size()==15,"Five forest families / fifteen biomes")
	var vegetation=load("res://scripts/vegetation_visual.gd")
	var appearances={}
	for x in range(30):
		var a=vegetation.appearance(810,2,Vector2i(x,3));check(a==vegetation.appearance(810,2,Vector2i(x,3)),"Deterministic appearance")
		appearances[a.tile]=true
	check(appearances.size()==vegetation.VARIANTS,"All variants appear")
	for family in family_seen:
		for variant in range(vegetation.VARIANTS):
			var scene=load(vegetation.model_path(family,variant)).instantiate()
			var meshes=scene.find_children("*","MeshInstance3D",true,false);check(meshes.size()==1,"One vegetation mesh per tile")
			if not meshes.is_empty():
				var mesh=meshes[0].mesh;var bounds=mesh.get_aabb()
				check(bounds.size.x<=.95 and bounds.size.z<=.95 and bounds.size.y>1,"Tall trees fit tile footprint")
				var anchored=false;var flexible=false;var phases={}
				for surface in range(mesh.get_surface_count()):
					var colors=mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
					check(colors!=null and colors.size()>0,"Imported per-tree wind data")
					for color in colors:
						anchored=anchored or color.r<.001;flexible=flexible or color.r>.1;phases[snappedf(color.g,.01)]=true
				check(anchored and flexible and phases.size()>3,"Anchored roots and independent tree motion")
			scene.free()
	arena.walls.clear();arena.trenches.clear();arena.generators.clear();arena.wrecks.clear();arena.terrain.patches.clear()
	for actor in arena.actors:
		actor.set_physics_process(false)
		if actor!=arena.player:actor.dead=true
	var player=arena.player;player.kind="soldier";player.position=Vector3.ZERO;player.cell=arena.grid_pos(player.position);player.occupying_trench=false
	arena.terrain.set_cell(player.cell,"vegetation");arena.navigation.reset()
	check(not arena.can_enter(player.cell,player) and not arena.can_stand(player.position,player),"Vegetation blocks movement")
	check(arena.clear_shot(player.position-Vector3.RIGHT,player.position+Vector3.RIGHT,.5),"Vegetation permits line of fire")
	var bullet=arena.spawn_bullet(player,player.position,Vector2i.RIGHT,1,true)
	check(not arena.bullet_hit(bullet),"Vegetation permits bullets");bullet.consume()
	for kind in ["buggy","apc","tank"]:
		check(GarageCatalog.stats(kind).damage>={"buggy":.35,"apc":1.25,"tank":3.75}[kind],"Vehicle damage increased")
	arena.queue_free();await get_tree().process_frame
	print("COMBAT TERRAIN REVISION failures ",errors);get_tree().quit(1 if errors else 0)
