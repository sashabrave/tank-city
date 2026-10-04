extends Node
var return_through_gate=false
## Test tool (hub → Инструменты): on the route map any room opens with «Перейти» and «Перейти с прокачкой».
var dev_map=false
var garage=preload("res://scripts/garage/state.gd").new()
var progression=preload("res://scripts/progression/base_progression.gd").new()
const TIERS=preload("res://scripts/progression/recipe_tiers.gd")
const LOOT=preload("res://scripts/loot_catalog.gd")

var notification_history:Array=[]
var notifications:CanvasLayer
var new_recipes:Array=[]
var duplicate_recipes:Array=[]
var save_path = "user://progress_v1.json"
const ProfileStore=preload("res://scripts/profile/store.gd")
const ProfileSchema=preload("res://scripts/profile/schema.gd")
var profiles=preload("res://scripts/profile/slots.gd").new()
var run_checkpoint:Dictionary={}
var run_save_baseline:Dictionary={}
var fresh_profile:Dictionary={}
var save_error=""
var save_blocked=false
signal profile_changed
var class_levels:Dictionary={}
var specializations:Dictionary={}
var cores=0
## 0.7 merged documents into alloy: one old document is worth this much alloy.
const DOC_ALLOY=40
var selected_class="recruit"
var class_unlocks:Array=["recruit"]
var ability_slots=1
var class_second_slots:Array=[]
## Meta stage 3: which of the two «1» abilities each class carries (class id → ability id), switchable in the hub.
var class_choices:Dictionary={}
## 0.8.0: abilities in the class's two slots, class id → [slot 0, slot 1] (Q key, «1» key).
var class_slots:Dictionary={}
var gadget=""
var class_first_slots:Array=[]
var purchased_gadgets:Array=[]
var purchased_hq:Array=[]
var superboss_defeated=false
var equipped_abilities:Array=["barrier"]
var rescue_level=0
var shield_capacity_level=0
## Class names and short stats; roles, start modifiers and unlock goals live in ClassCatalog. "driver" is the
## legacy Механик, merged into Инженер (profiles move over on load).
const CLASSES={"recruit":{"name":"Стрелок","price":0,"desc":"Крит +5% · граната"},"heavy":{"name":"Штурмовик","price":0,"desc":"HP +1 · защита от пуль +10% · дробовик +10% · скорость −5%"},"gunner":{"name":"Подрывник","price":0,"desc":"Жар +25% · защита от взрывов +15% · динамит"},"marksman":{"name":"Разведчик","price":0,"desc":"Маскировка +12% · крит-урон +25% · снайперка +15%"},"engineer":{"name":"Инженер","price":0,"desc":"Ремонт за побеждённого +0,3 · запасливость +10% · техника +15% · дрон"},"driver":{"name":"Механик","price":0,"desc":"Объединён с инженером"}}
var credits = 0
var health_level = 0
var damage_level = 0
var luck_level = 0
## Station levels of registry stats (StatRegistry); unknown ids are kept for newer content.
var stat_levels:Dictionary={}
## Cosmetics: owned uniform skins (besides the default) and the one worn (Skins).
var skins_owned:Array=[]
var skin="woodland"
## Player cat mesh from the wardrobe (PlayerModels); visual only.
var player_model=PlayerModels.DEFAULT
var turret_level = 0
var rarity_level = 0
var base_level = 0
var heal_level = 0
var mobility_level = 0
var recovery_level = 0
var ability_unlocks: Array=["barrier","shield"]
var selected_ability="barrier"
var branch_unlocks: Array=["health"]
var weapon_unlocks: Array=["pistol"]
## Weapons with the second ammo slot bought in the Arsenal (scripts/combat/ammo.gd).
var ammo_slot_weapons:Array=[]
var selected_weapon="pistol"
## World difficulty picked on the world select (T-266): "easy" / "normal" / "hard"; applies to the next run.
var world_difficulty="normal"
var backpack_slots=1
var reroll_level=0
var camp_level=0
var hq_unlocks:Array=HQCatalog.DEFAULT_UNLOCKS.duplicate()
var hq_modules:Array=[]
var hq_active=""
var hq_levels:Dictionary={}
var hq_slots=1
var pressure_level=0
var research_unlocks: Array=["character"]
var built_workshops: Array=[]
const RESEARCH={"headquarters":{"name":"Штаб","rarity":0},"rescue":{"name":"Страховка чертежей","rarity":1},"character":{"name":"Прокачка базы","rarity":0},"weapons":{"name":"Арсенал","rarity":0},"bonuses":{"name":"Верстак бонусов","rarity":1},"reroll":{"name":"Переброс карточек","rarity":1},"garage":{"name":"Стоянка","rarity":0},"range":{"name":"Полигон","rarity":0}}
## Former buildings folded into stations: Прокачка базы → Боец/Штаб, Верстак бонусов → Арсенал.
const RETIRED_BUILDINGS={"character":168,"bonuses":144}
## Which built station a permanent branch needs: supply branches live in «Казарма» (always there), defence in «Штаб».
const BRANCH_STATION={"base":"headquarters","turret":"headquarters"}
func station_ready(id:String)->bool:return id=="" or id in built_workshops
var BUILD_COST=Balance.CONFIG.economy.building_costs
## The yard outside the hangar is bought first (alloy, no blueprint); the parking and the range stand on it.
const YARD_COST=150
const BUILDING_REQUIRES={"garage":"yard","range":"yard"}
## Shop prices read as round numbers (author, 2026-10-03): to 5 under 100, to 10 under 1000, to 50 under 5000,
## to 100 above. Small token prices (under 20) stay exact. Every alloy price formula passes through here.
static func nice_price(value:int)->int:
	if value<20:return value
	var step=5 if value<100 else 10 if value<1000 else 50 if value<5000 else 100
	return maxi(step,roundi(float(value)/step)*step)
func building_cost(id:String)->int:return nice_price(YARD_COST if id=="yard" else int(BUILD_COST.get(id,0)))
func building_known(id:String)->bool:return id=="yard" or id in research_unlocks
## Missing prerequisite building ("" when none).
func building_blocker(id:String)->String:
	var need=str(BUILDING_REQUIRES.get(id,""))
	return need if need!="" and need not in built_workshops else ""
var bonus_unlocks: Array=["heart"]
var bonus_levels: Dictionary={}
var UNLOCK_COSTS=Balance.CONFIG.economy.branch_unlock_costs
const MAX_LEVEL=20
var save_enabled = true
## Input lives in InputRouter; these properties keep the Game.touch_* API used by controls and tests.
var input_router=preload("res://scripts/input_router.gd").new()
const MOVE_DIRECTIONS=preload("res://scripts/input_router.gd").MOVE_DIRECTIONS
var touch_direction:Vector2i:
	get:return input_router.touch_direction
	set(value):input_router.touch_direction=value
var touch_fire:bool:
	get:return input_router.touch_fire
	set(value):input_router.touch_fire=value
var keyboard_fire_held:bool:
	get:return input_router.keyboard_fire_held
	set(value):input_router.keyboard_fire_held=value
var movement_press_order:Array[String]:
	get:return input_router.movement_press_order
var visual_run_seed=0
var sound_enabled = true
var sound_times: Dictionary={}
var music_controller: Node
var effects_controller: Node

## Total time with a profile open (pause counts out: the tree is paused then). Stored in progression counters.
func _process(delta):
	if save_enabled and profiles.selected and progression!=null:
		progression.counters["play_seconds"]=float(progression.counters.get("play_seconds",0.0))+delta
func _ready():
	add_child(input_router);input_router.register_actions()
	BUILD_COST["headquarters"]=240
	fresh_profile=serialize_progress().duplicate(true)
	profiles.initialize()
	load_progress()
	notifications=load("res://scripts/notifications/channel.gd").new();add_child(notifications)
	if sound_enabled:audio().warm()
	add_child(load("res://scripts/progression/quest_notifications.gd").new())

func direction() -> Vector2i:return input_router.direction()
func reset_input():input_router.reset()
func wants_fire() -> bool:return input_router.wants_fire()

func level(branch: String) -> int:
	return {"health":health_level,"damage":damage_level,"luck":luck_level,"turret":turret_level,"rarity":rarity_level,"base":base_level,"heal":heal_level,"mobility":mobility_level,"recovery":recovery_level,"supplies":camp_level,"pressure":pressure_level}.get(branch,0)

func shell_raw_cost(branch:String, current_level:int)->int:
	return roundi((24 if branch=="health" else 16)*pow(1.0+current_level,1.8))

func character_level()->int:
	return health_level+damage_level+mobility_level+pressure_level

func shell_refund()->int:
	var refund=0
	for branch in ["health","damage","mobility","pressure"]:
		for n in range(level(branch)):refund+=nice_price(ceili(shell_raw_cost(branch,n)*1.2))
	return refund

func reset_shell()->int:
	var refund=shell_refund()
	health_level=0;damage_level=0;mobility_level=0;pressure_level=0
	credits+=refund
	save_progress()
	return refund

func raw_cost(branch: String) -> int:
	if branch in ["health","damage","mobility","pressure"]:return shell_raw_cost(branch,level(branch))
	if branch=="health":return 2*(Balance.CONFIG.economy.upgrade_base_cost+Balance.CONFIG.economy.upgrade_step_cost*health_level)
	return 60*int(pow(2,camp_level)) if branch=="supplies" else Balance.CONFIG.economy.upgrade_base_cost+Balance.CONFIG.economy.upgrade_step_cost*level(branch)

func meta_damage() -> float:return damage_level*.25
func heart_chance() -> float:return Balance.CONFIG.economy.heart_chance+luck_level*Balance.CONFIG.economy.luck_per_level+bonus_level("heart")*.002
func bonus_chance() -> float:
	var extra=0.0
	for id in bonus_levels:
		if id not in ["heart","star"]:extra+=bonus_levels[id]*.001
	return Balance.CONFIG.economy.bonus_chance+luck_level*Balance.CONFIG.economy.luck_per_level+extra
func turret_damage() -> float:return Balance.CONFIG.economy.turret_damage+turret_level*Balance.CONFIG.economy.turret_damage_per_level
func heal_amount() -> float:return Balance.CONFIG.economy.heal_amount+heal_level*Balance.CONFIG.economy.heal_per_level
func rarity_roll(value: float,stage:int=-1) -> int:
	if stage>=0:
		stage=Campaign.progress_index(stage)
		if stage<2:return 2 if value<.025 else 1 if value<.16 else 0
		var epic=.07 if stage<7 else minf(.85,(.35 if stage<12 else .65)+luck_level*.006)
		var uncommon=minf(.98,(.35 if stage<7 else .85 if stage<12 else .95)+luck_level*.006)
		return 2 if value<epic else 1 if value<uncommon else 0
	if value<.08+luck_level*.006:return 2
	if value<.35+luck_level*.012:return 1
	return 0

func purchase(branch: String) -> bool:
	if not station_ready(BRANCH_STATION.get(branch,"")):return false
	if branch not in ["health","damage","luck","turret","rarity","base","heal","mobility","supplies","pressure"] or (branch not in ["health","damage","mobility","pressure"] and not branch_unlocked(branch)) or level(branch)>=upgrade_cap(branch) or credits<cost(branch):return false
	credits-=cost(branch)
	match branch:
		"pressure":pressure_level+=1
		"health":health_level+=1
		"damage":damage_level+=1
		"luck":luck_level+=1
		"turret":turret_level+=1
		"rarity":rarity_level+=1
		"base":base_level+=1
		"heal":heal_level+=1
		"mobility":mobility_level+=1
		"recovery":recovery_level+=1
		"supplies":camp_level+=1
	save_progress();return true

func reset_upgrades() -> int:
	notification_history.clear()
	if is_instance_valid(notifications):notifications.pending.clear()
	garage=preload("res://scripts/garage/state.gd").new()
	new_recipes.clear();duplicate_recipes.clear()
	hq_unlocks=HQCatalog.DEFAULT_UNLOCKS.duplicate();hq_modules=[];hq_active="";hq_levels.clear();hq_slots=1;pressure_level=0
	progression=preload("res://scripts/progression/base_progression.gd").new()
	class_first_slots.clear();purchased_gadgets.clear();purchased_hq.clear();class_second_slots.clear();class_choices.clear();class_slots.clear();gadget="";superboss_defeated=false;cores=0;selected_class="recruit";class_unlocks=["recruit"];class_levels.clear();specializations.clear();ability_slots=1;equipped_abilities=["barrier"];rescue_level=0;shield_capacity_level=0
	selected_weapon="pistol";world_difficulty="normal";backpack_slots=1;reroll_level=0;camp_level=0;research_unlocks.clear();built_workshops.clear()
	ability_unlocks=["barrier","shield"];selected_ability="barrier";branch_unlocks=["health"];weapon_unlocks=["pistol"];ammo_slot_weapons=[];bonus_unlocks=["heart"];bonus_levels.clear()
	health_level=0;damage_level=0;luck_level=0;turret_level=0;rarity_level=0;base_level=0;heal_level=0;mobility_level=0;recovery_level=0;credits=0
	stat_levels.clear();skins_owned.clear();skin="woodland";player_model=PlayerModels.DEFAULT
	set_all_recipes(false)
	return 0

func earn(amount: int):
	credits += amount
	save_progress()

## A detached deep copy (T-276): callers may edit it freely — the live profile is never touched through it.
func serialize_progress()->Dictionary:
	return {"skins":skins_owned.duplicate(),"skin":skin,"player_model":player_model,"stat_levels":stat_levels.duplicate(),"run_checkpoint":run_checkpoint,"duplicate_recipes":duplicate_recipes,"garage":garage.serialize(),"notifications":notification_history,"class_first_slots":class_first_slots,"purchased_gadgets":purchased_gadgets,"purchased_hq":purchased_hq,"class_second_slots":class_second_slots,"class_choices":class_choices,"class_slots":class_slots,"gadget":gadget,"pressure_level":pressure_level,"headquarters":{"slots":hq_slots,"unlocks":hq_unlocks,"modules":hq_modules,"active":hq_active,"levels":hq_levels},"progression":progression.serialize(),"version":ProfileSchema.VERSION,"camp_level":camp_level,"selected_weapon":selected_weapon,"world_difficulty":world_difficulty,"backpack_slots":backpack_slots,"reroll_level":reroll_level,"research":research_unlocks,"built":built_workshops,"credits":credits,"health":health_level,"damage":damage_level,"luck":luck_level,"turret":turret_level,"rarity":rarity_level,"base":base_level,"heal":heal_level,"mobility":mobility_level,"recovery":recovery_level,"v09":{"class_levels":class_levels,"specializations":specializations,"cores":cores,"class":selected_class,"classes":class_unlocks,"superboss_defeated":superboss_defeated,"slots":ability_slots,"equipped":equipped_abilities,"rescue":rescue_level,"shield_capacity":shield_capacity_level},"abilities":ability_unlocks,"selected_ability":selected_ability,"branch_unlocks":branch_unlocks,"weapon_unlocks":weapon_unlocks,"ammo_slot_weapons":ammo_slot_weapons,"bonus_unlocks":bonus_unlocks,"bonus_levels":bonus_levels}.duplicate(true)

## Small UI state (seen badges, read messages, collapsed panels) does not need a disk write and a blinking
## save icon on every click (author, 4 Oct 2026): save_soon() marks the profile dirty and writes it quietly
## after SOFT_SAVE_DELAY, or together with the next real save, or on quit / focus loss.
const SOFT_SAVE_DELAY=10.0
var soft_save_pending=false
func save_soon():
	if not save_enabled or soft_save_pending:return
	soft_save_pending=true
	get_tree().create_timer(SOFT_SAVE_DELAY,true,false,true).timeout.connect(func():if soft_save_pending:save_progress(true))
func save_progress(quiet:=false)->bool:
	soft_save_pending=false
	if not save_enabled or not profiles.selected:return true
	if save_blocked:return false
	var data=serialize_progress() if run_save_baseline.is_empty() else run_save_baseline.duplicate(true)
	data.run_checkpoint=run_checkpoint
	var result=ProfileStore.write_file(save_path,data,ProfileSchema.validate)
	save_error="" if result.ok else result.error
	# Our own snapshot failing validation is a code bug: make it loud instead of silently keeping an old file.
	if not result.ok:push_error("Profile save failed: "+str(result.error))
	elif not quiet:save_indicator().pulse()
	return result.ok
var save_icon:CanvasLayer
func save_indicator()->CanvasLayer:
	# Saves often happen while a scene is still building its children: attach on the next idle frame.
	if not is_instance_valid(save_icon):save_icon=preload("res://scripts/ui/save_indicator.gd").new();save_icon.name="SaveIndicator";add_child.call_deferred(save_icon)
	return save_icon

func load_progress()->bool:
	var result=ProfileStore.load_file(save_path,ProfileSchema.validate)
	if not result.ok:
		save_blocked=result.error!="missing" or FileAccess.file_exists(save_path+".bak")
		save_error=result.error if save_blocked else ""
		return not save_blocked
	save_blocked=false
	save_error="Восстановлена резервная копия" if result.get("recovered",false) else ""
	apply_profile(result.data)
	return true

func apply_profile(data:Dictionary):
	run_checkpoint=data.get("run_checkpoint",{}).duplicate(true);run_save_baseline.clear()
	garage=preload("res://scripts/garage/state.gd").new()
	progression=preload("res://scripts/progression/base_progression.gd").new()
	if data is Dictionary:

		duplicate_recipes=data.get("duplicate_recipes",[]).filter(func(r):return r.get("category","") in ["weapon","bonus","research","ability","hq","garage"] and r.get("id","") in recipe_catalog(r.category))
		notification_history=data.get("notifications",[]).slice(-150)
		garage.restore(data.get("garage",{}))
		progression.restore(data.get("progression",{}))
		var hq=data.get("headquarters",{})
		hq_slots=1;pressure_level=maxi(0,int(data.get("pressure_level",0)))
		hq_unlocks=HQCatalog.DEFAULT_UNLOCKS.duplicate()
		for id in hq.get("unlocks",[]):
			if id in HQCatalog.DATA and id not in hq_unlocks:hq_unlocks.append(id)
		hq_modules=[]
		for id in hq.get("modules",["hq_medbay"]):
			if id in hq_unlocks and HQCatalog.DATA[id].mode!="active" and id not in hq_modules and hq_modules.size()<2:hq_modules.append(id)
		hq_active=str(hq.get("active",""))
		if hq_active not in hq_unlocks or HQCatalog.DATA[hq_active].mode!="active":hq_active=""
		normalize_hq()
		hq_levels={}
		for id in HQCatalog.DATA:hq_levels[id]=clampi(int(hq.get("levels",{}).get(id,0)),0,5)
		ability_unlocks=["barrier","shield"]
		var saved=data.get("abilities",[])
		if saved is Array:
			for id in saved:
				if id in AbilityCatalog.DATA and id not in ability_unlocks:ability_unlocks.append(id)
		selected_ability=str(data.get("selected_ability",""))
		if selected_ability not in ability_unlocks:selected_ability="barrier"
		var extra=data.get("v09",{})
		class_levels=extra.get("class_levels",{});specializations=extra.get("specializations",{})
		class_second_slots=data.get("class_second_slots",[]);gadget=str(data.get("gadget","barrier"))
		class_choices={}
		var choices=data.get("class_choices",{})
		if choices is Dictionary:
			for id in choices:
				if str(choices[id]) in CLASS_CHOICES.get(str(id),[]):class_choices[str(id)]=str(choices[id])
		class_slots={}
		var saved_slots=data.get("class_slots",{})
		if saved_slots is Dictionary:
			for id in saved_slots:
				if saved_slots[id] is Array:class_slots[str(id)]=saved_slots[id].map(func(a):return str(a)).slice(0,2)
		if gadget not in ["barrier","mine","laser","airstrike"]:gadget=""
		cores=maxi(0,int(extra.get("cores",0)))
		selected_class=extra.get("class","recruit");class_unlocks=extra.get("classes",["recruit"])
		if "driver" in class_unlocks and "engineer" not in class_unlocks:class_unlocks.append("engineer")
		if selected_class=="driver":selected_class="engineer"
		if selected_class not in CLASSES:selected_class="recruit"
		class_first_slots=data.get("class_first_slots",class_unlocks.duplicate())
		purchased_gadgets=data.get("purchased_gadgets",ability_unlocks.filter(func(id):return id in ["barrier","mine","laser","airstrike"]))
		purchased_hq=data.get("purchased_hq",hq_unlocks.duplicate())
		superboss_defeated=bool(extra.get("superboss_defeated",false))
		ability_slots=clampi(int(extra.get("slots",1)),1,2);rescue_level=clampi(int(extra.get("rescue",0)),0,10);shield_capacity_level=clampi(int(extra.get("shield_capacity",0)),0,2)
		equipped_abilities=extra.get("equipped",[selected_ability]).filter(func(id):return id in ability_unlocks)
		if equipped_abilities.is_empty():equipped_abilities=["barrier"]
		equipped_abilities.resize(mini(ability_slots,equipped_abilities.size()))
		credits = maxi(0, int(data.get("credits",0)))
		if cores>0:
			credits+=cores*DOC_ALLOY;notification_history.append({"text":"Документы больше не нужны: накопленные переплавлены в %d ◈." % (cores*DOC_ALLOY),"sender":"Оперштаб","time":Time.get_unix_time_from_system(),"read":false,"category":"important"});cores=0
		health_level = maxi(0,int(data.get("health",0)))
		damage_level = maxi(0,int(data.get("damage",0)))
		luck_level=clampi(int(data.get("luck",0)),0,MAX_LEVEL)
		turret_level=clampi(int(data.get("turret",0)),0,MAX_LEVEL)
		rarity_level=clampi(int(data.get("rarity",0)),0,MAX_LEVEL)
		# One «Удача» since 0.2.1: the former rarity branch folds into luck, no levels are lost.
		if rarity_level>0:luck_level=mini(MAX_LEVEL,luck_level+rarity_level);rarity_level=0
		skins_owned=Array(data.get("skins",[])).filter(func(id):return id is String)
		skin=str(data.get("skin","woodland"))
		if not Skins.owned(skin):skin="woodland"
		player_model=str(data.get("player_model",PlayerModels.DEFAULT))
		if not PlayerModels.valid(player_model):player_model=PlayerModels.DEFAULT
		stat_levels={}
		var saved_stats=data.get("stat_levels",{})
		# Meta stage 4: «Выучка» is gone. Alloy spent on it and on the old 2500 second-ability slot comes back once.
		var refund=0
		if saved_stats is Dictionary:
			for key in saved_stats:
				var def=StatRegistry.get_def(str(key))
				if def==null or not typeof(saved_stats[key]) in [TYPE_INT,TYPE_FLOAT]:continue
				for step in range(clampi(int(saved_stats[key]),0,def.max_level)):refund+=def.cost_base+def.cost_step*step
		refund+=2500*data.get("class_second_slots",[]).size() if data.get("class_second_slots",[]) is Array else 0
		class_second_slots=[]
		if refund>0:
			credits+=refund
			notification_history.append({"text":"Выучка убрана, вторая способность теперь открывается на 3 уровне класса: возвращено %d ◈." % refund,"sender":"Оперштаб","time":Time.get_unix_time_from_system(),"read":false,"category":"important"})
		base_level=clampi(int(data.get("base",0)),0,MAX_LEVEL)
		heal_level=clampi(int(data.get("heal",0)),0,MAX_LEVEL)
		mobility_level=maxi(0,int(data.get("mobility",0)))
		recovery_level=clampi(int(data.get("recovery",0)),0,MAX_LEVEL)
		camp_level=clampi(int(data.get("camp_level",0)),0,3)
		branch_unlocks=["health"];weapon_unlocks=["pistol"];bonus_unlocks=["heart"];bonus_levels={}
		for branch in UNLOCK_COSTS:
			if level(branch)>0 or branch in data.get("branch_unlocks",[]):
				if branch not in branch_unlocks:branch_unlocks.append(branch)
		if "rarity" in branch_unlocks:
			branch_unlocks.erase("rarity")
			if "luck" not in branch_unlocks:branch_unlocks.append("luck")
		shield_capacity_level=0;recovery_level=0
		for id in LOOT.gun_ids():
			if id!="pistol" and (id in data.get("weapon_unlocks",[]) or (id=="sniper" and "heavy" in data.get("weapon_unlocks",[]))):weapon_unlocks.append(id)
		for id in LOOT.BONUSES:
			if id!="heart" and id in data.get("bonus_unlocks",[]):bonus_unlocks.append(id)
			bonus_levels[id]=clampi(int(data.get("bonus_levels",{}).get(id,0)),0,3)

		ammo_slot_weapons=data.get("ammo_slot_weapons",[]).filter(func(id):return str(id) in weapon_unlocks).map(func(id):return str(id))
		selected_weapon=str(data.get("selected_weapon","pistol"));selected_weapon="sniper" if selected_weapon=="heavy" else selected_weapon
		if selected_weapon not in weapon_unlocks:selected_weapon="pistol"
		world_difficulty=Campaign.difficulty_id(data.get("world_difficulty","normal"))
		backpack_slots=clampi(int(data.get("backpack_slots",1)),1,6);reroll_level=clampi(int(data.get("reroll_level",0)),0,5)
		research_unlocks=[];built_workshops=[]
		for id in RESEARCH:
			if id in data.get("research",[]):research_unlocks.append(id)
		if "character" not in research_unlocks:research_unlocks.append("character")
		for id in BUILD_COST:
			if id in data.get("built",[]):built_workshops.append(id)
		# The yard came after the parking and the range: profiles that built either keep it open.
		if "yard" in data.get("built",[]) or "garage" in built_workshops or "range" in built_workshops:built_workshops.append("yard")
		# Retired buildings: bonuses turn into the Arsenal when it is missing, the rest is refunded once.
		for id in RETIRED_BUILDINGS:
			if id not in data.get("built",[]):continue
			if id=="bonuses" and "weapons" not in built_workshops:built_workshops.append("weapons");research_unlocks.append("weapons")
			else:credits+=RETIRED_BUILDINGS[id]
		if not data.has("progression"):
			progression.level=maxi(1,ceili(maxi(health_level,maxi(damage_level,maxi(base_level,mobility_level)))/3.0))
		if int(data.get("version",0))<8:
			# Existing players keep their previously available workshops.
			research_unlocks=["character","weapons","bonuses","garage","range"];built_workshops=["character","weapons","bonuses","garage","range"]

func audio():
	if not is_instance_valid(effects_controller):
		effects_controller=load("res://scripts/audio_controller.gd").new();add_child(effects_controller)
	return effects_controller
func sound(kind: String, parent: Node):
	if sound_enabled:audio().play(kind,parent)
func sound_loop(kind:String,parent:Node,enabled:bool=true,pitch:float=1.0):
	if sound_enabled or is_instance_valid(effects_controller):audio().loop_event(kind,parent,enabled,pitch)
func weapon_sound(actor):
	var weapon=""
	if actor.kind=="soldier" and actor.player_owned:weapon=actor.arena.weapon
	elif actor.companion and actor.kind=="soldier":weapon=actor.companion_weapon
	elif actor.enemy_weapon!="":weapon=actor.enemy_weapon
	else:weapon={"buggy":"vehicle_mg","apc":"vehicle_mg","tank":"tank","boss":"boss","flyer":"vehicle_mg","mortar":"mortar","sniper":"sniper"}.get(actor.kind,"rifle")
	fire_sound(weapon,actor,actor.player_owned or actor.companion)
## One gunshot for a weapon id in every mode — battle, hub range, upgrade rooms, sandbox (T-269: the hub and rooms
## always played the pistol). Own shots are marked so the mixer never drops them for background noise.
func fire_sound(weapon:String,source:Node,own:=true):
	if weapon=="" or weapon==LootCatalog.PAWS:return
	var id="fire_"+weapon
	if sound_enabled and audio().banks.has(id):audio().play(id,source,own)
	else:sound("shot",source)
	if weapon in ["shotgun","sniper","tank"]:sound("weapon_mechanism",source)

func unlock_or_equip_ability(id: String) -> bool:
	if "weapons" not in built_workshops:return false
	if id not in AbilityCatalog.DATA:return false
	if not ability_available(id):return false
	if id not in ["barrier","mine","laser","airstrike"]:return false
	if id not in purchased_gadgets:
		if credits<gadget_cost(id):return false
		credits-=gadget_cost(id);purchased_gadgets.append(id)
	gadget=id;selected_ability=id;save_progress();return true

func branch_unlocked(id: String) -> bool:return id in branch_unlocks or level(id)>0
func unlock_branch(id: String) -> bool:
	if not station_ready(BRANCH_STATION.get(id,"")):return false
	if id=="recovery" or id not in UNLOCK_COSTS or branch_unlocked(id) or credits<UNLOCK_COSTS[id]:return false
	credits-=UNLOCK_COSTS[id];branch_unlocks.append(id);save_progress();return true
func bonus_level(id: String) -> int:return int(bonus_levels.get(id,0))
func bonus_power(id: String) -> float:return 1.0+bonus_level(id)*.1
func upgrade_bonus(id: String) -> bool:
	if "weapons" not in built_workshops:return false
	var price=bonus_cost(id)
	if id not in bonus_unlocks or bonus_level(id)>=Balance.CONFIG.economy.bonus_level_cap or credits<price:return false
	credits-=price;bonus_levels[id]=bonus_level(id)+1;save_progress();return true
func recipe_catalog(category: String) -> Dictionary:
	return GarageCatalog.recipes() if category=="garage" else HQCatalog.DATA if category=="hq" else AbilityCatalog.DATA if category=="ability" else LOOT.guns() if category=="weapon" else LOOT.BONUSES if category=="bonus" else RESEARCH
func recipe_owned(category: String) -> Array:
	return garage.unlocks if category=="garage" else hq_unlocks if category=="hq" else ability_unlocks if category=="ability" else weapon_unlocks if category=="weapon" else bonus_unlocks if category=="bonus" else research_unlocks
func roll_recipe(rng: RandomNumberGenerator,pending: Array,ground: Array=[],stage:int=0) -> Dictionary:
	var held=pending+ground
	for early in ["weapons","headquarters","garage"]:
		if early not in research_unlocks and not held.any(func(item):return item.id==early and item.category=="research"):
			return {"id":early,"category":"research"}
	if rng.randf()>.80:return {}
	var options=[]
	for category in ["weapon","bonus","research","ability","hq","garage"]:
		var catalog=recipe_catalog(category)
		for id in catalog:
			if id in recipe_owned(category) or held.any(func(item):return item.id==id and item.category==category):continue
			for i in range(GarageCatalog.weight(id,stage) if category=="garage" else TIERS.weight(id,stage)):options.append({"id":id,"category":category})
	return {} if options.is_empty() else options[rng.randi_range(0,options.size()-1)]
func discover_recipe(rng: RandomNumberGenerator,pending: Array) -> String:
	if pending.size()>=Backpack.capacity():return "Рюкзак полон"
	var recipe=roll_recipe(rng,pending)
	if recipe.is_empty():return ""
	pending.append(recipe);return "Чертёж · "+recipe_name(recipe)
func recipe_name(recipe: Dictionary) -> String:return recipe_catalog(recipe.category)[recipe.id].name
func bank_recipes(pending: Array):
	for recipe in pending:
		if recipe is Dictionary:recipe.erase("cell")  # a backpack position, not part of the blueprint
		var owned=recipe_owned(recipe.category)
		if recipe.id not in owned:owned.append(recipe.id);new_recipes.append(recipe.duplicate(true))
		else:duplicate_recipes.append({"category":recipe.category,"id":recipe.id})
	pending.clear();save_progress()
func bag_cost() -> int:return nice_price(ceili(72*pow(2,backpack_slots-1)))
func upgrade_backpack() -> bool:
	if backpack_slots>=Backpack.MAX_BOUGHT or credits<bag_cost():return false
	credits-=bag_cost();backpack_slots+=1;save_progress();return true
func reroll_cost() -> int:return nice_price(roundi(96*pow(1.7,reroll_level)))
func upgrade_rerolls() -> bool:
	if "reroll" not in research_unlocks or reroll_level>=5 or credits<reroll_cost():return false
	credits-=reroll_cost();reroll_level+=1;save_progress();return true
func build_workshop(id: String) -> bool:
	if (id not in BUILD_COST and id!="yard") or not building_known(id) or id in built_workshops or building_blocker(id)!="" or credits<building_cost(id):return false
	credits-=building_cost(id);built_workshops.append(id);save_progress();return true
func equip_weapon(id: String) -> bool:
	if "weapons" not in built_workshops or id not in weapon_unlocks:return false
	selected_weapon=id;sound("weapon_equip",self);save_progress();return true

func star_duration() -> float:return 6.0+bonus_level("star")*1.5
func star_chance(wave_index: int) -> float:
	if "star" not in bonus_unlocks or wave_index==0:return 0.0
	return (.006+bonus_level("star")*.0015) if wave_index==1 else (.015+bonus_level("star")*.003)

func recipe_offers(rng: RandomNumberGenerator,pending: Array,stage:int=0) -> Array:
	var result=[];var held=pending.duplicate(true)
	for i in range(3):
		var options=[]
		for category in ["research","weapon","bonus","ability","hq","garage"]:
			for id in recipe_catalog(category):
				if id in recipe_owned(category) or held.any(func(r):return r.id==id and r.category==category):continue
				for weight in range(GarageCatalog.weight(id,stage) if category=="garage" else TIERS.weight(id,stage)):options.append({"category":category,"id":id})
		var pick: Dictionary={}
		if i==0:
			for early in ["weapons","headquarters","garage"]:
				if early not in research_unlocks and not held.any(func(r):return r.category=="research" and r.id==early):pick={"category":"research","id":early};break
		if pick.is_empty() and not options.is_empty():pick=options[rng.randi_range(0,options.size()-1)]
		if pick.is_empty():pick={"category":"upgrade","id":["health","damage","speed","fire","intercept"][rng.randi_range(0,4)],"tier":rarity_roll(rng.randf())}
		else:held.append(pick)
		result.append(pick)
	return result

func music_context(context: String,refresh:bool=false):
	if not sound_enabled:return
	if not is_instance_valid(music_controller):music_controller=load("res://scripts/music_controller.gd").new();add_child(music_controller)
	music_controller.change(context,refresh)
func music_stinger(id: String):
	if not sound_enabled:return
	if is_instance_valid(music_controller):music_controller.celebrate(id,3 if id in ["boss_victory","defeat"] else 2)

func buy_special(id:String)->bool:
	if "headquarters" not in built_workshops:return false
	var price=special_cost(id)
	if price<0 or (cores if id=="slots" else credits)<price:return false
	if id=="slots":cores-=price
	else:credits-=price
	match id:
		"slots":ability_slots+=1
		"rescue":rescue_level+=1
		"shield":shield_capacity_level+=1
	save_progress();return true
func special_cost(id:String)->int:
	match id:
		"slots":return -1
		"rescue":return nice_price(144+rescue_level*120) if rescue_level<10 and "rescue" in research_unlocks else -1
		"shield":return -1
	return -1
const CLASS_SKILLS={"recruit":"grenade","gunner":"dynamite","driver":"field_repair","marksman":"cloak","engineer":"ally_drone","heavy":"shield"}
func class_skill()->String:return CLASS_SKILLS.get(selected_class,"")
## Every shell is available from world 1; the price (alloy or documents) is the only gate.
func class_world(_id:String)->int:return 1
func class_price(_id:String)->int:return 0
## A class opens by its goal (ClassCatalog); taking it is free.
func can_select_class(id:String)->bool:
	return id in class_unlocks or (id in ClassCatalog.ROSTER and ClassCatalog.goal_met(id))
func select_class(id:String)->bool:
	if id not in CLASSES or not can_select_class(id):return false
	if id not in class_unlocks:class_unlocks.append(id)
	selected_class=id
	var skill=class_skill()
	if skill not in ability_unlocks:ability_unlocks.append(skill)
	equipped_abilities=[skill]+equipped_abilities.filter(func(v):return v not in CLASS_SKILLS.values()).slice(0,maxi(0,ability_slots-1))
	selected_ability=skill;save_progress();return true

## Class upgrades bought for the selected class (0–19); the displayed level is ClassCatalog.level (1–20).
func class_level()->int:return ClassCatalog.level(selected_class)-1
func class_specialization()->int:return clampi(int(specializations.get(selected_class,0)),0,3)
func class_upgrade_cost(id:String,special:bool)->int:
	var upgrade_level=int((specializations if special else class_levels).get(id,0))
	if special:return -1 if upgrade_level>=3 else ceili((2+upgrade_level)*1.2)*DOC_ALLOY
	return class_step_cost(upgrade_level)
## 0.8.0: geometric ladder, 100 ◈ ×1.32 per level, round prices (nice_price). `stored` counts upgrades bought
## (level − 1); -1 past the top. The Barracks sums it for «Всего до N ур.».
static func class_step_cost(stored:int)->int:
	return -1 if stored>=ClassCatalog.MAX_LEVEL-1 else nice_price(roundi(100.0*pow(1.32,stored)))
func upgrade_class(id:String,special:bool)->bool:
	if id not in class_unlocks:return false
	var price=class_upgrade_cost(id,special)
	if price<0 or credits<price:return false
	credits-=price
	var levels=specializations if special else class_levels;levels[id]=int(levels.get(id,0))+1
	save_progress();return true

func wants_interact()->bool:
	return Input.is_action_just_pressed("interact") and not CardNavigation.release_required

func total_upgrade_level()->int:
	var total=pressure_level+maxi(0,hq_slots-1)+health_level+damage_level+luck_level+turret_level+rarity_level+base_level+heal_level+mobility_level+recovery_level+camp_level+rescue_level+shield_capacity_level+reroll_level+maxi(0,backpack_slots-1)+class_second_slots.size()
	for levels in [bonus_levels,class_levels,specializations,hq_levels,garage.levels]:
		for value in levels.values():total+=int(value)
	for value in progression.weapon_levels.values():total+=int(value)
	return total+progression.insurance

# Recipe discovery has a single mutation path, shared by test shop and full reset.
func set_recipe_unlocked(category:String,id:String,unlocked:bool):
	if category not in ["weapon","bonus","research","ability","hq","garage"] or id not in recipe_catalog(category):return
	if (category=="weapon" and id=="pistol") or (category=="bonus" and id=="heart") or (category=="research" and id=="character") or (category=="ability" and id in ["barrier","shield"]):return
	if category=="hq" and id in HQCatalog.DEFAULT_UNLOCKS:return
	var owned=recipe_owned(category)
	if unlocked:
		if id not in owned:owned.append(id)
	else:
		owned.erase(id)
		if category=="hq":
			hq_modules.erase(id)
			if hq_active==id:hq_active=""
		if category=="weapon" and selected_weapon==id:selected_weapon="pistol"
		if category=="ability":
			equipped_abilities.erase(id)
			if equipped_abilities.is_empty():equipped_abilities=["barrier"]
			selected_ability=equipped_abilities[0]
	save_progress()

func set_all_recipes(unlocked:bool):
	garage.unlocks=GarageCatalog.recipes().keys() if unlocked else []
	hq_unlocks=HQCatalog.DATA.keys() if unlocked else HQCatalog.DEFAULT_UNLOCKS.duplicate()
	hq_modules=hq_modules.filter(func(id):return id in hq_unlocks)
	if hq_active not in hq_unlocks:hq_active=""
	ability_unlocks=AbilityCatalog.DATA.keys() if unlocked else ["barrier","shield"]
	equipped_abilities=equipped_abilities.filter(func(id):return id in ability_unlocks)
	if equipped_abilities.is_empty():equipped_abilities=["barrier"]
	selected_ability=equipped_abilities[0]
	weapon_unlocks=LOOT.gun_ids() if unlocked else ["pistol"]
	bonus_unlocks=LOOT.BONUSES.keys() if unlocked else ["heart"]
	research_unlocks=RESEARCH.keys() if unlocked else ["character"]
	if selected_weapon not in weapon_unlocks:selected_weapon="pistol"
	save_progress()

func health_upgrade_bonus()->int:return health_level*HEALTH_PER_LEVEL
## Hub upgrades felt too small (author, 4 Oct 2026): «Сила» +10% weapon damage per level (was 5%), health +3
## (was 2), and every 5 levels of a general branch is a milestone: +1 card reroll per sortie.
const DAMAGE_PER_LEVEL=.10
const HEALTH_PER_LEVEL=3
const MILESTONE_EVERY=5
func branch_milestones()->int:
	var total=0
	for branch in ["health","damage","mobility","pressure"]:total+=level(branch)/MILESTONE_EVERY
	return total

func cost(branch:String)->int:return nice_price(ceili(raw_cost(branch)*1.2))
## Permanent upgrades are limited by price and fixed caps from economy.tres; there is no base level gate.
func upgrade_cap(branch:String)->int:return 2147483647 if branch in ["health","damage","mobility","pressure"] else Balance.CONFIG.economy.supplies_cap if branch=="supplies" else Balance.CONFIG.economy.branch_cap
func bonus_cost(id:String)->int:return nice_price(ceili((80+60*bonus_level(id))*1.2))
func death_loss_fraction(insurance:int=-1)->float:
	var e=Balance.CONFIG.economy;return maxf(e.death_loss_floor,e.death_loss-(progression.insurance if insurance<0 else insurance)*.05)
func insurance_cost()->int:return nice_price(roundi(180*pow(1.5,progression.insurance)))
func buy_insurance()->bool:
	if progression.insurance>=Balance.CONFIG.economy.insurance_cap or credits<insurance_cost():return false
	credits-=insurance_cost();progression.insurance+=1;save_progress();return true
func weapon_level(id:String)->int:return int(progression.weapon_levels.get(id,0))
func weapon_factor(id:String)->float:return 1.0+weapon_level(id)*.04  # 0.8: +4% per level (was 1.5%, a weak mid-game buy)
func weapon_upgrade_cost(id:String)->int:return nice_price(roundi(350*pow(1.65,weapon_level(id))))
func upgrade_weapon(id:String)->bool:
	if "weapons" not in built_workshops or id not in weapon_unlocks or weapon_level(id)>=Balance.CONFIG.economy.weapon_level_cap or credits<weapon_upgrade_cost(id):return false
	credits-=weapon_upgrade_cost(id);progression.weapon_levels[id]=weapon_level(id)+1;save_progress();return true

## Meta stage 3 (guides/01_design/08_meta_proposal.md): every class has its own Q (CLASS_SKILLS) and picks
## one of two abilities for slot «1». No Q repeats between classes; the gadget (F) and HQ support stay shared.
const CLASS_CHOICES={"recruit":["comrade","mine"],"heavy":["barrier","gas"],"gunner":["gas","mine"],"marksman":["airstrike","laser"],"engineer":["field_repair","barrier"],"driver":["field_repair","barrier"]}
## The open slots of a class, "" for an empty one (the player may clear a slot). Without a saved layout the
## unlocked abilities fill the slots in order.
func class_slot_layout(id:String=selected_class)->Array:
	var open:Array=ClassCatalog.unlocked_abilities(id);var count=ClassCatalog.slot_count(id)
	var result:Array=[]
	if class_slots.has(id):
		for a in class_slots[id]:result.append(str(a) if str(a) in open and str(a) not in result else "")
	else:
		result=open.slice(0,count)
	while result.size()<count:
		# A slot that opened after the layout was saved gets the next free ability.
		var spare=open.filter(func(a):return a not in result)
		result.append(spare[0] if not spare.is_empty() and class_slots.has(id) and result.size()>=class_slots[id].size() else "")
	return result.slice(0,count)
## Abilities actually in the slots (empty slots skipped) — what the soldier takes into a run.
func class_slot_items(id:String=selected_class)->Array:
	return class_slot_layout(id).filter(func(a):return a!="")
## Puts an unlocked ability into a slot (free, in the hub), "" clears it; an ability already in the other
## slot swaps places.
func set_class_slot(id:String,slot:int,ability:String)->bool:
	if slot<0 or slot>=ClassCatalog.slot_count(id):return false
	if ability!="" and ability not in ClassCatalog.unlocked_abilities(id):return false
	var items=class_slot_layout(id)
	if items[slot]==ability:return false
	var other=items.find(ability) if ability!="" else -1
	if other>=0:items[other]=items[slot]
	items[slot]=ability
	class_slots[id]=items;save_progress();return true
## Second slot's ability (old API for tests and tooltips).
func class_second(id:String=selected_class)->String:
	var items=class_slot_items(id);return str(items[1]) if items.size()>1 else ""
func choose_class_second(id:String,ability:String)->bool:return set_class_slot(id,1,ability)
func class_loadout()->Array:
	if selected_class not in class_unlocks:return []
	return class_slot_items(selected_class)
## The gadget (F) is left out when the class already carries the same ability in slot «1».
func hero_loadout()->Array:
	var result=class_loadout()
	if gadget!="" and gadget in purchased_gadgets and ability_available(gadget) and gadget not in result:result.append(gadget)
	return result
func ability_action(index:int)->String:return "ability" if index>=class_loadout().size() else "class_ability" if index==0 else "skill_1"

func ability_available(id:String)->bool:
	if id in class_loadout():return selected_class in class_unlocks
	if id in CLASS_SKILLS.values() or id in ["comrade","gas","field_repair"]:return false  # class-only abilities
	return id in ability_unlocks

func hq_loadout()->Array:return ([hq_active] if hq_active!="" else [])+hq_modules
func normalize_hq():
	hq_slots=1
	hq_modules=hq_modules.slice(0,maxi(0,hq_slots-int(hq_active!="")))
func buy_hq_slot()->bool:return false
func equip_hq(id:String,slot:int=0)->bool:
	if "headquarters" not in built_workshops or not HQCatalog.available(id):return false
	var loadout=hq_loadout()
	if id not in purchased_hq:
		if credits<hq_purchase_cost(id):return false
		credits-=hq_purchase_cost(id);purchased_hq.append(id)
	if id in loadout:return true
	if HQCatalog.DATA[id].mode=="active" and hq_active!="":loadout.erase(hq_active)
	slot=clampi(slot,0,hq_slots-1)
	if slot<loadout.size():loadout[slot]=id
	else:loadout.append(id)
	hq_active="";hq_modules=[]
	for tech in loadout.slice(0,hq_slots):
		if HQCatalog.DATA[tech].mode=="active":hq_active=tech
		else:hq_modules.append(tech)
	progression.event("equip_hq");save_progress();return true
func upgrade_hq(id:String)->bool:
	if "headquarters" not in built_workshops or not HQCatalog.available(id) or int(hq_levels.get(id,0))>=HQCatalog.cap() or credits<HQCatalog.permanent_cost(id):return false
	credits-=HQCatalog.permanent_cost(id);hq_levels[id]=int(hq_levels.get(id,0))+1;progression.event("upgrade_hq");save_progress();return true

# Keep the old gunner profile key so existing unlocks and levels are preserved.
## Class health now comes from ClassCatalog start modifiers.
func class_health_bonus()->float:return 0.0
func class_pressure_bonus()->float:return 0.0

func gadget_cost(id:String)->int:return 35 if id=="barrier" else 100 if id=="mine" else 240
func hq_purchase_cost(id:String)->int:return nice_price(60 if id=="hq_medbay" else 90+HQCatalog.DATA[id].rarity*120)

func mobility_multiplier()->float:return 1.0+.35*mobility_level/(70.0+mobility_level)
func shell_pressure_bonus()->float:return .2*pressure_level/(20.0+pressure_level)

func duplicate_price(recipe:Dictionary)->int:return [8,12,20,30][TIERS.tier(recipe.id)]
func sell_duplicate(index:int)->bool:
	if index<0 or index>=duplicate_recipes.size():return false
	var recipe=duplicate_recipes[index]
	if recipe.id not in recipe_owned(recipe.category):return false
	var before=credits;credits+=duplicate_price(recipe);duplicate_recipes.remove_at(index)
	if not save_progress():credits=before;duplicate_recipes.insert(index,recipe);return false
	return true
func sell_all_duplicates()->int:
	var before=duplicate_recipes.duplicate(true);var total=0
	for recipe in before:
		if recipe.id in recipe_owned(recipe.category):total+=duplicate_price(recipe)
	if total==0:return 0
	duplicate_recipes=before.filter(func(r):return r.id not in recipe_owned(r.category));credits+=total
	if not save_progress():credits-=total;duplicate_recipes=before;return 0
	return total

func checkpoint_run(arena,index:int,mode:String,choices:Dictionary)->bool:
	run_checkpoint=preload("res://scripts/profile/run_checkpoint.gd").capture(arena,index,mode,choices)
	run_save_baseline=serialize_progress().duplicate(true);run_save_baseline.erase("run_checkpoint")
	var ok=save_progress()
	if not ok and is_instance_valid(arena):arena.toast("Не удалось сохранить забег: "+save_error)
	return ok
func clear_run_checkpoint():
	run_checkpoint={};run_save_baseline={}
	save_progress()
# Explicit exit and window close both flush the profile. During a run this writes the
# checkpoint snapshot, so the unfinished battle is replaced by the route map on return.
func quit_game():
	save_progress();Settings.save()
	get_tree().quit()
func _notification(what):
	# Cmd+Q, closing the window, hiding the app or a phone call: flush before the OS may kill the process.
	if what in [NOTIFICATION_WM_CLOSE_REQUEST,NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_WM_GO_BACK_REQUEST]:save_progress(true);Settings.save()
