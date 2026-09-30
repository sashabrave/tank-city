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
	Game.selected_ability="grenade";Game.ability_unlocks=["grenade"]
	arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false
	arena.run_seed=seed_value;arena.combat_rng.seed=seed_value;arena.begin_room(0)
func _physics_process(_delta):
	if finished:return
	ticks+=1
	if arena.phase=="countdown":arena.countdown=minf(arena.countdown,.1)
	elif arena.phase=="upgrade" and arena.reward_claimed:
		var next=arena.room_index+1
		if next in [2,4,6]:
			var service=load("res://scripts/service_room.gd").new();service.arena=arena;service.index=next;service.branch=service_choice;add_child(service);service.claim(0);service.queue_free()
		arena.begin_room(next)
	elif arena.phase=="upgrade":
		var offer=arena.upgrade_offers[0]
		for candidate in arena.upgrade_offers:
			if candidate.id==("weapon_damage" if arena.next_is_room else "damage"):offer=candidate
			if not arena.next_is_room and arena.soldier_hp<arena.soldier_max_hp*.7 and candidate.id=="health":offer=candidate;break
		arena.apply_upgrade(offer.id,offer.tier)
	elif arena.phase=="result" or ticks>72000:
		finished=true
		print("BALANCE06 tier=%d seed=%d service=%s won=%s room=%d kills=%d time=%.1f hp=%.2f base=%.2f timeout=%s" % [tier,seed_value,service_choice,arena.boss_defeated,arena.room_index+1,arena.kills,arena.elapsed,arena.soldier_hp,arena.base_hp,ticks>72000]);get_tree().quit()
	elif arena.phase=="combat":
		if arena.room_cleared:arena.open_flag()
		else:
			arena.abilities.cast()
			drive()
