extends RefCounted
## Executes abilities. Cooldowns, loadout and upgrade levels stay in RunAbility.
func execute(ability)->bool:
	var arena=ability.arena
	# Remote fuse (T-295): the mine key blows the oldest placed mine; no cooldown is spent.
	if ability.selected=="mine" and ability.mine_detonates() and arena.phase in ["combat","countdown"] and is_instance_valid(arena.player) and not arena.player.dead:
		var mine=ability.live_mines().pop_front();ability.mines.erase(mine);mine.detonate();return true
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
		laser_beam(arena,p,end)
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
			if ability.mines.size()>=ability.mine_limit():arena.toast("Лимит мин");return false
		var effect=load("res://scripts/ability_effect.gd").new();effect.arena=arena;effect.kind=ability.selected;effect.power=ability.power();effect.utility=ability.level.utility;effect.position=p.position;arena.add_child(effect)
		if ability.selected=="mine":ability.mines.append(effect)
	ability.cooldown=ability.interval()+(ability.shield_time if ability.selected=="shield" else 0.0);ability.cooldown_totals[ability.selected]=ability.cooldown;Game.sound({"barrier":"barrier_deploy","grenade":"grenade_throw","laser":"laser_fire","shield":"shield_restore","cloak":"cloak","mine":"mine_arm","dynamite":"mine_arm","comrade":"delivery_land"}.get(ability.selected,"ability_generic"),p);return true

## Gadget laser look (T-296): a thin red beam from the gun's muzzle, hotter than the sniper's sight, strobing hard
## for half a second; a red flash where it stops. Visual only.
const LASER_RED:=Color("ff2335")
const LASER_SECONDS:=.5
static var laser_core:ShaderMaterial
static var laser_halo:ShaderMaterial
func laser_beam(arena,p,end:Vector3):
	if laser_core==null:
		laser_core=ShaderMaterial.new();laser_core.shader=preload("res://shaders/fx/gadget_laser.gdshader");laser_core.set_shader_parameter("color",LASER_RED)
		laser_halo=laser_core.duplicate();laser_halo.set_shader_parameter("halo",1.0)
	var start:Vector3=arena.to_local(Gun.muzzle(p,p.facing).flash)
	var stop=Vector3(end.x,start.y,end.z);var length=maxf(.1,start.distance_to(stop))
	var beam=Node3D.new();beam.name="GadgetLaser";arena.add_child(beam);beam.position=(start+stop)*.5;beam.rotation.y=atan2(stop.x-start.x,stop.z-start.z)
	var parts=[]
	for spec in [[Vector3(.04,.04,length),laser_core],[Vector3(.17,.17,length),laser_halo]]:
		var box=Visuals.box(beam,Vector3.ZERO,spec[0],LASER_RED);box.material_override=spec[1];box.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parts.append(box)
	arena.burst(stop,LASER_RED,.3);arena.burst(start,LASER_RED.lightened(.3),.12)
	var tween=beam.create_tween()
	var burn=func(t:float):
		for box in parts:box.set_instance_shader_parameter("age",t)
	tween.tween_method(burn,0.0,1.0,LASER_SECONDS)
	tween.tween_callback(beam.queue_free)
