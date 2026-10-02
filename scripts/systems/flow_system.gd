extends RefCounted
## Flow system. Owns rules; Arena remains the scene coordinator.
signal changed(previous:String,current:String)
const PHASES=["countdown","combat","paused","upgrade","map","result"]
## HP restored after each cleared field (campaign and endless).
const ROOM_HEAL=1.0
var current="countdown"
var arena

func _init(context):
	arena=context

func start_wave(index: int):
	arena.room.upgrade_offers.clear()
	arena.room.wave = index
	arena.phase = "countdown"
	arena.room.countdown = Balance.CONFIG.combat.wave_delay
	var entries=WaveDirector.build(arena.run.run_seed,arena.room.room_index,index,arena.room.difficulty,arena.room.route_node_id)
	if arena.room.boss_room and arena.room.twin_boss:entries=[{"kind":"boss","rank":1},{"kind":"boss","rank":1}]
	arena.room.spawn_queue=entries.map(func(entry):return entry.kind)
	arena.room.wave_roster.clear();arena.room.wave_spawned=0
	for entry in entries:arena.room.wave_roster.append({"kind":entry.kind,"rank":entry.rank,"weapon":entry.get("weapon",EnemyLoadouts.default_for(entry.kind)),"state":"queued"})
	if not arena.room.boss_room and "vehicle" in Game.bonus_unlocks and (arena.room.room_index in [0,2,4] and index==2):
		arena.drop_pickup(Vector2i(arena.room.base_cell.x,arena.room.grid_size-3),"vehicle")
	if not arena.room.boss_room and "turret" in Game.bonus_unlocks and arena.room.room_index>=2 and index==0:arena.drop_pickup(arena.room.base_cell,"turret")
	arena.surprises.start_wave()
	arena.effects.emit("wave_start",{"wave":index})
	for marker in arena.room.spawn_markers:
		if is_instance_valid(marker):preload("res://scripts/battle_stage.gd").vanish(marker,.14,0.0)
	arena.room.spawn_markers.clear()
	if not arena.room.boss_room:
		for cell in WaveDirector.side_spawn_cells(arena.room.grid_size,index):
			var direction=Vector2i.RIGHT if cell.x==0 else Vector2i.LEFT
			arena.room.spawn_markers.append(arena.create_spawn_marker(cell,direction))
	arena.room.spawn_timer = .2
	Game.reset_input()
	if arena.hud: arena.hud.close_modal()
	if is_instance_valid(arena.presentation):arena.presentation.prepare_wave(index)

func finish_wave():
	if arena.phase!="combat" or arena.enemy_count()>0 or not arena.spawn_queue.is_empty():return
	arena.surprises.end_wave()
	arena.reward.collect_resources()
	if Campaign.endless and (arena.room.boss_defeated if arena.room.boss_room else arena.room.wave==2 and arena.room.room_boss_spawned):
		for pickup in arena.room.pickups:
			if pickup.kind=="recipe_draft":arena.reward.open_recipe_draft(pickup);return
	if arena.room.boss_room:
		if arena.room.boss_defeated and not arena.room.pickups.any(func(p):return p.kind=="recipe_draft"):
			if arena.room.room_cleared:return
			arena.room.room_cleared=true;arena.room.reward_claimed=true
			Game.progression.record_field(arena.room_index)
			if Campaign.world==3 and not Campaign.endless and arena.room.room_index==6:
				arena.phase="paused";arena.hud.show_final_preparation()
			elif Campaign.endless:
				arena.phase="paused";depart_room()
			else:
				Game.progression.complete_world(Campaign.world)
				finish_run(true,"Мир %d завершён · %s" % [Campaign.world,Campaign.WORLDS[Campaign.world].name])
		return
	if arena.room.wave==2 and not arena.room.room_boss_spawned:
		arena.room.commander_countdown=true;arena.countdown=3.0;arena.phase="countdown"
		Game.reset_input()
		arena.presentation.announce("Командир · 3","",.65);Game.music_stinger("commander")
		return
	Game.progression.event("waves")
	if arena.room.wave==2:Game.progression.record_field(arena.room.room_index)
	Game.save_progress()
	if is_instance_valid(arena.presentation):arena.presentation.announce("Поле боя зачищено" if arena.room.wave==2 else "Волна завершена","",.9)
	Game.music_stinger("wave_victory")
	arena.room.next_is_room=arena.room.wave==2
	arena.room.upgrade_offers.clear()
	if arena.room.next_is_room:
		arena.room.room_cleared=true
		# A breather after every cleared field: the soldier patches up 1 HP (never above the maximum).
		var patched=minf(ROOM_HEAL,arena.run.soldier_max_hp-arena.run.soldier_hp)
		if patched>0:
			arena.run.soldier_hp+=patched
			if is_instance_valid(arena.room.player) and arena.room.player.kind=="soldier":arena.room.player.hp=arena.run.soldier_hp;arena.room.player.refresh_health()
			arena.toast("Передышка · +%s здоровья" % UiKit.number(patched))
		var reward=Balance.CONFIG.economy.clear_reward+Campaign.progress_index(arena.room.room_index)*Balance.CONFIG.economy.clear_reward_per_room
		Game.earn(reward);arena.run.earned+=reward
		place_flag("Награда · +%d ◈" % reward)
		arena.toast("Маршрут открыт")
		if Campaign.endless:open_flag()
		return
	arena.phase="upgrade"
	Game.reset_input()
	for bullet in arena.room.projectiles.duplicate():
		if is_instance_valid(bullet):bullet.consume()
	arena.hud.show_upgrades()

func finish_run(won: bool,reason: String):
	if arena.phase=="result": return
	# Sandbox never ends a run: the soldier and the HQ come back on the spot.
	if arena.sandbox and not won:sandbox_respawn.call_deferred(reason);return
	if won:arena.reward.collect_resources()
	# Defeat fanfare comes from the battle theme; the effect stays when music is muted.
	if won or Settings.values.music<=.01 or not is_instance_valid(Game.music_controller):Game.sound("rare_reveal" if won else "defeat",arena)
	else:Game.music_stinger("defeat")
	arena.phase="result"
	if not won:
		arena.run.lost_run=true
		if not arena.sandbox:Game.progression.event("deaths")
		var loss=mini(Game.credits,roundi(arena.run.earned*Game.death_loss_fraction()))
		arena.run.lost_alloy=loss;Game.credits-=loss;Game.save_progress()
		var carried=arena.run.pending_recipes.duplicate(true)
		arena.run.pending_recipes=preload("res://scripts/recipe_extraction.gd").survivors(arena.run.pending_recipes,false,Game.rescue_level,arena.run.combat_rng,int(arena.run.safe_slots))
		arena.set_meta("saved_recipes",arena.run.pending_recipes.duplicate(true));arena.set_meta("lost_recipes",carried.filter(func(r):return r not in arena.run.pending_recipes))
		if not arena.run.pending_recipes.is_empty():Game.bank_recipes(arena.run.pending_recipes)
	Game.reset_input()
	if won:
		if Campaign.is_final(arena.room.room_index):Game.superboss_defeated=true
		arena.run.earned+=20;Game.earn(20)
	Game.clear_run_checkpoint()
	if won:arena.hud.show_result(won,reason)
	else:preload("res://scripts/death_presentation.gd").play(arena,arena.base_hp<=0,func():
		if is_instance_valid(arena) and arena.is_inside_tree():arena.hud.show_result(false,reason))

func pause_battle():
	if arena.phase in ["combat","countdown"]:
		arena.room.previous_phase=arena.phase;arena.phase="paused";Game.reset_input();arena.hud.show_pause()
	elif arena.phase=="paused":
		arena.phase=arena.room.previous_phase;arena.hud.close_modal()

## Exit flag in front of the HQ; the room is left through it.
func place_flag(caption:String):
	arena.room.flag=Node3D.new();arena.add_child(arena.room.flag);arena.room.flag.position=arena.world_pos(Vector2i(arena.room.base_cell.x,arena.room.grid_size-3))
	ExitFlag.build(arena.room.flag)
	Visuals.label3d(arena.room.flag,caption,Vector3(0,3.35,0),Color("f5edcc"),25)
	preload("res://scripts/battle_stage.gd").rise(arena.room.flag,.35)
func open_flag():
	arena.room.flag_armed=false;arena.phase="upgrade";Game.reset_input()
	if arena.room.reward_claimed:arena.hud.show_departure()
	else:arena.hud.show_upgrades()

func return_to_field():
	arena.hud.close_modal();arena.phase="combat";arena.room.flag_armed=false;Game.reset_input()

func depart_room():
	if arena.phase=="map":return
	arena.hud.close_modal();arena.phase="map";Game.reset_input()
	if is_instance_valid(arena.presentation):
		arena.presentation.announce("Путь открыт","Следующая комната" if Campaign.endless else "Возвращаемся на карту",.35)
		# The soldier boards, the HQ drives off and knocks the leftover defence bricks; then the map opens.
		preload("res://scripts/battle_stage.gd").outro(arena,func():
			if is_instance_valid(arena) and arena.is_inside_tree() and arena.phase=="map":arena.map_requested.emit(arena.room.room_index+1))
	else:arena.map_requested.emit(arena.room.room_index+1)


func transition(next:String):
	assert(next in PHASES,"Unknown battle phase: "+next)
	if next==current:return
	var previous=current
	current=next
	changed.emit(previous,current)

func sandbox_respawn(reason:String):
	var cell=Vector2i(arena.room.base_cell.x,arena.room.grid_size-3)
	if not is_instance_valid(arena.room.player) or arena.room.player.dead:
		arena.run.soldier_hp=arena.run.soldier_max_hp
		arena.room.player=arena.spawn_actor("soldier",arena.find_free_near(cell),true)
		arena.room.player.invulnerable=1.5
	arena.room.base_hp=arena.room.base_max_hp
	if is_instance_valid(arena.room.base_bar):arena.room.base_bar.set_health(arena.room.base_hp,arena.room.base_max_hp)
	arena.phase="combat"
	arena.toast(reason+" · возрождение")
