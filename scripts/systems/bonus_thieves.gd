extends RefCounted
## Bonus thieves (T-072): an enemy that walks over a field bonus lying on the ground for a while grabs it and
## gets a cheeky, short buff — and it shows: a ring in the bonus colour, the bonus spinning over its head and a
## coloured frame on its health bar. Kill the thief and the bonus drops back out where it fell.
## Combat RNG is not touched; everything here is deterministic from positions and time.
const DURATION=12.0
## A bonus must lie this long before enemies notice it: the hero always gets the first chance.
const NOTICE=4.0
const GRAB_RANGE=.65
const EFFECTS={
	"heart":["fat","отъелся аптечкой"],"repair":["fat","подлатался ремкомплектом"],"vehicle_repair":["fat","натянул бронежилет"],
	"pressure":["rapid","разогнал затвор"],"turret":["rapid","прикрутил турельный приклад"],
	"freeze":["armor","покрылся льдом"],"wall":["armor","нацепил кирпичную каску"],
	"vehicle":["fast","нашёл педаль газа"],"star":["star","стал звездой"],
}
var arena
var thieves:Array=[]
func _init(context):arena=context
func is_thief(actor)->bool:return thieves.any(func(t):return t.actor==actor)
## Damage multiplier for a thief with armour (ice or brick): half damage.
func incoming(actor,amount:float)->float:
	for t in thieves:
		if t.actor==actor and t.effect=="armor":return amount*.5
	return amount
func tick(_delta:float):
	var room=arena.room
	for pickup in room.pickups.duplicate():
		if pickup.kind not in EFFECTS or not pickup.has("land_at"):continue
		if arena.run.elapsed<float(pickup.land_at)+NOTICE:continue
		for actor in room.actors:
			if not is_instance_valid(actor) or actor.dead or actor.player_owned or actor.allied or actor.kind=="boss" or is_thief(actor):continue
			if arena.flat_distance(actor.position,pickup.node.position)<GRAB_RANGE:steal(actor,pickup);break
	for t in thieves.duplicate():
		var actor=t.actor
		if not is_instance_valid(actor) or actor.dead:
			# Revenge: the stolen bonus falls out where the thief went down.
			thieves.erase(t)
			arena.reward.place_pickup(arena.grid_pos(t.last),t.kind,.5)
			arena.toast(Texts.render("Бонус отбит!"))
			continue
		t.last=actor.position
		if arena.run.elapsed>=t.until:end(t)
func steal(actor,pickup:Dictionary):
	arena.room.pickups.erase(pickup);preload("res://scripts/battle_stage.gd").vanish(pickup.node)
	var kind:String=pickup.kind;var info=arena.LOOT.BONUSES[kind];var color=Color(info.color)
	var effect:String=EFFECTS[kind][0]
	var t={"actor":actor,"kind":kind,"effect":effect,"until":arena.run.elapsed+DURATION,"last":actor.position,"speed":actor.speed,"interval":actor.fire_interval,"nodes":[]}
	match effect:
		"fat":
			actor.max_hp*=1.5;actor.hp=actor.max_hp
			if is_instance_valid(actor.model):actor.model.create_tween().tween_property(actor.model,"scale",actor.model.scale*1.22,.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		"rapid":actor.fire_interval*=.5
		"fast":actor.speed*=1.6
		"star":actor.invulnerable=6.0;actor.speed*=1.25
	actor.refresh_health()
	# Telltales: bonus-coloured ring, the bonus itself spinning over the head, a frame on the health bar.
	var ring=Visuals.ring(actor,color,.5);t.nodes.append(ring)
	var holder=Node3D.new();actor.add_child(holder);holder.position.y=1.55;holder.scale=Vector3.ONE*.45
	arena.LOOT.visual(holder,kind);t.nodes.append(holder)
	holder.create_tween().set_loops().tween_property(holder,"rotation:y",TAU,1.6).from(0.0)
	if actor.health_label:actor.health_label.accent=color;actor.health_label.rendered_key=Vector2i(-1,-1);actor.refresh_health()
	thieves.append(t)
	arena.burst(actor.position+Vector3.UP*.6,color,.7);Game.sound("pickup",actor)
	arena.toast(Texts.render("Враг")+" "+Texts.render(EFFECTS[kind][1])+"!")
func end(t:Dictionary):
	thieves.erase(t);var actor=t.actor
	actor.speed=t.speed;actor.fire_interval=t.interval
	for node in t.nodes:
		if is_instance_valid(node):node.queue_free()
	if actor.health_label:actor.health_label.accent=Color.TRANSPARENT;actor.health_label.rendered_key=Vector2i(-1,-1);actor.refresh_health()
