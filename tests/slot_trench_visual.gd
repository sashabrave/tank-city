extends Node
## Window shots: merchant slot machine (/tmp/r13-slot-*.png) and the trench hint chip (/tmp/r13-trench-*.png).
## Profile and settings writes stay disabled.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func settle():
	for i in range(3):await get_tree().process_frame
func shot(path:String):
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png(path)
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Settings.values.fullscreen=false;Settings.apply()
	get_window().size=Vector2i(1600,900)
	Campaign.configure(1);Game.profiles.selected=true
	var main=load("res://scenes/main.tscn").instantiate();add_child(main);await settle()
	main.start_run();await settle()
	main.enter_room(0,RoutePlan.build(Game.visual_run_seed)[0][1].id);await settle()
	var arena=main.run_arena;arena.auto_pause_enabled=false
	# Trench: player beside it, then inside, then crouched.
	var cell=arena.find_free_near(arena.player.cell+Vector2i(2,0));arena.add_trench(cell)
	arena.player.cell=cell+Vector2i(-1,0);arena.player.position=arena.world_pos(arena.player.cell)
	await get_tree().create_timer(.4).timeout
	var chip=arena.room.trenches[cell].find_child("TrenchHint",true,false)
	check(chip!=null and chip.visible,"chip shows beside the trench")
	var near_size=chip.size if chip else Vector2.ZERO
	await shot("/tmp/r13-trench-near.png")
	arena.set_physics_process(false)
	arena.player.cell=cell;arena.player.position=arena.world_pos(cell);arena.board.occupy_trench(arena.player,cell);arena.player.hidden_in_trench=false
	await get_tree().create_timer(.2).timeout
	var stand_size=chip.size;await shot("/tmp/r13-trench-inside.png")
	arena.player.hidden_in_trench=true;await get_tree().create_timer(.2).timeout
	check(chip.size==stand_size,"crouch toggle keeps the chip size (%s / %s)" % [stand_size,chip.size])
	check(near_size.y==chip.size.y,"one height in every state")
	await shot("/tmp/r13-trench-crouched.png")
	arena.set_physics_process(true)
	main.show_map(1);await settle();main.show_map(2);await settle()
	arena.run.tokens=20
	main.show_service("merchant",2);await get_tree().create_timer(.6).timeout
	var shop=main.current
	shop.cell=Vector2i(2,0);shop.destination=Vector3(2,0,0);shop.avatar.position=Vector3(2,0,0);shop.avatar.rotation.y=0
	await get_tree().create_timer(.5).timeout
	await shot("/tmp/r13-slot-room.png")
	shop.interact();await get_tree().create_timer(.3).timeout
	await shot("/tmp/r13-slot-spin.png")
	await get_tree().create_timer(.65).timeout
	await shot("/tmp/r13-slot-result.png")
	check(shop.find_child("SlotWindow",true,false)!=null,"verdict visible before closing")
	await get_tree().create_timer(.9).timeout
	check(shop.modal==null,"window closed")
	if is_instance_valid(main.run_arena):main.run_arena.free()
	main.queue_free();await settle()
	print("SLOT TRENCH: %d failures" % failures);get_tree().quit(1 if failures else 0)
