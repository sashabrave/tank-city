extends Node
var failures=0
var checks=0
var capture=false
var current
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures+=1;push_error("FAIL "+message)
	else:print("PASS "+message)
func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	capture="--capture" in OS.get_cmdline_user_args()
	call_deferred("run")
func shot(id:String):
	if not capture:return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://audio_demo/chapter2/"+id+".png")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=true
	Game.music_context("hub")
	var c=Game.music_controller
	for context in c.TRACKS:
		for track in c.TRACKS[context]:check(ResourceLoader.exists("res://assets/audio/music/"+track+".wav"),"track exists "+track)
	check(c.TRACKS.archive.has("battle_signal") and not c.TRACKS.battle.has("battle_signal"),"old tracks live in the archive")
	c.shuffle=false  # arrows walk the list in order
	for context in c.PLAYLISTS:
		c.change(context)
		var ids=c.pool(context)
		check(not ids.is_empty(),"playlist has tracks "+context)
		c.play_track(ids[0])
		var original=c.current_track
		c.skip(-1);check(c.current_track==ids[-1],"previous wraps "+context)
		c.skip(1);check(c.current_track==original,"next wraps "+context)
	# Themes: hub/map theme is held for the session, battle theme rolls per fight.
	check(c.themes.size()==6,"six music themes")
	for theme in c.themes:
		for key in ["battle","hub","map","miniboss","boss"]:check(ResourceLoader.exists("res://assets/audio/music/"+c.themes[theme][key]+".wav"),"theme track "+theme+" "+key)
		for kind in c.FANFARES:check(c.themes[theme][kind].size()==3,"three fanfares "+theme+" "+kind)
	var held=c.hub_theme
	var seen={}
	for i in range(12):
		c.change("map");c.change("battle")
		check(c.hub_theme==held,"hub theme held")
		seen[c.battle_theme]=true
		check(c.fanfare_for("battle_greeting") in c.themes[c.battle_theme].start,"battle start fanfare follows battle theme")
		check(c.fanfare_for("defeat") in c.themes[c.battle_theme].defeat,"defeat fanfare follows battle theme")
	check(seen.size()>=3,"battle theme changes between fights")
	var fight=c.battle_theme;c.change("miniboss");check(c.battle_theme==fight,"commander keeps the fight theme")
	check(c.current_track in c.pool("miniboss"),"commander track from theme or pool")
	c.change("hub");check(c.fanfare_for("hub_map_greeting") in c.themes[held].greeting,"greeting follows hub theme")
	c.shuffle=true
	for i in range(20):c.skip(1)
	await get_tree().create_timer(.8).timeout
	check(c.backgrounds.filter(func(p):return p.playing).size()==1,"rapid switching leaves only one deck")
	var ui=preload("res://scenes/ui/music_mini_player.tscn").instantiate();add_child(ui);ui.size=Vector2(840,70)
	get_tree().paused=true
	var before=c.current_track;ui.row_node.get_node("Next").pressed.emit()
	await get_tree().create_timer(.8).timeout
	check(c.current_track!=before and c.backgrounds[c.active].playing,"track changes during pause")
	check(ui.row_node.get_node("Info/Title").text==c.title(),"visible title updates")
	check(not c.stinger.playing or c.stinger_priority<=1,"switch does not create victory stinger")
	get_tree().paused=false;ui.queue_free()
	var audio=Game.audio()
	check(audio.banks.size()>=109,"all SFX banks")
	for id in ["countdown_tick","commander_arrive","route_select","route_enter","route_cancel","quest_ready","quest_claim","telegram_accept","base_level_up","weapon_tune","build_complete","trench_enter","trench_exit","trench_hide","armor_recover","low_health","enemy_surprise"]:
		check(audio.banks.has(id) and audio.stream_for(id).get_length()>0,"new event "+id)
	var observer=audio.get_child(0);observer.sample_progression()
	Game.progression.level+=1;observer.sample_progression()
	check(audio.stats.get("base_level_up",0)>0,"base level sound transition")
	Game.progression.claimed.append("audio_test");observer.sample_progression()
	check(audio.stats.get("quest_claim",0)>0,"quest reward sound transition")
	var main=load("res://scenes/main.tscn").instantiate();add_child(main)
	await get_tree().process_frame;await get_tree().process_frame
	Settings.open();await shot("player_hub")
	var widget=Settings.menu.find_child("MusicMiniPlayer",true,false)
	check(is_instance_valid(widget),"hub settings player exists")
	check(widget.get_global_rect().end.y<Settings.menu.get_viewport().get_visible_rect().size.y,"hub player fits viewport")
	Settings.close()
	main.show_map(0);await get_tree().process_frame
	check(c.context=="map","map uses own music context")
	main.current.show_pause();await shot("player_map")
	await get_tree().process_frame
	# Pause opens the field tablet; its radio tab hosts the mini player.
	check(not get_tree().get_nodes_in_group("field_tablet").is_empty(),"map pause opens the tablet")
	for tablet in get_tree().get_nodes_in_group("field_tablet"):tablet.queue_free()
	await get_tree().process_frame;get_tree().paused=false
	main.current.resume_map();main.enter_room(0);await get_tree().process_frame
	var arena=main.run_arena;current=arena;arena.auto_pause_enabled=false;arena.phase="countdown"
	arena.room.commander_countdown=true;arena.countdown=3
	observer.timer=0;observer._process(.1)
	check(audio.stats.get("countdown_tick",0)>0,"commander countdown cue")
	arena.room.commander_countdown=false;arena.phase="combat";observer.timer=0;observer._process(.1)
	check(audio.stats.get("commander_arrive",0)>0,"commander arrival cue")
	var actor_sound=arena.player.get_children().filter(func(n):return n.get_script()==load("res://scripts/actor_audio.gd"))[0]
	arena.player.occupying_trench=true;actor_sound._physics_process(.1)
	check(audio.stats.get("trench_enter",0)>0,"trench entry cue")
	arena.player.hidden_in_trench=true;actor_sound._physics_process(.1)
	check(audio.stats.get("trench_hide",0)>0,"trench hide cue")
	arena.player.occupying_trench=false;arena.player.hidden_in_trench=false;actor_sound._physics_process(.1)
	check(audio.stats.get("trench_exit",0)>0,"trench exit cue")
	arena.pause_battle()
	if capture:await get_tree().create_timer(3).timeout
	await shot("player_battle")
	await get_tree().process_frame
	var tablets=get_tree().get_nodes_in_group("field_tablet")
	check(not tablets.is_empty(),"battle pause opens the tablet")
	if not tablets.is_empty():
		var view=tablets[0].get_child(0);view.tab="music";view.refresh();await get_tree().process_frame
		check(tablets[0].find_child("MusicMiniPlayer",true,false)!=null,"battle pause radio has the player")
	main.queue_free();await get_tree().process_frame
	print("MUSIC_PLAYER_V2: ",checks," checks; ",failures," failures");get_tree().quit(failures)
