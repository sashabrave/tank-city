extends RefCounted
## Mutable progression for one run. Only explicit progression fields are stored in room checkpoints.
var run_seed = 0
var upgrade_history:Array=[]
var soldier_hp = 3.0
var soldier_max_hp = 3
var damage_bonus = 0.0
var fire_multiplier = 1.0
var speed_multiplier = 1.0
var earned = 0
var lost_alloy=0
var kills = 0
var elapsed = 0.0
var weapon = "pistol"
var rerolls_left=0
var weapon_mods: Dictionary={}
var recovery_bonus=0.0
var run_bonus_levels:Dictionary={}
var lost_run=false
var pending_recipes: Array=[]
var vehicle_mods={"buggy":{"damage":0.0,"hp":0.0,"speed":1.0},"apc":{"damage":0.0,"hp":0.0,"speed":1.0},"tank":{"damage":0.0,"hp":0.0,"speed":1.0}}
var pending_vehicle=""
var visited_services: Dictionary={} 
var intercept_chance = .70
var combat_rng = RandomNumberGenerator.new()

var route_choices:Dictionary={}

var range_multiplier=1.0
var healing_multiplier=1.0
var ability_power_multiplier=1.0
var ability_cooldown_multiplier=1.0

var behavior_cards:Array=[]
var last_player_shot=-10.0
var dash_until=0.0
var dash_ready_at=0.0
