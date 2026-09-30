extends Node
func _ready():call_deferred("run")
func shot(label:String):
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/r13-hub-animation-"+label+".png")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Settings.values.fullscreen=false;Settings.apply()
	Game.selected_weapon="rifle"
	var hub=load("res://scenes/hub.tscn").instantiate()
	add_child(hub);await get_tree().create_timer(.7).timeout
	hub.phase="combat";hub.avatar.position=Vector3(2,0,1);hub.moving=false
	var camera=hub.get_viewport().get_camera_3d();camera.size=5.5;camera.position=Vector3(3,8,7);camera.look_at(Vector3(3,.6,1))
	assert(hub.avatar.weapon_id=="rifle")
	Input.action_press("east");await get_tree().create_timer(.25).timeout
	assert(hub.avatar.preview_moving and hub.avatar.player.current_animation=="hero_walk")
	await shot("walking-a");await get_tree().create_timer(.18).timeout;await shot("walking-b")
	Input.action_release("east");await get_tree().create_timer(.25).timeout
	assert(not hub.avatar.preview_moving and hub.avatar.player.current_animation=="hero_idle")
	hub.shoot();assert(hub.avatar.recoil>.9);await shot("recoil")
	hub.phase="workshop";hub.moving=true;hub.sync_model_animation();assert(not hub.avatar.preview_moving)
	hub.phase="combat";hub.moving=false;hub.mounted=true;hub.avatar.hide();hub.training_tank.show();hub.training_tank.position=Vector3(2,0,1);hub.cell=Vector2i(2,1)
	var wheel=hub.training_tank.wheels[0];var angle=wheel.rotation.x
	Input.action_press("east");await get_tree().create_timer(.25).timeout
	assert(hub.training_tank.preview_moving and not is_equal_approx(wheel.rotation.x,angle))
	assert(not hub.avatar.preview_moving);await shot("vehicle")
	Input.action_release("east");await get_tree().create_timer(.25).timeout
	assert(not hub.training_tank.preview_moving)
	hub.shoot();assert(hub.training_tank.recoil>.9)
	print("HUB ANIMATION PASS: combat walk/idle, weapon, recoil, workshop stop, vehicle wheel speed")
	get_tree().quit()
