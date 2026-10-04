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
## Run-only merchant currency; lost when the run ends.
var tokens=0
var lost_alloy=0
var kills = 0
## Kills by enemy icon id (EnemyTypeIcon.IDS): the result screen lines them up.
var kills_by:Dictionary={}
var elapsed = 0.0
var weapon = "pistol"
var rerolls_left=0
var weapon_mods: Dictionary={}
var recovery_bonus=0.0
var run_bonus_levels:Dictionary={}
## Chest trophies (secret rewards) taken this sortie: [{type, id}] — shown in the tablet build block (T-246).
var trophies:Array=[]
var lost_run=false
var pending_recipes: Array=[]
var vehicle_mods={"buggy":{"damage":0.0,"hp":0.0,"speed":1.0,"rate":1.0},"apc":{"damage":0.0,"hp":0.0,"speed":1.0,"rate":1.0},"tank":{"damage":0.0,"hp":0.0,"speed":1.0,"rate":1.0}}
var pending_vehicle=""
var visited_services: Dictionary={} 
var intercept_chance = .70
var combat_rng = RandomNumberGenerator.new()

var route_choices:Dictionary={}

var range_multiplier=1.0
var healing_multiplier=1.0
var ability_power_multiplier=1.0
var ability_cooldown_multiplier=1.0
## Combat stats (CombatMods): fractions unless noted.
var crit_chance=.05
var crit_damage=1.5
var dodge=0.0
var guard_bullet=0.0
var guard_blast=0.0
var guard_vehicle=0.0
## Extra enemies a bullet passes through.
var pierce=0
var burn_chance=0.0
var shock_bonus=0.0
var stun_chance=0.0
## Effect strength (station «Жар/Разряд/Оглушение» and enhancement cards). They only matter once the
## base card of the effect gave a chance: hub upgrades never switch an effect on by themselves.
var burn_power=0.0
var burn_duration=0.0
var stun_duration=0.0
var shock_power=0.0
var stealth=0.0
var marauder=0.0
## HQ / vehicle HP restored per kill.
var field_repair=0.0
## Luck points from run cards (added to the station level).
var luck=0
## Backpack slots whose blueprints always survive a death (card «Сейф»).
var safe_slots=0

var behavior_cards:Array=[]
## Class path stats (ClassCatalog.PATHS) without a run card of their own: damage bonus within 2.5 cells, faster
## recharge of the class ability on Q, more armour on the hero's vehicles. Set at the start from the class level.
var close_damage=0.0
var class_cooldown=0.0
var vehicle_armor=0.0
## «Глаз-алмаз» (class perk): the bullets of the volley fired until this moment always crit.
var sure_crit_until=-10.0
## Ammo slots of the weapon (scripts/combat/ammo.gd): loaded types and the active one.
var ammo_slots:Array=[{"type":"standard","rarity":0,"stats":{},"damage":0.0,"twist":false}]
var ammo_active:=0
## Ammo items carried in the backpack (replaced or found), swapped in the gear screen.
var ammo_bag:Array=[]
## Supplies carried in the backpack (T-115): aid kits picked up at full health {type:"medkit", heal}.
var supplies:Array=[]
## Spare weapons carried for this run (backpack items {id, rarity, stats}); the one in hand is `weapon`.
var weapon_bag:Array=[]
## The gun in hand as an item: rarity and rolled stats from a weapon crate ({"damage": share, "fire": share}).
var weapon_rarity:=0
var weapon_stats:Dictionary={}
var last_player_shot=-10.0
var dash_until=0.0
var dash_ready_at=0.0
## Десант: bullets miss and crit is higher until this time.
var landing_until=0.0
## Выдержка: shots fired until this time carry the opening bonus (all pellets of one volley).
var opening_until=-10.0
## Softening bad moments: one lethal hit per run leaves the soldier at 1 HP.
var mercy_used=false
## Card screens in a row without a rare-or-better card; the third one guarantees a rare.
var dry_offers=0
## Kill series: kills within KILL_SERIES_WINDOW seconds of each other.
var series=0
## Run report («Вылазка», meta stage 2): best single hit, longest kill series, vehicles taken, damage taken.
var best_hit:=0.0
var best_series:=0
var captured:=0
var damage_taken:=0.0
var series_at=-10.0
