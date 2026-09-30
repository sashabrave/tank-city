@tool
class_name StatDef
extends Resource
## One run characteristic. The dossier, the station tree, card previews, run checkpoints and the
## sandbox sliders all read this file; adding a stat is adding one .tres in assets/balance/stats.
@export var id:String=""
@export var title:String=""
@export var icon:String=""
@export_enum("fire","survival","ammo","recon","logistics") var family:String="fire"
## Order inside the family branch (station tree and dossier).
@export var order:int=0
## RunState field that holds the value during a run.
@export var run_field:String=""
## How the value is shown: percent (0.12 → 12%), multiplier (1.5 → ×1.5), number, integer.
@export_enum("percent","multiplier","number","integer") var format:String="percent"
## Upper limit used in combat (0 = none).
@export var cap:float=0.0
@export_multiline var description:String=""
@export_group("Station")
## Permanent step per station level (0 = no station node).
@export var step:float=0.0
@export var max_level:int=5
@export var cost_base:int=60
@export var cost_step:int=30
## Node that must reach `requires_level` first (empty for the branch root).
@export var requires:String=""
@export var requires_level:int=2
## Profile field that already stores this stat's meta level instead of Game.stat_levels (e.g. luck_level).
@export var meta_field:String=""
