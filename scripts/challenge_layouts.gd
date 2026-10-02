class_name ChallengeLayouts
extends RefCounted
## Hand-shaped fields for special rooms: a symmetric military frame of blocks along the edges,
## a free plaza in the middle and a mode-specific motif. The HQ area at the bottom and all enemy
## entrances (top columns, side rows 2 and 4) stay as the regular generator made them.
## Cell kinds: C concrete, B brick, K reinforced brick, T trench, R rubble (walkable), N camouflage net, X barrel.
static func center(size:int,mode:String)->Vector2i:
	return Vector2i(int(size/2),int(size/3)) if mode=="hold" else Vector2i(int(size/2),int(size/2)-1)
## The maze fills the whole field above the HQ area: no terrain patches anywhere in it.
static func maze_area(size:int,cell:Vector2i)->bool:return cell.y<size-4
static func plaza_radius(mode:String)->float:
	return {"cache":2.2,"hold":2.2,"survive":3.0}.get(mode,0.0)
## Terrain patches (water, vegetation…) stay out of the plaza.
static func keeps_clear(size:int,mode:String,cell:Vector2i)->bool:
	if mode=="maze":return maze_area(size,cell)
	return Vector2(cell-center(size,mode)).length()<plaza_radius(mode)+.8

static func apply(rows:Array,size:int,mode:String,seed_value:int,difficulty:int=0):
	if mode=="maze":maze(rows,size,seed_value,difficulty);return
	var keep_from=size-4 # HQ fortifications and the soldier's start
	for y in range(1,keep_from):
		for x in range(size):put(rows,Vector2i(x,y),".",size)
	var rng=RandomNumberGenerator.new();rng.seed=seed_value+4099
	frame(rows,size)
	match mode:
		"cache":cache_vault(rows,size)
		"hold":hold_redoubt(rows,size)
		"survive":survive_shelters(rows,size,rng)

## Mirrored edge frame: corner bunkers, side rails with embrasures, chevrons under the top entrances.
static func frame(rows:Array,size:int):
	var right=size-1
	for side in [0,1]:
		var x0=1 if side==0 else right-1;var inward=1 if side==0 else -1
		# Corner bunker: concrete L with a net roof, clear of the corner entrance column.
		for cell in [Vector2i(x0+inward*1,2),Vector2i(x0+inward*2,2),Vector2i(x0+inward*1,3)]:put(rows,cell,"C",size)
		put(rows,Vector2i(x0+inward*2,3),"N",size)
		# Side rail from row 6 down to the HQ area: concrete posts with brick between, embrasure every third cell.
		for y in range(6,size-5):
			put(rows,Vector2i(x0,y),"." if (y-6)%3==2 else ("C" if (y-6)%3==0 else "B"),size)
		# Trench line behind the rail.
		for y in range(7,size-6,3):put(rows,Vector2i(x0+inward*2,y),"T",size)
	# Chevrons (Λ) between the top entrances.
	var middle=int(size/2)
	for offset in [-3,3]:
		var tip=Vector2i(middle+offset,3)
		for cell in [tip,tip+Vector2i(-1,1),tip+Vector2i(1,1)]:put(rows,cell,"K",size)


static func cache_vault(rows:Array,size:int):
	var c=center(size,"cache")
	# Sandbag horseshoe open towards the HQ, with two barrels at its horns.
	for x in range(-2,3):put(rows,c+Vector2i(x,-2),"B",size)
	for y in range(-1,1):
		put(rows,c+Vector2i(-2,y),"B",size);put(rows,c+Vector2i(2,y),"B",size)
	put(rows,c+Vector2i(-3,1),"X",size);put(rows,c+Vector2i(3,1),"X",size)
	for x in [-4,4]:put(rows,c+Vector2i(x,-1),"T",size)

static func hold_redoubt(rows:Array,size:int):
	var c=center(size,"hold")
	# Broken brick ring around the zone with four gaps, concrete at the diagonals.
	for dir in [Vector2i(1,1),Vector2i(-1,1),Vector2i(1,-1),Vector2i(-1,-1)]:
		put(rows,c+dir*2+Vector2i(dir.x,0),"C",size);put(rows,c+dir*2+Vector2i(0,dir.y),"B",size)
	for x in [-5,5]:
		put(rows,c+Vector2i(x,2),"B",size);put(rows,c+Vector2i(x,3),"T",size)

static func survive_shelters(rows:Array,size:int,rng:RandomNumberGenerator):
	var c=center(size,"survive")
	# Six short concrete shelters in two mirrored rows; barrels between them punish standing still.
	for row in [-3,2]:
		for x in [-4,0,4]:
			if x==0 and row==-3:continue
			put(rows,c+Vector2i(x,row),"C",size);put(rows,c+Vector2i(x+1,row),"C",size)
	for i in range(4):
		var side=1 if i%2==0 else -1
		put(rows,c+Vector2i(side*rng.randi_range(2,3),rng.randi_range(-1,1)),"X",size)

## Dark maze. Nodes sit on odd cells; a depth-first carve gives a perfect maze, then extra openings add
## routes: ★ many (size), ★ fewer (size/3), ★★ one. The entrance opens from the HQ area in the middle.
## Walls are concrete (indestructible). The same seed gives the same maze and goal.
static func maze_plan(size:int,seed_value:int,difficulty:int)->Dictionary:
	var rng=RandomNumberGenerator.new();rng.seed=seed_value+52183
	var bottom=size-5;var last=bottom if bottom%2==1 else bottom-1
	var open={}
	var nodes=[]
	for y in range(1,last+1,2):
		for x in range(1,size-1,2):nodes.append(Vector2i(x,y))
	var entry=Vector2i(int(size/2) if int(size/2)%2==1 else int(size/2)-1,last)
	var stack=[entry];var seen={entry:true};open[entry]=true
	while not stack.is_empty():
		var at:Vector2i=stack.back()
		var next=[]
		for dir in [Vector2i(2,0),Vector2i(-2,0),Vector2i(0,2),Vector2i(0,-2)]:
			var to=at+dir
			if to in nodes and not seen.has(to):next.append(to)
		if next.is_empty():stack.pop_back();continue
		var to:Vector2i=next[rng.randi_range(0,next.size()-1)]
		open[to]=true;open[(at+to)/2]=true;seen[to]=true;stack.append(to)
	var extra=[maxi(2,size),maxi(1,int(size/3)),1][clampi(difficulty,0,2)]
	var walls=[]
	for node in nodes:
		for dir in [Vector2i(2,0),Vector2i(0,2)]:
			var to=node+dir
			if to in nodes and not open.has((node+to)/2):walls.append((node+to)/2)
	for i in range(mini(extra,walls.size())):open[walls.pop_at(rng.randi_range(0,walls.size()-1))]=true
	for y in range(last+1,size-4):open[Vector2i(entry.x,y)]=true
	# Goal: the node farthest from the entrance by walking distance.
	var distance={entry:0};var queue=[entry];var far=entry
	while not queue.is_empty():
		var at:Vector2i=queue.pop_front()
		if distance[at]>distance[far]:far=at
		for dir in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.UP,Vector2i.DOWN]:
			var to=at+dir
			if open.has(to) and not distance.has(to):distance[to]=distance[at]+1;queue.append(to)
	return {"open":open,"goal":far,"entry":entry,"last":last}
static func maze_goal(size:int,seed_value:int,difficulty:int)->Vector2i:return maze_plan(size,seed_value,difficulty).goal
static func maze(rows:Array,size:int,seed_value:int,difficulty:int):
	var plan=maze_plan(size,seed_value,difficulty)
	for y in range(0,size-4):
		for x in range(size):
			BattleMapGenerator.put(rows,Vector2i(x,y),"." if plan.open.has(Vector2i(x,y)) else "C")
static func put(rows:Array,cell:Vector2i,kind:String,size:int):
	if cell.x<0 or cell.y<1 or cell.x>=size or cell.y>=size-4:return
	# Enemy entrances stay open: top spawn columns and side spawn rows.
	if cell.y<=1 and cell.x in [1,int(size/2),size-2]:return
	if cell.x in [0,size-1] and cell.y in [2,4]:return
	if kind!="." and cell.x in [0,1,size-2,size-1] and cell.y in [2,4]:return
	BattleMapGenerator.put(rows,cell,kind)
