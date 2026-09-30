extends Node
signal track_changed
var TRACKS={
	"hub":["break_quartet","break_samovar","break_night_shift"],
	"map":["break_dust_road","break_tailwind","break_landmark"],
	"battle":["break_azimuth","break_morse","break_nomad","break_dry_ice","break_kaleidoscope","break_square","break_mercury"],
	"miniboss":["break_highway","break_breakthrough","break_vice"],
	"boss":["break_storm","break_millstones","break_tsunami"],
	# Earlier chip tracks: kept playable from the radio, not picked automatically.
	"archive":["battle_signal","battle_mosaic","battle_patrol","battle_current","chill_background_loop","battle_variation_1","battle_variation_2","battle_muted_pulse","camp_lantern","camp_waltz","hub_evening_dial","hub_map_ambient_loop","hub_variation_1","hub_variation_2","hub_expedition_1","hub_expedition_2","route_compass","route_clouds","route_soft_beacon","map_expedition_1","map_expedition_2","map_expedition_3","map_expedition_4","commander_clock","commander_flank","miniboss_1","miniboss_2","boss_vector","boss_redoubt","boss_tense_1","boss_tense_2","boss_background_loop"]}
const PLAYLISTS=["hub","map","battle","miniboss","boss"]
const FANFARES=["greeting","start","victory","defeat"]
const FANFARE_NAMES={"greeting":"Приветствие","start":"Начало боя","victory":"Победа","defeat":"Поражение"}
const OLD_FANFARES=["hub_map_greeting","battle_greeting","wave_victory","boss_victory","expedition_greeting_1","expedition_greeting_2","expedition_greeting_3","expedition_greeting_4","expedition_greeting_5"]
## Chance that a context plays its theme version instead of a track from the shared pool.
const THEME_CHANCE=.7
var themes:Dictionary={}
var hub_theme=""  # held for the whole game session
var battle_theme=""  # picked again for every battle
const GREETINGS=["expedition_greeting_1","expedition_greeting_2","expedition_greeting_3","expedition_greeting_4","expedition_greeting_5"]
const NAMES={"boss_background_loop":"Осада","hub_map_ambient_loop":"Тихий лагерь","hub_variation_1":"У костра","hub_variation_2":"Утро","hub_expedition_1":"Передышка","hub_expedition_2":"Письма","chill_background_loop":"На рубеже","battle_variation_1":"Дозор","battle_variation_2":"Искры","map_expedition_1":"Тропа","map_expedition_2":"Перевал","map_expedition_3":"Дальний путь","map_expedition_4":"Горизонт","miniboss_1":"Командир","miniboss_2":"Манёвр","boss_tense_1":"Цитадель","boss_tense_2":"Последний рубеж"}
const CONTEXT_NAMES={"hub":"Хаб","map":"Карта","battle":"Бой","miniboss":"Командир","boss":"Босс","archive":"Архив"}
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
	if FileAccess.file_exists("res://assets/audio/music/themes.json"):
		var parsed=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/music/themes.json"))
		if parsed is Dictionary:themes=parsed
	pick_hub_theme()
	if AudioServer.get_bus_index("TankCityMusic")<0:AudioServer.add_bus();AudioServer.set_bus_name(AudioServer.bus_count-1,"TankCityMusic")
	for i in range(2):
		var player=AudioStreamPlayer.new();add_child(player);backgrounds.append(player);player.volume_db=-60;player.bus="TankCityMusic"
		player.finished.connect(func():if player==backgrounds[active]:track_finished())
	stinger=AudioStreamPlayer.new();add_child(stinger);stinger.volume_db=-6;stinger.bus="TankCityMusic"
	stinger.finished.connect(func():stinger_priority=0)
func theme_for(group:String)->String:return hub_theme if group in ["hub","map"] else battle_theme
func theme_track(group:String)->String:
	var entry=themes.get(theme_for(group),{})
	var id=str(entry.get("battle" if group=="battle" else group,""))
	return id if id!="" and int(ratings.get(id,0))>=0 else ""
## Theme version first, then the shared pool: used by the player arrows.
func pool(group:String)->Array:
	var result=[]
	var themed=theme_track(group)
	if themed!="":result.append(themed)
	for id in eligible(group):
		if id not in result:result.append(id)
	return result
## Day themes (folk) or night themes; "auto" follows the world time of day setting.
func mood()->String:
	var value=str(Settings.values.get("music_mood","auto"))
	if value=="auto":return "night" if str(Settings.values.get("world_lighting","day"))=="night" else "day"
	return value
func mood_themes()->Array:
	var wanted=mood()
	var result=themes.keys().filter(func(id):return str(themes[id].get("mood","day"))==wanted)
	return result if not result.is_empty() else themes.keys()
func pick_hub_theme():
	var options=mood_themes()
	if not options.is_empty():hub_theme=options[music_rng.randi_range(0,options.size()-1)]
func pick_battle_theme():
	if themes.is_empty():return
	var options=mood_themes().filter(func(id):return id!=battle_theme)
	battle_theme=options[music_rng.randi_range(0,options.size()-1)] if not options.is_empty() else mood_themes()[0]
func change(next:String,refresh:bool=false):
	if (next==context and not refresh) or next not in PLAYLISTS:return
	var changed=context!=next
	var previous=context
	# A new fight (from hub/map, or the next room) rolls a new theme; the commander keeps it.
	var new_fight=next in ["battle","boss"] and (refresh or previous in ["","hub","map"])
	if new_fight or battle_theme=="" or battle_theme not in mood_themes():pick_battle_theme()
	if hub_theme not in mood_themes():pick_hub_theme()
	context=next
	Game.sound_loop("ambience_hub",self,next=="hub")
	manual_tracks.erase(next)
	paused=false;repeat_mode=1
	var themed=theme_track(next)
	var pool_ids=eligible(next)
	if themed=="" and pool_ids.is_empty():
		for player in backgrounds:player.stop()
		current_track="";track_changed.emit();return
	var track=themed if themed!="" and (pool_ids.is_empty() or music_rng.randf()<THEME_CHANCE) else choose_variant(next,pool_ids)
	last_tracks[next]=track
	selections[next]+=1
	play_track(track)
	if changed and next=="hub":celebrate("hub_map_greeting",1)
	elif new_fight:celebrate("battle_greeting",1)
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
	var ids=pool(context)
	if ids.is_empty():return
	var index=posmod(ids.find(current_track)+direction,ids.size())
	if shuffle and direction>0:index=ids.find(choose_variant(context,ids))
	manual_tracks[context]=ids[index]
	play_track(ids[index])
func title()->String:return catalog.get(current_track,{}).get("title",NAMES.get(current_track,"Музыка"))
func subtitle()->String:
	if context not in TRACKS:return "Нет подборки"
	for theme in themes:
		if current_track in theme_tracks(theme):return "Тема «%s» · %s" % [themes[theme].title,CONTEXT_NAMES.get(track_group(theme,current_track),"")]
	var group=catalog.get(current_track,{}).get("context",context)
	if current_track not in TRACKS.get(group,[]):
		for candidate in TRACKS:
			if current_track in TRACKS[candidate]:group=candidate;break
	return "%s · %d / %d" % [CONTEXT_NAMES[group],TRACKS[group].find(current_track)+1,TRACKS[group].size()]
## Old event ids map onto the fanfares of the current theme.
func fanfare_for(id:String)->String:
	var kind={"hub_map_greeting":"greeting","battle_greeting":"start","wave_victory":"victory","boss_victory":"victory","defeat":"defeat"}.get(id,"")
	if kind=="":return id
	var theme=hub_theme if kind=="greeting" or (kind=="victory" and context in ["hub","map"]) else battle_theme
	var variants=themes.get(theme,{}).get(kind,[])
	if variants.is_empty():return choose_variant("greeting",GREETINGS) if id in ["hub_map_greeting","battle_greeting"] else ("" if id=="defeat" else id)
	return choose_variant("fanfare_"+kind,variants)
func theme_tracks(theme:String)->Array:
	var entry=themes.get(theme,{})
	var result=[]
	for group in ["battle","hub","map","miniboss","boss"]:
		if entry.has(group):result.append(entry[group])
	return result
func track_group(theme:String,id:String)->String:
	for group in ["battle","hub","map","miniboss","boss"]:
		if themes[theme].get(group,"")==id:return group
	return ""
func preview_fanfare(id:String):
	if not Game.sound_enabled:return
	stinger.stop();stinger_priority=1;stinger.stream=load("res://assets/audio/music/"+id+".wav");stinger.play()
func celebrate(id:String,priority:int):
	if not Game.sound_enabled:return
	if stinger.playing and priority<stinger_priority:return
	id=fanfare_for(id)
	if id=="":return
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
	if repeat_mode==0 and pool(context).find(current_track)==pool(context).size()-1:paused=true;track_changed.emit();return
	skip(1)

func refresh_library():
	for filename in DirAccess.get_files_at("res://assets/audio/music"):
		# Exported packs list imported audio as *.wav.import.
		filename=filename.trim_suffix(".import")
		if not filename.ends_with(".wav"):continue
		var id=filename.trim_suffix(".wav")
		if "greeting" in id or "victory" in id or "defeat" in id or id.begins_with("folk_") or id.begins_with("night_"):continue
		var known=false
		for theme in themes:
			if id in theme_tracks(theme):known=true
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
## Durations come from a generated index, so the radio never loads WAVs just to show a length.
var lengths:Dictionary={}
func track_length(id:String)->float:
	if lengths.is_empty() and FileAccess.file_exists("res://assets/audio/music/durations.json"):
		var parsed=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/music/durations.json"))
		if parsed is Dictionary:lengths=parsed
	if not lengths.has(id) and ResourceLoader.has_cached(track_path(id)):lengths[id]=load(track_path(id)).get_length()
	return float(lengths.get(id,0.0))
func duration()->float:
	return backgrounds[active].stream.get_length() if backgrounds[active].stream!=null else 0.0
func position_seconds()->float:return backgrounds[active].get_playback_position()
func seek(seconds:float):
	if backgrounds[active].stream!=null:backgrounds[active].seek(clampf(seconds,0,maxf(0,duration()-.05)))
