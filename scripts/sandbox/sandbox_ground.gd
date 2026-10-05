extends "res://scripts/playground.gd"
## The sandbox on the one field engine (step 3, guides/02_development/07_one_world.md): a «battle» playground of a
## test arena. The arena builds an ordinary generated battle field (begin_room) under this playground's rules —
## field size, room mode (battle or a challenge), difficulty stars, biome, waves on or off — which the admin panel
## (F2, scripts/sandbox/admin_panel.gd, a child of this node) changes before rebuilding the field. The hero, gun,
## abilities, cards, HUD, backpack and floor are the arena's, exactly as in a sortie. The real profile is never
## written: open() snapshots it and turns writing off, restore() puts it back (an unfinished real run included).
## A defeat respawns the hero and the HQ on the spot (take_defeat). Open with main.enter_playground("sandbox").
## Field size, cells (0 — the route's size for the field).
var size:=0
## Room mode: «battle» or a challenge (RoutePlan.CHALLENGES).
var mode:="battle"
## Difficulty stars 0–2.
var difficulty:=0
## Biome entry (BiomeCatalog.ENTRIES), −1 — the route's biome.
var biome:=-1
## Waves come as in battle; off — an empty field that never clears.
var waves:=false
var admin:CanvasLayer
var snapshot:Dictionary={}
var restore_state:Dictionary={}

## A sandbox playground with `rules` (keys of battle_rules). Put it on an arena before the arena enters the tree
## (`arena.playground = …`), and the arena opens on it.
static func make(rules:={})->Node3D:
	var ground=load("res://scripts/sandbox/sandbox_ground.gd").new();ground.name="SandboxGround"
	for key in rules:ground.set(key,rules[key])
	return ground
## A test arena with a sandbox playground (not yet in the tree). The profile is not touched: tests and scripted
## fields use it as is; open() is the hub's sandbox with its snapshot.
static func field(rules:={})->Node3D:
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=randi();arena.auto_pause_enabled=false
	arena.playground=make(rules)
	return arena
## The hub's sandbox: the profile is snapshotted, writing is off, every gun and class is open; the test arena
## stands under `parent`. Returns the playground (its `arena` is the field).
static func open(parent:Node)->Node3D:
	var snapshot=Game.serialize_progress().duplicate(true)
	var restore_state={"save":Game.save_enabled,"settings":Settings.persistence_enabled,"lighting":Settings.values.world_lighting,"world":Campaign.world,"endless":Campaign.endless}
	Game.save_enabled=false;Settings.persistence_enabled=false
	Game.weapon_unlocks=Game.LOOT.gun_ids();Game.class_unlocks=Game.CLASSES.keys()
	Campaign.configure(1)
	var arena=field()
	var ground=arena.playground;ground.snapshot=snapshot;ground.restore_state=restore_state
	parent.add_child(arena)
	return ground
## Leaving the sandbox: the profile, settings and campaign as they were before open().
func restore():
	if restore_state.is_empty():return
	Settings.values.world_lighting=restore_state.lighting;Settings.apply()
	Game.apply_profile(snapshot)
	Game.save_enabled=restore_state.save;Settings.persistence_enabled=restore_state.settings
	Campaign.configure(restore_state.world,restore_state.endless)
	ResourceStrip.track_run(null)
	restore_state={}

func _init():index=0
func _ready():
	admin=load("res://scripts/sandbox/admin_panel.gd").new();admin.name="SandboxAdmin";admin.arena=arena;admin.ground=self;add_child(admin)
	admin.exit_requested.connect(func():hub_requested.emit())
## The admin panel pauses the tree itself; Esc stays the arena's pause.
func _process(_delta):pass

func field_mode()->String:return "battle"
func battle_rules()->Dictionary:return {"mode":mode,"size":size,"difficulty":difficulty,"biome":biome,"waves":waves}
func window_open()->bool:return false
## A defeat never ends the sandbox: the soldier and the HQ come back on the spot.
func take_defeat(reason:String)->bool:
	respawn.call_deferred(reason);return true
func respawn(reason:String):
	if not is_instance_valid(arena):return
	var room=arena.room
	if not is_instance_valid(room.player) or room.player.dead:
		arena.run.soldier_hp=arena.run.soldier_max_hp
		room.player=arena.spawn_actor("soldier",arena.find_free_near(Vector2i(room.base_cell.x,room.grid_size-3)),true)
		room.player.invulnerable=1.5
	room.base_hp=room.base_max_hp
	if is_instance_valid(room.base_bar):room.base_bar.set_health(room.base_hp,room.base_max_hp)
	arena.phase="combat"
	arena.toast(reason+" · возрождение")
