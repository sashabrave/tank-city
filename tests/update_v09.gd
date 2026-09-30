extends Node
var checks=0
var failures=0
func check(ok,msg):
	checks+=1
	if not ok:failures+=1;push_error(msg)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Game.reset_upgrades()
	Game.equipped_abilities=["barrier","grenade","gas"];Game.ability_slots=3
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false);arena.player.set_physics_process(false);arena.phase="combat"
	check(arena.abilities.interval()==33 and arena.abilities.barrier_count()==1,"barrier baseline")
	var front=arena.player.cell+arena.player.facing
	if arena.walls.has(front):arena.walls[front].node.queue_free();arena.walls.erase(front)
	check(arena.abilities.cast(),"barrier casts")
	check(arena.walls[front].hp==12 and arena.walls[front].has("bar"),"barrier health bar")
	arena.abilities.cooldown=0;arena.player.facing=Vector2i.LEFT
	front=arena.player.cell+arena.player.facing
	if arena.walls.has(front):arena.walls[front].node.queue_free();arena.walls.erase(front)
	check(arena.abilities.cast() and arena.abilities.barriers.size()==1,"old barrier replaced")
	arena.abilities.select("grenade");check(arena.abilities.radius()==2 and arena.abilities.interval()==36,"grenade baseline")
	var enemy=arena.spawn_actor("soldier",Vector2i(2,2),false);enemy.set_physics_process(false)
	check(arena.abilities.cast(),"grenade cast")
	var grenade=arena.grenades.back();grenade.set_physics_process(false);check(grenade.fuse==1,"one second fuse")
	grenade._physics_process(.65);check(not grenade.spent,"grenade waits after landing")
	grenade._physics_process(1);check(grenade.spent,"grenade detonates")
	var hp=arena.player.hp;arena.player.invulnerable=0;arena.player.take_damage(1)
	check(arena.player.hp<hp,"no passive shield")
	arena.player.invulnerable=0;hp=arena.player.hp
	arena.abilities.select("shield");arena.abilities.cooldown=0
	check(arena.abilities.cast() and arena.abilities.shield_time==4,"active shield casts for 4 seconds")
	for i in range(10):arena.player.take_damage(100)
	check(arena.player.hp==hp,"active shield blocks every hit")
	arena.abilities.tick(4)
	check(arena.abilities.shield_time==0 and arena.abilities.cooldown==15,"shield ends then has 15 second cooldown")
	check(not arena.abilities.cast(),"cannot cast shield on cooldown")
	arena.player.take_damage(.25);check(arena.player.hp<hp,"damage resumes after shield")
	arena.abilities.tick(15);check(arena.abilities.cast(),"shield reactivates only on input")
	arena.abilities.shield_time=0
	check(is_equal_approx(arena.current_intercept(),.4),"pistol initial interception halved")
	arena.pending_recipes=[{"category":"research","id":"rescue"}];arena.room_cleared=true;arena.resolve_recipes_on_return();check("rescue" in Game.research_unlocks,"cleared room banks recipes")
	var offers=arena.chest_offers();check(offers.size()==3 and offers[1].category=="alloy" and offers[2].category=="secret","chest categories")
	arena.drop_recipe(arena.player.cell,{});arena.open_recipe_draft(arena.pickups.back());var money=Game.credits;arena.choose_recipe_card(1);check(Game.credits==money+60,"chest alloy paid once")
	arena.choose_recipe_card(1);check(Game.credits==money+60,"cannot double claim")
	arena.phase="combat"
	for id in ["gas","mine","airstrike","ally_drone","cloak"]:
		arena.abilities.select(id);arena.abilities.cooldown=0;check(arena.abilities.cast(),"cast "+id)
	check(arena.actors.any(func(a):return a.allied and a.kind=="flyer"),"helper exists")
	arena.abilities.level.utility=3;arena.abilities.cooldown=0;arena.abilities.cast();check(arena.abilities.cloak_ghost,"max cloak ghost")
	arena.phase="countdown";var oldcell=arena.player.cell;arena.player.facing=Vector2i.RIGHT
	var target=oldcell+Vector2i.RIGHT
	if arena.walls.has(target):arena.walls[target].node.queue_free();arena.walls.erase(target)
	Input.action_press("east");arena.player.turn_left=0;arena.player._physics_process(.1);arena.player._physics_process(.5);Input.action_release("east");check(arena.player.cell!=oldcell,"movement during countdown")
	arena.run_seed=42;arena.begin_room(6);arena.set_physics_process(false)
	check(arena.twin_boss and arena.spawn_queue==["boss","boss"] and arena.player.footprint==1,"twin wave only bosses have footprint")
	var boss1=arena.spawn_actor("boss",Vector2i(3,1),false);boss1.set_physics_process(false)
	var boss2=arena.spawn_actor("boss",Vector2i(14,1),false);boss2.set_physics_process(false)
	check(boss1.footprint==2 and boss1.max_hp+boss2.max_hp==700,"twins total health and footprint")
	arena.spawn_queue.clear();arena.phase="combat";boss1.take_damage(9999);check(not arena.boss_defeated,"first twin is not victory")
	boss2.take_damage(9999);check(arena.boss_defeated and arena.phase!="result","victory waits for chest")
	arena.open_recipe_draft(arena.pickups.back());arena.choose_recipe_card(1);check(Game.cores==1,"final chest grants core")
	var owner=Node3D.new();add_child(owner)
	for kind in ["soldier","shield","sniper","grenadier","buggy","apc","tank","boss","drone","flyer","mortar"]:
		var model=Visuals.model(kind,owner);check(model.find_children("*","MeshInstance3D",true,false).size()>0,"model "+kind)
	for id in Game.LOOT.BONUSES:check(Game.LOOT.visual(owner,id)!=null,"physical bonus "+id)
	Game.built_workshops=["character"];Game.credits=10000;check(Game.buy_special("rescue") and Game.rescue_level==1,"rescue purchase")
	Game.progression.boss_classes=["recruit"];check(Game.select_class("engineer"),"class opens by goal")
	var path=Game.save_path;Game.save_path="/private/tmp/v09-save.json";Game.save_enabled=true;Game.save_progress();Game.save_enabled=false;Game.reset_upgrades();Game.load_progress();Game.save_path=path
	check(Game.selected_class=="engineer" and Game.rescue_level==1 and Game.ability_slots==2,"v09 persistence clamps legacy three slots to two")
	arena.queue_free();owner.queue_free();await get_tree().process_frame
	print("V09: %d checks, %d failures" % [checks,failures]);get_tree().quit(1 if failures else 0)
