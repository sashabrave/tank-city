class_name InfantryPalette
extends RefCounted
## Runtime palette swap for v6 infantry: fur per unit (cats on our side, dogs on the enemy side), camo per side/biome. Visual only.
## NAMES/COLORS mirror tools/v6_common.py (checked by tests/infantry_v6_revision against palette.json).
const CELL=4
const NAMES=["camo_a","camo_b","camo_c","vest","pouch","black","strap","band","sole","fur","fur_dark","muzzle","nose","ear_inner","lamp","gun","gun_light","furniture","hull","hull_light","hull_dark","rubber","glass","canvas","canvas_dark","concrete","concrete_dark","stone","wood","flag","gold","bronze","marble","steel","hazard","tarp","tarp_dark","screen","screen_amber","glow_red","desk"]
const COLORS={"camo_a":"5d6147","camo_b":"525840","camo_c":"6a694b","vest":"4a5039","pouch":"545a41","black":"232323","strap":"2e2f2c","band":"e0692a","sole":"3a3a38","fur":"d9853b","fur_dark":"a45a22","muzzle":"efe6d6","nose":"c9736f","ear_inner":"e3a39a","lamp":"fff1c9","gun":"2f3236","gun_light":"4a4e52","furniture":"5f6448","hull":"7a8062","hull_light":"b9b39c","hull_dark":"4f5443","rubber":"262626","glass":"9fb6bd","canvas":"7d7a5f","canvas_dark":"5f5d48","concrete":"9a9d93","concrete_dark":"74786f","stone":"a8a79c","wood":"7a5a3c","flag":"c8452f","gold":"c9a24a","bronze":"7b8a6e","marble":"c3bba7","steel":"9aa1a4","hazard":"e3b23c","tarp":"6b6e52","tarp_dark":"55583f","screen":"6fd8e0","screen_amber":"f2b74a","glow_red":"ff4a3a","desk":"b8ad94"}
const SOURCE_MATERIAL="V6_palette_fabric"
# Coats: ginger (player), grey, black, cream, tabby, white.
const FURS=[
	{"fur":"d9853b","fur_dark":"a45a22","muzzle":"efe6d6","nose":"c9736f"},
	{"fur":"8d9096","fur_dark":"5e6167","muzzle":"e9e6e0","nose":"b07a80"},
	{"fur":"343236","fur_dark":"1f1e21","muzzle":"e6e1d8","nose":"5c4b4d"},
	{"fur":"e3cfa8","fur_dark":"c2a57a","muzzle":"f3ede2","nose":"d08d86"},
	{"fur":"8a6a48","fur_dark":"5a4430","muzzle":"e6dccb","nose":"b4786e"},
	{"fur":"ece8e0","fur_dark":"c9c3b8","muzzle":"f6f3ee","nose":"e09a98"},
]
# Enemy dogs: black-and-tan, brown, sable, grey, cream, brindle. Noses are dark, ear lining darker than on cats.
const DOG_FURS=[
	{"fur":"4a3a30","fur_dark":"2a221d","muzzle":"c08a55","nose":"221e1e","ear_inner":"8a5c44"},
	{"fur":"7b5236","fur_dark":"553622","muzzle":"d9c0a0","nose":"2a2424","ear_inner":"a0705a"},
	{"fur":"b07a42","fur_dark":"5e3f22","muzzle":"e8d4b4","nose":"262222","ear_inner":"b88068"},
	{"fur":"8c8a86","fur_dark":"55534f","muzzle":"dcd8d0","nose":"242222","ear_inner":"9a8480"},
	{"fur":"d8c29a","fur_dark":"a88c62","muzzle":"f2e8d6","nose":"2e2828","ear_inner":"c4988a"},
	{"fur":"6a5236","fur_dark":"3a2c1e","muzzle":"b99870","nose":"201c1c","ear_inner":"8c644c"},
]
static var materials:Dictionary={}

## Local troops wear camo mixed from the room's ground, edge and wall colours.
static func biome_camo(biome:Dictionary)->Dictionary:
	if biome.is_empty():return {}
	var floor_color=Color(biome.get("floor","aab197"));var edge=Color(biome.get("edge","88917c"));var wall=Color(biome.get("wall","919987"))
	var olive=Color(COLORS.camo_a)
	return {"camo_a":floor_color.darkened(.26).lerp(olive,.1),"camo_b":edge.darkened(.38),"camo_c":wall.darkened(.12),
		"vest":floor_color.darkened(.5).lerp(olive,.15),"pouch":edge.darkened(.45),
		# Vehicles: light panels and tarps take the local ground tone.
		"hull_light":floor_color.lerp(wall,.3),"hull_dark":edge.darkened(.4),"canvas":floor_color.darkened(.3),"canvas_dark":edge.darkened(.45)}

static func texture_for(overrides:Dictionary)->ImageTexture:
	var image=Image.create(CELL*NAMES.size(),CELL,false,Image.FORMAT_RGBA8)
	for i in range(NAMES.size()):
		var value=overrides.get(NAMES[i],COLORS[NAMES[i]])
		image.fill_rect(Rect2i(i*CELL,0,CELL,CELL),value if value is Color else Color(value))
	return ImageTexture.create_from_image(image)

## Shared material per (source, fur, camo): identical soldiers still batch together.
static func material(source:StandardMaterial3D,fur:int,camo:Dictionary,species:String="cat")->StandardMaterial3D:
	var key="%d|%d|%s|%s" % [source.get_instance_id(),fur,str(camo),species]
	if materials.has(key):return materials[key]
	var coats=DOG_FURS if species=="dog" else FURS
	var overrides=coats[posmod(fur,coats.size())].duplicate();overrides.merge(camo,true)
	var mat:StandardMaterial3D=source.duplicate()
	mat.albedo_texture=texture_for(overrides);mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	materials[key]=mat
	return mat
