@tool
class_name GameBalance
extends Resource
@export_group("Оружие — раскрой нужный ресурс")
@export var weapons:Array[WeaponBalance]=[]
@export_group("Способности")
@export var abilities:Array[AbilityBalance]=[]
@export_group("Враги и транспорт")
@export var enemies:Array[EnemyBalance]=[]
@export_group("Общие настройки")
@export var combat:CombatTuning
@export var economy:EconomyTuning
@export var campaign:CampaignTuning
func weapon_data()->Dictionary:
	var result={}
	for entry in weapons:result[entry.id]=entry.as_dict()
	return result
func ability_data()->Dictionary:
	var result={}
	for entry in abilities:result[entry.id]=entry.as_dict()
	return result
func enemy(id:String)->EnemyBalance:
	for entry in enemies:
		if entry.id==id:return entry
	push_error("Unknown enemy balance: "+id);return enemies[0]
func wave_costs()->Dictionary:
	var result={}
	# Preserve the original order, which participates in seeded wave generation.
	const ORDER=["drone","flyer","soldier","grenadier","shield","sniper","buggy","apc","mortar","tank","boss"]
	for id in ORDER:result[id]=enemy(id).wave_cost
	# Enemies added later as resources join after the original order (it feeds seeded generation).
	for entry in enemies:
		if entry.id not in result:result[entry.id]=entry.wave_cost
	return result
