extends RunEffect
## Кураж (Стрелок, class path level 16): a kill whose last hit was a crit gives +15% fire rate for 3 s.
const BONUS=.15
const SECONDS=3.0
var until=-10.0
func on_room_start(_data:Dictionary):until=-10.0
func on_kill(data:Dictionary):
	var actor=data.get("actor")
	if actor==null or not is_instance_valid(actor) or not actor.get_meta("crit_hit",false):return
	if arena.run.elapsed>=until:arena.toast("Кураж · темп +15%")
	until=arena.run.elapsed+SECONDS
func modify_fire_rate(value:float,_data:Dictionary)->float:
	return value*(1.0+BONUS) if arena.run!=null and arena.run.elapsed<until else value
