@tool
class_name EconomyTuning
extends Resource
@export_group("Постоянная прокачка")
@export_range(0,1000,1) var upgrade_base_cost:int=10
@export_range(0,1000,1) var upgrade_step_cost:int=3
@export var building_costs:Dictionary={"character":168,"weapons":120,"bonuses":144,"garage":120,"range":72}
@export var branch_unlock_costs:Dictionary={"health":0,"damage":168,"base":120,"heal":120,"recovery":168,"turret":144,"mobility":144,"rarity":216,"luck":144,"supplies":120}
@export_group("Дроп — вероятность от 0 до 1")
@export_range(0,1,0.001) var heart_chance:float=0.06
@export_range(0,1,0.001) var bonus_chance:float=0.12
@export_range(0,0.1,0.001) var luck_per_level:float=0.005
@export_group("Лечение и турель")
@export_range(0.1,20,0.05) var heal_amount:float=1
@export_range(0,2,0.01) var heal_per_level:float=0.15
@export_range(0.1,100,0.05) var turret_damage:float=2
@export_range(0,10,0.01) var turret_damage_per_level:float=0.05
@export_group("Сундук — награда сплавом")
@export_range(0,10000,5) var chest_alloy:int=60
@export_range(0,1000,5) var chest_alloy_per_room:int=25

@export_group("Поздняя игра — после первой победы над гигабоссом")
@export_range(1,1000,1) var second_ability_slot_documents:int=15
