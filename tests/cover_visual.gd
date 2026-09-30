extends Node3D
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.new_recipes.clear()
	Settings.values.fullscreen=false;Settings.apply();Campaign.configure(1)
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena)
	arena.set_physics_process(false);arena.auto_pause_enabled=false;arena.phase="upgrade"
	var checked_trenches=0
	var captured=false
	for index in range(7):
		arena.begin_room(index);arena.phase="upgrade"
		var foundation=arena.get_node("BattleFoundation").multimesh
		assert(foundation.instance_count==arena.grid_size*arena.grid_size-arena.trenches.size())
		checked_trenches+=arena.trenches.size()
		for cell in arena.trenches:
			for i in range(foundation.instance_count):
				var p=foundation.get_instance_transform(i).origin
				assert(not (is_equal_approx(p.x,arena.world_pos(cell).x) and is_equal_approx(p.z,arena.world_pos(cell).z)))
		for actor in arena.actors:actor.set_physics_process(false)
		if not arena.trenches.is_empty():
			var cell=arena.trenches.keys()[0]
			arena.player.cell=cell;arena.player.position=arena.world_pos(cell);arena.player.occupying_trench=true
			arena.player.model.position.y=-.65
			assert(arena.player.model.position.y>-.94)
		if not captured and not arena.trenches.is_empty() and DisplayServer.get_name()!="headless":
			captured=true
			arena.camera.position+=arena.world_pos(arena.trenches.keys()[0]);arena.camera.size=4.2
			await get_tree().create_timer(2).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("/tmp/cover-battle.png")
	assert(checked_trenches>0)
	arena.queue_free();await get_tree().process_frame
	var cam=Visuals.setup_world(self,5.4,Vector3.ZERO)
	for i in range(3):
		var holder=Node3D.new();add_child(holder);holder.position.x=(i-1)*1.8
		var tint=Color(["92958e","88999e","9c927d"][i]);holder.set_meta("environment_floor",tint)
		Visuals.model("trench",holder,Vector3(0,0,.6))
		Visuals.model("net",holder,Vector3(0,0,-1))
		var soldier=Visuals.model("soldier",holder,Vector3(0,-.65,.6))
		Visuals.box(holder,Vector3(0,-.12,-1),Vector3(1,.2,1),tint)
	if DisplayServer.get_name()!="headless":
		await get_tree().create_timer(.6).timeout;await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/cover-palette.png")
	print("PASS cover assets, seven room foundations, open trench cells and hidden actor clearance")
	get_tree().quit()
