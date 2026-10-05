extends Node
## Chaos monkey: plays the game "wrong" on purpose. Random actions every few frames across the hub,
## the route map, battles, the sandbox, service rooms and resume, at 4x speed. The test fails on any
## invariant break; script errors are caught by the runner grepping the log (see 02_development/04_testing.md).
## Seed: first user arg (default 1). Actions: second arg (default 900).
var rng=RandomNumberGenerator.new()
var main
var steps=0
var limit=900
var errors=0
var log_counts={}
var clock=0.0
var missing_player=0

func check(value:bool,message:String):
	if not value:errors+=1;push_error("CHAOS FAIL: "+message)

func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	var args=OS.get_cmdline_user_args()
	rng.seed=int(args[0]) if args.size()>0 else 1
	limit=int(args[1]) if args.size()>1 else 900
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false
	for call in ["intro","first_death","garage","general"]:Game.progression.seen.append("call_"+call)
	Game.credits=5000;Game.cores=20
	Engine.time_scale=4.0
	main=load("res://scripts/main.gd").new();add_child(main)
	main.start_run()

func arena():
	var a=main.run_arena
	return a if is_instance_valid(a) and a.is_inside_tree() else null

func _process(delta):
	clock+=delta
	if clock<.05:return
	clock=0.0;steps+=1
	if steps>limit:finish();return
	if steps%100==0:print("CHAOS step ",steps," current=",main.current.get_script().resource_path.get_file() if is_instance_valid(main.current) else "-"," paused=",get_tree().paused)
	# The pause tablet stops the tree; the monkey closes it now and then like an impatient player.
	if get_tree().paused and rng.randf()<.5:
		for n in get_tree().root.find_children("*","",true,false):
			if n.get_script()!=null and n.get_script().resource_path.ends_with("pause_tablet.gd") and n.has_method("close"):n.close();break
	act()
	invariants()

const OUTSIDE=["enter_room","enter_room","enter_room","start_run","sandbox","resume","hub","service","skip_service"]
const INSIDE=["move","move","move","fire","fire","ability","vehicle","grenade","pause","tablet","close_modals","depart","upgrade","upgrade","begin_room","kill_all","kill_all","hurt_player","hurt_base","sandbox_boss","flag","to_map","to_hub","restart","result_close","leave_battle"]
func act():
	var a=arena()
	var name=OUTSIDE[rng.randi_range(0,OUTSIDE.size()-1)] if a==null else INSIDE[rng.randi_range(0,INSIDE.size()-1)]
	log_counts[name]=int(log_counts.get(name,0))+1
	if a==null:outside(name)
	else:inside(a,name)

func outside(name:String):
	var cur=main.current
	match name:
		"enter_room":
			if is_instance_valid(cur) and cur.get_script().resource_path.ends_with("route_map.gd"):main.enter_room(cur.available)
		"start_run":main.start_run()
		"sandbox":main.enter_playground("sandbox")
		"resume":
			if not Game.run_checkpoint.is_empty():main.resume_run()
		"hub":main.show_hub()
		"service":
			if is_instance_valid(main.run_arena):main.show_service(["vehicle","ability","headquarters","merchant"][rng.randi_range(0,3)],2)
		"skip_service":
			if is_instance_valid(cur) and cur.has_method("skip_choice"):
				cur.skip_choice()
				if cur.has_signal("completed"):cur.completed.emit(cur.index)

func inside(a,name:String):
	var p=a.player
	match name:
		"move":Game.touch_direction=[Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.ZERO][rng.randi_range(0,4)]
		"fire":Game.touch_fire=rng.randf()<.7
		"ability":a.abilities.cast_slot(rng.randi_range(0,1))
		"vehicle":a.vehicle.interact_vehicle()
		"grenade":
			if is_instance_valid(p):a.throw_grenade(p,a.world_pos(Vector2i(rng.randi_range(0,a.grid_size-1),rng.randi_range(0,a.grid_size-1))))
		"pause":a.pause_battle()
		"tablet":preload("res://scripts/ui/pause_tablet.gd").open(a,Callable(),func():pass)
		"close_modals":
			if a.hud:a.hud.close_modal()
		"depart":a.flow.depart_room()
		"upgrade":
			if a.phase=="upgrade" and not a.upgrade_offers.is_empty():
				var o=a.upgrade_offers[rng.randi_range(0,a.upgrade_offers.size()-1)];a.apply_upgrade(o.id,o.tier)
			elif a.phase=="upgrade":a.return_to_field()
		"begin_room":a.begin_room(rng.randi_range(0,Campaign.SIZES.size()-1))
		"kill_all":
			for e in a.actors.duplicate():
				if is_instance_valid(e) and not e.player_owned and not e.dead:e.take_damage(999)
		"hurt_player":
			if is_instance_valid(p):p.invulnerable=0;p.take_damage(rng.randf_range(.5,40))
		"hurt_base":a.damage_base(rng.randf_range(1,50))
		"sandbox_boss":
			var admin=a.playground.admin if a.sandbox else null
			if admin and admin.has_method("boss"):admin.boss()
		"flag":
			if a.phase=="combat" and a.room_cleared:a.open_flag()
		"to_map":
			if not a.sandbox:a.map_requested.emit(a.room_index+1)
		"to_hub":main.show_hub()
		"restart":a.restart_requested.emit()
		"result_close":
			if a.phase=="result":main.show_hub()
		"leave_battle":
			if a.sandbox:a.exit_requested.emit()
			else:main.show_hub()

func invariants():
	var a=arena()
	if a==null:return
	check(a.grid_size>0 and a.base_cell.x>=0,"field has a size and a base")
	if a.phase in ["combat","countdown"]:
		# One step between death and a respawn is fine; a field without a player for long is not.
		missing_player=0 if is_instance_valid(a.player) else missing_player+1
		check(missing_player<6,"a living player in combat (missing for %d steps, sandbox=%s)" % [missing_player,a.sandbox])
		if is_instance_valid(a.player):check(a.player.hp<=a.player.max_hp+.001 and a.player.hp>=0,"player hp within range")
	check(a.get_child_count()<4000,"arena children stay bounded ("+str(a.get_child_count())+")")

func finish():
	Engine.time_scale=1.0;Game.touch_direction=Vector2i.ZERO;Game.touch_fire=false
	print("CHAOS actions: ",log_counts)
	print("CHAOS: seed %d, %d steps, %d invariant failures" % [rng.seed,steps,errors])
	get_tree().quit(1 if errors else 0)
