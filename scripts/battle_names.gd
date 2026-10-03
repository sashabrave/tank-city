class_name BattleNames
extends RefCounted
## Battle names (T-008): every run gets a short, military-geographic and slightly silly name tied to the biomes it
## crosses — «Битва при Красной поляне», «Захват Бамбуковой рощи», «Оборона Мятного брода». Visual seed only.
## Pattern: [operation] + [coloured place]; the place noun comes from the run's first biome family.
const OPERATIONS=[["Битва при","prep"],["Захват","gen"],["Оборона","gen"],["Штурм","gen"],["Котёл у","gen"],["Марш на","acc"],["Прорыв к","dat"],["Засада у","gen"]]
## Place nouns per family: [nominative, grammatical gender m/f/n, prep, gen, acc, dat].
const PLACES={
	"forest":[["роща","f"],["бор","m"],["опушка","f"]],
	"steppe":[["поляна","f"],["курган","m"],["поле","n"]],
	"coast":[["бухта","f"],["брод","m"],["мыс","m"]],
	"desert":[["бархан","m"],["оазис","m"],["дюна","f"]],
	"urban":[["двор","m"],["квартал","m"],["пустошь","f"]],
	"marsh":[["топь","f"],["кочка","f"],["заводь","f"]],
	"frost":[["перевал","m"],["сугроб","m"],["ледник","m"]],
	"ash":[["пепелище","n"],["овраг","m"],["гарь","f"]],
}
## Colour or funny adjective, masculine nominative stem + ending set.
const ADJECTIVES=["Красн","Медн","Мятн","Бамбуков","Рыж","Сиз","Лунн","Ржав","Пушист","Ворчлив","Сонн","Хвостат","Колюч","Молочн","Усат","Полосат","Сметанн","Клубков"]
## Endings by case and gender for the adjective stems above (hard-stem «-ый» pattern; «Сизн» etc. are fine with it).
const ADJ_END={"ins":{"m":"ым","f":"ой","n":"ым"},"nom":{"m":"ый","f":"ая","n":"ое"},"prep":{"m":"ом","f":"ой","n":"ом"},"gen":{"m":"ого","f":"ой","n":"ого"},"acc":{"m":"ый","f":"ую","n":"ое"},"dat":{"m":"ому","f":"ой","n":"ому"}}
static func noun_case(word:String,gender:String,c:String)->String:
	if c=="nom" or (c=="acc" and gender!="f"):return word
	var stem=word.substr(0,word.length()-1);var last=word.right(1)
	var hushing=stem.right(1) in ["ж","ш","ч","щ","ц","к","г","х"]
	match gender:
		"f":
			if last=="а":return stem+{"prep":"е","gen":"и" if hushing else "ы","acc":"у","dat":"е","ins":"ой"}[c]
			if last=="я":return stem+{"prep":"е","gen":"и","acc":"ю","dat":"е","ins":"ей"}[c]
			if last=="ь":return stem+{"prep":"и","gen":"и","acc":"ь","dat":"и","ins":"ью"}[c]
		"n":
			if last=="о":return stem+{"prep":"е","gen":"а","acc":"о","dat":"у","ins":"ом"}[c]
			if last=="е":
				var soft=not stem.right(1) in ["ж","ш","ч","щ","ц"]
				return stem+{"prep":"е","gen":"я" if soft else "а","acc":"е","dat":"ю" if soft else "у","ins":"ем"}[c]
	if last=="ь":return stem+{"prep":"е","gen":"я","acc":"ь","dat":"ю","ins":"ем"}[c]
	# Masculine consonant ending.
	return word+{"prep":"е","gen":"а","acc":"","dat":"у","ins":"ом"}[c]
static func adjective(stem:String,gender:String,c:String)->String:
	var ending=ADJ_END[c][gender]
	if stem.right(1) in ["ж","ш","ч","щ","к","г","х"] and ending.begins_with("ы"):ending="и"+ending.substr(1)
	return stem+ending
## English: same picks by index, so a run has one name in both languages.
const OPERATIONS_EN=["Battle of","Capture of","Defence of","Storming of","Pocket at","March on","Push to","Ambush at"]
const PLACES_EN={"forest":["Grove","Pinewood","Edge"],"steppe":["Glade","Mound","Field"],"coast":["Bay","Ford","Cape"],"desert":["Dune","Oasis","Drift"],"urban":["Yard","Block","Wasteland"],"marsh":["Bog","Hummock","Backwater"],"frost":["Pass","Snowdrift","Glacier"],"ash":["Ashland","Gully","Burnt Hill"]}
const ADJECTIVES_EN=["Red","Copper","Mint","Bamboo","Ginger","Grey","Moon","Rusty","Fluffy","Grumpy","Sleepy","Tailed","Prickly","Milky","Whiskered","Striped","Creamy","Yarn"]
static func generate(seed_value:int,family:String,english:=false)->String:
	var rng=RandomNumberGenerator.new();rng.seed=hash([seed_value,"battle_name"])
	var oi=rng.randi_range(0,OPERATIONS.size()-1);var op=OPERATIONS[oi]
	var places:Array=PLACES.get(family,PLACES.steppe);var pi=rng.randi_range(0,places.size()-1);var place=places[pi]
	var ai=rng.randi_range(0,ADJECTIVES.size()-1);var stem=ADJECTIVES[ai]
	if english:return "%s %s %s" % [OPERATIONS_EN[oi],ADJECTIVES_EN[ai],PLACES_EN.get(family,PLACES_EN.steppe)[pi]]
	var c=str(op[1])
	return "%s %s %s" % [op[0],adjective(stem,place[1],c),noun_case(place[0],place[1],c)]
## The current run's name (campaign only): from the biome of the first field.
static func current()->String:
	var family=str(preload("res://scripts/biome_catalog.gd").entry(Game.visual_run_seed,0).get("family","steppe"))
	return generate(Game.visual_run_seed+Campaign.world*7919,family,str(Settings.values.get("language","ru"))=="en")

## Room names (author, 2 Oct): every field has its own name like a line in a history book — a battle word, a
## preposition and the place made of this room's biome: «Засада у Красного поля», «Сеча под Медным курганом».
## Picks are seeded per run, room and lane (visual only), so the route map and the battle show the same name.
const BATTLES=["Засада","Битва","Бойня","Сеча","Осада","Штурм","Прорыв","Оборона","Котёл","Схватка","Стычка","Натиск"]
const BATTLES_EN=["Ambush","Battle","Slaughter","Clash","Siege","Storm","Breakthrough","Defence","Pocket","Fight","Skirmish","Onslaught"]
## Preposition and the case it governs; English pairs by index.
const PREPOSITIONS=[["у","gen"],["под","ins"],["над","ins"],["за","acc"],["при","prep"]]
const PREPOSITIONS_EN=["at","below","above","for","by"]
## Serious adjectives, hard stems (the «-ый» pattern; к/г/х stems take «-ий»).
const EPIC=["Красн","Медн","Ржав","Сиз","Лунн","Чёрн","Бел","Горел","Каменн","Холодн","Стар","Тих","Пыльн","Кровав","Багров","Туманн","Долг"]
const EPIC_EN=["Red","Copper","Rusty","Grey","Moon","Black","White","Burnt","Stone","Cold","Old","Quiet","Dusty","Bloody","Crimson","Misty","Long"]
static func room(seed_value:int,room_index:int,lane:int,family:String,english:=false)->String:
	var rng=RandomNumberGenerator.new();rng.seed=hash([seed_value,room_index,maxi(lane,0),Campaign.world,Campaign.cycle,"room_name"])
	var bi=rng.randi_range(0,BATTLES.size()-1);var pi=rng.randi_range(0,PREPOSITIONS.size()-1);var ai=rng.randi_range(0,EPIC.size()-1)
	var places:Array=PLACES.get(family,PLACES.steppe);var ni=rng.randi_range(0,places.size()-1)
	if english or str(Settings.values.get("language","ru"))=="en":
		return "%s %s %s %s" % [BATTLES_EN[bi],PREPOSITIONS_EN[pi],EPIC_EN[ai],PLACES_EN.get(family,PLACES_EN.steppe)[ni]]
	var place=places[ni];var c=str(PREPOSITIONS[pi][1])
	return "%s %s %s %s" % [BATTLES[bi],PREPOSITIONS[pi][0],adjective(EPIC[ai],place[1],c),noun_case(place[0],place[1],c)]

