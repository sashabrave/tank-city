extends Node3D
var checks=0
var failures=0
func check(ok,message):
	checks+=1
	if not ok:failures+=1;push_error(message)
func _ready():call_deferred("run")
func shot(name):
	if DisplayServer.get_name()=="headless":return
	RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("res://art_demo/environment_v7/"+name+".png")
func run():
	Game.sound_enabled=false;Game.save_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades()
	# Persistence tests use their own fresh temporary folder (profile and backups), never the real player profile.
	var folder="/tmp/war-cats-environment-v7-%d-%d" % [Time.get_ticks_usec(),randi()];DirAccess.make_dir_recursive_absolute(folder)
	var original=Game.save_path;Game.save_path=folder+"/profile.json";Game.save_enabled=true
	Game.set_all_recipes(true);Game.selected_weapon="rifle";Game.save_progress();Game.load_progress()
	check(Game.recipe_owned("weapon").size()==Game.LOOT.gun_ids().size(),"all weapon recipes survive save/load")
	Game.set_recipe_unlocked("weapon","rifle",false);Game.load_progress()
	check("rifle" not in Game.weapon_unlocks and Game.selected_weapon=="pistol","closing equipped weapon persists and restores pistol")
	Game.set_recipe_unlocked("research","garage",false);Game.load_progress()
	check("garage" not in Game.research_unlocks,"closing research persists")
	Game.reset_upgrades();Game.load_progress()
	check(Game.weapon_unlocks==["pistol"] and Game.bonus_unlocks==["heart"] and Game.research_unlocks==["character"],"reset clears all discovered recipes after reload")
	check(Game.built_workshops.is_empty() and Game.credits==0 and Game.cores==0,"reset clears buildings and currency")
	Game.save_enabled=false;Game.save_path=original
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub)
	await get_tree().create_timer(.4).timeout;shot("hub_locked")
	check(not hub.training_tank.visible,"locked garage contains no tank")
	check(hub.bench_visuals.find_children("*parking*","Node3D",true,false).size()>0,"locked garage has concrete parking asset")
	hub.show_recipe_shop();await get_tree().create_timer(.3).timeout;shot("recipe_shop")
	check(CardNavigation.available().size()>=10,"recipe shop keyboard selections available")
	# The yard shows the owned starting vehicle once the garage stands.
	hub.close_station();Game.set_all_recipes(true);Game.built_workshops=Game.BUILD_COST.keys();Game.garage.owned=["tank"];Game.garage.selected="tank";hub.refresh()
	await get_tree().create_timer(.4).timeout;shot("hub_built")
	check(hub.training_tank.visible,"built garage shows tank")
	for kind in Game.BUILD_COST.keys().filter(func(id):return id not in ["garage","range"]):check(hub.bench_visuals.find_children("*bench_"+kind+"*","Node3D",true,false).size()>0,"distinct bench "+kind)
	hub.mounted=true;hub.avatar.hide();hub.reset_upgrades()
	check(not hub.mounted and hub.avatar.visible and not hub.training_tank.visible and Game.research_unlocks==["character"],"hub reset clears recipes and exits removed vehicle")
	hub.queue_free();await get_tree().process_frame
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false)
	for actor in arena.actors:actor.set_physics_process(false)
	await get_tree().create_timer(.3).timeout;shot("zone_one")
	# Destructible cover is the sectioned brick wall in every zone (colour from the biome palette).
	var bricks=arena.walls.values().filter(func(w):return w.hp>0 and not w.get("barrel",false) and not w.get("barrier",false))
	check(not bricks.is_empty() and bricks.all(func(w):return w.has("sections")),"zone one uses sectioned brick")
	arena.queue_free();await get_tree().process_frame
	Campaign.configure(2)
	arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false)
	for actor in arena.actors:actor.set_physics_process(false)
	await get_tree().create_timer(.3).timeout;shot("zone_two")
	bricks=arena.walls.values().filter(func(w):return w.hp>0 and not w.get("barrel",false) and not w.get("barrier",false))
	check(not bricks.is_empty() and bricks.all(func(w):return w.has("sections")),"zone two uses sectioned brick")
	var cell=arena.walls.find_key(bricks[0]);arena.board.damage_wall(cell,1000)
	check(not arena.walls.has(cell),"wall destruction removes collider cell")
	arena.queue_free();await get_tree().process_frame
	var display=Node3D.new();add_child(display);Visuals.setup_world(display,10,Vector3(0,0,0))
	var kinds=["wall","brick","cement","crate","bench_character","bench_weapons","bench_bonuses","parking"]
	for i in range(kinds.size()):
		var pos=Vector3((i%4-1.5)*2.4,0,(int(i/4.0)-.5)*3)
		Visuals.model(kinds[i],display,pos)
	await get_tree().create_timer(.4).timeout;shot("asset_review")
	print("ENVIRONMENT V7: %d checks, %d failures" % [checks,failures]);get_tree().quit(1 if failures else 0)
