extends Node
var actor
var last_position=Vector3.ZERO
var trench_state=false
var hidden_state=false
var low_health=false
func _ready():
	actor=get_parent();last_position=actor.position
func _physics_process(_delta):
	if not is_instance_valid(actor.arena) or actor.dead:return
	if actor.player_owned:
		if actor.occupying_trench!=trench_state:
			Game.sound("trench_enter" if actor.occupying_trench else "trench_exit",actor);trench_state=actor.occupying_trench
		elif actor.hidden_in_trench!=hidden_state and actor.occupying_trench:Game.sound("trench_hide",actor)
		hidden_state=actor.hidden_in_trench
		var low=actor.hp/actor.max_hp<=.25
		if low and not low_health:Game.sound("low_health",actor)
		low_health=low
	var moving=actor.position.distance_to(last_position)>.001
	last_position=actor.position
	var nearby=not is_instance_valid(actor.arena.player) or actor.position.distance_to(actor.arena.player.position)<9.0
	var active=nearby and actor.arena.phase in ["combat","countdown"] and not actor.hidden_in_trench and actor.parachute_left<=0
	var motor={"buggy":"engine_buggy","apc":"engine_apc","tank":"engine_tank","boss":"engine_tank","flyer":"rotor_drone","drone":"ground_drone_motor"}.get(actor.kind,"")
	if motor!="":
		Game.sound_loop(motor,actor,active,1.08 if moving else .87)
		if actor.kind in ["tank","boss"]:Game.sound_loop("tracks",actor,active and moving)
	if motor!="":Game.sound_loop("turret_servo",actor,active and actor.turn_left>0)
