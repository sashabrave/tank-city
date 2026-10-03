extends Node
## Biomes per route node and room names (author, 2 Oct): nodes of one stage get different biome families, world 1
## carries all eight, every room has a generated name «<battle> <preposition> <adjective> <place>».
## Prints sample names. No profile or settings writes.
const B=preload("res://scripts/biome_catalog.gd")
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():
	Game.save_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	var seen={};var stage_ok=true;var samples=[]
	for seed in range(60):
		for room in range(Campaign.SIZES.size()):
			var lanes=[]
			for lane in range(3):
				var e=B.entry(seed,room,lane);lanes.append(e.family);seen[e.family]=true
				var name=BattleNames.room(seed,room,lane,e.family)
				if seed<3 and lane==0:samples.append(name)
				if name.split(" ").size()<4 or "ы" in name.right(3) and "кочкы" in name:stage_ok=false
			if lanes[0]==lanes[1] or lanes[1]==lanes[2] or lanes[0]==lanes[2]:stage_ok=false
	check(stage_ok,"three nodes of a stage always have three different biome families")
	check(seen.size()==8,"world 1 shows all eight families (%d)" % seen.size())
	var early={};for seed in range(60):early[B.entry(seed,0,0).family]=true
	check(not early.has("frost") and not early.has("ash"),"first fields stay calm (no frost or ash)")
	check(B.entry(5,2,1).name==B.entry(5,2,1).name and B.index(5,2,1)==B.index(5,2,1),"deterministic per node")
	check(BattleNames.noun_case("поле","n","gen")=="поля" and BattleNames.noun_case("кочка","f","gen")=="кочки" and BattleNames.noun_case("топь","f","ins")=="топью","declensions: поля, кочки, топью")
	check(BattleNames.adjective("Тих","m","ins")=="Тихим" and BattleNames.adjective("Красн","n","gen")=="Красного","adjectives: Тихим, Красного")
	var caption=B.caption(7,3,2)
	check(caption.split("\n").size()==2 and caption.split("\n")[0]==BattleNames.room(7,3,2,B.entry(7,3,2).family),"plate shows the room name, then the biome")
	for s in samples:print("NAME ",s)
	print("BIOME ROOMS: %d failures" % failures);get_tree().quit(1 if failures else 0)
