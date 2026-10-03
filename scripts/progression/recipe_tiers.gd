extends RefCounted
# Availability score: 100..75 common, 74..50 uncommon, 49..25 rare, 24..0 exceptional.
const SCORES={"character":100,"weapons":95,"heart":100,"pistol":100,"repair":90,"wall":82,"garage":78,"range":85,"smg":76,"shotgun":72,"bonuses":70,"rifle":64,"reroll":60,"vehicle_repair":58,"rescue":55,"pressure":52,"grenade":70,"barrier":95,"shield":80,"mine":58,"freeze":46,"turret":42,"sniper":40,"cloak":38,"gas":34,"ally_drone":30,"rpg":22,"grenade_launcher":32,"vehicle":20,"star":10,"laser":24,"comrade":18,"airstrike":8}
static func tier(id:String)->int:
	if id in GarageCatalog.recipes():return 0 if id=="vehicle_buggy" else 1 if id.begins_with("buggy_") else 2 if id=="vehicle_apc" or id.begins_with("apc_") else 3
	var score=int(HQCatalog.DATA[id].score if id in HQCatalog.DATA else 90 if id=="headquarters" else SCORES.get(id,60));return 0 if score>=75 else 1 if score>=50 else 2 if score>=25 else 3
## World 1 route stage (0–6) → highest blueprint tier that can appear: rare items only in the second half and from the boss.
const WORLD1_TIER_CAP=[1,1,2,2,3,3,3]
static func unlocked(stage:int)->int:
	if Campaign.unified_content():return WORLD1_TIER_CAP[clampi(stage,0,WORLD1_TIER_CAP.size()-1)]
	return 0 if stage<2 else 1 if stage<7 else 2 if stage<12 else 3
static func weight(id:String,stage:int)->int:
	if id in ["sniper","rpg","grenade_launcher"] and Campaign.recipe_world()<Campaign.weapon_world(id):return 0
	var t=tier(id);var cap=unlocked(stage)
	if t>cap:return 0
	return [[100,0,0,0],[35,100,0,0],[6,30,100,0],[1,8,45,100]][cap][t]
