extends Node3D
## Window check of status markers: burning (flame tongues), stunned (stars), sleeping in the gas cloud (Z z z),
## frozen (ice block) and the HP-bar status icon. Saves /tmp/r13-status-*.png. No profile or settings writes.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func settle(n:=3):
	for i in n:await get_tree().process_frame
func shot(name:String):
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-status-"+name+".png")
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades();Campaign.configure(1)
	get_window().size=Vector2i(1600,900)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=31;add_child(arena);arena.auto_pause_enabled=false
	await settle(30);arena.set_physics_process(false)
	var player=arena.player;player.set_physics_process(false)
	var kinds=["soldier","soldier","sniper","tank"];var enemies=[]
	for i in kinds.size():
		var e=arena.spawn_actor(kinds[i],Vector2i(3+i*2,4),false);e.set_physics_process(false);e.hp=e.max_hp*.7;e.refresh_health();enemies.append(e)
	enemies[0].burn_time=99;enemies[0].burn_dps=1
	enemies[1].stun_time=99
	enemies[2].stun_time=99;enemies[2].sleep_time=99
	enemies[3].burn_time=99;enemies[3].burn_dps=1
	var gas=load("res://scripts/ability_effect.gd").new();gas.arena=arena;gas.kind="gas";gas.power=99;gas.position=enemies[2].position;arena.add_child(gas);gas.set_physics_process(false)
	var focus=enemies[1].position.lerp(enemies[2].position,.5)
	var camera=get_viewport().get_camera_3d();camera.set_process(false);camera.set_physics_process(false)
	camera.size=6.5;camera.global_position=focus+Vector3(0,19,14).rotated(Vector3.UP,deg_to_rad(10));camera.look_at(focus)
	await settle(40)
	var fx=enemies.map(func(e):return e.get_node("StatusFx"))
	check(fx[0].marker=="burning" and fx[0].flames.visible,"burning shows flame tongues")
	check(fx[1].marker=="stun" and fx[1].stars.visible,"stun shows stars")
	check(fx[2].marker=="sleep" and fx[2].sleep.visible and not is_instance_valid(fx[2].stars),"gas sleep shows Z z z, not stars")
	check(fx.all(func(f):return f.icon.visible),"every status has an HP-bar icon")
	check(gas.visual.get_node_or_null("GasCloud")!=null,"gas uses the shared soft cloud")
	await shot("burn-stun-sleep")
	arena.freeze_time=99;await settle(20)
	check(fx.all(func(f):return f.marker=="frozen" and f.ice.visible),"freeze puts enemies into ice blocks")
	await shot("frozen")
	print("STATUS VISUALS: %d failures" % failures);get_tree().quit(1 if failures else 0)
