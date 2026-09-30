extends RefCounted
## Stable test IDs; colour and floor rules are one entry, never independently shuffled.
const ENTRIES=[
	{"vegetation":"palm","name":"Песчаная пустыня","floor":"b8aa7d","wall":"a69d83","brick":"b67b43","edge":"978963","kinds":["vegetation","sand"],"info":"песок","ambience":"desert"},
	{"vegetation":"charred","name":"Терракотовая пустыня","floor":"b68e78","wall":"a38c7f","brick":"b9754e","edge":"947260","kinds":["vegetation","sand"],"info":"песок","ambience":"desert"},
	{"vegetation":"palm","name":"Оливковый берег","floor":"aab197","wall":"919987","brick":"ae895c","edge":"88917c","kinds":["vegetation","sand","water"],"info":"песок + вода","ambience":"marsh"},
	{"vegetation":"broadleaf","name":"Розовый берег","floor":"bea7a1","wall":"a4938e","brick":"b98269","edge":"9c8985","kinds":["vegetation","sand","water"],"info":"песок + вода","ambience":"marsh"},
	{"vegetation":"spruce","name":"Влажный лес","floor":"82968b","wall":"778d83","brick":"b58054","edge":"6b8078","kinds":["vegetation","water"],"info":"вода","ambience":"forest"},
	{"vegetation":"frost","name":"Морозная равнина","floor":"98aab1","wall":"899da5","brick":"b88150","edge":"7a9099","kinds":["vegetation","ice"],"info":"лёд","ambience":"mountains"},
	{"vegetation":"frost","name":"Сиреневый перевал","floor":"a29caf","wall":"918a9d","brick":"ac735c","edge":"817b90","kinds":["vegetation","ice"],"info":"лёд","ambience":"mountains"},
	{"name":"Медная роща","floor":"ae9477","wall":"98856f","brick":"b17953","edge":"867360","kinds":["vegetation","sand"],"info":"песок","ambience":"forest","vegetation":"broadleaf"},
	{"name":"Пепельный лес","floor":"968c86","wall":"827c77","brick":"986e5e","edge":"736d68","kinds":["vegetation","sand"],"info":"песок","ambience":"inferno","vegetation":"charred"},
	{"name":"Ледяная тайга","floor":"a0b4af","wall":"8fa39e","brick":"a17e65","edge":"7c9390","kinds":["vegetation","ice"],"info":"лёд","ambience":"forest","vegetation":"frost"},
	{"name":"Бирюзовая дельта","floor":"90b0a4","wall":"819b90","brick":"ae805e","edge":"72948a","kinds":["vegetation","water","sand"],"info":"песок + вода","ambience":"marsh","vegetation":"palm"},
	{"name":"Золотой бор","floor":"b7ac89","wall":"9c967d","brick":"b98150","edge":"918970","kinds":["vegetation","sand"],"info":"песок","ambience":"forest","vegetation":"spruce"},
	{"name":"Лиловое болото","floor":"a39ca9","wall":"898590","brick":"a57d68","edge":"7e7787","kinds":["vegetation","water"],"info":"вода","ambience":"marsh","vegetation":"broadleaf"},
	{"name":"Обгоревший берег","floor":"ac9890","wall":"91817b","brick":"ac705b","edge":"86736d","kinds":["vegetation","water","sand"],"info":"песок + вода","ambience":"inferno","vegetation":"charred"},
	{"name":"Серебряный перевал","floor":"b3b9bd","wall":"969fa5","brick":"a28570","edge":"85919a","kinds":["vegetation","ice"],"info":"лёд","ambience":"mountains","vegetation":"frost"}
]
static func index(seed_value:int,room:int)->int:return posmod(seed_value+room,ENTRIES.size())
static func entry(seed_value:int,room:int)->Dictionary:return ENTRIES[index(seed_value,room)]
static func caption(seed_value:int,room:int)->String:
	var b=entry(seed_value,room)
	return "Биом %02d · %s\n%s" % [index(seed_value,room)+1,b.name,b.info+" + растительность"]
