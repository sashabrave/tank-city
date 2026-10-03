class_name RecipeExtraction
extends RefCounted
# One policy for both emergency exits; completed rooms guarantee extraction.
## safe_slots: the first N carried blueprints always survive (card «Сейф»); the rest roll the HQ insurance.
static func survivors(recipes:Array, safe:bool, rescue_level:int, rng:RandomNumberGenerator, safe_slots:int=0)->Array:
	if safe:return recipes.duplicate(true)
	# 0.8 balance (guides/03_release/07_balance_pacing.md): building blueprints (research) always survive,
	# so the base opens in the first hour instead of after the general. Weapons and the rest roll as before.
	var buildings=recipes.filter(func(r):return str(r.get("category",""))=="research")
	var rest=recipes.filter(func(r):return str(r.get("category",""))!="research")
	var chance=clampf(rescue_level*.06,0,.6)
	var kept=buildings.duplicate(true)+rest.slice(0,mini(safe_slots,rest.size())).duplicate(true)
	for recipe in rest.slice(mini(safe_slots,rest.size())):
		if rng.randf()<chance:kept.append(recipe)
	return kept
