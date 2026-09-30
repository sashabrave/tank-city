extends Node
signal track_changed
var TRACKS={
	"hub":["camp_lantern","camp_waltz","hub_map_ambient_loop","hub_variation_1","hub_variation_2","hub_expedition_1","hub_expedition_2"],
	"map":["route_compass","route_clouds","hub_expedition_1","hub_expedition_2"],
	"battle":["battle_patrol","battle_mosaic","battle_current","battle_signal","chill_background_loop","battle_variation_1","battle_variation_2","map_expedition_1","map_expedition_2","map_expedition_3","map_expedition_4"],
	"miniboss":["commander_clock","commander_flank","miniboss_1","miniboss_2"],
	"boss":["boss_vector","boss_redoubt","boss_tense_1","boss_tense_2"]}
const GREETINGS=["expedition_greeting_1","expedition_greeting_2","expedition_greeting_3","expedition_greeting_4","expedition_greeting_5"]
const NAMES={"hub_map_ambient_loop":"Тихий лагерь","hub_variation_1":"У костра","hub_variation_2":"Утро","hub_expedition_1":"Передышка","hub_expedition_2":"Письма","chill_background_loop":"На рубеже","battle_variation_1":"Дозор","battle_variation_2":"Искры","map_expedition_1":"Тропа","map_expedition_2":"Перевал","map_expedition_3":"Дальний путь","map_expedition_4":"Горизонт","miniboss_1":"Командир","miniboss_2":"Манёвр","boss_tense_1":"Цитадель","boss_tense_2":"Последний рубеж"}
const CONTEXT_NAMES={"hub":"Хаб","map":"Карта","battle":"Бой","miniboss":"Командир","boss":"Босс"}
var backgrounds:Array[AudioStreamPlayer]=[]
var active=0
var paused=false
var repeat_mode=2 # 0: stop at end, 1: current track, 2: playlist
var shuffle=true
var enabled_before=true
var context=""
var current_track=""
var duck=0.0
var fade:Tween
var stinger:AudioStreamPlayer
var stinger_priority=0
var selections={"hub":0,"map":0,"battle":0,"boss":0,"miniboss":0}
var last_tracks={}
var manual_tracks={}
var catalog:Dictionary={}
var ratings:Dictionary={}
var browser_folder="all"
var browser_scroll=0
var preferences_path="user://music_preferences.json"
var music_rng=RandomNumberGenerator.new()
func choose_variant(key:String,pool:Array)->String:
	var options=pool.filter(func(id):return id!=last_tracks.get(key,""))
	var result=options[music_rng.randi_range(0,options.size()-1)] if not options.is_empty() else pool[0]
	last_tracks[key]=result;return result
func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	music_rng.randomize()
	refresh_library()
	if FileAccess.file_exists(preferences_path):
		var saved=JSON.parse_string(FileAccess.get_file_as_string(preferences_path))
		if saved is Dictionary:ratings=saved
	catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/music/chapter2_catalog.json"))
	if AudioServer.get_bus_index("TankCityMusic")<0:AudioServer.add_bus();AudioServer.set_bus_name(AudioServer.bus_count-1,"TankCityMusic")
	for i in range(2):
		var player=AudioStreamPlayer.new();add_child(player);backgrounds.append(player);player.volume_db=-60;player.bus="TankCityMusic"
		player.finished.connect(func():if player==backgrounds[active]:track_finished())
	stinger=AudioStreamPlayer.new();add_child(stinger);stinger.volume_db=-6;stinger.bus="TankCityMusic"
	stinger.finished.connect(func():stinger_priority=0)
func change(next:String,refresh:bool=false):
	if (next==context and not refresh) or next not in TRACKS:return
	var changed=context!=next
	context=next
	Game.sound_loop("ambience_hub",self,next=="hub")
	manual_tracks.erase(next)
	paused=false;repeat_mode=1
	var pool=eligible(next)
	if pool.is_empty():
		for player in backgrounds:player.stop()
		current_track="";track_changed.emit();return
	var track=choose_variant(next,pool)
	selections[next]+=1
	play_track(track)
	if changed:
		if next=="hub":celebrate("hub_map_greeting",1)
		elif next=="battle":celebrate("battle_greeting",1)
## Tracks are large WAV files: they load on a background thread and start once ready, so a context
## change never blocks the frame. The loaded resource is shared; looping is always disabled on it.
var pending_track=""
static func track_path(track:String)->String:return "res://assets/audio/music/"+track+".wav"
func play_track(track:String):
	current_track=track;last_tracks[context]=track
	var path=track_path(track)
	if ResourceLoader.has_cached(path):
		pending_track="";start_track(track,load(path));return
	pending_track=track
	if ResourceLoader.load_threaded_get_status(path)==ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:ResourceLoader.load_threaded_request(path)
	track_changed.emit()
func poll_pending():
	if pending_track=="":return
	var path=track_path(pending_track)
	match ResourceLoader.load_threaded_get_status(path):
		ResourceLoader.THREAD_LOAD_LOADED:
			var track=pending_track;pending_track=""
			if track==current_track:start_track(track,ResourceLoader.load_threaded_get(path))
		ResourceLoader.THREAD_LOAD_FAILED,ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_warning("Music track failed to load: "+pending_track);pending_track=""
func start_track(track:String,stream:AudioStream):
	if is_instance_valid(fade):fade.kill()
	var old=backgrounds[active];active=1-active;var player=backgrounds[active]
	player.stop();player.stream=stream
	if player.stream is AudioStreamWAV:
		player.stream.loop_mode=AudioStreamWAV.LOOP_DISABLED;player.stream.loop_begin=0;player.stream.loop_end=roundi(player.stream.get_length()*player.stream.mix_rate)
	player.volume_db=-60
	if Game.sound_enabled:player.play();player.stream_paused=paused
	fade=create_tween().set_parallel(true);fade.tween_property(old,"volume_db",-60,.65);fade.tween_property(player,"volume_db",-6,.65)
	fade.chain().tween_callback(old.stop)
	track_changed.emit()
func skip(direction:int):
	if context not in TRACKS:return
	var pool=eligible(context) if shuffle else TRACKS[context]
	if pool.is_empty():return
	var index=posmod(pool.find(current_track)+direction,pool.size())
	if shuffle and direction>0:index=pool.find(choose_variant(context,pool))
	manual_tracks[context]=pool[index]
	play_track(pool[index])
func title()->String:return catalog.get(current_track,{}).get("title",NAMES.get(current_track,"Музыка"))
func subtitle()->String:
	if context not in TRACKS:return "Нет подборки"
	var group=catalog.get(current_track,{}).get("context",context)
	if current_track not in TRACKS.get(group,[]):
		for candidate in TRACKS:
			if current_track in TRACKS[candidate]:group=candidate;break
	return "%s · %d / %d" % [CONTEXT_NAMES[group],TRACKS[group].find(current_track)+1,TRACKS[group].size()]
func celebrate(id:String,priority:int):
	if not Game.sound_enabled:return
	if stinger.playing and priority<stinger_priority:return
	if id in ["hub_map_greeting","battle_greeting"]:id=choose_variant("greeting",GREETINGS)
	stinger.stop();stinger_priority=priority;stinger.stream=load("res://assets/audio/music/"+id+".wav");stinger.play()
func _process(delta):
	poll_pending()
	if not Game.sound_enabled:
		for player in backgrounds:player.stop()
		stinger.stop();enabled_before=false;return
	if not enabled_before and context!="":backgrounds[active].play();backgrounds[active].stream_paused=paused
	enabled_before=true
	var bus=AudioServer.get_bus_index("TankCityMusic")
	duck=lerpf(duck,-3.0 if stinger.playing else 0.0,minf(1,delta*5))
	if bus>=0:AudioServer.set_bus_volume_db(bus,linear_to_db(maxf(.0001,Settings.values.music))+duck)

func toggle_play():
	paused=not paused
	if not paused and not backgrounds[active].playing:backgrounds[active].play()
	for player in backgrounds:player.stream_paused=paused
	track_changed.emit()
func cycle_repeat():
	repeat_mode=(repeat_mode+1)%3;track_changed.emit()
func toggle_shuffle():
	shuffle=not shuffle;track_changed.emit()
func track_finished():
	if repeat_mode==1:backgrounds[active].play();return
	if repeat_mode==0 and TRACKS[context].find(current_track)==TRACKS[context].size()-1:paused=true;track_changed.emit();return
	skip(1)

func refresh_library():
	for filename in DirAccess.get_files_at("res://assets/audio/music"):
		if not filename.ends_with(".wav"):continue
		var id=filename.trim_suffix(".wav")
		if "greeting" in id or "victory" in id or "defeat" in id:continue
		var known=false
		for group in TRACKS:
			if id in TRACKS[group]:known=true
		if known:continue
		var group=""
		for prefix in [["hub","hub"],["camp","hub"],["map","map"],["route","map"],["battle","battle"],["miniboss","miniboss"],["commander","miniboss"],["boss","boss"]]:
			if id.begins_with(prefix[0]):group=prefix[1];break
		if group!="":TRACKS[group].append(id)
func eligible(group:String)->Array:return TRACKS.get(group,[]).filter(func(id):return int(ratings.get(id,0))>=0)
func rate(id:String,value:int):
	ratings[id]=0 if int(ratings.get(id,0))==value else value
	var file=FileAccess.open(preferences_path,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify(ratings))
	track_changed.emit()
func duration()->float:
	return backgrounds[active].stream.get_length() if backgrounds[active].stream!=null else 0.0
func position_seconds()->float:return backgrounds[active].get_playback_position()
func seek(seconds:float):
	if backgrounds[active].stream!=null:backgrounds[active].seek(clampf(seconds,0,maxf(0,duration()-.05)))
