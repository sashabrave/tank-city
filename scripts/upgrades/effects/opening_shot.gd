extends RunEffect
## Выдержка: after 1.5 s without firing, the next shot deals +40% damage.
func modify_shot_damage(value:float,_data:Dictionary)->float:
	var boosted=arena.run.elapsed-arena.run.last_player_shot>=1.5
	arena.run.last_player_shot=arena.run.elapsed
	if boosted:arena.toast("Выдержка · усиленный выстрел")
	return value*1.4 if boosted else value
