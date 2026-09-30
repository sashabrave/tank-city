extends RefCounted
const WIDTH=.9
static func build(arena):
	var root=Node3D.new();root.name="FieldBorder";arena.add_child(root)
	var half=arena.grid_size*.5;var middle=half+WIDTH*.5
	var tint=Color(arena.room_palette().floor).lerp(Color("797e70"),.32)
	var edge=Color(arena.room_palette().edge).lerp(tint,.3)
	for side in [-1,1]:
		Visuals.box(root,Vector3(side*middle,-.57,0),Vector3(WIDTH,1.08,arena.grid_size+WIDTH*2),edge)
		Visuals.box(root,Vector3(0,-.57,side*middle),Vector3(arena.grid_size,1.08,WIDTH),edge)
		Visuals.box(root,Vector3(side*middle,-.035,0),Vector3(WIDTH,.055,arena.grid_size+WIDTH*2),tint)
		Visuals.box(root,Vector3(0,-.035,side*middle),Vector3(arena.grid_size,.055,WIDTH),tint)
		for z in [-half+1,half-1]:preload("res://scripts/base_surroundings.gd").lamp(root,Vector3(side*middle,0,z))
	var rng=RandomNumberGenerator.new();rng.seed=arena.run_seed+arena.room_index*6203+119
	var count=rng.randi_range(2,3);var used=[]
	for i in range(count):
		var side=rng.randi_range(0,3)
		while side in used:side=(side+1)%4
		used.append(side)
		var along=rng.randf_range(-half+2,half-2)
		# Leave the front-center HQ apron free.
		if side==3 and absf(along)<2:along=-half+2
		var prop=Node3D.new();prop.name=["Barrier","Wire","CementBags"][i];root.add_child(prop)
		prop.position=Vector3(-middle,0,along) if side==0 else Vector3(middle,0,along) if side==1 else Vector3(along,0,-middle) if side==2 else Vector3(along,0,middle)
		prop.rotation.y=PI*.5 if side<2 else 0.0
		match i:
			0:barrier(prop,tint)
			1:wire(prop)
			2:bags(prop,tint)
	cargo(root,arena,half,middle)
## Cargo under tarps along the far edge and the upper sides (visual only, own RNG).
static func cargo(root:Node3D,arena,half:float,middle:float):
	var rng=RandomNumberGenerator.new();rng.seed=arena.run_seed+arena.room_index*6203+947
	var spots=[]
	for k in range(3):spots.append([Vector3(lerpf(-half+2.2,half-2.2,(k+rng.randf_range(.2,.8))/3.0),0,-middle),0.0])
	for side in [-1,1]:spots.append([Vector3(side*middle,0,rng.randf_range(-half+2.5,-1.5)),PI*.5])
	for spot in spots:
		var pile=load("res://assets/models/environment_v7/tarp_%d.glb" % rng.randi_range(0,2)).instantiate()
		root.add_child(pile);pile.position=spot[0];pile.rotation.y=spot[1]+rng.randf_range(-.2,.2);pile.scale=Vector3.ONE*rng.randf_range(.72,.88)
static func barrier(parent,color):
	Visuals.box(parent,Vector3(0,.055,0),Vector3(.65,.11,.27),color.darkened(.15))
	Visuals.box(parent,Vector3(0,.17,0),Vector3(.58,.18,.16),color)
	for x in [-.18,.18]:
		var stripe=Visuals.box(parent,Vector3(x,.18,-.085),Vector3(.085,.12,.012),Color("b39858"));stripe.rotation.z=-.25
static func wire(parent):
	for x in [-.34,.34]:Visuals.box(parent,Vector3(x,.16,0),Vector3(.025,.32,.025),Color("59665c"))
	var mesh=ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in range(65):
		var t=float(i)/64;mesh.surface_add_vertex(Vector3(lerpf(-.34,.34,t),.19+sin(t*TAU*8)*.075,cos(t*TAU*8)*.075))
	mesh.surface_end();var shape=MeshInstance3D.new();shape.mesh=mesh;shape.material_override=Visuals.material(Color("899182"));shape.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(shape)
static func bags(parent,color):
	for i in range(5):
		var top=i>=3
		var bag=Visuals.box(parent,Vector3((i%3)*.17-.17+(.08 if top else 0),.06+(.10 if top else 0),0),Vector3(.16,.10,.22),color.lerp(Color("b4ab8e"),.5));bag.rotation.y=.05*(i-2)
