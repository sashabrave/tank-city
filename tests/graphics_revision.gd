extends Node
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	Settings.values.shaders=true;Settings.values.ui_theme="dark";Settings.values.world_lighting="day";Settings.apply()
	assert(SentenceCase.normalize("ПОЛЕ 2 / 6")=="Поле 2 / 6")
	assert(SentenceCase.normalize("ВОЛНА 1 / 3 · Контакт")=="Волна 1 / 3 · Контакт")
	assert(SentenceCase.normalize("FPS · MSAA · БТР")=="FPS · MSAA · БТР")
	var arena=load("res://scenes/arena.tscn").instantiate();arena.auto_pause_enabled=false;add_child(arena)
	arena.set_physics_process(false);arena.phase="combat"
	for actor in arena.actors:actor.set_physics_process(false)
	var sun_energy=arena.get_node("WorldLighting").sun.light_energy
	Settings.change("ui_theme","light");await get_tree().process_frame
	assert(is_equal_approx(arena.get_node("WorldLighting").sun.light_energy,sun_energy))
	Settings.change("world_lighting","night");assert(Settings.values.ui_theme=="light")
	var bossbar=arena.hud.boss_bar
	assert(bossbar.get_theme_stylebox("fill").bg_color.r>.7)
	assert(bossbar.get_theme_stylebox("background").bg_color.a<.5)
	var player=arena.player;player.invulnerable=0;player.hp=10;arena.soldier_hp=10
	var shot=load("res://scenes/projectile.tscn").instantiate();shot.arena=arena;shot.sniper_round=true;shot.damage=1;shot.position=player.position+Vector3.UP*shot.SNIPER_HEIGHT;arena.add_child(shot);shot.set_physics_process(false)
	var before=player.hp
	assert(not arena.bullet_hit(shot));assert(player.hp<before and not shot.spent)
	var after=player.hp;player.invulnerable=0
	assert(not arena.bullet_hit(shot));assert(player.hp==after)
	var wall=arena.walls.keys()[0];var hp=arena.walls[wall].hp
	shot.position=arena.world_pos(wall)+Vector3.UP*shot.SNIPER_HEIGHT
	assert(not arena.bullet_hit(shot));assert(arena.walls.has(wall) and arena.walls[wall].hp==hp)
	shot.position=arena.world_pos(arena.base_cell)+Vector3.UP*shot.SNIPER_HEIGHT
	before=arena.base_hp;assert(not arena.bullet_hit(shot));assert(arena.base_hp==before-1)
	assert(not arena.bullet_hit(shot));assert(arena.base_hp==before-1)
	shot.consume()
	for i in range(8):
		var root=Node3D.new();arena.add_child(root);Game.LOOT.visual(root,"heart")
	arena.get_node("WorldLighting").update_lamps()
	assert(get_tree().get_nodes_in_group("pickup_lights").filter(func(n):return n.visible).size()<=4)
	arena.hud._process(.06);NumberDisplay.refresh()
	var frame_text=arena.hud.wave_label.text
	for i in range(4):
		arena.hud._process(.06);NumberDisplay.refresh()
		assert(arena.hud.wave_label.text==frame_text)
	arena.queue_free();await get_tree().process_frame
	print("REVISION PASS: sniper over cover/piercing once, independent UI/daynight, red boss bars, bounded pickup lights, stable sentence case")
	get_tree().quit()
