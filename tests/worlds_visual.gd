extends Node3D
func _ready():call_deferred("run")
func shot(id):
	await get_tree().create_timer(.25).timeout
	RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("/tmp/worlds_"+id+".png")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Game.reset_upgrades();Campaign.configure(1)
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub);await get_tree().create_timer(.6).timeout
	var picker=load("res://scripts/ui/world_select.gd").new();hub.root.add_child(picker);await shot("select");picker.queue_free();await get_tree().process_frame
	hub.show_command();await shot("quests");hub.build_menu.tab="orders";hub.build_menu.refresh();await shot("orders");hub.close_station()
	Game.built_workshops.append("character");hub.open_workshop(false);await shot("character");hub.close_station();Game.research_unlocks.append("headquarters");Game.built_workshops.append("headquarters");hub.show_hq_workshop();await shot("hq");hub.build_menu.category="active";hub.build_menu.refresh();await shot("hq_active");hub.close_station();Game.built_workshops.append("garage");hub.show_garage();await shot("garage");hub.close_station();hub.queue_free();await get_tree().process_frame
	var map=load("res://scripts/route_map.gd").new();map.wave_seed=128;map.available=2;map.needs_service=true;add_child(map);await get_tree().create_timer(1.5).timeout;await shot("map")
	map.show_pause();await shot("pause");get_tree().get_first_node_in_group("field_tablet").close();await get_tree().process_frame;map.queue_free();await get_tree().process_frame
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.phase="combat";arena.set_physics_process(false);await shot("battle")
	arena.pause_battle();await shot("battle_pause");get_tree().get_first_node_in_group("field_tablet").close();await get_tree().process_frame
	print("WORLD VISUAL PASS");get_tree().quit()
