extends Node
var checks=0
var failures=0
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures+=1;push_error(message)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Game.reset_upgrades()
	var config=Balance.CONFIG
	check(config.weapons.size()==6 and config.abilities.size()==10 and config.enemies.size()==11,"complete editable catalogs")
	for weapon in config.weapons:check(Game.LOOT.WEAPONS[weapon.id]==weapon.as_dict(),"weapon resource consumed: "+weapon.id)
	for ability in config.abilities:check(AbilityCatalog.DATA[ability.id]==ability.as_dict(),"ability resource consumed: "+ability.id)
	var original_hp=config.enemy("soldier").health;var original_cost=config.economy.upgrade_base_cost
	config.enemy("soldier").health=7;config.economy.upgrade_base_cost=17
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false);arena.player.set_physics_process(false)
	var enemy=arena.spawn_actor("soldier",Vector2i(1,0),false);enemy.set_physics_process(false)
	check(enemy.max_hp==7,"enemy Inspector health drives spawned actors")
	check(Game.cost("health")==17,"economy Inspector cost drives purchases")
	config.enemy("soldier").health=original_hp;config.economy.upgrade_base_cost=original_cost
	arena.actors.erase(enemy);enemy.free()
	check(arena.abilities.slots.size()==1 and arena.hud.skill_buttons.size()==2 and not arena.hud.skill_buttons[1].visible,"one ability by default; maximum two UI slots")
	Game.built_workshops=["character"];Game.cores=100;Game.credits=10000
	check(not Game.buy_special("slots") and Game.cores==100,"second slot locked before giga victory")
	Game.superboss_defeated=true;var price=config.economy.second_ability_slot_documents
	check(Game.buy_special("slots") and Game.ability_slots==2 and Game.cores==100-price and Game.credits==10000,"slot costs documents after victory")
	check(not Game.buy_special("slots"),"no third slot")
	var saved_path=Game.save_path;Game.save_path="/private/tmp/editor-profile.json";Game.save_enabled=true;Game.save_progress();Game.save_enabled=false;Game.reset_upgrades();Game.load_progress();Game.save_path=saved_path
	check(Game.superboss_defeated and Game.ability_slots==2,"late slot and victory persist")
	var authored=arena.hud.top.position;arena.hud.top.position+=Vector2(9,11);arena.hud._process(.1)
	check(arena.hud.top.position==authored+Vector2(9,11),"runtime respects edited HUD placement")
	arena.hud.show_upgrades();var card=arena.hud.modal.get_node("Panel/Card1");var choice=card.get_node("ChooseButton")
	check(card.scene_file_path.ends_with("choice_upgrade.tscn") and choice.pressed.get_connections().size()==1,"shared authored reward card connected once")
	arena.hud.show_pause();check(arena.hud.modal.get_node("Panel/Inventory").get_child_count()==Game.backpack_slots,"authored inventory slots match capacity")
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub);hub.set_physics_process(false)
	check(hub.root.scene_file_path.ends_with("hub_screen.tscn"),"hub uses editable screen")
	check(hub.station.scene_file_path.ends_with("character_workshop.tscn"),"hub shares editable workshop")
	check(hub.workshop_content.get_child(0).scene_file_path.ends_with("upgrade_row.tscn"),"real upgrade rows are scene instances")
	hub.workshop_tab=3;hub.refresh();check(hub.workshop_content.find_children("*","Panel",true,false).size()==10,"all ten ability cards instantiated")
	hub.queue_free();arena.hud.close_modal()
	var rules_ok=true;var no_drones=true;var buggy_first=true
	var shares=[]
	for room in range(6):
		var people=0;var machines=0
		for seed_value in range(100):
			for wave in range(3):
				var entries=WaveDirector.build(seed_value,room,wave)
				for entry in entries:
					rules_ok=rules_ok and WaveDirector.allowed(entry.kind,entry.rank,room)
					no_drones=no_drones and entry.kind not in ["drone","flyer"]
					if entry.kind in WaveDirector.MACHINES:machines+=1
					else:people+=1
				if room==1 and wave==0:buggy_first=buggy_first and entries.any(func(e):return e.kind=="buggy")
		shares.append(machines/float(people+machines))
	check(rules_ok and no_drones and buggy_first,"all wave seeds respect progression and omit drones")
	check(shares[0]==0 and shares[1]<.25 and shares[5]>.5,"early infantry and late majority vehicles")
	arena.begin_room(0);arena.set_physics_process(false);arena.player.set_physics_process(false);arena.phase="combat"
	var roster=arena.wave_roster.duplicate(true);var queue=arena.spawn_queue.duplicate();var rng_state=arena.combat_rng.state
	arena.room.combat_elapsed=31;arena.room.surprise_timer=0;arena.surprises.tick(.1)
	check(arena.actors.any(func(a):return a.kind in ["drone","flyer"] and a.wave_slot==-1),"unexpected drone spawns outside roster")
	check(arena.wave_roster==roster and arena.spawn_queue==queue and arena.combat_rng.state==rng_state,"surprises preserve regular wave and reward RNG")
	check(arena.wave_enemy_count()==0 and arena.enemy_count()==1,"drone does not consume ordinary cap")
	var before=arena.actors.size();arena.spawn_queue.clear();arena.room.combat_elapsed=31;arena.room.surprise_timer=0;arena.surprises.tick(.1)
	check(arena.actors.size()==before,"no surprise spawning to prolong an otherwise empty wave")
	arena.room.room_cleared=true;arena.spawn_queue=["soldier"];arena.surprises.tick(30);check(arena.actors.size()==before,"no surprise after clear")
	arena.queue_free();await get_tree().process_frame
	print("EDITOR WORKFLOW: %d checks, %d failures" % [checks,failures]);get_tree().quit(1 if failures else 0)
