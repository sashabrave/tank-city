extends Node3D
var failures=0
var checks=0
func check(ok:bool,msg:String):
	checks+=1
	if not ok:failures+=1;push_error(msg)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Game.visual_run_seed=42
	var preview=preload("res://scripts/room_wave_preview.gd")
	for seed_value in [42,43]:
		for room in range(17):
			var rosters=preview.waves(seed_value,room)
			if room in Campaign.BOSSES:
				check(rosters.size()==1 and rosters[0].size()==(2 if room in [6,15] and (seed_value+room)%2==0 else 1),"boss roster")
			else:
				for wave in range(3):check(rosters[wave]==WaveDirector.build(seed_value,room,wave),"exact wave roster")
	var route=load("res://scripts/route_map.gd").new();route.available=12;route.wave_seed=42;route.hero_kind="apc";route.hero_weapon="shotgun";add_child(route)
	check(route.wave_rosters.size()==17,"all rooms have rosters")
	var visible=0
	for i in range(17):
		var node=route.room_previews[i]
		if node.has_meta("lineup"):
			visible+=1;var lineup=node.get_meta("lineup")
			if i<route.available:
				check(lineup.name=="ClearedWrecks" and lineup.get_child_count()==2,"completed rooms have two wrecks only")
			else:
				var expected=preview.representatives(route.wave_rosters[i]).size()
				check(lineup.get_child_count()==expected,"one model per distinct type")
				var keys={}
				for unit in lineup.get_children():keys[unit.get_meta("enemy_type")]=true
				check(keys.size()==expected,"no duplicate enemy types")
	check(visible<=4,"only nearby lineups instantiated")
	check(route.find_children("CurrentHero","Node3D",true,false).size()==1,"one player marker on whole map")
	check(route.player_marker.get_node("CurrentHero").kind=="apc","current transport displayed")
	check(is_equal_approx(route.player_marker.position.z,route.stage_z(11)+2.0*route.MINI_SCALE),"hero starts on completed current room")
	route.scroll=0;route.move_camera();check(not route.room_previews[12].has_meta("lineup"),"distant units unloaded")
	check(route.room_previews[0].get_meta("lineup").get_child_count()==2,"old room stays cleared on scroll")
	route.scroll=-route.stage_z(12)-7;route.move_camera()
	route.travel_to_room(13);check(not route.travelling,"cannot skip ahead")
	route.needs_service=true;route.travel_to_room(12);check(not route.travelling,"service cannot be bypassed")
	route.needs_service=false
	var entered=[];route.enter_requested.connect(func(index):entered.append(index))
	route.tap_at(route.camera.unproject_position(route.previews[route.reachable[0]].position+Vector3.UP*.17))
	check(route.travelling and entered.is_empty(),"click starts travel before combat")
	route.travel_to_room(12)
	await get_tree().create_timer(.4).timeout
	check(route.player_marker.position.z<route.stage_z(11)+2.0*route.MINI_SCALE and route.player_marker.position.z>route.stage_z(12)+2.0*route.MINI_SCALE,"player visibly moves between rooms")
	await get_tree().create_timer(.85).timeout
	check(entered.is_empty() and is_instance_valid(route.modal),"arrival opens confirmation")
	route.confirm_entry();await get_tree().create_timer(.45).timeout
	check(entered==[12],"one entry after confirmation")
	route.queue_free();await get_tree().process_frame
	var main=load("res://scripts/main.gd").new();add_child(main);main.start_run()
	var seed_before=main.current.wave_seed;main.enter_room(0)
	check(main.run_arena.run_seed==seed_before,"first room uses preview seed")
	main.run_arena.weapon="sniper";main.run_arena.pending_vehicle="buggy";main.show_map(1)
	check(main.current.hero_weapon=="sniper" and main.current.hero_kind=="buggy","run weapon and pending vehicle forwarded")
	main.show_hub();main.queue_free();await get_tree().process_frame
	print("ROUTE PREVIEW: %d checks, %d failures" % [checks,failures]);get_tree().quit(1 if failures else 0)
