class_name UnitKinds
extends RefCounted
## One place for unit families. Code asks UnitKinds.is_infantry(kind) / is_vehicle(kind) instead of repeating
## kind lists; a new enemy or machine is added here (and in its balance resource) once.
## Foot soldiers: quarter-step movement, body hits, trench use, gas sleep.
const INFANTRY=["soldier","grenadier","sniper","shield"]
## Ground vehicles a hero can drive (also enemy armour): headlights, wrecks, crew.
const VEHICLES=["buggy","apc","tank"]
## Flying units: no ground collision, separate surprise cap.
const FLYING=["drone","flyer"]
static func is_infantry(kind:String)->bool:return kind in INFANTRY
static func is_vehicle(kind:String)->bool:return kind in VEHICLES
static func is_flying(kind:String)->bool:return kind in FLYING
