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
var pierce_left=0
var opening=false
var piercing=false
var star_power=false
var rocket_radius=0.0
const SNIPER_HEIGHT=1.45
var sniper_round=false
var hit_base=false
var sniper_visual=false
var flyer_round=false
var hit_actors: Array=[]
var blink_halo:Node3D
var grove_cell:=Vector2i(-99,-99)

func _ready():
	if is_instance_valid(owner_actor) and owner_actor.has_method("pressure"):pressure=owner_actor.pressure()
	rotation.y = atan2(-travel_direction.x,-travel_direction.z)
	# Callers set rocket/orb/sniper fields right after add_child; build once they are known.
	build_visual.call_deferred()
func build_visual():
	if not is_inside_tree():return
	var color=Color("ffcf79") if friendly else Color("ff5c40")
	if star_power:color=Color("fff0a0")
	var kind="bullet"
	if rocket_radius>0:kind="rocket";color=Color("ffb45a") if friendly else Color("ff7440")
	elif sniper_round or sniper_visual:kind="sniper";color=Color("ff263f")
	elif orb:kind="orb";color=Color("ff8e40")
	elif piercing or (is_instance_valid(owner_actor) and owner_actor.kind in ["tank","boss","apc","mortar"]):kind="shell"
	var visual=EffectLighting.projectile_visual(self,kind,color)
	# Enemy rounds flicker so they read as danger among friendly tracers.
	if not friendly and visual.get_child_count()>1:blink_halo=visual.get_child(1)
	if kind in ["sniper","orb","rocket"]:EffectLighting.projectile_light(self,color)
func _physics_process(delta):
	if spent or not is_instance_valid(arena) or arena.phase not in ["combat","countdown"]: return
	if rocket_radius>0:Game.sound_loop("rocket_flight",self)
	if is_instance_valid(blink_halo):blink_halo.visible=fposmod(Time.get_ticks_msec()*.011+position.x,1.0)<.6
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
	rustle_grove()

## Bullets fly through groves; the tree they cross gives a shiver and a few twigs (visual only).
func rustle_grove():
	# The hub range has no grid or groves.
	if not arena.has_method("grid_pos") or arena.get("terrain")==null:return
	var cell=arena.grid_pos(position)
	if cell==grove_cell:return
	grove_cell=cell
	var grove=arena.terrain.vegetation.get(cell)
	if is_instance_valid(grove):preload("res://scripts/vegetation_visual.gd").rustle(grove,travel_direction)

func consume():
	if spent:return
	spent=true
	if is_instance_valid(arena):arena.projectiles.erase(self)
	queue_free()

func _exit_tree():
	if is_instance_valid(arena):arena.projectiles.erase(self)
