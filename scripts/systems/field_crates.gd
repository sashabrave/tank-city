extends Node3D
## Army crates: a few small olive boxes (about a quarter of a cell, 1.2× the first version) per field, usually alone, sometimes in a pair,
## rarely stacked up to three. A player bullet breaks one into splinters with a wooden crack. Anything walking into
## a crate kicks it apart too, so crates never block movement or pathfinding. Placement uses its own RNG seeded by
## the room; the loot (T-228, 4 Oct: the author never saw an ingot) rolls on the run's combat RNG.
const SIZE=Vector3(.264,.192,.204)
const HIT_RADIUS=.24
## A crate broken by the soldier (shot or kicked) holds something with this chance, then one prize by weight:
## alloy ingots, an ammo box for the gun in hand, a medkit, or a gun. Enemies kicking crates drop nothing.
const LOOT_CHANCE=.55
const LOOT_WEIGHTS={"alloy":45,"ammo":25,"medkit":20,"weapon":10}
const ALLOY=[4,8]
var arena
var rng=RandomNumberGenerator.new()
var crates:Array=[]  # {node, top:float}
static var parts:={}

func setup(context):
	arena=context;name="FieldCrates"
	rng.seed=hash([arena.run_seed,arena.room_index,"field_crates"])
	if arena.boss_room:return
	# Crates hide in corners against cover: an inner corner of two walls first, else the end of a block.
	# The crate is pressed into the corner of its cell, so passages stay free.
	var spots_all=[];var dirs=[Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]
	for x in range(1,arena.grid_size-1):
		for y in range(2,arena.grid_size-4):
			var cell=Vector2i(x,y)
			if arena.walls.has(cell) or arena.trenches.has(cell) or arena.terrain.movement_blocked_at_cell(cell):continue
			for d in dirs:
				if not arena.walls.has(cell+d):continue
				for p in [Vector2i(d.y,d.x),Vector2i(-d.y,-d.x)]:
					var inner=arena.walls.has(cell+p)
					var block_end=not arena.walls.has(cell+d+p)
					if inner or block_end:spots_all.append({"cell":cell,"d":d,"p":p,"rank":2 if inner else 1})
	var inner_spots=spots_all.filter(func(s):return s.rank==2)
	var pool=inner_spots if inner_spots.size()>=2 else spots_all
	var used={}
	var spots=mini(pool.size(),rng.randi_range(2,4))
	for i in range(spots):
		if pool.is_empty():break
		var spot=pool.pop_at(rng.randi_range(0,pool.size()-1))
		if used.has(spot.cell):continue
		used[spot.cell]=true
		var inset=.5-SIZE.x*.55
		var base=arena.world_pos(spot.cell)+Vector3(spot.d.x,0,spot.d.y)*inset+Vector3(spot.p.x,0,spot.p.y)*inset
		var height=1+(1 if rng.randf()<.1 else 0)+(1 if rng.randf()<.03 else 0)
		for level in range(height):add_crate(base+Vector3(rng.randf_range(-.02,.02),level*SIZE.y,rng.randf_range(-.02,.02)),rng.randf_range(-.15,.15))
		# A second crate along the wall, away from the corner.
		if rng.randf()<.25:add_crate(base-Vector3(spot.p.x,0,spot.p.y)*SIZE.x*1.08,rng.randf_range(-.15,.15))

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
				smash(crate,actor==arena.player);break

## Splinters fly from the broken crate; one broken by the soldier may hold a prize (loot()).
func smash(crate:Dictionary,by_player:bool):
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
	if by_player:loot(pos)

## What a broken crate holds, rolled on the combat RNG: "" (empty) or one of LOOT_WEIGHTS. Alloy flies out as
## ingots; the other prizes lie on the crate's cell as one item with its E / C card (reward.place_sack).
static func roll_prize(combat:RandomNumberGenerator)->String:
	if combat.randf()>=LOOT_CHANCE:return ""
	var total=0
	for kind in LOOT_WEIGHTS:total+=int(LOOT_WEIGHTS[kind])
	var pick=combat.randi_range(0,total-1)
	for kind in LOOT_WEIGHTS:
		pick-=int(LOOT_WEIGHTS[kind])
		if pick<0:return kind
	return "alloy"
func loot(pos:Vector3):
	if not is_instance_valid(arena) or arena.run==null:return
	var combat:RandomNumberGenerator=arena.run.combat_rng
	var kind=roll_prize(combat)
	if kind=="":return
	if kind=="alloy":
		preload("res://scripts/resource_drop.gd").spawn(arena,pos,combat.randi_range(ALLOY[0],ALLOY[1]),"alloy");return
	# An aid kit lies as itself and heals on pickup (no aid kits in the backpack since 4 Oct 2026).
	if kind=="medkit":
		arena.reward.place_pickup(arena.grid_pos(pos),"heart",0.0);arena.room.pickups.back()["heal"]=Game.heal_amount();return
	var content={"recipes":[],"ammo":[]}
	if kind=="ammo":
		var types=Ammo.TYPES.filter(func(t):return Ammo.fits(t,str(arena.weapon)))
		if types.is_empty():types=Ammo.TYPES
		content.ammo=[Ammo.roll(types[combat.randi_range(0,types.size()-1)],1 if combat.randf()<.2 else 0,combat.randi())]
	else:
		var locker=preload("res://scripts/weapon_locker.gd")
		var pool=Game.LOOT.gun_ids().filter(func(id):return id in Game.weapon_unlocks)
		if pool.is_empty():pool=[str(arena.weapon)]
		var rarity=locker.pick_rarity(combat,0.0);var stats={}
		for key in locker.STATS:
			var span:Array=locker.STATS[key][1][rarity];stats[key]=snappedf(combat.randf_range(span[0],span[1]),.01)
		content["weapons"]=[{"id":str(pool[combat.randi_range(0,pool.size()-1)]),"rarity":rarity,"stats":stats}]
	arena.reward.place_sack(arena.grid_pos(pos),content)
