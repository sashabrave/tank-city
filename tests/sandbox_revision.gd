extends Node
# Sandbox: isolated profile, no automatic waves, admin actions, respawn on death, clean exit.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func settle():
	for i in range(4):await get_tree().process_frame
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Settings.values.fullscreen=false;Settings.apply()
	Game.profiles.selected=true;Game.credits=77;Game.weapon_unlocks=["pistol"]
	var main=load("res://scenes/main.tscn").instantiate();add_child(main);await settle()
	check(main.current.root.has_node("DevMenu/SandboxButton"),"hub has the sandbox button")
	main.current.sandbox_requested.emit();await settle()
	var arena=main.run_arena
	check(arena!=null and arena.sandbox and main.current==arena,"sandbox opens a field")
	check(Game.weapon_unlocks.size()==Game.LOOT.WEAPONS.size() and not Game.save_enabled,"everything unlocked, writing off")
	var admin=arena.get_node("SandboxAdmin")
	for i in range(30):arena._physics_process(.05)
	check(arena.phase=="combat" and arena.room.spawn_queue.is_empty() and not arena.room.room_cleared,"no automatic waves")
	admin.count=3;admin.spawn_enemies("tank")
	check(arena.enemy_count()==3,"admin calls enemies")
	admin.clear_enemies();check(arena.enemy_count()==0,"admin clears enemies")
	admin.rebuild({"size":21});await settle()
	check(arena.grid_size==21,"field size changes")
	admin.rebuild({"mode":"thimbles"});await settle()
	check(arena.room.mode=="thimbles" and arena.challenges.cups.size()>0,"any challenge can be started")
	admin.rebuild({"mode":"battle","waves":false});await settle()
	RunUpgrades.apply(arena,"fire",2)
	check(arena.run.upgrade_history.size()==1,"cards can be handed out")
	arena.player.invulnerable=0;arena.player.take_damage(99);await settle()
	check(is_instance_valid(arena.player) and not arena.player.dead and arena.phase=="combat","soldier respawns on the spot")
	arena.damage_base(99);await settle()
	check(arena.room.base_hp==arena.room.base_max_hp and arena.phase=="combat","HQ comes back")
	Game.earn(500)
	admin.exit_requested.emit();await settle();await settle()
	check(Game.credits==77 and Game.weapon_unlocks==["pistol"],"profile restored after exit")
	check(main.run_arena==null and main.current!=null and main.current.get_script().resource_path.ends_with("hub.gd"),"back in the hub")
	main.queue_free();await settle()
	print("SANDBOX: %d failures" % failures);get_tree().quit(1 if failures else 0)
