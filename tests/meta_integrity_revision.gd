extends Node
## The big consistency test of the meta (2026-10-03, author: «эпик-тест на работоспособность»).
## Part 1 — the data tables reference each other: roadmap steps ↔ rewards ↔ art, classes ↔ abilities ↔ stats,
## blueprints ↔ buildings ↔ stations, every counter a goal waits for is really written by the game, every
## player-facing meta text has English.
## Part 2 — a fresh profile walks the intended path (first field → rewards → class level 3 → Arsenal → Штаб →
## yard and Стоянка → second class → boss → world 1 → save round trip) and every step opens what it should.
## Hard breaks are FAIL; art gaps and known design questions are WARN (printed, not failing).
## Saves stay off: Game.save_enabled and Settings.persistence_enabled are false the whole time.
const BaseProgression=preload("res://scripts/progression/base_progression.gd")
const RunState=preload("res://scripts/state/run_state.gd")
var failures=0
var warnings:=[]
func check(ok:bool,message:String):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func warn(message:String):warnings.append(message);print("WARN ",message)
func _ready():call_deferred("run")

## Every literal counter the code writes: progression.event("x") and event("x",…) plus dynamic prefixes.
func emitted()->Dictionary:
	var found={"literal":{},"prefix":{}}
	var exact=RegEx.create_from_string("event\\(\\s*\"([a-z0-9_]+)\"\\s*[,)]")
	var prefix=RegEx.create_from_string("event\\(\\s*\"([a-z0-9_]+_)\"\\s*\\+")
	var calls=RegEx.create_from_string("progression\\.event\\(([^\n]*)")
	var literal=RegEx.create_from_string("\"([a-z][a-z0-9_]*)\"")
	var counters=RegEx.create_from_string("counters\\[\\s*\"([a-z0-9_%]+)\"")
	var stack=["res://scripts"]
	while not stack.is_empty():
		var dir=stack.pop_back()
		for sub in DirAccess.get_directories_at(dir):stack.append(dir.path_join(sub))
		for file in DirAccess.get_files_at(dir):
			if not file.ends_with(".gd"):continue
			var text=FileAccess.get_file_as_string(dir.path_join(file))
			for m in exact.search_all(text):found.literal[m.get_string(1)]=true
			# event("a" if x else "b"): every literal in the call's line counts.
			for m in calls.search_all(text):
				for lit in literal.search_all(m.get_string(1)):found.literal[lit.get_string(1)]=true
			for m in prefix.search_all(text):found.prefix[m.get_string(1)]=true
			for m in counters.search_all(text):
				var key=m.get_string(1)
				if "%" in key:found.prefix[key.get_slice("%",0)]=true
				else:found.literal[key]=true
	return found
func written(found:Dictionary,id:String)->bool:
	if found.literal.has(id) or BaseProgression.STATE_EVENTS.has(id):return true
	for p in found.prefix:
		if id.begins_with(p):return true
	return BaseProgression.STATE_PREFIXES.any(func(p):return id.begins_with(p))
func is_fallback(texture:Texture2D)->bool:return texture==null or texture.resource_path.ends_with("v1/recipe.png")
func english(text:String)->bool:
	return Texts.localization.exact.has(text.to_lower()) or Texts.localization.exact.has(text)

func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false
	var keep_profile=JSON.parse_string(JSON.stringify(Game.serialize_progress()))
	Game.reset_upgrades();Campaign.configure(1)
	var found=emitted()
	check(found.literal.size()>30,"static scan found the game's counters (%d)" % found.literal.size())

	# ── Roadmap ──────────────────────────────────────────────────────────────────────────────────────────
	var road=preload("res://scripts/ui/stations/roadmap_station.gd").new()
	var step_ids=[]
	for tab in road.tabs():
		for step in road.steps(tab[0]):step_ids.append(str(step[0]))
		check(not road.items(tab[0]).is_empty(),"roadmap tab «%s» has steps" % tab[1])
		check(not is_fallback(UiKit.icon_texture(str(tab[2]))),"roadmap tab icon «%s» resolves" % tab[2])
	for id in step_ids:
		check(road.reward(id)>0,"roadmap step %s pays a reward" % id)
		if not ResourceLoader.exists("res://assets/ui/roadmap/%s.png" % id):warn("roadmap step %s has no art (assets/ui/roadmap/%s.png)" % [id,id])
	for id in road.REWARDS:check(id in step_ids,"roadmap reward %s belongs to a step" % id)
	for file in DirAccess.get_files_at("res://assets/ui/roadmap"):
		if file.ends_with(".png") and file.get_basename() not in step_ids:warn("roadmap art %s matches no step" % file)
	for counter in ["world_depth_1","endless_cycle","challenge_w1","challenge_maze","challenge_hard"]:
		check(written(found,counter),"roadmap counter «%s» is written by the game" % counter)

	# ── Classes ──────────────────────────────────────────────────────────────────────────────────────────
	for id in ClassCatalog.ROSTER:
		check(Game.CLASSES.has(id) and ClassCatalog.INFO.has(id),"class %s is in CLASSES and INFO" % id)
		check(ClassCatalog.BIO.has(id) and ClassCatalog.BIO[id].size()==3,"class %s has a three-part bio" % id)
		check(ClassCatalog.PATHS.has(id) and ClassCatalog.PATHS[id].stats.size()==5 and ClassCatalog.perks(id).size()==4,"class %s has a path: five stats and four perks" % id)
		check(Game.CLASS_SKILLS.has(id) and Game.CLASS_CHOICES.has(id),"class %s has its Q and choices" % id)
		for ability in ClassCatalog.abilities(id):
			check(AbilityCatalog.DATA.has(ability),"class %s ability %s exists" % [id,ability])
			if AbilityCatalog.DATA.has(ability) and is_fallback(UiKit.icon_texture("abilities/"+ability)):warn("ability %s has no icon of its own" % ability)
		var unlock:Dictionary=ClassCatalog.INFO[id].unlock
		if unlock.has("event"):check(written(found,str(unlock.event)),"class %s unlock counter «%s» is written" % [id,unlock.event])
		var stats=[]
		for m in ClassCatalog.INFO[id].modifiers:stats.append(str(m.stat))
		for stat in ClassCatalog.PATHS[id].stats:
			if ClassCatalog.STATS[stat].has("field"):stats.append(str(ClassCatalog.STATS[stat].field))
		for perk in ClassCatalog.perks(id):
			if perk.has("card"):check(UpgradeRegistry.has(str(perk.card)),"class %s perk «%s» reuses a real card" % [id,perk.title])
			if perk.has("effect"):check(ResourceLoader.exists(str(perk.effect)),"class %s perk «%s» has its effect script" % [id,perk.title])
		var probe=RunState.new()
		for stat in stats:check(stat in probe,"class %s stat «%s» is a run field" % [id,stat])
		for text in ClassCatalog.BIO[id]:
			if not english(str(text)):warn("class %s bio line has no English: %s" % [id,str(text).left(40)])
	check(ClassCatalog.MAX_LEVEL==20,"class path has 20 levels")
	for lv in ClassCatalog.ABILITY_LEVELS+ClassCatalog.PERK_LEVELS:check(not ClassCatalog.milestone("recruit",lv).is_empty(),"class path marks level %d" % lv)

	# ── Blueprints, buildings, stations ─────────────────────────────────────────────────────────────────
	var obtainable={}
	for stage in range(0,7):
		for level in [1,2]:
			for recipe in EncounterRules.recipe_pool(level,[],stage,true):obtainable[str(recipe.category)+":"+str(recipe.id)]=true
	for id in Game.RESEARCH:
		if id in Game.RETIRED_BUILDINGS:continue
		check(obtainable.has("research:"+id) or id in EncounterRules.GUARANTEED.values(),"blueprint %s can drop in world 1" % id)
	for id in Game.BUILD_COST:
		check(Game.RESEARCH.has(id),"building %s has a blueprint" % id)
		check(preload("res://scripts/ui/stations/hq_station.gd").building_name(id)!=id,"building %s has a name" % id)
		if not ResourceLoader.exists("res://assets/ui/buildings/%s.png" % id):warn("building %s has no picture" % id)
	for need in Game.BUILDING_REQUIRES.values():check(need=="yard" or need in Game.BUILD_COST,"building requirement %s is a building" % need)
	var hub_script=load("res://scripts/hub.gd")
	for kind in hub_script.STATIONS:
		var gate=str(hub_script.STATIONS[kind][0])
		check(gate=="" or gate in Game.BUILD_COST,"station %s is gated by a real building (%s)" % [kind,gate])
		var provider=load(hub_script.STATIONS[kind][1]).new()
		for tab in provider.tabs():
			if provider.has_method("page_for") and provider.page_for(tab[0])!=null:continue
			var list=provider.items(tab[0])
			for item in list:check(str(item.get("id",""))!="" and str(item.get("title",""))!="","station %s/%s items have id and title" % [kind,tab[0]])

	# from guaranteed_blueprints: world 1 hands HQ at the end of the first segment and the Garage in the middle
	# one, until owned; never twice in a run. Building blueprints survive a death, weapons roll.
	var research_keep=Game.research_unlocks.duplicate()
	Campaign.configure(1);Game.research_unlocks.erase("headquarters");Game.research_unlocks.erase("garage")
	check(EncounterRules.guaranteed(1,[])=={"category":"research","id":"headquarters"},"guaranteed HQ blueprint at the end of the first segment")
	check(EncounterRules.guaranteed(3,[])=={"category":"research","id":"garage"},"guaranteed Garage blueprint in the middle segment")
	check(EncounterRules.guaranteed(0,[]).is_empty() and EncounterRules.guaranteed(2,[]).is_empty(),"other fields stay random")
	check(EncounterRules.guaranteed(1,[{"category":"research","id":"headquarters"}]).is_empty(),"a guaranteed blueprint is not given twice in one run")
	Game.research_unlocks.append("headquarters")
	check(EncounterRules.guaranteed(1,[]).is_empty(),"no guaranteed blueprint once it is owned")
	check(RecipeExtraction.survivors([{"category":"research","id":"garage"},{"category":"weapon","id":"smg"}],false,0,RandomNumberGenerator.new()).size()==1,"building blueprints survive a death, weapons roll")
	Game.research_unlocks=research_keep

	# from world1_content_revision: world 1 holds the content of all worlds; tiers open along the route.
	var pool_ids=func(level:int,stage:int)->Array:return EncounterRules.recipe_pool(level,[],stage,true).map(func(r):return r.id)
	check(Campaign.recipe_world()==3 and Campaign.unified_content(),"world 1 holds all content")
	check(pool_ids.call(2,0).is_empty() and pool_ids.call(2,1).is_empty(),"no rare blueprints on the first two stages")
	check(pool_ids.call(1,0).all(func(id):return Game.TIERS.tier(id)<=1),"early stages drop common blueprints")
	for id in ["sniper","rpg","vehicle_tank","vehicle_apc","laser","airstrike"]:check(id in pool_ids.call(2,6) or id in pool_ids.call(2,4),"late world 1 can drop "+id)
	check(not ("vehicle_tank" in pool_ids.call(2,2)),"tank blueprint waits for the second half")
	for id in Game.CLASSES:check(Game.class_world(id)==1,"shell available in world 1: "+id)
	var counters_keep=Game.progression.counters.duplicate()
	Game.progression.counters["field_reached"]=5
	check(Game.can_select_class("heavy") and Game.can_select_class("engineer"),"classes open by goals in world 1")
	Game.progression.counters=counters_keep
	Campaign.configure(2)
	check(not Campaign.unified_content() and Campaign.recipe_world()==2,"locked world 2 keeps its gating")
	Campaign.configure(1)
	# Barrels grow towards the boss; the boss arena has barrels only in its corners.
	var counts=[]
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=77;add_child(arena);arena.set_physics_process(false);arena.auto_pause_enabled=false
	for room in range(7):
		arena.begin_room(room)
		for f in range(3):await get_tree().process_frame
		counts.append(arena.room.walls.values().filter(func(w):return w.get("barrel",false)).size())
	check(counts[0]>=1 and counts[5]>counts[0],"barrels grow along the route %s" % str(counts))
	var g=arena.room.grid_size
	var corners=[Vector2i(1,2),Vector2i(g-2,2),Vector2i(1,g-6),Vector2i(g-2,g-6)].filter(func(c):return arena.room.walls.has(c) and arena.room.walls[c].get("barrel",false)).size()
	check(counts[6]>=3 and corners==counts[6],"boss barrels only in the corners (%d)" % counts[6])
	# The mechanic upgrades the vehicle the player has, not a world-bound one.
	arena.pending_vehicle="tank"
	var service=load("res://scripts/service_room.gd").new();service.branch="vehicle";arena.begin_playground(service,2)
	for f in range(3):await get_tree().process_frame
	check(service.vehicle=="tank","mechanic works on the pending tank")
	arena.end_service();arena.pending_vehicle=""
	arena.queue_free()
	for f in range(3):await get_tree().process_frame

	# ── Quests: every goal counter is written ────────────────────────────────────────────────────────────
	var quests=preload("res://scripts/progression/quest_catalog.gd")
	for q in quests.STORY+quests.INSTITUTE+quests.BRIEFINGS:
		check(written(found,str(q.event)),"quest %s counter «%s» is written" % [q.id,q.event])
		if q.has("requires") and str(q.requires)!="":check(written(found,str(q.requires).get_slice(":",0)) or str(q.requires).contains(":"),"quest %s requirement «%s» is written" % [q.id,q.requires])
		if not english(str(q.text)):warn("quest %s title has no English" % q.id)

	# ── The path of a fresh profile ──────────────────────────────────────────────────────────────────────
	Game.reset_upgrades();Game.progression.counters.clear();Game.progression.seen.clear();Game.progression.cleared_worlds.clear();Game.credits=0
	check(Game.class_unlocks==["recruit"] or Game.class_unlocks.has("recruit"),"start: Стрелок is open")
	check(Game.class_loadout().is_empty(),"start: no abilities yet")
	check(road.unclaimed().is_empty() if road.has_method("unclaimed") else true,"start: nothing to claim on the roadmap")
	check(preload("res://scripts/wall_counter.gd").value()==9,"start: the wall reads 9")
	# First field.
	Game.progression.event("world_depth_1",1,true)
	# from roadmap_rewards: a reached step waits to be claimed by hand; an unreached one pays nothing.
	check("depth1" in road.unclaimed(),"first field: the roadmap step is waiting to be claimed")
	var d=road.detail("story","depth1")
	check(d.actions.size()==1 and d.actions[0].id=="claim","the step detail offers to claim it")
	var before=Game.credits
	check(road.act("story","depth1","claim")!="" and Game.credits==before+road.reward("depth1"),"first field: the roadmap pays %d ◈" % road.reward("depth1"))
	before=Game.credits
	check(road.act("story","depth1","claim")=="" and Game.credits==before,"a reward is paid once")
	check(road.act("story","depth3","claim")=="" and Game.credits==before,"an unreached step pays nothing")
	# Class to level 3: the first ability.
	Game.credits=10000
	for i in range(2):Game.upgrade_class("recruit",false)
	check(ClassCatalog.level("recruit")==3 and not Game.class_loadout().is_empty(),"class level 3 brings the first ability (%s)" % str(Game.class_loadout()))
	# Arsenal from its blueprint.
	check(not Game.build_workshop("weapons"),"no Arsenal without its blueprint")
	Game.bank_recipes([{"category":"research","id":"weapons"}])
	check(Game.build_workshop("weapons") and "weapons" in Game.built_workshops,"the Arsenal blueprint builds the Arsenal")
	check(road.steps("base")[0][2],"the roadmap sees the Arsenal")
	# Штаб, then yard → Стоянка.
	Game.bank_recipes([{"category":"research","id":"headquarters"}])
	check(Game.build_workshop("headquarters"),"Штаб builds from its blueprint")
	Game.bank_recipes([{"category":"research","id":"garage"}])
	check(not Game.build_workshop("garage"),"Стоянка waits for the yard")
	check(Game.build_workshop("yard") and Game.build_workshop("garage"),"yard, then Стоянка")
	# Second class by its goal.
	Game.progression.event("barrel_kills",10)
	check(Game.can_select_class("gunner"),"10 barrel kills open the Подрывник")
	# A boss, then world 1.
	Game.progression.event("boss_wins")
	check(preload("res://scripts/wall_counter.gd").value()==8,"a boss win turns the wall to 8")
	# from wall_counter_revision: the wall clicks 9 → 8 once after the boss and remembers it (tween sped up).
	Game.progression.counters.erase("wall_shown")
	var scale_keep=Engine.time_scale;Engine.time_scale=20.0
	var wall=preload("res://scripts/wall_counter.gd").new();add_child(wall)
	await get_tree().process_frame
	check(wall.clicking and wall.label.text=="9","the wall starts clicking from the last shown 9")
	var waited=0
	while int(Game.progression.counters.get("wall_shown",9))!=8 and waited<300:
		await get_tree().process_frame;waited+=1
	check(wall.label.text=="8" and int(Game.progression.counters.get("wall_shown",9))==8,"the wall clicks to 8 and remembers it")
	wall.queue_free();Engine.time_scale=scale_keep
	wall=preload("res://scripts/wall_counter.gd").new();add_child(wall)
	await get_tree().process_frame
	check(not wall.clicking and wall.label.text=="8","no second click on the next visit")
	wall.queue_free()
	Game.progression.complete_world(1)
	check(not Campaign.unlocked(2) and Campaign.infinite_unlocked() and road.steps("story")[3][2],"world 1 done: the endless front opens, world 2 stays closed in the demo, the roadmap marks the general")
	Settings.values["dev_worlds"]=true
	check(Campaign.unlocked(2) and not Campaign.unlocked(3),"the development switch opens world 2 (world 3 still needs world 2)")
	Settings.values["dev_worlds"]=false
	# Save round trip of everything the path touched.
	var loadout=Game.class_loadout()
	# A JSON snapshot right away: serialize_progress hands out the live arrays, which reset_upgrades clears.
	var snapshot=JSON.stringify(Game.serialize_progress())
	var verdict=preload("res://scripts/profile/schema.gd").validate(JSON.parse_string(snapshot))
	check(verdict.get("ok",false),"the profile passes the schema (%s)" % verdict.get("error",""))
	Game.reset_upgrades();Game.apply_profile(JSON.parse_string(snapshot))
	check("garage" in Game.built_workshops,"buildings survive a reload")
	check(ClassCatalog.level("recruit")==3,"class level survives a reload (%d)" % ClassCatalog.level("recruit"))
	check("roadmap_reward:depth1" in Game.progression.seen,"claimed roadmap rewards survive a reload")
	check(int(Game.progression.counters.get("boss_wins",0))==1,"boss wins survive a reload")
	check(Game.class_loadout()==loadout,"the ability loadout survives a reload")

	Game.reset_upgrades();Game.apply_profile(keep_profile)
	print("META INTEGRITY: %d failures, %d warnings" % [failures,warnings.size()])
	get_tree().quit(1 if failures else 0)
