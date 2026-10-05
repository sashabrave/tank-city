extends RefCounted
# One 0.48-second timeline; gameplay and UI unlock together at its end. The hero is the practice run's soldier
# (the arena's Actor, one field engine): he comes out of the printer or in through the gate, then walks on his own.
static func play(hub:Node3D):
	hub.phase="intro";hub.root.hide();hub.intro_camera=true
	var hud=hub.arena.hud if is_instance_valid(hub.arena) else null
	if is_instance_valid(hud):hud.visible=false
	Game.reset_input()
	var camera=hub.get_viewport().get_camera_3d()
	var original=camera.position;var size=camera.size
	var returning=Game.return_through_gate;Game.return_through_gate=false
	var focus=(Vector3(5,0,-2) if returning else hub.printer_pos)+Vector3(0,.55,0)
	var hero=hub.avatar
	var goal=Vector3(5,0,0) if returning else Vector3(3,0,1)
	hub.place_hero(Vector3(5,0,-2) if returning else hub.printer_pos)
	var facing=Vector2i.DOWN if returning else Vector2i.UP
	hero.facing=facing;hero.model.rotation.y=hero.angle_for(facing)
	hero.scale=Vector3.ONE if returning else Vector3.ONE*.01
	var ring=hub.printer_model.find_child("ScanRing",true,false)
	var timeline=hub.create_tween().set_parallel(true)
	timeline.tween_property(camera,"position",original+focus*.3,.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	timeline.tween_property(camera,"size",size*.87,.10)
	timeline.tween_property(camera,"position",original,.38).set_delay(.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	timeline.tween_property(camera,"size",size,.38).set_delay(.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	timeline.tween_property(hero,"scale",Vector3.ONE,.10).set_delay(.04)
	timeline.tween_property(hero,"position",goal,.30).set_delay(.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if ring and not returning:
		var rest=ring.position
		timeline.tween_property(ring,"position:y",1.25,.12)
		timeline.tween_property(ring,"position:y",.38,.18).set_delay(.12)
		timeline.tween_property(ring,"position",rest,.18).set_delay(.30)
	timeline.chain().tween_callback(func():
		if is_instance_valid(hero):hero.scale=Vector3.ONE
		if is_instance_valid(hub.avatar):hub.place_hero(goal)
		hub.phase="combat";hub.root.show();hub.intro_camera=false
		if is_instance_valid(hud):hud.visible=true
		Game.reset_input();hub.show_arrival())
