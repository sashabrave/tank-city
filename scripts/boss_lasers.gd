extends Node3D
var arena
var boss
var age=0.0
var tick=0.0
var count=4
var rays:Array=[]
func _ready():
	Game.sound("boss_laser_charge",self)
	count=4+arena.combat_rng.randi_range(0,2)
	for i in range(count):
		var pivot=Node3D.new();add_child(pivot);pivot.rotation.y=TAU*i/count
		var beam=Visuals.box(pivot,Vector3(0,.35,-arena.grid_size*.5),Vector3(.07,.06,arena.grid_size),Color("e7ad8d"));rays.append(beam)
	arena.toast("Лазеры: уйди между лучами!")
func _physics_process(delta):
	if not is_instance_valid(boss) or boss.dead:queue_free();return
	if arena.phase!="combat":return
	position=boss.position;age+=delta;tick-=delta
	if age>1.6:
		Game.sound_loop("boss_laser_loop",self)
		rotation.y+=delta*.18
		for ray in rays:ray.scale.x=4;ray.material_override=Visuals.material(Color("ff6f51"),true)
		if tick<=0:
			tick=.5
			for actor in arena.actors.duplicate():
				if not is_instance_valid(actor) or actor.dead or not (actor.player_owned or actor.allied):continue
				var diff=actor.position-position
				for i in range(count):
					var direction=Vector3(0,0,-1).rotated(Vector3.UP,rotation.y+TAU*i/count)
					if diff.dot(direction)>0 and absf(diff.cross(direction).y)<.4:actor.take_damage(2);break
	if age>2.8:queue_free()
