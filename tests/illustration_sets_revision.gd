extends Control
## Illustration sets: both sets cover every managed path with equal sizes, icons are unique inside a set,
## the setting resolves paths, and a live switch swaps pictures already on screen. Saves stay disabled.
var errors=0
func check(value:bool,message:String):
	if value:print("PASS ",message)
	else:errors+=1;push_error("FAIL: "+message)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false
	var before=Settings.values.get("illustration_set","")
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/illustrations/manifest.json"))
	check(manifest!=null,"manifest readable")
	var hashes={}
	for set_id in Illustrations.SETS:
		hashes[set_id]={}
		for group in ["upgrades","stats","abilities","headquarters","garage"]:
			for file in DirAccess.get_files_at("res://assets/illustrations/"+set_id+"/icons/"+group):
				if not file.ends_with(".png"):continue
				var other=Illustrations.SETS[1-Illustrations.SETS.find(set_id)]
				check(ResourceLoader.exists("res://assets/illustrations/"+other+"/icons/"+group+"/"+file),"%s/%s in both sets" % [group,file])
				hashes[set_id][FileAccess.get_md5("res://assets/illustrations/"+set_id+"/icons/"+group+"/"+file)]=true
		check(hashes[set_id].size()==82,"%s: 82 unique icons (%d)" % [set_id,hashes[set_id].size()])
	for atlas in ["portraits/v16/portraits.png","portraits/v16/miniatures.png","ui/enemies/enemy_atlas_v1.png","ui/workshops/atlas.png"]:
		var a=load("res://assets/illustrations/gpt_image_2_5/"+atlas);var b=load("res://assets/illustrations/nano_banana/"+atlas)
		check(a!=null and b!=null and a.get_size()==b.get_size(),"atlas sizes match: "+atlas)
	Settings.values["illustration_set"]="gpt_image_2_5"
	check(Illustrations.path("res://assets/icons/upgrades/crit_damage.png").contains("/gpt_image_2_5/"),"gpt path")
	check(Illustrations.path("res://assets/icons/v1/star.png")=="res://assets/icons/v1/star.png","shared art passes through")
	check(UiKit.icon_texture("abilities/field_repair").resource_path!=UiKit.icon_texture("upgrades/field_repair").resource_path and UiKit.icon_texture("stats/field_repair").resource_path!=UiKit.icon_texture("upgrades/field_repair").resource_path,"three field_repair pictures")
	var garage={}
	for v in ["buggy","apc","tank"]:
		for branch in ["armor","gun","loader"]:garage[UiKit.icon_texture("garage/%s_%s" % [v,branch]).resource_path]=true
	check(garage.size()==9,"nine garage branches")
	# Live switch: a picture and a portrait already on screen follow the setting.
	var icon=TextureRect.new();add_child(icon);icon.texture=UiKit.icon_texture("upgrades/crit_damage")
	var portrait=TextureRect.new();add_child(portrait);portrait.texture=preload("res://scripts/ui/class_gallery.gd").texture("recruit")
	Settings.change("illustration_set","nano_banana")
	check(icon.texture.resource_path.contains("/nano_banana/") and portrait.texture.atlas.resource_path.contains("/nano_banana/"),"live switch to Nano Banana")
	check(preload("res://scripts/ui/enemy_type_icon.gd").atlas().resource_path.contains("/nano_banana/"),"wave atlas follows")
	Settings.change("illustration_set","gpt_image_2_5")
	check(icon.texture.resource_path.contains("/gpt_image_2_5/") and portrait.texture.atlas.resource_path.contains("/gpt_image_2_5/"),"live switch back to GPT")
	Settings.values["illustration_set"]="bogus"
	check(Illustrations.current()==Illustrations.DEFAULT,"unknown value falls back to default")
	Settings.values["illustration_set"]=before if before!="" else Illustrations.DEFAULT
	print("ILLUSTRATION SETS: %d failures" % errors)
	get_tree().quit(errors)
