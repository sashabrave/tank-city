extends Node3D
## Window shots of the tablet character pages during a run: Снаряжение (doll, abilities, state) and Вылазка
## (run report). Saves /tmp/r13-tablet-*.png. No profile or settings writes.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func settle(n:=3):
	for i in n:await get_tree().process_frame
func shot(name:String):
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-tablet-"+name+".png")
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	get_window().size=Vector2i(1600,900)
	var memory=preload("res://scripts/ui/tablet_memory.gd");memory.loaded=true;memory.state={}
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=41;add_child(arena);arena.auto_pause_enabled=false
	await settle(30);arena.set_physics_process(false)
	RunUpgrades.apply(arena,"burn",1);RunUpgrades.apply(arena,"burn_heat",0);RunUpgrades.apply(arena,"stun",0)
	arena.abilities.shield_time=4.0;arena.room.freeze_time=2.5
	arena.run.kills_by={"soldier":12,"tank":2,"apc":3,"zombie":5};arena.kills=22;arena.run.best_hit=87;arena.run.best_series=6;arena.run.captured=1;arena.run.damage_taken=64
	var view=preload("res://scripts/ui/field_tablet.gd").new();view.tab="inventory";view.arena=arena;add_child(view)
	await settle(10);await shot("inventory")
	check(view.find_child("Doll",true,false)!=null,"inventory shows the gear page doll")
	view.tab="fighter";view.refresh();await settle(10);await shot("fighter")
	check(view.find_child("Moment_0",true,false)!=null,"«Вылазка» shows the run report")
	view.queue_free()
	print("TABLET CHARACTER: %d failures" % failures);get_tree().quit(1 if failures else 0)
