class_name SquadCatalog
extends RefCounted
## Enemy squads: small functional groups that arrive together. A wave is a few squads chosen by the seed, not a
## random pile of units. tier: content tier of the field (1 infantry, 2 light vehicles, 3 heavy); from_wave: first
## wave index it may join; members: kind + weapon ("" = the kind's default, "*" = any basic rifle-class weapon).
## New squads (or squads of new worlds/enemies) are added here; WaveDirector keeps the caps.
const SQUADS=[
	{"id":"patrol","name":"Дозор","tier":1,"from_wave":0,"weight":10,"members":[["soldier","*"],["soldier","*"]]},
	{"id":"assault_pair","name":"Штурмовая пара","tier":1,"from_wave":0,"weight":8,"members":[["shield",""],["soldier","smg"]]},
	{"id":"firing_point","name":"Огневая точка","tier":1,"from_wave":0,"weight":6,"members":[["soldier","rifle"],["soldier","rifle"]]},
	{"id":"grenade_team","name":"Расчёт гранатомёта","tier":1,"from_wave":1,"weight":6,"members":[["grenadier",""],["soldier","shotgun"]]},
	{"id":"lone_shield","name":"Щитовик","tier":1,"from_wave":0,"weight":4,"members":[["shield",""]]},
	{"id":"moto_patrol","name":"Мотодозор","tier":2,"from_wave":0,"weight":8,"members":[["buggy",""],["soldier","smg"]]},
	{"id":"armour_group","name":"Бронегруппа","tier":2,"from_wave":0,"weight":7,"members":[["apc",""],["soldier","*"],["soldier","*"]]},
	{"id":"battery","name":"Батарея","tier":2,"from_wave":1,"weight":5,"members":[["mortar",""],["shield",""]]},
	{"id":"sniper_pair","name":"Снайперская пара","tier":2,"from_wave":1,"weight":5,"members":[["sniper",""],["soldier","rifle"]]},
	{"id":"tank_wedge","name":"Танковый клин","tier":3,"from_wave":0,"weight":7,"members":[["tank",""],["soldier","*"],["soldier","*"]]},
	{"id":"tank_hunters","name":"Истребители танков","tier":3,"from_wave":0,"weight":6,"members":[["rpg",""],["rpg",""],["shield",""]]},
	{"id":"storm_column","name":"Штурмовая колонна","tier":3,"from_wave":1,"weight":6,"members":[["apc",""],["shield",""],["soldier","smg"]]},
]
## Most units of a kind in one wave.
const CAPS={"mortar":1,"sniper":1,"tank":3,"rpg":3}
static func pool(tier:int,wave:int)->Array:
	return SQUADS.filter(func(s):return s.tier<=tier and s.from_wave<=wave)
## Squads of the field's own tier weigh double, so later fields feel different, yet lighter squads still mix in.
static func weight(squad:Dictionary,tier:int)->float:return float(squad.weight)*(2.0 if squad.tier==tier else 1.0)
