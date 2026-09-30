extends Node
var checks=0
func check(value:bool,title:String):
	checks+=1
	if not value:push_error("FAIL: "+title);get_tree().quit(1)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=true;Game.reset_upgrades()
	check(Game.camp_level==0,"no starting medkits")
	check(is_equal_approx(Game.death_loss_fraction(),.5),"50 percent loss")
	Game.credits=100000;Game.built_workshops=["character","weapons","bonuses"]
	check(Game.upgrade_cap("health")==3,"base cap")
	for i in range(3):check(Game.purchase("health"),"health upgrade")
	check(not Game.purchase("health"),"health cap enforced")
	check(Game.upgrade_weapon("pistol"),"weapon tuning")
	check(is_equal_approx(Game.weapon_factor("pistol"),1.015),"small weapon bonus")
	var data=Game.progression.serialize();var restored=load("res://scripts/progression/base_progression.gd").new();restored.restore(data)
	check(restored.weapon_levels==Game.progression.weapon_levels,"progression serialization")
	for id in Game.TIERS.SCORES:
		if Game.TIERS.tier(id)>0:check(Game.TIERS.weight(id,0)==0,"early rare gate "+id)
	check(Game.TIERS.weight("heart",16)<Game.TIERS.weight("airstrike",16),"late rarity bias")
	Game.progression.event("extracted",30)
	var q=Game.progression.active(load("res://scripts/progression/quest_catalog.gd").STORY)
	check(Game.progression.claim(q),"quest claim");check(not Game.progression.claim(q),"no duplicate rewards")
	var main=load("res://scripts/main.gd").new();add_child(main)
	await get_tree().process_frame
	main.start_run();main.enter_room(0)
	var arena=main.run_arena;arena.auto_pause_enabled=false;arena.set_physics_process(false)
	arena.run.pending_recipes=[{"category":"weapon","id":"smg"}]
	main.show_map(1);main.show_hub();await get_tree().process_frame;await get_tree().process_frame
	check("smg" in Game.weapon_unlocks,"map extraction banks recipes")
	check(is_instance_valid(main.current) and main.run_arena==null,"return hub completes")
	main.current.show_command();await get_tree().process_frame
	if DisplayServer.get_name()!="headless":
		RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("res://art_demo/progression_v10/base.png")
	main.current.build_menu.tab=1;main.current.build_menu.refresh()
	await get_tree().process_frame
	if DisplayServer.get_name()!="headless":
		RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("res://art_demo/progression_v10/quests.png")
	main.current.close_station();main.current.open_workshop(true)
	await get_tree().process_frame
	if DisplayServer.get_name()!="headless":
		RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("res://art_demo/progression_v10/weapons.png")
	main.current.close_station();main.start_run();main.enter_room(0)
	arena=main.run_arena;arena.auto_pause_enabled=false;arena.set_physics_process(false);arena.phase="combat"
	for actor in arena.actors:actor.set_physics_process(false)
	var tank=arena.spawn_actor("tank",Vector2i(3,3),false);tank.set_physics_process(false);var armor=arena.vehicle.player_armor("tank","captured",Campaign.zone(arena.room_index));tank.dead=true;arena.combat.actor_destroyed(tank)
	var wreck=arena.wrecks[-1];check(wreck.boardable and not wreck.unstable,"capture first wreck");check(is_equal_approx(wreck.armor,armor*.5),"half armor")
	var hero=arena.player;hero.cell=Vector2i(3,4);hero.position=arena.world_pos(hero.cell)
	arena.vehicle.interact_vehicle();check(arena.player.kind=="tank","board salvage")
	arena.player.dead=true;arena.combat.actor_destroyed(arena.player);check(arena.wrecks[-1].unstable and not arena.wrecks[-1].boardable,"second destruction cannot board")
	arena.add_trench(Vector2i(5,5));hero=arena.player;hero.cell=Vector2i(5,6);hero.position=arena.world_pos(hero.cell)
	check(arena.board.interact_trench() and hero.occupying_trench,"enter trench")
	check(arena.board.interact_trench() and not hero.occupying_trench,"exit trench")
	# Commander delay uses countdown phase; health multiplier applies only at spawn.
	arena.room.wave=2;arena.room.room_boss_spawned=false;arena.room.room_cleared=false;arena.phase="combat"
	arena.flow.finish_wave();check(arena.phase=="countdown" and arena.room.commander_countdown,"commander pause")
	check(not arena.room.room_boss_spawned,"not spawned before countdown")
	arena._physics_process(3.1);check(arena.room.room_boss_spawned,"spawn after countdown")
	check(arena.room.commander.hp==arena.room.commander.max_hp,"commander full armor or health")
	# Ability recipes can render in the same chest without a legacy rarity property.
	arena.room.draft_pickup={"elite":true,"offers":[{"category":"ability","id":"airstrike"},{"category":"ability","id":"grenade"},{"category":"alloy","id":"alloy","amount":50,"tier":0}]}
	arena.hud.show_recipe_draft();arena.hud.close_modal()
	Game.credits=1000;arena.run.earned=100;arena.phase="combat";arena.flow.finish_run(false,"Test")
	check(Game.credits==950,"death loses 50 percent of expedition alloy")
	arena.flow.finish_run(false,"Test");check(Game.credits==950,"death penalty once")
	var original_path=Game.save_path;Game.save_path="/tmp/tank_progression_v10_test.json";Game.save_enabled=true
	Game.save_progress();var saved_xp=Game.progression.xp;Game.progression.xp=0;Game.load_progress()
	check(Game.progression.xp==saved_xp and Game.weapon_level("pistol")==1,"disk save reload")
	Game.save_enabled=false;Game.save_path=original_path
	main.show_hub();await get_tree().process_frame;await get_tree().process_frame
	main.queue_free();await get_tree().process_frame
	print("PROGRESSION V10 PASS: ",checks)
	get_tree().quit()
