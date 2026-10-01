class_name Illustrations
extends RefCounted
## Two interchangeable illustration sets (assets/illustrations/<set>/…, same relative paths and sizes):
## unique card/stat/ability/HQ/garage icons, class portraits and miniatures, the enemy wave atlas and the
## workshop atlas. Callers keep asking for the classic path ("res://assets/icons/upgrades/x.png",
## "res://assets/portraits/v16/portraits.png"…); path() points it at the chosen set. Shared art (items,
## weapons, hearts, guide, logo) is not part of a set and passes through unchanged.
const SETS=["gpt_image_2_5","nano_banana"]
const NAMES=["GPT","Nano Banana"]
const DEFAULT="gpt_image_2_5"
const ROOT="res://assets/illustrations/"
const PREFIXES=["icons/upgrades/","icons/stats/","icons/abilities/","icons/headquarters/","icons/garage/","portraits/v16/","ui/enemies/enemy_atlas_v1.png","ui/workshops/atlas.png"]

static func current()->String:
	var value=str(Settings.values.get("illustration_set",DEFAULT))
	return value if value in SETS else DEFAULT

## Classic asset path → the same picture in the chosen set (or the classic path for shared art).
static var resolved:Dictionary={}  # "set|path" → final path: UI code asks every frame, the disk is asked once
static func path(original:String,set_id:String="")->String:
	if not original.begins_with("res://assets/"):return original
	var key=(set_id if set_id!="" else current())+"|"+original
	if resolved.has(key):return resolved[key]
	var result=_resolve(original,set_id)
	resolved[key]=result
	return result

static func _resolve(original:String,set_id:String)->String:
	var relative=original.trim_prefix("res://assets/")
	for prefix in PREFIXES:
		if relative.begins_with(prefix):
			var variant=ROOT+(set_id if set_id!="" else current())+"/"+relative
			if ResourceLoader.exists(variant):return variant
			if OS.has_feature("editor"):push_warning("Illustration missing in set: "+variant)
			return original
	return original

static var textures:Dictionary={}
static func texture(original:String)->Texture2D:
	var final_path=path(original)
	if not textures.has(final_path):textures[final_path]=load(final_path) if ResourceLoader.exists(final_path) else null
	return textures[final_path]

## Live switch: every texture already on screen that comes from the old set is swapped for the same
## picture of the new set (plain textures, AtlasTexture atlases, button icons). Nothing is rebuilt.
static func swap_tree(root:Node,from_set:String,to_set:String):
	if from_set==to_set or root==null:return
	var old_root=ROOT+from_set+"/"
	for node in root.find_children("*","",true,false):
		for property in ["texture","icon"]:
			if not property in node:continue
			var value=node.get(property)
			if value is AtlasTexture and value.has_meta("trim_source"):
				var source:String=value.get_meta("trim_source")
				if source.begins_with(old_root):node.set(property,UiKit.trimmed(load(source.replace(old_root,ROOT+to_set+"/"))))
			elif value is AtlasTexture:
				var atlas:Texture2D=value.atlas
				if atlas and atlas.resource_path.begins_with(old_root):
					var copy:AtlasTexture=value.duplicate();copy.atlas=load(atlas.resource_path.replace(old_root,ROOT+to_set+"/"));node.set(property,copy)
			elif value is Texture2D and value.resource_path.begins_with(old_root):
				var swapped=value.resource_path.replace(old_root,ROOT+to_set+"/")
				if ResourceLoader.exists(swapped):node.set(property,load(swapped))
