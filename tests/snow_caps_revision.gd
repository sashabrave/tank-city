extends Node3D
## Snow caps follow the real top faces: full blocks are fully covered, half and L-shaped concrete leave the
## empty part of their bounds bare. No profile or settings writes.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false
	var D=preload("res://scripts/systems/block_decor.gd")
	var full=Visuals.model("concrete_smooth",self,Vector3.ZERO);await get_tree().process_frame
	var cells=D.top_cells(full,D.bounds(full))
	var tops=cells.filter(func(h):return not is_nan(h))
	check(tops.size()==4,"full block: every quarter has a top face %s" % str(cells))
	var partial=0
	for i in 8:
		var block=Visuals.model("concrete_smooth_half_%d" % i,self,Vector3(2+i*2,0,0));await get_tree().process_frame
		var c=D.top_cells(block,D.bounds(block)).filter(func(h):return not is_nan(h))
		print("half_%d covered %d/4" % [i,c.size()])
		if c.size()>0 and c.size()<4:partial+=1
	check(partial>=4,"half/L blocks leave empty cells uncovered (%d of 8)" % partial)
	print("SNOW CAPS: %d failures" % failures);get_tree().quit(1 if failures else 0)
