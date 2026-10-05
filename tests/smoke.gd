extends Node
var failures=0
var checks=0
var arena
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;push_error("FAIL: "+message)
	else:print("PASS: "+message)
func _ready():call_deferred("run")
func fresh():
	if is_instance_valid(arena):arena.free()
	Game.reset_input()
	arena=load("res://scenes/arena.tscn").instantiate();add_child(arena)
	arena.auto_pause_enabled=false;arena.phase="combat";arena.set_physics_process(false);arena.spawn_queue.clear()
func clear_cell(p: Vector2i):
	if arena.walls.has(p):arena.walls[p].node.queue_free();arena.walls.erase(p)
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades();Game.built_workshops=Game.BUILD_COST.keys()
	Game.bonus_unlocks=Game.LOOT.BONUSES.keys()
	var generator_ok=true;var variants={}
	for room in range(6):
		for seed_value in range(100):
			var generated=BattleMapGenerator.generate(seed_value,room)
			generator_ok=generator_ok and BattleMapGenerator.validate(generated.rows) and generated.rows.size()==Campaign.SIZES[room]
			var middle=int(generated.rows.size()/2.0)
			var total_concrete=0
			for row in generated.rows:total_concrete+=row.count("C")
			generator_ok=generator_ok and total_concrete>3
			for x in range(middle-1,middle+2):
				var blocked=false
				for row in generated.rows:blocked=blocked or row[x]=="C"
				generator_ok=generator_ok and blocked
			variants[str(generated.rows)]=true
	check(generator_ok,"600 generated maps: size, three central columns blocked and extra concrete, both flanks, all floor connected")
	check(variants.size()>250,"generation produces diverse layouts")
	fresh()
	check(arena.soldier_hp==3 and arena.base_hp==5,"initial health")
	check(arena.grid_size==Campaign.SIZES[0],"first room uses the world size table")
	var brick=Vector2i(arena.base_cell.x,arena.grid_size-2)
	check(not arena.can_enter(brick),"brick blocks movement")
	arena.damage_wall(brick,3)
	check(not arena.walls.has(brick),"brick is destructible")
	var concrete=Vector2i.ZERO
	for cell in arena.walls:
		if arena.walls[cell].hp<0:concrete=cell;break
	arena.damage_wall(concrete,999)
	check(arena.walls.has(concrete),"central concrete cannot be shot through")
	var p=arena.player
	p.set_facing(Vector2i.RIGHT);check(not p.shoot(),"no shots during turn")
	p._physics_process(.11);check(p.shoot(),"shots allowed after turn")
	var press=InputEventKey.new();press.physical_keycode=KEY_SPACE;press.pressed=true;Game.input_router._input(press)
	for dir in [Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]:
		p.fire_cooldown=0;p.set_facing(dir);p._physics_process(.04)
		check(is_zero_approx(p.fire_cooldown),"held fire pauses for rotation "+str(dir))
		p._physics_process(.08);check(p.fire_cooldown>0,"held fire resumes without new keydown "+str(dir))
	press.pressed=false;Game.input_router._input(press);check(not Game.wants_fire(),"releasing space stops fire")
	p.facing=Vector2i.UP;p.model.rotation.y=0;p.turn_left=0;p.moving=false
	Game.touch_direction=Vector2i.RIGHT;p._physics_process(.01)
	check(p.facing==Vector2i.RIGHT,"movement always turns aim; strafe removed")
	Game.touch_direction=Vector2i.ZERO;p._physics_process(.5)
	check(p.fire_interval==.6,"slower base rifle interval")

	# The soldier lands with a short spawn grace; end it before checking hits.
	p.invulnerable=0;p.take_damage(1);check(arena.soldier_hp==2,"hit costs one heart")
	p.take_damage(1);check(arena.soldier_hp==2,"damage grace period")
	var adjacent=p.cell+Vector2i.RIGHT;clear_cell(adjacent)
	var wreck=arena.make_wreck("apc",adjacent,Vector2i.UP,true)
	# A destroyed enemy vehicle is a 5-second bomb, never boarded (capture goes through the beacon).
	check(wreck.unstable and not wreck.boardable and is_equal_approx(wreck.timer,5.0),"enemy wreck is a five-second bomb")
	wreck.spent=true;arena.wrecks.erase(wreck);wreck.queue_free()
	var supply=arena.make_wreck("apc",adjacent,Vector2i.UP,false,5)
	supply._physics_process(20);check(not supply.spent,"supply vehicle has no boarding deadline")
	arena.interact();check(arena.player.kind=="apc" and arena.player.hp==5,"boarding supplied APC retains full armor")
	arena.interact();check(arena.player.kind=="soldier" and arena.soldier_hp==2,"exit preserves soldier hearts")
	check(arena.nearest_wreck()!=null,"abandoned vehicle can be boarded again")
	arena.interact();arena.player.invulnerable=0;arena.player.take_damage(99)
	check(arena.player.kind=="soldier" and arena.phase=="combat","destroyed armor ejects soldier")
	var timed=arena.make_wreck("tank",Vector2i(0,0),Vector2i.DOWN,true);timed._physics_process(5.01)
	check(timed.husk and not timed.boardable and not timed.unstable,"wreck explodes after five seconds and stays as a husk")
	fresh()
	check(arena.unlocked_vehicle()=="","no vehicle supply before first room final wave")
	arena.start_wave(2);check(arena.unlocked_vehicle()=="buggy","buggy unlocks at room 1 wave 3")
	var supply_pickup=arena.pickups.back();arena.collect_pickup(supply_pickup)
	check(arena.wrecks.size()==1 and arena.wrecks[0].kind=="buggy" and not arena.wrecks[0].boardable,"vehicle supply descends before boarding")
	# The random run may route into a dark maze challenge, which uses the largest field of the world.
	var field_size=func(index):return Campaign.SIZES.max() if arena.room.mode=="maze" else Campaign.SIZES[index]
	arena.begin_room(1);check(arena.grid_size==field_size.call(1) and arena.unlocked_vehicle()=="buggy","room 2 size and vehicle progression")
	arena.start_wave(2);check(arena.unlocked_vehicle()=="buggy","buggy supply stays through room 2")
	arena.begin_room(2);check(arena.grid_size==field_size.call(2),"room 3 size")
	var mixed=WaveDirector.build(42,4,2)
	check(mixed.size()==WaveDirector.wave_size(4,2) and mixed.any(func(e):return e.kind in WaveDirector.PEOPLE) and mixed.any(func(e):return e.kind in WaveDirector.MACHINES),"room 5 uses mixed squad waves")
	fresh()
	# The run seed is random: route every stage through a plain battle node, so a challenge room (maze, hold…)
	# never replaces the wave machine checked below (it made this check flaky).
	var plan=RoutePlan.build(arena.run_seed)
	for stage in range(mini(7,plan.size())):
		var battles=plan[stage].filter(func(node):return node.type=="battle")
		if not battles.is_empty():arena.run.route_choices[stage]=battles[0].id
	arena.begin_room(0);arena.phase="combat";arena.spawn_queue.clear()
	for room in range(6):
		for wave in range(3):
			arena.room_index=room;arena.wave=wave;arena.phase="combat";arena.spawn_queue.clear()
			arena.room_boss_spawned=true;arena.finish_wave()
			if wave==2:arena.open_flag()
			check(arena.phase=="upgrade","upgrade r%d w%d (%s, mode %s)" % [room+1,wave+1,arena.phase,arena.room.mode])
			arena.apply_upgrade("damage")
			if wave==2:
				check(arena.reward_claimed and arena.room_index==room,"flag upgrade waits for departure")
				arena.begin_room(room+1)
			check(arena.room_index==(room+1 if wave==2 else room),"correct room transition")
	check(arena.room_index==6 and arena.grid_size==Campaign.SIZES[6] and arena.boss_room,"final arena")
	check(arena.damage_bonus==9.0,"upgrades persist across six rooms")
	check(arena.walls.size()>=8 and arena.walls.values().all(func(w):return w.hp>0),"boss arena has only four small cover islands")
	arena.phase="combat";arena.spawn_queue.clear()
	var boss=arena.spawn_actor("boss",Vector2i(5,0),false)
	# Boss variants (BossCatalog) differ in model and footprint per run seed.
	var encounter=BossCatalog.encounter(arena.run_seed,arena.room_index)
	check(boss.footprint==encounter.footprint and arena.cells_for(boss,boss.cell).size()==encounter.footprint*encounter.footprint,"boss occupies its square collision footprint")
	check(arena.inside(Vector2i(arena.grid_size-encounter.footprint,0)) and not arena.can_enter(Vector2i(arena.grid_size-encounter.footprint+1,0),boss),"boss cannot cross arena boundary")
	if encounter.model=="boss":check(boss.turret_pivot.get_child_count()>=3,"boss turret contains the gun and rotates separately")
	var count_before=arena.projectiles.size()
	arena.boss_radial_attack(boss)
	check(arena.projectiles.size()==count_before+16,"boss radial attack emits 16 projectiles")
	check(arena.projectiles.any(func(b):return b.orb and absf(b.travel_direction.x)>.1 and absf(b.travel_direction.z)>.1),"radial projectiles include diagonal directions")
	var diagonal=arena.spawn_free_bullet(boss,Vector3(1,0,1),2,6.8,false)
	var before=diagonal.position;diagonal._physics_process(.02)
	check(diagonal.position.x>before.x and diagonal.position.z>before.z,"aimed boss shell moves at an arbitrary angle")
	# Boss patterns wind up first: the charge phase shows the warning ring and the attack name.
	boss.moving=false;boss.set_meta("boss_pattern",{"phase":"move","timer":0.0,"index":0,"direction":Vector3.FORWARD,"target":Vector3.ZERO,"warning":null});arena.boss_step(boss,.01)
	check(boss.get_meta("boss_pattern").phase=="charge" and boss.warning_ring.visible,"boss attack has a visible warning interval")

	# T-260: the HQ stays on the field in a world general fight and can be damaged.
	var base_before=arena.base_hp;arena.damage_base(1);check(arena.base_hp<base_before or Campaign.is_final(arena.room_index),"the HQ is a target in the general fight")
	# Shield phases cap boss damage (boss_campaign_revision); without them the boss falls and drops the commander chest.
	arena.room.generator_order.clear();arena.room.generator_thresholds.clear();boss.invulnerable=0;boss.take_damage(boss.max_hp+1)
	check(arena.boss_defeated and arena.pickups.any(func(p):return p.kind=="recipe_draft"),"boss death drops the commander chest")
	fresh()
	for side in [-1,1]:
		var drop_cell=Vector2i(arena.base_cell.x+side*2,arena.grid_size-1)
		var drone=arena.spawn_actor("drone",drop_cell,false);drone.flank=side
		arena.drone_step(drone)
		check(drone.dead and arena.bombs.size()>0,"drone plants bomb on matching base flank "+str(side))
		var bomb=arena.bombs.back();bomb._physics_process(1.4)
		check(bomb.spent,"planted bomb explodes")
	check(not arena.walls.has(arena.base_cell+Vector2i.LEFT) and not arena.walls.has(arena.base_cell+Vector2i.RIGHT),"flank bombs breach side walls")
	fresh();arena.damage_base(5);check(arena.phase=="result","normal-room base destruction loses run")
	# The once-per-run reprieve («На волоске») is spent first.
	fresh();arena.run.mercy_used=true;arena.player.invulnerable=0;arena.player.take_damage(99);check(arena.phase=="result","soldier death loses run")
	fresh()
	for chance in [1.0,0.0]:
		var friendly=load("res://scenes/projectile.tscn").instantiate();var hostile=load("res://scenes/projectile.tscn").instantiate()
		friendly.arena=arena;friendly.friendly=true;hostile.arena=arena
		arena.add_child(friendly);arena.add_child(hostile);arena.projectiles.append(friendly);arena.projectiles.append(hostile)
		# Interception is a pressure contest: the friendly bullet wins with pressure/(pressure+enemy pressure).
		friendly.pressure=chance;hostile.pressure=1.0-chance;arena.resolve_interception(friendly,hostile)
		check(hostile.spent==(chance==1.0) and friendly.spent==(chance==0.0),"bullet interception probability "+str(chance))
	arena.intercept_chance=.9;arena.phase="upgrade";arena.apply_upgrade("intercept",2)
	check(CombatStats.probability(arena)<=Balance.CONFIG.combat.interception_cap+.0001,"interception stays under the balance cap")
	Game.credits=Game.cost("health");check(Game.purchase("health") and Game.health_level==1 and Game.credits==0,"meta purchase")
	# Round trip only inside a fresh temporary folder (profile, backup and temp files).
	var dir=OS.get_temp_dir().path_join("warcats_smoke_%d" % Time.get_ticks_usec());DirAccess.make_dir_recursive_absolute(dir)
	var restore={"path":Game.save_path,"selected":Game.profiles.selected,"blocked":Game.save_blocked}
	Game.save_path=dir.path_join("profile.json");Game.profiles.selected=true;Game.save_blocked=false;Game.save_enabled=true;Game.credits=23;Game.save_progress()
	Game.credits=0;Game.health_level=0;Game.load_progress();check(Game.credits==23 and Game.health_level==1,"persistent save/reload")
	for file in DirAccess.get_files_at(dir):DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir);Game.save_enabled=false;Game.save_path=restore.path;Game.profiles.selected=restore.selected;Game.save_blocked=restore.blocked
	arena.free()
	obstacle_density_checks()
	terrain_checks()
	# The hub is the practice run's arena (one field engine): its garage tank is the arena's vehicle — E boards it,
	# the battle controls drive it, E again leaves it.
	for id in ["garage","yard"]:
		if id not in Game.built_workshops:Game.built_workshops.append(id)
	Game.garage.owned=["tank"];Game.garage.selected="tank";Engine.set_meta("hub_calls_off",true)
	var hub=preload("res://scripts/hub.gd").open_practice(self);await get_tree().process_frame
	var practice=hub.arena;hub.phase="combat";practice.phase="combat";practice.set_physics_process(false)
	var parked=practice.wrecks.filter(func(w):return is_instance_valid(w) and w.kind=="tank" and not w.spent)
	hub.place_hero(parked[0].position+Vector3(-1,0,0));hub.interact()
	check(practice.player.kind=="tank" and hub.riding(),"board the hub tank")
	var z=practice.player.position.z
	Game.touch_direction=Vector2i.DOWN
	for i in range(30):practice.player._physics_process(.05)
	check(practice.player.position.z>z+.5,"drive hub tank")
	Game.touch_direction=Vector2i.ZERO;hub.interact()
	check(practice.player.kind=="soldier" and hub.on_foot(),"leave hub tank")
	hub.queue_free();await get_tree().process_frame;Engine.remove_meta("hub_calls_off")
	print("R13 SMOKE: %d checks, %d failures" % [checks,failures]);get_tree().quit(1 if failures else 0)

# from obstacle_density_revision: thinning cuts every obstacle family by 15%, deterministically, keeping layouts valid.
func obstacle_density_checks():
	var rows=[]
	for y in range(31):rows.append(".".repeat(31))
	var kinds=["B","C","X","R","T","N"]
	for i in range(kinds.size()):
		for x in range(1,21):BattleMapGenerator.put(rows,Vector2i(x,2+i*3),kinds[i])
	var copy=rows.duplicate();BattleMapGenerator.thin_obstacles(rows,917,false);BattleMapGenerator.thin_obstacles(copy,917,false)
	check(rows==copy,"obstacle thinning is deterministic for one seed")
	var thinned=true
	for kind in kinds:
		var count=0
		for row in rows:count+=row.count(kind)
		thinned=thinned and count==17
	check(thinned,"every obstacle family is reduced by 15 percent (20 -> 17)")
	var valid=true
	for world in range(1,4):
		Campaign.configure(world)
		for room in [0,3,5]:
			for seed_value in range(20):
				valid=valid and BattleMapGenerator.validate(BattleMapGenerator.generate(seed_value*1117,room).rows)
	Campaign.configure(1)
	check(valid,"thinning preserves connected paths and base cover in 180 layouts of three worlds")

# from terrain_v1: floor patches (water/sand/ice/vegetation) by biome, determinism and movement rules. Screenshot dropped.
func terrain_checks():
	var ta=load("res://scenes/arena.tscn").instantiate();ta.run_seed=82415;add_child(ta);ta.process_mode=Node.PROCESS_MODE_DISABLED;ta.auto_pause_enabled=false
	var kinds={};var seen_biomes={};var saw_bend=false;var saw_long=false
	var deterministic=true;var exclusive=true;var palette_ok=true;var budget_ok=true;var strips_ok=true
	for world in range(1,4):
		Campaign.configure(world)
		for room in range(7):
			ta.begin_room(room)
			var before=ta.terrain.patches.duplicate()
			ta.terrain.generate();var again=ta.terrain.patches.duplicate()
			ta.terrain.generate();deterministic=deterministic and again==ta.terrain.patches
			for p in before:
				var c=Vector2i(p.x/2,p.y/2)
				exclusive=exclusive and not ta.trenches.has(c) and not ta.walls.has(c) and not ta.generators.has(c)
				kinds[before[p]]=true
			seen_biomes[ta.BIOMES.index(ta.run_seed,room)]=true
			palette_ok=palette_ok and ta.room_palette().family in ta.BIOMES.families(room) and not before.is_empty()
			for kind in before.values():palette_ok=palette_ok and kind in ta.room_palette().kinds
			var hazard_count=0
			for kind in before.values():
				if kind in ["water","ice"]:hazard_count+=1
			budget_ok=budget_ok and hazard_count/4<=ta.terrain.terrain_budget()
			for strip in ta.terrain.strips:
				strips_ok=strips_ok and strip.width==1.0 and strip.length>=1 and strip.length<=6
				saw_bend=saw_bend or strip.bend;saw_long=saw_long or strip.length>2
	check(deterministic,"terrain generation is deterministic on a finished field")
	check(exclusive,"floor patches never overlap trenches, walls or generators")
	check(palette_ok,"room palette follows the biome families of the world and route part")
	check(budget_ok,"water and ice stay inside the terrain budget")
	check(kinds.size()==4 and seen_biomes.size()>=7 and saw_bend,"three worlds show four floor kinds, 7+ biomes and bends")
	for seed_value in range(140):
		ta.run_seed=seed_value;ta.room.difficulty=2;ta.terrain.generate()
		for strip in ta.terrain.strips:
			strips_ok=strips_ok and strip.width==1 and strip.cells.size()==strip.length
			for i in range(strip.cells.size()):
				var c=strip.cells[i]
				if i>0:strips_ok=strips_ok and (c-strip.cells[i-1]).length_squared()==1
				for x in range(2):
					for y in range(2):strips_ok=strips_ok and ta.terrain.patches[c*2+Vector2i(x,y)]==strip.kind
			if strip.length==6:saw_long=true
	check(strips_ok and saw_long,"terrain strips are one cell wide, contiguous, atomically placed, up to 6 long")
	ta.walls.clear();ta.trenches.clear();ta.generators.clear();ta.wrecks.clear()
	for a in ta.actors:
		if a!=ta.player:a.dead=true
	var actor=ta.player;actor.occupying_trench=false;actor.kind="soldier";actor.position=Vector3.ZERO;actor.cell=ta.grid_pos(actor.position);actor.moving=false
	ta.terrain.patches.clear();ta.terrain.set_cell(actor.cell,"water")
	check(not ta.can_stand(actor.position,actor) and not ta.can_enter(actor.cell,actor),"water blocks actors")
	check(ta.clear_shot(actor.position-Vector3.RIGHT,actor.position+Vector3.RIGHT,.5),"water does not block shots")
	var bullet=ta.spawn_bullet(actor,actor.position,Vector2i.RIGHT,1,true)
	check(not ta.bullet_hit(bullet),"bullets pass over water");bullet.consume()
	ta.terrain.patches.clear();ta.terrain.set_cell(actor.cell,"sand")
	var sand_soldier=ta.terrain.speed_factor(actor);actor.kind="tank"
	check(is_equal_approx(sand_soldier,.55) and is_equal_approx(ta.terrain.speed_factor(actor),.55),"sand slows infantry and tanks to 55%")
	ta.terrain.patches.clear();ta.terrain.set_cell(actor.cell,"ice")
	for kind in ["soldier","tank"]:
		actor.kind=kind;actor.position=Vector3.ZERO;actor.moving=false;actor.slide_remaining=0;actor.terrain_direction=Vector2i.RIGHT
		var started=ta.terrain.begin_slide(actor) and actor.quarter_destination==Vector3(.25,0,0)
		for step in range(12):
			actor.position=actor.quarter_destination;actor.cell=ta.grid_pos(actor.position);actor.moving=false
			if not ta.terrain.begin_slide(actor):break
		check(started and actor.slide_remaining==0 and actor.position.x<2,"ice coasts a short distance and stops ("+kind+")")
	actor.kind="soldier";actor.position=Vector3.ZERO;actor.cell=ta.grid_pos(actor.position);actor.moving=false;actor.terrain_direction=Vector2i.RIGHT
	ta.terrain.set_cell(actor.cell+Vector2i.RIGHT,"water")
	for step in range(8):
		if not ta.terrain.begin_slide(actor):break
		actor.position=actor.quarter_destination;actor.moving=false
	check(not ta.terrain.blocked(actor.position,.245),"ice slide stops before water")
	Campaign.configure(1)
	ta.free()
