class_name RecipeExtraction
extends RefCounted
# One policy for both emergency exits; completed rooms guarantee extraction.
static func survivors(recipes:Array, safe:bool, rescue_level:int, rng:RandomNumberGenerator)->Array:
	if safe:return recipes.duplicate(true)
	var chance=clampf(rescue_level*.06,0,.6)
	return recipes.filter(func(_recipe):return rng.randf()<chance)
