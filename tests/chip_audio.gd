extends Node
var errors=0
func check(ok:bool,message:String):
	if not ok:errors+=1;push_error(message)
	else:print("PASS: "+message)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=true
	var audio=Game.audio()
	check(audio.banks.size()>=109,"all audio banks load")
	var files=0
	for id in audio.banks:
		for file in audio.banks[id].files:
			var stream=load(audio.ROOT+file)
			check(stream is AudioStreamWAV and stream.get_length()>0,"valid asset "+file);files+=1
	var expected=0
	for id in audio.banks:expected+=audio.banks[id].files.size()
	check(files==expected and files>=253,"every manifest variation loads")
	var old=audio.stream_for("fire_pistol");check(old!=audio.stream_for("fire_pistol"),"variations do not repeat consecutively")
	for i in range(40):
		var source=Node.new();add_child(source);Game.sound("fire_rifle",source);source.queue_free()
	check(audio.voices.size()<=28,"one-shot polyphony bounded")
	var loop_owner=Node3D.new();add_child(loop_owner);Game.sound_loop("engine_tank",loop_owner)
	var key=str(loop_owner.get_instance_id())+":engine_tank"
	check(audio.loops.has(key),"engine loop starts")
	loop_owner.queue_free();await get_tree().process_frame;await get_tree().process_frame
	check(not audio.loops.has(key),"loop removed with owner")
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena)
	arena.auto_pause_enabled=false;arena.phase="combat";arena.spawn_queue.clear();arena.set_physics_process(false)
	var player=arena.player;player.set_physics_process(false)
	for weapon in ["pistol","smg","shotgun","rifle","sniper","rpg"]:
		arena.weapon=weapon;arena.fire_weapon(player)
		check(audio.stats.get("fire_"+weapon,0)>0,"weapon hook "+weapon)
	var shotgun_count=int(audio.stats.get("fire_shotgun",0))
	check(shotgun_count==1,"shotgun pellets emit one sound")
	player.invulnerable=0;arena.abilities.shield_time=2;player.take_damage(1)
	check(audio.stats.get("shield_hit",0)>0,"shield hit hook")
	arena.abilities.shield_time=0;player.invulnerable=0;player.take_damage(.1)
	check(audio.stats.get("player_hurt",0)>0,"player damage hook")
	arena.explosion(Vector3(-50,0,-50),1)
	check(audio.stats.get("explosion_heavy",0)>0,"heavy explosion hook")
	for kind in ["soldier","grenadier","shield","sniper","buggy","apc","tank","boss","drone","flyer","mortar"]:
		var enemy=arena.spawn_actor(kind,Vector2i(2,2),false)
		enemy.set_physics_process(false)
		Game.weapon_sound(enemy)
		enemy.get_child(0).set_process(false)
	for ability in ["barrier","grenade","laser","shield","cloak","ally_drone","gas","mine","airstrike","comrade"]:
		arena.abilities.select(ability);arena.abilities.cooldown=0
		arena.abilities.cast()
	for effect in arena.get_children():
		if effect.get_script()==load("res://scripts/ability_effect.gd"):effect._physics_process(.1)
	var boss=arena.actors.filter(func(a):return a.kind=="boss")[0]
	arena.boss.boss_radial_attack(boss)
	check(audio.stats.get("boss_radial",0)==1,"radial salvo emits one event")
	get_tree().paused=true;Game.sound("ui_confirm",self);audio._process(.01)
	check(not audio.voices.back().stream_paused,"UI audible while paused")
	get_tree().paused=false
	for context in ["hub","battle","boss","hub","battle","boss","hub","battle","boss"]:
		Game.music_context(context)
		var mc=Game.music_controller;check(mc.backgrounds[mc.active].stream!=null or mc.pending_track!="","music context "+context)  # tracks load in the background
	check(Game.music_controller.selections.hub==3,"music variants rotate")
	var owner=Node3D.new();add_child(owner);Game.sound_loop("engine_buggy",owner)
	Game.sound_enabled=false;await get_tree().process_frame;await get_tree().process_frame
	check(audio.loops.is_empty(),"sound disable stops loops")
	Game.sound_enabled=true
	arena.queue_free();owner.queue_free();await get_tree().process_frame
	print("CHIP_AUDIO_FAILURES=",errors);get_tree().quit(errors)
