extends "res://tests/balance_v09.gd"
var reported=false
func _ready():
	super._ready()
	arena.begin_room(12)
func _physics_process(delta):
	if reported:return
	super._physics_process(delta)
	if finished or ticks>=7200:
		reported=true
		print("INFANTRY LATE PLAYTEST seed=%d stage=%d kills=%d time=%.1f hp=%.2f base=%.2f alive=%s" % [seed_value,arena.room_index+1,arena.kills,arena.elapsed,arena.soldier_hp,arena.base_hp,arena.soldier_hp>0])
		get_tree().quit()
