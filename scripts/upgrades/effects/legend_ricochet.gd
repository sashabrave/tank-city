extends RunEffect
## Рикошет: every third hit of the soldier bounces into the nearest other enemy within 4 tiles for 60% damage.
var hits=0
func on_enemy_hit(data:Dictionary):
	if not is_instance_valid(arena.room.player) or arena.room.player.kind!="soldier":return
	hits+=1
	if hits%3!=0:return
	var source=data.target;var best=null;var best_d=4.0
	for other in arena.room.actors:
		if not is_instance_valid(other) or other==source or other.dead or other.player_owned or other.allied:continue
		var d=arena.flat_distance(other.position,source.position)
		if d<best_d:best=other;best_d=d
	if best==null:return
	best.take_damage(float(data.damage)*.6,Vector3.ZERO,"","")
	arena.burst(best.position+Vector3.UP*.5,Color("ffe39a"),.25);Game.sound("ricochet",arena)
