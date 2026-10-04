extends RunEffect
## Глаз-алмаз (Стрелок, class path level 11): every 5th volley of the soldier always crits. The volley is marked
## through run.sure_crit_until, so every pellet of it crits, like «Выдержка» marks its volley.
const EVERY=5
var shots=0
func on_shot(_data:Dictionary):
	shots+=1
	if shots%EVERY==0:arena.run.sure_crit_until=arena.run.elapsed+.05
