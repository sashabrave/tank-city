extends Node
# «Шкаф → Модель игрока»: every listed cat mesh loads with the v6 rig and clips, only the player wears it,
# the choice survives a profile round trip, unknown ids fall back to v6, the wardrobe tab selects it.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades()
	var stage=Node3D.new();add_child(stage)
	check(Game.player_model==PlayerModels.DEFAULT,"default player model is v6")
	for id in PlayerModels.MODELS:
		check(PlayerModels.valid(id),"model file exists: "+id)
		Game.player_model=id
		var m=Visuals.model("soldier",stage,Vector3.ZERO,"cat",true)
		check(m.get_child(0).scene_file_path==PlayerModels.MODELS[id].path,"player soldier uses "+id)
		check(m.skeleton!=null and m.skeleton.find_bone("hand.L")>=0 and m.skeleton.find_bone("tail.001")>=0,"v6 bones on "+id)
		for clip in ["hero_idle","hero_walk","hero_run_free","hero_fire","hero_hit","hero_death"]:
			check(m.player.has_animation(clip),id+" has "+clip)
		m.equip_weapon("rifle")
		check(m.weapon_socket!=null and m.find_child("Flashlight",true,false)!=null,"weapon socket and lamp on "+id)
		var other=Visuals.model("soldier",stage,Vector3(2,0,0))
		check(other.get_child(0).scene_file_path.ends_with("infantry_v6/soldier.glb"),"non-player cats stay v6 while "+id+" is chosen")
		m.queue_free();other.queue_free()
	await get_tree().process_frame
	Game.player_model="hunyuan"
	var profile=Game.serialize_progress()
	check(profile.get("player_model")=="hunyuan","profile stores the model")
	Game.reset_upgrades();check(Game.player_model==PlayerModels.DEFAULT,"reset returns to v6")
	Game.apply_profile(profile);check(Game.player_model=="hunyuan","profile restores the model")
	profile.player_model="nope";Game.apply_profile(profile);check(Game.player_model==PlayerModels.DEFAULT,"unknown model falls back to v6")
	var wardrobe=preload("res://scripts/ui/stations/wardrobe_station.gd").new()
	check(wardrobe.tabs().any(func(t):return t[0]=="model"),"wardrobe has the model tab")
	check(wardrobe.items("model").size()==PlayerModels.MODELS.size(),"wardrobe lists every model")
	check(wardrobe.act("model","v8","use")!="" and Game.player_model=="v8","wardrobe selects a model")
	check(not wardrobe.detail("model","v8").actions[0].enabled,"selected model cannot be selected again")
	Game.player_model=PlayerModels.DEFAULT
	print("PLAYER MODELS %s: %d failures" % ["PASS" if failures==0 else "FAIL",failures])
	get_tree().quit(1 if failures else 0)
