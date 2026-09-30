extends RefCounted
## Independent seeded choices: appearance never consumes combat RNG.
static func pick(seed_value:int,cell:Vector2i)->Dictionary:
	var rng=RandomNumberGenerator.new();rng.seed=seed_value+cell.x*73856093+cell.y*19349663+7349
	var kind="concrete_smooth" if rng.randf()<.5 else "concrete_%d" % rng.randi_range(0,1)
	var shape=-1 if rng.randf()<.5 else rng.randi_range(0,7)
	return {"kind":kind,"shape":shape}
static func asset(style:Dictionary)->String:
	return style.kind+("" if style.shape<0 else "_half_%d" % style.shape)
