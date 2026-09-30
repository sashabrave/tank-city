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
		c.change(context)
		c.play_track(c.TRACKS[context][0])
		var original=c.current_track
		c.skip(-1);check(c.current_track==c.TRACKS[context][-1],"previous wraps "+context)
		c.skip(1);check(c.current_track==original,"next wraps "+context)
		c.skip(1);var manual=c.current_track
		c.change("boss" if context!="boss" else "hub");c.change(context,true)
		check(c.current_track==manual,"manual choice retained "+context)
	for i in range(20):c.skip(1)
	await get_tree().create_timer(.8).timeout
	check(c.backgrounds.filter(func(p):return p.playing).size()==1,"rapid switching leaves only one deck")
	var ui=preload("res://scenes/ui/music_mini_player.tscn").instantiate();add_child(ui);ui.size=Vector2(840,70)
	get_tree().paused=true
	var before=c.current_track;ui.get_node("Row/Next").pressed.emit()
	await get_tree().create_timer(.8).timeout
	check(c.current_track!=before and c.backgrounds[c.active].playing,"track changes during pause")
	check(ui.get_node("Row/Info/Title").text==c.title(),"visible title updates")
	check(not c.stinger.playing or c.stinger_priority<=1,"switch does not create victory stinger")
	get_tree().paused=false;ui.queue_free()
	var audio=Game.audio()
	check(audio.banks.size()==98,"98 total SFX banks")
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
	check(main.current.modal.find_child("MusicMiniPlayer",true,false)!=null,"map pause player exists")
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
	check(arena.hud.modal.find_child("MusicMiniPlayer",true,false)!=null,"battle pause player exists")
	var panel=arena.hud.modal.get_node("Panel");var player=panel.get_node("MusicMiniPlayer")
	check(player.position.y+player.size.y<=panel.get_node("ResumeButton").position.y,"player does not overlap resume")
	check(panel.get_global_rect().position.y>=0 and panel.get_global_rect().end.y<=get_viewport().get_visible_rect().size.y,"battle pause fits screen")
	main.queue_free();await get_tree().process_frame
	print("MUSIC_PLAYER_V2: ",checks," checks; ",failures," failures");get_tree().quit(failures)
