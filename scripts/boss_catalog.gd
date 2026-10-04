class_name BossCatalog
extends RefCounted
# World generals (T-260, 4 Oct): quicker, a ram among the attacks, ~15% less HP — reinforcement shields replace generators.
# Change these lists to choose which encounters can appear in each world.
const WORLD_VARIANTS={1:["heavy","twins","medium"],2:["heavy","twins","medium"],3:["heavy","twins","medium"]}
const DATA={
	"heavy":{"name":"Бастион","model":"boss","count":1,"footprint":4,"scale":1.0,"hp":.85,"speed":1.6,"patterns":["salvo","ram","fan"]},
	"twins":{"name":"Клещи","model":"buggy","count":2,"footprint":2,"scale":1.8,"hp":.45,"speed":2.1,"patterns":["salvo","ram"]},
	"medium":{"name":"Батарея","model":"apc","count":1,"footprint":3,"scale":2.5,"hp":.75,"speed":2.0,"patterns":["mortar","ram","salvo"]},
	"giga":{"name":"Цитадель","model":"boss","count":1,"footprint":4,"scale":1.0,"hp":1.25,"speed":.9,"patterns":["salvo","mortar","fan"]}
}
static func encounter(seed_value:int,index:int)->Dictionary:
	var id="giga" if Campaign.is_final(index) else WORLD_VARIANTS[Campaign.world][posmod(seed_value+Campaign.world+Campaign.cycle,WORLD_VARIANTS[Campaign.world].size())]
	var result=DATA[id].duplicate(true);result.id=id
	if Campaign.world>=2 and id=="heavy":result.patterns=["salvo","ram","mortar","fan"]
	return result
