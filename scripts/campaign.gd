class_name Campaign
extends RefCounted
# A run uses local stage indices. Legacy content indices are resolved only here.
static var world=1
static var endless=false
static var cycle=0
static var endless_strength=1.0
static var daily=false  # endless on the shared seed of the day (DailyRun)
static var daily_key=""
static var SIZES:Array=[11,13,15,15,17,17,19]
static var BOSSES:Array=[6]
static var SERVICES:Array=[2,4,6]
const WORLDS={1:{"name":"Тихий двор","offset":0,"sizes":[11,13,15,15,17,17,19],},2:{"name":"Мисочная гряда","offset":7,"sizes":[22,23,24,25,26,27,30],},3:{"name":"Цитадель","offset":16,"sizes":[25,26,27,28,29,30,35],}}
## Challenge ladder of the current run: 0 normal, 1–3 = I–III (campaign only). Set after configure().
static var challenge=0
const CHALLENGE_REWARD=[1.0,1.25,1.5,2.0]
## Professionalism added per ladder step (see Professionalism.skill); no upper bound, so later steps or
## a late-game ladder can keep raising it (the derived behaviours are clamped by Professionalism.LIMITS).
const CHALLENGE_SKILL=.2
static func challenge_level()->int:return 0 if endless else challenge
## Highest ladder step a world offers: none until the world is cleared, then one past the best cleared step.
static func challenge_open(id:int)->int:
	if id not in Game.progression.cleared_worlds:return 0
	return mini(3,int(Game.progression.counters.get("challenge_w%d" % id,0))+1)
static func reward_multiplier()->float:return CHALLENGE_REWARD[clampi(challenge_level(),0,3)]
static func configure(id:int,infinite:bool=false,is_daily:bool=false):
	world=clampi(id,1,3);endless=infinite or is_daily;cycle=0;daily=is_daily;daily_key=DailyRun.today_key() if is_daily else "";challenge=0
	var hp=CombatStats.initial_health()
	var weapon=Game.LOOT.WEAPONS[Game.selected_weapon]
	var stats=CombatStats.weapon()
	var dps=stats.damage*weapon.pellets*weapon.get("burst",1)/stats.interval
	endless_strength=clampf(.8+.12*sqrt(maxf(0,hp-3))+.10*sqrt(maxf(0,dps-2.5))+.12*Game.garage.owned.size(),1,2.5)
	if daily:endless_strength=DailyRun.STRENGTH  # same enemies for everyone that day
	# Odd sizes only (the HQ needs a centre column); growth slows toward the boss.
	SIZES=WORLDS[world].sizes.duplicate() if not endless else [15,17,17,19,19,21,21]
	if world==3 and not endless:SIZES=[25,26,27,28,29,30,32,35]
	BOSSES=[6,7] if world==3 and not endless else [SIZES.size()-1]
	SERVICES=[2,4,6,7] if world==3 and not endless else [2,4,6]
static func progress_index(index:int)->int:return mini(22,int(WORLDS[world].offset)+index) if not endless else mini(22,7+cycle*2+index)
## Share of brick blocks that become reinforced: none before mid-route, 15% there, 35% at the boss.
static func reinforced_share(index:int)->float:
	if endless:return minf(.35,.15+cycle*.05+index*.01)
	var start=ceili(BOSSES[0]*.5)
	if index<start:return 0.0
	return lerpf(.15,.35,clampf(float(index-start)/maxf(1,BOSSES[0]-start),0,1))
static func zone(_index:int)->int:return world if not endless else mini(3,1+cycle/2)
static func is_final(index:int)->bool:return not endless and world==3 and index==7
## World multipliers, per-field growth, boss health and the active cap come from Balance.CONFIG.campaign.
static func tuning()->CampaignTuning:return Balance.CONFIG.campaign
static func hp_scale(index:int)->float:
	if endless:return endless_strength*(1+cycle*.30+cycle*cycle*.025+index*.065)
	var t=tuning();return t.world_value(t.world_health,world)*(1+index*t.world_value(t.health_step_per_field,world))
static func damage_scale(index:int)->float:
	if endless:return sqrt(endless_strength)*(1+cycle*.12+cycle*cycle*.006+index*.035)
	var t=tuning();return t.world_value(t.world_damage,world)*(1+index*t.damage_step_per_field)
static func boss_health()->float:
	if endless:return 650*endless_strength*(1+cycle*.40+cycle*cycle*.04)
	return tuning().world_value(tuning().world_boss_health,world)
static func active_cap(index:int)->int:
	if endless:return mini(8,4+cycle/2)
	var t=tuning();return mini(t.active_cap,t.active_base+world+index/t.active_fields_per_step)
static func title(index:int)->String:
	if daily:return "Забег дня · сектор %d · поле %d" % [cycle+1,index+1]
	if endless:return "Бесконечный · сектор %d · поле %d" % [cycle+1,index+1]
	return "%s · %s" % [BattleNames.current(),"Гигабосс" if is_final(index) else "Генерал" if index in BOSSES else "поле %d / %d" % [index+1,6]]
static func unlocked(id:int)->bool:return id==1 or id-1 in Game.progression.cleared_worlds
static func infinite_unlocked()->bool:return 1 in Game.progression.cleared_worlds
static func service_options(seed_value:int,index:int)->Array:
	# World 1 rows hold the two key stops — instructor and merchant; mechanic and workshop are route nodes.
	if world==1 and not endless:return ["ability","merchant"]
	var options=["vehicle","ability","headquarters"];var rng=RandomNumberGenerator.new();rng.seed=seed_value+index*977+world*181+cycle*371
	if not endless:
		var removed=rng.randi_range(0,2);options.remove_at(removed)
	return options
## World 1 and endless hold all content of the three worlds; locked worlds 2–3 keep their original gating.
static func recipe_world()->int:return 3 if world==1 else world
static func unified_content()->bool:return world==1 and not endless
static func weapon_world(id:String)->int:return 3 if id=="rpg" else 2 if id in ["sniper","grenade_launcher"] else 1
