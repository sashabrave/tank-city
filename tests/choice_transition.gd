extends Node
var checks=0
var failures=0
func check(ok,message):
	checks+=1
	if not ok:failures+=1;push_error(message)
func key(pressed:bool,echo=false):
	var event=InputEventKey.new();event.keycode=KEY_E;event.physical_keycode=KEY_E;event.pressed=pressed;event.echo=echo
	Input.parse_input_event(event)
func run():
	Game.save_enabled=false;Game.sound_enabled=false
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false)
	for actor in arena.actors:actor.set_physics_process(false)
	arena.phase="combat";arena.wave=0
	key(true)
	arena.flow.finish_wave()
	check(arena.phase=="upgrade" and not is_instance_valid(arena.hud.modal),"status precedes reward window")
	check(CardNavigation.transition_locked,"confirmation locked during status")
	await get_tree().create_timer(1.0).timeout
	check(not is_instance_valid(arena.hud.modal),"no cards under status title")
	await get_tree().create_timer(.42).timeout
	check(is_instance_valid(arena.hud.modal) and CardNavigation.transition_locked,"cards enter immediately after title, input still blocked")
	check(CardNavigation.available().is_empty(),"cards disabled during entrance")
	await get_tree().create_timer(.4).timeout
	check(not CardNavigation.transition_locked and CardNavigation.release_required,"held E requires release after entrance")
	check(arena.presentation.heading.modulate.a==0,"status fully hidden before card selection")
	key(true,true);await get_tree().process_frame
	check(arena.phase=="upgrade","E repeat does not choose unseen reward")
	key(false);await get_tree().process_frame
	check(arena.phase=="upgrade" and not CardNavigation.release_required,"release arms without choosing")
	var selected=CardNavigation.selected
	check(selected.get_parent().get_theme_stylebox("panel").border_width_left==6,"selected card has thick border")
	key(true);await get_tree().process_frame
	check(arena.phase=="countdown","fresh E selects exactly once")
	key(false)
	arena.hud.show_upgrades();arena.hud.close_modal()
	await get_tree().create_timer(1.6).timeout
	check(not is_instance_valid(arena.hud.modal),"cancelled pending window cannot reappear")
	arena.queue_free();await get_tree().process_frame
	var route=load("res://scripts/route_map.gd").new();route.wave_seed=42;add_child(route)
	var focus=Vector3(0,0,-route.scroll)
	check((route.camera.position-focus).normalized().is_equal_approx(Vector3(0,19,14).rotated(Vector3.UP,deg_to_rad(10)).normalized()),"map uses combat tilt and yaw")
	check(route.previews.values()[0].scale.is_equal_approx(Vector3.ONE*.8),"room miniatures reduced twenty percent")
	route.queue_free();await get_tree().process_frame
	print("CHOICE TRANSITION: %d checks, %d failures" % [checks,failures]);get_tree().quit(1 if failures else 0)
func _ready():call_deferred("run")
