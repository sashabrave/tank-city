extends Node
## Challenge ladder I–III: unlock order, default = last open step, effects (professionalism, reward, no breather,
## weaker HQ, +1 enemy), record on world clear, and the world card buttons. Window shot /tmp/r13-ladder.png.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false
	get_window().size=Vector2i(1600,900)
	var worlds=Game.progression.cleared_worlds.duplicate();var counters=Game.progression.counters.duplicate()
	Game.progression.cleared_worlds=[];check(Campaign.challenge_open(1)==0,"no ladder before the world is cleared")
	Game.progression.cleared_worlds=[1];Game.progression.counters.erase("challenge_w1")
	check(Campaign.challenge_open(1)==1,"clearing the world opens step I")
	Game.progression.counters["challenge_w1"]=1;check(Campaign.challenge_open(1)==2,"clearing I opens II")
	Campaign.configure(1);var base_skill=Professionalism.skill(0);var base_size=WaveDirector.wave_size(0,0)
	Campaign.challenge=2
	check(is_equal_approx(Professionalism.skill(0),base_skill+2*Campaign.CHALLENGE_SKILL),"each step adds professionalism")
	check(is_equal_approx(Campaign.reward_multiplier(),1.5),"step II pays +50%")
	Campaign.challenge=3;check(WaveDirector.wave_size(0,0)==base_size+1,"step III adds one enemy per wave")
	Game.progression.complete_world(1);check(int(Game.progression.counters.challenge_w1)==3,"clearing at III records it")
	Campaign.configure(1);check(Campaign.challenge==0,"configure starts at normal")
	Game.progression.counters["challenge_w1"]=1
	var picker=preload("res://scripts/ui/world_select.gd").new();add_child(picker)
	for i in 10:await get_tree().process_frame
	check(picker.challenge_for(1)==2,"the last open step is chosen by default")
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-ladder.png")
	picker.queue_free()
	Game.progression.cleared_worlds=worlds;Game.progression.counters=counters;Campaign.configure(1)
	print("CHALLENGE LADDER: %d failures" % failures);get_tree().quit(1 if failures else 0)
