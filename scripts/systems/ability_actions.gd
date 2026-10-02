extends RefCounted
## Executes abilities. Cooldowns, loadout and upgrade levels stay in RunAbility.
func execute(ability)->bool:
	var arena=ability.arena
	if ability.selected=="" or ability.cooldown>0 or arena.phase not in ["combat","countdown"] or not is_instance_valid(arena.player) or arena.player.dead:return false
	var p=arena.player
	if ability.selected=="field_repair":
		if p.kind=="soldier":
			if arena.soldier_hp>=arena.soldier_max_hp:return false
			arena.soldier_hp=minf(arena.soldier_max_hp,arena.soldier_hp+ability.power()/3);p.hp=arena.soldier_hp
		else:
			if p.hp>=p.max_hp:return false
			p.hp=minf(p.max_hp,p.hp+ability.power())
		p.refresh_health();arena.floating_number(p.position,ability.power()/3 if p.kind=="soldier" else ability.power())
	elif ability.selected=="barrier":
		var cell=p.cell+p.facing
		if not arena.can_enter(cell):arena.toast("Нет места перед героем");return false
		ability.barriers=ability.barriers.filter(func(c):return arena.walls.has(c) and arena.walls[c].get("barrier",false))
		if not arena.add_barrier(cell,ability.power()):return false
		while ability.barriers.size()>=ability.barrier_count():
			var old=ability.barriers.pop_front()
			if arena.walls.has(old):arena.walls[old].node.queue_free();arena.walls.erase(old);arena.navigation.invalidate(old)
		ability.barriers.append(cell)
	elif ability.selected=="grenade":
		var grenade=load("res://scenes/grenade.tscn").instantiate()
		grenade.arena=arena;grenade.friendly=true;grenade.damage=ability.power();grenade.blast_radius=ability.radius()
		grenade.target=p.position+Vector3(p.facing.x,0,p.facing.y)*5;grenade.position=p.position+Vector3.UP*.8;grenade.flight_time=.65;grenade.fuse=maxf(.35,Balance.CONFIG.combat.grenade_fuse-ability.level.utility*.1)
		arena.add_child(grenade);arena.grenades.append(grenade)
	elif ability.selected=="laser":
		var cell=p.cell;var concrete=0;var hit=[];var end=p.position
		for step in range(arena.grid_size):
			cell+=p.facing
			if not arena.inside(cell):break
			end=arena.world_pos(cell)
			if arena.walls.has(cell):
				if arena.walls[cell].hp<0:
					concrete+=1
					if concrete>ability.laser_walls():break
				else:arena.damage_wall(cell,ability.power())
			if arena.nets.has(cell):arena.shred_net(cell)
			for enemy in arena.actors.duplicate():
				if not is_instance_valid(enemy) or enemy.dead or enemy.player_owned or enemy.allied or enemy in hit:continue
				if cell in arena.cells_for(enemy,arena.grid_pos(enemy.position) if enemy.kind=="flyer" else enemy.cell):
					hit.append(enemy);enemy.take_damage(ability.power())
		var beam=Visuals.box(arena,(p.position+end)*.5+Vector3.UP*.65,Vector3(.15,.15,maxf(.1,p.position.distance_to(end))),Color("79dbfa"))
		beam.material_override=Visuals.material(Color("79dbfa"),true);beam.rotation.y=atan2(end.x-p.position.x,end.z-p.position.z)
		arena.create_tween().tween_property(beam,"scale",Vector3.ZERO,.3).finished.connect(beam.queue_free)
	elif ability.selected=="comrade":
		if arena.actors.any(func(a):return is_instance_valid(a) and a.companion and not a.dead):arena.toast("Товарищ уже в бою");return false
		arena.summon_comrade(ability.power(),ability.level.utility)
	elif ability.selected=="shield":ability.shield_time=ability.shield_duration()
	elif ability.selected=="cloak":ability.cloak_time=ability.power()+ability.level.utility;ability.cloak_ghost=ability.level.utility>=3
	elif ability.selected=="ally_drone":
		var drones=arena.actors.filter(func(a):return is_instance_valid(a) and a.allied and a.kind=="flyer" and not a.dead)
		if drones.size()>=mini(3,1+int(ability.level.utility)):arena.toast("Лимит помощников");return false
		var drone=arena.spawn_actor("flyer",arena.find_free_near(p.cell),false,true)
		drone.max_hp=ability.power();drone.hp=drone.max_hp;drone.damage=1+ability.level.power*.2;drone.refresh_health()
	elif ability.selected in ["gas","mine","airstrike","dynamite"]:
		if ability.selected=="mine":
			ability.mines=ability.mines.filter(func(m):return is_instance_valid(m) and not m.is_queued_for_deletion())
			if ability.mines.size()>=mini(5,1+int(ability.level.utility)):arena.toast("Лимит мин");return false
		var effect=load("res://scripts/ability_effect.gd").new();effect.arena=arena;effect.kind=ability.selected;effect.power=ability.power();effect.utility=ability.level.utility;effect.position=p.position;arena.add_child(effect)
		if ability.selected=="mine":ability.mines.append(effect)
	ability.cooldown=ability.interval()+(ability.shield_time if ability.selected=="shield" else 0.0);ability.cooldown_totals[ability.selected]=ability.cooldown;Game.sound({"barrier":"barrier_deploy","grenade":"grenade_throw","laser":"laser_fire","shield":"shield_restore","cloak":"cloak","mine":"mine_arm","dynamite":"mine_arm","comrade":"delivery_land"}.get(ability.selected,"ability_generic"),p);return true
