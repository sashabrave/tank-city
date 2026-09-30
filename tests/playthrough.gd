extends Node
var arena
var ticks=0
var finished=false
func _ready():
	Game.save_enabled=false;Game.sound_enabled=false;Game.health_level=0;Game.damage_level=0
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
	elif arena.phase=="result":
		finished=true
		print("PLAYTHROUGH: room=",arena.room_index+1," wave=",arena.wave+1," kills=",arena.kills," ticks=",ticks," base_damage=",999-arena.base_hp)
		get_tree().quit(0 if arena.boss_defeated else 1)
	elif arena.phase=="combat":
		if arena.room_cleared:arena.open_flag()
		else:drive()
	if ticks>60000:
		print("PLAYTHROUGH TIMEOUT wave=",arena.wave+1," remaining=",arena.enemy_count()," kills=",arena.kills)
		for actor in arena.actors:print(actor.kind," ",actor.cell," moving ",actor.moving)
		get_tree().quit(1)

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
	var aim=arena.aligned_direction(p.cell,target.cell)
	if aim!=Vector2i.ZERO and arena.clear_line(p.cell,target.cell):
		p.set_facing(aim)
		Game.touch_fire=true
		return
	var queue=[p.cell];var came={p.cell:p.cell};var head=0;var goal=p.cell
	while head<queue.size():
		var cell=queue[head];head+=1
		if arena.aligned_direction(cell,target.cell)!=Vector2i.ZERO and arena.clear_line(cell,target.cell):goal=cell;break
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
