extends Node
var checks=0
var failures=0
func check(ok,message):
	checks+=1
	if not ok:failures+=1;push_error("FAIL: "+message)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Game.reset_upgrades()
	check(Game.weapon_unlocks==["pistol"] and Game.built_workshops.is_empty() and Game.backpack_slots==1,"fresh profile starts pistol one slot no benches")
	Game.credits=10000
	check(not Game.build_workshop("character"),"building needs blueprint")
	Game.research_unlocks=Game.RESEARCH.keys()
	for id in Game.BUILD_COST:check(Game.build_workshop(id),"build "+id)
	var money=Game.credits;check(not Game.build_workshop("weapons") and Game.credits==money,"no double construction charge")
	check(Game.bag_cost()==60 and Game.upgrade_backpack() and Game.bag_cost()==120,"backpack costs double")
	check(Game.upgrade_rerolls() and Game.reroll_level==1,"recipe unlocks reroll purchase")
	Game.weapon_unlocks=Game.LOOT.WEAPONS.keys();check(Game.equip_weapon("shotgun"),"owned weapon can be selected")
	var valid=true
	for room in range(6):
		for wave in range(3):
			for seed_value in range(100):
				var entries=WaveDirector.build(seed_value,room,wave)
				valid=valid and entries.size()==WaveDirector.COUNTS[room][wave]
				for entry in entries:valid=valid and WaveDirector.allowed(entry.kind,entry.rank,room)
	check(valid,"1800 waves follow people machinery rank ladder")
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false);arena.phase="combat";arena.spawn_queue.clear()
	check(arena.weapon=="shotgun" and arena.rerolls_left==1,"loadout and rerolls snapshot at run start")
	var before=arena.projectiles.size();arena.player.fire_cooldown=0;arena.player.shoot()
	check(arena.projectiles.size()==before+5,"shotgun fires five pellets")
	for id in Game.LOOT.WEAPONS:
		arena.weapon=id;arena.player.apply_weapon();arena.fire_weapon(arena.player)
		var bullet=arena.projectiles.back();var spec=Game.LOOT.WEAPONS[id]
		check(is_equal_approx(arena.player.damage,spec.damage) and bullet.piercing==spec.pierce and bullet.rocket_radius==spec.blast,"ballistics "+id)
	arena.weapon="pistol";arena.player.apply_weapon();var pistol=arena.player.damage
	arena.weapon_mods.pistol.damage=.18;arena.player.apply_weapon();var pistol_gain=arena.player.damage/pistol
	arena.weapon="rifle";arena.player.apply_weapon();var rifle=arena.player.damage;arena.weapon_mods.rifle.damage=.18;arena.player.apply_weapon()
	check(is_equal_approx(pistol_gain,arena.player.damage/rifle),"damage upgrades proportional for pistol and rifle")
	Game.research_unlocks=[];Game.weapon_unlocks=["pistol"];Game.bonus_unlocks=["heart"]
	var offers=Game.recipe_offers(arena.combat_rng,[])
	check(offers.size()==3 and offers[0].id=="character","first draft contains character blueprint")
	check(offers[0]!=offers[1] and offers[1]!=offers[2] and offers[0]!=offers[2],"draft recipes unique")
	arena.drop_recipe(arena.player.cell,{})
	var drop=arena.pickups.back();check(drop.kind=="recipe_draft" and arena.pending_recipes.is_empty(),"glowing drop does not auto bank recipe")
	arena.player.moving=false;arena.interact()
	check(arena.phase=="paused" and arena.draft_pickup.offers.size()==3,"E opens three recipe cards")
	arena.rerolls_left=2;arena.reroll_recipe_draft();check(arena.rerolls_left==1,"recipe draft spends shared reroll")
	Game.backpack_slots=1;arena.pending_recipes=[{"id":"star","category":"bonus"}];arena.choose_recipe_card(0)
	check(not arena.recipe_offer.is_empty() and arena.pending_recipes.size()==1,"full backpack blocks recipe claim")
	arena.discard_recipe(0);arena.take_offered_recipe()
	check(arena.pending_recipes.size()==1 and arena.pickups.is_empty(),"discard then take consumes draft once")
	arena.room_cleared=true;arena.resolve_recipes_on_return()
	check(arena.pending_recipes.is_empty() and "character" in Game.research_unlocks,"delivered build blueprint saved")
	Game.research_unlocks=Game.RESEARCH.keys();Game.weapon_unlocks=Game.LOOT.WEAPONS.keys();Game.bonus_unlocks=Game.LOOT.BONUSES.keys()
	offers=Game.recipe_offers(arena.combat_rng,[])
	check(offers.all(func(o):return o.category=="upgrade" and o.tier in [0,1,2]),"complete collection gives random tier stat cards")
	arena.phase="upgrade";arena.next_is_room=false;arena.reward_claimed=false;arena.hud.show_upgrades();arena.rerolls_left=1
	check(arena.reroll_cards() and arena.rerolls_left==0 and not arena.reroll_cards(),"normal card reroll cannot overspend")
	var path=Game.save_path;Game.save_path="/private/tmp/tank08-profile.json";Game.save_enabled=true;Game.selected_weapon="rpg";Game.backpack_slots=4;Game.reroll_level=3;Game.save_progress();Game.selected_weapon="pistol";Game.backpack_slots=1;Game.load_progress()
	check(Game.selected_weapon=="rpg" and Game.backpack_slots==4 and Game.reroll_level==3 and Game.built_workshops.size()==5,"v8 persistent construction loadout inventory rerolls")
	Game.save_enabled=false;Game.save_path=path
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub);hub.show_build_menu()
	check(is_instance_valid(hub.build_menu) and not hub.dpad.enabled,"build menu locks gameplay controls")
	hub.close_station();hub.open_workshop(true);check(hub.weapon_station.visible,"six weapon loadout menu opens")
	arena.phase="paused";arena.pending_recipes=[];arena.drop_recipe(arena.player.cell,{})
	arena.draft_pickup=arena.pickups.back();arena.draft_pickup.offers=Game.recipe_offers(arena.combat_rng,[])
	var prior=arena.soldier_max_hp;arena.draft_pickup.offers[0]={"category":"upgrade","id":"health","tier":2};arena.choose_recipe_card(0)
	check(arena.soldier_max_hp==prior+2 and arena.pending_recipes.is_empty(),"fallback card applies run stat without using bag slot")
	Game.reroll_level=2;arena.rerolls_left=2
	Game.camp_level=2
	var service=load("res://scripts/service_room.gd").new();service.arena=arena;service.index=2;service.branch="vehicle";add_child(service);service.avatar.position=Vector3.ZERO;service.interact();service.reroll_cards()
	check(arena.rerolls_left==1,"service uses shared reroll allowance")
	arena.soldier_hp=1;service.claim(0)
	check(arena.soldier_hp==1 and service.medkits.size()==3,"service reward does not auto heal; upgraded supply spawns physical kits")
	service.avatar.position=service.medkits[0].position;service.collect_medkits();var healed=arena.soldier_hp;service.collect_medkits()
	check(healed>1 and arena.soldier_hp==healed and service.medkits.size()==2,"medkit heals only on manual approach and consumes once")
	Game.sound_enabled=true
	var music=load("res://scripts/music_controller.gd").new();add_child(music);music.change("hub");var active=music.active;music.change("hub")
	check(music.active==active and music.get_child_count()==3,"music reentry retains fixed players")
	check(music.backgrounds[active].stream.loop_mode==AudioStreamWAV.LOOP_FORWARD,"background loops full WAV")
	music.celebrate("boss_victory",3);music.celebrate("wave_victory",2)
	check(music.stinger.stream.resource_path.ends_with("boss_victory.wav"),"boss stinger takes priority over wave")
	music.queue_free();Game.sound_enabled=false
	await get_tree().process_frame
	print("V08: %d checks, %d failures" % [checks,failures]);get_tree().quit(1 if failures else 0)
