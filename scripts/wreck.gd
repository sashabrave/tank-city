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
	if not unstable and arena.phase!="combat":return
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

func explode():
	if spent: return
	spent = true
	arena.wrecks.erase(self)
	arena.explosion(position,2)
	queue_free()

func take_damage(amount: float):
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
