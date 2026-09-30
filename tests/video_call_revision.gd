extends Node
## Tutorial video calls: order of triggers, shown once, every line localized.
var errors=0
func check(value:bool,message:String):
	if value:print("PASS ",message)
	else:errors+=1;push_error("FAIL: "+message)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false
	var Call=preload("res://scripts/ui/video_call.gd")
	var p=Game.progression;p.seen=p.seen.filter(func(s):return not str(s).begins_with("call_"));p.counters.erase("deaths");p.counters.erase("world_depth_1")
	var built=Game.built_workshops.duplicate();Game.built_workshops.erase("garage")
	check(Call.due(null)=="intro","intro comes first")
	var view=Call.new();view.id="intro";add_child(view);await get_tree().process_frame
	for i in range(40):
		if not is_instance_valid(view):break
		view.advance();view.advance()
	await get_tree().process_frame
	check(not is_instance_valid(view) and "call_intro" in p.seen,"intro plays through and is remembered")
	check(Call.due(null)=="","nothing else is due on a fresh profile")
	p.event("deaths");check(Call.due(null)=="first_death","first death call after dying")
	Call.mark_seen("first_death");Game.built_workshops.append("garage");check(Call.due(null)=="garage","garage call after the motor pool is built")
	Call.mark_seen("garage");p.event("world_depth_1",4,true);check(Call.due(null)=="general","general call on approach")
	Game.built_workshops=built
	var missing=[]
	for call in Call.CALLS:
		for line in Call.CALLS[call]:
			if not Texts.localization.exact.has(str(line[1]).to_lower()):missing.append(line[1])
	check(missing.is_empty(),"all call lines have English "+str(missing))
	print("VIDEO CALL: %d failures" % errors);get_tree().quit(1 if errors else 0)
