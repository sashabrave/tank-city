extends Node3D
var checks=0
var failures=0
func check(ok,message):
	checks+=1
	if not ok:failures+=1;push_error(message)
func _ready():call_deferred("run")
func shot(name):
	if DisplayServer.get_name()=="headless":return
	RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("res://art_demo/environment_v7/"+name+".png")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Game.reset_upgrades();Game.credits=123;Game.cores=4
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false)
	for actor in arena.actors:actor.set_physics_process(false)
	var original=arena.player
	var wreck=arena.make_wreck("tank",arena.player.cell,Vector2i.UP,true);wreck.set_physics_process(false)
	check(not wreck.boardable and arena.nearest_wreck()==null,"unstable wreck cannot be boarded")
	wreck.boardable=true;arena.vehicle.interact_vehicle()
	check(arena.player==original and not wreck.spent,"even stale boardable flag cannot cancel destruction")
	arena.phase="upgrade";wreck._physics_process(2)
	check(is_equal_approx(wreck.timer,3),"timer continues through reward phase")
	arena.phase="countdown";wreck._physics_process(2)
	check(is_equal_approx(wreck.timer,1),"new wave does not reset timer")
	wreck._physics_process(1.1);check(wreck.spent,"wreck always explodes at expiry")
	arena.phase="upgrade";arena.presentation.text_tween.kill()
	var before=arena.speed_multiplier;arena.reward.apply_speed_upgrade(2)
	check(is_equal_approx(arena.speed_multiplier,before+.08),"epic speed adds eight points")
	for i in range(30):arena.reward.apply_speed_upgrade(2)
	check(arena.speed_multiplier<=1.45 and arena.player.speed<=5.2,"speed stacking stays controllable")
	var preview=arena.reward.upgrade_card({"id":"health","tier":0})
	check("→" in preview.detail,"upgrade reports before and after")
	arena.upgrade_offers=[{"id":"health","tier":0},{"id":"speed","tier":1},{"id":"damage","tier":2}];arena.hud.show_upgrades()
	await get_tree().create_timer(.5).timeout;shot("numeric_upgrades")
	check(ResourceStrip.label.text.contains("123") and ResourceStrip.label.text.contains("4"),"shared currency counter")
	arena.queue_free();await get_tree().process_frame
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub);Game.built_workshops=["bonuses"];Game.set_all_recipes(true);hub.open_workshop(false,true)
	await get_tree().create_timer(.3).timeout;shot("numeric_bonuses")
	check(ResourceStrip.panel.position.y==10,"same resource placement in hub")
	print("POLISH: %d checks, %d failures" % [checks,failures]);get_tree().quit(failures)
