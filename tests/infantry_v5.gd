extends Node3D
var checks=0
var failures=0
var arena
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures+=1;push_error(message)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Game.reset_upgrades()
	for kind in ["soldier","grenadier","shield","sniper","rpg_soldier"]:
		var model=Visuals.model(kind,self);model.set_process(false)
		var bounds=Visuals.mesh_bounds(model,Transform3D.IDENTITY)
		print("MODEL ",kind," bounds=",bounds.size," clips=",model.player.get_animation_list())
		check(absf(bounds.size.y-.936)<.03,"0.936-cell height "+kind)
		check(model.skeleton.get_bone_count()==17,"shared 17 bone rig "+kind)
		for clip in ["hero_idle","hero_walk","hero_fire"]:check(model.player.has_animation(clip),"clip "+kind+" "+clip)
		for weapon in (["pistol","smg","rifle","shotgun","sniper","rpg","mg","grenade_launcher"] if kind=="soldier" else [EnemyLoadouts.default_for("grenadier" if kind=="rpg_soldier" else kind)]):
			model.equip_weapon(weapon);model.preview_moving=true
			await get_tree().process_frame
			model._process(.1)
			check(model.weapon_id==weapon and model.muzzle!=null,"equipped "+kind+" "+weapon)
			var hand=model.skeleton.find_bone("hand.R");var grip=model.skeleton.find_bone("weapon")
			check(model.skeleton.get_bone_global_pose(hand).origin.distance_to(model.skeleton.get_bone_global_pose(grip).origin)<.001,"trigger grip at right hand")
			if kind!="shield":
				var left=model.skeleton.get_bone_global_pose(model.skeleton.find_bone("hand.L")).origin
				var target=model.skeleton.to_local(model.support_grip.global_position)
				print("FIT ",kind," ",weapon," ",left.distance_to(target))
				check(left.distance_to(target)<.035,"support grip "+kind+" "+weapon)
		model.free()
	var weapons_seen={};var rpg_count=0
	for seed_value in range(100):
		for room in range(17):
			for wave in range(3):
				var entries=WaveDirector.build(seed_value,room,wave)
				check(entries==WaveDirector.build(seed_value,room,wave),"deterministic wave")
				if room<12:
					var old=preload("res://tests/fixtures/wave_director_before_infantry_v5.gd").build(seed_value,room,wave)
					check(entries.map(func(e):return [e.kind,e.rank])==old.map(func(e):return [e.kind,e.rank]),"early wave population and ranks unchanged")
				var rockets=entries.filter(func(e):return e.get("weapon","")=="rpg")
				check(rockets.size()<=1,"one RPG maximum")
				if room<12 or room in Campaign.BOSSES:check(rockets.is_empty(),"no early/boss RPG")
				elif (room+wave)%2==0:
					check(rockets.size()==1,"scheduled RPG wave")
					check(not entries.any(func(e):return (e.kind=="grenadier" and e.get("weapon","")!="rpg") or e.kind=="mortar"),"explosives separated")
					rpg_count+=rockets.size()
				if room not in Campaign.BOSSES:
					var budget=WaveDirector.BUDGETS[mini(room,5)][wave]+(Balance.CONFIG.campaign.zone_two_budget_bonus if room>=7 else 0)
					var cost=0
					for entry in entries:
						cost+=WaveDirector.rank_cost(entry.kind,entry.rank)
						if entry.kind=="soldier":weapons_seen[entry.weapon]=true
					check(cost<=budget+2,"wave keeps budget including optional extra soldier")
	check(weapons_seen.size()==4,"all four basic weapons distributed")
	print("WAVES 5100; RPG waves ",rpg_count,"; basic weapons ",weapons_seen.keys())
	arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false);arena.begin_room(0);arena.phase="combat"
	for actor in arena.actors:actor.set_physics_process(false)
	for weapon in EnemyLoadouts.BASIC:
		var actor=arena.spawn_actor("soldier",Vector2i(1,1),false,false,1,false,weapon);actor.set_physics_process(false)
		actor.fire_cooldown=0;actor.turn_left=0
		var before=arena.projectiles.size();check(actor.shoot(),"start "+weapon)
		for tick in range(30):EnemyLoadouts.tick(actor,.02)
		var rounds=arena.projectiles.slice(before);var damage=0.0
		for bullet in rounds:damage+=bullet.damage;bullet.set_physics_process(false)
		var data=EnemyLoadouts.profile(weapon)
		check(rounds.size()==data.shots*data.pellets,"correct volley "+weapon)
		# Exercise real hit handling, including the player's invulnerability window.
		arena.abilities.shield_hits=0;arena.player.invulnerable=0
		arena.player.hp=100;arena.player.max_hp=100
		arena.player.position=arena.world_pos(Vector2i(5,5));arena.player.cell=Vector2i(5,5)
		if arena.walls.has(arena.player.cell):arena.walls[arena.player.cell].node.queue_free();arena.walls.erase(arena.player.cell)
		for bullet in rounds:
			bullet.position=arena.player.position;arena.bullet_hit(bullet)
		check(is_equal_approx(100-arena.player.hp,actor.damage),"same effective damage per volley "+weapon)
		check(is_equal_approx(actor.fire_cooldown,1.45),"same cadence "+weapon)
		for bullet in rounds:check(is_equal_approx(bullet.lifetime*bullet.speed,data.range),"range "+weapon)
		print("PATTERN ",weapon," rounds=",rounds.size()," effective_damage=",100-arena.player.hp," interval=",actor.fire_cooldown)
		arena.actors.erase(actor);actor.free()
	var shield=arena.spawn_actor("shield",Vector2i(2,2),false);shield.set_physics_process(false)
	check(shield.enemy_weapon=="shotgun" and shield.model.weapon_id=="shotgun","shield shotgun visual and logic")
	check(shield.shield_visual!=null,"authored shield pivot")
	shield.shield_phase="active";shield.fire_cooldown=0;check(not shield.shoot(),"shield cannot fire while blocking")
	var rocket=arena.spawn_actor("grenadier",Vector2i(3,3),false,false,1,false,"rpg");rocket.set_physics_process(false);rocket.fire_cooldown=0
	check(rocket.model.kind=="rpg_soldier" and rocket.model.weapon_id=="rpg","RPG specialist model")
	arena.player.position=rocket.position+Vector3(0,0,2);arena.player.cell=arena.grid_pos(arena.player.position)
	for cell in arena.walls.keys():arena.walls[cell].node.queue_free()
	arena.walls.clear()
	var before=arena.projectiles.size();check(arena.enemy.rpg_step(rocket,.01),"RPG warning begins");check(arena.projectiles.size()==before,"no instant rocket")
	var locked=rocket.rocket_target;arena.player.position.x+=1;arena.enemy.rpg_step(rocket,.4)
	check(rocket.rocket_target==locked,"RPG aim locks during warning")
	arena.enemy.rpg_step(rocket,.5);check(arena.projectiles.size()==before+1,"one rocket after warning")
	var bullet=arena.projectiles.back();bullet.set_physics_process(false)
	check(bullet.rocket_radius==.8 and bullet.speed==4.5 and rocket.fire_cooldown==4.8,"gentle RPG tuning")
	arena.player.invulnerable=0;arena.abilities.shield_hits=0;var hp=arena.player.hp;var enemy_hp=rocket.hp
	bullet.position=arena.player.position;arena.combat.rocket_impact(bullet)
	check(arena.player.hp<hp and rocket.hp==enemy_hp,"hostile rocket damages only opposing side")
	rocket.hp=100;arena.player.hp=100;arena.player.invulnerable=0;rocket.invulnerable=0
	bullet.friendly=true;bullet.owner_actor=arena.player;bullet.position=rocket.position
	arena.combat.rocket_impact(bullet)
	check(rocket.hp<100 and arena.player.hp==100,"player rocket still damages enemies only")
	arena.free()
	print("INFANTRY V5: ",checks," checks; ",failures," failures");get_tree().quit(failures)
