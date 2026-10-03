extends Node
## 0.8 pacing: world 1 hands the HQ blueprint at the end of the first segment and the Garage in the middle
## segment, until owned; never twice, never in endless. Profile writes stay disabled.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades();Campaign.configure(1)
	Game.research_unlocks.erase("headquarters");Game.research_unlocks.erase("garage")
	check(EncounterRules.guaranteed(1,[])=={"category":"research","id":"headquarters"},"HQ at the end of the first segment")
	check(EncounterRules.guaranteed(3,[])=={"category":"research","id":"garage"},"Garage in the middle segment")
	check(EncounterRules.guaranteed(0,[]).is_empty() and EncounterRules.guaranteed(2,[]).is_empty(),"other fields stay random")
	check(EncounterRules.guaranteed(1,[{"category":"research","id":"headquarters"}]).is_empty(),"not twice in one run")
	Game.research_unlocks.append("headquarters")
	check(EncounterRules.guaranteed(1,[]).is_empty(),"not once built")
	check(RecipeExtraction.survivors([{"category":"research","id":"garage"},{"category":"weapon","id":"smg"}],false,0,RandomNumberGenerator.new()).size()==1,"building blueprints survive a death, weapons roll")
	print("GUARANTEED BLUEPRINTS: %d failures" % failures);get_tree().quit(1 if failures else 0)
