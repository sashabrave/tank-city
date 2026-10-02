extends Node
## T-072 bonus thieves (window shot /tmp/r13-thief.png): an enemy grabs a bonus that lay for a while, gets a visible buff, and drops it on death.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=31;add_child(arena);arena.set_physics_process(false);arena.auto_pause_enabled=false
	await get_tree().create_timer(.8).timeout
	arena.phase="combat";arena.room.spawn_queue.clear()
	for a in arena.room.actors.duplicate():
		if is_instance_valid(a) and not a.player_owned:a.dead=true;arena.room.actors.erase(a);a.queue_free()
	var cell=Vector2i(4,3)
	arena.reward.place_pickup(cell,"heart",0.0)
	var enemy=arena.spawn_actor("soldier",cell,false)
	check(enemy!=null,"enemy spawned")
	enemy.position=arena.world_pos(cell)
	arena.reward.thieves.tick(.1)
	check(not arena.reward.thieves.is_thief(enemy),"a fresh bonus is left for the hero first")
	arena.run.elapsed+=5.0
	var hp_before=enemy.max_hp
	arena.reward.thieves.tick(.1)
	check(arena.reward.thieves.is_thief(enemy),"enemy grabs a bonus that lay on the ground")
	check(arena.room.pickups.filter(func(p):return p.kind=="heart").is_empty(),"the bonus is gone from the floor")
	check(enemy.max_hp>hp_before*1.4 and enemy.hp==enemy.max_hp,"aid kit makes it fatter (%.1f → %.1f)" % [hp_before,enemy.max_hp])
	check(enemy.health_label.accent.a>0,"health bar framed in the bonus colour")
	if DisplayServer.get_name()!="headless":
		await get_tree().create_timer(.6).timeout;await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-thief.png")
	var hp=enemy.hp;enemy.take_damage(1.0)
	check(is_equal_approx(enemy.hp,hp-1.0),"fat thief takes normal damage")
	enemy.take_damage(1e6)
	arena.reward.thieves.tick(.1)
	check(not arena.reward.thieves.thieves.any(func(t):return t.actor==enemy),"thief removed on death")
	check(arena.room.pickups.any(func(p):return p.kind=="heart"),"stolen bonus drops back out")
	# Armour thieves take half damage; the buff wears off.
	arena.reward.place_pickup(Vector2i(6,3),"wall",0.0);arena.run.elapsed+=5.0
	var brick=arena.spawn_actor("soldier",Vector2i(6,3),false);brick.position=arena.world_pos(Vector2i(6,3));brick.max_hp=10;brick.hp=10
	arena.reward.thieves.tick(.1)
	brick.take_damage(2.0);check(is_equal_approx(brick.hp,9.0),"brick helmet halves damage (%.1f)" % brick.hp)
	arena.run.elapsed+=13.0;arena.reward.thieves.tick(.1)
	check(not arena.reward.thieves.is_thief(brick) and brick.health_label.accent.a<=0,"buff wears off after a while")
	print("THIEVES: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
