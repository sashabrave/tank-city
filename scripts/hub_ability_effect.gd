extends Node3D
var hub
var kind=""
var accepted=true
var elapsed=0.0
var duration=5.0
var tick=0.0
var power=0.0
var start=Vector3.ZERO
var target=Vector3.ZERO
var visual:Node3D
var grenade_marker:Node3D
var grenade_motion
var deployed_cell=Vector2i.ZERO
func _ready():
	power=AbilityCatalog.DATA[kind].power;position=hub.training_tank.position if hub.mounted else hub.avatar.position
	start=position;target=hub.dummy.position if "range" in Game.built_workshops else start+Vector3(hub.facing.x,0,hub.facing.y)*2
	if kind=="field_repair":visual=bubble(Color(.4,.8,.5,.2),.5);duration=.7
	elif kind=="barrier":
		deployed_cell=hub.cell+hub.facing
		if not hub.hub_free(deployed_cell):accepted=false;return
		# Cancel an in-flight step toward the newly placed obstacle.
		if hub.moving:
			var controlled=hub.training_tank if hub.mounted else hub.avatar
			controlled.position=Vector3(hub.cell.x,0,hub.cell.y);hub.moving=false
		position=Vector3(deployed_cell.x,0,deployed_cell.y);visual=Visuals.model("hedgehog",self);hub.training_barriers.append(deployed_cell);duration=20
	elif kind in ["ally_drone","comrade"]:
		visual=Visuals.model("flyer" if kind=="ally_drone" else "soldier",self,Vector3(1,0,0));duration=15
	elif kind=="laser":
		target=start+Vector3(hub.facing.x,0,hub.facing.y)*9
		visual=Visuals.box(self,(target-start)*.5+Vector3.UP*.5,Vector3(.12,.12,9),Color("79dbfa"));visual.rotation.y=atan2(target.x-start.x,target.z-start.z);duration=.35
		if absf((hub.dummy.position-start).cross((target-start).normalized()).y)<.5 and (hub.dummy.position-start).dot(target-start)>0:hit_dummy()
	elif kind=="grenade":
		target=start+Vector3(hub.facing.x,0,hub.facing.y)*5
		position=start+Vector3.UP*.8
		grenade_motion=preload("res://scripts/grenade_motion.gd").new(position,target,.65,func(probe):return probe.y<1.15 and not hub.hub_free(Vector2i(roundi(probe.x),roundi(probe.z))))
		GrenadeVisual.projectile(self,true);visual=get_node("GrenadeModel");duration=1.65
		grenade_marker=GrenadeVisual.marker(hub,target,Balance.CONFIG.combat.grenade_radius,true);grenade_marker.hide()
	elif kind=="mine":visual=Visuals.box(self,Vector3.UP*.1,Vector3(.4,.14,.4),Color("677854"));duration=20
	elif kind=="airstrike":duration=3
	elif kind=="gas":visual=preload("res://scripts/gas_cloud.gd").new(1.5,int(start.x*31+start.z*17));add_child(visual);duration=power
	elif kind=="shield":visual=bubble(Color(.45,.85,.7,.25),.6);duration=4
	elif kind=="cloak":duration=power;fade_hero(.7)
	Game.sound({"barrier":"barrier_deploy","grenade":"grenade_throw","laser":"laser_fire","shield":"shield_restore","cloak":"cloak","mine":"mine_arm"}.get(kind,"ability_generic"),hub)
func bubble(color:Color,radius:float)->MeshInstance3D:
	var node=MeshInstance3D.new();var mesh=SphereMesh.new();mesh.radius=radius;mesh.height=radius*2;node.mesh=mesh;add_child(node);node.position.y=.5
	var material=StandardMaterial3D.new();material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.albedo_color=color;node.material_override=material;return node
func hit_dummy():
	if "range" not in Game.built_workshops:return
	hub.dummy_hits+=1;Texts.set_text(hub.dummy_label,"−"+UiKit.number(power));hub.dummy.scale=Vector3(1.08,.94,1.08);hub.create_tween().tween_property(hub.dummy,"scale",Vector3.ONE,.18)
func fade_hero(amount):
	if not is_instance_valid(hub.avatar):return
	for mesh in hub.avatar.find_children("*","MeshInstance3D",true,false):mesh.transparency=amount
func _process(delta):
	if not accepted:return
	elapsed+=delta;tick+=delta
	if kind=="shield":position=hub.training_tank.position if hub.mounted else hub.avatar.position
	if kind=="grenade":
		var was_landed=grenade_motion.landed
		grenade_motion.advance(delta);position=grenade_motion.position;target=Vector3(position.x,0,position.z)
		grenade_marker.visible=grenade_motion.landed
		grenade_marker.position=target+Vector3.UP*.06
		if grenade_motion.landed and not was_landed:Game.sound("grenade_land",hub)
	if kind in ["ally_drone","comrade"] and tick>1.1:tick=0;hit_dummy()
	if kind=="airstrike" and tick>.65:
		tick=0;var streak=Visuals.box(self,target-start+Vector3.UP*2,Vector3(.12,4,.12),Color("eba862"));var tween=create_tween();tween.tween_property(streak,"scale",Vector3.ZERO,.3);tween.tween_callback(streak.queue_free);hit_dummy()
	if kind=="gas" and position.distance_to(hub.dummy.position)<1.8:Texts.set_text(hub.dummy_label,"Оглушение")
	if kind=="mine" and position.distance_to(hub.dummy.position)<1.2:duration=minf(duration,elapsed+.2)
	if elapsed>=duration:
		if kind in ["grenade","mine"]:
			if kind!="grenade" or position.distance_to(hub.dummy.position)<=Balance.CONFIG.combat.grenade_radius:hit_dummy()
			Game.sound("boom",hub)
			if kind=="grenade":GrenadeVisual.explode(hub,target,Balance.CONFIG.combat.grenade_radius,true)
		queue_free()
func _exit_tree():
	if is_instance_valid(grenade_marker):grenade_marker.queue_free()
	if kind=="cloak":fade_hero(0)
	if kind=="barrier" and is_instance_valid(hub):hub.training_barriers.erase(deployed_cell)
