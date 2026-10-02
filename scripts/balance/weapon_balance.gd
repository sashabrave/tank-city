@tool
class_name WeaponBalance
extends Resource
@export_storage var id: String = "pistol"
@export var name: String = "Оружие"
@export_enum("Обычное","Редкое","Эпическое") var rarity: int = 0
@export_range(0.01, 100, 0.01, "or_greater") var damage: float = 1.5
@export_range(0.03, 10, 0.01, "suffix:s") var interval: float = 0.6
@export_range(1, 100, 0.1) var speed: float = 16.0
@export_range(1, 100, 0.1) var range: float = 13.0
@export_range(1, 20, 1) var pellets: int = 1
## Shots per trigger pull (SMG bursts); the next pull waits `interval` from the first shot.
@export_range(1, 6, 1) var burst: int = 1
@export_range(0, 0.5, 0.01, "suffix:s") var burst_gap: float = 0.0
@export var pierce: bool = false
@export_range(0, 10, 0.1) var blast: float = 0.0
@export_range(0.01, 1, 0.01) var intercept: float = 0.8
@export var icon: String = "pistol"
@export_multiline var role: String = "Описание оружия"

func as_dict()->Dictionary:
	return {"name":name, "rarity":rarity, "damage":damage, "interval":interval, "speed":speed, "range":range, "pellets":pellets, "burst":burst, "burst_gap":burst_gap, "pierce":pierce, "blast":blast, "intercept":intercept, "icon":icon, "role":role}
