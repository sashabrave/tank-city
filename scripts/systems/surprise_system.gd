extends RefCounted
## Background attacks use their own RNG/cooldown, never a wave completion quota.
var arena
func _init(context):arena=context
func start_wave():
	var room=arena.room
	if room.surprise_initialized:return
	room.surprise_initialized=true
	room.surprise_rng.seed=arena.run.run_seed+room.room_index*104729+room.route_node_id.hash()+271
	room.surprise_timer=maxf(0.0,room.surprise_rng.randf_range(Balance.CONFIG.campaign.first_surprise_min,Balance.CONFIG.campaign.first_surprise_max)-room.combat_elapsed)
func tick(delta:float):
	var room=arena.room;var tuning=Balance.CONFIG.campaign
	if arena.phase!="combat" or room.room_cleared or room.boss_defeated:return
	# Never wait for or dispatch a late drone after the main fight is over.
	if room.spawn_queue.is_empty() and arena.wave_enemy_count()==0:return
	room.surprise_timer-=delta
	if room.surprise_timer>0 or room.combat_elapsed<tuning.first_surprise_min:return
	room.surprise_timer=room.surprise_rng.randf_range(tuning.surprise_delay_min,tuning.surprise_delay_max)
	if arena.enemy_count()-arena.wave_enemy_count()>=tuning.surprise_active_cap:return
	var kind="flyer" if room.surprise_rng.randf()<.5 else "drone"
	var cell=Vector2i(0 if room.surprise_rng.randf()<.5 else room.grid_size-1,room.surprise_rng.randi_range(0,2))
	if kind=="drone" and not arena.can_enter(cell):kind="flyer"
	Game.sound("enemy_surprise",arena)
	arena.spawn_actor(kind,cell,false,false,Campaign.world if not Campaign.endless else mini(3,1+Campaign.cycle),true)
func end_wave():
	# Only clear residual ordnance after every spawned enemy has been defeated.
	if arena.enemy_count()>0:return
	for bomb in arena.bombs.duplicate():
		if is_instance_valid(bomb):bomb.spent=true;bomb.queue_free()
	arena.bombs.clear()
	for bullet in arena.projectiles.duplicate():
		if is_instance_valid(bullet) and not bullet.friendly:bullet.consume()
