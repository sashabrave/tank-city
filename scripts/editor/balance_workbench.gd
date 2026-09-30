@tool
extends Node
## Выбери этот узел, затем раскрой Balance в Inspector. Изменения ресурсов сохраняй Ctrl/Cmd+S и перезапускай игру.
@export var balance:GameBalance=preload("res://assets/balance/game_balance.tres")
func _get_configuration_warnings()->PackedStringArray:
	var warnings=PackedStringArray()
	if balance==null:return PackedStringArray(["Назначь assets/balance/game_balance.tres"])
	if balance.campaign.room_sizes.size()!=17 or balance.campaign.active_enemy_caps.size()!=17:warnings.append("В кампании должно оставаться 17 размеров полей боя и 17 лимитов врагов.")
	if balance.campaign.wave_counts.size()!=6 or balance.campaign.wave_budgets.size()!=6:warnings.append("Нужны 6 записей количества врагов и бюджета, по одной на поле боя первой зоны.")
	return warnings
