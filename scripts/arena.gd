extends Node3D
const LOOT=preload("res://scripts/loot_catalog.gd")
signal restart_requested
signal exit_requested
signal map_requested(index: int)
var run=preload("res://scripts/state/run_state.gd").new()
var room=preload("res://scripts/state/room_state.gd").new()

# Compatibility properties delegate to the single source of truth below.
var replay:Node
var room_cleared:
	get:return room.room_cleared
	set(value):room.room_cleared=value
var room_boss_spawned:
	get:return room.room_boss_spawned
	set(value):room.room_boss_spawned=value
var reward_claimed:
	get:return room.reward_claimed
	set(value):room.reward_claimed=value
var flag: Node3D:
	get:return room.flag
	set(value):room.flag=value
var flag_armed:
	get:return room.flag_armed
	set(value):room.flag_armed=value
var upgrade_offers: Array:
	get:return room.upgrade_offers
	set(value):room.upgrade_offers=value
var trenches: Dictionary:
	get:return room.trenches
	set(value):room.trenches=value

const DIRS = [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]
var ROOM_SIZES = Campaign.SIZES
const ROOM_WAVES = [
 [["soldier","soldier","soldier","soldier","soldier"],["soldier","soldier","soldier","grenadier","soldier","soldier"],["soldier","grenadier","soldier","buggy","soldier","buggy"]],
 [["soldier","buggy","grenadier","drone","soldier","buggy"],["buggy","grenadier","soldier","drone","buggy","grenadier","soldier"],["buggy","apc","soldier","grenadier","drone","apc","soldier"]],
 [["apc","grenadier","buggy","mortar","soldier","drone","apc"],["grenadier","apc","buggy","mortar","drone","apc","soldier","grenadier"],["apc","grenadier","mortar","drone","buggy","apc","tank","soldier"]],
 [["tank","apc","grenadier","drone","buggy","mortar","soldier","apc"],["tank","grenadier","buggy","mortar","apc","drone","tank","soldier","grenadier"],["tank","tank","apc","mortar","drone","buggy","grenadier","tank","apc"]],
 [["tank","apc","buggy","grenadier","mortar","drone","tank","grenadier","drone"],["tank","mortar","grenadier","buggy","tank","drone","apc","mortar","tank","grenadier"],["tank","tank","tank","tank","tank","tank","tank"]],
 [["tank","apc","flyer"],["tank","shield","drone"],["tank","tank","sniper"]],
 [["boss"]]
]
const BIOMES=preload("res://scripts/biome_catalog.gd")
var navigation=preload("res://scripts/systems/navigation_cache.gd").new(self)
func room_palette()->Dictionary:return BIOMES.ENTRIES[sandbox_biome] if sandbox and sandbox_biome>=0 else BIOMES.entry(run_seed,room_index)

var grid_size:
	get:return room.grid_size
	set(value):room.grid_size=value
var room_index:
	get:return room.room_index
	set(value):room.room_index=value
var run_seed:
	get:return run.run_seed
	set(value):run.run_seed=value
var boss_room:
	get:return room.boss_room
	set(value):room.boss_room=value
var boss_defeated:
	get:return room.boss_defeated
	set(value):room.boss_defeated=value
var next_is_room:
	get:return room.next_is_room
	set(value):room.next_is_room=value
var reinforcement_timer:
	get:return room.reinforcement_timer
	set(value):room.reinforcement_timer=value
var bombs: Array:
	get:return room.bombs
	set(value):room.bombs=value
var grenades: Array:
	get:return room.grenades
	set(value):room.grenades=value
var current_layout: Array:
	get:return room.current_layout
	set(value):room.current_layout=value
var phase:String:
	get:return flow.current
	set(value):flow.transition(value)
var previous_phase:
	get:return room.previous_phase
	set(value):room.previous_phase=value
var wave:
	get:return room.wave
	set(value):room.wave=value
var spawn_queue: Array:
	get:return room.spawn_queue
	set(value):room.spawn_queue=value
var spawn_timer:
	get:return room.spawn_timer
	set(value):room.spawn_timer=value
var countdown:
	get:return room.countdown
	set(value):room.countdown=value
var wave_roster: Array:
	get:return room.wave_roster
	set(value):room.wave_roster=value
var wave_spawned:
	get:return room.wave_spawned
	set(value):room.wave_spawned=value
var actors: Array:
	get:return room.actors
	set(value):room.actors=value
var wrecks: Array:
	get:return room.wrecks
	set(value):room.wrecks=value
var walls: Dictionary:
	get:return room.walls
	set(value):room.walls=value
var pickups: Array:
	get:return room.pickups
	set(value):room.pickups=value
var player:
	get:return room.player
	set(value):room.player=value
var hud
var headquarters
var camera: Camera3D
var presentation:Node
var base_hp:
	get:return room.base_hp
	set(value):room.base_hp=value
var base_max_hp:
	get:return room.base_max_hp
	set(value):room.base_max_hp=value
var base_cell:
	get:return room.base_cell
	set(value):room.base_cell=value
var base_model: Node3D:
	get:return room.base_model
	set(value):room.base_model=value
var base_label: Label3D:
	get:return room.base_label
	set(value):room.base_label=value
var base_bar: Sprite3D:
	get:return room.base_bar
	set(value):room.base_bar=value
var soldier_hp:
	get:return run.soldier_hp
	set(value):run.soldier_hp=value
var soldier_max_hp:
	get:return run.soldier_max_hp
	set(value):run.soldier_max_hp=value
var damage_bonus:
	get:return run.damage_bonus
	set(value):run.damage_bonus=value
var fire_multiplier:
	get:return run.fire_multiplier
	set(value):run.fire_multiplier=value
var speed_multiplier:
	get:return run.speed_multiplier
	set(value):run.speed_multiplier=value
var earned:
	get:return run.earned
	set(value):run.earned=value
var kills:
	get:return run.kills
	set(value):run.kills=value
var elapsed:
	get:return run.elapsed
	set(value):run.elapsed=value
var spawn_index:
	get:return room.spawn_index
	set(value):room.spawn_index=value
var toast_text = "Защищай базу. Техника появится в конце первой поля боя."
var toast_time = 5.0
var exiting = false
var auto_pause_enabled = true
var nets: Dictionary:
	get:return room.nets
	set(value):room.nets=value
var weapon:
	get:return run.weapon
	set(value):run.weapon=value
var rerolls_left:
	get:return run.rerolls_left
	set(value):run.rerolls_left=value
var recipe_offer: Dictionary:
	get:return room.recipe_offer
	set(value):room.recipe_offer=value
var draft_pickup: Dictionary:
	get:return room.draft_pickup
	set(value):room.draft_pickup=value
var weapon_mods: Dictionary:
	get:return run.weapon_mods
	set(value):run.weapon_mods=value
var recovery_bonus:
	get:return run.recovery_bonus
	set(value):run.recovery_bonus=value
var generators:Dictionary:
	get:return room.generators
	set(value):room.generators=value
var run_bonus_levels:Dictionary:
	get:return run.run_bonus_levels
	set(value):run.run_bonus_levels=value
var freeze_time:
	get:return room.freeze_time
	set(value):room.freeze_time=value
var pressure_time:
	get:return room.pressure_time
	set(value):room.pressure_time=value
var lost_run:
	get:return run.lost_run
	set(value):run.lost_run=value
var twin_boss:
	get:return room.twin_boss
	set(value):room.twin_boss=value
var star_time:
	get:return room.star_time
	set(value):room.star_time=value
var pending_recipes: Array:
	get:return run.pending_recipes
	set(value):run.pending_recipes=value
var abilities
var vehicle_mods:
	get:return run.vehicle_mods
	set(value):run.vehicle_mods=value
var pending_vehicle:
	get:return run.pending_vehicle
	set(value):run.pending_vehicle=value
var visited_services: Dictionary:
	get:return run.visited_services
	set(value):run.visited_services=value
var intercept_chance:
	get:return run.intercept_chance
	set(value):run.intercept_chance=value
var projectiles: Array:
	get:return room.projectiles
	set(value):room.projectiles=value
var combat_rng:
	get:return run.combat_rng
	set(value):run.combat_rng=value


# Systems share this scene context; they do not own or free the scene.
var reward=preload("res://scripts/systems/reward_system.gd").new(self)
var vehicle=preload("res://scripts/systems/vehicle_system.gd").new(self)
var combat=preload("res://scripts/systems/combat_system.gd").new(self)
var enemy=preload("res://scripts/systems/enemy_system.gd").new(self)
var boss=preload("res://scripts/systems/boss_system.gd").new(self)
var board=preload("res://scripts/systems/board_system.gd").new(self)
var terrain=preload("res://scripts/systems/terrain_system.gd").new(self)
var surprises=preload("res://scripts/systems/surprise_system.gd").new(self)
var flow=preload("res://scripts/systems/flow_system.gd").new(self)
## Run event bus: card effects react to events and adjust live values (see scripts/upgrades/run_effects.gd).
var effects=preload("res://scripts/upgrades/run_effects.gd").new(self)
var challenges=preload("res://scripts/systems/challenge_rooms.gd").new(self)

var resume_checkpoint:Dictionary={}
## Sandbox (test field from the hub): overrides applied by begin_room; the admin panel sets them.
## Resume to the route map: restore the run but build no battle room until a room is entered.
var defer_room=false
var sandbox=false
var sandbox_size=0
var sandbox_mode="battle"
var sandbox_difficulty=0
var sandbox_biome=-1
var sandbox_waves=false
func _ready():
	set_meta("start_documents",Game.cores)
	ResourceStrip.track_run(run)
	weapon=Game.selected_weapon;rerolls_left=3+Game.reroll_level
	for id in LOOT.WEAPONS:weapon_mods[id]={"damage":0.0,"interval":1.0,"intercept":0.0}
	abilities=load("res://scripts/run_ability.gd").new();abilities.arena=self;abilities.selected=Game.selected_ability;abilities.setup()
	if run_seed==0:run_seed=randi()
	# Daily runs: fights and offers follow the day's seed; normal runs stay unpredictable.
	if Campaign.daily:combat_rng.seed=hash([run_seed,"combat"])
	else:combat_rng.randomize()
	headquarters=load("res://scripts/headquarters/run_support.gd").new(self)
	base_max_hp=headquarters.max_hp()
	soldier_max_hp = CombatStats.initial_health()
	soldier_hp = soldier_max_hp
	speed_multiplier=CombatStats.initial_speed_multiplier()
	StatRegistry.apply_meta(run)
	ClassCatalog.apply_start(run)
	camera = Visuals.setup_world(self,15.5,Vector3.ZERO)
	hud = load("res://scenes/hud.tscn").instantiate()
	hud.arena = self
	add_child(hud)
	presentation=load("res://scripts/battle_presentation.gd").new();presentation.arena=self;add_child(presentation)
	pending_vehicle=Game.garage.starting_vehicle()
	if not resume_checkpoint.is_empty():preload("res://scripts/profile/run_checkpoint.gd").restore(self,resume_checkpoint)
	if defer_room:return
	begin_room(int(resume_checkpoint.index) if not resume_checkpoint.is_empty() else 0)

func begin_room(index: int):
	Game.progression.combat_entered=true
	if Campaign.daily:combat_rng.seed=DailyRun.room_seed(run_seed,Campaign.cycle,index)
	effects.emit("room_start",{"index":index})
	Game.music_context("boss" if index in Campaign.BOSSES else "battle",true)
	star_time=0.0;recipe_offer={};draft_pickup={};generators.clear()
	var carried_kind="soldier"
	var carried_armor=0.0
	var carried_salvaged=false
	var carried_origin="owned"
	var carried_zone=1
	if is_instance_valid(player) and not player.dead:
		carried_kind=player.kind;carried_armor=player.hp;carried_salvaged=player.salvaged;carried_origin=player.vehicle_origin;carried_zone=player.vehicle_zone
	if not resume_checkpoint.is_empty() and not resume_checkpoint.hero.is_empty():
		var hero=resume_checkpoint.hero
		carried_kind=hero.kind;carried_armor=hero.hp;carried_salvaged=hero.salvaged;carried_origin=hero.origin;carried_zone=int(hero.zone)
	resume_checkpoint={}
	if pending_vehicle!="":carried_kind=pending_vehicle;carried_armor=0;carried_salvaged=false;carried_origin="owned";pending_vehicle=""
	# Drop references to the previous room's HQ before freeing it: a boss room builds no label or bar,
	# and a stale typed reference to a freed node crashes the exported build.
	room.base_model=null;room.base_label=null;room.base_bar=null
	preload("res://scripts/battle_stage.gd").stop(self)
	for child in get_children():
		if child==presentation or child==hud or child==camera or child is WorldEnvironment or child is DirectionalLight3D or child.name in ["WorldLighting","WorldAtmosphere","SandboxAdmin"]:continue
		remove_child(child);child.queue_free()
	if room.has_meta("pending_flag"):room.remove_meta("pending_flag")
	room.commander_countdown=false;room_cleared=false;room_boss_spawned=false;reward_claimed=false;flag=null;flag_armed=true;upgrade_offers.clear();trenches.clear()
	room.resource_drops.clear();actors.clear();wrecks.clear();walls.clear();pickups.clear();nets.clear();projectiles.clear();bombs.clear();grenades.clear()
	twin_boss=index in Campaign.BOSSES and BossCatalog.encounter(run_seed,index).count==2
	var route_node=RoutePlan.chosen(RoutePlan.build(run_seed),index,run.route_choices)
	room.difficulty=route_node.difficulty;room.route_node_id=route_node.id
	room.mode=route_node.get("type","battle") if route_node.get("type","battle") in RoutePlan.CHALLENGES else "battle"
	if sandbox:room.mode=sandbox_mode;room.difficulty=sandbox_difficulty;room.commander_elite=sandbox_difficulty>0
	challenges.reset()
	room.commander_elite=room.difficulty>0 or Campaign.challenge_level()>=3
	room.commander=null;room.commander_help_timer=0;room.commander_help_waves=0;room.commander_help_pool.clear()
	room_index=index;grid_size=ROOM_SIZES[index];boss_room=index in Campaign.BOSSES;boss_defeated=false
	if sandbox and sandbox_size>0 and not boss_room:grid_size=sandbox_size
	# The dark maze is a big field, like the boss arena: the largest size of this world.
	if room.mode=="maze" and not (sandbox and sandbox_size>0):grid_size=ROOM_SIZES.max()
	base_cell=Vector2i(int(grid_size/2),grid_size-1)
	headquarters.room_started()
	reinforcement_timer=9.2
	room.combat_elapsed=0.0;room.surprise_initialized=false;room.surprise_timer=0.0
	room.generator_stage=0;room.generator_order.clear();room.generator_thresholds.clear()
	camera.size=grid_size+5.0
	_build_map()
	preload("res://scripts/world_lighting.gd").field(self)
	preload("res://scripts/systems/block_decor.gd").decorate(self)
	var weather=preload("res://scripts/systems/weather.gd").new();add_child(weather);weather.setup(self)
	if get_node_or_null("CombatFeel")==null:
		var feel=preload("res://scripts/combat/combat_feel.gd").new();add_child(feel);feel.setup(self)
	var old_crates=get_node_or_null("FieldCrates")
	if old_crates:old_crates.name="FieldCratesOld";old_crates.queue_free()
	# Containers first, so crates lean against them and never end up inside.
	var dressing=preload("res://scripts/systems/field_dressing.gd").new();add_child(dressing);dressing.setup(self)
	var crates=preload("res://scripts/systems/field_crates.gd").new();add_child(crates);crates.setup(self)
	preload("res://scripts/systems/floor_ao.gd").build_for(self)
	preload("res://scripts/world_lighting.gd").reflection_probe(self,Vector3(grid_size+4,6,grid_size+4))
	var previous=get_node_or_null("BiomeParticles")
	if previous:previous.name="BiomeParticlesOld";previous.queue_free()
	var drifting=preload("res://scripts/systems/biome_particles.gd").new();add_child(drifting);drifting.setup(self,weather)
	get_node("WorldLighting").apply()
	get_node("WorldAtmosphere").battle_clouds(grid_size,Game.visual_run_seed+index*131)
	get_node("WorldAtmosphere").apply()
	var ambience=load("res://scripts/location_ambience.gd").new()
	ambience.seed_value=Game.visual_run_seed;ambience.room_index=index;ambience.biome=room_palette().ambience;ambience.radius=grid_size*.5;add_child(ambience)
	player=spawn_actor(carried_kind,Vector2i(base_cell.x,grid_size-2 if boss_room else grid_size-3),true,false,1,false,"",carried_origin,carried_zone)
	player.salvaged=carried_salvaged
	# A short spawn grace covers the arrival; the soldier shimmers and the HUD shows the chip.
	player.invulnerable=2.4
	if carried_kind!="soldier" and carried_armor>0:player.hp=minf(carried_armor,player.max_hp);player.refresh_health()
	toast("Атакуй босса. При включении щита уничтожь светящийся генератор." if Campaign.is_final(room_index) else "Бой с генералом. Когда включится щит, уничтожь светящийся генератор на фланге." if boss_room else "")
	preload("res://scripts/effect_warmup.gd").run(self)
	# HQ arrives on an arc, the soldier steps out, the brick defence builds up; visual only.
	preload("res://scripts/battle_stage.gd").intro(self)
	if challenges.active():challenges.start();phase="combat"
	elif sandbox and not sandbox_waves and not boss_room:room.spawn_queue.clear();room.wave_roster.clear();phase="combat"
	else:start_wave(0)
	if boss_room:drop_pickup(Vector2i(base_cell.x-3,grid_size-2),"vehicle")

func world_pos(cell: Vector2i) -> Vector3:
	var center=(grid_size-1)*.5
	return Vector3(cell.x-center,0,cell.y-center)

func grid_pos(pos: Vector3) -> Vector2i:
	var center=(grid_size-1)*.5
	return Vector2i(roundi(pos.x+center),roundi(pos.z+center))

func inside(cell: Vector2i) -> bool:
	return cell.x>=0 and cell.y>=0 and cell.x<grid_size and cell.y<grid_size

func _build_map():
	navigation.reset()
	set_meta("environment_wall",Color(room_palette().wall))
	set_meta("environment_brick",Color(room_palette().brick))
	for child in get_children():
		if child.name=="WorldLighting":
			child.day_background=Color("bec3b8").lerp(Color(room_palette().floor),.35);child.apply()
	preload("res://scripts/field_border.gd").build(self)
	var layout={} if boss_room else BattleMapGenerator.generate(run_seed+room_index*100003,room_index,false,grid_size)
	terrain.patches.clear()
	set_meta("environment_floor",Color(room_palette().floor))
	if boss_room:
		current_layout=[]
		for y in range(grid_size):current_layout.append(".".repeat(grid_size))
		# Seeded cover islands on the flanks leave room for the 4x4 boss.
		var cover_rng=RandomNumberGenerator.new();cover_rng.seed=run_seed+300009+room_index*991+Campaign.world*7919
		for side in [0,1]:
			for band in [0,1]:
				var x=cover_rng.randi_range(1,3) if side==0 else grid_size-cover_rng.randi_range(3,5)
				var y=cover_rng.randi_range(3,5) if band==0 else grid_size-cover_rng.randi_range(5,7)
				var cluster=[Vector2i(x,y),Vector2i(x+1,y)]
				if side!=band:cluster.append(Vector2i(x,y+1))
				if side==0 and band==0:cluster.append(Vector2i(x+1,y+1))
				for cell in cluster:
					BattleMapGenerator.put(current_layout,cell,"B")
		BattleMapGenerator.thin_obstacles(current_layout,run_seed+room_index*991,false)
		board.reinforce_layout(current_layout)
		for z in range(grid_size):
			for x in range(grid_size):
				if current_layout[z][x]=="B":add_wall(Vector2i(x,z),4)
				elif current_layout[z][x]=="K":board.add_reinforced_wall(Vector2i(x,z),16)
		if Campaign.unified_content():board.corner_barrels(current_layout)
		board.shape_map_walls()
		terrain.build()
		spawn_generators()
		base_model=Visuals.model("base",self,world_pos(base_cell));base_model.rotation.y=preload("res://scripts/mobile_hq.gd").orientation(run_seed+room_index*719)
		return
	current_layout=layout.rows
	if room.mode!="battle":ChallengeLayouts.apply(current_layout,grid_size,room.mode,run_seed+room_index*977,room.difficulty)
	elif Campaign.zone(room_index)>=2:ruin_layout(current_layout)
	elif Campaign.unified_content():board.scatter_barrels(current_layout)
	if room.mode=="battle":
		BattleMapGenerator.thin_obstacles(current_layout,run_seed+room_index*100003)
		board.reinforce_layout(current_layout)
	for x in spawn_columns():
		create_spawn_marker(Vector2i(x,0),Vector2i.DOWN)
	for z in range(grid_size):
		for x in range(grid_size):
			var cell=Vector2i(x,z)
			match layout.rows[z][x]:
				"X":add_barrel(cell)
				"R":add_rubble(cell)
				"B":add_wall(cell,3)
				"K":board.add_reinforced_wall(cell,12)
				"C":add_wall(cell,-1)
				"T":add_trench(cell)
				"N":nets[cell]=Visuals.model("net",self,world_pos(cell))
	board.shape_map_walls()
	terrain.build()
	base_model=Visuals.model("base",self,world_pos(base_cell));base_model.rotation.y=preload("res://scripts/mobile_hq.gd").orientation(run_seed+room_index*719)
	base_label=Visuals.label3d(self,"База",world_pos(base_cell)+Vector3(0,2.75,0),Color("f8e1b0"),30)

	base_bar=load("res://scripts/health_bar_3d.gd").new();add_child(base_bar);base_bar.position=world_pos(base_cell)+Vector3.UP*2.45
	base_bar.set_health(base_hp,base_max_hp)

func actor_world_pos(actor,cell: Vector2i) -> Vector3:
	return world_pos(cell)+Vector3.ONE*Vector3((actor.footprint-1)*.5,0,(actor.footprint-1)*.5)

func cells_for(actor,cell: Vector2i) -> Array:
	var result=[]
	for x in range(actor.footprint):
		for y in range(actor.footprint):result.append(cell+Vector2i(x,y))
	return result

func add_wall(cell: Vector2i, hp: int):
	return board.add_wall(cell, hp)

func can_enter(cell: Vector2i,actor=null) -> bool:
	var footprint=1 if actor==null else actor.footprint
	for x in range(footprint):
		for y in range(footprint):
			var p=cell+Vector2i(x,y)
			if not inside(p) or terrain.movement_blocked_at_cell(p) or generators.has(p) or walls.has(p) or (trenches.has(p) and (actor==null or actor.player_owned or actor.kind!="soldier" or not board.trench_available(p,actor))) or (not boss_room and p==base_cell):return false
			for other in actors:
				if other==actor or not is_instance_valid(other) or other.dead or other.kind=="flyer":continue
				if p in cells_for(other,other.cell) or (other.moving and p in cells_for(other,other.destination)):return false
			for wreck in wrecks:
				if is_instance_valid(wreck) and not wreck.spent and wreck.cell==p:return false
	return true

func spawn_actor(kind: String, cell: Vector2i, owned: bool, allied=false,rank: int=1,surprise:bool=false,loadout:String="",vehicle_origin:String="owned",vehicle_zone:int=1):
	var actor = load("res://scenes/"+kind+".tscn").instantiate()
	actor.vehicle_origin=vehicle_origin;actor.vehicle_zone=vehicle_zone
	actor.rank=rank;actor.surprise_spawn=surprise;actor.enemy_weapon=loadout
	if not owned and not allied:actor.chevrons=Professionalism.tier(room_index)
	actor.arena = self
	actor.player_owned = owned
	actor.allied = allied
	actor.cell = cell
	actor.destination = cell
	actor.footprint=BossCatalog.encounter(run_seed,room_index).footprint if kind=="boss" else 1
	actor.position = actor_world_pos(actor,cell)
	add_child(actor)
	actors.append(actor)
	if not owned and not allied and phase in ["combat","countdown"]:entry_animation(actor)
	if not owned and not allied and kind not in ["boss","drone","mortar","sniper","flyer"]:
		for band in [int(grid_size*.35),int(grid_size*.65)]:
			var options=[]
			for x in range(1,grid_size-1):
				if not walls.has(Vector2i(x,band)) and not terrain.movement_blocked_at_cell(Vector2i(x,band)) and not trenches.has(Vector2i(x,band)) and absi(x-cell.x)<=maxi(3,int(grid_size*.2)):options.append(Vector2i(x,band))
			if not options.is_empty():actor.route_points.append(options[combat_rng.randi_range(0,options.size()-1)])
	if not owned and not allied:
		actor.aim_delay_time=Professionalism.of(self,"aim_delay");actor.pause_scale=Professionalism.of(self,"pause")
	if kind=="soldier" and not owned and not trenches.is_empty() and combat_rng.randf()<Professionalism.of(self,"trench_share"):
		actor.route_points=[trenches.keys()[combat_rng.randi_range(0,trenches.size()-1)]]
	if kind=="drone":actor.flank=-1 if cell.x<grid_size/2 else 1
	preload("res://scripts/status_fx.gd").of(actor)
	return actor

## Nothing pops in: infantry drops onto its cell with a small bounce, vehicles roll in from beyond the
## edge, drones descend. Visual only — the actor's cell and logic are in place at once.
func entry_animation(actor):
	if not is_instance_valid(actor.model) or actor.kind=="boss":return
	var model:Node3D=actor.model;var rest=model.position
	var tween=actor.create_tween()
	if actor.kind in Visuals.INFANTRY:
		model.position=rest+Vector3(0,1.7,0);model.scale=Vector3.ONE*.85
		tween.tween_property(model,"position",rest,.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(model,"scale",Vector3.ONE,.28)
		tween.tween_callback(func():if is_instance_valid(actor):burst(actor.position,Color("d8cfb4"),.35))
	elif actor.kind in ["drone","flyer"]:
		model.position=rest+Vector3(0,3.0,0)
		tween.tween_property(model,"position",rest,.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		var back=Vector3(-actor.facing.x,0,-actor.facing.y)*1.4
		model.position=rest+back
		tween.tween_property(model,"position",rest,.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
func start_wave(index: int):
	return flow.start_wave(index)

func _unhandled_input(event):
	if phase in ["combat","countdown","paused"] and event.is_action_pressed("pause") and not event.is_echo():
		get_viewport().set_input_as_handled()
		pause_battle()

func _physics_process(delta):
	if phase=="combat" and run!=null:effects.emit("tick",{"delta":delta})
	if phase == "countdown":
		var before=ceili(countdown)
		countdown -= delta
		if room.commander_countdown and ceili(countdown)!=before and countdown>0:presentation.announce("Командир · %d" % ceili(countdown),"",.65)
		if countdown <= 0:
			phase = "combat"
			if room.commander_countdown:room.commander_countdown=false;spawn_room_boss()
		# The pause between waves is not a freeze (T-020, T-053): time runs, so bonuses keep falling, and the
		# soldier can shoot and use abilities while the next wave gets ready.
		elapsed+=delta
		abilities.tick(delta)
		for slot in range(abilities.slots.size()):
			if Input.is_action_just_pressed(Game.ability_action(slot)):abilities.cast_slot(slot)
		if Input.is_action_just_pressed("ammo_switch") and Ammo.switch(self):hud.refresh_ammo()
		collect_nearby_pickups(delta)
		return
	if phase != "combat": return
	freeze_time=maxf(0,freeze_time-delta);pressure_time=maxf(0,pressure_time-delta)
	star_time=maxf(0,star_time-delta)
	abilities.tick(delta)
	headquarters.tick(delta)
	if Input.is_action_just_pressed("hq_ability"):headquarters.cast()
	if Input.is_action_just_pressed("ammo_switch") and Ammo.switch(self):hud.refresh_ammo()
	for slot in range(abilities.slots.size()):
		if Input.is_action_just_pressed(Game.ability_action(slot)):abilities.cast_slot(slot)
	elapsed += delta
	room.combat_elapsed += delta
	toast_time = maxf(0,toast_time-delta)
	boss.tick_commander_help(delta)
	surprises.tick(delta)
	spawn_timer -= delta
	if not spawn_queue.is_empty() and spawn_timer<=0 and wave_enemy_count()<Campaign.active_cap(room_index):
		var next_kind=spawn_queue[0]
		var entries=WaveDirector.spawn_cells(grid_size,room.wave,spawn_columns())
		var spawn=entries[spawn_index%entries.size()]
		if next_kind=="drone":spawn=Vector2i(0 if spawn_index%2==0 else grid_size-1,0)
		if next_kind=="boss":spawn=Vector2i((4 if wave_spawned==0 else grid_size-6) if twin_boss else int(grid_size/2)-2,0)
		if next_kind=="flyer" or can_enter(spawn):
			var enemy=spawn_actor(spawn_queue.pop_front(),spawn,false,false,wave_roster[wave_spawned].rank,false,wave_roster[wave_spawned].get("weapon",""))
			enemy.wave_slot=wave_spawned;wave_roster[wave_spawned].state="active";wave_spawned+=1
			spawn_index+=1;spawn_timer=Balance.CONFIG.combat.spawn_interval
		else:spawn_index+=1;spawn_timer=.35
	collect_nearby_pickups(delta)
	if challenges.active():challenges.tick(delta)
	if room_cleared and is_instance_valid(flag) and is_instance_valid(player):
		var near=flat_distance(player.position,flag.position)<1.1
		if not near:flag_armed=true
		if near and flag_armed:open_flag()
	if not room_cleared and spawn_queue.is_empty() and enemy_count()==0 and grenades.is_empty() and not challenges.blocks_waves() and not (sandbox and not sandbox_waves and not boss_room):
		finish_wave()

func wave_enemy_count()->int:
	return actors.filter(func(actor):return is_instance_valid(actor) and not actor.player_owned and not actor.allied and not actor.dead and actor.kind not in ["drone","flyer"]).size()

func enemy_count() -> int:
	var count=0
	for actor in actors:
		if is_instance_valid(actor) and not actor.player_owned and not actor.allied and not actor.dead: count+=1
	return count

func aligned_direction(from: Vector2i, to: Vector2i) -> Vector2i:
	var diff = to-from
	if diff == Vector2i.ZERO: return Vector2i.ZERO
	if diff.x==0: return Vector2i(0,signi(diff.y))
	if diff.y==0: return Vector2i(signi(diff.x),0)
	return Vector2i.ZERO

func clear_line(from: Vector2i,to: Vector2i) -> bool:
	if aligned_direction(from,to)==Vector2i.ZERO:return false
	return clear_shot(world_pos(from),world_pos(to))

func enemy_aim(actor) -> Vector2i:
	return enemy.enemy_aim(actor)

func path_direction(actor) -> Vector2i:
	return enemy.path_direction(actor)

func spawn_bullet(owner_actor,pos: Vector3,dir: Vector2i,damage: float,friendly: bool):
	return combat.spawn_bullet(owner_actor, pos, dir, damage, friendly)

func bullet_hit(bullet) -> bool:
	return combat.bullet_hit(bullet)

func flat_distance(a: Vector3,b: Vector3) -> float:
	return Vector2(a.x,a.z).distance_to(Vector2(b.x,b.z))

func damage_wall(cell: Vector2i, amount: float):
	return board.damage_wall(cell, amount)

func damage_base(amount: float):
	return combat.damage_base(amount)

func actor_destroyed(actor):
	return combat.actor_destroyed(actor)

func find_free_near(cell: Vector2i) -> Vector2i:
	for dir in DIRS:
		if can_enter(cell+dir): return cell+dir
	for radius in range(2,grid_size*2):
		for y in range(grid_size):
			for x in range(grid_size):
				var p=Vector2i(x,y)
				if absi(p.x-cell.x)+absi(p.y-cell.y)==radius and can_enter(p): return p
	return Vector2i(base_cell.x,grid_size-3)

func make_wreck(kind: String,cell: Vector2i,facing: Vector2i,unstable: bool,armor=0,origin:String="owned",zone:int=1):
	return vehicle.make_wreck(kind, cell, facing, unstable, armor,origin,zone)

func nearest_wreck():
	return vehicle.nearest_wreck()

func interact():
	if phase not in ["combat","countdown"] or not is_instance_valid(player) or player.moving: return
	var recipe=nearest_recipe()
	if not recipe.is_empty():open_recipe_draft(recipe);return
	if not challenges.nearest_cache().is_empty():challenges.open_cache();return
	if room_cleared and is_instance_valid(flag) and flat_distance(player.position,flag.position)<1.8:
		open_flag();return
	if player.kind=="soldier" and board.interact_trench():return
	vehicle.interact_vehicle()

func explosion(pos: Vector3,amount: float):
	return combat.explosion(pos, amount)

func burst(pos: Vector3,color: Color,radius: float):
	# Visual randomness is isolated from combat_rng and gameplay outcomes.
	preload("res://scripts/combat_effect.gd").spawn(self,pos,color,radius)

func drop_pickup(_cell: Vector2i,kind: String):
	return reward.drop_pickup(_cell, kind)

func collect_pickup(pickup: Dictionary):
	return reward.collect_pickup(pickup)

func toast(text: String):
	toast_text=text;toast_time=3.5
	Game.notifications.post(text)

func finish_wave():
	return flow.finish_wave()

func apply_upgrade(id: String,tier: int=0):
	return reward.apply_upgrade(id, tier)

func finish_run(won: bool,reason: String):
	return flow.finish_run(won, reason)

func pause_battle():
	return flow.pause_battle()

func _notification(what):
	if auto_pause_enabled and what==NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(hud) and phase in ["combat","countdown"]: pause_battle()

func leave():
	if exiting: return
	exiting=true
	Game.reset_input()
	exit_requested.emit()

func resolve_interception(a, b):
	return combat.resolve_interception(a, b)

func unlocked_vehicle() -> String:
	return vehicle.unlocked_vehicle()

func drone_step(actor):
	return enemy.drone_step(actor)

func boss_step(actor,delta: float):
	return boss.boss_step(actor, delta)

func spawn_free_bullet(actor,travel: Vector3,damage: float,speed: float,orb: bool):
	return combat.spawn_free_bullet(actor, travel, damage, speed, orb)

func boss_radial_attack(actor):
	return boss.boss_radial_attack(actor)

func throw_grenade(actor,target: Vector3):
	return combat.throw_grenade(actor, target)

func grenade_explosion(pos: Vector3,amount: float,friendly: bool,blast_radius: float=0.0):
	return combat.grenade_explosion(pos, amount, friendly, blast_radius)

func mortar_step(actor):
	return enemy.mortar_step(actor)

func install_turret():
	return vehicle.install_turret()

func open_flag():
	return flow.open_flag()

func return_to_field():
	return flow.return_to_field()

func depart_room():
	return flow.depart_room()

func floating_number(pos: Vector3,amount: float):
	if is_zero_approx(amount):return
	var number=Visuals.label3d(self,("+" if amount>0 else "")+str(snappedf(amount,.01)),pos+Vector3.UP*1.7,Color("8fe895") if amount>0 else Color("fff0da"),33)
	var tween=create_tween().set_parallel(true)
	tween.tween_property(number,"position:y",number.position.y+.9,.75)
	tween.tween_property(number,"modulate:a",0.0,.75)
	tween.chain().tween_callback(number.queue_free)

func shred_net(cell: Vector2i):
	return board.shred_net(cell)

func add_trench(cell: Vector2i):
	return board.add_trench(cell)

func sniper_step(actor,delta: float):
	return enemy.sniper_step(actor, delta)

func spawn_room_boss():
	return boss.spawn_room_boss()

func elite_step(actor,delta: float):
	return boss.elite_step(actor, delta)

func add_barrier(cell: Vector2i,hp: float):
	return board.add_barrier(cell, hp)

func flyer_target(actor):
	return enemy.flyer_target(actor)

func flyer_step(actor,delta: float):
	return enemy.flyer_step(actor, delta)

func current_intercept() -> float:
	return combat.current_intercept()

func player_pressure()->float:
	return combat.player_pressure()

func can_extract_recipes() -> bool:
	return reward.can_extract_recipes()

func resolve_recipes_on_return():
	return reward.resolve_recipes_on_return()

func recipe_summary() -> String:
	return reward.recipe_summary()

func fire_weapon(actor):
	return combat.fire_weapon(actor)

func rocket_impact(bullet):
	return combat.rocket_impact(bullet)

func drop_recipe(cell: Vector2i,_recipe: Dictionary):
	return reward.drop_recipe(cell, _recipe)

func nearest_recipe() -> Dictionary:
	return reward.nearest_recipe()

func open_recipe_draft(pickup: Dictionary):
	return reward.open_recipe_draft(pickup)

func reroll_recipe_draft():
	return reward.reroll_recipe_draft()

func choose_recipe_card(index: int):
	return reward.choose_recipe_card(index)

func apply_trophy_upgrade(id: String,tier: int):
	return reward.apply_trophy_upgrade(id, tier)

func discard_recipe(index: int):
	return reward.discard_recipe(index)

func take_offered_recipe():
	return reward.take_offered_recipe()

func reroll_cards() -> bool:
	return reward.reroll_cards()

func collect_nearby_pickups(delta):
	return reward.collect_nearby_pickups(delta)

func allied_flyer_step(actor,delta):
	return vehicle.allied_flyer_step(actor, delta)

func chest_offers()->Array:
	return reward.chest_offers()

func apply_secret(offer):
	return reward.apply_secret(offer)

func consume_chest(chest):
	return reward.consume_chest(chest)

func bonus_strength(id:String)->float:
	return reward.bonus_strength(id)

func effective_bonus_level(id:String)->int:
	return reward.effective_bonus_level(id)

func spawn_columns()->Array:
	return [1,int(grid_size/3.0),int(grid_size*2/3.0),grid_size-2] if Campaign.zone(room_index)>=2 else [1,base_cell.x,grid_size-2]
func ruin_layout(rows:Array):
	return board.ruin_layout(rows)

func add_barrel(cell):
	return board.add_barrel(cell)

func add_rubble(cell):
	return board.add_rubble(cell)

func explode_barrel(cell):
	return board.explode_barrel(cell)

func spawn_generators():
	return boss.spawn_generators()

func damage_generator(cell,amount):
	return boss.damage_generator(cell, amount)

func boss_extra_attacks(actor,delta):
	return boss.boss_extra_attacks(actor, delta)

func summon_comrade(factor:float,utility:float):
	return vehicle.summon_comrade(factor, utility)

func comrade_step(buddy,delta):
	return vehicle.comrade_step(buddy, delta)

func fire_comrade_weapon(buddy):
	return vehicle.fire_comrade_weapon(buddy)

func create_spawn_marker(cell:Vector2i,direction:Vector2i)->Node3D:
	var marker=Node3D.new();add_child(marker);marker.position=world_pos(cell)
	Visuals.box(marker,Vector3(0,.01,0),Vector3(.8,.025,.8),Color("b97150"))
	var arrow="▼" if direction==Vector2i.DOWN else "▶" if direction==Vector2i.RIGHT else "◀"
	Visuals.label3d(marker,arrow,Vector3(-direction.x*.65,.14,-direction.y*.65),Color("8b4433"),45)
	preload("res://scripts/battle_stage.gd").pop(marker,.2)
	return marker

func wall_contacts(pos:Vector3,direction:Vector3,width:float)->Array:
	if absf(direction.x)>absf(direction.z):pos.z=snappedf(pos.z,.25)
	else:pos.x=snappedf(pos.x,.25)
	var half=Vector2(.035,width*.5) if absf(direction.x)>absf(direction.z) else Vector2(width*.5,.035)
	var result=[];var cell=grid_pos(pos)
	for x in range(cell.x-1,cell.x+2):
		for z in range(cell.y-1,cell.y+2):
			var c=Vector2i(x,z)
			if walls.has(c) and preload("res://scripts/section_wall.gd").overlap(walls[c],world_pos(c),pos,half):result.append(c)
	return result
func body_size(actor)->float:
	return 1.0 if actor.occupying_trench else .49 if UnitKinds.is_infantry(actor.kind) else float(actor.footprint)
func can_stand(pos:Vector3,actor,ignore_actors:bool=false,static_only:bool=false)->bool:
	var half=body_size(actor)*.5;var edge=grid_size*.5
	if actor.kind!="flyer" and terrain.blocked(pos,half):return false
	if absf(pos.x)+half>edge+.001 or absf(pos.z)+half>edge+.001:return false
	var cell=grid_pos(pos)
	for x in range(maxi(0,grid_pos(pos-Vector3(half,0,0)).x),mini(grid_size-1,grid_pos(pos+Vector3(half,0,0)).x)+1):
		for z in range(maxi(0,grid_pos(pos-Vector3(0,0,half)).y),mini(grid_size-1,grid_pos(pos+Vector3(0,0,half)).y)+1):
			var c=Vector2i(x,z);var center=world_pos(c)
			if walls.has(c) and preload("res://scripts/section_wall.gd").overlap(walls[c],center,pos,Vector2(half,half)):return false
			if (generators.has(c) or (trenches.has(c) and (actor.player_owned or actor.kind!="soldier" or (not static_only and not board.trench_available(c,actor)))) or (not boss_room and c==base_cell)) and absf(pos.x-center.x)<half+.499 and absf(pos.z-center.z)<half+.499:return false
	if static_only:return true
	for other in ([] if ignore_actors else actors):
		if other==actor or not is_instance_valid(other) or other.dead or other.kind=="flyer":continue
		var radius=half+body_size(other)*.5-.001
		if absf(pos.x-other.position.x)<radius and absf(pos.z-other.position.z)<radius:return false
	for wreck in wrecks:
		if is_instance_valid(wreck) and not wreck.spent and absf(pos.x-wreck.position.x)<half+.499 and absf(pos.z-wreck.position.z)<half+.499:return false
	return true
func clear_shot(from:Vector3,to:Vector3,width:float=.5)->bool:
	var delta=to-from;delta.y=0
	var direction=delta.normalized()
	for i in range(1,ceili(delta.length()/.1)):
		if not wall_contacts(from+direction*i*.1,direction,width).is_empty():return false
	return true
