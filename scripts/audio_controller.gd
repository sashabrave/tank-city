extends Node
## Independent audio RNG never changes combat/map seeds. One-shots survive emitter deletion.
const ROOT="res://assets/audio/chip/"
const ALIASES={"shot":"fire_pistol","hit":"hit_stone","boom":"explosion_small","upgrade":"ui_confirm","foliage_crack":"hit_wood"}
var banks:Dictionary={}
var cache:Dictionary={}
var last_variant:Dictionary={}
var cooldowns:Dictionary={}
var voices:Array=[]
var loops:Dictionary={}
var rng=RandomNumberGenerator.new()
var stats:Dictionary={}
func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index("TankCityEffects")<0:
		AudioServer.add_bus();AudioServer.set_bus_name(AudioServer.bus_count-1,"TankCityEffects")
	var bus=AudioServer.get_bus_index("TankCityEffects")
	if AudioServer.get_bus_effect_count(bus)==0:AudioServer.add_bus_effect(bus,AudioEffectLimiter.new())
	rng.randomize()
	banks=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"manifest.json"))
	add_child(load("res://scripts/progression_audio.gd").new())
	add_child(load("res://scripts/ui/interface_audio.gd").new())
func stream_for(id:String):
	var files=banks[id].files
	var index=rng.randi_range(0,files.size()-1)
	if files.size()>1 and index==last_variant.get(id,-1):index=(index+1)%files.size()
	last_variant[id]=index
	var path=ROOT+files[index]
	if not cache.has(path):
		# Warmed in the background at start; a finished threaded load is picked up without blocking.
		if ResourceLoader.load_threaded_get_status(path)==ResourceLoader.THREAD_LOAD_LOADED:cache[path]=ResourceLoader.load_threaded_get(path)
		else:cache[path]=load(path)
	return cache[path]
## Starts background loading of every effect variant so the first shots do not wait for the disk.
func warm():
	for id in banks:
		for file in banks[id].files:
			var path=ROOT+file
			if not cache.has(path) and ResourceLoader.load_threaded_get_status(path)==ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:ResourceLoader.load_threaded_request(path)
func gain(id:String,own:=false)->float:
	# The hero's gun sits on top of the battle; enemy guns stay a step under it, impacts under the guns.
	if own and id.begins_with("fire"):return -15.0
	if id=="ui_hover":return -27.0
	if id.begins_with("reward_reveal_"):return -23.0
	if id.begins_with("ambience") or id.begins_with("weather"):return -30.0
	if id.begins_with("step") or id=="gear_foley":return -27.0
	if id=="base_alert":return -16.0
	if id=="wall_crumble":return -21.0
	if banks[id].loop:return -26.0
	if id.begins_with("fire"):return -18.0 if id in ["fire_tank","fire_boss"] else -20.0
	if id.begins_with("hit"):return -23.0
	return -20.0
func spatial(player,source):
	player.position=get_viewport().get_visible_rect().size*.5
	var attenuation=0.0
	if source is Node3D and source.is_inside_tree():
		var camera=source.get_viewport().get_camera_3d()
		if is_instance_valid(camera):
			player.position=camera.unproject_position(source.global_position)
		var arena=source.get("arena")
		if is_instance_valid(arena) and is_instance_valid(arena.get("player")):
			attenuation=-minf(10.0,source.global_position.distance_to(arena.player.global_position)*.5)
	return attenuation
func make_player():
	var p=AudioStreamPlayer2D.new();p.bus="TankCityEffects";p.max_distance=1600;p.attenuation=0;p.panning_strength=.55;add_child(p)
	return p
## Mix (T-269, author: «звуки оружия потерялись»): up to MAX_VOICES at once; when full the oldest background voice
## goes first — the hero's own shots and interface sounds are kept. One event never stacks more than SAME_EVENT
## copies (a stream of hits no longer washes the guns out).
const MAX_VOICES:=40
const SAME_EVENT:=4
func play(event:String,source:Node,own:=false):
	if not Game.sound_enabled:return
	var id=ALIASES.get(event,event)
	if not banks.has(id):push_warning("Unknown audio event: "+id);return
	var key=id if id.begins_with("ui_") else id+":"+str(source.get_instance_id())
	var now=Time.get_ticks_msec()
	if now-int(cooldowns.get(key,-10000))<55:return
	cooldowns[key]=now
	if cooldowns.size()>2048:
		for old in cooldowns.keys():
			if now-cooldowns[old]>2000:cooldowns.erase(old)
	voices=voices.filter(is_instance_valid)
	var same=voices.filter(func(v):return v.get_meta("event","")==id)
	if same.size()>=SAME_EVENT:drop(same[0])
	if voices.size()>=MAX_VOICES:
		var background=voices.filter(func(v):return not v.get_meta("own",false) and not v.get_meta("ui",false))
		drop(background[0] if not background.is_empty() else voices[0])
	var p=make_player();p.stream=stream_for(id);p.volume_db=gain(id,own)+(0.0 if own else spatial(p,source))-(6.0 if event=="foliage_crack" else 0.0)
	if own:p.position=get_viewport().get_visible_rect().size*.5;p.panning_strength=.25
	p.set_meta("event",id);p.set_meta("own",own)
	p.set_meta("ui",id.begins_with("ui_") or id.begins_with("inv_") or id.begins_with("reward_reveal_") or id in ["ui_confirm","pickup","heal","repair","chest_open","rare_reveal","weapon_equip","reroll","extraction","defeat","route_select","route_enter","route_cancel","quest_ready","quest_claim","telegram_accept","base_level_up","weapon_tune","build_complete"]);p.pitch_scale=rng.randf_range(.88,1.12) if id=="wall_crumble" else rng.randf_range(1.35,1.6) if event=="foliage_crack" else rng.randf_range(.97,1.03);p.finished.connect(p.queue_free);p.play();voices.append(p)
	stats[id]=int(stats.get(id,0))+1
func drop(voice):
	voices.erase(voice)
	if is_instance_valid(voice):voice.queue_free()
func loop_event(id:String,source:Node,enabled:bool=true,pitch:float=1.0):
	var key=str(source.get_instance_id())+":"+id
	if not enabled or not Game.sound_enabled:
		if loops.has(key):
			if is_instance_valid(loops[key].player):loops[key].player.queue_free()
			loops.erase(key)
		return
	if not banks.has(id):return
	if not loops.has(key):
		if loops.size()>=12:return
		var p=make_player();p.stream=stream_for(id).duplicate()
		p.stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;p.stream.loop_begin=0;p.stream.loop_end=roundi(p.stream.get_length()*p.stream.mix_rate)
		loops[key]={"player":p,"owner":weakref(source),"id":id};p.play()
	var p=loops[key].player
	p.pitch_scale=pitch;p.volume_db=gain(id)+spatial(p,source)
func _process(_delta):
	for key in loops.keys():
		var entry=loops[key];var owner=entry.owner.get_ref()
		if not is_instance_valid(owner) or not owner.is_inside_tree() or not Game.sound_enabled:
			entry.player.queue_free();loops.erase(key)
		else:
			var arena=owner.get("arena")
			entry.player.stream_paused=get_tree().paused or (is_instance_valid(arena) and arena.get("phase") not in ["combat","countdown"])
	for p in voices:
		if is_instance_valid(p):p.stream_paused=get_tree().paused and not p.get_meta("ui",false)
	if not Game.sound_enabled:
		for p in voices:
			if is_instance_valid(p):p.stop();p.queue_free()
		voices.clear()
