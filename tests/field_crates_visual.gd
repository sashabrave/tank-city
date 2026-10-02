extends Node3D
## Army crates: a few per field next to cover, a player bullet breaks one into splinters, walking into one breaks
## it too, stacks drop down. Window shots /tmp/r13-crates-*.png. No profile or settings writes.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func settle(n:=3):
	for i in n:await get_tree().process_frame
func shot(name:String):
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-crates-"+name+".png")
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	get_window().size=Vector2i(1600,900)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=21;add_child(arena);arena.auto_pause_enabled=false
	await settle(60);arena.set_physics_process(false);arena.phase="combat"
	var crates=arena.get_node("FieldCrates")
	check(crates.crates.size()>=2 and crates.crates.size()<=10,"a few crates on the field (%d)" % crates.crates.size())
	var first=crates.crates[0];var at:Vector3=first.node.global_position
	var camera=get_viewport().get_camera_3d();camera.set_process(false);camera.set_physics_process(false)
	camera.size=4.0;camera.global_position=at+Vector3(0,19,14).rotated(Vector3.UP,deg_to_rad(10)).normalized()*20;camera.look_at(at)
	await settle(10);await shot("before")
	var bullet=load("res://scenes/projectile.tscn").instantiate();bullet.friendly=true;bullet.arena=arena;bullet.owner_actor=arena.player;arena.add_child(bullet)
	bullet.global_position=at+Vector3(0,.12,0);arena.projectiles.append(bullet)
	var before=crates.crates.size()
	crates._physics_process(.016)
	check(crates.crates.size()==before-1 and bullet.spent,"a player bullet breaks the crate and is used up")
	await settle(6);await shot("splinters")
	if not crates.crates.is_empty():
		var other=crates.crates[0];arena.player.position=other.node.global_position;crates._physics_process(.016)
		check(not crates.crates.has(other),"walking into a crate kicks it apart")
	print("FIELD CRATES: %d failures" % failures);get_tree().quit(1 if failures else 0)
