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
	var p=Game.progression;p.seen=p.seen.filter(func(s):return not str(s).begins_with("call_"))
	for key in ["deaths","world_depth_1","extracted","merchant_buy","slot_play","challenge_any","legend_taken","challenge_w1"]:p.counters.erase(key)
	p.claimed.clear();p.cleared_worlds.clear();Game.built_workshops.erase("headquarters")
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
	p.event("extracted",30);check(Call.due(null)=="first_haul","story order: first haul before the general")
	Game.built_workshops=built
	# Incoming call: a ringing corner button, the call itself opens only on answer.
	var ring=preload("res://scripts/ui/incoming_call.gd").new();ring.call_id="first_haul";add_child(ring)
	var opened=[];ring.answered.connect(func():opened.append(true))
	await get_tree().create_timer(.4).timeout
	check(ring.get_node("Answer").position.x>ring.size.x*.7 and ring.get_node("Answer").position.y<200,"handset sits in the top-right corner")
	check(opened.is_empty(),"nothing opens until answered")
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-call-ring.png")
	ring.get_node("Answer").pressed.emit();await get_tree().process_frame
	check(opened.size()==1 and not is_instance_valid(ring),"answer opens the call and removes the button")
	var missing=[]
	for call in Call.CALLS:
		for line in Call.CALLS[call]:
			if not Texts.localization.exact.has(str(line[1]).to_lower()):missing.append(line[1])
	check(missing.is_empty(),"all call lines have English "+str(missing))
	print("VIDEO CALL: %d failures" % errors);get_tree().quit(1 if errors else 0)
