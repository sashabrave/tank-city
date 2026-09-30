class_name RoutePlan
extends RefCounted
## Stable per-run graph. Branches never consume combat randomness.
## One spacing for every map object: stages, service rows and the start pad.
const STAGE_STEP=11.2
## World 1: difficulty levels offered on each regular stage (0 simple, 1 ★, 2 ★★). Hard rooms appear later.
const WORLD1_LEVELS=[[0,0,1],[0,1,1],[0,1,2],[0,1,2],[1,1,2],[1,2,2]]
## World 1: service points mixed into regular stages as ordinary nodes, one per listed stage range.
const WORLD1_SPECIALS=[{"type":"mechanic","stages":[1,2]},{"type":"workshop","stages":[3,4]}]
const SERVICE_BRANCH={"mechanic":"vehicle","workshop":"headquarters"}
static func gradual()->bool:return Campaign.world==1
static func node_branch(node:Dictionary)->String:return SERVICE_BRANCH.get(node.get("type","battle"),"")
static func build(seed_value:int)->Array:
	var rng=RandomNumberGenerator.new();rng.seed=seed_value+830021+Campaign.world*991+Campaign.cycle*19391
	var plan=[]
	for stage in range(Campaign.SIZES.size()):
		var count=1 if stage in Campaign.BOSSES else 3
		var levels=[0,1,2] if not gradual() or stage>=WORLD1_LEVELS.size() else WORLD1_LEVELS[stage].duplicate()
		for i in range(2,0,-1):
			var j=rng.randi_range(0,i);var swap=levels[i];levels[i]=levels[j];levels[j]=swap
		var nodes=[]
		for lane in range(count):
			var level=2 if stage in Campaign.BOSSES else levels[lane]
			nodes.append({"id":"%d:%d" % [stage,lane],"stage":stage,"lane":lane,"difficulty":level,"elite":level>0,"next":[],"type":"battle"})
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
	# Endless has no map, so its rooms stay battles.
	if gradual() and not Campaign.endless:
		for special in WORLD1_SPECIALS:
			var stage=special.stages[rng.randi_range(0,special.stages.size()-1)]
			if stage>=plan.size() or plan[stage].size()<2:continue
			var node=plan[stage][rng.randi_range(0,plan[stage].size()-1)]
			node.type=special.type;node.difficulty=0;node.elite=false
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
	return Vector3((node.lane-(count-1)*.5)*6.5,0,-node.stage*STAGE_STEP)
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
