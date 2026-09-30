extends Node
var checks=0
var failures=0
func check(ok,message):
	checks+=1
	if not ok:failures+=1;push_error(message)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=true
	var music=load("res://scripts/music_controller.gd").new();add_child(music)
	for context in music.TRACKS:
		var previous=""
		for i in range(15):
			var chosen=music.choose_variant(context,music.TRACKS[context]);check(chosen!=previous,"no immediate repeat "+context);previous=chosen
		for id in music.TRACKS[context]:
			var stream=load("res://assets/audio/music/"+id+".wav")
			check(stream is AudioStreamWAV and stream.get_length()>25,"valid loop "+id)
	for id in music.GREETINGS:
		var stream=load("res://assets/audio/music/"+id+".wav");check(stream.get_length()>2 and stream.get_length()<5,"short greeting")
	music.change("battle");var first=music.backgrounds[music.active].stream.resource_path
	var count=music.selections.battle;music.change("battle");check(music.selections.battle==count,"same context stays playing")
	music.change("battle",true);check(music.selections.battle==count+1,"next room refreshes track")
	music.change("miniboss");check(music.context=="miniboss" and music.TRACKS.miniboss.size()>=2,"dedicated miniboss pool")
	music.change("boss");check(music.context=="boss","major boss music")
	music.celebrate("battle_greeting",3);check(music.GREETINGS.has(music.last_tracks.greeting),"greeting alias uses new variants")
	Game.sound_enabled=false;music.queue_free()
	print("MUSIC EXPANSION: %d checks, %d failures" % [checks,failures]);get_tree().quit(failures)
