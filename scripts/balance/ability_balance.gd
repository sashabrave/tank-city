@tool
class_name AbilityBalance
extends Resource
@export_storage var id: String = "barrier"
@export var name: String = "Способность"
@export_range(0, 10000, 5, "or_greater") var price: int = 0
@export_range(1, 300, 0.5, "or_greater", "suffix:s") var cooldown: float = 33.0
@export_range(0.01, 100, 0.01, "or_greater") var power: float = 12.0
@export_multiline var description: String = "Описание способности"

func as_dict()->Dictionary:
	return {"name":name, "price":price, "cooldown":cooldown, "power":power, "description":description}
