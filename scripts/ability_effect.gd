extends Node3D
var arena
var kind="gas"
var power=5.0
var utility=0.0
var age=0.0
var shot=0.0
var fired=0
var visual:Node3D
var lamp:Node3D
func _ready():
	visual=Node3D.new();add_child(visual)
	if kind=="gas":
		visual.add_child(preload("res://scripts/gas_cloud.gd").new(1.5+utility*.35,int(position.x*31+position.z*17)))
	elif kind=="mine":
		# Round anti-tank mine (T-295, the arsenal icon): olive disc, ribbed rim, pressure cap and a red lamp that
		# blinks slowly while arming and fast once armed. The yellow ring marks the player's own mine.
		var ordnance=preload("res://scripts/ordnance.gd")
		ordnance.part(visual,"cylinder",Vector3(0,.06,0),Vector3(.5,.12,.5),Color("7a8150"))
		ordnance.part(visual,"cylinder",Vector3(0,.075,0),Vector3(.54,.035,.54),Color("62683f"))
		ordnance.part(visual,"cylinder",Vector3(0,.135,0),Vector3(.3,.035,.3),Color("8f9760"))
		ordnance.part(visual,"cylinder",Vector3(0,.165,0),Vector3(.13,.03,.13),Color("3b3f36"))
		for i in range(6):ordnance.part(visual,"box",Vector3(cos(i*TAU/6)*.215,.135,sin(i*TAU/6)*.215),Vector3(.05,.02,.03),Color("4a4f33"),Vector3(0,-i*TAU/6,0))
		lamp=ordnance.blink(visual,Vector3(.1,.19,-.1),2.0,.055);lamp.name="MineLamp"
		Visuals.ring(visual,Color("f1cb63"),.35)
	elif kind=="dynamite":
		# Three red sticks taped together with a sparking fuse.
		for i in range(3):Visuals.box(visual,Vector3((i-1)*.11,.09,0),Vector3(.1,.18,.42),Color("c8402f"))
		Visuals.box(visual,Vector3(0,.09,0),Vector3(.36,.19,.06),Color("2a2a28"))
		var spark=Visuals.box(visual,Vector3(0,.32,-.18),Vector3(.07,.07,.07),Color("ffd36a"));spark.name="Spark";spark.material_override=Visuals.material(Color("ffd36a"),true)
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
	elif kind!="dynamite" and age>=2 and age-delta<2:Game.sound("mine_arm",self)
	if kind=="gas":
		# Sleeping infantry: held like a stun, shown with «Z z z» instead of stars.
		for enemy in arena.actors:
			if is_instance_valid(enemy) and not enemy.player_owned and not enemy.allied and UnitKinds.is_infantry(enemy.kind) and arena.flat_distance(position,enemy.position)<1.5+utility*.35:
				enemy.stun_time=maxf(enemy.stun_time,.2);enemy.sleep_time=maxf(enemy.sleep_time,.2)
		if age>=power:
			# The cloud thins out on its own; the effect ends now.
			var cloud=visual.get_node_or_null("GasCloud")
			if cloud:visual.remove_child(cloud);arena.add_child(cloud);cloud.position=position;cloud.fade_out()
			queue_free()
	elif kind=="dynamite":
		var spark=visual.get_node_or_null("Spark")
		if spark:spark.scale=Vector3.ONE*(1.0+.6*absf(sin(age*24.0)));spark.position.y=.32-.18*minf(1.0,age/FUSE)
		if age>=FUSE:blast();return
	elif kind=="mine":
		if is_instance_valid(lamp):lamp.blink_rate=2.0 if age<2 else 5.0
		if age<2:return
		# Enemies set it off by stepping on it; the hero and allies walk over their own mine (T-295: the hero blows
		# it with the gadget key instead).
		for actor in arena.actors:
			if is_instance_valid(actor) and not actor.dead and not actor.allied and not actor.player_owned and arena.flat_distance(position,actor.position)<.6:detonate();return
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
const FUSE=1.5
## Dynamite: a cross along both axes. Every destructible block on a line takes the full blast (bricks and
## barrels break through), the line stops at indestructible concrete or the field edge. Enemies on the
## lines are hit; the soldier is not. Range 2 + utility (max 6).
func blast():
	var origin=arena.grid_pos(position);var cells=[origin];var reach=mini(6,2+int(utility))
	for dir in arena.DIRS:
		for i in range(1,reach+1):
			var cell=origin+dir*i
			if not arena.inside(cell):break
			if arena.walls.has(cell) and float(arena.walls[cell].get("hp",0))<0:break
			cells.append(cell)
			if arena.walls.has(cell):arena.damage_wall(cell,power*3.0)
	for cell in cells:
		arena.burst(arena.world_pos(cell),Color("ffb04a"),.5)
		for actor in arena.actors.duplicate():
			if is_instance_valid(actor) and not actor.dead and not actor.player_owned and not actor.allied and arena.grid_pos(actor.position)==cell:actor.take_damage(power)
	Game.sound("explosion_heavy",arena);queue_free()
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
			# T-165 rule for explosives: the hero and allies caught in the cross take a small bite, enemies the mine.
			if is_instance_valid(actor) and not actor.dead and arena.grid_pos(actor.position)==cell:actor.take_damage(1.0 if actor.player_owned or actor.allied else power,Vector3.ZERO,"","blast" if actor.player_owned or actor.allied else "")
	Game.sound("boom",arena);queue_free()
