class_name BehaviorCards
extends RefCounted
const DATA={
"opening_shot":{"name":"Выдержка","text":"Пехота: после 1,5 с без стрельбы следующий выстрел наносит +40% урона."},
"last_stand":{"name":"Последний рубеж","text":"Пехота: при HP не выше 25% стрельба быстрее на 25%."},
"exit_dash":{"name":"Смена позиции","text":"После выхода из машины: +25% скорости на 3 с. Откат 8 с."}}
static func shot_multiplier(arena)->float:
	var boosted="opening_shot" in arena.run.behavior_cards and arena.run.elapsed-arena.run.last_player_shot>=1.5
	arena.run.last_player_shot=arena.run.elapsed
	if boosted:arena.toast("Выдержка · усиленный выстрел")
	return 1.4 if boosted else 1.0
static func rate_multiplier(arena)->float:
	return 1.25 if "last_stand" in arena.run.behavior_cards and arena.run.soldier_hp>0 and arena.run.soldier_hp<=arena.run.soldier_max_hp*.25 else 1.0
static func exited_vehicle(arena):
	if "exit_dash" not in arena.run.behavior_cards or arena.run.elapsed<arena.run.dash_ready_at:return
	arena.run.dash_until=arena.run.elapsed+3;arena.run.dash_ready_at=arena.run.elapsed+8
	arena.toast("Смена позиции · рывок 3 с")
static func speed_multiplier(arena)->float:return 1.25 if arena.run.elapsed<arena.run.dash_until else 1.0
