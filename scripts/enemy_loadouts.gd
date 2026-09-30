class_name EnemyLoadouts
extends RefCounted
## Each basic infantry cycle spends the same damage budget. No extra wave cost.
const BASIC=["pistol","shotgun","smg","rifle"]
const PROFILES={
	"pistol":{"shots":1,"gap":0.0,"pellets":1,"spread":0.0,"range":5.0},
	"shotgun":{"shots":1,"gap":0.0,"pellets":3,"spread":.12,"range":3.5},
	"smg":{"shots":3,"gap":.13,"pellets":1,"spread":0.0,"range":4.5},
	"rifle":{"shots":2,"gap":.22,"pellets":1,"spread":0.0,"range":7.0}}
static func default_for(kind:String)->String:
	return {"soldier":"rifle","shield":"shotgun","sniper":"sniper","grenadier":"grenade_launcher"}.get(kind,"")
static func profile(id:String)->Dictionary:return PROFILES.get(id,PROFILES.rifle)
static func model_for(kind:String,weapon:String)->String:
	return "rpg_soldier" if kind=="grenadier" and weapon=="rpg" else kind
static func fire_volley(actor):
	var data=profile(actor.enemy_weapon)
	for i in range(data.pellets):
		var bullet=actor.arena.spawn_bullet(actor,actor.position,actor.burst_direction,actor.damage*(.55 if actor.enemy_weapon=="smg" and Campaign.world==1 and actor.arena.room_index<3 else .8 if actor.enemy_weapon=="smg" and Campaign.world==1 and actor.arena.room_index<6 else 1.0),false)
		# One target can take damage only once per trigger pull, including invulnerability/shields.
		bullet.hit_actors=actor.volley_hits
		bullet.pressure=actor.pressure()/float(data.shots*data.pellets)
		bullet.travel_direction=bullet.travel_direction.rotated(Vector3.UP,(i-(data.pellets-1)*.5)*data.spread)
		bullet.rotation.y=atan2(-bullet.travel_direction.x,-bullet.travel_direction.z)
		bullet.lifetime=data.range/bullet.speed
	actor.model.kick()
static func begin(actor):
	var data=profile(actor.enemy_weapon)
	actor.volley_hits=[]
	actor.burst_direction=actor.facing;actor.pending_shots=data.shots-1;actor.burst_delay=data.gap
	fire_volley(actor)
static func tick(actor,delta:float):
	if actor.pending_shots<=0:return
	if actor.arena.abilities.cloak_time>0:actor.pending_shots=0;return
	actor.burst_delay-=delta
	if actor.burst_delay<=0:
		fire_volley(actor);actor.pending_shots-=1;actor.burst_delay=profile(actor.enemy_weapon).gap
