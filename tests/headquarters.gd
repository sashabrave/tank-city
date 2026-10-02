extends Node3D
func _ready():call_deferred("run")
func shot(id):
	if DisplayServer.get_name()=="headless":return
	RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("/tmp/hq_"+id+".png")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades()
	# HQ support sits on 2 since 0.3; Q is the class ability.
	assert(InputMap.has_action("hq_ability") and Settings.DEFAULT_KEYS.hq_ability==KEY_2 and Settings.DEFAULT_KEYS.class_ability==KEY_Q)
	assert(Game.hq_modules.is_empty() and HQCatalog.available("hq_medbay") and not HQCatalog.available("hq_tesla"))
	Game.credits=5000
	assert(not Game.build_workshop("headquarters"))
	Game.research_unlocks.append("headquarters");assert(Game.build_workshop("headquarters"))
	# One HQ slot in the hub: a newly equipped tech replaces the previous one; more come from battle cards.
	assert(Game.equip_hq("hq_patch"));assert(Game.equip_hq("hq_plating"));assert(Game.hq_active=="" and Game.hq_modules==["hq_plating"])
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.phase="combat";arena.set_physics_process(false)
	assert(is_equal_approx(Game.death_loss_fraction(),.4))
	Game.progression.insurance=1;assert(is_equal_approx(Game.death_loss_fraction(),.35))
	Game.progression.insurance=6;assert(is_equal_approx(Game.death_loss_fraction(),.2))
	assert(not Game.buy_insurance());Game.progression.insurance=0
	var h=arena.headquarters
	assert(arena.base_max_hp==8)
	h.modules=["hq_medbay","hq_plating"];h.active="hq_patch";h.room_started();assert(arena.base_max_hp==8)
	var panel=load("res://scripts/headquarters/battle_panel.gd").new();panel.arena=arena;arena.hud.root.add_child(panel)
	h.active="";panel._process(0)
	assert(not panel.button.visible and panel.display.action=="")
	assert(panel.automatics[0].display.key_hint=="" and panel.automatics[0].display.cooling)
	assert(not panel.automatics[1].display.cooling)
	h.active="hq_field";h.shield_time=4;panel._process(0)
	assert(panel.button.visible and panel.display.action=="hq_ability" and panel.display.active==4)
	h.shield_time=0;h.active="hq_patch";h.cooldown=25;panel._process(0)
	assert(panel.display.cooling and is_equal_approx(panel.display.progress,.5))
	h.cooldown=0;panel.queue_free()
	# Supply never arrives during countdown; every 90 combat seconds.
	arena.phase="countdown";h.tick(100);assert(arena.pickups.is_empty())
	arena.phase="combat";h.tick(89);assert(arena.pickups.is_empty())
	h.tick(1);assert(arena.pickups.size()==1 and arena.pickups[0].kind=="heart")
	h.tick(89);assert(arena.pickups.size()==1)
	h.tick(1);assert(arena.pickups.size()==2)
	arena.phase="upgrade";h.tick(300);assert(arena.pickups.size()==2)
	arena.phase="combat";h.tick(90);assert(arena.pickups.size()==3)
	var pickup=arena.pickups[0];arena.soldier_hp=1;arena.player.hp=1;arena.reward.collect_pickup(pickup);assert(arena.soldier_hp>1)
	arena.base_hp=3;assert(h.cast());assert(arena.base_hp==6 and not h.cast())
	Game.set_all_recipes(true);Game.progression.level=4
	h.apply("hq_swap:hq_field:0",1);assert(h.cooldown>=55);h.cooldown=0;assert(h.cast());var health=arena.base_hp;arena.combat.damage_base(1);assert(arena.base_hp==health)
	h.shield_time=0;arena.combat.damage_base(1);assert(h.hit_delay==6)
	h.modules=["hq_regen"];h.timers.hq_regen=0;h.tick(1);assert(arena.base_hp==health-1);h.tick(6);assert(arena.base_hp>health-1)
	var foe=arena.spawn_actor("soldier",Vector2i(3,3),false);foe.set_physics_process(false);foe.position=h.origin()+Vector3(1,0,-1);var hp=foe.hp
	assert(h.trigger("hq_tesla"));assert(foe.dead or foe.hp<hp)
	var bullet=load("res://scenes/projectile.tscn").instantiate();bullet.arena=arena;bullet.position=h.origin()+Vector3(1,0,0);arena.add_child(bullet);arena.projectiles.append(bullet);assert(h.trigger("hq_interceptor") and bullet.spent)
	h.modules=["hq_medbay","hq_plating"];h.active="hq_patch"
	# HQ cards come from the headquarters service stop on the route, not from ordinary wave rewards.
	var offers=arena.reward.service_offers("headquarters");assert(not offers.is_empty() and offers.all(func(o):return o.id.begins_with("hq_")))
	arena.phase="upgrade";arena.upgrade_offers=offers
	arena.hud._show_upgrades_now();await get_tree().create_timer(.3).timeout;shot("cards")
	arena.queue_free();await get_tree().process_frame
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub);await get_tree().create_timer(.3).timeout;shot("hub")
	hub.open_station("hq");await get_tree().create_timer(.3).timeout;shot("workbench")
	assert(Game.upgrade_hq("hq_medbay"))
	# Profile round trip only inside a fresh temporary folder (profile, backups and slot index).
	Game.profiles.directory="/tmp/war-cats-hq-%d" % Time.get_ticks_usec();DirAccess.make_dir_recursive_absolute(Game.profiles.directory);Game.profiles.active=1;Game.profiles.selected=true;Game.save_path=Game.profiles.path(1)
	Game.save_enabled=true;assert(Game.save_progress());Game.hq_unlocks=[];Game.hq_levels={};Game.load_progress();assert("hq_tesla" in Game.hq_unlocks and Game.hq_levels.hq_medbay==1);Game.save_enabled=false
	print("HQ PASS: recipe/build/gates, repeating medkit/pause timing, heal, Q cooldown, shield, regeneration, Tesla, interceptor, cards, workbench, save/load")
	get_tree().quit()
