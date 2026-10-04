extends Node
const Store=preload("res://scripts/profile/store.gd")
const Schema=preload("res://scripts/profile/schema.gd")
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():
	print("Existing selected profile readable: ",not Game.save_blocked)
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.save_blocked=false
	var directory="/tmp/tank-profiles-%d" % Time.get_ticks_usec()
	var path=directory.path_join("save.json")
	var data=Game.fresh_profile.duplicate(true);data.credits=73
	assert(Store.write_file(path,data,Schema.validate).ok)
	data.credits=91;assert(Store.write_file(path,data,Schema.validate).ok)
	assert(Store.read_json(path+".bak",Schema.validate).data.credits==73)
	var file=FileAccess.open(path,FileAccess.WRITE);file.store_string("{broken");file.close()
	var recovered=Store.load_file(path,Schema.validate);assert(recovered.ok and recovered.recovered and recovered.data.credits==73)
	assert(Store.write_file(path,data,Schema.validate).ok)
	assert(Store.read_json(path+".bak",Schema.validate).data.credits==73)
	for version in range(1,Schema.VERSION+1):
		var legacy=data.duplicate(true);legacy.version=version
		var result=Schema.validate(legacy);assert(result.ok and result.data.version==Schema.VERSION)
		assert(Schema.validate(result.data).data==result.data,"Idempotent migration")
	var retired=data.duplicate(true);retired.version=9;retired.v09.shield_capacity=1;retired.recovery=2
	var migrated=Schema.validate(retired).data
	assert(migrated.credits>retired.credits and migrated.v09.shield_capacity==0 and migrated.recovery==0)
	assert(Schema.validate(migrated).data.credits==migrated.credits,"Refund once")
	var partial={"version":11,"credits":5};assert(not Schema.validate(partial).ok)
	var invalid=data.duplicate(true);invalid.progression.weapons=[];assert(not Schema.validate(invalid).ok)
	invalid=data.duplicate(true);invalid.garage.owned="bad";assert(not Schema.validate(invalid).ok)
	invalid=data.duplicate(true);invalid.version=99
	file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(invalid));file.close()
	assert(Store.load_file(path,Schema.validate).get("future",false),"Future profile never replaced by backup")
	assert(not Store.write_file(path,data,Schema.validate).ok)
	assert(not Store.write_file("/dev/null/impossible/save.json",data,Schema.validate).ok)
	Game.profiles.directory=directory;Game.profiles.active=1;Game.profiles.selected=true;Game.save_path=Game.profiles.path(1);Game.save_enabled=true
	Game.apply_profile(Game.fresh_profile.duplicate(true));Game.credits=123;Game.progression.prepare_telegrams();assert(Game.save_progress())
	assert(Game.profiles.choose(2,true));assert(Game.credits==0 and Game.built_workshops.is_empty() and Game.hero_loadout().is_empty())  # no abilities at the start (0.8.0)
	Game.duplicate_recipes=[{"category":"weapon","id":"pistol"}];Game.credits=456;Game.health_level=7;assert(Game.save_progress())
	assert(Game.profiles.choose(1));assert(Game.credits==123 and Game.health_level==0 and Game.duplicate_recipes.is_empty())
	assert(Game.profiles.choose(2));assert(Game.credits==456 and Game.health_level==7 and Game.duplicate_recipes.size()==1)
	assert(Game.profiles.remove(1));assert(not Game.profiles.exists(1));assert(Game.credits==456)
	assert(Game.profiles.remove(2));assert(Game.credits==0 and Game.health_level==0)
	Game.save_enabled=true
	Game.checkpoint_run(null,0,"map",{})
	assert(not Game.profiles.exists(2),"Deleted slot is not implicitly recreated")
	assert(Game.profiles.choose(1,true));assert(Game.run_checkpoint.is_empty())
	assert(Game.profiles.choose(2,true));assert(Game.run_checkpoint.is_empty())
	# Merged checks below write only into a fresh subfolder of this test's temp directory.
	var extra=directory.path_join("extra-%d" % Time.get_ticks_usec());DirAccess.make_dir_recursive_absolute(extra)
	Game.save_path=extra.path_join("profile.json");Game.profiles.selected=true;Game.save_blocked=false;Game.save_enabled=true
	# from save_integrity_revision: hub stations keep their seen lists (Arrays) in viewed_updates and the profile still saves.
	var N=preload("res://scripts/ui/station_notices.gd")
	Game.credits=100000;Game.cores=50
	for kind in N.STATIONS:N.mark_all_seen(kind)
	check(Game.progression.viewed_updates.get("station:fighter") is Array,"stations keep their seen lists")
	check(Game.save_progress() and Game.save_error=="","save succeeds after visiting every station, no save error")
	var loaded=Store.load_file(Game.save_path,Schema.validate)
	check(loaded.ok and int(loaded.data.credits)==100000 and loaded.data.progression.viewed_updates.get("station:fighter") is Array,"written profile loads back with credits and station lists")
	Game.credits=4242;check(Game.save_progress(),"second save rotates the backup")
	var backup=Store.read_json(Game.save_path+".bak",Schema.validate)
	check(backup.ok and int(backup.data.credits)==100000,"backup keeps the previous good save")
	# serialize_progress shares nested dictionaries with the live state: copy before breaking it.
	var broken=Game.serialize_progress().duplicate(true);broken.progression.viewed_updates["station:x"]=[1]
	check(not Schema.validate(broken).ok,"non-string ids in a station list are still rejected")
	# from environment_v7: discovered recipes survive save/load; closing one persists; reset clears them after reload.
	Game.set_all_recipes(true);Game.selected_weapon="rifle";Game.save_progress();Game.load_progress()
	check(Game.recipe_owned("weapon").size()==Game.LOOT.gun_ids().size(),"all weapon recipes survive save/load")
	Game.set_recipe_unlocked("weapon","rifle",false);Game.load_progress()
	check("rifle" not in Game.weapon_unlocks and Game.selected_weapon=="pistol","closing the equipped weapon persists and restores the pistol")
	Game.set_recipe_unlocked("research","garage",false);Game.load_progress()
	check("garage" not in Game.research_unlocks,"closing research persists")
	Game.reset_upgrades();Game.load_progress()
	check(Game.weapon_unlocks==["pistol"] and Game.bonus_unlocks==["heart"] and Game.research_unlocks==["character"],"reset clears all discovered recipes after reload")
	check(Game.built_workshops.is_empty() and Game.credits==0 and Game.cores==0,"reset clears buildings and currency")
	# from player_models_revision: the player model choice survives a profile round trip; unknown ids fall back.
	var model=PlayerModels.MODELS.keys().filter(func(id):return id!=PlayerModels.DEFAULT)
	model=model[0] if not model.is_empty() else PlayerModels.DEFAULT
	Game.player_model=model
	var profile=Game.serialize_progress()
	check(profile.get("player_model")==model,"profile stores the player model")
	Game.reset_upgrades();check(Game.player_model==PlayerModels.DEFAULT,"reset returns to the default model")
	Game.apply_profile(profile);check(Game.player_model==model,"profile restores the player model")
	profile.player_model="nope";Game.apply_profile(profile);check(Game.player_model==PlayerModels.DEFAULT,"unknown model falls back to the default")
	Game.player_model=PlayerModels.DEFAULT
	Game.save_enabled=false
	print("PASS profiles: migration 1–12, validation, atomic backup recovery, future/write protection, isolated slots and deletion")
	print("PROFILES: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
