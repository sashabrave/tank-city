extends Node3D
static var timer_frames:Dictionary={}
var timer_frame=-1
var model:Node3D
var paint_state=""
var arena
var kind = "apc"
var cell = Vector2i.ZERO
var facing = Vector2i.UP
var timer = 5.0
var unstable = true
var boardable = false
var spent = false
var salvaged=false
var vehicle_origin="owned"
var vehicle_zone=1
var armor = 0.0
var max_armor=9.0
var label: Label3D
var health_bar: Sprite3D
var delivery_left=0.0
var delivery_duration=1.0
var canopy: Node3D
var timer_sprite: Sprite3D
## After the blast the vehicle stays as a charred husk: smoking, burning a little, blocking its cell. Shots or a
## blast break it apart (HUSK_HEALTH), then it is gone.
const HUSK_HEALTH=6.0
var husk=false
var husk_hp=HUSK_HEALTH
var husk_clock=0.0
## Enemy crew: a mechanic standing by the wreck repairs it in REPAIR_TIME; the vehicle fights again at 40%.
const REPAIR_TIME=4.0
var mechanic=null
var repair=0.0

func _ready():
	model = Visuals.model(kind,self)
	model.rotation.y = atan2(-float(facing.x),-float(facing.y))
	Visuals.ring(self,Color("d26e49") if unstable else Color("fae79c"),.61)
	label = Visuals.label3d(self,"",Vector3(0,1.85,0),Color("ffe3a1"),34)
	timer_sprite=Sprite3D.new();add_child(timer_sprite);timer_sprite.position=Vector3(0,2.2,0);timer_sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED;timer_sprite.pixel_size=.012
	health_bar=load("res://scripts/health_bar_3d.gd").new();add_child(health_bar);health_bar.position=Vector3(0,1.4,0)
	refresh_label()

func refresh_label():
	var state="explode" if unstable else "capture" if boardable else "friendly"
	if model and state!=paint_state:
		model.set_paint(state);paint_state=state
	if health_bar:
		health_bar.visible=not unstable
		health_bar.set_health(armor,max_armor)
	if label:
		Texts.set_text(label,"▼" if boardable else "")
		label.modulate=Color("83ea77")
	if timer_sprite:
		timer_sprite.visible=unstable
		if unstable:
			var frame=clampi(floori((1-timer/5)*50),0,50)
			if frame==timer_frame:return
			timer_frame=frame
			if not timer_frames.has(frame):
				var img=Image.create(48,48,false,Image.FORMAT_RGBA8);img.fill(Color.TRANSPARENT)
				for y in range(48):
					for x in range(48):
						var d=Vector2(x-24,y-24)
						if d.length()<21 and fposmod(atan2(d.y,d.x)+PI/2,TAU)<TAU*frame/50.0:img.set_pixel(x,y,Color.WHITE)
				timer_frames[frame]=ImageTexture.create_from_image(img)
			timer_sprite.texture=timer_frames[frame]

func _physics_process(delta):
	if spent:return
	if husk:
		husk_clock-=delta
		if husk_clock<=0:husk_clock=randf_range(.7,1.4);arena.burst(position+Vector3(randf_range(-.25,.25),.7,randf_range(-.25,.25)),Color("4a4542"),.32)
		return
	if not unstable and arena.phase!="combat":return
	if mechanic!=null:tick_repair(delta)
	label.position.y=1.85+sin(Time.get_ticks_msec()*.003)*.18
	if delivery_left>0:
		delivery_left=maxf(0,delivery_left-delta);position.y=6*pow(delivery_left/delivery_duration,1.2)
		if delivery_left<=0:boardable=true;canopy.queue_free();refresh_label();Game.sound("delivery_land",self)
	if unstable:
		var previous=timer
		timer -= delta
		if floori(previous/(.25 if timer<2 else .75))!=floori(timer/(.25 if timer<2 else .75)):Game.sound("wreck_warning",self)
		refresh_label()
		if timer <= 0: explode()

var blasting=false
func explode():
	if spent or blasting: return
	if husk:shatter();return
	# Its own blast must not hit the fresh husk again; neighbouring wrecks still catch it.
	blasting=true;become_husk();arena.explosion(position,2);blasting=false

## Charred husk: dark model, two small flames, smoke puffs, no ring, label, timer or boarding.
func become_husk():
	husk=true;unstable=false;boardable=false;husk_hp=HUSK_HEALTH
	for node in [label,timer_sprite,health_bar]:
		if is_instance_valid(node):node.hide()
	for child in get_children():
		if child is MeshInstance3D and child!=model:child.hide()  # the colored ring
	# A dead husk has no headlights: the beams and their soft cones go first, otherwise the charred tint painted
	# the cone into a black wedge across the field (T-085).
	for light in model.find_children("*","Light3D",true,false):light.queue_free()  # cones are their children
	Visuals.tint_model(model,Color("2c2724"))
	for i in range(2):
		var flame=MeshInstance3D.new();var cone=CylinderMesh.new();cone.top_radius=0.0;cone.bottom_radius=.11;cone.height=.3;cone.radial_segments=6;flame.mesh=cone
		flame.material_override=Visuals.material(Color(1,.5,.15),true);flame.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(flame);flame.position=Vector3(-.2+i*.38,.62,.1-i*.2)
		var flicker=flame.create_tween().set_loops();flicker.tween_property(flame,"scale",Vector3(.85,1.3,.85),.18+i*.05);flicker.tween_property(flame,"scale",Vector3(1.05,.8,1.05),.16+i*.04)
	husk_clock=.3

## Breaking the husk: debris burst, a dull crack, the cell is free again.
func shatter():
	spent=true;arena.wrecks.erase(self)
	arena.burst(position+Vector3.UP*.4,Color("3a3532"),.9);Game.sound("debris",arena);Game.sound("explosion_small",arena)
	queue_free()

func take_damage(amount: float):
	if husk:
		husk_hp-=amount;arena.burst(position+Vector3.UP*.5,Color("2f2b29"),.18)
		if husk_hp<=0:shatter()
		return
	if unstable:explode()
	else:
		armor-=amount
		if armor<=0:explode()
		else:refresh_label()

func start_delivery(duration: float):
	boardable=false;delivery_duration=duration;delivery_left=duration;position.y=6
	canopy=Node3D.new();add_child(canopy)
	var dome=MeshInstance3D.new();var mesh=SphereMesh.new();mesh.radius=1.1;mesh.height=2.2;dome.mesh=mesh
	canopy.add_child(dome);dome.position=Vector3(0,2.8,0);dome.scale=Vector3(1,.38,.85);dome.material_override=Visuals.material(Color("d9d7bd"))
	for side in [-1,1]:Visuals.box(canopy,Vector3(side*.6,1.9,0),Vector3(.025,1.8,.025),Color.WHITE)
	refresh_label()

func tick_repair(delta:float):
	if not is_instance_valid(mechanic) or mechanic.dead or husk or not boardable or delivery_left>0:
		mechanic=null;repair=0.0;timer_sprite.visible=false;return
	if arena.flat_distance(mechanic.position,position)>1.2:return
	repair+=delta
	timer_sprite.visible=true;timer_sprite.modulate=Color("ff8a5c")
	var frame=clampi(floori(repair/REPAIR_TIME*50),0,50)
	if frame!=timer_frame:
		timer_frame=frame
		if not timer_frames.has(frame):
			var img=Image.create(48,48,false,Image.FORMAT_RGBA8);img.fill(Color.TRANSPARENT)
			for y in range(48):
				for x in range(48):
					var d=Vector2(x-24,y-24)
					if d.length()<21 and fposmod(atan2(d.y,d.x)+PI/2,TAU)<TAU*frame/50.0:img.set_pixel(x,y,Color.WHITE)
			timer_frames[frame]=ImageTexture.create_from_image(img)
		timer_sprite.texture=timer_frames[frame]
	if repair>=REPAIR_TIME:revive()

## The mechanic finished: he climbs in and the vehicle rejoins the fight with 40% armour.
func revive():
	spent=true;arena.wrecks.erase(self)
	var vehicle=arena.spawn_actor(kind,cell,false)
	vehicle.hp=maxf(1.0,vehicle.max_hp*.4);vehicle.refresh_health();vehicle.position=position
	if is_instance_valid(mechanic):mechanic.dead=true;arena.room.actors.erase(mechanic);mechanic.queue_free()
	arena.burst(position+Vector3.UP*.5,Color("ffb04a"),.5);Game.sound("engine_start",vehicle);arena.toast("Механик починил технику")
	queue_free()
