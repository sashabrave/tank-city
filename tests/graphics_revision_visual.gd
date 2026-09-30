extends Node
func _ready():call_deferred("run")
func shot(label:String):
	await get_tree().create_timer(.8).timeout
	await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png("res://screenshots/"+label+".png")==OK)
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	Settings.values.fullscreen=false;Settings.values.shaders=true;Settings.values.ui_theme="dark";Settings.values.world_lighting="night";Settings.apply()
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub)
	var layer=CanvasLayer.new();add_child(layer);layer.layer=200
	var tablet=load("res://scripts/ui/field_tablet.gd").new();tablet.tab="settings";tablet.settings_tab="Видео";layer.add_child(tablet)
	await shot("appearance-dark")
	Settings.change("ui_theme","light");await shot("appearance-light")
	tablet.tab="guide";tablet.guide_query="Снайпер";tablet.refresh();await shot("guide-sniper")
	layer.queue_free();hub.queue_free();await get_tree().process_frame
	Settings.change("ui_theme","dark")
	var arena=load("res://scenes/arena.tscn").instantiate();arena.auto_pause_enabled=false;add_child(arena);arena.set_physics_process(false);arena.phase="combat"
	for actor in arena.actors:actor.set_physics_process(false)
	var boss=arena.spawn_actor("boss",Vector2i(4,1),false);boss.set_physics_process(false);boss.hp=boss.max_hp*.6
	for i in range(3):
		var root=Node3D.new();arena.add_child(root);root.position=arena.player.position+Vector3(-2+i*1.5,0,-2)
		Game.LOOT.visual(root,["star","heart","repair"][i])
	await shot("boss-bonuses-night")
	Settings.change("ui_theme","light");await shot("boss-bonuses-light-ui")
	arena.queue_free();await get_tree().process_frame
	print("VISUAL PASS: appearance themes, guide artwork, boss bars, bonus glow")
	get_tree().quit()
