extends Node
## Battle names: short, grammatical, per seed and biome. Prints a sample.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false
	var names=[]
	for family in BattleNames.PLACES:
		for s in range(3):names.append(BattleNames.generate(s*17+family.length(),family))
	for n in names:print("NAME ",n)
	check(names.all(func(n):return n.length()<=34),"names stay short")
	check(BattleNames.generate(5,"forest")==BattleNames.generate(5,"forest"),"same seed, same name")
	check(BattleNames.noun_case("поляна","f","prep")=="поляне" and BattleNames.adjective("Красн","f","prep")=="Красной","«при Красной поляне»")
	check(BattleNames.noun_case("брод","m","gen")=="брода" and BattleNames.adjective("Мятн","m","gen")=="Мятного","«Мятного брода»")
	print("BATTLE NAMES: %d failures" % failures);get_tree().quit(1 if failures else 0)
