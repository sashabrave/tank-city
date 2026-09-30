class_name BattleMapGenerator
extends RefCounted

const DIRS=[Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]

static func generate(seed_value: int, room: int, reduce_obstacles:bool=true) -> Dictionary:
	var rng=RandomNumberGenerator.new();rng.seed=seed_value
	var width=Campaign.SIZES[room]
	var stage=mini(room,5)
	var middle=int(width/2.0)
	for attempt in range(80):
		var rows: Array=[]
		for y in range(width):rows.append(".".repeat(width))
		# Offset cover islands leave cross-lanes and make the two flanks different.
		for band in [2,int(width/2.0)-1,width-4]:
			for side in [0,1]:
				var x=rng.randi_range(1,middle-2) if side==0 else rng.randi_range(middle+2,width-2)
				var length=rng.randi_range(1,2)
				var material="C" if rng.randf()<.22 else "B"
				for offset in range(length):
					var y=mini(width-4,band+offset)
					put(rows,Vector2i(x,y),material)
				if rng.randf()<.65:
					var next=x+1 if side==0 else x-1
					put(rows,Vector2i(next,band),"B")
		for i in range(5+stage*2):
			var p=Vector2i(rng.randi_range(1,width-2),rng.randi_range(2,width-4))
			if p.x==middle:continue
			if rows[p.y][p.x]==".":put(rows,p,"B" if rng.randf()<.7 else "N")
		# More area needs more cover: compact islands, with at least two tiles between groups.
		if width>=20:
			for y in range(4,width-5,5):
				for x in range(3,width-3,5):
					var p=Vector2i(x+rng.randi_range(0,1),y+rng.randi_range(-1,1))
					for offset in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN]:
						var tile=p+offset
						if rows[tile.y][tile.x]==".":put(rows,tile,"C" if offset==Vector2i.ZERO else "B")
		# Protect all three central firing lanes, with independently varied depth.
		for x in range(middle-1,middle+2):
			put(rows,Vector2i(x,rng.randi_range(2,width-4)),"C")
		# Additional concrete on both flanks; reserve the open edge lanes.
		for side in [0,1]:
			for block in range(3+stage):
				var x=rng.randi_range(1,middle-2) if side==0 else rng.randi_range(middle+2,width-2)
				put(rows,Vector2i(x,rng.randi_range(2,width-4)),"C")
		# Lower barriers break easy horizontal camping lanes; retain base access.
		for side in [-1,1]:
			put(rows,Vector2i(middle+side*3,width-3),"C")
			put(rows,Vector2i(middle+side*rng.randi_range(2,4),width-5),"C")
		# Covered perimeter routes for the bomb drones. Neither lane is blocked.
		flank_nets(rows,seed_value)
		for p in [Vector2i(middle-1,width-2),Vector2i(middle,width-2),Vector2i(middle+1,width-2),Vector2i(middle-1,width-1),Vector2i(middle+1,width-1)]:put(rows,p,"B")
		put(rows,Vector2i(middle,width-1),"H")
		for i in range(2+stage):
			var trench=Vector2i(rng.randi_range(1,width-2),rng.randi_range(2,width-5))
			if rows[trench.y][trench.x]==".":put(rows,trench,"T")
		if rng.randf()<.65:
			var start=rng.randi_range(2,middle);var end=mini(width-4,start+rng.randi_range(2,5))
			for y in range(start,end+1):
				for x in range(1,middle-1):put(rows,Vector2i(width-1-x,y),rows[y][x])
		if validate(rows):
			if reduce_obstacles:thin_obstacles(rows,seed_value)
			return {"seed":seed_value,"rows":rows,"name":"Рубеж %02d" % (room+1)}
	# Guaranteed valid fallback retains the same invariants.
	var fallback_rows=[]
	for y in range(width):fallback_rows.append(".".repeat(width))
	for x in range(middle-1,middle+2):put(fallback_rows,Vector2i(x,2+rng.randi_range(0,2)),"C")
	for x in [2,width-3]:put(fallback_rows,Vector2i(x,width-5),"C")
	for x in [2,width-3]:
		for y in [2,int(width/2.0),width-4]:put(fallback_rows,Vector2i(x,y),"B")
	for p in [Vector2i(middle-1,width-2),Vector2i(middle,width-2),Vector2i(middle+1,width-2),Vector2i(middle-1,width-1),Vector2i(middle+1,width-1)]:put(fallback_rows,p,"B")
	for side in [-1,1]:
		put(fallback_rows,Vector2i(middle+side*3,width-3),"C")
		put(fallback_rows,Vector2i(middle+side*2,width-5),"C")
	put(fallback_rows,Vector2i(middle,width-1),"H")
	flank_nets(fallback_rows,seed_value)
	if reduce_obstacles:thin_obstacles(fallback_rows,seed_value)
	return {"seed":seed_value,"rows":fallback_rows,"name":"Рубеж %02d" % (room+1)}

static func flank_nets(rows:Array,seed_value:int):
	var rng=RandomNumberGenerator.new();rng.seed=seed_value+81237
	for x in [0,rows.size()-1]:
		var slots=range(1,rows.size()-1)
		for i in range(slots.size()-1,0,-1):
			var j=rng.randi_range(0,i);var swap=slots[i];slots[i]=slots[j];slots[j]=swap
		for i in range(slots.size()):put(rows,Vector2i(x,slots[i]),"N" if i<roundi(slots.size()*.75) else ".")

static func put(rows: Array,p: Vector2i,value: String):
	rows[p.y]=rows[p.y].substr(0,p.x)+value+rows[p.y].substr(p.x+1)

static func validate(rows: Array) -> bool:
	var width=rows.size()
	var middle=int(width/2.0)
	var concrete=0;var walkable=0;var central_columns={}
	for y in range(width):
		if rows[y].length()!=width:return false
		for x in range(width):
			if rows[y][x] in [".","N"]:walkable+=1
			if rows[y][x]=="C":
				concrete+=1
				if absi(x-middle)<=1:central_columns[x]=true
	if concrete<=3 or central_columns.size()!=3:return false
	var start=Vector2i(middle,width-3);var visited={start:true};var queue=[start];var head=0
	while head<queue.size():
		var p=queue[head];head+=1
		for dir in DIRS:
			var next=p+dir
			if next.x<0 or next.x>=width or next.y<0 or next.y>=width or visited.has(next):continue
			if rows[next.y][next.x] not in [".","N"]:continue
			visited[next]=true;queue.append(next)
	# Every traversable cell belongs to one connected component without breaking any brick.
	if visited.size()!=walkable:return false
	for p in [Vector2i(1,0),Vector2i(middle,0),Vector2i(width-2,0),Vector2i(middle-2,width-1),Vector2i(middle+2,width-1)]:
		if not visited.has(p):return false
	# Both full flank lanes and the lower cross-lane stay walkable.
	for y in range(width):
		if rows[y][0] not in [".","N"] or rows[y][width-1] not in [".","N"]:return false
	return true

# Visual thinning uses an independent RNG after the valid layout is selected.
# Keep base cover and one central sightline blocker in each protected column.
static func thin_obstacles(rows:Array,seed_value:int,protect_base=true):
	var width=rows.size();var middle=int(width/2.0);var groups={};var central={}
	for y in range(width):
		for x in range(width):
			var kind=rows[y][x];var cell=Vector2i(x,y)
			if kind not in ["B","C","X","R","T","N"]:continue
			if protect_base and kind=="N" and x in [0,width-1]:continue
			if protect_base and y>=width-2 and absi(x-middle)<=1:continue
			if protect_base and kind=="C" and absi(x-middle)<=1 and not central.has(x):central[x]=true;continue
			if not groups.has(kind):groups[kind]=[]
			groups[kind].append(cell)
	var rng=RandomNumberGenerator.new();rng.seed=seed_value+65029
	for kind in groups:
		var cells:Array=groups[kind];var target=roundi(cells.size()*.15)
		for i in range(cells.size()-1,0,-1):
			var j=rng.randi_range(0,i);var swap=cells[i];cells[i]=cells[j];cells[j]=swap
		for cell in cells:
			if target<=0:break
			# Opening a surrounded cell must not create an isolated pocket.
			var connected=false
			for dir in DIRS:
				var next=cell+dir
				if next.x>=0 and next.y>=0 and next.x<width and next.y<width and rows[next.y][next.x] in [".","N"]:connected=true;break
			if connected:put(rows,cell,".");target-=1
