extends RefCounted
## Transient room state. Scene-owned nodes are invalidated during begin_room.
var room_cleared=false
var room_boss_spawned=false
var commander_countdown=false
var reward_claimed=false
var flag: Node3D
var flag_armed=true
var upgrade_offers: Array=[]
var trenches: Dictionary={} 
var grid_size = 13
var room_index = 0
var boss_room = false
var boss_defeated = false
var next_is_room = false
var reinforcement_timer = 9.2
var bombs: Array = []
var grenades: Array = []
var current_layout: Array = []
var previous_phase = "combat"
var wave = 0
var spawn_queue: Array = []
var spawn_timer = 0.0
var countdown = 4.5  # 0.8: the HQ drive-in, hop-out and wall beats finish before the fight
var wave_roster: Array = []
var wave_spawned = 0
var actors: Array = []
var wrecks: Array = []
var walls: Dictionary = {}
var pickups: Array = []
var player
var base_hp = 5.0
var base_max_hp = 5
var base_cell = Vector2i(5,9)
var base_model: Node3D
var base_label: Label3D
var base_bar: Sprite3D
var spawn_index = 0
var nets: Dictionary = {}
var recipe_offer: Dictionary={}
var draft_pickup: Dictionary={}
var generators:Dictionary={}
var freeze_time=0.0
var pressure_time=0.0
var twin_boss=false
var star_time=0.0
var projectiles: Array = []

var combat_elapsed=0.0
var surprise_timer=0.0
var surprise_initialized=false
var surprise_rng=RandomNumberGenerator.new()

var difficulty=0
## Route node type played in this room: battle or a challenge (cache…).
var mode="battle"
var route_node_id=""
var commander_elite=false
var commander
var commander_help_timer=0.0
var commander_help_waves=0
var commander_help_pool:Array=[]

var resource_drops:Array=[]

var spawn_markers:Array=[]

var generator_stage=0
var generator_order:Array=[]
var generator_thresholds:Array=[]
var generator_hp=18.0
var generator_guards=2
