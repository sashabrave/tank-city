extends RefCounted
static func play(arena,base_destroyed:bool,done:Callable):
	var focus=arena.world_pos(arena.base_cell) if base_destroyed else arena.player.position if is_instance_valid(arena.player) else arena.world_pos(arena.base_cell)
	var camera=arena.camera
	if is_instance_valid(arena.presentation):
		arena.presentation.set_process(false)
		arena.presentation.heading.hide();arena.presentation.caption.hide()
		if arena.presentation.text_tween and arena.presentation.text_tween.is_valid():arena.presentation.text_tween.kill()
	var tween=arena.create_tween().set_parallel(true)
	var hold=.35
	tween.tween_property(camera,"position",camera.position+(focus-camera.position+Vector3(0,19,14).rotated(Vector3.UP,deg_to_rad(10)))*.25,.42).set_trans(Tween.TRANS_SINE)
	tween.tween_property(camera,"size",camera.size*.82,.42).set_trans(Tween.TRANS_SINE)
	if base_destroyed:
		if is_instance_valid(arena.base_model):arena.base_model.hide()
		var wreck=Visuals.model("base",arena,focus);wreck.rotation.y=PI/2
		tween.tween_property(wreck,"rotation:z",.24,.55);tween.tween_property(wreck,"position:y",-.15,.55)
		arena.burst(focus+Vector3.UP*.7,Color("e78b45"),2.0)
		var rng=RandomNumberGenerator.new();rng.randomize()
		for i in range(9):
			var bit=Visuals.box(arena,focus+Vector3(0,.7,0),Vector3(.25,.18,.3),Color("69775c") if i%2 else Color("343b36"))
			var target=focus+Vector3(rng.randf_range(-1.7,1.7),.12,rng.randf_range(-1.4,1.4))
			tween.tween_property(bit,"position",target,.55);tween.tween_property(bit,"rotation",Vector3(rng.randf()*3,rng.randf()*3,rng.randf()*3),.55)
		Game.sound("vehicle_destroy",arena)
	else:
		var fallen=Visuals.model("soldier",arena,focus)
		Visuals.equip_model(fallen,arena.weapon)
		if is_instance_valid(arena.player):
			fallen.rotation.y=arena.player.rotation.y;arena.player.hide()
			if is_instance_valid(arena.player.model):fallen.rotation.y=arena.player.model.global_rotation.y
		if fallen.has_method("play_death") and fallen.play_death():hold=.8
		else:
			tween.tween_property(fallen,"rotation:z",PI/2,.38).set_trans(Tween.TRANS_QUAD)
			tween.tween_property(fallen,"position:y",.12,.38)
	tween.chain().tween_interval(hold);tween.chain().tween_callback(done)
