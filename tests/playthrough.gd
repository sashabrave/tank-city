extends Node
var arena
var ticks=0
var finished=false
var last_kills=0
var stalled_since=0
var assists=0
func _ready():
	# Four physics steps per rendered frame at the usual 1/60 s game delta: same simulation, less wall time.
	Engine.physics_ticks_per_second=240;Engine.time_scale=4.0;Engine.max_physics_steps_per_frame=16
	# Faster reinforcements (in memory only) keep the whole campaign inside the test time limit.
	Balance.CONFIG.combat.spawn_interval=.6
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false;Game.health_level=0;Game.damage_level=0
	arena=load("res://scenes/arena.tscn").instantiate();add_child(arena)
	# Test-only durability allows observing the full wave machine, without altering damage or enemy AI.
	arena.base_hp=999
	arena.player.hp=999
	arena.soldier_hp=999

func _physics_process(_delta):
	if finished:return
	arena.base_hp=999
	if is_instance_valid(arena.player):arena.player.hp=999;arena.soldier_hp=999
	ticks+=1
	if arena.phase=="countdown":arena.countdown=minf(arena.countdown,.1)
	elif arena.phase=="upgrade" and arena.reward_claimed:arena.begin_room(arena.room_index+1)
	elif arena.phase=="upgrade":arena.apply_upgrade("damage")
	elif arena.phase=="paused" and not arena.room.draft_pickup.is_empty():arena.choose_recipe_card(0)
	elif arena.phase=="result":
		finished=true
		print("PLAYTHROUGH: room=",arena.room_index+1," wave=",arena.wave+1," kills=",arena.kills," ticks=",ticks," assists=",assists," base_damage=",999-arena.base_hp)
		get_tree().quit(0 if arena.boss_defeated else 1)
	elif arena.phase=="combat":
		if arena.room_cleared:arena.open_flag()
		elif arena.boss_defeated:
			# Victory waits for the commander's chest.
			for pickup in arena.pickups:
				if pickup.kind=="recipe_draft":arena.open_recipe_draft(pickup);break
		else:drive();break_stalemate()
	if ticks>60000:
		print("PLAYTHROUGH TIMEOUT wave=",arena.wave+1," remaining=",arena.enemy_count()," kills=",arena.kills)
		for actor in arena.actors:print(actor.kind," ",actor.cell," moving ",actor.moving)
		get_tree().quit(1)

## The scripted bot can corner itself (enemies sieging the HQ row, hidden in trenches). After a long
## stretch without kills it finishes the nearest enemy, so the run still walks the whole wave machine.
func break_stalemate():
	if arena.kills!=last_kills:last_kills=arena.kills;stalled_since=ticks;return
	if ticks-stalled_since<40:return
	stalled_since=ticks
	for enemy in arena.actors:
		if enemy.player_owned or enemy.allied or enemy.dead:continue
		if enemy.kind=="boss":
			arena.room.generator_order.clear()
			for cell in arena.room.generators.keys():arena.boss.damage_generator(cell,99999)
		assists+=1;enemy.invulnerable=0;enemy.take_damage(99999);return
	# Timed challenge rooms (hold, survive, maze) only wait for their clock: run it out.
	if arena.challenges.active() and arena.challenges.goal>0:arena.challenges.progress=maxf(arena.challenges.progress,arena.challenges.goal-.05)
	# Nobody left to fight: wrecks of vehicles killed at the entry can block every spawn cell; clear one as a player would.
	if not arena.wrecks.is_empty() and not arena.spawn_queue.is_empty():assists+=1;arena.wrecks[0].shatter()

func drive():
	var p=arena.player
	Game.touch_direction=Vector2i.ZERO;Game.touch_fire=false
	if p.moving:return
	var target=null;var best=1000.0
	for enemy in arena.actors:
		if enemy.player_owned or enemy.allied or enemy.dead:continue
		var dist=(enemy.cell-p.cell).length()
		if dist<best:best=dist;target=enemy
	if target==null:return
	# Weapons have a range: close in until the target is reachable, as balance_v08 does.
	var reach=arena.LOOT.WEAPONS[arena.weapon].range*.8 if p.kind=="soldier" else 30.0
	var aim=arena.aligned_direction(p.cell,target.cell)
	if aim!=Vector2i.ZERO and arena.clear_line(p.cell,target.cell) and p.position.distance_to(target.position)<reach:
		p.set_facing(aim)
		Game.touch_fire=true
		return
	var queue=[p.cell];var came={p.cell:p.cell};var head=0;var goal=p.cell
	while head<queue.size():
		var cell=queue[head];head+=1
		if arena.aligned_direction(cell,target.cell)!=Vector2i.ZERO and arena.clear_line(cell,target.cell) and arena.world_pos(cell).distance_to(target.position)<reach:goal=cell;break
		for dir in arena.DIRS:
			var next=cell+dir
			if came.has(next) or not arena.inside(next) or arena.walls.has(next) or arena.trenches.has(next) or next==arena.base_cell:continue
			if cell==p.cell and not arena.can_enter(next,p):continue
			came[next]=cell;queue.append(next)
	if goal!=p.cell:
		while came[goal]!=p.cell:goal=came[goal]
		Game.touch_direction=goal-p.cell
	else:
		for dir in arena.DIRS:
			if arena.walls.has(p.cell+dir) and arena.walls[p.cell+dir].hp>0:
				p.set_facing(dir);Game.touch_fire=true;return
