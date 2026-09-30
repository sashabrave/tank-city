class_name RunEffect
extends RefCounted
## Base for behaviour cards. Override on_<event>(data) to react to RunEffects.emit and
## modify_<key>(value, data) to change a live value queried through RunEffects.modify.
## modify_* handlers may be queried by UI at any time; only modify_shot_damage is called once per real shot.
var arena
var id:String
