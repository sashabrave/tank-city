extends "res://tests/balance_v08.gd"
## test-timeout: 420 (simulates a long run)
var stage_limit=15
func _ready():
	Game.save_enabled=false;Game.sound_enabled=false;Game.reset_upgrades()
	var args=Array(OS.get_cmdline_user_args()).filter(func(s):return not str(s).begins_with("--"));seed_value=int(args[0]) if args.size()>0 else 42
	Game.health_level=20;Game.damage_level=20;Game.base_level=10;Game.heal_level=10;Game.mobility_level=10;Game.turret_level=10;Game.luck_level=10;Game.rarity_level=10;Game.recovery_level=10;Game.camp_level=3
	Game.ability_slots=2;Game.equipped_abilities=["grenade","ally_drone"];Game.selected_ability="grenade";Game.ability_unlocks=Game.equipped_abilities.duplicate();Game.shield_capacity_level=1
	arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.run_seed=seed_value;arena.combat_rng.seed=seed_value;arena.begin_room(0)
func advance():
	var next=arena.room_index+1
	if next in Campaign.SERVICES:
		var service=load("res://scripts/service_room.gd").new();service.arena=arena;service.index=next;service.branch="vehicle";add_child(service)
		for kit in service.medkits.duplicate():service.avatar.position=kit.position;service.collect_medkits()
		service.claim(0);service.queue_free()
	arena.begin_room(next)
func _physics_process(_delta):
	if finished:return
	ticks+=1
	# The exit waits for the commander's chest (T-044): the bot takes the chest without picking a card.
	if arena.room.has_meta("pending_flag"):
		for chest in arena.room.pickups.filter(func(c):return c.kind=="recipe_draft"):arena.reward.consume_chest(chest)
	if arena.phase=="result" or (arena.room_index==stage_limit and arena.boss_defeated) or ticks>130000:
		finished=true;print("BALANCE09 seed=%d stage=%d kills=%d time=%.1f hp=%.2f base=%.2f earned=%d clear=%s timeout=%s" % [seed_value,arena.room_index+1,arena.kills,arena.elapsed,arena.soldier_hp,arena.base_hp,arena.earned,arena.boss_defeated,ticks>130000]);get_tree().quit();return
	if arena.phase=="countdown":arena.countdown=minf(arena.countdown,.1)
	elif arena.phase=="paused" and arena.boss_defeated:advance()
	elif arena.phase=="upgrade" and arena.reward_claimed:advance()
	elif arena.phase=="upgrade":
		if arena.upgrade_offers.is_empty():return # cards appear after the wave announcement
		var offer=arena.upgrade_offers[0]
		for candidate in arena.upgrade_offers:
			if candidate.id==("weapon_damage" if arena.next_is_room else "damage"):offer=candidate
			if not arena.next_is_room and arena.soldier_hp<arena.soldier_max_hp*.7 and candidate.id=="health":offer=candidate;break
		arena.apply_upgrade(offer.id,offer.tier)
	elif arena.phase=="combat":
		if arena.boss_defeated:
			if not arena.pickups.is_empty():
				var chest=arena.pickups.filter(func(p):return p.kind=="recipe_draft")
				if not chest.is_empty():arena.open_recipe_draft(chest[0]);arena.choose_recipe_card(2)
		elif arena.room_cleared:
			var chest=arena.pickups.filter(func(p):return p.kind=="recipe_draft")
			if not chest.is_empty():arena.open_recipe_draft(chest[0]);arena.choose_recipe_card(2)
			else:arena.open_flag()
		else:
			for i in range(arena.abilities.slots.size()):arena.abilities.cast_slot(i)
			if not seek_heal():drive()

func seek_heal()->bool:
	var p=arena.player
	if p.kind!="soldier" or arena.soldier_hp>arena.soldier_max_hp*.65:return false
	var hearts=arena.pickups.filter(func(item):return item.kind=="heart")
	if hearts.is_empty():return false
	var goal=arena.grid_pos(hearts[0].node.position)
	Game.touch_direction=Vector2i.ZERO;Game.touch_fire=false
	if p.moving:return true
	var queue=[p.cell];var came={p.cell:p.cell};var head=0
	while head<queue.size():
		var cell=queue[head];head+=1
		if cell==goal:break
		for direction in arena.DIRS:
			var next=cell+direction
			if came.has(next) or not arena.inside(next) or arena.walls.has(next) or arena.trenches.has(next) or next==arena.base_cell:continue
			came[next]=cell;queue.append(next)
	if not came.has(goal) or goal==p.cell:return false
	while came[goal]!=p.cell:goal=came[goal]
	Game.touch_direction=goal-p.cell;return true
