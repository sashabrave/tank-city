class_name RoutePlan
extends RefCounted
## Stable per-run graph. Branches never consume combat randomness.
static func build(seed_value:int)->Array:
	var rng=RandomNumberGenerator.new();rng.seed=seed_value+830021+Campaign.world*991+Campaign.cycle*19391
	var plan=[]
	for stage in range(Campaign.SIZES.size()):
		var count=1 if stage in Campaign.BOSSES else 3
		var levels=[0,1,2]
		for i in range(2,0,-1):
			var j=rng.randi_range(0,i);var swap=levels[i];levels[i]=levels[j];levels[j]=swap
		var nodes=[]
		for lane in range(count):
			var level=2 if stage in Campaign.BOSSES else levels[lane]
			nodes.append({"id":"%d:%d" % [stage,lane],"stage":stage,"lane":lane,"difficulty":level,"elite":level>0,"next":[]})
		plan.append(nodes)
	for stage in range(plan.size()-1):
		var from=plan[stage];var to=plan[stage+1]
		if from.size()==1 or to.size()==1:
			for node in from:
				for target in to:node.next.append(target.id)
		else:
			# Three continuing roads and one nearby fork, never crossing diagonals.
			for lane in range(from.size()):from[lane].next.append(to[lane].id)
			var lane=rng.randi_range(0,1)
			if rng.randf()<.5:from[lane].next.append(to[lane+1].id)
			else:from[lane+1].next.append(to[lane].id)
	return plan
static func chosen(plan:Array,stage:int,choices:Dictionary)->Dictionary:
	var id=choices.get(stage,choices.get(str(stage),""))
	for node in plan[stage]:
		if node.id==id:return node
	return plan[stage][0]
static func reachable(plan:Array,stage:int,choices:Dictionary)->Array:
	if stage==0:return plan[0].map(func(n):return n.id)
	return chosen(plan,stage-1,choices).next
static func point(node:Dictionary,count:int)->Vector3:
	return Vector3((node.lane-(count-1)*.5)*6.5,0,-node.stage*10.4)
static func chest_alloy(stage:int,elite:bool)->int:
	var full=Balance.CONFIG.economy.chest_alloy+Campaign.progress_index(stage)*Balance.CONFIG.economy.chest_alloy_per_room
	return full if elite else maxi(15,roundi(full*.3))
static func reward_text(stage:int,elite:bool)->String:
	return "%d ◈ / чертёж / секрет" % chest_alloy(stage,true) if elite else "%d ◈ / малое усиление" % chest_alloy(stage,false)

static func commander_kind(seed_value:int,stage:int,node_id:String="")->String:
	return WaveDirector.commander_entry(seed_value,stage,node_id).kind
static func path_to(plan:Array,stage:int,node_id:String)->Dictionary:
	var choices={stage:node_id}
	for previous in range(stage-1,-1,-1):
		for node in plan[previous]:
			if choices[previous+1] in node.next:choices[previous]=node.id;break
	return choices
