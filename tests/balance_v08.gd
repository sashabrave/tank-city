extends "res://tests/playthrough.gd"
var tier=0
var seed_value=42
var service_choice="vehicle"
func _ready():
	var args=OS.get_cmdline_user_args()
	if args.size()>0:tier=int(args[0])
	if args.size()>1:seed_value=int(args[1])
	if args.size()>2:service_choice=args[2]
	Game.save_enabled=false;Game.sound_enabled=false;Game.reset_upgrades()
	Game.health_level=tier;Game.damage_level=tier;Game.luck_level=tier;Game.turret_level=tier;Game.base_level=tier;Game.heal_level=tier;Game.rarity_level=tier;Game.mobility_level=tier;Game.recovery_level=tier
	Game.selected_ability="grenade" if tier>0 else "barrier";Game.ability_unlocks=[Game.selected_ability]
	Game.camp_level=3 if tier>0 else 0
	Game.selected_weapon=args[3] if args.size()>3 else "pistol"
	if tier>0:
		Game.health_level=20;Game.damage_level=20;Game.base_level=10;Game.heal_level=10;Game.mobility_level=10;Game.turret_level=10;Game.luck_level=10;Game.rarity_level=10;Game.recovery_level=10
	arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false
	arena.run_seed=seed_value;arena.combat_rng.seed=seed_value;arena.begin_room(0)
func _physics_process(_delta):
	if finished:return
	ticks+=1
	if arena.phase=="countdown":arena.countdown=minf(arena.countdown,.1)
	elif arena.phase=="upgrade" and arena.reward_claimed:
		var next=arena.room_index+1
		if next in [2,4,6]:
			var service=load("res://scripts/service_room.gd").new();service.arena=arena;service.index=next;service.branch=service_choice;add_child(service)
			for kit in service.medkits.duplicate():service.avatar.position=kit.position;service.collect_medkits()
			service.claim(0);service.queue_free()
		arena.begin_room(next)
	elif arena.phase=="upgrade":
		var offer=arena.upgrade_offers[0]
		for candidate in arena.upgrade_offers:
			if candidate.id==("weapon_damage" if arena.next_is_room else "damage"):offer=candidate
			if not arena.next_is_room and arena.soldier_hp<arena.soldier_max_hp*.7 and candidate.id=="health":offer=candidate;break
		arena.apply_upgrade(offer.id,offer.tier)
	elif arena.phase=="result" or ticks>72000:
		finished=true
		print("BALANCE08 tier=%d seed=%d service=%s weapon=%s won=%s room=%d kills=%d time=%.1f hp=%.2f base=%.2f earned=%d boss_hp=%.1f timeout=%s" % [tier,seed_value,service_choice,Game.selected_weapon,arena.boss_defeated,arena.room_index+1,arena.kills,arena.elapsed,arena.soldier_hp,arena.base_hp,arena.earned,arena.actors.filter(func(a):return a.kind=="boss" and not a.dead)[0].hp if arena.actors.any(func(a):return a.kind=="boss" and not a.dead) else 0.0,ticks>72000]);get_tree().quit()
	elif arena.phase=="combat":
		if arena.room_cleared:arena.open_flag()
		else:
			arena.abilities.cast()
			drive()

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
	var reach=arena.LOOT.WEAPONS[arena.weapon].range*.8 if p.kind=="soldier" else 30.0
	if p.kind=="soldier" and arena.weapon=="shotgun":reach=2.8
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
