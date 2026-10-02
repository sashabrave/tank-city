extends Node3D
const DROP=preload("res://scripts/resource_drop.gd")
func _ready():call_deferred("run")
func run():
	Settings.persistence_enabled=false;Game.save_enabled=false;Game.sound_enabled=true;Game.reset_upgrades()
	for amount in [2,7,20,49,50,77,200]:
		var sum=0
		for part in DROP.split(amount):sum+=part.amount
		assert(sum==amount)
	# Bars of 1, 5 and 10 in a random mix (T-105): only these sizes, and big sums stay a handful of pieces.
	for i in range(20):
		var parts=DROP.split(77)
		var sizes_ok=parts.all(func(x):return int(x.denomination) in [1,5,10])
		if not sizes_ok or parts.size()>14:print("SPLIT FAIL ",parts)
		assert(sizes_ok and parts.size()<=14)
	assert(DROP.split(200).size()<=26)
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.phase="combat";arena.set_physics_process(false)
	var enemy=arena.spawn_actor("tank",Vector2i(3,3),false);enemy.set_physics_process(false)
	var before=Game.credits;enemy.take_damage(999,Vector3(1,0,0))
	assert(Game.credits==before and arena.room.resource_drops.size()>0)
	assert(arena.room.resource_drops[0].velocity.x>1)
	DROP.spawn(arena,arena.world_pos(Vector2i(5,5)),77)
	DROP.spawn(arena,arena.world_pos(Vector2i(6,5)),2,"documents")
	await get_tree().create_timer(.55).timeout
	if DisplayServer.get_name()!="headless":RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("res://art_demo/resource_drops/drops.png")
	var expected=0
	for token in arena.room.resource_drops:
		expected+=token.amount if token.currency=="alloy" else token.amount*Game.DOC_ALLOY if token.currency=="documents" else 0
	var earned=arena.run.earned
	arena.reward.collect_resources()
	assert(Game.credits==before+expected and Game.cores==0 and arena.run.earned==earned+expected)
	arena.reward.collect_resources();assert(Game.credits==before+expected)
	DROP.spawn(arena,arena.player.position,7)
	await get_tree().create_timer(.8).timeout
	assert(Game.credits==before+expected+7)
	print("RESOURCE DROPS PASS: exact denominations, explosion impulse, pickup, sweep, no duplication, sound")
	get_tree().quit()
