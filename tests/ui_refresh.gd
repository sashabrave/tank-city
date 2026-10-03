extends Node
var checks=0
var failures=0
func check(ok,message):
	checks+=1
	if not ok:failures+=1;push_error(message)
func key(code:int,pressed:bool,echo=false):
	var event=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=pressed;event.echo=echo;Input.parse_input_event(event)
## Panel slides take a few frames; a loaded machine stretches them.
func until(condition:Callable):
	for i in range(30):
		await get_tree().create_timer(.1).timeout
		if condition.call():return
## Map travel lasts as long as the road (up to 1.6 s): wait for arrival instead of a fixed delay.
func arrive(route):
	for i in range(40):
		await get_tree().create_timer(.1).timeout
		if not route.travelling:return
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades()
	# Abilities come from the class: heavy has the shield first and a bought second slot (comrade).
	Game.selected_class="heavy";Game.class_unlocks=["recruit","heavy"];Game.class_levels={"heavy":7}
	var benchmark=preload("res://scripts/ui/weapon_benchmarks.gd").weapon("rifle")
	check(is_equal_approx(benchmark.damage,9.55865625) and is_equal_approx(benchmark.rate,1.0/(.28*pow(.7,4))),"rifle benchmark follows real damage and rate formulas")
	check(UiKit.number(10)=="10" and UiKit.number(1.25)=="1.25","number formatting")
	check(NumberDisplay.clean("12.00 / 2,0 / 0.75")=="12 / 2 / 0.75","text numbers retain fractional precision")
	Game.health_level=2;Game.bonus_levels={"heart":2};Game.class_levels={"recruit":1}
	check(Game.total_upgrade_level()==5,"total includes levels")
	Game.class_levels["heavy"]=7  # level 8: two slots (0.8.0 class path)
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false)
	for actor in arena.actors:actor.set_physics_process(false)
	arena.phase="combat";arena.abilities.select("comrade");arena.abilities.cast_slot(0)
	check(arena.abilities.selected=="shield" and arena.abilities.shield_time>0,"first slot independent of selected ability")
	var snap=preload("res://scripts/ui/battle_snapshot.gd").capture(arena)
	check(snap.skills[0].text=="" and snap.skills[0].active==4 and snap.skills[0].cooling,"active state uses separate timer, no cooldown number")
	arena.abilities.tick(8);snap=preload("res://scripts/ui/battle_snapshot.gd").capture(arena)
	check(snap.skills[0].active==0 and snap.skills[0].progress>0 and snap.skills[0].progress<1,"sector fills during cooldown")
	arena.phase="upgrade"
	if arena.presentation.text_tween:arena.presentation.text_tween.kill()
	arena.hud.show_upgrades()
	# Cards slide in before they accept input.
	await until(func():return not CardNavigation.available().is_empty())
	key(KEY_SPACE,true);await get_tree().process_frame;key(KEY_SPACE,false)
	check(arena.phase=="upgrade","space never confirms reward")
	key(KEY_E,true);await get_tree().process_frame;key(KEY_E,false)
	check(arena.phase=="countdown","E confirms reward")
	arena.phase="upgrade";arena.room.next_is_room=false;var damage=arena.damage_bonus
	arena.reward.skip_upgrade();check(arena.phase=="countdown" and arena.damage_bonus==damage,"skip advances without reward")
	arena.phase="upgrade";arena.hud.show_departure();await get_tree().process_frame
	check(CardNavigation.available().size()==2,"departure buttons keyboard navigable")
	arena.hud.close_modal()
	var foot=arena.player;var personal_weapon=arena.weapon
	arena.player=arena.spawn_actor("tank",Vector2i(5,5),true);arena.player.set_physics_process(false)
	await until(func():return arena.hud.transport_panel.visible and is_equal_approx(arena.hud.left_info.position.y,339))
	check(arena.hud.transport_panel.visible and is_equal_approx(arena.hud.left_info.position.y,339),"vehicle panel slides in above weapon")
	check(arena.hud.vehicle_label.text==Texts.localized(arena.LOOT.WEAPONS[personal_weapon].name),"boarding keeps personal weapon panel")
	var vehicle=arena.player;arena.player=foot;vehicle.queue_free()
	await until(func():return not arena.hud.transport_panel.visible and is_equal_approx(arena.hud.left_info.position.y,135))
	check(not arena.hud.transport_panel.visible and is_equal_approx(arena.hud.left_info.position.y,135),"exit restores weapon panel position")
	arena.phase="combat";arena.drop_recipe(arena.player.cell,{"elite":false});arena.open_recipe_draft(arena.pickups.back())
	var money=Game.credits;var recipes=arena.pending_recipes.size();arena.reward.skip_chest()
	check(arena.phase=="combat" and arena.draft_pickup.is_empty() and Game.credits==money and arena.pending_recipes.size()==recipes,"decline chest grants no optional reward")
	var camp=load("res://scripts/service_room.gd").new();camp.arena=arena;add_child(camp)
	var mods=arena.run.vehicle_mods.duplicate(true);camp.skip_choice()
	check(camp.claimed and not camp.continue_button.disabled and arena.run.vehicle_mods==mods,"decline service permits exit without upgrade")
	camp.queue_free();arena.queue_free();await get_tree().process_frame
	var route=load("res://scripts/route_map.gd").new();route.available=2;route.needs_service=true;route.ability_available=false;route.wave_seed=42;add_child(route)
	# Service stops are reached by the road from the previous lane: only those branches are offered.
	var offered=Campaign.service_options(route.wave_seed,2)
	check(not route.fork_positions.is_empty() and route.fork_positions.keys().all(func(b):return b in offered) and route.service_choices==route.fork_positions.keys(),"service branches follow the roads")
	check(route.fork_positions.values().all(func(p):return is_equal_approx(p.z,route.stage_z(2)+RoutePlan.STAGE_STEP)),"service row sits one regular step before its stage")
	var branch="ability" if "ability" in route.fork_positions else route.service_choices[0]
	var service=[];route.service_requested.connect(func(chosen,_index):service.append(chosen))
	route.choose_service(branch);await get_tree().create_timer(.6).timeout
	route.confirm_service();check(service==[branch],"service branch is chosen even without ability unlocks")
	# The map scene would switch here; reuse it for the room stop.
	route.travelling=false;route.pending_service="";route.needs_service=false
	route.show_pause();await get_tree().process_frame;await get_tree().process_frame
	var tablets=get_tree().get_nodes_in_group("field_tablet")
	check(route.showing_pause and tablets.size()==1,"map inventory can open")
	tablets[0].close();await get_tree().process_frame
	check(not route.showing_pause and not get_tree().paused,"map inventory closes")
	var start=route.player_marker.position;var entered=[];route.route_selected.connect(func(i,id):entered.append([i,id]))
	route.travel_to_room(2,route.reachable[0]);await arrive(route)
	check(not route.travelling and entered.is_empty(),"approach does not enter by itself")
	route.show_pause();await get_tree().process_frame;await get_tree().process_frame
	get_tree().get_nodes_in_group("field_tablet")[0].close();await get_tree().process_frame
	check(is_instance_valid(route.modal) and not route.showing_pause and not get_tree().paused,"inventory returns to briefing")
	route.cancel_entry();await arrive(route)
	check(route.player_marker.position.is_equal_approx(start) and not route.travelling,"cancel returns hero to previous position")
	route.travel_to_room(2,route.reachable[0]);await arrive(route)
	route.confirm_entry();await until(func():return not entered.is_empty());await get_tree().create_timer(.2).timeout
	check(entered.size()==1,"confirmed entry emitted once after fade")
	route.queue_free();await get_tree().process_frame
	var route_dev=load("res://scripts/route_map.gd").new();route_dev.wave_seed=42;add_child(route_dev)
	var target=route_dev.plan[4][0].id;var dev_events=[]
	route_dev.dev_requested.connect(func(stage,progress,id):dev_events.append([stage,progress,id]))
	await arrive(route_dev)  # the hero first drives out of the garage
	route_dev.travel_to_room(4,target);await arrive(route_dev)
	route_dev.confirm_entry();check(not route_dev.travelling,"normal entry cannot skip ahead")
	route_dev.dev_entry(true);await until(func():return not dev_events.is_empty())
	check(dev_events==[[4,true,target]],"dev progression can enter arbitrary stage")
	route_dev.queue_free();await get_tree().process_frame
	# With a selected profile main opens the hub deferred; let that happen before the jump replaces it.
	var main=load("res://scripts/main.gd").new();add_child(main);await get_tree().process_frame;await get_tree().process_frame
	main.test_jump(4,true,"4:0")
	main.run_arena.set_physics_process(false)
	var replay=main.run_arena.replay
	check(is_instance_valid(replay) and replay.cursor==1 and main.run_arena.room_index==0,"progress run waits for first player choice")
	var event_count=replay.events.size()
	for step in range(event_count):
		await get_tree().create_timer(.4).timeout
		var event=replay.events[step]
		match event.type:
			"upgrade":
				if step==0:
					var offer=main.run_arena.upgrade_offers[0];main.run_arena.reward.apply_upgrade(offer.id,offer.tier)
				else:main.run_arena.reward.skip_upgrade()
			"chest":
				if step==2:main.run_arena.reward.choose_recipe_card(1)
				else:main.run_arena.reward.skip_chest()
			"service":
				replay.open_service("vehicle",event.room);replay.service.claim(0);replay.service.completed.emit(event.room)
		await get_tree().process_frame
	check(main.run_arena.room_index==4 and not is_instance_valid(main.run_arena.replay),"all interactive choices finish at target room")
	main.test_jump(4,false,"4:0")
	check(main.run_arena.room_index==4 and not is_instance_valid(main.run_arena.replay),"plain dev run skips progression choices")
	main.run_arena.set_physics_process(false);main.queue_free();await get_tree().process_frame
	print("UI REFRESH: %d checks, %d failures" % [checks,failures]);get_tree().quit(1 if failures else 0)
func _ready():call_deferred("run")
