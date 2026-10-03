extends Node
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Settings.values.fullscreen=false;Settings.values.world_lighting="night";Settings.apply()
	var scene=Node3D.new();add_child(scene);Visuals.setup_world(scene,8,Vector3.ZERO)
	Visuals.box(scene,Vector3(0,-.1,0),Vector3(8,.15,8),Color("697969"))
	for i in range(50):
		var bullet=load("res://scripts/projectile.gd").new();bullet.sniper_visual=i%3==0;bullet.friendly=i%3==1;bullet.orb=i%3==2
		scene.add_child(bullet);bullet.position=Vector3((i%10)*.6-2.7,.65,floori(i/10.0)*.65-1.4)
	await get_tree().process_frame
	# Sniper: thin core and the longest trail of the projectile family.
	var visual=null
	for child in scene.get_children():
		if child.has_node("ProjectileVisual") and child.sniper_visual:visual=child.get_node("ProjectileVisual");break
	assert(visual!=null)
	var core=visual.get_child(2);assert(core.scale==EffectLighting.PROJECTILES.sniper.core);assert(core.material_override.shading_mode==BaseMaterial3D.SHADING_MODE_UNSHADED)
	assert(is_equal_approx(visual.get_child(0).scale.z,EffectLighting.PROJECTILES.sniper.trail))
	var halo=EffectLighting.glow(Color("ff263f"),true,true)
	assert(is_equal_approx(halo.albedo_color.a,.12*.7))
	Settings.change("world_lighting","day");assert(is_equal_approx(halo.albedo_color.a,.12*.2))
	Settings.change("world_lighting","night");assert(is_equal_approx(halo.albedo_color.a,.12*.7))
	assert(get_tree().get_nodes_in_group("projectile_lights").size()<=2)
	for i in range(25):preload("res://scripts/combat_effect.gd").spawn(scene,Vector3((i%5)-2,0,2),Color("ffad53"),.7)
	assert(get_tree().get_nodes_in_group("combat_effects").size()<=20);assert(get_tree().get_nodes_in_group("blast_lights").size()<=3)
	await get_tree().create_timer(.08).timeout
	if DisplayServer.get_name()!="headless":RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("/tmp/effect-lighting.png")
	# T-188: switching day/night mid-game drops the cached tracer materials and re-captures reflections.
	var lighting=scene.find_child("WorldLighting",true,false)
	if lighting:
		var was=Settings.values.world_lighting
		EffectLighting.glow(Color.RED,false,true);assert(not EffectLighting.materials.is_empty())
		Settings.values.world_lighting="night" if was=="day" else "day";lighting.apply()
		await get_tree().process_frame;await get_tree().process_frame
		assert(EffectLighting.materials.is_empty(),"day/night switch clears cached tracer materials")
		Settings.values.world_lighting=was;lighting.apply()
		print("PASS relight on day/night switch")
	scene.queue_free();await get_tree().process_frame
	assert(get_tree().get_nodes_in_group("projectile_lights").is_empty());assert(get_tree().get_nodes_in_group("blast_lights").is_empty())
	print("PASS 50 projectiles, short red sniper tracer, bounded effect lights and cleanup");get_tree().quit()
