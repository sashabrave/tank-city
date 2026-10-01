extends Node3D
## Visual-only brick fragments: crumbs, halves, whole bricks and bonded chunks.
## Own RNG and a single updater per arena; never touches combat randomness.
const WALL=preload("res://scripts/section_wall.gd")
const GRAVITY=9.0
static var meshes:={}
static var debris_material:ShaderMaterial
static var reinforced_material:ShaderMaterial
var rng=RandomNumberGenerator.new()
var pieces:Array=[]

static func shared(arena:Node3D)->Node3D:
	var node=arena.get_node_or_null("BrickDebris")
	if node:return node
	node=load("res://scripts/brick_debris.gd").new();node.name="BrickDebris";node.rng.randomize();arena.add_child(node)
	return node

static func mesh(kind:String)->ArrayMesh:
	if meshes.has(kind):return meshes[kind]
	var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var clay=Color(WALL.CLAY.r,WALL.CLAY.g,WALL.CLAY.b,.5);var mortar=Color(WALL.MORTAR.r,WALL.MORTAR.g,WALL.MORTAR.b,0)
	var brick=WALL.BRICK;var course=WALL.ROW_HEIGHT
	match kind:
		"crumb":WALL.add_box(surface,Vector3.ZERO,Vector3.ONE,clay)
		"half":WALL.add_box(surface,Vector3.ZERO,Vector3(brick.x*.5,brick.y,brick.z),clay)
		"brick":WALL.add_box(surface,Vector3.ZERO,brick,clay)
		"pair","triple":
			var count=2 if kind=="pair" else 3
			WALL.add_box(surface,Vector3.ZERO,Vector3(brick.x*.8,course*count-.03,brick.z*.8),mortar)
			for i in range(count):WALL.add_box(surface,Vector3(((i%2)-.5)*.04,(i-(count-1)*.5)*course,0),brick,clay)
		"rod":WALL.add_box(surface,Vector3.ZERO,Vector3(.46,.026,.026),Color(WALL.STEEL.r,WALL.STEEL.g,WALL.STEEL.b,0))
		"slab":
			# A torn piece of wall: two courses, running bond, a brick and a half wide.
			WALL.add_box(surface,Vector3.ZERO,Vector3(.30,course*2-.03,brick.z*.8),mortar)
			for row in [0,1]:
				var y=(row-.5)*course
				if row==0:
					WALL.add_box(surface,Vector3(-.059,y,0),brick,clay);WALL.add_box(surface,Vector3(.118,y,0),Vector3(brick.x*.5,brick.y,brick.z),clay)
				else:
					WALL.add_box(surface,Vector3(-.118,y,0),Vector3(brick.x*.5,brick.y,brick.z),clay);WALL.add_box(surface,Vector3(.059,y,0),brick,clay)
	meshes[kind]=surface.commit()
	return meshes[kind]

## Fragments for removed sections. Size of the pieces follows the hit strength.
func burst(center:Vector3,removed:Array,power:float,direction:Vector3):
	var budget=clampi(4+removed.size()*2,4,14)
	for i in removed:
		if budget<=0:break
		var pos=center+Vector3(-.375+(i%4)*WALL.STEP,0,-.375+int(i/4)*WALL.STEP)
		var kinds:Array
		if power<1.2:kinds=["half","crumb","crumb"] if rng.randf()<.6 else ["brick","crumb"]
		elif power<2.5:kinds=["brick","half","crumb"] if rng.randf()<.55 else ["pair","crumb"]
		elif power<4.0:kinds=["pair","brick","crumb"] if rng.randf()<.5 else ["triple","half"]
		else:kinds=["slab","brick"] if rng.randf()<.55 else ["triple","pair"]
		for kind in kinds:
			if budget<=0:break
			var height=rng.randf_range(.1,.62)
			launch(kind,pos+Vector3(rng.randf_range(-.08,.08),height,rng.randf_range(-.08,.08)),direction,power);budget-=1

## A reinforced block giving way: nothing larger than one brick, plus loose rods from the cage.
func collapse(center:Vector3,direction:Vector3,reinforced:=true):
	for i in range(12):
		var kind="brick" if i<5 else "half" if i<9 else "crumb"
		launch(kind,center+Vector3(rng.randf_range(-.4,.4),rng.randf_range(.1,.65),rng.randf_range(-.4,.4)),direction,1.6,reinforced)
	for i in range(3):launch("rod",center+Vector3(rng.randf_range(-.4,.4),rng.randf_range(.2,.7),rng.randf_range(-.4,.4)),direction,1.2)

## Surface chips for a hit that did not remove a whole section.
func chips(pos:Vector3,direction:Vector3,count:int,max_kind:="half",reinforced:=false):
	pos.y=0.0
	for i in range(count):
		var kind="crumb" if max_kind=="crumb" or rng.randf()<.7 else max_kind
		launch(kind,pos+Vector3(rng.randf_range(-.06,.06),rng.randf_range(.12,.6),rng.randf_range(-.06,.06)),direction,.8,reinforced)

func launch(kind:String,pos:Vector3,direction:Vector3,power:float,reinforced:=false):
	if debris_material==null:
		WALL.prepare_visual();debris_material=WALL.brick_material.duplicate();debris_material.set_shader_parameter("section_tint",false)
		reinforced_material=debris_material.duplicate();reinforced_material.set_shader_parameter("clay_tint",WALL.REINFORCED_TINT)
	var node=MeshInstance3D.new();node.mesh=mesh(kind);node.material_override=reinforced_material if reinforced else debris_material
	var small=kind=="crumb"
	if small:node.scale=Vector3.ONE*rng.randf_range(.035,.07)
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if small or kind=="half" else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(node);node.global_position=pos;node.rotation=Vector3(rng.randf()*.4,rng.randf()*TAU,rng.randf()*.4)
	var push=direction.normalized() if direction.length_squared()>.01 else Vector3(rng.randf_range(-1,1),0,rng.randf_range(-1,1)).normalized()
	var weight={"crumb":.4,"rod":.8,"half":.7,"brick":1.0,"pair":1.5,"triple":1.9,"slab":2.2}[kind]
	var speed=rng.randf_range(1.0,2.2)*clampf(.7+power*.18,.7,1.6)/sqrt(weight)
	var side=Vector3(-push.z,0,push.x)*rng.randf_range(-.8,.8)
	var velocity=(push+side).normalized()*speed+Vector3.UP*rng.randf_range(.9,2.4)/sqrt(weight)
	var spin=Vector3(rng.randf_range(-9,9),rng.randf_range(-6,6),rng.randf_range(-9,9))/weight
	var extent=node.get_aabb().size*node.scale
	var rest=minf(extent.x,minf(extent.y,extent.z))*.5
	pieces.append({"node":node,"velocity":velocity,"spin":spin,"rest":rest,"life":rng.randf_range(1.8,2.8),"age":0.0,"landed":false,"base_scale":node.scale})

func _process(delta:float):
	for i in range(pieces.size()-1,-1,-1):
		var p=pieces[i];var node:MeshInstance3D=p.node
		if not is_instance_valid(node):pieces.remove_at(i);continue
		p.age+=delta
		if node.position.y>p.rest or p.velocity.y>0:
			p.velocity.y-=GRAVITY*delta
			node.position+=p.velocity*delta;node.rotation+=p.spin*delta
			if node.position.y<=p.rest:
				node.position.y=p.rest
				# Heavy chunks thud and stop quickly; light crumbs skip once more.
				p.velocity=Vector3(p.velocity.x*.35,-p.velocity.y*.28,p.velocity.z*.35);p.spin*=.3
				if p.velocity.y<.4:p.velocity.y=0.0;p.landed=true
		elif p.landed:
			# Settle flat on the thinnest face instead of balancing on an edge.
			node.rotation=Vector3(lerp_angle(node.rotation.x,PI*.5,delta*12),node.rotation.y,lerp_angle(node.rotation.z,0.0,delta*12))
			node.position+=Vector3(p.velocity.x,0,p.velocity.z)*delta;p.velocity*=maxf(0,1-delta*8)
		var fade=clampf((p.life-p.age)/.45,0,1)
		node.scale=p.base_scale*fade
		if p.age>=p.life:node.queue_free();pieces.remove_at(i)
