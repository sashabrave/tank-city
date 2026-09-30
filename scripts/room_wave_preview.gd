extends RefCounted
## Uses the same deterministic rosters as combat; never consumes the run RNG.
static func waves(seed_value:int,room:int,difficulty:int=0,node_id:String="")->Array:
	if room in Campaign.BOSSES:
		var count=BossCatalog.encounter(seed_value,room).count
		var entries=[]
		for i in range(count):entries.append({"kind":"boss","rank":1,"weapon":"","model":BossCatalog.encounter(seed_value,room).model})
		return [entries]
	var result=[]
	for wave in range(3):result.append(WaveDirector.build(seed_value,room,wave,difficulty,node_id))
	return result

static func representatives(rosters:Array)->Array:
	var unique={}
	for wave in rosters:
		for entry in wave:
			var key=entry.get("model",EnemyLoadouts.model_for(entry.kind,entry.get("weapon","")))
			if not unique.has(key) or entry.rank>unique[key].rank:unique[key]=entry.duplicate()
	return unique.values()

static func build(parent:Node3D,rosters:Array)->Node3D:
	var display=Node3D.new();display.name="EnemyTypes";parent.add_child(display)
	var entries=representatives(rosters)
	var rows=[];var max_width=0.0;var max_depth=0.0
	for start in range(0,entries.size(),5):
		var row=[];var width=0.0
		for entry in entries.slice(start,start+5):
			var model=Visuals.model(entry.get("model",EnemyLoadouts.model_for(entry.kind,entry.get("weapon",""))),display)
			model.set_meta("enemy_type",entry.get("model",EnemyLoadouts.model_for(entry.kind,entry.get("weapon",""))))
			if entry.kind in WaveDirector.PEOPLE:Visuals.equip_model(model,entry.get("weapon",EnemyLoadouts.default_for(entry.kind)))
			Visuals.recolor_enemy(model,entry.rank);model.rotation.y=PI
			if model.has_method("equip_weapon"):model._process(.01)
			model.set_process(false)
			var bounds=Visuals.mesh_bounds(model,Transform3D.IDENTITY)
			var span=maxf(.4,bounds.size.x)+.3
			row.append({"model":model,"span":span});width+=span
			max_depth=maxf(max_depth,bounds.size.z)
		rows.append({"items":row,"width":width});max_width=maxf(max_width,width)
	var factor=minf(1.0,minf(6.2/maxf(max_width,.1),1.7/maxf(max_depth,.1)))
	for w in range(rows.size()):
		var row=rows[w];var x=-row.width*factor*.5
		for item in row.items:
			item.model.scale*=factor
			item.model.position=Vector3(x+item.span*factor*.5,.17,-1.4+w*2.1)
			x+=item.span*factor
	return display

static func cleared(parent:Node3D)->Node3D:
	var display=Node3D.new();display.name="ClearedWrecks";parent.add_child(display)
	for i in range(2):
		var tank=Visuals.model("tank",display);tank.set_process(false)
		tank.scale=Vector3.ONE*.85;tank.rotation=Vector3(.12,.4 if i==0 else -.6,2.65 if i==0 else 2.4)
		tank.set_paint("enemy")
		var bounds=Visuals.mesh_bounds(tank,Transform3D.IDENTITY)
		tank.position=Vector3(-1.5 if i==0 else 1.5,.17-bounds.position.y,-.6 if i==0 else .5)
	return display
