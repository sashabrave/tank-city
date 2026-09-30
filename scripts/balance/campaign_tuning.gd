@tool
class_name CampaignTuning
extends Resource
## В кампании 17 этапов. Порядок боссов сохраняется; X/Y/Z — три волны поля боя.
@export_group("Размеры и одновременные враги — по 17 этапам")
@export var room_sizes:Array[int]=[11,13,15,15,17,17,19,22,23,24,25,26,27,28,29,30,35]
@export var active_enemy_caps:Array[int]=[2,3,4,4,4,4,3,5,5,5,5,5,5,5,5,3,4]
@export_group("Шесть полей боя первой зоны — X/Y/Z это волны 1/2/3")
@export var wave_counts:Array[Vector3i]=[Vector3i(4,5,6),Vector3i(5,6,7),Vector3i(6,7,8),Vector3i(6,7,8),Vector3i(6,7,8),Vector3i(6,7,8)]
@export var wave_budgets:Array[Vector3i]=[Vector3i(10,13,16),Vector3i(16,19,22),Vector3i(21,24,27),Vector3i(21,24,27),Vector3i(21,24,27),Vector3i(21,24,27)]
@export_group("Усиление поздних полей боя")
@export_range(0.1,10,0.05) var late_zone_one_scale:float=2
@export_range(0.1,10,0.05) var zone_two_health:float=2.2
@export_range(0,2,0.01) var zone_two_health_step:float=0.13
@export_range(0.1,10,0.05) var zone_two_damage:float=2.05
@export_range(0,2,0.005) var zone_two_damage_step:float=0.055
@export_range(0.5,3,0.05) var zone_two_population:float=1.2
@export_range(0,100,1) var zone_two_budget_bonus:int=8
@export_group("Сюрпризы")
@export_range(0,1,0.01) var drone_surprise_chance:float=0.72
@export_range(0,0.2,0.005) var extra_soldier_chance:float=0.09

@export_group("Состав — индекс поля боя с нуля")
@export var vehicle_first_room:Dictionary={"buggy":1,"apc":2,"mortar":2,"tank":3}
@export var machine_weights:Array[float]=[0.0,0.35,0.7,3.0,6.0,9.0]
@export_group("Случайные дроны — отдельно от волн")
@export_range(1,60,0.5) var surprise_delay_min:float=18
@export_range(1,90,0.5) var surprise_delay_max:float=30
@export_range(1,4,1) var surprise_active_cap:int=2
