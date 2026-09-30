extends Node3D
func _ready():call_deferred("run")
func check(value:bool,label:String):
	if not value:push_error(label);get_tree().quit(1)
	assert(value,label)
func shot(id):
	if DisplayServer.get_name()=="headless":return
	RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("/tmp/v14_"+id+".png")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Game.reset_upgrades()
	for world in range(1,4):
		Campaign.configure(world)
		for seed_value in range(30):
			var seen={};var ranks={}
			for stage in range(Campaign.SIZES.size()-1):
				var previous=0
				for wave in range(3):
					var roster=WaveDirector.build(seed_value,stage,wave);check(roster.size()>previous,"increasing wave count");previous=roster.size()
					for entry in roster:seen[entry.kind]=true;ranks[entry.rank]=true;check(entry.kind not in ["drone","flyer"],"drones separate")
			for kind in WaveDirector.PEOPLE+WaveDirector.MACHINES:check(seen.has(kind),"every type in every world")
			check(ranks.has(3)==(world==3),"third rank in world three")
	Game.progression.counters["barrel_kills"]=10;check(Game.select_class("gunner") and Game.hero_loadout()==["gas"],"demolisher opens by goal with gas")
	Game.progression.boss_classes=["recruit"];check(Game.select_class("engineer") and Game.hero_loadout()==["ally_drone"],"engineer after the boss with a drone")
	check(Game.purchase("pressure") and Game.pressure_level==1,"shared pressure in printer")
	check(Game.purchase("health"),"shared HP without workshop")
	Game.built_workshops.append("headquarters");check(Game.equip_hq("hq_patch") and Game.hq_loadout().size()==1,"HQ active replaces passive")
	Game.credits=10000;Game.progression.level=4;check(Game.buy_hq_slot() and Game.hq_slots==2,"expensive second slot")
	check(Game.equip_hq("hq_medbay",1) and Game.hq_loadout().size()==2,"HQ two combined slots")
	var path=Game.save_path;Game.save_path="/tmp/v14_profile.json";Game.save_enabled=true;Game.save_progress();Game.load_progress();Game.save_enabled=false;Game.save_path=path
	check(Game.hq_slots==2 and Game.pressure_level==1,"slot and stats survive save")
	Campaign.configure(3)
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false);arena.phase="combat"
	var enemy=arena.spawn_actor("tank",Vector2i(2,2),false,false,3);enemy.set_physics_process(false);check(enemy.rank==3 and enemy.model.paint_rank==3,"rank three visual")
	arena.soldier_hp-=1;arena.player.hp=arena.soldier_hp;check(arena.abilities.cast_slot(0),"Mechanic repairs hero")
	await get_tree().create_timer(.6).timeout;shot("battle")
	arena.earned=100;Game.credits=1000;arena.pending_recipes=[{"category":"weapon","id":"smg"}];arena.flow.finish_run(false,"Солдат погиб")
	await get_tree().create_timer(.25).timeout;shot("fall")
	await get_tree().create_timer(.8).timeout;check(is_instance_valid(arena.hud.modal),"death result after animation");shot("death")
	check(arena.get_meta("lost_recipes").size()==1 and arena.run.lost_alloy==50,"loss summary")
	arena.queue_free();await get_tree().process_frame
	var hub=load("res://scenes/hub.tscn").instantiate();Game.return_through_gate=true;add_child(hub);await get_tree().create_timer(.6).timeout;check(hub.cell==Vector2i(5,0),"voluntary return through gate");shot("return")
	hub.show_classes();await get_tree().create_timer(.15).timeout;shot("printer");hub.show_class_catalog();await get_tree().create_timer(.15).timeout;shot("classes")
	hub.close_station();hub.show_command();hub.build_menu.tab="guide";hub.build_menu.refresh();await get_tree().create_timer(.15).timeout;shot("guide");hub.close_station();hub.queue_free();await get_tree().process_frame
	arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.phase="combat";arena.set_physics_process(false);arena.base_hp=0;arena.flow.finish_run(false,"Штаб уничтожен");await get_tree().create_timer(.35).timeout;shot("base_death");await get_tree().create_timer(.7).timeout
	print("V14 PASS: all enemies/world, wave growth, rank3, classes, slots, save, printer, death, gate intro");get_tree().quit()
