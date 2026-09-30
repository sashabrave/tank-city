extends Node
var failures=0
func check(ok:bool,label:String):
	if not ok:failures+=1;push_error(label)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	check(Campaign.reinforced_share(0)==0 and Campaign.reinforced_share(2)==0,"No reinforced brick before mid-route")
	check(is_equal_approx(Campaign.reinforced_share(3),.15) and is_equal_approx(Campaign.reinforced_share(6),.35),"Share grows 15% to 35% toward the boss")
	var arena=load("res://scenes/arena.tscn").instantiate();arena.auto_pause_enabled=false;arena.run_seed=21;add_child(arena);arena.set_physics_process(false)
	for a in arena.actors:a.set_physics_process(false)
	var cell=Vector2i(4,4)
	if arena.walls.has(cell):arena.walls[cell].node.queue_free();arena.walls.erase(cell)
	arena.board.add_reinforced_wall(cell,12)
	var wall=arena.walls[cell];var origin=arena.world_pos(cell)
	check(wall.sections.all(func(v):return v>0),"Reinforced brick starts as a full collision mask")
	var combat_state=arena.run.combat_rng.state
	for i in range(7):arena.board.damage_wall(cell,1.5,origin+Vector3(0,.4,.5),Vector3.FORWARD,.5)
	check(arena.walls.has(cell) and not arena.can_stand(origin,arena.player),"Still a full block after 10.5 of 12 damage")
	check(wall.sections.all(func(v):return v>0),"Damage never removes reinforced sections")
	arena.board.damage_wall(cell,1.5,origin+Vector3(0,.4,.5),Vector3.FORWARD,.5)
	check(not arena.walls.has(cell),"Breaks as a whole at the full brick-block damage")
	check(arena.run.combat_rng.state==combat_state,"Debris does not touch combat randomness")
	# Mid-route rooms actually place reinforced brick; early ones never do.
	var early=0;var late=0
	for room in [1,5]:
		for seed_value in [3,4,5]:
			arena.run_seed=seed_value;arena.begin_room(room)
			var count=arena.walls.values().filter(func(w):return w.get("reinforced",false)).size()
			if room==1:early+=count
			else:late+=count
	check(early==0 and late>0,"Placement follows the route: early=%d late=%d" % [early,late])
	# Base fortification bonus: 0-1 brick, 2 reinforced brick, 3+ indestructible PO-2 fence halves.
	Game.bonus_levels["wall"]=0
	var expected={1:"brick",2:"reinforced",3:"fence"}
	for level in [1,2,3]:
		arena.run_seed=8;arena.begin_room(1);arena.run.run_bonus_levels["wall"]=level
		var base_cells=[Vector2i(arena.base_cell.x-1,arena.grid_size-2),Vector2i(arena.base_cell.x,arena.grid_size-2),Vector2i(arena.base_cell.x+1,arena.grid_size-2),Vector2i(arena.base_cell.x-1,arena.grid_size-1),Vector2i(arena.base_cell.x+1,arena.grid_size-1)]
		var holder=Node3D.new();arena.add_child(holder)
		arena.reward.collect_pickup({"node":holder,"kind":"wall"})
		for c in base_cells:
			var w=arena.walls.get(c)
			check(w!=null,"Base wall present at level %d" % level)
			if w==null:continue
			var kind="fence" if w.hp<0 and w.get("style_kind","")=="concrete_0" else "reinforced" if w.get("reinforced",false) else "brick" if w.hp>0 else "other"
			check(kind==expected[level],"Level %d gives %s, got %s" % [level,expected[level],kind])
			check(w.has("half_side"),"Base wall keeps its prescribed half shape")
	check(BattleMapGenerator.generate(5,4,false).rows.all(func(r):return "A" not in r),"No legacy armored blocks")
	arena.queue_free();await get_tree().process_frame
	print("REINFORCED BRICK: failures=",failures)
	get_tree().quit()
