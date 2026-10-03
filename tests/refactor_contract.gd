extends Node
var checks=0
var failures=0
func check(ok,message):
	checks+=1
	if not ok:failures+=1;push_error(message)
func _ready():call_deferred("run_test")
func run_test():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false
	var baseline="--baseline" in OS.get_cmdline_user_args()
	# Golden master of arena behaviour. After a deliberate rule change, rerun with `-- --baseline` to rewrite the fixture.
	var source="res://scripts/arena.gd"
	var results=[]
	for seed_value in [42,137]:
		# [world, local stage]: first field, last field, general; world 3 also the gigaboss.
		for scenario in [[1,0],[1,5],[1,6],[2,0],[2,6],[3,6],[3,7]]:
			Campaign.configure(scenario[0]);var stage=scenario[1]
			Game.reset_upgrades();Game.health_level=6;Game.damage_level=3;Game.base_level=4;Game.bonus_unlocks=Game.LOOT.BONUSES.keys();Game.weapon_unlocks=Game.LOOT.gun_ids()
			var arena=load(source).new();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false);arena.hud.set_process(false)
			arena.run_seed=seed_value;arena.combat_rng.seed=seed_value;arena.begin_room(stage);arena.phase="combat";arena.player.set_physics_process(false)
			var result={"seed":seed_value,"world":scenario[0],"stage":stage,"layout":arena.current_layout.duplicate(),"wave":arena.wave_roster.duplicate(true),"hero":[arena.soldier_hp,arena.soldier_max_hp,arena.base_hp,arena.player.damage,arena.player.fire_interval,arena.player_pressure()],"enemies":[]}
			for kind in ["soldier","shield","sniper","grenadier","buggy","apc","tank","drone","flyer","mortar"]:
				var actor=arena.spawn_actor(kind,Vector2i(1,1),false,false,2);actor.set_physics_process(false)
				# No path step here: path search runs on a per-frame time budget (navigation_cache and terrain tests cover it).
				result.enemies.append([kind,actor.max_hp,actor.damage,actor.speed,actor.fire_interval,actor.pressure(),str(arena.enemy_aim(actor))])
				arena.actors.erase(actor);actor.free()
			result.chests=[]
			for i in range(5):result.chests.append(arena.chest_offers())
			var wall_cells=arena.walls.keys();wall_cells.sort();result.walls=[]
			for cell in wall_cells:result.walls.append([str(cell),arena.walls[cell].hp])
			var front=arena.player.cell+arena.player.facing
			if arena.walls.has(front):arena.walls[front].node.free();arena.walls.erase(front)
			arena.abilities.select("barrier");arena.abilities.cast();result.barrier=[arena.walls[front].hp,arena.abilities.cooldown]
			var wreck=arena.make_wreck("tank",arena.player.cell+Vector2i.LEFT,Vector2i.UP,false,7)
			arena.interact();result.board=[arena.player.kind,arena.player.hp,arena.player.damage,arena.player.speed]
			arena.interact();result.exit=[arena.player.kind,arena.player.hp,arena.wrecks.size()]
			result.rng_state=str(arena.combat_rng.state)
			results.append(result);arena.queue_free();await get_tree().process_frame
	var path="res://tests/fixtures/refactor_contract.json"
	if baseline:
		FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(results,"\t"));print("CONTRACT BASELINE: ",results.size()," scenarios")
	else:
		var expected=JSON.parse_string(FileAccess.get_file_as_string(path))
		# JSON normalization removes intentional int/float representation differences.
		var actual=JSON.parse_string(JSON.stringify(results))
		for i in range(results.size()):
			for key in actual[i]:
				# Wave composition changed intentionally; covered by editor_workflow invariants.
				if key=="wave":continue
				check(actual[i][key]==expected[i][key],"Behavior changed at scenario %d: %s" % [i,key])
		print("REFACTOR CONTRACT: ",checks," checks, ",failures," failures")
	get_tree().quit(1 if failures else 0)
