extends RefCounted
## Shader warm-up: the first time an effect appears its GPU pipelines compile inside that frame,
## which reads as a freeze on the first shots, hits and explosions. Once per session, while the first
## room loads, every combat effect is drawn a few frames below the floor and then removed.
static var done=false
static func run(arena:Node3D):
	if done or DisplayServer.get_name()=="headless":return
	done=true
	var holder=Node3D.new();holder.name="EffectWarmup";arena.add_child(holder);holder.position=Vector3(0,-2.5,0)
	var colors=[Color("ffcf79"),Color("ff5c40"),Color("fff0a0"),Color("ffb45a"),Color("ff263f"),Color("ff8e40")]
	var kinds=["bullet","shell","sniper","rocket","orb"]
	for i in range(kinds.size()):
		var slot=Node3D.new();holder.add_child(slot);slot.position=Vector3(i*.6-1.2,0,0)
		EffectLighting.projectile_visual(slot,kinds[i],colors[i])
		if kinds[i] in ["sniper","orb","rocket"]:EffectLighting.projectile_light(slot,colors[i])
	preload("res://scripts/combat_effect.gd").spawn(holder,Vector3(0,0,1),Color("e78331"),1.2)
	preload("res://scripts/combat_effect.gd").spawn(holder,Vector3(1,0,1),Color("ffbd61"),.3)
	var debris=preload("res://scripts/brick_debris.gd").shared(arena)
	debris.chips(holder.position,Vector3.FORWARD,3,"brick")
	debris.chips(holder.position,Vector3.FORWARD,2,"half",true)
	ExitFlag.build(holder)
	for currency in ["alloy","tokens","documents"]:
		var drop=load("res://scripts/resource_drop.gd").new();drop.arena=arena;drop.currency=currency;drop.denomination=20;drop.collected=true
		holder.add_child(drop);drop.position=Vector3(-1,0,-1)
	Visuals.label3d(holder,"-1",Vector3.ZERO,Color("fff0da"),33)
	# Every enemy and vehicle model: loading and first draw happen here instead of mid-fight (drones arrive at 15–30 s).
	var x=-4.0
	for kind in ["soldier","grenadier","shield","sniper","rpg_soldier","buggy","apc","tank","drone","flyer","boss"]:
		var model=Visuals.model(kind,holder,Vector3(x,0,-2));x+=.8
		model.set_process(false);model.set_physics_process(false)
	var tree=arena.get_tree()
	for i in range(4):await tree.process_frame
	if is_instance_valid(holder):holder.queue_free()
