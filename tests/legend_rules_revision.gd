extends Node3D
## Legendary rules: only from the captured command post (never ordinary offers), one per world route, and each
## of the eight rules does its job. No profile or settings writes.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func enemy(arena,kind:String,cell:Vector2i,hp:=20.0):
	var a=arena.spawn_actor(kind,cell,false);a.set_physics_process(false);a.hp=hp;a.max_hp=hp;return a
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades();Campaign.configure(1)
	var ids=preload("res://scripts/legend_stop.gd").legendary_ids()
	check(ids.size()==8,"eight legendary rules")
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=11;add_child(arena);arena.auto_pause_enabled=false
	await get_tree().process_frame;arena.set_physics_process(false);arena.phase="combat"
	check(not ids.any(func(id):return RunUpgrades.eligible(arena,UpgradeRegistry.get_def(id))),"legends never appear in ordinary offers")
	var plans=0
	for seed_value in range(20):
		var plan=RoutePlan.build(seed_value);var posts=0
		for stage in plan:
			for node in stage:if node.type=="command_post":posts+=1
		if posts==1:plans+=1
	check(plans==20,"every world 1 route has one captured command post")
	var g=Vector2i(arena.grid_size/2,4)
	# Fury
	RunUpgrades.apply(arena,"legend_fury",3);for i in 4:arena.effects.emit("kill",{"actor":null})
	check(is_equal_approx(arena.effects.modify("shot_damage",1.0),1.2),"fury: +5% per kill")
	# Second wind
	RunUpgrades.apply(arena,"legend_second_wind",3);var hero=arena.player;hero.hp=1.0;hero.invulnerable=0
	hero.take_damage(5.0);check(not hero.dead and is_equal_approx(hero.hp,1.0),"second wind saves a lethal hit once per field")
	# Detonator
	RunUpgrades.apply(arena,"legend_detonator",3);var a=enemy(arena,"soldier",g);var b=enemy(arena,"soldier",g+Vector2i(1,0));b.position=a.position+Vector3(.6,0,0)
	arena.effects.emit("kill",{"actor":a});check(b.hp<20.0,"detonator hurts neighbours")
	# Ricochet
	RunUpgrades.apply(arena,"legend_ricochet",3);var c=enemy(arena,"soldier",g+Vector2i(0,2));var hp_c=c.hp
	for i in 3:arena.effects.emit("enemy_hit",{"target":a,"damage":5.0})
	check(c.hp<hp_c or b.hp<20.0-1.5,"every third hit ricochets")
	# Vehicle rules
	var tank=arena.spawn_actor("tank",g+Vector2i(3,3),true);tank.set_physics_process(false);arena.room.player=tank
	RunUpgrades.apply(arena,"legend_iron_will",3);arena.effects.emit("vehicle_shot",{"actor":tank})
	check(is_equal_approx(arena.effects.modify("incoming_damage",10.0,{"actor":tank}),3.0),"iron will: −70% while firing")
	RunUpgrades.apply(arena,"legend_field_workshop",3);tank.hp=tank.max_hp-2;var before=tank.hp
	for i in 4:arena.effects.emit("tick",{"delta":1.0})
	check(tank.hp>before,"workshop on wheels repairs armour")
	RunUpgrades.apply(arena,"legend_volley",3);var shells=[0]
	arena.child_entered_tree.connect(func(n):if n.get("friendly")==true:shells[0]+=1)
	arena.effects.emit("vehicle_shot",{"actor":tank});check(shells[0]==2,"volley adds two shells")
	RunUpgrades.apply(arena,"legend_ram",3);var victim=enemy(arena,"soldier",tank.cell);victim.position=tank.position;tank.moving=true
	arena.effects.emit("tick",{"delta":.016});check(victim.hp<=0 or victim.dead,"ram crushes infantry")
	print("LEGEND RULES: %d failures" % failures);get_tree().quit(1 if failures else 0)
