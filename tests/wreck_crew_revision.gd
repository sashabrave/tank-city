extends Node3D
## Knocked-out enemy vehicles: the crew bails out (pistol dogs, 1 HP), the mechanic repairs the wreck back into a
## fighting vehicle unless shot; a blown-up vehicle stays as a burning husk until shot apart. No profile writes.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=8;add_child(arena);arena.auto_pause_enabled=false
	await get_tree().process_frame;arena.set_physics_process(false);arena.phase="combat"
	var tank=arena.spawn_actor("tank",Vector2i(arena.grid_size/2,3),false);tank.set_physics_process(false)
	var before=arena.room.actors.size()
	tank.dead=true;arena.combat.actor_destroyed(tank)
	var wreck=arena.room.wrecks.back()
	var crew=arena.room.actors.filter(func(a):return is_instance_valid(a) and a.has_meta("crew"))
	check(crew.size()==2 and crew.all(func(a):return a.max_hp==1.0 and a.enemy_weapon=="pistol"),"tank crew: two pistol dogs with 1 HP")
	check(wreck.mechanic!=null and wreck.mechanic.has_meta("mechanic"),"the first crew member is the mechanic")
	for c in crew:c.set_physics_process(false)
	wreck.mechanic.position=wreck.position+Vector3(.6,0,0)
	for i in range(int(4.1/0.05)):wreck._physics_process(.05)
	var revived=arena.room.actors.filter(func(a):return is_instance_valid(a) and not a.dead and a.kind=="tank")
	check(revived.size()==1 and revived[0].hp<revived[0].max_hp and not is_instance_valid(wreck) or wreck.spent,"an unshot mechanic repairs the tank back into the fight")
	# A blown-up wreck becomes a husk that stays until shot apart.
	var husk=arena.make_wreck("apc",Vector2i(2,4),Vector2i.UP,true)
	husk.explode()
	check(husk in arena.room.wrecks and husk.husk and not husk.boardable,"blown-up vehicle stays as a charred husk")
	await get_tree().process_frame
	check(husk.model.find_children("*","Light3D",true,false).is_empty() and husk.model.find_children("SoftCone","MeshInstance3D",true,false).is_empty(),"husk has no headlights or light cones (T-085)")
	husk.take_damage(3.0);check(is_instance_valid(husk) and not husk.spent,"the husk takes a few hits")
	husk.take_damage(3.0);check(husk.spent and husk not in arena.room.wrecks,"enough hits break it apart")
	print("WRECK CREW: %d failures" % failures);get_tree().quit(1 if failures else 0)
