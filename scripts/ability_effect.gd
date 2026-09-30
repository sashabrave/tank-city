extends Node3D
var arena
var kind="gas"
var power=5.0
var utility=0.0
var age=0.0
var shot=0.0
var fired=0
var visual:Node3D
func _ready():
	visual=Node3D.new();add_child(visual)
	if kind=="gas":
		for i in range(5):
			var puff=Visuals.box(visual,Vector3(sin(i*2.4),.25,cos(i*2.4))*(1+utility*.2),Vector3(1.6,.18,1.6),Color("9cba87"));puff.rotation.y=i
	elif kind=="mine":
		Visuals.box(visual,Vector3(0,.08,0),Vector3(.55,.16,.55),Color("8d9855"));Visuals.ring(visual,Color("f1cb63"),.35)
	else:
		Visuals.box(visual,Vector3.ZERO,Vector3(.8,.65,1.6),Color("6f8a75"))
		Visuals.box(visual,Vector3(0,.2,-.65),Vector3(.65,.45,.45),Color("9cbfc1"))
		Visuals.box(visual,Vector3(0,0,1.5),Vector3(.15,.2,1.8),Color("6f8a75"))
		Visuals.box(visual,Vector3(0,.3,2.2),Vector3(.1,.8,.4),Color("6f8a75"))
		var rotor=Visuals.box(visual,Vector3(0,.55,0),Vector3(3.5,.06,.14),Color("424d48"));rotor.name="Rotor"
		visual.position=Vector3(-arena.grid_size*.5,4,0)
func _physics_process(delta):
	if arena.phase not in ["combat","countdown"]:return
	age+=delta
	if kind=="gas":Game.sound_loop("gas_loop",self)
	elif kind=="airstrike":Game.sound_loop("helicopter_rotor",self)
	elif age>=2 and age-delta<2:Game.sound("mine_arm",self)
	if kind=="gas":
		visual.rotation.y+=delta*.05
		for enemy in arena.actors:
			if is_instance_valid(enemy) and not enemy.player_owned and not enemy.allied and enemy.kind in ["soldier","grenadier","sniper","shield"] and arena.flat_distance(position,enemy.position)<1.5+utility*.35:enemy.stun_time=maxf(enemy.stun_time,.2)
		if age>=power:queue_free()
	elif kind=="mine":
		if age<2:return
		for actor in arena.actors:
			if is_instance_valid(actor) and not actor.dead and not actor.allied and arena.flat_distance(position,actor.position)<.6:detonate();return
	else:
		visual.position.x+=delta*3;visual.get_node("Rotor").rotation.y+=delta*22
		shot-=delta
		if shot<=0:
			shot=.3;fired+=1
			var enemies=arena.actors.filter(func(a):return is_instance_valid(a) and not a.dead and not a.player_owned and not a.allied)
			if not enemies.is_empty():
				Game.sound("fire_vehicle_mg",self)
				var target=enemies[fired%enemies.size()]
				var line=Visuals.box(arena,(global_position+visual.position+target.position)*.5,Vector3(.05,(global_position+visual.position).distance_to(target.position),.05),Color("ffdb8f"));line.look_at(target.position);line.rotate_object_local(Vector3.RIGHT,PI/2)
				arena.create_tween().tween_property(line,"scale",Vector3.ZERO,.15).finished.connect(line.queue_free)
				if utility>=3 and fired%4==0:arena.grenade_explosion(target.position,power*2,true,2)
				else:target.take_damage(power)
		if age>6+utility:queue_free()
func detonate():
	var origin=arena.grid_pos(position);var cells=[origin]
	for dir in arena.DIRS:
		for i in range(1,3+int(utility)):
			var cell=origin+dir*i
			if not arena.inside(cell):break
			cells.append(cell)
			if arena.walls.has(cell):arena.damage_wall(cell,power);break
	for cell in cells:
		arena.burst(arena.world_pos(cell),Color("ffc96b"),.4)
		for actor in arena.actors.duplicate():
			if is_instance_valid(actor) and not actor.dead and arena.grid_pos(actor.position)==cell:actor.take_damage(power)
	Game.sound("boom",arena);queue_free()
