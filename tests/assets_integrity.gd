extends Node3D
## Everything the game ships loads (merged from chip_audio, music_player_v2, infantry_v6_revision,
## vehicles_v6_revision, player_models_revision, music_expansion): scenes, data JSON, every SFX variation, every music track and
## theme, infantry cats and dogs (rig, clips, lamp, budget, palette), player models, vehicles (node contract).
var failures=0
func check(ok,message):
	if not ok:failures+=1;print("FAIL ",message)
func files_in(dir:String,ext:String)->Array:
	var out=[];var d=DirAccess.open(dir)
	if d==null:return out
	for f in d.get_files():
		f=f.trim_suffix(".remap")
		if f.ends_with(ext):out.append(dir.path_join(f))
	for sub in d.get_directories():out.append_array(files_in(dir.path_join(sub),ext))
	return out
func body_triangles(root:Node)->int:
	var tris=0
	for mesh in root.find_children("*","MeshInstance3D",true,false):
		if not str(mesh.name).ends_with("_body"):continue  # weapon and shield panel are counted separately
		for i in range(mesh.mesh.get_surface_count()):tris+=mesh.mesh.surface_get_arrays(i)[Mesh.ARRAY_INDEX].size()/3
	return tris
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=true
	# Scenes and data.
	var scenes=files_in("res://scenes",".tscn")
	check(scenes.size()>=20,"scenes found (%d)" % scenes.size())
	for path in scenes:check(load(path) is PackedScene,"scene loads: "+path)
	for path in files_in("res://data",".json"):
		check(JSON.parse_string(FileAccess.get_file_as_string(path))!=null,"data parses: "+path)
	# SFX: every manifest variation is a non-empty WAV (chip_audio).
	var audio=Game.audio();var files=0
	check(audio.banks.size()>=109,"all audio banks load (%d)" % audio.banks.size())
	for id in audio.banks:
		for file in audio.banks[id].files:
			var stream=load(audio.ROOT+file)
			check(stream is AudioStreamWAV and stream.get_length()>0,"sound file: "+file);files+=1
	check(files>=253,"every manifest variation loads (%d)" % files)
	# Music: every playlist track and every theme track exists, three fanfares each (music_player_v2).
	Game.music_context("hub");var c=Game.music_controller
	# Playlist loops are real Ogg streams longer than 25 s; fanfares are short (2–6 s) (music_expansion).
	for context in c.TRACKS:
		for track in c.TRACKS[context]:
			var stream=load("res://assets/audio/music/"+track+".ogg")
			check(stream is AudioStreamOggVorbis and stream.get_length()>25,"music loop "+track)
	check(c.themes.size()==12,"twelve music themes")
	for theme in c.themes:
		for key in ["battle","hub","map","miniboss","boss"]:check(ResourceLoader.exists("res://assets/audio/music/"+c.themes[theme][key]+".ogg"),"theme track "+theme+" "+key)
		for kind in c.FANFARES:
			check(c.themes[theme][kind].size()==3,"three fanfares "+theme+" "+kind)
			for id in c.themes[theme][kind]:
				var fanfare=load("res://assets/audio/music/"+id+".ogg")
				check(fanfare!=null and fanfare.get_length()>2 and fanfare.get_length()<6,"short fanfare "+id)
	Game.sound_enabled=false
	# Infantry v6: runtime palette = Blender palette; cats and dogs share the rig, clips, lamp and budget.
	var stage=Node3D.new();add_child(stage)
	var exported=JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/infantry_v6/palette.json"))
	check(exported!=null and exported.names==InfantryPalette.NAMES and exported.colors==InfantryPalette.COLORS,"infantry palette.json matches InfantryPalette")
	for kind in Visuals.INFANTRY:
		for species in ["cat","dog"]:
			var m=Visuals.model(kind,stage,Vector3.ZERO,species)
			m.equip_weapon("rpg" if kind=="rpg_soldier" else EnemyLoadouts.default_for(kind))
			var glb=("infantry_v6/%s.glb" % kind) if species=="cat" else ("infantry_v6/dog_%s.glb" % kind)
			check(m.get_child(0).scene_file_path.ends_with(glb),"%s %s model file" % [species,kind])
			check(m.skeleton!=null and m.skeleton.find_bone("tail.001")>=0 and m.find_child("Flashlight",true,false)!=null,"%s %s rig and lamp" % [species,kind])
			for clip in ["hero_idle","hero_walk","hero_fire","hero_hit","hero_death"]:check(m.player.has_animation(clip),"%s %s clip %s" % [species,kind,clip])
			var limit=2100 if kind=="soldier" else 2400
			check(body_triangles(m.get_child(0))<=limit,"%s %s triangle budget" % [species,kind])
			m.free()
	# Player models from the wardrobe load with the v6 rig and clips.
	var keep=Game.player_model
	for id in PlayerModels.MODELS:
		check(PlayerModels.valid(id),"player model file exists: "+id)
		Game.player_model=id
		var m=Visuals.model("soldier",stage,Vector3.ZERO,"cat",true)
		check(m.get_child(0).scene_file_path==PlayerModels.MODELS[id].path and m.skeleton!=null and m.skeleton.find_bone("hand.L")>=0,"player model rig: "+id)
		for clip in ["hero_idle","hero_walk","hero_run_free","hero_fire","hero_hit","hero_death"]:check(m.player.has_animation(clip),id+" has "+clip)
		m.free()
	Game.player_model=keep
	# Vehicles v6: node contract of kit_model, team paint, metal, lamps, beacons.
	var expect={"tank":[1,1,0,0],"apc":[1,1,6,0],"buggy":[1,1,4,0],"drone":[0,0,4,0],"flyer":[1,1,0,4],"boss":[3,3,0,0]}
	check(expect.size()==Visuals.VEHICLES.size(),"every vehicle kind is covered")
	for kind in Visuals.VEHICLES:
		var m=Visuals.model(kind,stage,Vector3.ZERO)
		check(m.get_child(0).scene_file_path.ends_with("vehicles_v6/"+kind+".glb"),kind+" model file")
		var e=expect.get(kind,[-1,-1,-1,-1])
		check(m.yaws.size()==e[0] and m.pitches.size()==e[1] and m.wheels.size()==e[2] and m.rotors.size()==e[3] and m.recoils.size()>=e[1],"%s node contract %s" % [kind,[m.yaws.size(),m.pitches.size(),m.wheels.size(),m.rotors.size()]])
		if kind!="drone":check(m.paint_materials.size()>=1,kind+" team paint surface")
		var metal=m.find_children("*","MeshInstance3D",true,false).any(func(mesh):return range(mesh.mesh.get_surface_count()).any(func(i):return mesh.mesh.surface_get_material(i)!=null and mesh.mesh.surface_get_material(i).resource_name=="V6_metal"))
		check(metal,kind+" metal surface")
		if kind in ["drone","flyer"]:check(m.beacons.size()==1,kind+" beacon")
		if kind in ["tank","apc","buggy"]:check(m.find_children("*","SpotLight3D",true,false).size()==2,kind+" head lamps")
		m.free()
	stage.queue_free();await get_tree().process_frame
	print("ASSETS INTEGRITY: %d scenes, %d sounds, %d failures" % [scenes.size(),files,failures])
	get_tree().quit(1 if failures else 0)
