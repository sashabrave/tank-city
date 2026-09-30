extends RefCounted
## Boss system. Owns rules; Arena remains the scene coordinator.
var arena

func _init(context):
	arena=context

func boss_step(actor,delta:float):
	if not is_instance_valid(arena.player) or arena.player.dead:return
	var spec=BossCatalog.encounter(arena.run_seed,arena.room_index)
	if not actor.has_meta("boss_pattern"):
		actor.set_meta("boss_pattern",{"phase":"move","timer":1.6+actor.wave_slot*1.5,"index":0,"direction":Vector3.FORWARD,"target":Vector3.ZERO,"warning":null})
	var state:Dictionary=actor.get_meta("boss_pattern")
	state.timer-=delta
	if state.phase=="charge":
		actor.warning_ring.scale=Vector3.ONE*(1.0+.08*sin(state.timer*20))
		if state.timer<=0:
			fire_pattern(actor,state,spec)
			if is_instance_valid(state.warning):state.warning.queue_free()
			actor.warning_ring.hide();actor.attack_label.hide()
			state.phase="recover";state.timer=2.0;state.index+=1
		return
	if state.phase=="recover":
		if state.timer<=0:state.phase="move";state.timer=1.8 if spec.id=="twins" else 2.4
		return
	var diff=arena.player.position-actor.position;diff.y=0
	var yaw=atan2(-diff.x,-diff.z);actor.turret_yaw=rotate_toward(actor.turret_yaw,yaw,1.9*delta);actor.model.aim(actor.turret_yaw)
	if state.timer<=0 and not actor.moving:
		if arena.abilities.cloak_time>0:state.timer=.25;return
		# The pair takes turns winding up, so both attacks never start together.
		if spec.id=="twins" and arena.actors.any(func(other):return is_instance_valid(other) and other!=actor and not other.dead and other.kind=="boss" and other.get_meta("boss_pattern",{}).get("phase","")=="charge"):
			state.timer=.35;return
		state.phase="charge";state.timer=1.1;state.direction=diff.normalized();state.target=arena.player.position
		state.attack=spec.patterns[state.index%spec.patterns.size()]
		actor.warning_ring.show();actor.attack_label.show()
		Texts.set_text(actor.attack_label,{"salvo":"Прицельный залп","fan":"Веерный залп","mortar":"Миномётный залп"}[state.attack])
		Game.sound("danger_warning",actor)
		state.warning=Node3D.new();actor.add_child(state.warning)
		if state.attack!="mortar":
			for angle in ([-.36,-.18,0.0,.18,.36] if state.attack=="fan" else [-.10,0.0,.10]):
				var ray=Node3D.new();state.warning.add_child(ray);ray.rotation.y=atan2(state.direction.x,state.direction.z)+angle
				var mark=Visuals.box(ray,Vector3(0,.07,7),Vector3(.10,.02,14),Color("efae54"));mark.material_override=EffectLighting.glow(Color("efae54"),true)
		return
	if not actor.moving and actor.movement_pause<=0:
		var toward=Vector2i(signi(roundi(diff.x)),0) if absf(diff.x)>absf(diff.z) else Vector2i(0,signi(roundi(diff.z)))
		var dir=toward
		if diff.length()<7 or spec.id in ["twins","medium"]:
			dir=Vector2i(-toward.y,toward.x)*(1 if actor.wave_slot%2==0 else -1)
		for next in [dir,toward,-dir]:
			if next!=Vector2i.ZERO and arena.can_enter(actor.cell+next,actor):actor.set_facing(next);actor.try_move(next);break

func fire_pattern(actor,state:Dictionary,spec:Dictionary):
	actor.model.kick();Game.weapon_sound(actor)
	if state.attack=="mortar":
		for offset in [-2.2,0.0,2.2]:
			var grenade=load("res://scenes/grenade.tscn").instantiate();grenade.arena=arena;grenade.damage=1.0+.15*(Campaign.world-1);grenade.blast_radius=1.3;grenade.flight_time=1.6
			grenade.position=actor.position+Vector3.UP;grenade.target=state.target+Vector3(offset,0,0);grenade.target.y=0
			arena.add_child(grenade);arena.grenades.append(grenade)
	else:
		var angles=[-.36,-.18,0.0,.18,.36] if state.attack=="fan" else [-.10,0.0,.10]
		for angle in angles:
			arena.spawn_free_bullet(actor,state.direction.rotated(Vector3.UP,-angle),.8 if spec.id=="twins" else 1.2,4.2 if state.attack=="fan" else 6.0,false)

func boss_radial_attack(actor):
	for i in range(16):
		var angle=TAU*i/16.0
		arena.spawn_free_bullet(actor,Vector3(cos(angle),0,sin(angle)),.65 if arena.room.twin_boss else 1,3.6 if arena.room.twin_boss else 4.2,true)
	Game.sound("boss_radial",actor)

func spawn_room_boss():
	if arena.room.room_boss_spawned:return
	Game.music_context("miniboss")
	var node=RoutePlan.chosen(RoutePlan.build(arena.run.run_seed),arena.room.room_index,arena.run.route_choices)
	var entry=WaveDirector.commander_entry(arena.run.run_seed,arena.room.room_index,node.id)
	var kind=entry.kind
	var columns=arena.spawn_columns()
	var location=Vector2i(columns[int((columns.size()-1)/2)],0)
	if not arena.can_enter(location):return
	arena.room.room_boss_spawned=true
	var elite=arena.room.commander_elite
	var enemy=arena.spawn_actor(kind,location,false,false,WaveDirector.max_rank(arena.room.room_index),false,entry.weapon)
	enemy.elite=true;enemy.commander_elite=elite;arena.room.commander=enemy
	var difficulty=arena.room.difficulty
	enemy.max_hp*=[3.0,4.0,5.0][difficulty];enemy.hp=enemy.max_hp;enemy.damage*=[1.0,1.1,1.2][difficulty]
	arena.room.commander_help_timer=8.0 if elite else 12.0
	arena.room.commander_help_pool=WaveDirector.build(arena.run.run_seed,arena.room.room_index,2,arena.room.difficulty,arena.room.route_node_id)
	arena.room.commander_help_pool.sort_custom(func(a,b):return WaveDirector.rank_cost(a.kind,a.rank)>WaveDirector.rank_cost(b.kind,b.rank))
	arena.room.commander_help_pool=arena.room.commander_help_pool.slice(0,3)
	Visuals.box(enemy.model,Vector3(0,.8,.15),Vector3(.45,.08,.08),Color("f1b656"))
	enemy.elite_star=Visuals.label3d(enemy,EncounterRules.STARS[difficulty],Vector3(0,1.95,0),Color("ffd26b"),36)
	enemy.refresh_health();enemy.wave_slot=arena.room.wave_roster.size();arena.room.wave_roster.append({"kind":kind,"state":"active"})
	arena.toast(EncounterRules.NAMES[difficulty]+" · командир")
	if is_instance_valid(arena.presentation):arena.presentation.miniboss(difficulty)

func tick_commander_help(delta:float):
	var room=arena.room;var commander=room.commander
	if arena.phase!="combat" or not is_instance_valid(commander) or commander.dead or room.commander_help_pool.is_empty():return
	var elite=commander.commander_elite
	var limit=[1,2,3][room.difficulty]
	if room.commander_help_waves>=limit:return
	room.commander_help_timer-=delta
	if room.commander_help_timer>0:return
	var alive=room.actors.filter(func(a):return is_instance_valid(a) and not a.dead and a.commander_support)
	var cap=[1,2,3][room.difficulty]
	if alive.size()>=cap:room.commander_help_timer=2;return
	var amount=mini(cap-alive.size(),2 if elite and Campaign.zone(room.room_index)>=2 else 1)
	var spawned=0
	for x in arena.spawn_columns():
		if spawned>=amount:break
		var cell=Vector2i(x,0)
		if not arena.can_enter(cell):continue
		var pool=room.commander_help_pool.filter(func(e):return e.kind!="grenadier" or not room.actors.any(func(a):return is_instance_valid(a) and not a.dead and a.kind=="grenadier"))
		if pool.is_empty():pool=[{"kind":"soldier","rank":1,"weapon":"rifle"}]
		var entry=pool[arena.run.combat_rng.randi_range(0,pool.size()-1)]
		var helper=arena.spawn_actor(entry.kind,cell,false,false,entry.rank,false,entry.get("weapon",EnemyLoadouts.default_for(entry.kind)))
		helper.commander_support=true;helper.wave_slot=room.wave_roster.size()
		room.wave_roster.append({"kind":entry.kind,"rank":entry.rank,"state":"active"});spawned+=1
	if spawned>0:
		room.commander_help_waves+=1;room.commander_help_timer=13.0 if elite else 18.0
		arena.toast("Командир вызвал подкрепление")
	else:room.commander_help_timer=1.0

func elite_step(actor,delta: float):
	if not is_instance_valid(arena.room.player) or arena.room.player.dead:return
	if actor.elite_charge>0:
		actor.elite_charge-=delta
		actor.elite_star.modulate=Color("ff634a") if fmod(actor.elite_charge,.2)<.1 else Color("ffd26b")
		if actor.elite_charge<=0:
			var direction=(arena.room.player.position-actor.position).normalized();direction.y=0
			for angle in [-.26,0.0,.26]:arena.spawn_free_bullet(actor,direction.rotated(Vector3.UP,angle),actor.strength_scale,6.5,false)
			actor.elite_star.modulate=Color("ffd26b");actor.elite_timer=6.0
			Game.weapon_sound(actor)
	else:
		actor.elite_timer-=delta
		if actor.elite_timer<=0:actor.elite_charge=1.2

func spawn_generators():
	var room=arena.room
	room.generator_order=[Vector2i(3,3),Vector2i(room.grid_size-4,3),Vector2i(room.grid_size-4,room.grid_size-4),Vector2i(3,room.grid_size-4)]
	for cell in room.generator_order:
		var node=Node3D.new();arena.add_child(node);node.position=arena.world_pos(cell)
		Visuals.box(node,Vector3(0,.6,0),Vector3(.8,1.2,.8),Color("689baf"))
		var ring=Visuals.ring(node,Color("91dcf4"),.65);ring.hide()
		var bar=load("res://scripts/health_bar_3d.gd").new();node.add_child(bar);bar.position.y=1.5;bar.set_health(18,18);bar.hide()
		var label=Visuals.label3d(node,"Генератор · резерв",Vector3(0,1.9,0),Color("a2aaad"),22)
		room.generators[cell]={"node":node,"hp":18.0,"bar":bar,"active":false,"ring":ring,"label":label}
		# An L-shaped outer wall protects the post; its two inward approaches stay open.
		var outer=Vector2i(-1 if cell.x<room.grid_size/2 else 1,-1 if cell.y<room.grid_size/2 else 1)
		for offset in [Vector2i(outer.x,0),outer,Vector2i(0,outer.y)]:
			var block=cell+offset
			if not room.walls.has(block):arena.add_wall(block,5);BattleMapGenerator.put(room.current_layout,block,"B")
		arena.navigation.invalidate(cell)
	arena.board.shape_map_walls()
func shield_active()->bool:
	return arena.room.generators.values().any(func(generator):return generator.active)
func limit_damage(actor,amount:float)->float:
	if shield_active():return 0.0
	var stage=arena.room.generator_stage
	if stage>=4:return amount
	var threshold=actor.max_hp*[.8,.6,.4,.2][stage]
	var allowed=minf(amount,maxf(0,actor.hp-threshold))
	if actor.hp-allowed<=threshold+.001:activate_generator()
	return allowed
func activate_generator():
	var room=arena.room
	if room.generator_stage>=room.generator_order.size():return
	var cell=room.generator_order[room.generator_stage];room.generator_stage+=1
	var generator=room.generators[cell];generator.active=true;generator.ring.show();generator.bar.show()
	generator.ring.material_override=EffectLighting.glow(Color("61d8ff"))
	Texts.set_text(generator.label,"Генератор · щит активен")
	Game.sound_loop("generator_loop",generator.node)
	arena.toast("Щит активен — уничтожь светящийся генератор")
	var inward=Vector2i(1 if cell.x<room.grid_size/2 else -1,1 if cell.y<room.grid_size/2 else -1)
	for offset in [Vector2i(inward.x*2,0),Vector2i(0,inward.y*2)]:
		var guard_cell=cell+offset
		if not arena.can_enter(guard_cell):guard_cell=arena.find_free_near(guard_cell)
		if not arena.can_enter(guard_cell):continue
		var guard=arena.spawn_actor("soldier",guard_cell,false,false,2,false,"rifle")
		guard.set_meta("generator_guard",true);guard.fire_cooldown=1.5
		# Partial brick cover, with a clear lane toward the center.
		var cover=guard_cell-inward
		if arena.inside(cover) and not room.walls.has(cover) and not room.generators.has(cover) and arena.can_enter(cover):arena.add_wall(cover,4)
func damage_generator(cell,amount):
	if not arena.room.generators.has(cell) or not arena.room.generators[cell].active:return
	var generator=arena.room.generators[cell]
	generator.hp-=amount;generator.bar.set_health(maxf(0,generator.hp),18)
	if generator.hp<=0:
		Game.sound("generator_off",arena)
		generator.node.queue_free();arena.room.generators.erase(cell);arena.navigation.invalidate(cell);arena.burst(arena.world_pos(cell),Color("99d4df"),1)
		arena.toast("Щит отключён — атакуй командира!")
func boss_extra_attacks(_actor,_delta):pass
