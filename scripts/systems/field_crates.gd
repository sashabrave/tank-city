extends Node3D
## Army crates: a few small olive boxes (a quarter of a cell) per field, usually alone, sometimes in a pair,
## rarely stacked up to three. A player bullet breaks one into splinters with a wooden crack; with a small
## chance it holds a little alloy. Anything walking into a crate kicks it apart too, so crates never block
## movement or pathfinding. Placement and loot use their own RNG seeded by the room, not the combat RNG.
const SIZE=Vector3(.22,.16,.17)
const HIT_RADIUS=.2
const LOOT_CHANCE=.15
const LOOT=[2,4]
var arena
var rng=RandomNumberGenerator.new()
var crates:Array=[]  # {node, top:float}
static var parts:={}

func setup(context):
	arena=context;name="FieldCrates"
	rng.seed=hash([arena.run_seed,arena.room_index,"field_crates"])
	if arena.boss_room:return
	var cells=[]
	for x in range(1,arena.grid_size-1):
		for y in range(2,arena.grid_size-4):
			var cell=Vector2i(x,y)
			if arena.walls.has(cell) or arena.trenches.has(cell) or arena.terrain.movement_blocked_at_cell(cell):continue
			# Crates lean against cover: at least one wall next to the cell.
			if not [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN].any(func(d):return arena.walls.has(cell+d)):continue
			cells.append(cell)
	var spots=mini(cells.size(),rng.randi_range(2,4))
	for i in range(spots):
		var cell=cells.pop_at(rng.randi_range(0,cells.size()-1))
		var corner=Vector3(rng.randf_range(-.28,.28),0,rng.randf_range(-.28,.28))
		var base=arena.world_pos(cell)+corner
		var height=1+(1 if rng.randf()<.1 else 0)+(1 if rng.randf()<.03 else 0)
		for level in range(height):add_crate(base+Vector3(rng.randf_range(-.02,.02),level*SIZE.y,rng.randf_range(-.02,.02)),rng.randf_range(-.4,.4))
		if rng.randf()<.25:add_crate(base+Vector3(SIZE.x*1.05*(1 if corner.x<0 else -1),0,rng.randf_range(-.05,.05)),rng.randf_range(-.4,.4))

static func part(kind:String)->Array:
	if parts.has(kind):return parts[kind]
	var mesh=BoxMesh.new();var color={"body":Color("5f6744"),"band":Color("3f4430"),"stencil":Color("d8cfa6"),"splinter":Color("8a7550")}[kind]
	mesh.size=Vector3.ONE;parts[kind]=[mesh,Visuals.material(color)];return parts[kind]

func add_crate(pos:Vector3,yaw:float):
	var node=Node3D.new();add_child(node);node.position=pos;node.rotation.y=yaw;node.name="Crate"
	for piece in [["body",Vector3(0,SIZE.y*.5,0),SIZE],["band",Vector3(0,SIZE.y*.82,0),Vector3(SIZE.x*1.02,SIZE.y*.12,SIZE.z*1.02)],["band",Vector3(0,SIZE.y*.18,0),Vector3(SIZE.x*1.02,SIZE.y*.12,SIZE.z*1.02)],["stencil",Vector3(0,SIZE.y*.5,SIZE.z*.51),Vector3(SIZE.x*.4,SIZE.y*.18,.004)]]:
		var mesh=MeshInstance3D.new();var data=part(piece[0]);mesh.mesh=data[0];mesh.material_override=data[1]
		mesh.position=piece[1];mesh.scale=piece[2];node.add_child(mesh)
	crates.append({"node":node,"top":pos.y+SIZE.y})

func _physics_process(_delta):
	if not is_instance_valid(arena) or arena.phase not in ["combat","countdown"] or crates.is_empty():return
	for crate in crates.duplicate():
		var spot:Vector3=crate.node.global_position
		var hit=false
		for bullet in arena.projectiles:
			if not is_instance_valid(bullet) or bullet.spent or not bullet.friendly:continue
			if Vector2(bullet.global_position.x-spot.x,bullet.global_position.z-spot.z).length()<HIT_RADIUS and bullet.global_position.y<crate.top+.25:
				bullet.consume();hit=true;break
		if hit:smash(crate,true);continue
		for actor in arena.actors:
			if is_instance_valid(actor) and not actor.dead and actor.kind!="drone" and actor.kind!="flyer" and Vector2(actor.position.x-spot.x,actor.position.z-spot.z).length()<.3*actor.footprint:
				smash(crate,false);break

## Splinters fly from the broken crate; a shot crate may drop a little alloy.
func smash(crate:Dictionary,shot:bool):
	crates.erase(crate)
	var node:Node3D=crate.node;var pos=node.global_position+Vector3.UP*SIZE.y*.5
	Game.sound("hit_wood",node);Game.sound("debris",arena)
	var visual=RandomNumberGenerator.new();visual.seed=hash([pos.x,pos.z,"splinters"])
	var data=part("splinter")
	for i in range(9):
		var chip=MeshInstance3D.new();chip.mesh=data[0];chip.material_override=data[1];arena.add_child(chip)
		chip.scale=Vector3(visual.randf_range(.015,.03),visual.randf_range(.015,.03),visual.randf_range(.06,.13));chip.global_position=pos
		chip.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var out=Vector3(visual.randf_range(-1,1),0,visual.randf_range(-1,1)).normalized()*visual.randf_range(.25,.6)
		var peak=pos+out*.5+Vector3.UP*visual.randf_range(.25,.55);var land=Vector3(pos.x,.01,pos.z)+out
		var tween=chip.create_tween()
		tween.tween_property(chip,"global_position",peak,.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(chip,"rotation",Vector3(visual.randf()*TAU,visual.randf()*TAU,0),.42)
		tween.tween_property(chip,"global_position",land,.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_interval(1.2);tween.tween_property(chip,"scale",Vector3.ZERO,.35);tween.tween_callback(chip.queue_free)
	# Crates stacked above fall onto the gap.
	for other in crates:
		var other_pos:Vector3=other.node.global_position
		if Vector2(other_pos.x-node.global_position.x,other_pos.z-node.global_position.z).length()<.08 and other_pos.y>node.global_position.y+.01:
			var drop=other.node.create_tween();drop.tween_property(other.node,"position:y",other.node.position.y-SIZE.y,.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT);other.top-=SIZE.y
	node.queue_free()
	if shot and rng.randf()<LOOT_CHANCE:preload("res://scripts/resource_drop.gd").spawn(arena,pos,rng.randi_range(LOOT[0],LOOT[1]),"alloy")
