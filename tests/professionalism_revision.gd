extends Node3D
## Enemy professionalism: one smooth curve through the world (0.8 → 1.2), aim delay before the first shot,
## pauses, trench share and assault chance follow it; allies fire without delay. No profile/settings writes.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades();Campaign.configure(1)
	var P=Professionalism
	check(is_equal_approx(P.skill(0),.8) and is_equal_approx(P.skill(5),1.2) and is_equal_approx(P.skill(6),1.2),"world 1: 0.8 at the first room, 1.2 at the last and the boss")
	var smooth=true
	for i in range(1,6):smooth=smooth and P.skill(i)>P.skill(i-1) and P.value("aim_delay",i)<P.value("aim_delay",i-1)
	check(smooth,"skill grows and aim delay shrinks room by room")
	check(absf(P.skill(2)-.96)<.01 and absf(P.skill(3)-1.04)<.01,"middle rooms stay near today's tuning")
	check(is_equal_approx(P.value("trench_share",0),.15) and is_equal_approx(P.value("assault_chance",5),.55),"trench share and assault follow the curve")
	Campaign.configure(2);check(is_equal_approx(P.skill(0),.8),"a world without its own curve reuses world 1")
	Campaign.configure(1,true);check(P.skill(0)>1.0 and P.skill(0)<=1.4,"endless keeps growing, clamped")
	Campaign.configure(1)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=7;add_child(arena);arena.set_physics_process(false);arena.auto_pause_enabled=false
	var enemy=arena.spawn_actor("soldier",Vector2i(3,1),false);enemy.set_physics_process(false)
	check(is_equal_approx(enemy.aim_delay_time,P.value("aim_delay",0)) and enemy.pause_scale>1.0,"room 0 enemy gets a slow aim and longer rests")
	enemy.fire_cooldown=0;enemy.aim_hold=0
	enemy.track_aim(Vector2i.DOWN,.1)
	check(not enemy.aimed_shot() and enemy.aim_glint.visible,"no shot before the aim delay, the glint shows")
	enemy.track_aim(Vector2i.DOWN,.4)
	check(enemy.aim_hold>=enemy.aim_delay_time and not enemy.aim_glint.visible,"after the delay the glint goes and the shot is allowed")
	enemy.track_aim(Vector2i.ZERO,.2)
	check(enemy.aim_hold<enemy.aim_delay_time,"breaking the line resets the aim")
	check(P.tier(0)==1 and P.tier(1)==1 and P.tier(2)==2 and P.tier(3)==2 and P.tier(4)==3 and P.tier(6)==3,"chevrons 1-1-2-2-3-3 through world 1")
	check(enemy.health_label.rank==1,"room 0 enemy shows one chevron")
	var ally=arena.spawn_actor("soldier",Vector2i(5,1),false,true);ally.set_physics_process(false)
	check(ally.aim_delay_time==0.0 and ally.pause_scale==1.0,"allies have no aim delay")
	print("PROFESSIONALISM: %d failures" % failures);get_tree().quit(1 if failures else 0)
