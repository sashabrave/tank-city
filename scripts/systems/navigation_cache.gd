extends RefCounted
## Lazy shared quarter-grid occupancy. Dynamic units, wrecks and trench claims stay live.
var arena
var buckets:Dictionary={}
var revision=0
var base_revision=0
var hits=0
var misses=0
func _init(context):arena=context
func reset():
	buckets.clear();revision+=1;base_revision+=1;hits=0;misses=0
func invalidate(cell:Vector2i):
	if absi(cell.x-arena.base_cell.x)<=8 and absi(cell.y-arena.base_cell.y)<=8:base_revision+=1
	# Largest body is 4 cells wide; include edge buckets on both sides.
	for x in range(cell.x-3,cell.x+4):
		for y in range(cell.y-3,cell.y+4):buckets.erase(Vector2i(x,y))
	revision+=1
func is_open(pos:Vector3,actor)->bool:
	var bucket=arena.grid_pos(pos)
	var point=Vector2i(roundi(pos.x*4),roundi(pos.z*4))
	var key=[point,arena.body_size(actor),actor.kind=="flyer",actor.kind=="soldier" and not actor.player_owned]
	if not buckets.has(bucket):buckets[bucket]={}
	if buckets[bucket].has(key):hits+=1;return buckets[bucket][key]
	misses+=1
	var result=arena.can_stand(pos,actor,true,true)
	buckets[bucket][key]=result
	return result
