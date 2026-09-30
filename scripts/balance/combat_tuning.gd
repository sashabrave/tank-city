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
@export_range(1,10000,10) var first_boss_health:float=700
@export_range(1,10000,10) var second_boss_health:float=1100
@export_range(1,20000,10) var superboss_health:float=1600
@export_group("Способности и защита")
@export_range(1,120,0.5) var shield_cooldown:float=32
@export_range(1,30,0.5) var shield_minimum_cooldown:float=6
@export_range(0.1,1,0.01) var ability_cooldown_multiplier:float=0.82
@export_range(0,2,0.01) var ability_power_step:float=0.35
@export_range(0.1,30,0.1) var minimum_ability_cooldown:float=5
@export_range(0.5,10,0.1) var grenade_radius:float=1.5
@export_range(0.1,5,0.1) var grenade_fuse:float=1
@export_range(0.01,1,0.01) var interception_base_scale:float=0.5
@export_range(0.1,20,0.1) var allied_turret_interval:float=2.4
@export_group("Ритм боя")
@export_range(0.5,15,0.25) var wave_delay:float=3.75
@export_range(0.1,15,0.1) var spawn_interval:float=2.4

@export_group("Взрыв уничтоженного дрона")
@export_range(0.1,3,0.1) var drone_death_damage:float=0.5
@export_range(0.2,3,0.05) var drone_death_radius:float=1.15
