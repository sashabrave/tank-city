extends Node
## Observes transitions only; does not alter quests, progression or combat randomness.
var previous:Dictionary={}
var countdown_key=""
var timer=0.0
func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	sample_progression()
func _process(delta):
	timer-=delta
	if timer>0:return
	timer=.1
	sample_progression()
	var main=get_tree().current_scene
	if not is_instance_valid(main):return
	var current=main.get("current")
	if not is_instance_valid(current) or not current.is_inside_tree():countdown_key="";return
	var room=current.get("room")
	if room==null:return
	if room.commander_countdown and current.phase=="countdown":
		var key=str(current.get_instance_id())+":"+str(ceili(current.countdown))
		if key!=countdown_key:Game.sound("countdown_tick",Game);countdown_key=key
	elif countdown_key!="":
		if current.phase=="combat":Game.sound("commander_arrive",Game)
		countdown_key=""
func sample_progression():
	var p=Game.progression
	var ready=[]
	for chain in [p.QUESTS.STORY,p.QUESTS.INSTITUTE]:
		for q in chain:
			if q.id in p.claimed:continue
			if q.id in p.accepted and p.count(q)>=q.goal:ready.append(q.id)
			break
	var state={"object":p.get_instance_id(),"level":p.level,"claimed":p.claimed.size(),"telegram":p.telegram.get("id",""),"weapons":p.weapon_levels.duplicate(),"built":Game.built_workshops.size(),"ready":ready}
	if not previous.is_empty() and previous.object==state.object:
		if state.level>previous.level:Game.sound("base_level_up",Game)
		elif state.claimed>previous.claimed:Game.sound("quest_claim",Game)
		elif state.built>previous.built:Game.sound("build_complete",Game)
		elif state.weapons!=previous.weapons:Game.sound("weapon_tune",Game)
		elif state.telegram!="" and state.telegram!=previous.telegram:Game.sound("telegram_accept",Game)
		elif state.ready.any(func(id):return id not in previous.ready):Game.sound("quest_ready",Game)
	previous=state
