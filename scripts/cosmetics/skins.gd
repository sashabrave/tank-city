class_name Skins
extends RefCounted
## Uniform skins for the player's soldier (visual only). Each swaps the camo cells of the v6 palette.
## source: start — owned from the beginning; chest — commander chests; boss — world boss; slot — merchant slot machine.
const UNIFORMS={
	"woodland":{"name":"Лес","source":"start","camo":{}},
	"desert":{"name":"Пустыня","source":"chest","camo":{"camo_a":"b59a6a","camo_b":"9c7f52","camo_c":"cdb88a","vest":"8a7450","pouch":"9a8158"}},
	"winter":{"name":"Зима","source":"chest","camo":{"camo_a":"e4e6e2","camo_b":"b9bec0","camo_c":"8e969a","vest":"6f777b","pouch":"9aa1a4"}},
	"urban":{"name":"Город","source":"chest","camo":{"camo_a":"7d8187","camo_b":"55595e","camo_c":"a3a7ab","vest":"3f4246","pouch":"5b5f64"}},
	"night":{"name":"Ночь","source":"chest","camo":{"camo_a":"2e3440","camo_b":"232833","camo_c":"3c4454","vest":"1c2029","pouch":"2a303b"}},
	"parade":{"name":"Парадная","source":"boss","camo":{"camo_a":"2f4a3a","camo_b":"2f4a3a","camo_c":"c9a24a","vest":"23372b","pouch":"c9a24a"}},
	"tiger":{"name":"Тигровая","source":"slot","camo":{"camo_a":"d9853b","camo_b":"2a241e","camo_c":"e8b25a","vest":"5a4430","pouch":"2a241e"}},
}
const SOURCE_TEXT={"start":"Есть сразу","chest":"Выпадает из сундуков командиров","boss":"Награда за победу над боссом","slot":"Джекпот в автомате торговца"}
static func owned(id:String)->bool:return id=="woodland" or id in Game.skins_owned
static func camo(id:String)->Dictionary:
	var result={}
	var source:Dictionary=UNIFORMS.get(id,UNIFORMS.woodland).camo
	for key in source:result[key]=Color(source[key])
	return result
## Grants a random not-yet-owned uniform of this source; returns its id or "".
static func grant(source:String,rng:RandomNumberGenerator)->String:
	var pool=UNIFORMS.keys().filter(func(id):return UNIFORMS[id].source==source and not owned(id))
	if pool.is_empty():return ""
	var id=pool[rng.randi_range(0,pool.size()-1)]
	Game.skins_owned.append(id);Game.save_progress()
	return id
## Small swatch for cards: three camo stripes with a vest band.
static var swatches:Dictionary={}
static func swatch(id:String)->Texture2D:
	if swatches.has(id):return swatches[id]
	var colors=camo(id);var base={"camo_a":Color("5d6147"),"camo_b":Color("525840"),"camo_c":Color("6a694b"),"vest":Color("4a5039")}
	var image=Image.create(48,48,false,Image.FORMAT_RGBA8)
	for i in range(3):image.fill_rect(Rect2i(0,i*12,48,12),colors.get(["camo_a","camo_b","camo_c"][i],base[["camo_a","camo_b","camo_c"][i]]))
	image.fill_rect(Rect2i(0,36,48,12),colors.get("vest",base.vest))
	var texture=ImageTexture.create_from_image(image);swatches[id]=texture;return texture
