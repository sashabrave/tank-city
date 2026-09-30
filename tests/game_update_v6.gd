extends Node3D
var checks=0
var failures=0
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures+=1;push_error(message)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Game.reset_upgrades()
	for kind in ["soldier","shield","sniper","grenadier","apc","buggy","tank","boss","drone","flyer"]:
		var model=Visuals.model(kind,self)
		check(not model.paint_materials.is_empty(),"paint surfaces "+kind)
		model.set_paint("enemy",2)
		for mat in model.paint_materials:
			check(mat.get_shader_parameter("striped"),"rank two stripes "+kind)
			check(mat.get_shader_parameter("paint_color")==Color("702d2b"),"enemy color "+kind)
		model.set_paint("capture");model.clock=0;model._process(.1)
		check(model.paint_materials[0].get_shader_parameter("flash")>0,"capture pulse on")
		model._process(.4);check(model.paint_materials[0].get_shader_parameter("flash")==0,"capture pulse off")
		model.set_paint("explode");check(not model.paint_materials[0].get_shader_parameter("striped"),"wreck clears rank stripes")
		model.free()
	for id in ["heart","repair","wall","vehicle_repair","turret","vehicle","star"]:
		var bonus=LootCatalog.visual(self,id)
		check(bonus.find_children("*","MeshInstance3D",true,false).size()>0,"Blender bonus "+id)
		var bounds=Visuals.mesh_bounds(bonus,Transform3D.IDENTITY)
		check(is_equal_approx(maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z)),.7),"bonus fits cell "+id)
		bonus.free()
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false)
	for room in [0,7]:
		arena.begin_room(room);arena.phase="combat"
		for actor in arena.actors:actor.set_physics_process(false)
		var columns=arena.spawn_columns();var target=Vector2i(columns[1],0)
		var block=arena.spawn_actor("soldier",target,false);block.set_physics_process(false)
		arena.spawn_room_boss();check(not arena.room_boss_spawned,"blocked central spawner waits")
		arena.actors.erase(block);block.free()
		arena.spawn_room_boss()
		var bosses=arena.actors.filter(func(a):return a.elite)
		check(bosses.size()==1 and bosses[0].cell==target,"miniboss at spawner two for "+str(columns.size()))
		check(bosses[0].model.paint_mode=="enemy","miniboss keeps faction paint")
	var wreck=arena.make_wreck("apc",Vector2i(1,3),Vector2i.UP,true)
	check(wreck.model.paint_mode=="explode","unstable wreck red")
	wreck.unstable=false;wreck.refresh_label();check(wreck.model.paint_mode=="capture","boardable wreck green")
	wreck.start_delivery(2);check(wreck.model.paint_mode=="friendly","airborne delivery not boardable")
	wreck._physics_process(2);check(wreck.model.paint_mode=="capture","landed delivery green")
	arena.phase="upgrade";arena.room.upgrade_offers.clear();arena.reward.prepare_upgrade_offers()
	check(not arena.room.upgrade_offers.any(func(o):return o.id=="recovery"),"no passive shield cards")
	check("shield" in Game.ability_unlocks and Game.special_cost("shield")==-1,"active shield available; no passive purchase")
	var original_path=Game.save_path;Game.save_path="/private/tmp/game-update-v6-save.json"
	var file=FileAccess.open(Game.save_path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"version":9,"credits":50,"recovery":2,"branch_unlocks":["health","recovery"],"v09":{"shield_capacity":2}}));file.close()
	Game.load_progress()
	check(Game.credits==1263 and Game.recovery_level==0 and Game.shield_capacity_level==0,"old shield purchases refunded")
	Game.save_enabled=true;Game.save_progress();Game.save_enabled=false;Game.load_progress()
	check(Game.credits==1263,"refund does not repeat after saving")
	Game.save_path=original_path
	arena.queue_free();await get_tree().process_frame
	print("GAME UPDATE V6: %d checks, %d failures" % [checks,failures]);get_tree().quit(1 if failures else 0)
