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

@export_group("Пределы постоянной прокачки — ограничивает только цена")
@export_range(1,100,1) var branch_cap:int=20
@export_range(1,20,1) var supplies_cap:int=3
@export_range(1,20,1) var insurance_cap:int=6
@export_range(1,50,1) var weapon_level_cap:int=10
@export_range(1,20,1) var bonus_level_cap:int=3
@export_range(1,20,1) var hq_level_cap:int=5
@export_range(1,20,1) var vehicle_equipment_cap:int=5
@export_group("Жетоны — валюта забега для торговца")
@export_range(0,1,0.005) var token_chance:float=0.06
@export_range(0,1,0.005) var token_vehicle_chance:float=0.15
@export_range(0,1,0.005) var token_rank_bonus:float=0.10
@export_range(0,10,1) var token_commander:int=2

@export_group("Поздняя игра — после первой победы над гигабоссом")
@export_range(1,1000,1) var second_ability_slot_documents:int=15
