extends Node
# Quests for world 1 and endless: no locked-world references, document rewards, new events, messenger feed.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func settle():
	for i in range(3):await get_tree().process_frame
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades()
	var Q=preload("res://scripts/progression/quest_catalog.gd")
	var all=Q.STORY+Q.INSTITUTE+Q.BRIEFINGS
	var stale=all.filter(func(q):return "мир 2" in (q.text+q.hint).to_lower() or "мир 3" in (q.text+q.hint).to_lower() or "цитадел" in (q.text+q.hint).to_lower() or "втором мире" in q.hint)
	check(stale.is_empty(),"no quest points to locked worlds %s" % str(stale.map(func(q):return q.id)))
	check(all.all(func(q):return q.has("docs")),"every quest states its document reward")
	for type in RoutePlan.CHALLENGES:check(Q.BRIEFINGS.any(func(q):return q.event=="challenge_"+type),"briefing for challenge "+type)
	check(Q.sender(Q.STORY[0])=="story" and Q.sender(Q.INSTITUTE[0])=="institute" and Q.sender(Q.BRIEFINGS[0])=="operations","senders")
	var p=Game.progression
	var quest=Q.STORY.filter(func(q):return q.id=="general1")[0]
	p.accepted.append(quest.id);p.event(quest.event,1,true);var cores=Game.cores;var credits=Game.credits
	check(p.claim(quest) and Game.cores==cores+quest.docs and Game.credits==credits+quest.alloy,"claim pays alloy and documents")
	var before=int(p.counters.get("challenge_any",0))
	Campaign.configure(1)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.sandbox=true;arena.sandbox_mode="hold";arena.sandbox_difficulty=2;add_child(arena);arena.set_physics_process(false);await settle()
	arena.challenges.complete(arena.player.position)
	check(int(p.counters.get("challenge_any",0))==before+1 and int(p.counters.get("challenge_hold",0))>=1 and int(p.counters.get("challenge_hard",0))>=1,"challenge success counts")
	RunUpgrades.apply(arena,"opening_shot",0)
	for i in range(5):RunUpgrades.apply(arena,"fire",0)
	check(int(p.counters.get("behavior_cards",0))>=1 and int(p.counters.get("card_stack",0))>=5,"card events count")
	arena.queue_free();await settle()
	# Messenger feed in the command centre: new messages on top.
	var memory=preload("res://scripts/ui/tablet_memory.gd");memory.loaded=true;memory.state={}
	var view=preload("res://scripts/ui/field_tablet.gd").new();view.manage=true;view.tab="quests";add_child(view);await settle()
	var feed=view.find_child("QuestFeed",true,false)
	check(feed!=null and feed.get_child_count()>0,"quest feed renders")
	var first=feed.get_children().filter(func(c):return c.name.begins_with("Quest_"))
	check(not first.is_empty() and first[0].has_node("Bubble"),"quests are messages with bubbles")
	view.queue_free();await settle()
	print("QUESTS: %d failures" % failures);get_tree().quit(1 if failures else 0)
