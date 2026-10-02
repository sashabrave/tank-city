extends Node3D
## Upgrade cards in table view: change on the left, parameter on the right, one short sentence.
## Window shot /tmp/r13-cards-table.png. No profile or settings writes.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	get_window().size=Vector2i(1600,900)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=4;add_child(arena);arena.auto_pause_enabled=false
	await get_tree().create_timer(1.0).timeout;arena.set_physics_process(false)
	RunUpgrades.apply(arena,"burn",0)
	arena.room.upgrade_offers=[{"id":"burn_heat","tier":1},{"id":"crit_chance","tier":2},{"id":"health","tier":0}]
	arena.hud._show_upgrades_now()
	await get_tree().create_timer(1.2).timeout
	var rows=arena.hud.modal.find_children("RowValue","Label",true,false)
	check(rows.size()>=2,"cards show table rows (%d)" % rows.size())
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-cards-table.png")
	print("CARD TABLE: %d failures" % failures);get_tree().quit(1 if failures else 0)
