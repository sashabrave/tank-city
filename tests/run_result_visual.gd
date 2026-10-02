extends Node3D
## Window check of the end-of-run screen: a won sortie and a lost one (loss on the bar, coins falling),
## killed enemies by type as a staircase. Saves /tmp/r13-result-*.png. No profile or settings writes.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func settle(n:=3):
	for i in n:await get_tree().process_frame
func shot(name:String):
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-result-"+name+".png")
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	get_window().size=Vector2i(1600,900)
	for won in [true,false]:
		var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=12;add_child(arena);arena.auto_pause_enabled=false
		await settle(20);arena.set_physics_process(false)
		arena.run.earned=184;arena.run.kills=23;arena.run.elapsed=402
		arena.run.kills_by={"rifle":8,"smg":5,"shield":4,"grenade_launcher":3,"buggy":2,"commander":1}
		if not won:arena.run.lost_alloy=55;arena.base_hp=0;arena.set_meta("base_hit_by","tank");Game.backpack_slots=2
		arena.room.room_index=3
		arena.hud.show_result(won,"Поле 4 · Тихий двор" if won else "Штаб уничтожен")
		var panel=arena.hud.modal.find_child("RunResult",true,false)
		check(panel!=null,"result screen opens (%s)" % ("won" if won else "lost"))
		if not won:check(panel.find_child("DeathCause",true,false)!=null and "танк" in panel.find_child("DeathCause",true,false).text,"defeat names the killer (T-086)")
		await get_tree().create_timer(1.1 if won else .95).timeout;await shot(("won" if won else "lost")+"-mid")
		await get_tree().create_timer(2.2).timeout;await shot("won" if won else "lost")
		check(panel.find_child("Kill_rifle",true,false)!=null and panel.find_child("Kill_rifle",true,false).modulate.a>.9,"kill staircase revealed")
		var total:Label=panel.find_child("KeptTotal",true,false)
		check(total.text==str(184-(0 if won else 55)),"total shows what reaches the base: "+total.text)
		if not won:check(panel.find_child("LossValue",true,false)!=null,"loss line shown on defeat")
		arena.queue_free();await settle(3)
	print("RUN RESULT: %d failures" % failures);get_tree().quit(1 if failures else 0)
