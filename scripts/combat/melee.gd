class_name Melee
extends RefCounted
## Close combat (2026-10-03): the cat scratches with its paws when the hands are empty (the hidden «paws» weapon,
## Space like any shot) and anyone can strike with V — the paws, or the gun's butt when a gun is in hand.
## Damage is the bare-hand base grown by «Сила» (Казарма: +5% per level), the same factor guns build on.
const REACH:=1.55       # metres in front of the soldier
const ARC:=.55          # cos of the half-angle: about ±57° around the facing
const COOLDOWN:=.45     # V strike, seconds
const BUTT:=1.25        # a gun butt hits a bit harder than bare claws

## Bare-hand damage for the HUD, the tablet and the strike: the paws' base × class/«Сила»/run bonuses.
static func damage(arena=null)->float:
	return CombatStats.weapon(arena,LootCatalog.PAWS).damage
static func armed(arena)->bool:return arena!=null and arena.get("run")!=null and LootCatalog.is_gun(str(arena.run.weapon))

## V: a strike at any moment in battle, with its own short cooldown. False while it recovers.
static func try(arena)->bool:
	var player=arena.room.player
	if not is_instance_valid(player) or player.dead or player.kind!="soldier" or arena.phase not in ["combat","countdown"]:return false
	if float(player.get_meta("melee_ready_at",0.0))>arena.run.elapsed:return false
	player.set_meta("melee_ready_at",arena.run.elapsed+COOLDOWN)
	strike(arena,player,damage(arena)*(BUTT if armed(arena) else 1.0),not armed(arena))
	return true

## Hits every enemy (and the wall) in a short arc in front of the actor; plays the swipe.
static func strike(arena,actor,amount:float,claws:=true)->int:
	var forward=Vector3(actor.facing.x,0,actor.facing.y).normalized()
	var hits=0
	for enemy in arena.room.actors.duplicate():
		if not is_instance_valid(enemy) or enemy.dead or enemy.player_owned or enemy.allied:continue
		var to=enemy.position-actor.position;to.y=0
		var reach=REACH+(.45 if enemy.kind in GarageCatalog.VEHICLES or enemy.kind=="boss" else 0.0)
		if to.length()>reach or (to.length()>.2 and to.normalized().dot(forward)<ARC):continue
		enemy.take_damage(amount,Vector3.ZERO,"","melee");hits+=1
	if hits==0:
		var cell=arena.grid_pos(actor.position+forward*.9)
		if arena.room.walls.has(cell):arena.damage_wall(cell,amount);hits=-1
	swipe(actor,arena,claws)
	Game.sound("hit_body" if hits>0 else "grenade_throw",arena)
	if hits!=0 and arena.get_node_or_null("CombatFeel"):arena.get_node("CombatFeel").hit_stop(.03)
	return hits

## The look of a strike, shared by the battle, the hub and the rooms: a lunge of the model and three claw marks
## (paws) or one wide arc (gun butt) in front. Visual only — no combat randomness.
static func swipe(actor:Node3D,parent:Node,claws:=true,toward:=Vector2i.ZERO):
	var model:Node3D=actor.get("model") if actor.get("model") is Node3D else actor
	var facing:Vector2i=toward if toward!=Vector2i.ZERO else actor.get("facing") if actor.get("facing") is Vector2i else Vector2i.UP
	var forward=Vector3(facing.x,0,facing.y).normalized()
	if is_instance_valid(model) and model!=actor:
		var base=model.position
		var lunge=model.create_tween();lunge.tween_property(model,"position",base+forward*.22,.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		lunge.tween_property(model,"position",base,.16).set_trans(Tween.TRANS_QUAD)
	if model.has_method("kick"):model.kick()
	var marks=Node3D.new();marks.name="ClawSwipe";parent.add_child(marks)
	marks.global_position=actor.global_position+forward*.75+Vector3.UP*.55
	marks.look_at(marks.global_position+forward,Vector3.UP)
	var material=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color=Color(1,.97,.9,.95) if claws else Color(1,.88,.6,.85);material.cull_mode=BaseMaterial3D.CULL_DISABLED
	var count=3 if claws else 1
	for i in range(count):
		var line=MeshInstance3D.new();var mesh=BoxMesh.new()
		mesh.size=Vector3(.05,.62,.02) if claws else Vector3(.9,.08,.02)
		line.mesh=mesh;line.material_override=material;marks.add_child(line)
		line.position=Vector3((i-(count-1)*.5)*.16,0,0);line.rotation.z=-.5 if claws else 0.0
	marks.scale=Vector3(.4,.4,.4)
	var t=marks.create_tween().set_parallel()
	t.tween_property(marks,"scale",Vector3.ONE,.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(material,"albedo_color:a",0.0,.22).set_delay(.06)
	t.chain().tween_callback(marks.queue_free)
