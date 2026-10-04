@tool
class_name EconomyTuning
extends Resource
@export_group("Постоянная прокачка")
@export_range(0,1000,1) var upgrade_base_cost:int=10
@export_range(0,1000,1) var upgrade_step_cost:int=3
## Buildings: Арсенал (weapons), Стоянка (garage), Полигон (range); Штаб (headquarters) is set in Game._ready.
@export var building_costs:Dictionary={"weapons":120,"garage":120,"range":70}
@export var branch_unlock_costs:Dictionary={"health":0,"damage":170,"base":120,"heal":120,"recovery":170,"turret":140,"mobility":140,"rarity":220,"luck":140,"supplies":120}
@export_group("Дроп — вероятность от 0 до 1")
@export_range(0,1,0.001) var heart_chance:float=0.06
@export_range(0,1,0.001) var bonus_chance:float=0.12
@export_range(0,0.1,0.001) var luck_per_level:float=0.005
@export_group("Лечение и турель")
@export_range(0.1,20,0.05) var heal_amount:float=1
@export_range(0,2,0.01) var heal_per_level:float=0.15
@export_range(0.1,100,0.05) var turret_damage:float=2
@export_range(0,10,0.01) var turret_damage_per_level:float=0.05
@export_group("Доход за вылазку — темп до первого босса ≈2 ч, победа ≈3 ч")
## Множитель сплава за убийство (база из EncounterRules.KILL_ALLOY).
@export_range(0,20,0.05) var kill_alloy_scale:float=4.0
## Награда за зачищенное поле: база + шаг за каждую пройденную точку маршрута.
@export_range(0,500,1) var clear_reward:int=10
@export_range(0,200,1) var clear_reward_per_room:int=5
## Доля добытого за вылазку сплава, которая теряется при выбывании без страховки.
@export_range(0,1,0.01) var death_loss:float=0.4
@export_range(0,1,0.01) var death_loss_floor:float=0.2
@export_group("Сундук — награда сплавом")
@export_range(0,10000,5) var chest_alloy:int=60
@export_range(0,1000,5) var chest_alloy_per_room:int=25

@export_group("Пределы постоянной прокачки — ограничивает только цена")
@export_range(1,100,1) var branch_cap:int=20
@export_range(1,20,1) var supplies_cap:int=3
@export_range(1,20,1) var insurance_cap:int=4
@export_range(1,50,1) var weapon_level_cap:int=10
@export_range(1,20,1) var bonus_level_cap:int=5
@export_range(1,20,1) var hq_level_cap:int=5
@export_range(1,20,1) var vehicle_equipment_cap:int=5
@export_group("Жетоны — валюта забега для торговца")
@export_range(0,1,0.005) var token_chance:float=0.06
@export_range(0,1,0.005) var token_vehicle_chance:float=0.15
@export_range(0,1,0.005) var token_rank_bonus:float=0.10
@export_range(0,10,1) var token_commander:int=2

@export_group("Поздняя игра — после первой победы над гигабоссом")
@export_range(1,1000,1) var second_ability_slot_documents:int=15
