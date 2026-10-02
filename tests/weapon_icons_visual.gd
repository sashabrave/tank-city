extends Node3D
## Weapon art check: every weapon in the HUD panel and the tablet equipment cell.
## Window shots /tmp/r13-weapon-<id>.png and /tmp/r13-weapon-tablet.png. No profile or settings writes.
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
	for id in Game.LOOT.WEAPONS:
		arena.weapon=id;await get_tree().create_timer(.15).timeout
		var art=arena.hud.weapon_icon.texture
		check(art!=null,"HUD art for "+id)
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().get_region(Rect2i(20,140,300,200)).save_png("/tmp/r13-weapon-%s.png" % id)
	arena.weapon="pistol"
	var tablet=load("res://scripts/ui/pause_tablet.gd")
	tablet.open(arena,Callable(),Callable(),"inventory")
	await get_tree().create_timer(.8).timeout
	check(get_tree().root.find_child("WeaponArt",true,false)!=null,"tablet weapon cell holds the art")
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-weapon-tablet.png")
	print("WEAPON ICONS: %d failures" % failures);get_tree().quit(1 if failures else 0)
