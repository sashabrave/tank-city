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
const WORLDS={1:{"name":"Тихий двор","offset":0,"sizes":[11,13,15,15,17,17,19],"boss_hp":700.0,"hp":1.0,"damage":1.0},2:{"name":"Мисочная гряда","offset":7,"sizes":[22,23,24,25,26,27,30],"boss_hp":1100.0,"hp":1.75,"damage":1.35},3:{"name":"Цитадель","offset":16,"sizes":[25,26,27,28,29,30,35],"boss_hp":1600.0,"hp":2.7,"damage":1.7}}
static func configure(id:int,infinite:bool=false,is_daily:bool=false):
	world=clampi(id,1,3);endless=infinite or is_daily;cycle=0;daily=is_daily;daily_key=DailyRun.today_key() if is_daily else ""
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
static func hp_scale(index:int)->float:return endless_strength*(1+cycle*.30+cycle*cycle*.025+index*.065) if endless else WORLDS[world].hp*(1+index*(.13 if world==1 else .08))
static func damage_scale(index:int)->float:return sqrt(endless_strength)*(1+cycle*.12+cycle*cycle*.006+index*.035) if endless else WORLDS[world].damage*(1+index*.055)
static func boss_health()->float:return 650*endless_strength*(1+cycle*.40+cycle*cycle*.04) if endless else WORLDS[world].boss_hp
static func active_cap(index:int)->int:return mini(8,4+cycle/2) if endless else mini(6,2+world+index/3)
static func title(index:int)->String:
	if daily:return "Забег дня · сектор %d · поле %d" % [cycle+1,index+1]
	if endless:return "Бесконечный · сектор %d · поле %d" % [cycle+1,index+1]
	return "%s · %s" % [WORLDS[world].name,"Гигабосс" if is_final(index) else "Генерал" if index in BOSSES else "поле %d / %d" % [index+1,6]]
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
static func weapon_world(id:String)->int:return 3 if id=="rpg" else 2 if id=="sniper" else 1
