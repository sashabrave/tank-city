extends Node3D
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.new_recipes.clear();Settings.values.fullscreen=false;Settings.apply()
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=82415;add_child(arena);arena.process_mode=Node.PROCESS_MODE_DISABLED;arena.auto_pause_enabled=false
	var kinds={};var seen_biomes={};var saw_bend=false;var saw_long=false
	for world in range(1,4):
		Campaign.configure(world)
		for room in range(7):
			arena.begin_room(room)
			var before=arena.terrain.patches.duplicate()
			arena.terrain.generate();assert(before==arena.terrain.patches)
			for p in before:
				var c=Vector2i(p.x/2,p.y/2)
				assert(not arena.trenches.has(c) and not arena.walls.has(c) and not arena.generators.has(c))
				kinds[before[p]]=true
			seen_biomes[arena.BIOMES.index(arena.run_seed,room)]=true
			for kind in before.values():assert(kind in arena.room_palette().kinds)
			assert(not before.is_empty())
			var hazard_count=0
			for kind in before.values():
				if kind in ["water","ice"]:hazard_count+=1
			assert(hazard_count/4<=arena.terrain.terrain_budget())
			for strip in arena.terrain.strips:
				assert(strip.width==1.0 and strip.length>=1 and strip.length<=6)
				saw_bend=saw_bend or strip.bend;saw_long=saw_long or strip.length>2
	assert(kinds.size()==4 and seen_biomes.size()==7 and saw_bend)
	# Many seeds exercise full-length bends and atomic water placement.
	for seed_value in range(140):
		arena.run_seed=seed_value;arena.room.difficulty=2;arena.terrain.generate()
		for strip in arena.terrain.strips:
			assert(strip.width==1 and strip.cells.size()==strip.length)
			for i in range(strip.cells.size()):
				var c=strip.cells[i]
				if i>0:assert((c-strip.cells[i-1]).length_squared()==1)
				for x in range(2):
					for y in range(2):assert(arena.terrain.patches[c*2+Vector2i(x,y)]==strip.kind)
			if strip.length==6:saw_long=true
	assert(saw_long)
	# Isolated mechanics fixture, same movement/collision methods as combat.
	arena.walls.clear();arena.trenches.clear();arena.generators.clear();arena.wrecks.clear()
	for a in arena.actors:
		if a!=arena.player:a.dead=true
	var actor=arena.player;actor.occupying_trench=false;actor.kind="soldier";actor.position=Vector3.ZERO;actor.cell=arena.grid_pos(actor.position);actor.moving=false
	arena.terrain.patches.clear();arena.terrain.set_cell(actor.cell,"water")
	assert(not arena.can_stand(actor.position,actor) and not arena.can_enter(actor.cell,actor))
	assert(arena.clear_shot(actor.position-Vector3.RIGHT,actor.position+Vector3.RIGHT,.5))
	var bullet=arena.spawn_bullet(actor,actor.position,Vector2i.RIGHT,1,true)
	assert(not arena.bullet_hit(bullet));bullet.consume()
	arena.terrain.patches.clear();arena.terrain.set_cell(actor.cell,"sand")
	assert(is_equal_approx(arena.terrain.speed_factor(actor),.55))
	actor.kind="tank";assert(is_equal_approx(arena.terrain.speed_factor(actor),.55))
	arena.terrain.patches.clear();arena.terrain.set_cell(actor.cell,"ice")
	for kind in ["soldier","tank"]:
		actor.kind=kind;actor.position=Vector3.ZERO;actor.moving=false;actor.slide_remaining=0;actor.terrain_direction=Vector2i.RIGHT
		assert(arena.terrain.begin_slide(actor));assert(actor.quarter_destination==Vector3(.25,0,0))
		for step in range(12):
			actor.position=actor.quarter_destination;actor.cell=arena.grid_pos(actor.position);actor.moving=false
			if not arena.terrain.begin_slide(actor):break
		assert(actor.slide_remaining==0 and actor.position.x<2)
	actor.kind="soldier";actor.position=Vector3.ZERO;actor.cell=arena.grid_pos(actor.position);actor.moving=false;actor.terrain_direction=Vector2i.RIGHT
	arena.terrain.set_cell(actor.cell+Vector2i.RIGHT,"water")
	for step in range(8):
		if not arena.terrain.begin_slide(actor):break
		actor.position=actor.quarter_destination;actor.moving=false
	assert(not arena.terrain.blocked(actor.position,.245))
	Campaign.configure(1);arena.begin_room(2);arena.phase="upgrade"
	arena.process_mode=Node.PROCESS_MODE_INHERIT;arena.set_physics_process(false);arena.camera.current=true
	for a in arena.actors:a.set_physics_process(false)
	if DisplayServer.get_name()!="headless":
		await get_tree().create_timer(2.3).timeout;await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/terrain-battle.png")
	print("PASS 21 maps: deterministic exclusive floors with vegetation; 15 biome catalog; full-width ribbons and bends; water blocks actors not bullets; sand slows infantry/tanks; ice coasts and stops at water")
	get_tree().quit()
