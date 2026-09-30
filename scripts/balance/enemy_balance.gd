@tool
class_name EnemyBalance
extends Resource
@export_storage var id: String = "soldier"
@export_range(0.1, 3000, 0.1, "or_greater") var health: float = 2.0
@export_range(0, 20, 0.1) var move_speed: float = 2.5
@export_range(0.05, 100, 0.05, "suffix:s") var fire_interval: float = 1.45
@export_range(0, 100, 0.05, "or_greater") var damage: float = 1.0
@export_range(0, 100, 0.05, "or_greater") var enemy_damage: float = 1.0
@export_range(0.05, 100, 0.05, "suffix:s") var enemy_interval: float = 1.45
@export_range(0, 20, 0.1) var player_speed: float = 2.5
@export_range(0.01, 10, 0.01, "or_greater") var pressure: float = 1.0
@export_range(1, 100, 1) var wave_cost: int = 2

func _validate_property(property:Dictionary):
	# Boss health is centralized by campaign encounter in CombatTuning.
	if id=="boss" and property.name=="health":property.usage=PROPERTY_USAGE_STORAGE
