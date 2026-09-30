class_name RecipeExtraction
extends RefCounted
# One policy for both emergency exits; completed rooms guarantee extraction.
## safe_slots: the first N carried blueprints always survive (card «Сейф»); the rest roll the HQ insurance.
static func survivors(recipes:Array, safe:bool, rescue_level:int, rng:RandomNumberGenerator, safe_slots:int=0)->Array:
	if safe:return recipes.duplicate(true)
	var chance=clampf(rescue_level*.06,0,.6)
	var kept=recipes.slice(0,mini(safe_slots,recipes.size())).duplicate(true)
	for recipe in recipes.slice(mini(safe_slots,recipes.size())):
		if rng.randf()<chance:kept.append(recipe)
	return kept
