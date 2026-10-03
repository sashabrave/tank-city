extends RefCounted
const QUESTS=preload("res://scripts/progression/quest_catalog.gd")
var cleared_worlds:Array=[]
var tracked:Array=[]
var accepted:Array=[]
var viewed_updates:Dictionary={}
var tracker_collapsed=false
var completed_orders:Array=[]
var order_wait=0
var order_serial=0
var combat_entered=false
var recent_sorties:Array=[]
var sortie_counts:Dictionary={}
var sortie_active=false
var seen:Array=[]
var outcome_serial=0
var level=1
var xp=0
var insurance=0
var weapon_levels:Dictionary={}
var counters:Dictionary={}
## Summary of the last finished sortie for the «Вылазка» tab outside a run.
var last_run:Dictionary={}
var daily:Dictionary={}  # DailyRun records by UTC date
var claimed:Array=[]
## Progress of accepted action quests, counted only after the quest was taken (id → value).
var quest_progress:Dictionary={}
var boss_classes:Array=[]
var telegram:Dictionary={}
var telegram_options:Array=[]
var telegram_result="Выбери приказ на следующую вылазку"
func serialize()->Dictionary:
	return {"accepted":accepted,"viewed_updates":viewed_updates,"worlds":cleared_worlds,"tracked":tracked,"collapsed":tracker_collapsed,"completed_orders":completed_orders,"order_wait":order_wait,"order_serial":order_serial,"sortie_active":sortie_active,"combat_entered":combat_entered,"sortie_counts":sortie_counts,"recent_sorties":recent_sorties,"seen":seen,"level":level,"xp":xp,"insurance":insurance,"weapons":weapon_levels,"counters":counters,"daily":daily,"claimed":claimed,"quest_progress":quest_progress,"boss_classes":boss_classes,"telegram":telegram,"telegram_options":telegram_options,"telegram_result":telegram_result,"last_run":last_run}
func restore(data:Dictionary):
	last_run=data.get("last_run",{}) if data.get("last_run",{}) is Dictionary else {}
	cleared_worlds=data.get("worlds",[]).map(func(value):return int(value));tracked=data.get("tracked",["first_alloy","institute_character"]);tracker_collapsed=data.get("collapsed",false)
	accepted=data.get("accepted",tracked.duplicate());viewed_updates=data.get("viewed_updates",{})
	completed_orders=data.get("completed_orders",[]);order_wait=data.get("order_wait",0);order_serial=data.get("order_serial",0)
	sortie_active=data.get("sortie_active",false);combat_entered=data.get("combat_entered",false);sortie_counts=data.get("sortie_counts",{})
	recent_sorties=data.get("recent_sorties",[]).slice(-3)
	seen=data.get("seen",[]);level=maxi(1,int(data.get("level",1)));xp=maxi(0,int(data.get("xp",0)));insurance=clampi(int(data.get("insurance",0)),0,10)
	weapon_levels=data.get("weapons",{});counters=data.get("counters",{});daily=data.get("daily",{});claimed=data.get("claimed",[]);boss_classes=data.get("boss_classes",[]);telegram=data.get("telegram",{});telegram_options=data.get("telegram_options",[]);telegram_result=data.get("telegram_result",telegram_result)
	quest_progress=data.get("quest_progress",{})
	# Saves before 0.7 kept no per-quest progress: quests already taken keep what they had.
	if not data.has("quest_progress"):
		for q in QUESTS.STORY+QUESTS.INSTITUTE+QUESTS.BRIEFINGS:
			if q.id in accepted and q.id not in claimed:quest_progress[q.id]=int(counters.get(q.event,0))
	if not data.has("worlds"):
		for pair in [[1,"boss_6"],[2,"boss_15"],[3,"boss_16"]]:
			if int(counters.get(pair[1],0))>0:cleared_worlds.append(pair[0])
	if not telegram.is_empty():
		if not str(telegram.id).begins_with("order_"):order_serial+=1;telegram.id="order_"+str(order_serial)
		telegram["runs_left"]=telegram.get("runs_left",3);telegram["run_limit"]=telegram.get("run_limit",3)
		telegram["hint"]=telegram.get("hint","Выполни приказ за несколько вылазок. Сдай в командном центре.")
func required_xp()->int:return roundi(120*pow(level,1.45))
func level_cost()->int:return roundi(500*pow(level,1.6))
func upgrade()->bool:
	if xp<required_xp() or Game.credits<level_cost():return false
	xp-=required_xp();Game.credits-=level_cost();level+=1
	if is_instance_valid(Game.notifications):Game.notifications.post("Уровень базы повышен до %d" % level,"Командование","important")
	Game.save_progress();return true
func cap()->int:return mini(20,level*3)
func event(id:String,amount:int=1,maximum:bool=false):
	if sortie_active and not maximum:sortie_counts[id]=int(sortie_counts.get(id,0))+amount
	counters[id]=maxi(int(counters.get(id,0)),amount) if maximum else int(counters.get(id,0))+amount
	if not telegram.is_empty() and telegram.get("active",false) and telegram.event==id:telegram.progress=mini(telegram.goal,telegram.progress+amount)
	if state_event(id):return
	for q in QUESTS.STORY+QUESTS.INSTITUTE+QUESTS.BRIEFINGS:
		if q.event!=id or q.id not in accepted or q.id in claimed:continue
		var now=int(quest_progress.get(q.id,0))
		quest_progress[q.id]=maxi(now,amount) if maximum else now+amount
## One-shot story states (built, owned, opened, cleared) count from the profile, so a step done earlier never
## blocks the story. Everything else is an action and counts only after the quest is taken.
const STATE_PREFIXES=["world_clear_","own_","build_","recipe_","enter_world_"]
const STATE_EVENTS=["vehicle_equipment","health_level","camp_level","shells","weapon_level","boss_classes","enter_endless"]
static func state_event(id:String)->bool:
	return id in STATE_EVENTS or STATE_PREFIXES.any(func(prefix):return id.begins_with(prefix))
func sync():
	for id in cleared_worlds:event("world_clear_"+str(id),1,true)
	for kind in Game.garage.owned:event("own_"+kind,1,true)
	for value in Game.garage.levels.values():event("vehicle_equipment",int(value),true)
	for id in Game.built_workshops:event("build_"+id,1,true)
	event("health_level",Game.health_level,true);event("camp_level",Game.camp_level,true)
	event("shells",Game.class_unlocks.size(),true)
	for value in weapon_levels.values():event("weapon_level",int(value),true)
	for id in Game.ability_unlocks:event("recipe_"+id,1,true)
func active(chain:Array)->Dictionary:
	sync()
	for quest in chain:
		if quest.id not in claimed:return quest
	if chain==QUESTS.STORY and "another_class" in claimed:
		var target=3
		while "another_class_"+str(target) in claimed:target+=1
		if target<=Game.CLASSES.size():return {"id":"another_class_"+str(target),"text":"Победи гигабосса новым классом","event":"boss_classes","goal":target,"alloy":500+100*(target-2),"xp":400}
	return {}
func claim(quest:Dictionary)->bool:
	if quest.is_empty() or quest.id not in accepted or quest.id in claimed or count(quest)<quest.goal:return false
	var was_tracked=quest.id in tracked;tracked.erase(quest.id)
	claimed.append(quest.id)
	xp+=int(quest.get("xp",0));Game.earn(int(quest.alloy)+int(quest.get("docs",0))*Game.DOC_ALLOY);Game.save_progress();return true
func choose_telegram(index:int):
	if not telegram.is_empty() or order_wait>0 or index<0 or index>=telegram_options.size():return
	telegram=telegram_options[index].duplicate(true);telegram.progress=0;telegram.active=false
	order_serial+=1;telegram["template"]=telegram.id;telegram.id="order_"+str(order_serial)
	telegram["runs_left"]=telegram.run_limit
	viewed_updates["operations"]=operations_signature()
	Game.notifications.post("Новый приказ\n"+telegram.text,"Оперштаб","important");Game.save_progress()
func prepare_telegrams():
	if not telegram.is_empty() or order_wait>0:return
	if not telegram_options.is_empty() and telegram_options.all(func(q):return q.get("adaptive_version",0)==2):return
	var rng=RandomNumberGenerator.new();rng.randomize()
	telegram_options=preload("res://scripts/progression/adaptive_orders.gd").create(self,rng)
	if is_instance_valid(Game.notifications):Game.notifications.post("Поступила телеграмма: выбери сложность задания в командном центре.","Оперштаб","important")
	Game.save_progress()
func begin_run():
	sortie_counts.clear();sortie_active=true;combat_entered=false
	counters["runs"]=int(counters.get("runs",0))+1
	prepare_telegrams()
	if not telegram.is_empty():telegram.active=true
	for id in Game.equipped_abilities:event("use_"+id)
	Game.save_progress()
func end_run():
	if not sortie_active:return
	sortie_active=false
	if combat_entered:
		if int(sortie_counts.get("waves",0))>0 or int(sortie_counts.get("infantry",0))>0:
			recent_sorties.append(sortie_counts.duplicate());recent_sorties=recent_sorties.slice(-3)
		if order_wait>0:order_wait-=1
		if not telegram.is_empty() and telegram.get("active",false) and telegram.progress<telegram.goal:
			telegram.runs_left=maxi(0,int(telegram.runs_left)-1)
			if telegram.runs_left==0:
				outcome_serial+=1;telegram_result="Приказ провален: "+telegram.text
				Game.notifications.post(telegram_result,"Оперштаб","important");telegram={};telegram_options=[]
	if not telegram.is_empty():telegram.active=false
	combat_entered=false;prepare_telegrams();Game.save_progress()
func claim_telegram()->bool:
	if telegram.is_empty() or telegram.progress<telegram.goal:return false
	xp+=telegram.xp;Game.earn(telegram.alloy);completed_orders.append(telegram.duplicate(true));completed_orders=completed_orders.slice(-60)
	telegram_result="Приказ сдан";telegram={};telegram_options=[];prepare_telegrams();Game.save_progress();return true
func abandon_telegram():
	if telegram.is_empty() and telegram_options.is_empty():return
	telegram={};telegram_options=[];viewed_updates["operations"]="";order_wait=1;telegram_result="Новая телеграмма после следующей вылазки"
	Game.notifications.post(telegram_result,"Оперштаб","important");Game.save_progress()
func record_field(index:int):
	event("depth",Campaign.progress_index(index)+1,true)
	if Campaign.endless:event("endless_fields")
	else:event("world_depth_"+str(Campaign.world),index+1,true)
func complete_world(id:int):
	if Campaign.challenge_level()>0:counters["challenge_w%d" % id]=maxi(int(counters.get("challenge_w%d" % id,0)),Campaign.challenge_level())
	if id not in cleared_worlds:
		cleared_worlds.append(id)
		Game.notifications.post("Мир %d завершён\n" % id+("Открыты мир 2 и бесконечный режим" if id==1 else "Открыт мир 3" if id==2 else "Гигабосс уничтожен"),"Командование","important")
	event("world_clear_"+str(id),1,true)
	Game.save_progress()
func count(q:Dictionary)->int:
	if str(q.id).begins_with("order_"):return mini(int(q.goal),int(q.get("progress",0)))
	if state_event(str(q.event)):return mini(int(q.goal),int(counters.get(q.event,0)))
	return mini(int(q.goal),int(quest_progress.get(q.id,0)))
func quests(filter:String="active")->Array:
	sync();var result=[]
	for chain in [QUESTS.STORY,QUESTS.INSTITUTE]:
		if filter=="completed":
			for q in chain:
				if q.id in claimed:result.append(q)
		else:
			var q=active(chain)
			if not q.is_empty():result.append(q)
	if filter=="completed":
		for q in QUESTS.BRIEFINGS:
			if q.id in claimed:result.append(q)
	else:
		var briefing=current_briefing()
		if not briefing.is_empty():result.append(briefing)
	if filter=="completed":result.append_array(completed_orders)
	elif not telegram.is_empty():result.append(telegram)
	if filter not in ["available","completed"]:result=result.filter(func(q):return q.id in accepted or str(q.id).begins_with("order_"))
	if filter=="tracked":return result.filter(func(q):return q.id in tracked)
	return result
## Operations briefings come one at a time in story order: the taken one until it is handed in, else the
## first whose requirement is met.
func current_briefing()->Dictionary:
	for q in QUESTS.BRIEFINGS:
		if q.id in accepted and q.id not in claimed:return q
	for q in QUESTS.BRIEFINGS:
		if q.id not in claimed and int(counters.get(q.get("requires",""),0))>=int(q.get("threshold",0)):return q
	return {}
func toggle_track(id:String):
	if not quests().any(func(q):return q.id==id):return
	if id in tracked:tracked.erase(id)
	else:
		if tracked.size()>=3:tracked.pop_front()
		tracked.append(id)
	Game.save_progress()

func notices()->Array:
	var result=[]
	for quest in quests("available"):
		if not str(quest.id).begins_with("order_"):result.append("quest:"+quest.id)
		if not str(quest.id).begins_with("order_") and quest.id in accepted and count(quest)>=quest.goal:result.append("ready:"+quest.id)
	if xp>=required_xp():result.append("base:"+str(level+1))
	return result
func has_news()->bool:return news_kind()!=""
func operations_signature()->String:
	if not telegram.is_empty():return str([telegram.id,telegram.progress>=telegram.goal])
	return str(telegram_options) if order_wait==0 and not telegram_options.is_empty() else ""
func operations_news()->bool:
	var signature=operations_signature()
	return signature!="" and signature!=str(viewed_updates.get("operations",""))
func news_kind()->String:
	if notices().any(func(id):return id not in seen):return "general"
	return "operations" if operations_news() else ""
func view_quest_updates(filter:String):
	if filter in ["all","operations"]:viewed_updates["operations"]=operations_signature()
	for q in quests("available"):
		if str(q.id).begins_with("order_"):continue
		if filter=="completed":continue
		# "main" (story + institute) and "operations" (briefings) mark only their own messages as seen.
		if filter=="main" and q in QUESTS.BRIEFINGS:continue
		if filter=="operations" and q not in QUESTS.BRIEFINGS:continue
		if filter=="general" and q in QUESTS.INSTITUTE:continue
		if filter=="institute" and q not in QUESTS.INSTITUTE:continue
		for id in ["quest:"+q.id,"ready:"+q.id]:
			if id in notices() and id not in seen:seen.append(id)
	Game.save_progress()
func build_targets()->Array:
	var result=[]
	for q in quests("available"):
		if str(q.event).begins_with("build_"):
			var id=str(q.event).trim_prefix("build_")
			if id not in Game.built_workshops:result.append(id)
	return result
func mark_seen():
	viewed_updates["operations"]=operations_signature()
	for id in notices():
		if id not in seen:seen.append(id)
	Game.save_progress()

func accept_quest(id:String)->bool:
	if id in accepted or not quests("available").any(func(q):return q.id==id):return false
	accepted.append(id);quest_progress[id]=0
	if tracked.size()<3:tracked.append(id)
	Game.save_progress();return true
func update_signature(section:String)->String:
	match section:
		"quests":return str(quests("available").map(func(q):return [q.id,count(q),q.id in accepted,q.id in claimed]))+operations_signature()
		"base":return str([level,xp,Game.credits>=level_cost()])
		"inventory":return str([Game.selected_weapon,Game.hero_loadout(),Game.hq_loadout(),Game.backpack_slots,Game.new_recipes])
		"fighter":return str([Game.selected_class,Game.total_upgrade_level()])
	return ""
func section_new(section:String)->bool:
	if section=="notifications":return Game.notifications.unread()>0
	var signature=update_signature(section)
	return signature!="" and str(viewed_updates.get(section,""))!=signature
func view_section(section:String):
	viewed_updates[section]=update_signature(section)
	if section=="base":
		for id in notices():
			if (str(id).begins_with("base:")== (section=="base")) and id not in seen:seen.append(id)
	Game.save_progress()
