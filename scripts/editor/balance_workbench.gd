@tool
extends Node
## Выбери этот узел, затем раскрой Balance в Inspector. Изменения ресурсов сохраняй Ctrl/Cmd+S и перезапускай игру.
@export var balance:GameBalance=preload("res://assets/balance/game_balance.tres")
func _get_configuration_warnings()->PackedStringArray:
	var warnings=PackedStringArray()
	if balance==null:return PackedStringArray(["Назначь assets/balance/game_balance.tres"])
	var worlds=balance.campaign.world_health.size()
	if balance.campaign.world_damage.size()!=worlds or balance.campaign.world_boss_health.size()!=worlds:warnings.append("У каждого мира должны быть множитель здоровья, урона и здоровье босса.")
	return warnings
