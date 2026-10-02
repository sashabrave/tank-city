@tool
class_name CombatTuning
extends Resource
@export_group("Герой и база")
@export_range(1,100,1) var hero_health:int=3
@export_range(1,100,1) var base_health:int=5
@export_range(0.5,15,0.1) var hero_speed:float=3.8
@export_group("Враги II ранга")
@export_range(1,5,0.05) var rank_health:float=1.6
@export_range(1,5,0.05) var rank_damage:float=1.3
@export_range(1,5,0.05) var rank_pressure:float=1.2
@export_group("Боссы — суммарное здоровье")
@export_group("Способности и защита")
@export_range(1,120,0.5) var shield_cooldown:float=32
@export_range(0.1,1,0.01) var ability_cooldown_multiplier:float=0.82
@export_range(0,2,0.01) var ability_power_step:float=0.35
@export_range(0.1,30,0.1) var minimum_ability_cooldown:float=5
## Rate-of-fire ceiling: no card stack can push a shot interval below this (12.5 shots/s at .08).
@export_range(0.02,1,0.01) var minimum_fire_interval:float=0.08
@export_range(0.5,10,0.1) var grenade_radius:float=1.5
@export_range(0.1,5,0.1) var grenade_fuse:float=1
@export_range(0.01,1,0.01) var interception_base_scale:float=0.5
@export_range(0.1,20,0.1) var allied_turret_interval:float=2.4
@export_group("Пределы характеристик")
## Абсолютный предел скорости техники и бойца игрока, клеток в секунду.
@export_range(1,15,0.1) var player_speed_cap:float=5.2
## Предел множителя скорости бойца от карт забега.
@export_range(1,5,0.01) var speed_multiplier_cap:float=1.45
## Пределы шанса перехвата снарядов (напор).
@export_range(0,1,0.01) var interception_floor:float=0.05
@export_range(0,1,0.01) var interception_cap:float=0.9
@export_group("Сила наград")
## Множитель силы наград по тиру: обычная, редкая, эпическая.
@export var reward_tier_power:PackedFloat32Array=PackedFloat32Array([1.0,1.6,2.3,3.2])
@export_group("Ритм боя")
@export_range(0.5,15,0.25) var wave_delay:float=3.75
@export_range(0.1,15,0.1) var spawn_interval:float=2.4

@export_group("Взрыв уничтоженного дрона")
@export_range(0.1,3,0.1) var drone_death_damage:float=0.5
@export_range(0.2,3,0.05) var drone_death_radius:float=1.15
