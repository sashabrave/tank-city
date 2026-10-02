extends Node
## test-timeout: 420 (plays a long simulated run)
## Stress test for deliberately broken builds: every class is pumped three ways (all cards at once,
## one card family, maxed meta) and fights endless waves at 4x speed. The game must stay finite and
## responsive: no NaN/INF, no negative or runaway intervals, bounded projectiles/actors, frame time sane.
## It also prints kills per second and survival per build — the raw material for the "meta" table.
const MODES=["all_cards","family","meta"]
const FIGHT_SECONDS=14.0
var rng=RandomNumberGenerator.new()
var errors=0
var results=[]
var queue=[]
var arena
var mode=""
var cls=""
var t=0.0
var kills_start=0
var taken=0.0
var last_hp=0.0
var worst_frame=0.0
var peak_projectiles=0
var deaths=0

func check(value:bool,message:String):
	if not value:
		errors+=1
		if errors<40:push_error("EXTREME FAIL [%s/%s]: %s" % [cls,mode,message])

func finite(v)->bool:return typeof(v) in [TYPE_FLOAT,TYPE_INT] and not is_nan(float(v)) and not is_inf(float(v))

func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	rng.seed=7
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false
	for c in ClassCatalog.ROSTER:
		for m in MODES:queue.append([c,m])
	next()

func next():
	if is_instance_valid(arena):arena.queue_free();arena=null
	Engine.time_scale=1.0
	if queue.is_empty():finish();return
	var job=queue.pop_front();cls=job[0];mode=job[1]
	Game.reset_upgrades();Game.selected_class=cls;Game.credits=0
	if cls not in Game.class_unlocks:Game.class_unlocks.append(cls)
	if mode=="meta":
		for field in ["health_level","damage_level","mobility_level","pressure_level"]:Game.set(field,200)
		Game.luck_level=1000
		for def in StatRegistry.all():
			if def.meta_field=="":Game.stat_levels[def.id]=def.max_level*40
	arena=load("res://scenes/arena.tscn").instantiate();arena.auto_pause_enabled=false;arena.sandbox=true;arena.sandbox_waves=true;add_child(arena)
	arena.begin_room(3)
	var family=ClassCatalog.info(cls).family
	var pool=UpgradeRegistry.all().filter(func(d):return d.weight>0)
	if mode=="family":pool=pool.filter(func(d):return d.family==family)
	var count={"all_cards":400,"family":300,"meta":40}[mode]
	for i in range(count):
		var def=pool[rng.randi_range(0,pool.size()-1)]
		RunUpgrades.apply(arena,def.id,3)
	RunUpgrades.refresh_player(arena)
	t=0.0;taken=0.0;deaths=0;worst_frame=0.0;peak_projectiles=0
	kills_start=arena.run.kills
	last_hp=arena.soldier_hp
	Engine.time_scale=4.0

func _process(delta):
	if not is_instance_valid(arena):return
	t+=delta
	worst_frame=maxf(worst_frame,delta/Engine.time_scale)
	var p=arena.player
	# Keep waves coming, keep the soldier alive enough to measure; count what it costs.
	if arena.phase in ["upgrade","paused","map"]:arena.phase="combat"
	if arena.phase=="result":deaths+=1;arena.phase="combat"
	if arena.enemy_count()==0 and arena.spawn_queue.is_empty():arena.start_wave(2)
	if is_instance_valid(p):
		if p.kind=="soldier":
			if arena.soldier_hp<last_hp:taken+=last_hp-arena.soldier_hp
			last_hp=arena.soldier_hp
		Game.touch_fire=true
		# Simple aim: turn toward the nearest enemy along the dominant axis, then hold and fire.
		var target=null;var best=INF
		for e in arena.actors:
			if is_instance_valid(e) and not e.dead and not e.player_owned and not e.allied:
				var dd=arena.flat_distance(p.position,e.position)
				if dd<best:best=dd;target=e
		if target:
			var d=target.position-p.position
			var want=Vector2i(signi(roundi(d.x)),0) if absf(d.x)>absf(d.z) else Vector2i(0,signi(roundi(d.z)))
			Game.touch_direction=want if want!=p.facing else Vector2i.ZERO
		elif rng.randf()<.05:Game.touch_direction=[Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.ZERO][rng.randi_range(0,4)]
		if rng.randf()<.02:arena.abilities.cast_slot(0)
		check(finite(p.hp) and finite(p.max_hp) and p.max_hp<1e7,"player hp finite and bounded (%s/%s)" % [p.hp,p.max_hp])
		check(finite(p.damage) and p.damage>=0 and p.damage<1e7,"player damage finite and bounded (%s)" % p.damage)
		check(finite(p.fire_interval) and p.fire_interval>=.02,"fire interval not runaway (%s)" % p.fire_interval)
		check(finite(p.speed) and p.speed>=0 and p.speed<=Balance.speed_cap()*Balance.speed_multiplier_cap()*1.5+1,"speed within cap (%s)" % p.speed)
		check(finite(p.position.x) and finite(p.position.z) and absf(p.position.x)<arena.grid_size and absf(p.position.z)<arena.grid_size,"player stays on the field")
	for key in ["crit_chance","crit_damage","dodge","burn_chance","stun_chance","stealth","luck"]:
		var v=arena.run.get(key)
		if v!=null:check(finite(v),"run.%s finite (%s)" % [key,v])
	check(CombatMods.crit_chance(arena)<=.95,"crit chance capped (%s)" % CombatMods.crit_chance(arena))
	peak_projectiles=maxi(peak_projectiles,arena.projectiles.size())
	check(arena.projectiles.size()<900,"projectiles bounded (%d)" % arena.projectiles.size())
	check(arena.actors.size()<250,"actors bounded (%d)" % arena.actors.size())
	if t>=FIGHT_SECONDS:
		var kills=arena.run.kills-kills_start
		var kps=kills/FIGHT_SECONDS
		var p2=arena.player;var run=arena.run
		var crit=CombatMods.crit_chance(arena);var dps=0.0;var ehp=0.0
		if is_instance_valid(p2):
			dps=p2.damage/maxf(.02,p2.fire_interval)*(1.0+crit*(float(run.crit_damage)-1.0))
			var guard=minf(CombatMods.CAPS.guard,float(run.guard_bullet));var dodge=minf(CombatMods.CAPS.dodge,float(run.dodge))
			ehp=float(run.soldier_max_hp)/maxf(.05,(1.0-guard)*(1.0-dodge))
		results.append({"class":cls,"mode":mode,"kps":snappedf(kps,.01),"taken":snappedf(taken,.1),"deaths":deaths,"proj":peak_projectiles,"frame_ms":snappedf(worst_frame*1000,.1),
			"damage":snappedf(arena.player.damage if is_instance_valid(arena.player) else 0,.01),"interval":snappedf(arena.player.fire_interval if is_instance_valid(arena.player) else 0,.001),
			"crit":snappedf(float(arena.run.crit_chance),.01),"dodge":snappedf(float(arena.run.dodge),.01),"dps":snappedf(dps,.1),"ehp":snappedf(ehp,.1),"hp":run.soldier_max_hp})
		print("EXTREME ",results.back())
		next()

func finish():
	Engine.time_scale=1.0;Game.touch_fire=false;Game.touch_direction=Vector2i.ZERO
	var ranked=results.duplicate();ranked.sort_custom(func(a,b):return a.dps*sqrt(a.ehp)>b.dps*sqrt(b.ehp))
	print("EXTREME TOP: ",ranked.slice(0,6).map(func(r):return "%s/%s dps %.1f ehp %.1f kps %.2f" % [r.class,r.mode,r.dps,r.ehp,r.kps]))
	print("EXTREME BUILDS: %d failures" % errors)
	get_tree().quit(1 if errors else 0)
