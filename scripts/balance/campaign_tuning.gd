@tool
class_name CampaignTuning
extends Resource
## Campaign numbers the game actually reads (WaveDirector, Campaign, SurpriseSystem). Defaults equal the values
## the code used before they moved here, so editing this resource is the one place to tune pacing.
## Worlds are listed in order: index 0 is world 1. A new world adds one entry to each world array.
@export_group("Миры")
@export var world_health:Array[float]=[1.0,1.75,2.7]
@export var world_damage:Array[float]=[1.0,1.35,1.7]
@export var world_boss_health:Array[float]=[700.0,1100.0,1600.0]
## HP growth per field inside a world: the first value is world 1, the second every later world.
@export var health_step_per_field:Array[float]=[0.13,0.08]
@export_range(0,0.5,0.005) var damage_step_per_field:float=0.055
@export_group("Размер волны: база + поле × шаг + номер волны + звёзды")
@export_range(1,20,1) var wave_base_size:int=4
@export_range(0,3,0.05) var wave_size_per_field:float=0.8
@export_range(0,5,1) var wave_size_per_wave:int=1
@export_range(0,5,1) var wave_size_per_star:int=1
@export_range(0,8,1) var endless_size_per_sector:int=2
@export_range(0,32,1) var endless_size_cap:int=16
## Fields with light vehicles hold at least this many enemies per wave.
@export_range(1,20,1) var vehicle_wave_minimum:int=6
@export_group("Одновременно на поле: база + мир + поле / шаг, не больше потолка")
@export_range(1,10,1) var active_base:int=2
@export_range(1,10,1) var active_fields_per_step:int=3
@export_range(1,12,1) var active_cap:int=6
@export_group("Случайные дроны — отдельно от волн")
@export_range(1,60,0.5) var first_surprise_min:float=15
@export_range(1,90,0.5) var first_surprise_max:float=30
@export_range(1,60,0.5) var surprise_delay_min:float=18
@export_range(1,90,0.5) var surprise_delay_max:float=30
@export_range(1,4,1) var surprise_active_cap:int=2

func world_value(values:Array,world:int)->float:
	return float(values[clampi(world-1,0,values.size()-1)])
