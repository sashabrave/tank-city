extends Node3D
## Sparse floating islands between the battle field and the side silhouettes (0.8): small low-poly chunks
## of the biome's ground carrying a few biome props (trees, rocks, bushes) and war leftovers (crates,
## hedgehogs, tarps, a burnt-out wreck). Visual only, own RNG; the field stays a diorama in the air.
const WAR=["crate","supply_stack","hedgehog","tarp_0","tarp_1","tarp_2"]
const ROCKS=["biome_rock_0","biome_rock_1","biome_rock_flat","biome_bush","biome_tuft","biome_stump","biome_log"]
const BIOME_EXTRA={"desert":["biome_cactus","biome_dune"],"inferno":["biome_ash_cone","biome_crystal"],"mountains":["biome_snow_mound","biome_crystal"],"marsh":["biome_reeds"],"forest":["biome_stump"],"city":[]}
var palette:Dictionary={}
var radius=10.0
var seed_value=0
var islands:Array=[]
var elapsed=0.0

func build():
	var rng=RandomNumberGenerator.new();rng.seed=hash([seed_value,"war_islands"])
	for side in [-1.0,1.0]:
		var count=rng.randi_range(2,3)
		var spots:Array=[]
		for i in range(count):
			# Spread along the side, never two islands in the same stretch.
			var z=0.0
			for attempt in range(8):
				z=rng.randf_range(-radius*1.25,radius*1.25)
				if spots.all(func(o):return absf(o-z)>radius*.55):break
			spots.append(z)
			var pos=Vector3(side*(radius+rng.randf_range(2.2,4.2)),rng.randf_range(-1.1,-.45),z)
			island(pos,rng.randf_range(1.0,1.9),rng)

func island(pos:Vector3,size:float,rng:RandomNumberGenerator):
	var root=Node3D.new();add_child(root);root.position=pos;root.rotation.y=rng.randf()*TAU
	var ground=Color(str(palette.get("floor","9aa08a")))
	var edge=Color(str(palette.get("edge","7d8270")))
	# The chunk: a flat top and a tapered, faceted underside like a piece broken off the field.
	var top=MeshInstance3D.new();var slab=CylinderMesh.new();slab.top_radius=size;slab.bottom_radius=size*.92;slab.height=.22;slab.radial_segments=7;slab.rings=1
	top.mesh=slab;top.material_override=Visuals.material(ground);root.add_child(top)
	var under=MeshInstance3D.new();var cone=CylinderMesh.new();cone.top_radius=size*.92;cone.bottom_radius=size*.18;cone.height=size*.9;cone.radial_segments=7;cone.rings=1
	under.mesh=cone;under.material_override=Visuals.material(edge.darkened(.25));under.position.y=-.11-size*.45;root.add_child(under)
	# Props: one or two from the biome, sometimes one war leftover, rarely a wreck.
	var family=str(palette.get("ambience","forest"))
	var pool:Array=ROCKS+BIOME_EXTRA.get(family,[])
	var props=rng.randi_range(1,3)
	for i in range(props):
		var spot=Vector3(rng.randf_range(-.5,.5),0,rng.randf_range(-.5,.5))*size+Vector3(0,.11,0)
		var roll=rng.randf()
		if roll<.4:tree(root,spot,rng)
		elif roll<.72:prop(root,str(pool[rng.randi()%pool.size()]),spot,rng.randf_range(.8,1.3),rng)
		else:prop(root,str(WAR[rng.randi()%WAR.size()]),spot,rng.randf_range(.55,.8),rng)
	if rng.randf()<.18:wreck(root,Vector3(0,.11,0),rng)
	islands.append({"node":root,"y":pos.y,"phase":rng.randf()*TAU})

func tree(root:Node3D,spot:Vector3,rng:RandomNumberGenerator):
	var family=str(palette.get("vegetation","spruce"))
	var path="res://assets/models/vegetation/%s_%02d.glb" % [family,rng.randi_range(0,4)]
	if not ResourceLoader.exists(path):return
	var node=load(path).instantiate();root.add_child(node);node.position=spot;node.rotation.y=rng.randf()*TAU;node.scale=Vector3.ONE*rng.randf_range(.9,1.3)
	# Same wind shader and biome tint as the field plants (VegetationVisual), so the raw model colours do not shout from the edges.
	var tint=Color(str(palette.get("floor","9aa08a")))
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		for surface in range(mesh.mesh.get_surface_count()):
			var original=mesh.mesh.surface_get_material(surface)
			if not original is StandardMaterial3D:continue
			var mat=ShaderMaterial.new();mat.shader=preload("res://assets/shaders/vegetation_wind.gdshader")
			mat.set_shader_parameter("foliage_color",original.albedo_color.lerp(tint,.36));mesh.set_surface_override_material(surface,mat)
		mesh.set_instance_shader_parameter("wind_offset",rng.randf()*100)

func prop(root:Node3D,kind:String,spot:Vector3,scale_value:float,rng:RandomNumberGenerator):
	var path=("res://assets/models/biome_props/"+kind.trim_prefix("biome_")+".glb") if kind.begins_with("biome_") else "res://assets/models/environment_v7/"+kind+".glb"
	if not ResourceLoader.exists(path):return
	var node=Visuals.model(kind,root,spot);node.rotation.y=rng.randf()*TAU;node.scale=Vector3.ONE*scale_value

## A burnt-out vehicle hull, tilted and darkened.
func wreck(root:Node3D,spot:Vector3,rng:RandomNumberGenerator):
	var kind=["tank","apc","buggy"][rng.randi()%3]
	var node=Visuals.model(kind,root,spot);node.rotation=Vector3(rng.randf_range(-.12,.12),rng.randf()*TAU,rng.randf_range(-.15,.15));node.scale=Vector3.ONE*.7
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		var mat=Visuals.material(Color("3a3632"));mat.roughness=1.0;mesh.material_override=mat

func _process(delta):
	elapsed+=delta
	for item in islands:item.node.position.y=item.y+sin(elapsed*TAU/70+item.phase)*.06
