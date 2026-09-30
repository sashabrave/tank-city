extends Node3D
## Softening bad moments and small rewards: mercy hit, rare-card pity, kill series.
var errors=0
func check(value:bool,message:String):
	if value:print("PASS ",message)
	else:errors+=1;push_error("FAIL: "+message)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false;Game.reset_upgrades()
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false);arena.begin_room(1);arena.phase="combat"
	var p=arena.player;p.hp=3;arena.soldier_hp=3;p.invulnerable=0
	p.take_damage(10)
	check(not p.dead and is_equal_approx(p.hp,1.0) and arena.run.mercy_used,"first lethal hit leaves 1 HP")
	p.invulnerable=0;p.take_damage(10)
	check(p.dead,"second lethal hit kills")
	# Pity: after two screens without a rare, the next one has one.
	var arena2=load("res://scenes/arena.tscn").instantiate();add_child(arena2);arena2.auto_pause_enabled=false;arena2.set_physics_process(false);arena2.begin_room(0);arena2.phase="combat"
	var dry_max=0
	for i in range(40):
		var before=arena2.run.dry_offers
		var offers=RunUpgrades.roll_offers(arena2,3)
		if before>=2:check(offers.any(func(o):return o.tier>=1),"third dry screen guarantees a rare")
		dry_max=maxi(dry_max,arena2.run.dry_offers)
	check(dry_max<=2,"never more than two dry screens in a row")
	# Series: three quick kills give a ×3 label and bonus alloy.
	arena2.run.series=0;arena2.run.series_at=-10
	var dummy=arena2.spawn_actor("soldier",Vector2i(2,2),false);dummy.set_physics_process(false)
	var labels=func():return arena2.get_children().filter(func(n):return n is Label3D and n.text.begins_with("×")).size()
	for i in range(3):arena2.reward.kill_series(dummy)
	check(arena2.run.series==3 and labels.call()>=2,"kill series shows ×N")
	arena2.elapsed+=5;arena2.reward.kill_series(dummy)
	check(arena2.run.series==1,"series resets after a pause")
	print("FEEL: %d failures" % errors);get_tree().quit(1 if errors else 0)
