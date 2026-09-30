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
	Game.save_enabled=false;Game.sound_enabled=false;Game.reset_upgrades();Game.built_workshops=Game.BUILD_COST.keys()
	Game.bonus_unlocks=Game.LOOT.BONUSES.keys()
	var generator_ok=true;var variants={}
	for room in range(6):
		for seed_value in range(100):
			var generated=BattleMapGenerator.generate(seed_value,room)
			generator_ok=generator_ok and BattleMapGenerator.validate(generated.rows) and generated.rows.size()==[13,15,17,18,19,20][room]
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
	check(arena.grid_size==13,"first room 13x13")
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
	var press=InputEventKey.new();press.physical_keycode=KEY_SPACE;press.pressed=true;Game._input(press)
	for dir in [Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]:
		p.fire_cooldown=0;p.set_facing(dir);p._physics_process(.04)
		check(is_zero_approx(p.fire_cooldown),"held fire pauses for rotation "+str(dir))
		p._physics_process(.08);check(p.fire_cooldown>0,"held fire resumes without new keydown "+str(dir))
	press.pressed=false;Game._input(press);check(not Game.wants_fire(),"releasing space stops fire")
	p.facing=Vector2i.UP;p.model.rotation.y=0;p.turn_left=0;p.moving=false
	Game.touch_direction=Vector2i.RIGHT;p._physics_process(.01)
	check(p.facing==Vector2i.RIGHT,"movement always turns aim; strafe removed")
	Game.touch_direction=Vector2i.ZERO;p._physics_process(.5)
	check(p.fire_interval==.6,"slower base rifle interval")

	p.take_damage(1);check(arena.soldier_hp==2,"hit costs one heart")
	p.take_damage(1);check(arena.soldier_hp==2,"damage grace period")
	var adjacent=p.cell+Vector2i.RIGHT;clear_cell(adjacent)
	var wreck=arena.make_wreck("apc",adjacent,Vector2i.UP,true)
	check(wreck.boardable,"enemy wreck is boardable for five seconds")
	wreck.spent=true;arena.wrecks.erase(wreck);wreck.queue_free()
	var supply=arena.make_wreck("apc",adjacent,Vector2i.UP,false,5)
	supply._physics_process(20);check(not supply.spent,"supply vehicle has no boarding deadline")
	arena.interact();check(arena.player.kind=="apc" and arena.player.hp==5,"boarding supplied APC retains full armor")
	arena.interact();check(arena.player.kind=="soldier" and arena.soldier_hp==2,"exit preserves soldier hearts")
	check(arena.nearest_wreck()!=null,"abandoned vehicle can be boarded again")
	arena.interact();arena.player.invulnerable=0;arena.player.take_damage(99)
	check(arena.player.kind=="soldier" and arena.phase=="combat","destroyed armor ejects soldier")
	var timed=arena.make_wreck("tank",Vector2i(0,0),Vector2i.DOWN,true);timed._physics_process(5.01)
	check(timed.spent,"wreck still explodes after five seconds")
	fresh()
	check(arena.unlocked_vehicle()=="","no vehicle supply before first room final wave")
	arena.start_wave(2);check(arena.unlocked_vehicle()=="buggy","buggy unlocks at room 1 wave 3")
	var supply_pickup=arena.pickups.back();arena.collect_pickup(supply_pickup)
	check(arena.wrecks.size()==1 and arena.wrecks[0].kind=="buggy" and not arena.wrecks[0].boardable,"vehicle supply descends before boarding")
	arena.begin_room(1);check(arena.grid_size==15 and arena.unlocked_vehicle()=="buggy","room 2 size and APC progression")
	arena.start_wave(2);check(arena.unlocked_vehicle()=="buggy","buggy supply stays through room 2")
	arena.begin_room(2);check(arena.grid_size==17,"room 3 is 17x17")
	check(WaveDirector.build(42,4,2).size()<=8,"room 5 uses compact mixed waves")
	fresh()
	for room in range(6):
		for wave in range(3):
			arena.room_index=room;arena.wave=wave;arena.phase="combat";arena.spawn_queue.clear()
			arena.room_boss_spawned=true;arena.finish_wave()
			if wave==2:arena.open_flag()
			check(arena.phase=="upgrade","upgrade r%d w%d" % [room+1,wave+1])
			arena.apply_upgrade("damage")
			if wave==2:
				check(arena.reward_claimed and arena.room_index==room,"flag upgrade waits for departure")
				arena.begin_room(room+1)
			check(arena.room_index==(room+1 if wave==2 else room),"correct room transition")
	check(arena.room_index==6 and arena.grid_size==21 and arena.boss_room,"final arena 21x21")
	check(arena.damage_bonus==9.0,"upgrades persist across six rooms")
	check(arena.walls.size()>=8 and arena.walls.values().all(func(w):return w.hp>0),"boss arena has only four small cover islands")
	arena.phase="combat";arena.spawn_queue.clear()
	var boss=arena.spawn_actor("boss",Vector2i(5,0),false)
	check(boss.footprint==4 and arena.cells_for(boss,boss.cell).size()==16,"boss occupies 4x4 collision footprint")
	check(not arena.can_enter(Vector2i(arena.grid_size-3,0),boss),"boss cannot cross arena boundary")
	check(boss.turret_pivot.get_child_count()>=3,"boss turret contains the gun and rotates separately")
	var count_before=arena.projectiles.size()
	arena.boss_radial_attack(boss)
	check(arena.projectiles.size()==count_before+16,"boss radial attack emits 16 projectiles")
	check(arena.projectiles.any(func(b):return b.orb and absf(b.travel_direction.x)>.1 and absf(b.travel_direction.z)>.1),"radial projectiles include diagonal directions")
	var diagonal=arena.spawn_free_bullet(boss,Vector3(1,0,1),2,6.8,false)
	var before=diagonal.position;diagonal._physics_process(.02)
	check(diagonal.position.x>before.x and diagonal.position.z>before.z,"aimed boss shell moves at an arbitrary angle")
	boss.radial_timer=0;boss.radial_charge=0;arena.boss_step(boss,.01)
	check(boss.radial_charge>1 and boss.warning_ring.visible,"radial attack has a visible warning interval")

	arena.damage_base(100);check(arena.phase=="combat","no base-loss condition in boss duel")
	boss.take_damage(999);check(arena.phase=="result" and arena.boss_defeated,"boss death completes run")
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
	fresh();arena.player.take_damage(99);check(arena.phase=="result","soldier death loses run")
	fresh()
	for chance in [1.0,0.0]:
		var friendly=load("res://scenes/projectile.tscn").instantiate();var hostile=load("res://scenes/projectile.tscn").instantiate()
		friendly.arena=arena;friendly.friendly=true;hostile.arena=arena
		arena.add_child(friendly);arena.add_child(hostile);arena.projectiles.append(friendly);arena.projectiles.append(hostile)
		arena.weapon="rifle";arena.combat_rng.seed=1;arena.intercept_chance=chance;arena.resolve_interception(friendly,hostile)
		check(hostile.spent and friendly.spent==(chance==0.0),"bullet interception probability "+str(chance))
	arena.intercept_chance=.9;arena.phase="upgrade";arena.apply_upgrade("intercept")
	check(is_equal_approx(arena.intercept_chance,.95),"interception capped at 95 percent")
	Game.credits=10;check(Game.purchase("health") and Game.health_level==1 and Game.credits==0,"meta purchase")
	Game.save_path="res://tmp/test-progress.json";Game.save_enabled=true;Game.credits=23;Game.save_progress()
	Game.credits=0;Game.health_level=0;Game.load_progress();check(Game.credits==23 and Game.health_level==1,"persistent save/reload")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.save_path));Game.save_enabled=false
	arena.free()
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub)
	hub.avatar.position=Vector3(5,0,1);hub.cell=Vector2i(5,1);hub.destination=hub.avatar.position;hub.interact()
	check(hub.mounted and not hub.avatar.visible,"board hub tank")
	Game.touch_direction=Vector2i.UP;hub._physics_process(.01);hub._physics_process(.5)
	check(hub.training_tank.position.z<1,"drive hub tank")
	Game.touch_direction=Vector2i.ZERO;hub._physics_process(.5);hub.interact()
	check(not hub.mounted and hub.avatar.visible,"leave hub tank")
	hub.free();await get_tree().process_frame
	print("R13 SMOKE: %d checks, %d failures" % [checks,failures]);get_tree().quit(1 if failures else 0)
