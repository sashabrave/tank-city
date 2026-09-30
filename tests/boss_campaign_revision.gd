extends Node
var errors=0
func check(value:bool,message:String):
	if not value:errors+=1;push_error(message)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	for world in [1,2,3]:
		Campaign.configure(world)
		for index in range(6):
			for seed_value in range(8):
				var rows=BattleMapGenerator.generate(seed_value,index).rows
				check(BattleMapGenerator.validate(rows),"Connected map")
				if world>=2:
					var cover=0;var width=rows.size()
					for y in range(int(width*.25),int(width*.75)):
						for x in range(int(width*.25),int(width*.75)):
							if rows[y][x] in ["B","C"]:cover+=1
					check(cover>=8,"Center cover: world %d field %d seed %d = %d" % [world,index,seed_value,cover])
		var variants={}
		for seed_value in range(3):variants[BossCatalog.encounter(seed_value,6).id]=true
		check(variants.size()==3,"Three boss variants in each world")
	Campaign.configure(3)
	check(Campaign.BOSSES==[6,7] and 7 in Campaign.SERVICES and not Campaign.is_final(6) and Campaign.is_final(7),"General, choice of service, then gigaboss")
	check(Campaign.service_options(42,7).size()==2,"Two final preparation options")
	var arena=load("res://scenes/arena.tscn").instantiate();arena.auto_pause_enabled=false;add_child(arena);arena.set_physics_process(false);arena.begin_room(7);arena.phase="combat"
	for actor in arena.actors:actor.set_physics_process(false)
	arena.spawn_queue.clear();var boss=arena.spawn_actor("boss",Vector2i(15,1),false);boss.set_physics_process(false)
	check(not arena.boss.shield_active() and arena.generators.size()==4,"Starts vulnerable, four dormant generators")
	for i in range(4):
		boss.take_damage(99999)
		check(is_equal_approx(boss.hp,boss.max_hp*[.8,.6,.4,.2][i]),"Damage clamped to phase threshold")
		check(arena.boss.shield_active(),"One active shield")
		var active=arena.generators.keys().filter(func(cell):return arena.generators[cell].active)
		check(active.size()==1,"Only one active generator")
		var hp=boss.hp;boss.take_damage(999);check(boss.hp==hp,"Shield blocks damage")
		for cell in arena.generators.keys():
			if cell!=active[0]:arena.damage_generator(cell,999);check(arena.generators.has(cell),"Dormant generator cannot be skipped")
		arena.damage_generator(active[0],999);check(not arena.boss.shield_active(),"Generator destruction removes shield immediately")
		for actor in arena.actors:actor.set_physics_process(false)
	check(arena.actors.filter(func(a):return a.get_meta("generator_guard",false)).size()==8,"Two defenders per active position")
	boss.take_damage(99999);check(boss.dead,"Final HP can be depleted after four phases")
	arena.queue_free();await get_tree().process_frame
	print("BOSS/CAMPAIGN/MAPS failures: ",errors);get_tree().quit(1 if errors else 0)
