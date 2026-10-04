extends Node
## test-timeout: 2400 (bot plays a whole world-1 route, 15–40 min depending on load; same limit as tools/balance/run_pacing.sh)
## test-flags: --fixed-fps 60
## Pacing probe for the economy model (tools/balance/pacing_model.py, guides/03_release/07_balance_pacing.md).
## The bot cannot defend like a person, so it never dies: soldier and HQ stay at 999 HP and every hit is
## booked per field as «damage taken». The model turns that pressure into a death chance with a human factor.
## Run: Godot --headless --fixed-fps 60 --path . tests/balance_pacing.tscn -- hp dmg mob press class_lvl challenge seed path [weapon_lvl] [debug]
## (tools/balance/run_pacing.sh runs a whole matrix).
## Without arguments it only checks that the scene loads and quits; tests/suites/long.txt passes a meta state.
## Fails (exit 1) on a timeout or a route without a single kill.
##   path: easy | mid | hard — which route nodes the bot picks (battle nodes only).
## Prints one PACE line per field and a PACE_RUN summary. Never saves: Game.save_enabled=false.
var arena
var ticks=0
var finished=false
var seed_value=42
var path="mid"
var field_start=0.0
var field_kills=0
var field_earned=0
var field_soldier=0.0
var field_base=0.0
var field_assists=0
var assists=0
var last_kill_tick=0
var last_kills=0
const STALL=20.0  # seconds of game time without a kill before the bot gets help
var last_kill_time=0.0
var total_soldier=0.0
var total_base=0.0
var boss_time=0.0
const FULL=999.0
var booked=0.0
var debug=false

func _ready():
	# Run with --fixed-fps 60: every frame is one 1/60 s physics step, as fast as the CPU allows.
	Engine.physics_ticks_per_second=60;Engine.max_physics_steps_per_frame=1
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false;Game.reset_upgrades()
	var a=Array(OS.get_cmdline_user_args()).filter(func(s):return not s.begins_with("--"))
	if a.is_empty():finished=true;print("PACE skipped: pass the meta state after --");get_tree().quit.call_deferred();return
	var n=func(i,d):return int(a[i]) if a.size()>i else d
	Game.health_level=n.call(0,0);Game.damage_level=n.call(1,0);Game.mobility_level=n.call(2,0);Game.pressure_level=n.call(3,0)
	Game.class_levels["recruit"]=n.call(4,0)
	debug="debug" in a;seed_value=n.call(6,42);path=a[7] if a.size()>7 else "mid"
	Game.progression.weapon_levels["pistol"]=n.call(8,0)
	Campaign.configure(1,false);Campaign.challenge=n.call(5,0)
	if Campaign.challenge>0:Game.progression.cleared_worlds.append(1)
	arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false
	arena.run_seed=seed_value;arena.combat_rng.seed=seed_value
	choose(0);arena.begin_room(0);start_field()

## Picks a battle node of the stage by the path's appetite for stars (no services or challenge rooms).
func choose(stage:int):
	var plan=RoutePlan.build(seed_value)
	if stage>=plan.size():return
	var want={"easy":0,"mid":1,"hard":2}.get(path,1)
	var best=null
	for node in plan[stage]:
		if node.type!="battle":continue
		if best==null or absi(node.difficulty-want)<absi(best.difficulty-want):best=node
	if best==null:best=plan[stage][0]
	arena.run.route_choices[stage]=best.id

func start_field():
	field_start=arena.elapsed;field_kills=arena.kills;field_earned=arena.run.earned;field_soldier=0.0;field_base=0.0;field_assists=0
	last_kill_time=arena.elapsed;last_kills=arena.kills

func end_field():
	var node=RoutePlan.chosen(RoutePlan.build(seed_value),arena.room_index,arena.run.route_choices)
	var biome=preload("res://scripts/biome_catalog.gd").entry(seed_value,arena.room_index,int(node.get("lane",0)))
	print("PACE "+JSON.stringify({"seed":seed_value,"challenge":Campaign.challenge,"path":path,"field":arena.room_index,"difficulty":arena.room.difficulty,"biome":biome.family,"kinds":biome.kinds,
		"time":snappedf(arena.elapsed-field_start,.1),"kills":arena.kills-field_kills,"earned":arena.run.earned-field_earned,"soldier_dmg":snappedf(field_soldier,.01),
		"base_dmg":snappedf(field_base,.01),"soldier_max":arena.run.soldier_max_hp,"base_max":arena.room.base_max_hp,"assists":field_assists,"tokens":arena.run.tokens}))

func account():
	var p=arena.player
	# Hits are booked by the game itself (RunState.damage_taken); hp only has to stay out of reach of death.
	var taken=arena.run.damage_taken-booked;booked=arena.run.damage_taken
	if taken>0:field_soldier+=taken;total_soldier+=taken
	if is_instance_valid(p) and p.kind=="soldier":p.hp=FULL;arena.soldier_hp=FULL
	# A fresh room resets the HQ to its maximum: that is not damage. Anything else below 999 is a hit.
	if arena.base_hp<FULL and not is_equal_approx(arena.base_hp,arena.room.base_max_hp):
		field_base+=FULL-arena.base_hp;total_base+=FULL-arena.base_hp
	arena.base_hp=FULL

func advance():
	end_field()
	var next=arena.room_index+1
	if next>=Campaign.SIZES.size():finish();return
	choose(next);arena.begin_room(next);start_field()

func finish():
	finished=true
	print("PACE_RUN "+JSON.stringify({"seed":seed_value,"challenge":Campaign.challenge,"path":path,"hp":Game.health_level,"dmg":Game.damage_level,"class":Game.class_level(),
		"time":snappedf(arena.elapsed,.1),"earned":arena.run.earned,"tokens":arena.run.tokens,"soldier_dmg":snappedf(total_soldier,.01),"base_dmg":snappedf(total_base,.01),"assists":assists,"boss":arena.boss_defeated,"ticks":ticks}))
	# In the long suite (tests/suites/long.txt passes a meta state) a timeout or a route without kills is a failure.
	var broken=ticks>2400000 or arena.kills==0
	if broken:print("FAIL balance_pacing: ","timeout" if ticks>2400000 else "no kills")
	get_tree().quit(1 if broken else 0)

func _physics_process(_delta):
	if finished:return
	ticks+=1
	if ticks>2400000:print("PACE_TIMEOUT field=%d" % arena.room_index);finish();return
	account()
	if arena.room.has_meta("pending_flag"):
		for chest in arena.room.pickups.filter(func(c):return c.kind=="recipe_draft"):arena.reward.consume_chest(chest)
	if arena.phase=="countdown":arena.countdown=minf(arena.countdown,.1)
	elif arena.phase=="paused" and not arena.room.draft_pickup.is_empty():arena.choose_recipe_card(0)
	elif arena.phase=="paused" and arena.boss_defeated:advance()
	elif arena.phase=="result":
		if arena.room_index==Campaign.BOSSES[0]:end_field()
		finish()
	elif arena.phase=="upgrade" and arena.reward_claimed:advance()
	elif arena.phase=="upgrade":
		if arena.upgrade_offers.is_empty():return
		var offer=arena.upgrade_offers[0]
		for candidate in arena.upgrade_offers:
			if candidate.id in ["damage","weapon_damage","health"]:offer=candidate;break
		arena.apply_upgrade(offer.id,offer.tier)
	elif arena.phase=="combat":
		if arena.boss_defeated or arena.room_cleared:
			var chest=arena.pickups.filter(func(p):return p.kind=="recipe_draft")
			if not chest.is_empty():arena.open_recipe_draft(chest[0])
			elif arena.room_cleared:arena.open_flag()
		else:
			for i in range(arena.abilities.slots.size()):arena.abilities.cast_slot(i)
			drive();stalemate()

func stalemate():
	if arena.kills!=last_kills:last_kills=arena.kills;last_kill_time=arena.elapsed;return
	if arena.elapsed-last_kill_time<STALL:return
	if debug:print("STALL t=%.1f phase=%s queue=%d enemies=%d" % [arena.elapsed,arena.phase,arena.spawn_queue.size(),arena.enemy_count()])
	last_kill_time=arena.elapsed
	for enemy in arena.actors:
		if enemy.player_owned or enemy.allied or enemy.dead:continue
		if enemy.kind=="boss":
			# The boss is fought for real; only a stuck generator order is helped once in a while.
			for cell in arena.room.generators.keys():arena.boss.damage_generator(cell,99999);assists+=1;field_assists+=1;return
			continue
		if debug:print("ASSIST t=%.1f kind=%s cell=%s trench=%s" % [arena.elapsed,enemy.kind,enemy.cell,enemy.hidden_in_trench])
		assists+=1;field_assists+=1;enemy.invulnerable=0;enemy.take_damage(99999);return
	if arena.challenges.active() and arena.challenges.goal>0:arena.challenges.progress=maxf(arena.challenges.progress,arena.challenges.goal-.05)
	if not arena.wrecks.is_empty() and not arena.spawn_queue.is_empty():assists+=1;arena.wrecks[0].shatter()

## Target choice: an enemy close to the HQ first (a person defends the base), otherwise the nearest one.
func drive():
	var p=arena.player
	Game.touch_direction=Vector2i.ZERO;Game.touch_fire=false
	var reach=arena.LOOT.WEAPONS[arena.weapon].range*.8 if p.kind=="soldier" else 30.0
	# Any enemy already in line of fire is shot first, the one nearest the HQ preferred (a person defends the base).
	var shot=null;var shot_score=1000.0
	for enemy in arena.actors:
		if enemy.player_owned or enemy.allied or enemy.dead:continue
		var line=arena.aligned_direction(p.cell,enemy.cell)
		if line==Vector2i.ZERO or not arena.clear_line(p.cell,enemy.cell) or p.position.distance_to(enemy.position)>=reach:continue
		var score=(enemy.cell-arena.base_cell).length()
		if score<shot_score:shot_score=score;shot=line
	if shot!=null:
		if not p.moving or p.facing==shot:
			if not p.moving:p.set_facing(shot)
			Game.touch_fire=true;return
	if p.moving:return
	var target=null;var best=1000.0
	for enemy in arena.actors:
		if enemy.player_owned or enemy.allied or enemy.dead:continue
		var dist=(enemy.cell-p.cell).length()
		if (enemy.cell-arena.base_cell).length()<4.5:dist-=6.0
		if dist<best:best=dist;target=enemy
	if target==null:return
	var queue=[p.cell];var came={p.cell:p.cell};var head=0;var goal=p.cell
	while head<queue.size():
		var cell=queue[head];head+=1
		if arena.aligned_direction(cell,target.cell)!=Vector2i.ZERO and arena.clear_line(cell,target.cell) and arena.world_pos(cell).distance_to(target.position)<reach:goal=cell;break
		for dir in arena.DIRS:
			var next=cell+dir
			if came.has(next) or not arena.inside(next) or arena.walls.has(next) or arena.trenches.has(next) or next==arena.base_cell:continue
			if cell==p.cell and not arena.can_enter(next,p):continue
			came[next]=cell;queue.append(next)
	if goal!=p.cell:
		while came[goal]!=p.cell:goal=came[goal]
		Game.touch_direction=goal-p.cell
	else:
		for dir in arena.DIRS:
			if arena.walls.has(p.cell+dir) and arena.walls[p.cell+dir].hp>0:
				p.set_facing(dir);Game.touch_fire=true;return
