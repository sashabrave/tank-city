extends Node
## Probe: gear screen in battle with ammo in slots and backpack. /tmp/r13-gear.png (+ -wide for collapsed menu).
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	get_window().size=Vector2i(1280,720)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=12;add_child(arena);arena.auto_pause_enabled=false
	await get_tree().create_timer(1.2).timeout
	Game.ammo_slot_weapons=[arena.weapon];Ammo.ensure(arena.run,arena.weapon)
	RunUpgrades.apply(arena,"burn",2);RunUpgrades.apply(arena,"cryo",1)
	arena.run.ammo_bag.append(Ammo.roll("explosive",3,5));arena.run.ammo_bag.append(Ammo.roll("shock",0,9))
	arena.pause_battle();await get_tree().create_timer(.6).timeout
	var tablet=get_tree().root.find_children("*","Control",true,false).filter(func(n):return n.get_script()==preload("res://scripts/ui/field_tablet.gd"))
	if tablet.is_empty():print("NO TABLET");get_tree().quit();return
	var t=tablet[0];t.tab="inventory";t.page_scrolls={};t.refresh();await get_tree().create_timer(.6).timeout
	for s in t.find_children("GearScroll","ScrollContainer",true,false):s.scroll_vertical=0
	await get_tree().create_timer(.2).timeout
	await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-gear.png")
	t.nav_collapsed=true;t.page_scrolls={};t.refresh();await get_tree().create_timer(.8).timeout
	for s in t.find_children("GearScroll","ScrollContainer",true,false):s.scroll_vertical=0
	await get_tree().create_timer(.2).timeout
	await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-gear-wide.png")
	get_tree().quit()
