extends Node3D
## The hub as a hangar inside a living camp. Visual only: its own RNG, nothing here touches gameplay.
## Hangar steel (columns, trusses, hanging lamps, storage racks), biome vegetation and cargo outside,
## and random background scenes on the road in front: convoys and patrols (the range side stays calm).
const ROAD_Z=6.6
const GROUND_Y=-.72
const WIND=preload("res://assets/shaders/vegetation_wind.gdshader")
var hub
var rng:=RandomNumberGenerator.new()
var next_scene=2.5
var busy=0
var convoy_on_road=false

func _ready():
	name="HubOutskirts"
	rng.seed=hash([Game.visual_run_seed,hub.index,"outskirts"])
	var biome:Dictionary=hub.room_palette()
	hangar()
	backwall()
	racks()
	road()
	vegetation(biome)
	cargo()
	landscape(biome)

## Bare structural steel (library surface «steel»), light enough to read as metal without bright reflections.
func steel()->Color:return Color("848b90")

func hangar():
	var frame=Node3D.new();frame.name="HangarFrame";add_child(frame)
	for x in [-5.8,7.8]:
		for z in [-3.4,.6,4.4]:
			Visuals.box(frame,Vector3(x,1.7,z),Vector3(.22,3.6,.22),steel(),"steel")
			Visuals.box(frame,Vector3(x,.06,z),Vector3(.5,.12,.5),steel().darkened(.2),"steel")
		Visuals.box(frame,Vector3(x,3.45,.5),Vector3(.2,.2,7.9),steel(),"steel")
	# Trusses only over the back half, so they never cover the playable floor from this camera.
	for z in [-3.4,-1.0]:
		Visuals.box(frame,Vector3(1,3.6,z),Vector3(13.8,.14,.14),steel(),"steel")
		Visuals.box(frame,Vector3(1,3.1,z),Vector3(13.8,.1,.1),steel(),"steel")
		for i in range(12):
			var brace=Visuals.box(frame,Vector3(-4.9+i*1.15,3.35,z),Vector3(.06,.6,.06),steel(),"steel");brace.rotation.z=.6 if i%2 else -.6
		for x in [-2.5,1.0,4.5]:
			Visuals.box(frame,Vector3(x,2.9,z),Vector3(.04,.4,.04),steel().darkened(.3),"steel")
			var lamp=Visuals.box(frame,Vector3(x,2.68,z),Vector3(.5,.08,.2),Color("ffe7b0"));lamp.material_override=Visuals.material(Color("ffe7b0"),true)

## Back wall over the lockers: pipes with gauges, a cable tray, stepped vent fans, a tool board,
## a breaker cabinet with blinking lights, hazard stripes and an engine on a chain hoist. All above
## head height or outside the walkable cells.
func backwall():
	var wall=Node3D.new();wall.name="BackWall";add_child(wall)
	var z=-3.25;var pipe=Color("7b6f5a");var olive=Color("59603f");var anim=preload("res://scripts/diorama_animator.gd").new();wall.add_child(anim)
	for y in [2.05,2.3]:
		var run=MeshInstance3D.new();var mesh=CylinderMesh.new();mesh.top_radius=.06;mesh.bottom_radius=.06;mesh.height=12.6;run.mesh=mesh
		run.rotation.z=PI*.5;run.position=Vector3(1,y,z);run.material_override=Visuals.surface_material(pipe,"paint") if y<2.2 else Visuals.surface_material(steel(),"steel");wall.add_child(run)
	for x in [-3.6,.4,4.2]:
		var gauge=MeshInstance3D.new();var disc=CylinderMesh.new();disc.top_radius=.13;disc.bottom_radius=.13;disc.height=.05;gauge.mesh=disc
		gauge.rotation.x=PI*.5;gauge.position=Vector3(x,2.05,z+.1);gauge.material_override=Visuals.material(Color("e8e2d0"));wall.add_child(gauge)
		var needle=Visuals.box(wall,Vector3(x,2.07,z+.14),Vector3(.02,.1,.01),Color("cf613f"));anim.add(needle,"rotation:z",[-.5,.2,-.1,.4])
	Visuals.box(wall,Vector3(1,2.62,z+.05),Vector3(12.6,.06,.3),Color("4a4f4c"))
	for i in range(10):Visuals.box(wall,Vector3(-4.6+i*1.25,2.66,z+.05),Vector3(.5,.04,.2),Color("2d3130"))
	for x in [-1.8,2.6,6.2]:
		var fan=Node3D.new();wall.add_child(fan);fan.position=Vector3(x,2.95,z+.08)
		Visuals.box(fan,Vector3.ZERO,Vector3(.62,.62,.06),Color("3a3f3d"))
		var blades=Node3D.new();fan.add_child(blades);blades.position.z=.05
		for k in range(3):
			var blade=Visuals.box(blades,Vector3(0,.13,0),Vector3(.1,.26,.02),Color("9aa19b"));blade.get_parent().remove_child(blade)
			var arm=Node3D.new();blades.add_child(arm);arm.rotation.z=k*TAU/3;arm.add_child(blade)
		anim.add(blades,"rotation:z",[0.0,.7,1.4,2.1])
	var board=Visuals.box(wall,Vector3(-.8,1.55,z+.02),Vector3(1.2,.7,.04),Color("6a6f63"))
	for i in range(5):
		var tool=Visuals.box(wall,Vector3(-1.25+i*.22,1.55,z+.06),Vector3(.05,.42-(i%2)*.14,.03),Color("c9cfbe") if i%2 else Color("cf613f"),"steel" if i%2 else "paint");tool.rotation.z=(i-2)*.08
	var cabinet=Visuals.box(wall,Vector3(5.2,1.5,z+.06),Vector3(.8,1.0,.14),olive,"paint")
	for i in range(3):
		var led=Visuals.box(wall,Vector3(4.95+i*.25,1.85,z+.14),Vector3(.08,.08,.02),[Color("8fe895"),Color("ffb52c"),Color("ff4a3a")][i]);led.material_override=Visuals.material([Color("8fe895"),Color("ffb52c"),Color("ff4a3a")][i],true)
		anim.add(led,"visible",[true,i!=2,i==0,true])
	for i in range(16):Visuals.box(wall,Vector3(-4.5+i*.8,1.2,z+.03),Vector3(.4,.1,.02),Color("e5b34f") if i%2==0 else Color("2f332d"))
	# Chain hoist over the corner with an engine block hanging from it.
	var hoist=Node3D.new();wall.add_child(hoist);hoist.position=Vector3(6.8,0,-2.6)
	Visuals.box(hoist,Vector3(0,3.2,0),Vector3(.12,.12,1.4),steel(),"steel")
	for i in range(6):Visuals.box(hoist,Vector3(0,3.05-i*.16,.2),Vector3(.05,.12,.05),Color("8d9189"),"steel")
	var engine=Node3D.new();hoist.add_child(engine);engine.position=Vector3(0,1.95,.2)
	Visuals.box(engine,Vector3.ZERO,Vector3(.7,.45,.5),Color("6d747a"),"gunmetal")
	for k in range(3):Visuals.box(engine,Vector3(-.2+k*.2,.3,0),Vector3(.12,.18,.3),Color("8a9196"),"steel")
	anim.add(engine,"rotation:y",[0.0,.08,0.0,-.08])

func racks():
	for x in [-6.9,8.9]:
		# Right racks stand clear of the covered passage to the yard (row z=0).
		for z in ([-1.8,1.8] if x<0 else [-2.2,2.2]):
			var rack=Node3D.new();rack.name="StorageRack";add_child(rack);rack.position=Vector3(x,0,z)
			for dx in [-.35,.35]:
				for dz in [-.9,.9]:Visuals.box(rack,Vector3(dx,1.1,dz),Vector3(.07,2.2,.07),steel(),"steel")
			for y in [.1,.85,1.6]:
				Visuals.box(rack,Vector3(0,y,0),Vector3(.8,.05,1.9),Color("8a7a56"))
				for k in range(2):
					if rng.randf()<.8:
						var crate=Visuals.model("crate" if rng.randf()<.6 else "supply_stack",rack,Vector3(0,y+.03,-.45+k*.9))
						crate.scale=Vector3.ONE*.55;crate.rotation.y=rng.randf_range(-.3,.3)+(PI*.5 if x<0 else -PI*.5)

func road():
	Visuals.box(self,Vector3(1,GROUND_Y-.01,ROAD_Z),Vector3(44,.03,1.9),Color("6b6e5c"))
	for i in range(18):Visuals.box(self,Vector3(-20+i*2.4,GROUND_Y+.01,ROAD_Z),Vector3(.9,.01,.09),Color("c9b27a"))

func free_cell(p:Vector3)->bool:
	if p.x>-7.4 and p.x<20.8 and p.z>-7.5 and p.z<5.4:return false  # hangar, yard and parked HQ
	return absf(p.z-ROAD_Z)>1.5

func vegetation(biome:Dictionary):
	var family=str(biome.get("vegetation","spruce"));var tint=Color(biome.floor)
	var placed=0;var tries=0
	while placed<26 and tries<300:
		tries+=1
		var p=Vector3(rng.randf_range(-12,14),GROUND_Y+.02,rng.randf_range(-9,10))
		if not free_cell(p):continue
		var scene=load("res://assets/models/vegetation/%s_%02d.glb" % [family,rng.randi_range(0,preload("res://scripts/vegetation_visual.gd").VARIANTS-1)])
		var node=scene.instantiate();add_child(node);node.position=p;node.rotation.y=rng.randi_range(0,3)*PI*.5;node.scale=Vector3.ONE*rng.randf_range(1.0,1.35)
		for mesh in node.find_children("*","MeshInstance3D",true,false):
			mesh.set_instance_shader_parameter("wind_offset",rng.randf()*100)
			for surface in range(mesh.mesh.get_surface_count()):
				var original=mesh.mesh.surface_get_material(surface)
				if not original is StandardMaterial3D:continue
				var mat=ShaderMaterial.new();mat.shader=WIND;mat.set_shader_parameter("foliage_color",original.albedo_color.lerp(tint,.36))
				mesh.set_surface_override_material(surface,mat)
		placed+=1

## Behind the range (T-248): the battle backdrop's abstract shapes of the biome, so the yard's far side is not bare.
const LANDSCAPE=[[Vector3(12.2,0,-5.3),1.2],[Vector3(14.8,0,-6.0),1.9],[Vector3(17.6,0,-5.2),1.1],[Vector3(20.2,0,-6.3),2.2],
	[Vector3(23.2,0,-5.4),1.4],[Vector3(25.6,0,-3.6),1.8],[Vector3(13.2,0,-8.4),2.4],[Vector3(16.8,0,-8.8),2.8],[Vector3(22.0,0,-9.0),3.0],[Vector3(27.0,0,-7.4),2.6],[Vector3(28.4,0,.8),2.2]]
func landscape(biome:Dictionary):
	var spots=LANDSCAPE.map(func(s):return [s[0]+Vector3(rng.randf_range(-.5,.5),GROUND_Y,rng.randf_range(-.4,.4)),float(s[1])*rng.randf_range(.85,1.15)])
	preload("res://scripts/location_ambience.gd").landscape(self,biome,rng.randi(),spots)
func cargo():
	for p in [Vector3(-9.5,GROUND_Y,-4.5),Vector3(-10.5,GROUND_Y,1.5),Vector3(21,GROUND_Y,-4.5),Vector3(12.5,GROUND_Y,4.6)]:
		var pile=load("res://assets/models/environment_v7/tarp_%d.glb" % rng.randi_range(0,2)).instantiate()
		add_child(pile);pile.position=p;pile.rotation.y=rng.randf_range(-.5,.5)+PI*.5;pile.scale=Vector3.ONE*1.3
	for p in [Vector3(-8.6,GROUND_Y,4.2),Vector3(10.6,GROUND_Y,-5.2)]:
		var stack=Visuals.model("supply_stack",self,p);stack.rotation.y=rng.randf()*TAU

# ---------------------------------------------------------------- background life
func _process(delta):
	if not is_instance_valid(hub):return
	next_scene-=delta
	if next_scene>0 or busy>=2:return
	next_scene=rng.randf_range(5,11)
	# Only the road in front of the outpost lives (author, 4 Oct 2026): the right side with the range and the
	# parking stays calm — no chatting cats there and no drone crossing the yard.
	if rng.randf()<.5 and not convoy_on_road:convoy()
	else:patrol()

func cat(pos:Vector3,weapon:="rifle")->Node3D:
	var m=Visuals.model("soldier",self,pos);m.equip_weapon(weapon)
	m.fur_override=rng.randi_range(1,InfantryPalette.FURS.size()-1);m.apply_palette()
	return m

func finish(node:Node):
	busy-=1
	if is_instance_valid(node):node.queue_free()

func convoy():
	var kind=["buggy","apc","tank","buggy"][rng.randi_range(0,3)]
	var left=rng.randf()<.5
	var m=Visuals.model(kind,self,Vector3(-18 if left else 20,GROUND_Y,ROAD_Z+(-.35 if left else .35)))
	m.rotation.y=-PI*.5 if left else PI*.5;m.preview_moving=true;m.preview_speed=3.2
	busy+=1;convoy_on_road=true
	var tween=create_tween();tween.tween_property(m,"position:x",20.0 if left else -18.0,rng.randf_range(8,11))
	tween.tween_callback(func():convoy_on_road=false;finish(m))

func patrol():
	var group=Node3D.new();add_child(group);busy+=1
	var left=rng.randf()<.5
	var count=rng.randi_range(2,3)
	for i in range(count):
		var m=cat(Vector3(-i*.9 if left else i*.9,0,rng.randf_range(-.15,.15)),["rifle","smg","shotgun"][rng.randi_range(0,2)])
		m.get_parent().remove_child(m);group.add_child(m)
		m.rotation.y=-PI*.5 if left else PI*.5;m.preview_moving=true
		if m.player:m.player.speed_scale=.62  # a jog, not a sprint
	group.position=Vector3(-17 if left else 19,GROUND_Y,ROAD_Z+1.25)
	var tween=create_tween();tween.tween_property(group,"position:x",19.0 if left else -17.0,rng.randf_range(16,20))
	tween.tween_callback(finish.bind(group))
