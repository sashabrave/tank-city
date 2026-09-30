extends RefCounted
## Board system. Owns rules; Arena remains the scene coordinator.
var arena

func _init(context):
	arena=context

func add_wall(cell: Vector2i, hp: int, style_kind:=""):
	arena.navigation.invalidate(cell)
	if arena.room.walls.has(cell):
		if arena.room.walls[cell].hp>0:
			arena.room.walls[cell].hp+=2;arena.room.walls[cell].max_hp+=2
			if arena.room.walls[cell].has("sections"):
				for i in range(16):
					if arena.room.walls[cell].sections[i]>0:arena.room.walls[cell].sections[i]+=.5
		return
	var obj:Node3D
	if hp>0:
		obj=Node3D.new();arena.add_child(obj);obj.position=arena.world_pos(cell)
	else:obj=concrete_visual(cell,style_kind)
	arena.room.walls[cell]={"node":obj,"hp":hp,"max_hp":hp}
	if style_kind!="":arena.room.walls[cell]["style_kind"]=style_kind
	if hp>0:arena.room.walls[cell].merge(preload("res://scripts/section_wall.gd").create(obj,hp))

func concrete_visual(cell:Vector2i,style_kind:="")->Node3D:
	var style=preload("res://scripts/concrete_style.gd").pick(arena.run.run_seed+arena.room.room_index*1907,cell)
	return Visuals.model(style_kind if style_kind!="" else style.kind,arena,arena.world_pos(cell))

func shape_wall(cell:Vector2i,side:int):
	arena.navigation.invalidate(cell)
	var wall=arena.room.walls[cell]
	if wall.has("half_side"):return
	wall["half_side"]=side
	if wall.hp<0:
		wall["sections"]=[]
		for i in range(16):wall.sections.append(1.0)
		wall.node.queue_free()
		var style=preload("res://scripts/concrete_style.gd").pick(arena.run.run_seed+arena.room.room_index*1907,cell)
		style.shape=side;style.kind=wall.get("style_kind",style.kind)
		wall.node=Visuals.model(preload("res://scripts/concrete_style.gd").asset(style),arena,arena.world_pos(cell))
	preload("res://scripts/section_wall.gd").set_half(wall,side)
func shape_base_wall(cell:Vector2i):
	# Upper corners retain both outer arms, joining the front and side walls.
	var side=0 if cell.x<arena.base_cell.x else 1
	if cell.y<arena.base_cell.y:side=2 if cell.x==arena.base_cell.x else 4+side
	shape_wall(cell,side)
func shape_map_walls():
	var rng=RandomNumberGenerator.new();rng.seed=arena.run.run_seed+arena.room.room_index*1907+781
	for cell in arena.room.walls:
		var wall=arena.room.walls[cell]
		if wall.get("barrel",false) or wall.get("barrier",false) or wall.get("reinforced",false):continue
		if not arena.boss_room and cell.y>=arena.grid_size-2 and absi(cell.x-arena.base_cell.x)<=1:shape_base_wall(cell)
		elif wall.hp<0:
			var style=preload("res://scripts/concrete_style.gd").pick(arena.run.run_seed+arena.room.room_index*1907,cell)
			if style.shape>=0:shape_wall(cell,style.shape)
		elif rng.randf()<.28:shape_wall(cell,rng.randi_range(0,3))
	place_statue()
## Rare landmark: in 20% of rooms one whole indestructible block becomes the cat generals' statue.
## Own RNG from the run seed and room: never touches combat randomness.
func place_statue():
	var rng=RandomNumberGenerator.new();rng.seed=arena.run.run_seed+arena.room.room_index*1907+52711
	if rng.randf()>=.2:return
	var candidates=[]
	for cell in arena.room.walls:
		var wall=arena.room.walls[cell]
		if wall.hp<0 and not wall.has("half_side") and not wall.get("barrel",false) and not wall.get("barrier",false) and not wall.get("reinforced",false) and wall.get("style_kind","")=="":candidates.append(cell)
	if candidates.is_empty():return
	candidates.sort()
	var cell=candidates[rng.randi_range(0,candidates.size()-1)]
	var wall=arena.room.walls[cell]
	wall.node.queue_free();wall.node=Visuals.model("concrete_statue",arena,arena.world_pos(cell));wall["style_kind"]="concrete_statue"

func damage_wall(cell: Vector2i, amount: float,impact:Vector3=Vector3.ZERO,direction:Vector3=Vector3.ZERO,width:float=1.0):
	if not arena.room.walls.has(cell) or arena.room.walls[cell].hp<0: return
	arena.floating_number(arena.world_pos(cell),-minf(arena.room.walls[cell].hp,amount))
	var wall=arena.room.walls[cell]
	if wall.has("sections") and not wall.get("reinforced",false):
		var removed=preload("res://scripts/section_wall.gd").hit(wall,arena.world_pos(cell),amount,impact,direction,width)
		if not removed.is_empty():
			arena.navigation.invalidate(cell)
			Game.sound("wall_crumble",wall.node)
		# Piece size follows the hit: pistol chips halves, a shell tears out bonded chunks.
		var debris=preload("res://scripts/brick_debris.gd").shared(arena)
		var power=amount/maxf(.01,wall.max_hp/4.0)*maxf(1.0,width)
		if removed.is_empty():debris.chips(impact if impact!=Vector3.ZERO else arena.world_pos(cell),direction,2,"half" if power>.6 else "crumb")
		else:debris.burst(arena.world_pos(cell),removed,power,direction)
	else:
		wall.hp-=amount
		arena.navigation.invalidate(cell)
		if wall.get("reinforced",false):
			# The cage holds: only chips up to one brick fly off until the whole block gives way.
			var debris=preload("res://scripts/brick_debris.gd").shared(arena)
			if wall.hp<=0:debris.collapse(arena.world_pos(cell),direction)
			else:debris.chips(impact if impact!=Vector3.ZERO else arena.world_pos(cell),direction,2 if amount<2 else 3,"brick" if amount>=2.5 else "half",true)
			wall.bar.visible=true
	if wall.has("bar"):wall.bar.set_health(maxf(0,wall.hp),wall.max_hp)
	if arena.room.walls[cell].hp<=0:
		Game.sound("debris",arena)
		var barrel=arena.room.walls[cell].get("barrel",false)
		arena.room.walls[cell].node.queue_free();arena.room.walls.erase(cell)
		if barrel:explode_barrel(cell)

func shred_net(cell: Vector2i):
	arena.room.nets[cell].queue_free();arena.room.nets.erase(cell)
	Game.sound("debris",arena)
	for i in range(7):
		var chip=Visuals.box(arena,arena.world_pos(cell)+Vector3.UP*.4,Vector3(.16,.04,.22),Color("819064"))
		var tween=arena.create_tween().set_parallel(true)
		tween.tween_property(chip,"position",chip.position+Vector3(arena.run.combat_rng.randf_range(-.8,.8),.2,arena.run.combat_rng.randf_range(-.8,.8)),.45)
		tween.tween_property(chip,"scale",Vector3.ZERO,.6)
		tween.chain().tween_callback(chip.queue_free)

func add_trench(cell: Vector2i):
	arena.navigation.invalidate(cell)
	var node=Node3D.new();arena.add_child(node);node.position=arena.world_pos(cell);arena.room.trenches[cell]=node
	var hints=preload("res://scripts/trench_hints.gd").new();hints.arena=arena;hints.cell=cell;node.add_child(hints)
	Visuals.model("trench",node)
	# Parapet on the camera side: sandbags that hide the lower body of whoever sits in the trench.
	for i in range(3):
		Visuals.box(node,Vector3(-.3+i*.3,.14,.4),Vector3(.3,.2,.16),Color("b8a47c")).rotation.y=(i-1)*.08

func add_barrier(cell: Vector2i,hp: float,hedgehog:bool=true):
	arena.navigation.invalidate(cell)
	var node=Node3D.new();arena.add_child(node);node.position=arena.world_pos(cell)
	if hedgehog:Visuals.model("hedgehog",node)
	else:Visuals.box(node,Vector3(0,.5,0),Vector3(.95,1,.95),Color("566979"))
	var bar=load("res://scripts/health_bar_3d.gd").new();node.add_child(bar);bar.position.y=1.35;bar.set_health(hp,hp)
	arena.room.walls[cell]={"node":node,"hp":hp,"max_hp":hp,"barrier":true,"bar":bar}
	var player=arena.player
	if is_instance_valid(player) and preload("res://scripts/section_wall.gd").overlap(arena.room.walls[cell],arena.world_pos(cell),player.position,Vector2.ONE*arena.body_size(player)*.5):
		var options=[]
		for y in range(maxi(0,player.cell.y-3),mini(arena.grid_size,player.cell.y+4)):
			for x in range(maxi(0,player.cell.x-3),mini(arena.grid_size,player.cell.x+4)):
				var pos=arena.actor_world_pos(player,Vector2i(x,y))
				if arena.can_stand(pos,player):options.append(pos)
		if options.is_empty():
			arena.room.walls.erase(cell);arena.navigation.invalidate(cell);node.queue_free();return false
		options.sort_custom(func(a,b):return a.distance_squared_to(player.position)<b.distance_squared_to(player.position))
		player.position=options[0];player.cell=arena.grid_pos(player.position);player.destination=player.cell
		player.quarter_destination=player.position;player.moving=false;player.terrain_sliding=false
	elif is_instance_valid(player) and player.moving and not arena.can_stand(player.quarter_destination if player.uses_quarter_steps() or player.terrain_sliding else arena.actor_world_pos(player,player.destination),player):
		player.moving=false;player.terrain_sliding=false;player.destination=player.cell;player.quarter_destination=player.position
	return true

func ruin_layout(rows:Array):
	var rng=RandomNumberGenerator.new();rng.seed=arena.run.run_seed+arena.room.room_index*977
	var rubble=minf(.28,.15+maxi(0,Campaign.progress_index(arena.room.room_index)-7)*.01)
	for y in range(2,arena.room.grid_size-4):
		for x in range(1,arena.room.grid_size-1):
			var cell=Vector2i(x,y)
			if rows[y][x]=="B":
				var roll=rng.randf()
				BattleMapGenerator.put(rows,cell,"R" if roll<rubble else "X" if roll<rubble+.14 else "B")
## World 1: part of the destructible walls become explosive barrels, more of them closer to the boss.
const WORLD1_BARRELS=[1,1,2,2,3,4]
func scatter_barrels(rows:Array):
	var count=WORLD1_BARRELS[clampi(arena.room.room_index,0,WORLD1_BARRELS.size()-1)]
	var rng=RandomNumberGenerator.new();rng.seed=arena.run.run_seed+arena.room.room_index*613+17
	var cells=[]
	for y in range(2,arena.room.grid_size-5):
		for x in range(1,arena.room.grid_size-1):
			if rows[y][x]=="B":cells.append(Vector2i(x,y))
	for i in range(mini(count,cells.size())):
		var pick=rng.randi_range(i,cells.size()-1);var cell=cells[pick];cells[pick]=cells[i];cells[i]=cell
		BattleMapGenerator.put(rows,cell,"X")
## World 1 boss: one barrel in each corner, clear of the centre where the boss fights.
func corner_barrels(rows:Array):
	var g=arena.room.grid_size
	for corner in [Vector2i(1,2),Vector2i(g-2,2),Vector2i(1,g-6),Vector2i(g-2,g-6)]:
		if arena.inside(corner) and rows[corner.y][corner.x]==".":
			BattleMapGenerator.put(rows,corner,"X");add_barrel(corner)
## Reinforced brick: no sections, breaks only as a whole after the damage of a full brick block.
func add_reinforced_wall(cell:Vector2i,hp:float):
	arena.navigation.invalidate(cell)
	if arena.room.walls.has(cell):return
	var obj=Node3D.new();arena.add_child(obj);obj.position=arena.world_pos(cell)
	var visual=preload("res://scripts/section_wall.gd").create(obj,4,true)
	var bar=load("res://scripts/health_bar_3d.gd").new();obj.add_child(bar);bar.position.y=1.15;bar.visible=false
	# Sections are only the collision mask (kept by base shaping); damage never removes them.
	arena.room.walls[cell]={"node":obj,"hp":hp,"max_hp":hp,"reinforced":true,"sections":visual.sections,"section_batch":visual.section_batch,"bar":bar}

## Converts part of the brick blocks ("B") into reinforced ones ("K"). Separate seeded RNG.
func reinforce_layout(rows:Array):
	var share=Campaign.reinforced_share(arena.room.room_index)
	if share<=0:return
	var rng=RandomNumberGenerator.new();rng.seed=arena.run.run_seed+arena.room.room_index*4099+37
	var width=rows.size();var middle=int(width/2.0)
	for y in range(width):
		for x in range(width):
			if rows[y][x]!="B":continue
			if not arena.boss_room and y>=width-2 and absi(x-middle)<=1:continue
			if rng.randf()<share:BattleMapGenerator.put(rows,Vector2i(x,y),"K")
func add_barrel(cell):
	arena.navigation.invalidate(cell)
	var node=Node3D.new();arena.add_child(node);node.position=arena.world_pos(cell)
	var mesh=MeshInstance3D.new();var shape=CylinderMesh.new();shape.top_radius=.27;shape.bottom_radius=.27;shape.height=.7;mesh.mesh=shape;mesh.position.y=.35;mesh.material_override=Visuals.material(Color("a26d49"));node.add_child(mesh)
	Visuals.box(node,Vector3(0,.38,-.28),Vector3(.2,.25,.025),Color("f5ca6e"))
	arena.room.walls[cell]={"node":node,"hp":2.0,"max_hp":2.0,"barrel":true}
func add_rubble(cell):
	for i in range(3):Visuals.box(arena,arena.world_pos(cell)+Vector3(-.25+i*.23,.04,.12 if i%2 else -.15),Vector3(.23,.08,.25),Color("94988a"))
func explode_barrel(cell):
	var pos=arena.world_pos(cell);arena.burst(pos,Color("f5a551"),2);Game.sound("boom",arena)
	for actor in arena.room.actors.duplicate():
		if is_instance_valid(actor) and not actor.dead and arena.flat_distance(actor.position,pos)<2:
			actor.take_damage(5,Vector3.ZERO,"","blast")
			if actor.dead and not actor.player_owned and not actor.allied:Game.progression.event("barrel_kills")
	for nearby in arena.room.walls.keys():
		if arena.flat_distance(arena.world_pos(nearby),pos)<2:damage_wall(nearby,5)

func trench_available(cell:Vector2i,actor)->bool:
	var center=arena.world_pos(cell)
	for other in arena.actors:
		if other==actor or not is_instance_valid(other) or other.dead or other.kind=="flyer":continue
		if other.cell==cell or (other.moving and other.destination==cell):return false
		var radius=.5+arena.body_size(other)*.5-.001
		if absf(other.position.x-center.x)<radius and absf(other.position.z-center.z)<radius:return false
	return true

func occupy_trench(actor,cell:Vector2i)->bool:
	if actor.kind!="soldier" or not arena.trenches.has(cell) or not trench_available(cell,actor):return false
	actor.cell=cell;actor.destination=cell;actor.position=arena.world_pos(cell)
	actor.quarter_destination=actor.position;actor.moving=false;actor.occupying_trench=true
	actor.hidden_in_trench=false;actor.slide_remaining=0;actor.terrain_direction=Vector2i.ZERO;actor.terrain_sliding=false
	if actor.has_meta("quarter_search"):actor.remove_meta("quarter_search")
	return true

func interact_trench()->bool:
	var actor=arena.player
	if actor.occupying_trench:
		var directions=[Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]
		var start=maxi(0,directions.find(actor.facing))
		for step in range(4):
			var target=actor.cell+directions[(start+step)%4]
			if arena.can_enter(target,actor):
				actor.cell=target;actor.destination=target;actor.position=arena.world_pos(target);actor.occupying_trench=false;actor.hidden_in_trench=false;actor.model.position.y=0;actor.moving=false;actor.quarter_destination=actor.position;return true
		arena.toast("Выход занят");return true
	for cell in arena.trenches:
		if (cell-actor.cell).length()>1.01:continue
		if occupy_trench(actor,cell):return true
	return false
