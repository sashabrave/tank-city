extends "res://tests/playthrough.gd"
var tier=0
var seed_value=42
func _ready():
	var args=OS.get_cmdline_user_args()
	if args.size()>0:tier=int(args[0])
	if args.size()>1:seed_value=int(args[1])
	Game.save_enabled=false;Game.sound_enabled=false;Game.health_level=tier;Game.damage_level=tier;Game.luck_level=tier;Game.turret_level=tier;Game.base_level=tier;Game.heal_level=tier;Game.rarity_level=tier
	arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false
	arena.run_seed=seed_value;arena.combat_rng.seed=seed_value;arena.begin_room(0)
func _physics_process(_delta):
	if finished:return
	ticks+=1
	if arena.phase=="countdown":arena.countdown=minf(arena.countdown,.1)
	elif arena.phase=="upgrade" and arena.reward_claimed:arena.begin_room(arena.room_index+1)
	elif arena.phase=="upgrade":arena.apply_upgrade("health" if arena.wave==1 else "damage")
	elif arena.phase=="result" or ticks>60000:
		finished=true
		print("BALANCE tier=%d seed=%d won=%s room=%d kills=%d time=%.1f hp=%.2f base=%.2f" % [tier,seed_value,arena.boss_defeated,arena.room_index+1,arena.kills,arena.elapsed,arena.soldier_hp,arena.base_hp]);get_tree().quit()
	elif arena.phase=="combat":
		if arena.room_cleared:arena.open_flag()
		else:drive()
