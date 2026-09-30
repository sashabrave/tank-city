extends RefCounted
var arena
var modules:Array=[]
var active=""
var levels:Dictionary={}
var timers:Dictionary={}
var delivered:Dictionary={}
var cooldown=0.0
var shield_time=0.0
var emp_time=0.0
var hit_delay=0.0
var basic_hp=5.0
func _init(context):
	arena=context;modules=Game.hq_modules.filter(func(id):return HQCatalog.available(id)).duplicate();active=Game.hq_active if HQCatalog.available(Game.hq_active) else "";levels=Game.hq_levels.duplicate()
	basic_hp=Balance.CONFIG.combat.base_health+int(Game.health_level/5.0)+Game.base_level
func level(id:String)->float:return float(levels.get(id,0))
func max_hp()->float:return basic_hp+(3+level("hq_plating")*2 if "hq_plating" in modules else 0)
func room_started():
	delivered.clear();timers.clear();shield_time=0;emp_time=0;hit_delay=0
	for id in modules:timers[id]=HQCatalog.interval(id,level(id))
	arena.base_max_hp=max_hp();arena.base_hp=arena.base_max_hp
func origin()->Vector3:return arena.world_pos(arena.base_cell)
func tick(delta:float):
	if arena.phase!="combat":return
	emp_time=maxf(0,emp_time-delta)
	cooldown=maxf(0,cooldown-delta);shield_time=maxf(0,shield_time-delta);hit_delay=maxf(0,hit_delay-delta)
	if shield_time>0 and is_instance_valid(arena.player) and arena.flat_distance(origin(),arena.player.position)<=3:arena.player.invulnerable=maxf(arena.player.invulnerable,.2)
	for id in modules:
		if HQCatalog.DATA[id].mode=="passive":continue
		timers[id]=maxf(0,timers.get(id,HQCatalog.interval(id,level(id)))-delta)
		if timers[id]>0:continue
		if trigger(id):timers[id]=HQCatalog.interval(id,level(id))
		else:timers[id]=1.0
func trigger(id:String)->bool:
	var n=level(id)
	match id:
		"hq_medbay","hq_supply":
			if id=="hq_supply" and int(delivered.get(id,0))>=1+int(n/3):return false
			if not supply("heart" if id=="hq_medbay" else "vehicle_repair",n):return false
			delivered[id]=int(delivered.get(id,0))+1
		"hq_regen":
			if hit_delay>0 or arena.base_hp>=arena.base_max_hp:return false
			repair(.5+n*.25)
		"hq_interceptor":
			var nearest=null;var distance=2.5
			for bullet in arena.projectiles:
				if not is_instance_valid(bullet) or bullet.friendly or bullet.spent:continue
				var d=arena.flat_distance(origin(),bullet.position)
				if d<distance:nearest=bullet;distance=d
			if nearest==null:return false
			arc(nearest.position);nearest.consume()
		"hq_tesla":
			var enemies=targets(2.8)
			if enemies.is_empty():return false
			for enemy in enemies.slice(0,3):arc(enemy.position);enemy.take_damage(1.5+n*.35)
	return true
func targets(radius:float)->Array:
	var result=arena.actors.filter(func(a):return is_instance_valid(a) and not a.dead and not a.player_owned and not a.allied and arena.flat_distance(origin(),a.position)<=radius)
	result.sort_custom(func(a,b):return origin().distance_squared_to(a.position)<origin().distance_squared_to(b.position));return result
func repair(amount:float):
	var healed=minf(amount,arena.base_max_hp-arena.base_hp);arena.base_hp+=healed
	if is_instance_valid(arena.base_bar):arena.base_bar.set_health(arena.base_hp,arena.base_max_hp)
	arena.floating_number(origin(),healed)
func supply(kind:String,n:float)->bool:
	var place=Vector2i(-1,-1)
	for radius in [1,2,3]:
		for offset in [Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.DOWN]:
			var c=arena.base_cell+offset*radius
			if arena.can_enter(c) and not arena.pickups.any(func(p):return arena.grid_pos(p.node.position)==c):place=c;break
		if place.x>=0:break
	if place.x<0:return false
	var node=Node3D.new();arena.add_child(node);node.position=arena.world_pos(place)
	var visual=arena.LOOT.visual(node,kind);Visuals.ring(node,Color("b3d7b1"),.4)
	arena.pickups.append({"node":node,"visual":visual,"kind":kind,"hq_heal":Game.heal_amount()+n*.25})
	Game.sound("delivery_land",arena);return true
func cast()->bool:
	if arena.phase!="combat" or active=="" or cooldown>0 or arena.base_hp<=0:return false
	var n=level(active)
	match active:
		"hq_patch":
			repair(3+n*.6)
			if is_instance_valid(arena.player) and arena.flat_distance(origin(),arena.player.position)<=3:
				var healed=minf(1+n*.25,arena.soldier_max_hp-arena.soldier_hp);arena.soldier_hp+=healed
				if arena.player.kind=="soldier":arena.player.hp=arena.soldier_hp;arena.player.refresh_health()
				arena.floating_number(arena.player.position,healed)
		"hq_field":shield_time=minf(8,5+n*.5)
		"hq_emp":
			emp_time=2+n*.15
			for enemy in targets(4):arc(enemy.position);enemy.stun_time=maxf(enemy.stun_time,2+n*.15);enemy.take_damage(4+n*.6)
	cooldown=HQCatalog.interval(active,n);pulse();Game.sound("shield_restore",arena);Game.progression.event("use_hq");return true
func pulse():
	var ring=Visuals.ring(arena,Color("86c9b6"),1);ring.position=origin()+Vector3.UP*.12
	var tween=arena.create_tween().set_parallel(true);tween.tween_property(ring,"scale",Vector3(3,1,3),.4);tween.tween_property(ring,"transparency",1.0,.4);tween.chain().tween_callback(ring.queue_free)
func arc(target:Vector3):
	var from=origin()+Vector3.UP*1.2;var to=target+Vector3.UP*.5
	var beam=Visuals.box(arena,(from+to)*.5,Vector3(.055,.055,from.distance_to(to)),Color("92d8eb"));beam.look_at(to)
	var tween=arena.create_tween();tween.tween_property(beam,"scale",Vector3.ZERO,.18);tween.tween_callback(beam.queue_free)
func loadout()->Array:return ([active] if active!="" else [])+modules
func offers(_at_service:bool=false)->Array:
	var result=[];var equipped=loadout()
	for id in equipped:
		if level(id)<10:result.append({"id":"hq_up:"+id,"tier":HQCatalog.DATA[id].rarity})
	for id in Game.purchased_hq:
		if HQCatalog.available(id) and id not in equipped:
			var slot=mini(equipped.size(),Game.hq_slots-1)
			result.append({"id":"hq_swap:"+id+":"+str(slot),"tier":HQCatalog.DATA[id].rarity})
	return result
func apply(id:String,tier:int):
	var parts=id.split(":");var tech=parts[1];var oldmax=max_hp()
	arena.run.upgrade_history.append({"id":tech,"detail":"Штаб","tier":tier})
	if parts[0]=="hq_up":levels[tech]=minf(10,level(tech)+Balance.tier_power(tier))
	else:
		var equipped=loadout();var slot=clampi(int(parts[2]),0,Game.hq_slots-1)
		if HQCatalog.DATA[tech].mode=="active" and active!="":equipped.erase(active)
		if slot<equipped.size():equipped[slot]=tech
		else:equipped.append(tech)
		active="";modules=[]
		for entry in equipped.slice(0,Game.hq_slots):
			if HQCatalog.DATA[entry].mode=="active":active=entry
			else:modules.append(entry)
		if active!="":cooldown=maxf(cooldown,HQCatalog.interval(active,level(active)))
		timers[tech]=HQCatalog.interval(tech,level(tech))
	arena.base_max_hp=max_hp();arena.base_hp=clampf(arena.base_hp+maxf(0,max_hp()-oldmax),0,arena.base_max_hp)
	if is_instance_valid(arena.base_bar):arena.base_bar.set_health(arena.base_hp,arena.base_max_hp)
	Game.progression.event("hq_run_upgrade")
func card(offer:Dictionary)->Dictionary:
	var parts=offer.id.split(":");var id=parts[1];var data=HQCatalog.DATA[id];var description=""
	if parts[0]=="hq_up":description=stat_change(id,level(id),minf(10,level(id)+Balance.tier_power(offer.tier)))
	else:
		var equipped=loadout();var old=equipped[int(parts[2])] if int(parts[2])<equipped.size() else ""
		description=("Вместо: "+HQCatalog.DATA[old].name+"\n" if old!="" else "Свободный слот\n")+data.description
	return {"title":data.name,"detail":description,"icon":data.icon,"heading":LootCatalog.RARITY_NAMES[offer.tier],"category":"Штаб","color":Color(LootCatalog.RARITY_COLORS[offer.tier])}

func stat_change(id:String,before:float,after:float)->String:
	var previous=HQCatalog.stat(id,before);var next=HQCatalog.stat(id,after)
	var pattern=RegEx.new();pattern.compile("[0-9]+(?:[.,][0-9]+)?")
	var old_values=pattern.search_all(previous);var new_values=pattern.search_all(next)
	for i in range(mini(old_values.size(),new_values.size())-1,-1,-1):
		var old=old_values[i];var value=new_values[i].get_string()
		if old.get_string()!=value:previous=previous.substr(0,old.get_start())+old.get_string()+" → "+value+previous.substr(old.get_end())
	return previous
