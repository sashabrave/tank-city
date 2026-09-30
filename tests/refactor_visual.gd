extends Node
func capture(name:String):
	await get_tree().process_frame
	await get_tree().process_frame
	RenderingServer.force_draw()
	get_viewport().get_texture().get_image().save_png("res://screenshots/refactor-"+name+".png")
func _ready():call_deferred("run_test")
func run_test():
	Game.save_enabled=false;Game.sound_enabled=false;Game.reset_upgrades()
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false);arena.player.set_physics_process(false)
	arena.phase="upgrade";arena.hud.show_upgrades();await capture("upgrades")
	arena.phase="combat";arena.drop_recipe(arena.player.cell,{});arena.open_recipe_draft(arena.pickups.back());await capture("chest")
	arena.hide();arena.hud.hide()
	var service=load("res://scripts/service_room.gd").new();service.arena=arena;service.index=4;service.branch="vehicle";add_child(service);service.avatar.position=Vector3.ZERO;service.interact();await capture("service")
	service.queue_free();await get_tree().process_frame;arena.show();arena.hud.show();arena.camera.current=true;arena.hud.close_modal();arena.begin_room(7);arena.set_physics_process(false);arena.player.set_physics_process(false);await capture("battle")
	print("REFACTOR VISUAL: four screenshots captured")
	get_tree().quit()
