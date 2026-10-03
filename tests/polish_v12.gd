extends Node3D
func _ready():call_deferred("run")
func shot(id):
	if DisplayServer.get_name()=="headless":return
	RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("/tmp/"+id+".png")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades()
	# Hub abilities are the class loadout: the recruit's Q comes with the class.
	assert(Game.class_loadout()==["grenade"])
	assert(Game.progression.level_cost()==500)
	for room in range(6):
		for seed_value in range(30):
			var map=BattleMapGenerator.generate(seed_value,room)
			assert(BattleMapGenerator.validate(map.rows))
	Game.music_controller=load("res://scripts/music_controller.gd").new();Game.add_child(Game.music_controller)
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub)
	await get_tree().create_timer(.8).timeout
	hub.use_training_ability();assert(hub.training_ability_cooldown>0)
	await get_tree().create_timer(.2).timeout;shot("v12_hub_skills");assert(hub.hub_skills.position.x>0 and hub.hub_skills.position.y>0)
	# Command centre opens on quests unless the tablet remembers another page (memory reset here).
	var memory=preload("res://scripts/ui/tablet_memory.gd");memory.loaded=true;memory.state={}
	hub.show_command();assert(hub.build_menu.tab=="quests")
	await get_tree().create_timer(.3).timeout;shot("v12_command")
	hub.close_station()
	Game.new_recipes=[{"category":"weapon","id":"smg"}];hub.present_unlock()
	await get_tree().create_timer(.3).timeout;shot("v12_unlock")
	hub.close_station();hub.queue_free();await get_tree().process_frame
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false)
	await get_tree().create_timer(.3).timeout;shot("v12_arena")
	arena.phase="combat"
	var cell=arena.player.cell+Vector2i.RIGHT
	arena.add_barrier(cell,10)
	var barrier=arena.room.walls[cell].node
	arena.damage_wall(cell,3)
	assert(arena.room.walls[cell].hp==7 and barrier.get_node_or_null("DamageCracks")==null)
	var bullet=load("res://scenes/projectile.tscn").instantiate();bullet.arena=arena;bullet.sniper_round=true;bullet.damage=1;bullet.position=arena.world_pos(arena.room.base_cell);arena.add_child(bullet)
	# A sniper round flies over cover and hits each target once: the base loses exactly 1 even if checked again.
	var hp=arena.room.base_hp;arena.bullet_hit(bullet);assert(arena.room.base_hp==hp-1 and bullet.hit_base);arena.bullet_hit(bullet);assert(arena.room.base_hp==hp-1);bullet.queue_free()
	Game.music_controller.change("battle",true)
	arena.hud.show_pause()
	await get_tree().create_timer(.3).timeout;shot("v12_pause")
	# Pause and the quest journal are the same field tablet: one at a time, each pauses the tree.
	assert(get_tree().paused);get_tree().get_first_node_in_group("field_tablet").close(false)
	await get_tree().process_frame;assert(not get_tree().paused)
	preload("res://scripts/progression/quest_journal.gd").open(get_tree().root)
	await get_tree().process_frame
	assert(get_tree().paused)
	get_tree().get_first_node_in_group("field_tablet").close()
	await get_tree().process_frame;assert(not get_tree().paused)
	var music=Game.music_controller
	music.change("battle",true);var before=music.current_track;music.change("battle",true);assert(music.current_track!=before)
	music.toggle_play();assert(music.paused);music.toggle_play();assert(not music.paused)
	music.repeat_mode=1;music.track_finished();assert(music.current_track!=before)
	arena.queue_free();await get_tree().process_frame
	var route=load("res://scripts/route_map.gd").new();add_child(route)
	await get_tree().create_timer(1.2).timeout
	route.travelling=false;route.show_pause()
	await get_tree().create_timer(.3).timeout;shot("v12_map_pause")
	# Map pause is the field tablet: the radio (music controls) is one of its pages.
	var tablet=get_tree().get_first_node_in_group("field_tablet");assert(tablet!=null and get_tree().paused)
	var view=tablet.get_child(0);view.tab="music";view.refresh();assert(view.content.get_child_count()>0)
	tablet.close(false);await get_tree().process_frame;assert(not get_tree().paused)
	print("V12 PASS: 180 maps, command, unlock, hub ability, journal pause, music controls")
	get_tree().quit()
