extends RefCounted
# One 0.48-second timeline; gameplay and UI unlock together at its end.
static func play(hub:Node3D):
	hub.phase="intro";hub.root.hide();hub.dpad.enabled=false;hub.fire_pad.enabled=false
	Game.reset_input()
	var camera=hub.get_viewport().get_camera_3d()
	var original=camera.position;var size=camera.size
	var returning=Game.return_through_gate;Game.return_through_gate=false
	var focus=(Vector3(5,0,-2) if returning else hub.printer_pos)+Vector3(0,.55,0)
	hub.avatar.position=Vector3(5,0,-2) if returning else hub.printer_pos;hub.avatar.rotation.y=0;hub.avatar.scale=Vector3.ONE if returning else Vector3.ONE*.01
	hub.facing=Vector2i.DOWN if returning else Vector2i.UP;hub.cell=Vector2i(5,0) if returning else Vector2i(3,1);hub.destination=Vector3(hub.cell.x,0,hub.cell.y);hub.avatar.rotation.y=PI if returning else 0;hub.moving=false
	var ring=hub.printer_model.find_child("ScanRing",true,false)
	var timeline=hub.create_tween().set_parallel(true)
	timeline.tween_property(camera,"position",original+focus*.3,.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	timeline.tween_property(camera,"size",size*.87,.10)
	timeline.tween_property(camera,"position",original,.38).set_delay(.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	timeline.tween_property(camera,"size",size,.38).set_delay(.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	timeline.tween_property(hub.avatar,"scale",Vector3.ONE,.10).set_delay(.04)
	timeline.tween_property(hub.avatar,"position",hub.destination,.30).set_delay(.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if ring and not returning:
		var rest=ring.position
		timeline.tween_property(ring,"position:y",1.25,.12)
		timeline.tween_property(ring,"position:y",.38,.18).set_delay(.12)
		timeline.tween_property(ring,"position",rest,.18).set_delay(.30)
	timeline.chain().tween_callback(func():
		hub.phase="combat";hub.root.show();hub.dpad.enabled=true;hub.fire_pad.enabled=true
		Game.reset_input();hub.show_arrival())
