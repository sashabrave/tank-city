extends Node3D
var checks=0
var failures=0
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures+=1;push_error(message)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false;Game.reset_upgrades()
	for kind in ["soldier","shield","sniper","grenadier","apc","buggy","tank","boss","drone","flyer"]:
		var model=Visuals.model(kind,self)
		check(not model.paint_materials.is_empty(),"paint surfaces "+kind)
		model.set_paint("enemy",2)
		# Rank is shown by paint colour now (stripes retired).
		for mat in model.paint_materials:
			check(not mat.get_shader_parameter("striped"),"no rank stripes "+kind)
			check(mat.get_shader_parameter("paint_color")==model.RANK_COLORS[1],"rank two enemy color "+kind)
		model.set_paint("capture");model.clock=0;model._process(.1)
		check(model.paint_materials[0].get_shader_parameter("flash")>0,"capture pulse on")
		model._process(.4);check(model.paint_materials[0].get_shader_parameter("flash")==0,"capture pulse off")
		model.set_paint("explode");check(model.paint_materials[0].get_shader_parameter("paint_color")==Color("af231b"),"wreck paint replaces rank colour")
		model.free()
	for id in ["heart","repair","wall","vehicle_repair","turret","vehicle","star"]:
		var bonus=LootCatalog.visual(self,id)
		check(bonus.find_children("*","MeshInstance3D",true,false).size()>0,"Blender bonus "+id)
		# Measure the model itself; the pickup glow around it is larger by design.
		var art=bonus.get_child(0);var bounds=Visuals.mesh_bounds(art,Transform3D.IDENTITY)
		check(is_equal_approx(maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z)),.7),"bonus fits cell "+id)
		bonus.free()
	var arena
	# Zone one field (three spawners) and zone two field (four spawners).
	for world in [1,2]:
		Campaign.configure(world)
		if arena:arena.queue_free();await get_tree().process_frame
		arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false)
		arena.begin_room(0);arena.phase="combat"
		for actor in arena.actors:actor.set_physics_process(false)
		var columns=arena.spawn_columns();var target=Vector2i(columns[1],0);check(columns.size()==world+2,"spawner count for world "+str(world))
		# 0.7.1: a blocked central spawner no longer holds the commander back; it enters next to it.
		var block=arena.spawn_actor("soldier",target,false);block.set_physics_process(false)
		arena.spawn_room_boss();var bosses=arena.actors.filter(func(a):return a.elite)
		check(arena.room_boss_spawned and bosses.size()==1 and bosses[0].cell!=target and absi(bosses[0].cell.x-target.x)+absi(bosses[0].cell.y-target.y)==1,"blocked central spawner: commander beside it")
		for actor in bosses+[block]:arena.actors.erase(actor);actor.free()
		arena.room_boss_spawned=false;arena.spawn_room_boss()
		bosses=arena.actors.filter(func(a):return a.elite)
		check(bosses.size()==1 and bosses[0].cell==target,"miniboss at spawner two for "+str(columns.size()))
		check(bosses[0].model.paint_mode=="enemy","miniboss keeps faction paint")
	var wreck=arena.make_wreck("apc",Vector2i(1,3),Vector2i.UP,true)
	check(wreck.model.paint_mode=="explode","unstable wreck red")
	wreck.unstable=false;wreck.boardable=true;wreck.refresh_label();check(wreck.model.paint_mode=="capture","boardable wreck green")
	wreck.start_delivery(2);check(wreck.model.paint_mode=="friendly","airborne delivery not boardable")
	wreck._physics_process(2);check(wreck.model.paint_mode=="capture","landed delivery green")
	arena.phase="upgrade";arena.room.upgrade_offers.clear();arena.reward.prepare_upgrade_offers()
	check(not arena.room.upgrade_offers.any(func(o):return o.id=="recovery"),"no passive shield cards")
	check("shield" in Game.ability_unlocks and Game.special_cost("shield")==-1,"active shield available; no passive purchase")
	var original_path=Game.save_path;var folder="/private/tmp/war-cats-game-update-v6-%d-%d" % [Time.get_ticks_usec(),randi()];DirAccess.make_dir_recursive_absolute(folder);Game.save_path=folder+"/progress.json"
	var file=FileAccess.open(Game.save_path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"version":9,"credits":50,"recovery":2,"branch_unlocks":["health","recovery"],"v09":{"shield_capacity":2}}));file.close()
	Game.load_progress()
	# Refund at today's prices: 50 owned + shield 350+700 + two recovery levels + the recovery branch unlock.
	var economy=Balance.CONFIG.economy;var refunded=50+1050+economy.upgrade_base_cost*2+economy.upgrade_step_cost+Game.UNLOCK_COSTS.get("recovery",140)
	check(Game.credits==refunded and Game.recovery_level==0 and Game.shield_capacity_level==0,"old shield purchases refunded")
	Game.save_enabled=true;Game.save_progress();Game.save_enabled=false;Game.load_progress()
	check(Game.credits==refunded,"refund does not repeat after saving")
	Game.save_path=original_path
	arena.queue_free();await get_tree().process_frame
	print("GAME UPDATE V6: %d checks, %d failures" % [checks,failures]);get_tree().quit(1 if failures else 0)
