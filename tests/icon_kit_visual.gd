extends Node3D
## Layered icon kit (guides/03_release/07_icon_kit_brief.md): run cards and a grid of every kit icon get
## KitIcon layers automatically through IconMotion. Window shots: /tmp/r13-icon-kit-cards.png (settled),
## /tmp/r13-icon-kit-appear.png (mid appear), /tmp/r13-icon-kit-grid.png. No profile or settings writes.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func shot(path:String):
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png(path)
func kit(rect:TextureRect)->KitIcon:
	return rect.get_meta("kit_icon") if rect.has_meta("kit_icon") and is_instance_valid(rect.get_meta("kit_icon")) else null
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	get_window().size=Vector2i(1600,900)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=4;add_child(arena);arena.auto_pause_enabled=false
	await get_tree().create_timer(1.0).timeout;arena.set_physics_process(false)
	arena.room.upgrade_offers=[{"id":"guard_blast","tier":1},{"id":"burn_long","tier":2},{"id":"health","tier":0}]
	arena.hud._show_upgrades_now()
	await get_tree().create_timer(.12).timeout
	await shot("/tmp/r13-icon-kit-appear.png")
	await get_tree().create_timer(1.1).timeout
	var icons=arena.hud.modal.find_children("Icon","TextureRect",true,false)
	check(icons.size()>=3,"three run cards with icons (%d)" % icons.size())
	for rect in icons:
		var icon=kit(rect)
		check(icon!=null and icon.parts.size()>=4,"%s: kit layers (%d)" % [icon.key if icon else "?",icon.parts.size() if icon else 0])
		check(rect.self_modulate.a==0.0,"host picture hidden under the layers")
		check(rect.get_child_count()>=1 and rect.get_child(0).name=="RarityFrame","rarity frame stays the first regular child")
	var badged=icons.filter(func(r):return kit(r) and kit(r).key=="upgrades/guard_blast")
	check(not badged.is_empty() and kit(badged[0]).parts.any(func(p):return p.kind=="badge"),"guard_blast shows the shield badge")
	await shot("/tmp/r13-icon-kit-cards.png")
	if DisplayServer.get_name()!="headless":
		var card:Control=icons[0].get_parent()
		var corner=card.get_global_rect().position+card.size*Vector2(.95,.9)
		get_viewport().warp_mouse(corner)
		var move=InputEventMouseMotion.new();move.position=corner;move.global_position=corner;Input.parse_input_event(move)
		await get_tree().create_timer(.6).timeout
		var icon=kit(icons[0])
		var shift=func(kind):
			var part=icon.parts.filter(func(p):return p.kind==kind)[0]
			return (part.node.position-part.base.position).length()
		check(icon.hovered and shift.call("symbol")>shift.call("face")+.5,"hover: layers part, symbol moves more than the base (%.1f vs %.1f px)" % [shift.call("symbol"),shift.call("face")])
		await shot("/tmp/r13-icon-kit-hover.png")
	arena.queue_free()
	await get_tree().process_frame
	var layer=CanvasLayer.new();add_child(layer)
	var back=ColorRect.new();back.color=Color("232c29");back.size=Vector2(1600,900);layer.add_child(back)
	var ids:Array=IconKit.table().icons.keys()
	var made=[]
	for i in ids.size():
		made.append(UiKit.icon(back,ids[i],Vector2(16+(i%20)*78,16+(i/20)*84),Vector2(64,64)))
	await get_tree().create_timer(.9).timeout
	var layered=made.filter(func(r):return kit(r)!=null and kit(r).parts.size()>=(1 if IconKit.table().icons[kit(r).key].group=="resource" else 3))
	check(layered.size()==ids.size(),"every kit id draws its layers (%d / %d)" % [layered.size(),ids.size()])
	var plain=UiKit.icon(back,"pistol",Vector2(16,860-70),Vector2(64,64))
	await get_tree().create_timer(.3).timeout
	check(kit(plain)!=null and kit(plain).parts.size()==1 and kit(plain).parts[0].kind=="flat","non-kit icon gets the shared motion as one flat layer")
	var glyph=TextureRect.new();glyph.texture=UiKit.interface_icon("close");back.add_child(glyph)
	await get_tree().create_timer(.2).timeout
	check(kit(glyph)==null,"interface glyphs stay still")
	await shot("/tmp/r13-icon-kit-grid.png")
	print("ICON KIT: %d failures" % failures);get_tree().quit(1 if failures else 0)
