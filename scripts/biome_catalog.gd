extends RefCounted
## Stable test IDs; colour and floor rules are one entry, never independently shuffled.
const ENTRIES=[
	{"family":"desert","vegetation":"palm","name":"Песчаная пустыня","floor":"b8aa7d","wall":"a69d83","brick":"b67b43","edge":"978963","kinds":["vegetation","sand"],"info":"песок","ambience":"desert"},
	{"family":"desert","vegetation":"charred","name":"Терракотовая пустыня","floor":"b68e78","wall":"a38c7f","brick":"b9754e","edge":"947260","kinds":["vegetation","sand"],"info":"песок","ambience":"desert"},
	{"family":"coast","vegetation":"palm","name":"Оливковый берег","floor":"aab197","wall":"919987","brick":"ae895c","edge":"88917c","kinds":["vegetation","sand","water"],"info":"песок + вода","ambience":"marsh"},
	{"family":"coast","vegetation":"broadleaf","name":"Розовый берег","floor":"bea7a1","wall":"a4938e","brick":"b98269","edge":"9c8985","kinds":["vegetation","sand","water"],"info":"песок + вода","ambience":"marsh"},
	{"family":"forest","vegetation":"spruce","name":"Влажный лес","floor":"82968b","wall":"778d83","brick":"b58054","edge":"6b8078","kinds":["vegetation","water"],"info":"вода","ambience":"forest"},
	{"family":"frost","vegetation":"frost","name":"Морозная равнина","floor":"98aab1","wall":"899da5","brick":"b88150","edge":"7a9099","kinds":["vegetation","ice"],"info":"лёд","ambience":"mountains"},
	{"family":"frost","vegetation":"frost","name":"Сиреневый перевал","floor":"a29caf","wall":"918a9d","brick":"ac735c","edge":"817b90","kinds":["vegetation","ice"],"info":"лёд","ambience":"mountains"},
	{"family":"forest","name":"Медная роща","floor":"ae9477","wall":"98856f","brick":"b17953","edge":"867360","kinds":["vegetation","sand"],"info":"песок","ambience":"forest","vegetation":"broadleaf"},
	{"family":"ash","name":"Пепельный лес","floor":"968c86","wall":"827c77","brick":"986e5e","edge":"736d68","kinds":["vegetation","sand"],"info":"песок","ambience":"inferno","vegetation":"charred"},
	{"family":"frost","name":"Ледяная тайга","floor":"a0b4af","wall":"8fa39e","brick":"a17e65","edge":"7c9390","kinds":["vegetation","ice"],"info":"лёд","ambience":"forest","vegetation":"frost"},
	{"family":"coast","name":"Бирюзовая дельта","floor":"90b0a4","wall":"819b90","brick":"ae805e","edge":"72948a","kinds":["vegetation","water","sand"],"info":"песок + вода","ambience":"marsh","vegetation":"palm"},
	{"family":"forest","name":"Золотой бор","floor":"b7ac89","wall":"9c967d","brick":"b98150","edge":"918970","kinds":["vegetation","sand"],"info":"песок","ambience":"forest","vegetation":"spruce"},
	{"family":"marsh","name":"Лиловое болото","floor":"a39ca9","wall":"898590","brick":"a57d68","edge":"7e7787","kinds":["vegetation","water"],"info":"вода","ambience":"marsh","vegetation":"broadleaf"},
	{"family":"ash","name":"Обгоревший берег","floor":"ac9890","wall":"91817b","brick":"ac705b","edge":"86736d","kinds":["vegetation","water","sand"],"info":"песок + вода","ambience":"inferno","vegetation":"charred"},
	{"family":"frost","name":"Серебряный перевал","floor":"b3b9bd","wall":"969fa5","brick":"a28570","edge":"85919a","kinds":["vegetation","ice"],"info":"лёд","ambience":"mountains","vegetation":"frost"},
	{"family":"urban","name":"Промзона","floor":"9c9e98","wall":"8b8e88","brick":"a8745a","edge":"7e817b","kinds":["vegetation","water"],"info":"лужи","ambience":"city","vegetation":"broadleaf"},
	{"family":"urban","name":"Портовые доки","floor":"8f9ea3","wall":"7f8d92","brick":"a77a5f","edge":"718086","kinds":["vegetation","water"],"info":"вода","ambience":"city","vegetation":"broadleaf"},
	{"family":"urban","name":"Руины квартала","floor":"a8a096","wall":"948c83","brick":"b0765a","edge":"857e75","kinds":["vegetation","sand"],"info":"пыль","ambience":"city","vegetation":"charred"},
	{"family":"steppe","name":"Степь у дороги","floor":"aeaa86","wall":"979377","brick":"b17d52","edge":"8a8668","kinds":["vegetation","sand"],"info":"песок","ambience":"forest","vegetation":"broadleaf"},
	{"family":"steppe","name":"Осенняя степь","floor":"b39a7c","wall":"9b876f","brick":"b4744c","edge":"8c7a63","kinds":["vegetation","water"],"info":"вода","ambience":"forest","vegetation":"broadleaf"},
	{"family":"marsh","name":"Торфяная топь","floor":"8f9a86","wall":"7d8775","brick":"a27a59","edge":"717a69","kinds":["vegetation","water"],"info":"вода","ambience":"marsh","vegetation":"spruce"}
]
## Families: one look and set of hazards each; colour variants are entries of the same family.
const FAMILIES={"forest":"лес","coast":"берег","steppe":"степь","desert":"пустыня","urban":"город","marsh":"болото","frost":"мороз","ash":"пепелище"}
## Biomes by world and part of the route (early stages 0–1, middle 2–3, late 4+): calm, readable ground first,
## hazards (ice, deep water, ash) later. Within a part the family and its colour variant are seeded.
const WORLD_FAMILIES={
	1:[["forest","steppe"],["coast","urban"],["urban","desert"]],
	2:[["desert","steppe"],["marsh","urban"],["frost","urban"]],
	3:[["urban","frost"],["ash","frost"],["ash","urban"]],
}
const ENDLESS_FAMILIES=["forest","steppe","coast","desert","urban","marsh","frost","ash"]
static func part(room:int)->int:return 0 if room<=1 else 1 if room<=3 else 2
static func families(room:int)->Array:
	if Campaign.endless or not WORLD_FAMILIES.has(Campaign.world):return ENDLESS_FAMILIES
	return WORLD_FAMILIES[Campaign.world][part(room)]
static func index(seed_value:int,room:int)->int:
	var rng=RandomNumberGenerator.new();rng.seed=hash([seed_value,room,Campaign.world,Campaign.cycle,"biome"])
	var pool=families(room);var family=pool[rng.randi_range(0,pool.size()-1)]
	var variants=[]
	for i in range(ENTRIES.size()):
		if ENTRIES[i].family==family:variants.append(i)
	return variants[rng.randi_range(0,variants.size()-1)]
static func entry(seed_value:int,room:int)->Dictionary:return ENTRIES[index(seed_value,room)]
static func caption(seed_value:int,room:int)->String:
	var b=entry(seed_value,room)
	return "%s · %s\n%s" % [FAMILIES[b.family].capitalize(),b.name,b.info+" + растительность"]
## «лес, степь, берег…» — every family a world can show, in route order (world card subtitle).
static func world_line(world:int)->String:
	if not WORLD_FAMILIES.has(world):return ""
	var names=[]
	for group in WORLD_FAMILIES[world]:
		for family in group:
			var shown=Texts.localized(FAMILIES[family])
			if shown not in names:names.append(shown)
	return ", ".join(names)
