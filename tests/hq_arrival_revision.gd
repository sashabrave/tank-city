extends Node3D
## The HQ arrives already heading the way it will stand (side follows the final yaw), so the last part of the
## drive-in has no turn on the spot; the defence wall builds 20% slower. Several seeds. No profile writes.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	check(is_equal_approx(preload("res://scripts/battle_stage.gd").BRICK_PACE,1.2),"wall assembly 20% slower")
	var worst=0.0;var aligned=true
	# T-152: the soldier cannot be moved while the intro plays; control returns when he reaches his cell.
	Game.visual_run_seed=77
	var probe=load("res://scenes/arena.tscn").instantiate();probe.run_seed=77;add_child(probe);probe.auto_pause_enabled=false
	var start_cell=probe.player.cell
	Input.action_press("north");for i in 20:await get_tree().physics_frame
	Input.action_release("north")
	check(probe.get_meta("intro_lock",false) and probe.player.cell==start_cell,"no control during the intro")
	await get_tree().create_timer(preload("res://scripts/battle_stage.gd").ARRIVE_RAMP+1.6).timeout
	check(not probe.get_meta("intro_lock",false),"control returns after the intro")
	probe.queue_free();await get_tree().process_frame
	for seed_value in [3,8,21,40]:
		Game.visual_run_seed=seed_value
		var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=seed_value;add_child(arena);arena.auto_pause_enabled=false
		var hq=arena.base_model;var yaw=hq.rotation.y;var samples=[]
		# 0.8: the drive up the field approach takes ARRIVE_RAMP; sample a little past it.
		var until=Time.get_ticks_msec()+int(preload("res://scripts/battle_stage.gd").ARRIVE_RAMP*1250)
		while Time.get_ticks_msec()<until:
			await get_tree().process_frame
			samples.append([hq.position,hq.rotation.y,Time.get_ticks_usec()])
		# Turning in the final 40% of the samples while the HQ is still moving.
		var tail=samples.slice(int(samples.size()*.25))
		for i in range(1,tail.size()):
			if tail[i][0].distance_to(tail[i-1][0])<.002:continue
			# A snap, not a rate: the old bug turned 90° on the spot in one step. Headless runs at 8–10 fps, so
			# per-frame rates are meaningless; one sample may turn a lot, but never most of a right angle.
			worst=maxf(worst,absf(angle_difference(tail[i][1],tail[i-1][1])))
		aligned=aligned and absf(angle_difference(hq.rotation.y,yaw))<.05
		arena.queue_free();await get_tree().process_frame
	check(aligned,"the HQ ends at its chosen side")
	check(worst<.8,"no turn on the spot during the drive-in (max %.2f rad per step)" % worst)
	print("HQ ARRIVAL: %d failures" % failures);get_tree().quit(1 if failures else 0)
