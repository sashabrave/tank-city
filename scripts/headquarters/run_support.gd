extends RefCounted
## The HQ in battle (author, 4 Oct 2026): every module acts on its own rule, there is no HQ key.
##   Аптечка  — a medkit next to the HQ every interval; one lying at a time, a blocked delivery waits «ready».
##   Броня    — passive HQ durability.
##   Ремонт   — after QUIET seconds without hits the HQ repairs in steps; the player's vehicle near the HQ too.
##   Медпункт — heals the hero on foot near the HQ in portions from a stock; an empty stock recharges.
##   Оборона  — an enemy close to the HQ sets off a pulse: damage and stun around, enemy rounds burnt; then recharge.
##   Купол    — the first hit raises a dome: the HQ takes no damage for a few seconds; then recharge.
## Timers count only in the «combat» phase. No randomness: the modules never touch the combat generator.
var arena
var modules:Array=[]
var levels:Dictionary={}
## Seconds until the module is ready again (0 = ready and waiting for its rule).
var timers:Dictionary={}
var shield_time=0.0
var hit_delay=0.0
var medpost_stock=0.0
var medpost_step=0.0
var basic_hp=5.0
## Triggers for the HUD (icon and caption over the HQ): {id, text}. The battle panel takes them.
var events:Array=[]
var dome:Node3D
func _init(context):
	arena=context;modules=HQCatalog.migrate_ids(Game.hq_modules).filter(func(id):return HQCatalog.available(id));levels=HQCatalog.migrate_levels(Game.hq_levels)
	basic_hp=Balance.CONFIG.combat.base_health+int(Game.health_level/5.0)+Game.base_level
	if Campaign.challenge_level()>=2:basic_hp=maxf(1,roundf(basic_hp*.75))  # challenge II: weaker HQ
func level(id:String)->float:return float(levels.get(id,0))
func max_hp()->float:return basic_hp+(3+level("hq_plating")*2 if "hq_plating" in modules else 0)
func room_started():
	timers.clear();shield_time=0;hit_delay=0;medpost_step=0;events.clear();clear_dome()
	medpost_stock=HQCatalog.medpost_stock(level("hq_medpost"))
	for id in modules:timers[id]=HQCatalog.interval(id,level(id)) if id=="hq_medbay" else 0.0
	arena.base_max_hp=max_hp();arena.base_hp=arena.base_max_hp
func origin()->Vector3:return arena.world_pos(arena.base_cell)
func tick(delta:float):
	if arena.phase!="combat":return
	hit_delay=maxf(0,hit_delay-delta);medpost_step=maxf(0,medpost_step-delta)
	if shield_time>0:
		shield_time=maxf(0,shield_time-delta)
		if shield_time<=0:clear_dome()
	for id in modules:
		if HQCatalog.DATA[id].mode=="passive":continue
		var was=float(timers.get(id,0.0));timers[id]=maxf(0,was-delta)
		if id=="hq_medpost" and was>0 and timers[id]<=0:medpost_stock=HQCatalog.medpost_stock(level(id))  # recharged
		if timers[id]>0:continue
		# Ready: the rule decides. A module that cannot act yet stays ready (no jump back to a short retry).
		trigger(id)
## One check of a ready module's rule; true when it acted (and went on its timer).
func trigger(id:String)->bool:
	var n=level(id)
	match id:
		"hq_medbay":
			if hq_medkit_lying() or not supply(n):return false
			timers[id]=HQCatalog.interval(id,n);notify(id,"Аптечка")
		"hq_regen":
			var amount=HQCatalog.repair_amount(n);var done=0.0
			if hit_delay<=0 and arena.base_hp<arena.base_max_hp:done+=repair(amount)
			var vehicle=nearby_vehicle()
			if vehicle!=null:
				var fixed=minf(amount,vehicle.max_hp-vehicle.hp);vehicle.hp+=fixed;vehicle.refresh_health();arena.floating_number(vehicle.position,fixed);done+=fixed
			if done<=0:return false
			timers[id]=HQCatalog.interval(id,n);notify(id,"Ремонт +"+UiKit.number(snappedf(amount,.1)))
		"hq_medpost":
			if medpost_step>0 or medpost_stock<=0:return false
			var hero=arena.player
			if not is_instance_valid(hero) or hero.dead or hero.kind!="soldier" or arena.flat_distance(origin(),hero.position)>HQCatalog.MEDPOST_REACH:return false
			var healed=minf(minf(HQCatalog.MEDPOST_PORTION,medpost_stock),arena.soldier_max_hp-arena.soldier_hp)
			if healed<=.001:return false
			arena.soldier_hp+=healed;hero.hp=arena.soldier_hp;hero.refresh_health();arena.floating_number(hero.position,healed)
			medpost_stock-=healed;medpost_step=HQCatalog.MEDPOST_STEP;notify(id,"Медпункт +"+UiKit.number(snappedf(healed,.1)))
			if medpost_stock<=.001:medpost_stock=0;timers[id]=HQCatalog.interval(id,n)
		"hq_tesla":
			var enemies=targets(HQCatalog.DEFENCE_REACH)
			if enemies.is_empty():return false
			for enemy in enemies:
				arc(enemy.position);enemy.stun_time=maxf(enemy.stun_time,HQCatalog.defence_stun(n));enemy.take_damage(HQCatalog.defence_damage(n))
			for bullet in arena.projectiles.duplicate():
				if is_instance_valid(bullet) and not bullet.friendly and not bullet.spent and arena.flat_distance(origin(),bullet.position)<=HQCatalog.DEFENCE_REACH:arc(bullet.position);bullet.consume()
			pulse(Color("92d8eb"));Game.sound("shield_restore",arena)
			timers[id]=HQCatalog.interval(id,n);notify(id,"Оборона")
		"hq_field":return false  # raised by a hit (hit()), not by the timer
		_:return false
	return true
## Every hit on the HQ goes through here first (CombatSystem.damage_base): false — the dome takes it.
## The hit that raises the dome still lands; the dome covers the HQ from the next one on.
func hit()->bool:
	if shield_time>0:
		if is_instance_valid(dome):
			var material:StandardMaterial3D=dome.material_override
			var t=dome.create_tween();t.tween_property(material,"albedo_color:a",.5,.05);t.tween_property(material,"albedo_color:a",.24,.2)
		return false
	hit_delay=HQCatalog.QUIET
	if "hq_field" in modules and float(timers.get("hq_field",0.0))<=0:
		var n=level("hq_field");shield_time=HQCatalog.dome_time(n)
		timers["hq_field"]=shield_time+HQCatalog.interval("hq_field",n)  # the recharge starts when the dome falls
		raise_dome();Game.sound("shield_restore",arena);notify("hq_field","Купол")
	return true
func hq_medkit_lying()->bool:return arena.pickups.any(func(p):return p.get("hq_medkit",false) and is_instance_valid(p.get("node")))
func nearby_vehicle():
	var hero=arena.player
	if not is_instance_valid(hero) or hero.dead or hero.kind=="soldier" or not hero.player_owned:return null
	if arena.flat_distance(origin(),hero.position)>HQCatalog.VEHICLE_REACH or hero.hp>=hero.max_hp-.001:return null
	return hero
func notify(id:String,text:String):
	events.append({"id":id,"text":text});Game.progression.event("use_hq")  # quest «Связь со штабом»: the HQ helped
	if events.size()>8:events.pop_front()
func targets(radius:float)->Array:
	var result=arena.actors.filter(func(a):return is_instance_valid(a) and not a.dead and not a.player_owned and not a.allied and arena.flat_distance(origin(),a.position)<=radius)
	result.sort_custom(func(a,b):return origin().distance_squared_to(a.position)<origin().distance_squared_to(b.position));return result
func repair(amount:float)->float:
	var healed=minf(amount,arena.base_max_hp-arena.base_hp);arena.base_hp+=healed
	if is_instance_valid(arena.base_bar):arena.base_bar.set_health(arena.base_hp,arena.base_max_hp)
	arena.floating_number(origin(),healed);return healed
## Аптечка: a medkit on a free cell next to the HQ (up, left, right, down; then farther).
func supply(n:float)->bool:
	var place=Vector2i(-1,-1)
	for radius in [1,2,3]:
		for offset in [Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.DOWN]:
			var c=arena.base_cell+offset*radius
			if arena.can_enter(c) and not arena.pickups.any(func(p):return arena.grid_pos(p.node.position)==c):place=c;break
		if place.x>=0:break
	if place.x<0:return false
	var node=Node3D.new();arena.add_child(node);node.position=arena.world_pos(place)
	var visual=arena.LOOT.visual(node,"heart");Visuals.ring(node,Color("b3d7b1"),.4)
	arena.pickups.append({"node":node,"visual":visual,"kind":"heart","heal":Game.heal_amount()+n*.25,"hq_medkit":true})
	Game.sound("delivery_land",arena);return true
## Купол: a translucent blue dome over the HQ while shield_time runs.
func raise_dome():
	clear_dome()
	var mesh=MeshInstance3D.new();var sphere=SphereMesh.new();sphere.radius=1.55;sphere.height=1.9;sphere.is_hemisphere=true;sphere.radial_segments=32;sphere.rings=10;mesh.mesh=sphere
	var material=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color=Color(.55,.82,1.0,.24);material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.rim_enabled=false
	mesh.material_override=material;mesh.name="HQDome";mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arena.add_child(mesh);mesh.position=origin();dome=mesh
	mesh.scale=Vector3(.2,.2,.2);var t=mesh.create_tween();t.tween_property(mesh,"scale",Vector3.ONE,.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
func clear_dome():
	if is_instance_valid(dome):dome.queue_free()
	dome=null
func pulse(color:=Color("86c9b6")):
	var ring=Visuals.ring(arena,color,1);ring.position=origin()+Vector3.UP*.12
	var tween=arena.create_tween().set_parallel(true);tween.tween_property(ring,"scale",Vector3(3,1,3),.4);tween.tween_property(ring,"transparency",1.0,.4);tween.chain().tween_callback(ring.queue_free)
func arc(target:Vector3):
	var from=origin()+Vector3.UP*1.2;var to=target+Vector3.UP*.5
	var beam=Visuals.box(arena,(from+to)*.5,Vector3(.055,.055,from.distance_to(to)),Color("92d8eb"));beam.look_at(to)
	var tween=arena.create_tween();tween.tween_property(beam,"scale",Vector3.ZERO,.18);tween.tween_callback(beam.queue_free)
## Readiness 0…1 of a module for the HUD ring (1 = ready); a dome in the air and an emptying stock read as full.
func readiness(id:String)->float:
	if HQCatalog.DATA[id].mode=="passive":return 1.0
	var remaining=float(timers.get(id,0.0))
	if id=="hq_field" and shield_time>0:return 1.0
	var total=HQCatalog.interval(id,level(id))
	return clampf(1.0-remaining/maxf(total,.01),0,1)
func loadout()->Array:return modules
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
	var parts=id.split(":");var tech=HQCatalog.current(parts[1]);var oldmax=max_hp()
	if tech not in HQCatalog.DATA:return
	arena.run.upgrade_history.append({"id":tech,"detail":"Штаб","tier":tier})
	if parts[0]=="hq_up":levels[tech]=minf(10,level(tech)+Balance.tier_power(tier))
	else:
		var equipped=loadout().duplicate();var slot=clampi(int(parts[2]) if parts.size()>2 else 0,0,Game.hq_slots-1)
		if tech not in equipped:
			if slot<equipped.size():equipped[slot]=tech
			else:equipped.append(tech)
		modules=equipped.slice(0,Game.hq_slots)
		timers[tech]=HQCatalog.interval(tech,level(tech)) if tech=="hq_medbay" else 0.0
		if tech=="hq_medpost":medpost_stock=HQCatalog.medpost_stock(level(tech))
		if "hq_field" not in modules:shield_time=0;clear_dome()
	arena.base_max_hp=max_hp();arena.base_hp=clampf(arena.base_hp+maxf(0,max_hp()-oldmax),0,arena.base_max_hp)
	if is_instance_valid(arena.base_bar):arena.base_bar.set_health(arena.base_hp,arena.base_max_hp)
	Game.progression.event("hq_run_upgrade")
func card(offer:Dictionary)->Dictionary:
	var parts=offer.id.split(":");var id=HQCatalog.current(parts[1]);var data=HQCatalog.DATA[id];var description=""
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
