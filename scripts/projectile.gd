extends Node3D
var wall_width=.5
var vehicle_credit=""
var arena
var owner_actor
var direction = Vector2i.UP
var travel_direction=Vector3.FORWARD
var orb=false
var friendly = false
# Keep attribution even after the firing vehicle is destroyed or abandoned.
var player_shot = false
var pressure=1.0
var damage = 1.0
var speed = 10.5
var lifetime = 2.5
var spent = false
var piercing=false
var star_power=false
var rocket_radius=0.0
const SNIPER_HEIGHT=1.45
var sniper_round=false
var hit_base=false
var sniper_visual=false
var flyer_round=false
var hit_actors: Array=[]

func _ready():
	if is_instance_valid(owner_actor) and owner_actor.has_method("pressure"):pressure=owner_actor.pressure()
	var color=Color("ffcf79") if friendly else Color("ff5c40")
	if sniper_round or sniper_visual:
		color=Color("ff263f");EffectLighting.tracer(self,color,Vector3(.045,.045,.28))
	elif orb:
		var visual=MeshInstance3D.new();var sphere=SphereMesh.new();sphere.radius=.16;sphere.height=.32;visual.mesh=sphere
		color=Color("ff8e40");visual.material_override=EffectLighting.glow(color);add_child(visual)
	else:EffectLighting.tracer(self,color,Vector3(.09,.09,.28))
	if sniper_round or sniper_visual or orb:EffectLighting.projectile_light(self,color)
	rotation.y = atan2(-travel_direction.x,-travel_direction.z)

func _physics_process(delta):
	if spent or not is_instance_valid(arena) or arena.phase != "combat": return
	if rocket_radius>0:Game.sound_loop("rocket_flight",self)
	lifetime -= delta
	if lifetime <= 0: consume(); return
	# Sweep with short substeps so a fast bullet cannot skip a wall or actor.
	var distance = speed*delta
	var steps = maxi(1,ceili(distance/.10))
	var step = travel_direction*distance/steps
	for i in range(steps):
		position += step
		if arena.bullet_hit(self):
			consume()
			return

func consume():
	if spent:return
	spent=true
	if is_instance_valid(arena):arena.projectiles.erase(self)
	queue_free()

func _exit_tree():
	if is_instance_valid(arena):arena.projectiles.erase(self)
