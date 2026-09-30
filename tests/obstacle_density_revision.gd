extends Node
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	var rows=[]
	for y in range(31):rows.append(".".repeat(31))
	var kinds=["B","C","A","X","R","T","N"]
	for i in range(kinds.size()):
		for x in range(1,21):BattleMapGenerator.put(rows,Vector2i(x,2+i*3),kinds[i])
	var copy=rows.duplicate();BattleMapGenerator.thin_obstacles(rows,917,false);BattleMapGenerator.thin_obstacles(copy,917,false)
	assert(rows==copy)
	for kind in kinds:
		var count=0
		for row in rows:count+=row.count(kind)
		assert(count==17,"Every generated obstacle family is reduced by 15 percent")
	for world in range(1,4):
		Campaign.configure(world)
		for room in [0,3,5]:
			for seed_value in range(20):
				var map=BattleMapGenerator.generate(seed_value*1117,room)
				assert(BattleMapGenerator.validate(map.rows),"Thinning preserves connected paths and base cover")
	print("OBSTACLE DENSITY PASS: all seven layout types -15%, deterministic, 180 connected layouts")
	get_tree().quit()
