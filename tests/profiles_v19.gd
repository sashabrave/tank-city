extends Node
const Store=preload("res://scripts/profile/store.gd")
const Schema=preload("res://scripts/profile/schema.gd")
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
	assert(Game.profiles.choose(2,true));assert(Game.credits==0 and Game.built_workshops.is_empty() and Game.hero_loadout()==[Game.class_skill()])
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
	print("PASS profiles: migration 1–12, validation, atomic backup recovery, future/write protection, isolated slots and deletion")
	get_tree().quit()
