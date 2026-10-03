extends Node
## T-165: own explosives bite allies a little, own bullets never do; the hub comrade blocks its cell.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.auto_pause_enabled=false;add_child(arena)
	await get_tree().create_timer(.6).timeout;arena.set_physics_process(false);arena.phase="combat"
	arena.summon_comrade(.5,0);var buddy=arena.actors.back();buddy.set_physics_process(false);buddy.parachute_left=0
	var hp=buddy.hp
	arena.grenade_explosion(buddy.position,5.0,true,1.2)
	check(buddy.hp==hp-1.0,"own grenade bites the comrade by 1 (%s → %s)" % [hp,buddy.hp])
	hp=buddy.hp
	var bullet=load("res://scenes/projectile.tscn").instantiate();bullet.arena=arena;bullet.owner_actor=arena.player;bullet.friendly=true;bullet.damage=3.0;bullet.position=buddy.position+Vector3.UP*.5;arena.add_child(bullet)
	arena.bullet_hit(bullet)
	check(buddy.hp==hp,"own bullets pass the comrade")
	arena.queue_free();await get_tree().process_frame
	# Hub: the comrade ability takes a cell beside the hero; the hero cannot walk into it.
	Game.selected_class="recruit"
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub);await get_tree().create_timer(.5).timeout
	var effect=load("res://scripts/hub_ability_effect.gd").new();effect.hub=hub;effect.kind="comrade";hub.add_child(effect)
	check(effect.accepted and effect.deployed_cell in hub.training_barriers and not hub.hub_free(effect.deployed_cell),"hub comrade blocks its cell")
	var taken=effect.deployed_cell
	effect.queue_free();await get_tree().process_frame
	check(taken not in hub.training_barriers,"the cell frees when the comrade leaves")
	print("FRIENDLY FIRE: %d failures" % failures);get_tree().quit(1 if failures else 0)
