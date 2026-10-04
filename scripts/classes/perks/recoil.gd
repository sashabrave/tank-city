extends RunEffect
## Отдача (Штурмовик, class path level 16): a hit on the soldier staggers enemy infantry within 1.5 cells for 1 s
## (they stop moving and shooting). Internal cooldown 4 s. No dice: the gameplay RNG is untouched.
const RADIUS=1.5
const STAGGER=1.0
const COOLDOWN=4.0
var ready_at=-10.0
func on_room_start(_data:Dictionary):ready_at=-10.0
func on_player_damaged(data:Dictionary):
	var actor=data.get("actor")
	if actor==null or not is_instance_valid(actor) or actor.kind!="soldier" or arena.run==null or arena.run.elapsed<ready_at:return
	var hit=false
	for other in arena.room.actors.duplicate():
		if is_instance_valid(other) and not other.dead and not other.player_owned and not other.allied and UnitKinds.is_infantry(other.kind) and arena.flat_distance(other.position,actor.position)<=RADIUS:
			CombatMods.stun(other,STAGGER);arena.burst(other.position+Vector3.UP*.4,Color("d9c08a"),.3);hit=true
	if hit:
		ready_at=arena.run.elapsed+COOLDOWN
		arena.burst(actor.position+Vector3.UP*.3,Color("f1d58a"),.9)
