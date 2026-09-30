extends Node
var failures=0
var checks=0
func check(ok,message):
	checks+=1
	if not ok:failures+=1;push_error(message)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Game.weapon_unlocks=["rifle","smg","heavy"];Game.mobility_level=0;Game.recovery_level=0
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false)
	arena.phase="upgrade";arena.next_is_room=false;arena.hud.show_upgrades()
	check(arena.upgrade_offers.size()==3 and arena.upgrade_offers.all(func(o):return o.id in ["health","speed","recovery","damage","intercept"]),"wave gives character stats only")
	arena.next_is_room=true;arena.upgrade_offers.clear();arena.hud.show_upgrades()
	check(arena.upgrade_offers[0].id in ["smg","heavy"] and arena.upgrade_offers[1].id=="weapon_damage" and arena.upgrade_offers[2].id=="weapon_fire","room gives one switch and two current-weapon stats")
	var before=arena.player.damage;arena.apply_upgrade("weapon_damage",2)
	check(arena.player.damage==before+1,"epic gun damage applied")
	arena.apply_upgrade("smg");check(arena.weapon_mods.smg.damage==0,"switch does not transfer gun upgrades")
	arena.apply_upgrade("rifle");check(arena.player.damage==before+1,"returning retains gun upgrade")
	var interval=arena.player.fire_interval;arena.apply_upgrade("weapon_fire",0)
	check(is_equal_approx(arena.player.fire_interval,interval*.85),"gun fire rate changes interval")
	arena.phase="combat"
	var sniper=arena.spawn_actor("sniper",Vector2i(0,0),false);sniper.fire_cooldown=0
	arena.sniper_step(sniper,.01);var hp=arena.player.hp;arena.sniper_step(sniper,1.6)
	var bullet=arena.projectiles.back()
	check(bullet.sniper_round and bullet.speed==15 and arena.player.hp==hp,"sniper emits fast projectile without hitscan damage")
	bullet.position=arena.player.position+Vector3.UP*.8;arena.player.invulnerable=0
	arena.walls[arena.grid_pos(bullet.position)]={"hp":-1,"node":Node3D.new()}
	check(arena.bullet_hit(bullet) and arena.player.hp==hp-1,"sniper projectile hits through cover")
	arena.walls.erase(arena.grid_pos(bullet.position))
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub)
	for tab in range(3):hub.workshop_tab=tab;hub.refresh()
	check(hub.workshop_content.get_child_count()==9,"mobility tab contains three detailed stats")
	hub.open_workshop(true);check(hub.weapon_station.visible and not hub.station.visible and not hub.dpad.enabled,"weapon workbench modal locks controls")
	hub.close_station();check(not hub.weapon_station.visible and hub.dpad.enabled,"closing weapon menu restores controls")
	arena.begin_room(0);arena.phase="combat";arena.wave=2;arena.spawn_queue.clear()
	arena.finish_wave()
	var elites=arena.actors.filter(func(a):return a.elite)
	check(elites.size()==1 and not arena.room_cleared and arena.phase=="combat","room boss appears before flag")
	var elite=elites[0]
	check(elite.max_hp>2 and elite.footprint==1 and is_instance_valid(elite.elite_star),"room boss has ordinary footprint enhanced health and star")
	elite.elite_timer=0;arena.elite_step(elite,.1);var count=arena.projectiles.size();arena.elite_step(elite,1.3)
	check(arena.projectiles.size()==count+3,"room boss adds telegraphed triple attack")
	elite.take_damage(1000);arena.finish_wave()
	check(arena.room_cleared and arena.flag!=null,"boss defeat unlocks flag")
	var path=Game.save_path;Game.save_path="/private/tmp/tank-v05-profile.json";Game.save_enabled=true
	Game.mobility_level=3;Game.recovery_level=4;Game.save_progress();Game.mobility_level=0;Game.recovery_level=0;Game.load_progress()
	check(Game.mobility_level==3 and Game.recovery_level==4,"new stats persist")
	Game.save_enabled=false;Game.save_path=path
	print("V05: %d checks, %d failures" % [checks,failures]);get_tree().quit(1 if failures else 0)
