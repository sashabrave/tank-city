class_name LocationStyle
extends RefCounted
const TYPES=["forest","city","mountains","desert","marsh","inferno"]
const NAMES={"forest":"Лес","city":"Город","mountains":"Горы","desert":"Пустыня","marsh":"Болота","inferno":"Пепельные земли"}
const COLORS={"forest":Color("929f8d"),"city":Color("939da0"),"mountains":Color("979ba7"),"desert":Color("b4a68b"),"marsh":Color("8eaaa4"),"inferno":Color("ac9691")}
static func biome(seed_value:int,index:int)->String:
	var rng=RandomNumberGenerator.new();rng.seed=seed_value+91873+int(index/6.0)*6301
	var order=TYPES.duplicate()
	for i in range(order.size()-1,0,-1):
		var j=rng.randi_range(0,i);var swap=order[i];order[i]=order[j];order[j]=swap
	return order[index%order.size()]
static func cloud_cover(index:int)->float:return [.08,.12,.17,.23,.29,.35,.40][clampi(index,0,6)]
