extends Node
func _ready():call_deferred("run_test")
func freeze(arena):
	arena.set_physics_process(false);arena.auto_pause_enabled=false
	for actor in arena.actors:actor.set_physics_process(false)
func run_test():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	Game.apply_profile(Game.fresh_profile.duplicate(true));Game.save_path="/tmp/tank-checkpoint-%d/profile.json" % Time.get_ticks_usec();Game.profiles.selected=true;Game.save_blocked=false;Game.save_enabled=true
	var main=load("res://scripts/main.gd").new();add_child(main);await get_tree().process_frame;await get_tree().process_frame
	main.start_run();assert(Game.run_checkpoint.mode=="map")
	# Stage 1 may hold a service or challenge point; follow a lane that is an ordinary battle on both stages.
	var lane=RoutePlan.build(Game.visual_run_seed)[1].filter(func(n):return n.type=="battle")[0].lane
	main.enter_room(0,"0:%d" % lane);var arena=main.run_arena;freeze(arena)
	assert(Game.run_checkpoint.mode=="room")
	arena.run.damage_bonus=2.5;arena.run.behavior_cards=["opening_shot"]
	arena.run.pending_recipes=[{"category":"weapon","id":"smg"}]
	arena.abilities.select("grenade");arena.abilities.slots=["grenade"];arena.abilities.level.power=2.0
	arena.headquarters.levels["hq_medbay"]=3.0
	Game.credits=100;Game.checkpoint_run(arena,0,"room",main.route_choices)
	var expected_seed=arena.run_seed
	Game.earn(70);arena.run.damage_bonus=99;arena.run.pending_recipes.clear();arena.run.behavior_cards.append("last_stand")
	arena.run.soldier_hp=.2;arena.phase="combat";arena.start_wave(2);Game.save_progress()
	var disk=Game.ProfileStore.load_file(Game.save_path,Game.ProfileSchema.validate)
	assert(disk.ok);assert(disk.data.credits==100 and Game.credits==170)
	assert(disk.data.run_checkpoint.run.damage_bonus==2.5)
	main.restart_room();arena=main.run_arena;freeze(arena)
	assert(Game.credits==100 and arena.run.damage_bonus==2.5 and arena.room.wave==0)
	assert(arena.run.behavior_cards==["opening_shot"] and arena.run.pending_recipes.size()==1)
	assert(arena.abilities.selected=="grenade" and arena.abilities.level.power==2)
	assert(arena.headquarters.levels.hq_medbay==3 and arena.run_seed==expected_seed)
	# A completed room's rewards are committed at the next map checkpoint.
	Game.earn(25);main.show_map(1);assert(Game.run_checkpoint.mode=="map")
	main.enter_room(1,"1:%d" % lane);arena=main.run_arena;freeze(arena)
	assert(Game.run_checkpoint.index==1 and arena.room_index==1)
	Game.earn(50);Game.save_progress()
	disk=Game.ProfileStore.load_file(Game.save_path,Game.ProfileSchema.validate);assert(disk.ok and disk.data.credits==125)
	# Simulate process loss: destroy nodes without going through hub/extraction.
	main.clear_current();main.run_arena.queue_free();main.run_arena=null;main.current=null;main.queue_free();await get_tree().process_frame
	Game.apply_profile(disk.data)
	main=load("res://scripts/main.gd").new();add_child(main);await get_tree().process_frame;await get_tree().process_frame
	assert(not Game.run_checkpoint.is_empty() and Game.credits==125)
	main.request_run();assert(main.current.build_menu.has_signal("continued"));main.current.close_station()
	# A room checkpoint resumes on the route map in front of that room; the room is built on entry.
	main.resume_run();arena=main.run_arena
	assert(arena.defer_room and main.current.get_script().resource_path.ends_with("route_map.gd") and main.current.available==1)
	main.enter_room(1,"1:%d" % lane);arena=main.run_arena;freeze(arena)
	assert(arena.room_index==1 and arena.room.wave==0 and arena.run.damage_bonus==2.5)
	assert(arena.run.route_choices.has(1) and arena.run.behavior_cards==["opening_shot"])
	assert(arena.abilities.level.power==2 and arena.run.pending_recipes.size()==1)
	# Map checkpoints preserve service visits, a captured vehicle and its entry armor.
	var cp=Game.run_checkpoint.duplicate(true);cp.mode="map";cp.index=2
	cp.run.visited_services={2:"vehicle"};cp.hero={"kind":"tank","hp":4.5,"salvaged":true,"origin":"captured","zone":2}
	cp=JSON.parse_string(JSON.stringify(cp))
	assert(preload("res://scripts/profile/run_checkpoint.gd").valid(cp))
	var restored=load("res://scenes/arena.tscn").instantiate();restored.resume_checkpoint=cp;add_child(restored);freeze(restored)
	assert(restored.player.kind=="tank" and restored.player.vehicle_origin=="captured" and restored.player.hp==4.5)
	assert(restored.run.visited_services.has(2))
	restored.queue_free()
	var invalid=cp.duplicate(true);invalid.abilities.levels.grenade.power=[]
	assert(not preload("res://scripts/profile/run_checkpoint.gd").valid(invalid))
	# Restart control is above hub and restores the same checkpoint.
	arena.phase="paused";preload("res://scripts/ui/pause_tablet.gd").open(arena,arena.pause_battle,arena.leave);await get_tree().process_frame
	var tablet=get_tree().get_first_node_in_group("field_tablet");var view=tablet.get_child(0)
	assert(view.can_restart)
	var buttons=view.find_children("*","Button",true,false);var restart_button;var hub_button
	for button in buttons:
		if button.tooltip_text=="Заново":restart_button=button
		if button.tooltip_text=="В хаб":hub_button=button
	assert(restart_button.position.y<hub_button.position.y)
	restart_button.pressed.emit();arena=main.run_arena;freeze(arena);assert(arena.room.wave==0 and not get_tree().paused);arena.phase="combat"
	arena.flow.finish_run(false,"test");assert(Game.run_checkpoint.is_empty())
	Game.save_enabled=false;main.clear_current();main.run_arena.queue_free();main.run_arena=null;main.queue_free()
	await get_tree().process_frame
	print("PASS checkpoints: JSON save/load, room rollback, no duplicate currency, map advance, abilities/HQ/cards/recipes, resume prompt, restart button, death clears checkpoint")
	get_tree().quit()
