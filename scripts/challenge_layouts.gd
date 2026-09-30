class_name ChallengeLayouts
extends RefCounted
## Hand-shaped fields for special rooms: a symmetric military frame of blocks along the edges,
## a free plaza in the middle and a mode-specific motif. The HQ area at the bottom and all enemy
## entrances (top columns, side rows 2 and 4) stay as the regular generator made them.
## Cell kinds: C concrete, B brick, K reinforced brick, T trench, R rubble (walkable), N camouflage net, X barrel.
static func center(size:int,mode:String)->Vector2i:
	return Vector2i(int(size/2),int(size/3)) if mode=="hold" else Vector2i(int(size/2),int(size/2)-1)
static func plaza_radius(mode:String)->float:
	return {"thimbles":4.6,"switches":4.2,"cache":2.2,"hold":2.2,"survive":3.0}.get(mode,0.0)
## Terrain patches (water, vegetation…) stay out of the plaza.
static func keeps_clear(size:int,mode:String,cell:Vector2i)->bool:
	return Vector2(cell-center(size,mode)).length()<plaza_radius(mode)+.8

static func apply(rows:Array,size:int,mode:String,seed_value:int):
	var keep_from=size-4 # HQ fortifications and the soldier's start
	for y in range(1,keep_from):
		for x in range(size):put(rows,Vector2i(x,y),".",size)
	var rng=RandomNumberGenerator.new();rng.seed=seed_value+4099
	frame(rows,size)
	match mode:
		"thimbles","switches":puzzle_plaza(rows,size,mode)
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

static func puzzle_plaza(rows:Array,size:int,mode:String):
	var c=center(size,mode);var r=plaza_radius(mode)
	# Rubble ring marks the plaza border; four concrete pylons guard its diagonals.
	for y in range(size):
		for x in range(size):
			var d=Vector2(Vector2i(x,y)-c).length()
			if d>=r and d<r+.9 and (x+y)%2==0:put(rows,Vector2i(x,y),"R",size)
	for dir in [Vector2i(1,1),Vector2i(-1,1),Vector2i(1,-1),Vector2i(-1,-1)]:
		put(rows,c+dir*roundi(r*.72+1),"C",size)

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

static func put(rows:Array,cell:Vector2i,kind:String,size:int):
	if cell.x<0 or cell.y<1 or cell.x>=size or cell.y>=size-4:return
	# Enemy entrances stay open: top spawn columns and side spawn rows.
	if cell.y<=1 and cell.x in [1,int(size/2),size-2]:return
	if cell.x in [0,size-1] and cell.y in [2,4]:return
	if kind!="." and cell.x in [0,1,size-2,size-1] and cell.y in [2,4]:return
	BattleMapGenerator.put(rows,cell,kind)
