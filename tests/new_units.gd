extends Node
var failures=0
var checks=0
var arena
func check(ok,message):
	checks+=1
	if not ok:failures+=1;push_error(message)
	else:print("PASS: ",message)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false;Game.damage_level=0
	arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false)
	arena.begin_room(2);arena.phase="combat";arena.player.set_physics_process(false)
	for actor in arena.actors:actor.set_physics_process(false)
	arena.install_turret();arena.install_turret();arena.install_turret()
	var allies=arena.actors.filter(func(a):return a.allied)
	check(allies.size()==2,"two turret limit")
	check(arena.enemy_count()==0,"friendly turrets do not block wave completion")
	var turret=allies[0];var original=turret.cell;turret.try_move(Vector2i.UP)
	check(not turret.moving and turret.cell==original,"stationary turret")
	arena.explosion(turret.position,3);check(turret.hp==2,"drone blast damages friendly turret")
	var bullet=load("res://scenes/projectile.tscn").instantiate();bullet.arena=arena;bullet.friendly=false;bullet.damage=2;bullet.position=turret.position+Vector3.UP*.55;arena.add_child(bullet)
	arena.bullet_hit(bullet);check(turret.dead,"enemy bullets destroy friendly turret without killing player")
	bullet.consume()
	arena.install_turret();check(arena.actors.filter(func(a):return a.allied).size()==2,"destroyed turret slot can be rebuilt")
	var enemy=arena.spawn_actor("mortar",Vector2i(1,0),false);enemy.set_physics_process(false);enemy.fire_cooldown=0
	arena.mortar_step(enemy)
	var grenade=arena.grenades.back();grenade.set_physics_process(false)
	check(grenade.target==arena.world_pos(arena.base_cell),"enemy mortar targets base")
	var base_before=arena.base_hp;grenade._physics_process(1.5)
	check(grenade.position.y>5 and arena.base_hp==base_before,"ballistic grenade rises above cover before impact")
	arena.phase="paused";var pos=grenade.position;grenade._physics_process(.5);check(grenade.position==pos,"grenade respects pause")
	arena.phase="combat";grenade._physics_process(1.5);check(arena.base_hp<base_before,"grenade lands and damages base")
	var grenadier=arena.spawn_actor("grenadier",arena.player.cell+Vector2i.UP*2,false);grenadier.set_physics_process(false)
	grenadier._physics_process(.01)
	check(not arena.grenades.is_empty() and arena.grenades.back().target==Vector3(arena.player.position.x,0,arena.player.position.z),"grenadier throws at player position")
	var supply=arena.make_wreck("buggy",arena.player.cell+Vector2i.LEFT,Vector2i.UP,false,4)
	arena.interact();check(arena.player.kind=="buggy","buggy can be boarded")
	var buggy=arena.player
	# Player vehicles take their numbers from the garage catalog (origin, zone and upgrades).
	check(is_equal_approx(buggy.damage,GarageCatalog.stats("buggy",arena,buggy.vehicle_origin,buggy.vehicle_zone).damage),"buggy damage from garage stats")
	buggy.shoot();check(arena.projectiles.back().speed==20,"buggy high velocity bullets")
	arena.interact();check(arena.player.kind=="soldier","buggy can be exited")
	for kind in ["drone","buggy"]:
		var unit=arena.spawn_actor(kind,Vector2i(0,0),false);unit.set_physics_process(false);unit.movement_pause=99
		unit.try_move(Vector2i.DOWN);check(unit.moving,"continuous movement ignores pauses: "+kind)
		arena.actors.erase(unit);unit.free()
	# Waypoints vary per unit but stay within max(3, 20% of the field) columns of the spawn lane (or a trench).
	var routes={};var near=true;var reach=maxi(3,int(arena.grid_size*.2))
	for i in range(20):
		var unit=arena.spawn_actor("soldier",Vector2i(1,0),false);routes[str(unit.route_points)]=true
		near=near and unit.route_points.all(func(p):return absi(p.x-1)<=reach or arena.trenches.has(p));arena.actors.erase(unit);unit.free()
	print("routes: ",routes.size())
	check(routes.size()>3 and near,"enemies choose varied intermediate routes near their lane")
	for room in range(5):
		# Layout rule before the 15% visual thinning (obstacle_density_revision), which may drop any unprotected block.
		var rows=BattleMapGenerator.generate(1234,room,false).rows;var middle=int(rows.size()/2.0)
		check(rows[rows.size()-3][middle-3]=="C" and rows[rows.size()-3][middle+3]=="C","lower camping lanes blocked room %d" % room)
	arena.free();print("NEW UNITS: ",checks," checks, ",failures," failures");get_tree().quit(failures)
