extends Node3D
## CORE: trenches, wall sections and half-blocks, reinforced brick, trench damage multipliers and the
## room flow around them. Profile and settings writes stay disabled.
var failures=0
func check(ok:bool,message:String)->bool:
	if not ok:failures+=1;printerr("FAIL ",message);push_error(message)
	return ok
func _ready():call_deferred("run")
func settle():
	for i in range(3):await get_tree().process_frame
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.new_recipes.clear();Campaign.configure(1)
	await trenches()
	await sections()
	await half_block_obstacle()
	await room_rules()
	await reinforced_brick()
	Campaign.configure(1)
	print("TRENCH REGRESSION: failures=",failures)
	get_tree().quit(1 if failures else 0)

func trenches():
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.set_physics_process(false);arena.phase="upgrade"
	for actor in arena.actors:actor.set_physics_process(false)
	var enemy=arena.spawn_actor("soldier",Vector2i(1,1),false);enemy.set_physics_process(false)
	enemy.route_points=[Vector2i(-10,-10)]
	var start=Time.get_ticks_usec()
	for i in range(5):arena.path_direction(enemy)
	print("PATH benchmark five unreachable searches ms: ",(Time.get_ticks_usec()-start)/1000.0)
	check((Time.get_ticks_usec()-start)<20000,"five unreachable searches stay under 20 ms")
	arena.process_mode=Node.PROCESS_MODE_DISABLED
	for a in arena.actors:a.queue_free()
	# Isolated fixture: the run seed is random, so its water and vegetation could block the test column.
	arena.actors.clear();arena.walls.clear();arena.trenches.clear();arena.wrecks.clear();arena.generators.clear();arena.terrain.patches.clear()
	var cell=Vector2i(5,5);var center=arena.world_pos(cell)
	var pit=Node3D.new();arena.add_child(pit);arena.trenches[cell]=pit
	var first=arena.spawn_actor("soldier",cell+Vector2i.LEFT,false)
	var second=arena.spawn_actor("soldier",cell+Vector2i.RIGHT,false)
	first.position=center+Vector3(-.5,0,0);first.cell=arena.grid_pos(first.position);first.moving=true;first.destination=cell
	check(not arena.board.trench_available(cell,second),"a trench being entered is reserved")
	check(arena.board.occupy_trench(first,cell),"the first soldier takes the trench")
	check(first.position.is_equal_approx(center) and not first.moving and first.occupying_trench,"the occupant is centred and stops")
	check(not arena.board.occupy_trench(second,cell),"a taken trench rejects a second soldier")
	check(not arena.can_stand(center+Vector3(.5,0,0),second,true),"an occupied trench excludes the full cell")
	first.dead=true
	check(arena.board.occupy_trench(second,cell),"death releases the trench")
	second.player_owned=true;arena.player=second
	check(arena.board.interact_trench() and not second.occupying_trench and not second.moving,"the player leaves the trench with E")
	check(arena.board.trench_available(cell,first),"exit releases the trench")
	second.dead=true;first.dead=false;first.occupying_trench=false;first.moving=false
	arena.trenches.clear();arena.boss_room=false
	# This scenario tests an explicit waypoint, with no open base firing lane.
	for side in [Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT]:arena.add_wall(arena.base_cell+side,8)
	# Two central columns removed: a straight .5-wide corridor through the block.
	var sections=[]
	for i in range(16):sections.append(0.0 if i%4 in [1,2] else 1.0)
	arena.walls[cell]={"hp":8.0,"sections":sections}
	arena.navigation.reset()
	check(is_equal_approx(arena.body_size(first),.49),"infantry body is .49 wide")
	for direction in [-1,1]:
		first.position=center+Vector3(0,0,-direction*1.5);first.cell=arena.grid_pos(first.position)
		first.route_points=[cell+Vector2i(0,direction*2)];first.assault_time=0
		if first.has_meta("quarter_search"):first.remove_meta("quarter_search")
		var reached=false;var straight=true
		for step in range(300):
			await get_tree().physics_frame
			var dir=arena.path_direction(first)
			if dir==Vector2i.ZERO:continue
			var next=first.position+Vector3(dir.x,0,dir.y)*.25
			if not arena.can_stand(next,first) or not is_equal_approx(next.x,center.x):straight=false;break
			first.position=next;first.cell=arena.grid_pos(next)
			if direction*(next.z-center.z)>=1.5:reached=true;break
		check(straight and reached,".49 infantry walks straight through the .5 corridor (direction %d)" % direction)
	# A remaining central section must immediately invalidate a cached move.
	arena.walls[cell].sections[5]=1.0;arena.navigation.invalidate(cell)
	check(not arena.can_stand(center,first),"a closed gap blocks at once")
	var crowd=[]
	for i in range(10):
		var a=arena.spawn_actor("soldier",Vector2i(1+i%5,1+i/5),false)
		a.route_points=[Vector2i(-10,-10)];crowd.append(a)
	var worst=0
	for frame in range(90):
		await get_tree().physics_frame
		var began=Time.get_ticks_usec()
		for a in crowd:arena.path_direction(a)
		worst=maxi(worst,Time.get_ticks_usec()-began)
	print("PATH ten infantry / 90 frames worst search batch ms: ",worst/1000.0)
	check(worst<20000,"ten infantry searches stay under 20 ms per frame")
	# T-108: two trenches next to the soldier — E takes the one closer to his centre, and only that one shows a hint.
	for t in arena.trenches.keys():arena.trenches[t].queue_free()
	arena.trenches.clear()
	var me=arena.player;me.occupying_trench=false;me.hidden_in_trench=false
	var spot=Vector2i(4,4);me.cell=spot;me.position=arena.world_pos(spot)+Vector3(.25,0,0);me.facing=Vector2i.UP
	for t in [spot+Vector2i.RIGHT,spot+Vector2i.LEFT]:
		if arena.walls.has(t):
			if arena.walls[t].has("node"):arena.walls[t].node.queue_free()
			arena.walls.erase(t)
		arena.trenches[t]=Node3D.new();arena.add_child(arena.trenches[t])
	check(arena.board.trench_target()==spot+Vector2i.RIGHT,"the trench closer to the soldier's centre wins")
	me.position=arena.world_pos(spot)+Vector3(-.25,0,0)
	check(arena.board.trench_target()==spot+Vector2i.LEFT,"step to the other side — the other trench")
	arena.free();await settle()

## from sections_v21: directional 4×4 wall damage, half-width slit, quarter movement, enemy fire through the hole.
func sections():
	Game.apply_profile(Game.fresh_profile.duplicate(true));Game.save_enabled=false
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.set_physics_process(false);arena.auto_pause_enabled=false;arena.phase="combat"
	for wall in arena.walls.values():wall.node.queue_free()
	arena.walls.clear()
	arena.terrain.patches.clear();arena.trenches.clear();arena.generators.clear();arena.navigation.reset()
	for actor in arena.actors:actor.set_physics_process(false)
	var cell=Vector2i(6,6);var origin=arena.world_pos(cell);arena.add_wall(cell,4)
	var wall=arena.walls[cell];check(wall.sections.size()==16,"a brick block has 16 sections")
	arena.board.damage_wall(cell,1,origin+Vector3(0,0,1),Vector3.FORWARD,.5)
	check(wall.sections.filter(func(hp):return hp<=0).size()==2 and wall.sections[13]==0 and wall.sections[14]==0,"a half-width shot removes the two facing central sections")
	for i in range(3):arena.board.damage_wall(cell,1,origin+Vector3(0,0,1),Vector3.FORWARD,.5)
	check(wall.sections.filter(func(hp):return hp<=0).size()==8,"four hits open a half-width slit")
	check(arena.clear_shot(origin+Vector3(0,0,2),origin+Vector3(0,0,-2),.5),"a half-width shot passes the slit")
	check(not arena.clear_shot(origin+Vector3(0,0,2),origin+Vector3(0,0,-2),1.0),"a full-width shot does not")
	var player=arena.player;player.position=origin+Vector3(0,0,1);player.cell=arena.grid_pos(player.position);player.facing=Vector2i.UP
	check(arena.can_stand(origin,player),"infantry stands in the slit")
	var walked=true
	for i in range(4):
		player.try_move(Vector2i.UP);walked=walked and player.moving
		player.position=player.quarter_destination;player.cell=player.destination;player.moving=false
	check(walked and player.position.is_equal_approx(origin),"quarter steps lead into the slit")
	player.kind="tank";check(not arena.can_stand(origin,player),"a tank does not fit the slit");player.kind="soldier"
	# Enemy can aim and shoot through the half-cell slit, without touching its edges.
	player.position=origin+Vector3(0,0,2)
	var enemy=arena.spawn_actor("soldier",Vector2i(6,4),false);enemy.set_physics_process(false)
	check(arena.enemy_aim(enemy)==Vector2i.DOWN,"enemy aims through the slit")
	var shot=arena.spawn_bullet(enemy,enemy.position,Vector2i.DOWN,1,false);shot.position=origin
	check(not arena.bullet_hit(shot),"a bullet in the slit touches no section");shot.consume()
	# Infantry navigation and locomotion use the same open half-cell passage (base lanes sealed).
	for blocker in [arena.base_cell+Vector2i.UP,arena.base_cell+Vector2i.LEFT,arena.base_cell+Vector2i.RIGHT]:arena.add_wall(blocker,4)
	check(arena.enemy.base_firing_cells(enemy).is_empty(),"sealed base has no firing cells")
	player.position=arena.world_pos(Vector2i(1,1))
	enemy.position=origin+Vector3(0,0,-1);enemy.cell=arena.grid_pos(enemy.position)
	enemy.route_points=[cell+Vector2i.DOWN*2];enemy.movement_pause=0
	var routed=true
	for step in range(8):
		var direction=Vector2i.ZERO
		for attempt in range(120):
			direction=arena.path_direction(enemy)
			if direction!=Vector2i.ZERO:break
			await get_tree().physics_frame
		if direction!=Vector2i.DOWN:routed=false;break
		enemy.try_move(direction)
		if not enemy.moving:routed=false;break
		enemy.position=enemy.quarter_destination;enemy.cell=enemy.destination;enemy.moving=false
	check(routed and enemy.position.is_equal_approx(origin+Vector3(0,0,1)),"infantry routes through the slit")
	# A single quarter-wide opening cannot fit the half-cell infantry body.
	var narrow=wall.sections.duplicate()
	for row in range(4):wall.sections[row*4+1]=1.0
	check(not arena.can_stand(origin+Vector3(.125,0,0),enemy),"a quarter-wide gap is too narrow")
	wall.sections=narrow
	# From the left, vehicle fire removes exactly one four-section column.
	var other=Vector2i(9,6);arena.add_wall(other,4);var center=arena.world_pos(other)
	arena.board.damage_wall(other,1,center-Vector3.RIGHT,Vector3.RIGHT,1)
	var column=arena.walls[other].sections.filter(func(hp):return hp<=0).size()==4
	for row in range(4):column=column and arena.walls[other].sections[row*4]==0
	check(column,"side vehicle fire removes one four-section column")
	# A wide shot straddling cells contacts both blocks.
	arena.add_wall(other+Vector2i.RIGHT,4)
	check(arena.wall_contacts(center+Vector3(.5,0,.5),Vector3.FORWARD,1).size()==2,"a straddling wide shot contacts both blocks")
	# Firing left from inside a slit must never damage the right-hand sections.
	var before=wall.sections.duplicate()
	arena.board.damage_wall(cell,10,origin+Vector3(-.3,0,0),Vector3.LEFT,.5)
	var right_kept=true
	for row in range(4):right_kept=right_kept and wall.sections[row*4+3]==before[row*4+3]
	check(right_kept and wall.sections[4]==0 and wall.sections[8]==0,"firing left from a slit spares the right-hand sections")
	var halves=true
	for side in range(4):
		var halfcell=Vector2i(2+side,9);arena.add_wall(halfcell,-1 if side%2 else 4);arena.board.shape_wall(halfcell,side)
		halves=halves and arena.walls[halfcell].sections.filter(func(hp):return hp>0).size()==8
	check(halves,"half-blocks keep 8 of 16 sections on every side")
	arena.free();await settle()

## from half_block_obstacle_revision: the brick half blocks bodies, pathing and shots; vehicles never pass.
func half_block_obstacle():
	var clear=func(arena,c):
		if arena.walls.has(c):arena.walls[c].node.queue_free();arena.walls.erase(c);arena.navigation.invalidate(c)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=5;add_child(arena);arena.auto_pause_enabled=false
	await get_tree().create_timer(.6).timeout;arena.set_physics_process(false)
	for a in arena.actors:if a!=arena.player:a.set_physics_process(false)
	var cell=Vector2i(6,6)
	for x in range(4,9):
		for y in range(4,9):clear.call(arena,Vector2i(x,y))
	arena.add_wall(cell,6);arena.board.shape_wall(cell,0)  # side 0: the left half stays
	arena.navigation.invalidate(cell)
	var soldier=arena.spawn_actor("soldier",cell+Vector2i(0,-2),false);soldier.set_physics_process(false)
	var tank=arena.spawn_actor("tank",cell+Vector2i(2,-3),false);tank.set_physics_process(false)
	var center=arena.world_pos(cell)
	var left=center+Vector3(-.25,0,0);var right=center+Vector3(.25,0,0)
	check(not arena.can_stand(left,soldier,true),"infantry cannot stand in the brick half")
	check(arena.can_stand(right,soldier,true),"infantry fits the open half")
	check(not arena.navigation.is_open(left,soldier) and arena.navigation.is_open(right,soldier),"the path planner sees the same: brick closed, gap open")
	check(not arena.can_enter(cell,tank) and not arena.can_stand(center,tank,true),"a vehicle never enters a half-block cell")
	var from_left=left+Vector3(0,0,-2);var to_left=left+Vector3(0,0,2)
	var from_right=right+Vector3(.06,0,-2);var to_right=right+Vector3(.06,0,2)
	check(not arena.clear_shot(from_left,to_left,.2),"a shot through the brick half is blocked")
	check(arena.clear_shot(from_right,to_right,.2),"a thin shot along the open half passes")
	# Real movement: the soldier walking down past the half-block never overlaps the brick.
	var overlapped=false;var goal=cell+Vector2i(0,3)
	soldier.route_points.clear()
	for frame in range(360):
		soldier.try_move(Vector2i.DOWN if soldier.position.z<arena.world_pos(goal).z else Vector2i.ZERO)
		soldier._physics_process(1.0/60.0)
		if preload("res://scripts/section_wall.gd").overlap(arena.walls[cell],center,soldier.position,Vector2(.245,.245)):overlapped=true
		if frame%6==0:await get_tree().physics_frame
	check(not overlapped,"a soldier moving past never steps into the brick half")
	arena.free();await settle()

## from update_v04 and active_battle_revision: trench protection, shell piercing, deliveries, the flag and run state.
func room_rules():
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false);arena.phase="combat"
	for wall in arena.walls.values():wall.node.queue_free()
	# Random floor patches (water, forest) and generators would decide the trench checks: clear them.
	arena.walls.clear();arena.trenches.clear();arena.terrain.patches.clear();arena.generators.clear();arena.navigation.reset()
	# from active_battle_revision: player damage multipliers — open full, trench half (bullet and blast), hidden zero.
	var player=arena.player;player.hp=100;player.max_hp=100;arena.star_time=0;arena.abilities.shield_time=0;arena.abilities.cloak_time=0;arena.run.dodge=0.0
	player.invulnerable=0;player.occupying_trench=false;player.hidden_in_trench=false;player.take_damage(4);check(is_equal_approx(player.hp,96),"open ground receives full damage")
	player.invulnerable=0;player.occupying_trench=true;player.take_damage(4);check(is_equal_approx(player.hp,94),"trench receives half bullet damage")
	player.invulnerable=0;player.take_damage(4,Vector3.RIGHT);check(is_equal_approx(player.hp,92),"trench receives half blast damage")
	player.invulnerable=0;player.hidden_in_trench=true;player.take_damage(100,Vector3.RIGHT);check(is_equal_approx(player.hp,92),"fully hidden receives zero damage")
	player.occupying_trench=false;player.hidden_in_trench=false;player.invulnerable=0
	# from update_v04.
	arena.add_trench(Vector2i(3,3))
	check(not arena.can_enter(Vector2i(3,3),arena.player),"trench blocks player")
	var enemy=arena.spawn_actor("soldier",Vector2i(3,2),false)
	check(arena.can_enter(Vector2i(3,3),enemy),"infantry special entry")
	enemy.cell=Vector2i(3,3);enemy.position=arena.world_pos(enemy.cell);enemy._physics_process(.1)
	var hp=enemy.hp;enemy.take_damage(99);check(enemy.hp==hp,"hidden infantry protected")
	enemy._physics_process(2);enemy.take_damage(1);check(enemy.hp<hp,"exposed infantry vulnerable")
	arena.actors.erase(enemy);enemy.queue_free()
	var buggy=arena.spawn_actor("buggy",Vector2i(arena.base_cell.x,arena.grid_size-2),false)
	buggy.facing=Vector2i.LEFT;buggy.fire_cooldown=0;buggy.route_points.clear()
	for i in range(20):buggy._physics_process(.1)
	for bullet in arena.projectiles.duplicate():
		for i in range(40):
			if not bullet.spent:bullet._physics_process(.02)
	check(arena.base_hp<arena.base_max_hp,"buggy damages base")
	arena.actors.erase(buggy);buggy.queue_free()
	# No random crit (base 5%, landing bonus, luck) on the pierce check: it made the old update_v04 check flaky.
	var luck_before=Game.luck_level;Game.luck_level=0;arena.run.crit_chance=0.0;arena.run.luck=0;arena.run.landing_until=-1.0
	var tank=arena.spawn_actor("tank",Vector2i(1,7),true)
	var first=arena.spawn_actor("soldier",Vector2i(1,5),false)
	var second=arena.spawn_actor("apc",Vector2i(1,3),false)
	arena.spawn_bullet(tank,tank.position,Vector2i.UP,3,true)
	var shell=arena.projectiles.back()
	for i in range(60):
		if not shell.spent:shell._physics_process(.01)
	check(first.dead and second.hp==2,"shell pierces two targets once")
	Game.luck_level=luck_before
	var wreck=arena.make_wreck("tank",Vector2i(9,9),Vector2i.UP,false,9);wreck.start_delivery(2)
	check(not wreck.boardable,"delivery cannot be boarded in air")
	wreck._physics_process(2.1);check(wreck.boardable and is_zero_approx(wreck.position.y),"delivery lands")
	# Clear the room first: the pierced APC survives with 2 HP and the opening wave may still be queued.
	for actor in arena.actors.filter(func(a):return not a.player_owned and not a.allied):arena.actors.erase(actor);actor.queue_free()
	arena.spawn_queue.clear();arena.wave=2;arena.room_boss_spawned=true;arena.finish_wave();var credits=Game.credits
	check(arena.room_cleared and arena.phase=="combat","clear waits at flag")
	arena.open_flag();var offers=arena.upgrade_offers.duplicate(true);arena.return_to_field();arena.open_flag()
	check(offers==arena.upgrade_offers and Game.credits==credits,"reopen preserves offers and reward")
	arena.apply_upgrade("damage",2);arena.return_to_field();arena.open_flag()
	check(arena.reward_claimed and arena.room_index==0,"upgrade does not leave room")
	# Unified luck: the old rarity branch folded into luck_level.
	var old=Game.luck_level;Game.luck_level=0;check(Game.rarity_roll(.15)==1,"base rarity")
	Game.luck_level=20;check(Game.rarity_roll(.15)==2,"luck improves rarity");Game.luck_level=old
	arena.free();await settle()
	var main=load("res://scripts/main.gd").new();add_child(main)
	# World 1 may place a service on stage 1: start on a lane whose road leads to an ordinary battle.
	main.start_run();var plan=RoutePlan.build(Game.visual_run_seed);var start="";var battle=""
	for node in plan[0]:
		for id in node.next:
			if battle=="" and RoutePlan.node_branch(RoutePlan.chosen(plan,1,{1:id}))=="":start=node.id;battle=id
	main.enter_room(0,start)
	main.current.damage_bonus=7.0;main.current.soldier_hp=2
	main.show_map(1)
	main.enter_room(1,battle)
	check(main.current.room_index==1 and main.current.damage_bonus==7 and main.current.soldier_hp==2,"map preserves run state")
	main.show_hub();main.queue_free();await settle()

## from reinforced_brick: share by route stage, whole-block breaking, separate randomness, base fortification levels.
func reinforced_brick():
	Campaign.configure(1)
	check(Campaign.reinforced_share(0)==0 and Campaign.reinforced_share(2)==0,"no reinforced brick before mid-route")
	check(is_equal_approx(Campaign.reinforced_share(3),.15) and is_equal_approx(Campaign.reinforced_share(6),.35),"share grows 15% to 35% toward the boss")
	var arena=load("res://scenes/arena.tscn").instantiate();arena.auto_pause_enabled=false;arena.run_seed=21;add_child(arena);arena.set_physics_process(false)
	for a in arena.actors:a.set_physics_process(false)
	var cell=Vector2i(4,4)
	if arena.walls.has(cell):arena.walls[cell].node.queue_free();arena.walls.erase(cell)
	arena.board.add_reinforced_wall(cell,12)
	var wall=arena.walls[cell];var origin=arena.world_pos(cell)
	check(wall.sections.all(func(v):return v>0),"reinforced brick starts as a full collision mask")
	var combat_state=arena.run.combat_rng.state
	for i in range(7):arena.board.damage_wall(cell,1.5,origin+Vector3(0,.4,.5),Vector3.FORWARD,.5)
	check(arena.walls.has(cell) and not arena.can_stand(origin,arena.player),"still a full block after 10.5 of 12 damage")
	check(wall.sections.all(func(v):return v>0),"damage never removes reinforced sections")
	arena.board.damage_wall(cell,1.5,origin+Vector3(0,.4,.5),Vector3.FORWARD,.5)
	check(not arena.walls.has(cell),"breaks as a whole at the full brick-block damage")
	check(arena.run.combat_rng.state==combat_state,"debris does not touch combat randomness")
	var early=0;var late=0
	for room in [1,5]:
		for seed_value in [3,4,5]:
			arena.run_seed=seed_value;arena.begin_room(room)
			var count=arena.walls.values().filter(func(w):return w.get("reinforced",false)).size()
			if room==1:early+=count
			else:late+=count
	check(early==0 and late>0,"placement follows the route: early=%d late=%d" % [early,late])
	# Base fortification bonus: 0-1 brick, 2 reinforced brick, 3+ indestructible PO-2 fence halves.
	var wall_level=Game.bonus_levels.get("wall",0);Game.bonus_levels["wall"]=0
	var expected={1:"brick",2:"reinforced",3:"fence"}
	for level in [1,2,3]:
		arena.run_seed=8;arena.begin_room(1);arena.run.run_bonus_levels["wall"]=level
		var base_cells=[Vector2i(arena.base_cell.x-1,arena.grid_size-2),Vector2i(arena.base_cell.x,arena.grid_size-2),Vector2i(arena.base_cell.x+1,arena.grid_size-2),Vector2i(arena.base_cell.x-1,arena.grid_size-1),Vector2i(arena.base_cell.x+1,arena.grid_size-1)]
		var holder=Node3D.new();arena.add_child(holder)
		arena.reward.collect_pickup({"node":holder,"kind":"wall"})
		for c in base_cells:
			var w=arena.walls.get(c)
			if not check(w!=null,"base wall present at level %d" % level):continue
			var kind="fence" if w.hp<0 and w.get("style_kind","")=="concrete_0" else "reinforced" if w.get("reinforced",false) else "brick" if w.hp>0 else "other"
			check(kind==expected[level],"level %d gives %s, got %s" % [level,expected[level],kind])
			check(w.has("half_side"),"base wall keeps its prescribed half shape")
	Game.bonus_levels["wall"]=wall_level
	check(BattleMapGenerator.generate(5,4,false).rows.all(func(r):return "A" not in r),"no legacy armored blocks")
	arena.free();await settle()
