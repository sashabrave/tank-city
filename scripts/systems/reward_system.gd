extends RefCounted
## Reward system. Owns rules; Arena remains the scene coordinator.
const START_EFFECTS=["health","speed","damage","intercept","fire","range","healing","device_power","device_cooldown"]
var arena

func _init(context):
	arena=context

func drop_pickup(_cell: Vector2i,kind: String):
	var candidates: Array[Vector2i]=[]
	var reachable=reachable_drop_cells()
	for candidate in reachable:
		if candidate.y<1 or candidate.y>=int(arena.room.grid_size/2.0):continue
		if arena.room.pickups.any(func(p):return arena.grid_pos(p.node.position)==candidate):continue
		candidates.append(candidate)
	if candidates.is_empty():
		for candidate in reachable:
			if not arena.room.pickups.any(func(p):return arena.grid_pos(p.node.position)==candidate):candidates.append(candidate)
	if candidates.is_empty():return
	var cell=candidates[arena.run.combat_rng.randi_range(0,candidates.size()-1)]
	if kind=="vehicle" and arena.unlocked_vehicle()=="":kind="repair" if "repair" in Game.bonus_unlocks else "heart"
	if kind=="turret" and arena.room.room_index<2:kind="repair" if "repair" in Game.bonus_unlocks else "heart"
	var node=Node3D.new();arena.add_child(node);node.position=arena.world_pos(cell)
	var visual=arena.LOOT.visual(node,kind)
	var info=arena.LOOT.BONUSES[kind]
	Visuals.ring(node,Color(arena.LOOT.RARITY_COLORS[info.rarity]),.42)
	var title=Visuals.label3d(node,info.name,Vector3(0,1.25,0),Color(info.color).lightened(.3),48)
	title.outline_size=3
	Visuals.label3d(node,arena.LOOT.RARITY_NAMES[info.rarity],Vector3(0,.91,0),Color(arena.LOOT.RARITY_COLORS[info.rarity]),18)
	arena.room.pickups.append({"node":node,"visual":visual,"kind":kind})

func collect_pickup(pickup: Dictionary):
	if pickup.kind=="recipe":
		if arena.run.pending_recipes.size()>=Game.backpack_slots:
			arena.room.recipe_offer=pickup;pickup["blocked"]=true;arena.pause_battle();return
		arena.run.pending_recipes.append(pickup.recipe);arena.toast("В рюкзаке: "+Game.recipe_name(pickup.recipe))
		arena.room.pickups.erase(pickup);pickup.node.queue_free();Game.sound("pickup",arena);return
	match pickup.kind:
		"star":
			arena.room.star_time=6+effective_bonus_level("star")*1.5;arena.toast("Звезда · неуязвимость и сокрушительный огонь!")
		"heart":
			var healed=minf(float(pickup.get("hq_heal",Game.heal_amount()*bonus_strength("heart")))*arena.run.healing_multiplier,arena.run.soldier_max_hp-arena.run.soldier_hp)
			arena.run.soldier_hp+=healed;arena.floating_number(arena.room.player.position,healed)
			if is_instance_valid(arena.room.player) and arena.room.player.kind=="soldier":arena.room.player.hp=arena.run.soldier_hp;arena.room.player.refresh_health()
		"pressure":arena.room.pressure_time=8+effective_bonus_level("pressure")*2
		"freeze":arena.room.freeze_time=3+effective_bonus_level("freeze")
		"turret":
			arena.install_turret()
		"vehicle_repair":
			if arena.room.player.kind=="soldier":arena.toast("Для ремонта займи технику");return
			var healed=minf((3+Game.heal_level*.15)*bonus_strength("vehicle_repair"),arena.room.player.max_hp-arena.room.player.hp)
			arena.room.player.hp+=healed;arena.room.player.refresh_health();arena.floating_number(arena.room.player.position,healed)
		"repair":
			var healed=minf((2+Game.heal_level*.15)*bonus_strength("repair"),arena.room.base_max_hp-arena.room.base_hp)
			arena.room.base_hp+=healed;arena.floating_number(arena.world_pos(arena.room.base_cell),healed)
			if is_instance_valid(arena.room.base_bar):arena.room.base_bar.set_health(arena.room.base_hp,arena.room.base_max_hp)
			arena.toast("База отремонтирована: +%.1f HP" % healed)
		"wall":
			for cell in [Vector2i(arena.room.base_cell.x-1,arena.room.grid_size-2),Vector2i(arena.room.base_cell.x,arena.room.grid_size-2),Vector2i(arena.room.base_cell.x+1,arena.room.grid_size-2),Vector2i(arena.room.base_cell.x-1,arena.room.grid_size-1),Vector2i(arena.room.base_cell.x+1,arena.room.grid_size-1)]:
				if arena.room.walls.has(cell) and arena.room.walls[cell].hp>0 and arena.room.base_hp>=arena.room.base_max_hp:
					arena.room.walls[cell].hp*=1.5;arena.room.walls[cell].max_hp*=1.5
					arena.room.walls[cell]["armor_level"]=arena.room.walls[cell].get("armor_level",0)+1
					if arena.room.walls[cell].has("sections"):
						for i in range(16):arena.room.walls[cell].sections[i]*=1.5
				elif arena.room.walls.has(cell) or arena.can_enter(cell):
					arena.add_wall(cell,4+effective_bonus_level("wall"));arena.board.shape_base_wall(cell)
			arena.toast("Защитные стены укреплены")
		"vehicle":
			var kind=arena.unlocked_vehicle()
			if kind!="":
				var cell=arena.find_free_near(Vector2i(arena.room.base_cell.x-2,arena.room.grid_size-3))
				var delivery=arena.make_wreck(kind,cell,Vector2i.UP,false,arena.vehicle.player_armor(kind))
				delivery.start_delivery((arena.room.grid_size-1)/3.8*.85*pow(.92,effective_bonus_level("vehicle")))
				arena.toast({"buggy":"Багги","apc":"БТР","tank":"Танк"}[kind]+" доставлен к базе. Садись в любое время.")
	Game.sound({"heart":"heal","repair":"repair","vehicle_repair":"armor_recover","star":"rare_reveal","wall":"barrier_deploy","freeze":"shield_restore","pressure":"pressure"}.get(pickup.kind,"pickup"),arena)
	arena.room.pickups.erase(pickup)
	pickup.node.queue_free()

func apply_upgrade(id: String,tier: int=0):
	var power=[1.0,1.5,2.0][tier]
	if arena.phase!="upgrade": return
	if not id.begins_with("hq_"):arena.run.upgrade_history.append({"id":id,"tier":tier})
	if id.begins_with("hq_"):arena.headquarters.apply(id,tier)
	if id in BehaviorCards.DATA and id not in arena.run.behavior_cards:arena.run.behavior_cards.append(id)
	match id:
		"damage":
			arena.run.damage_bonus+=.5*power
			if arena.room.player.kind=="soldier":arena.room.player.apply_weapon()
			else:arena.room.player.damage+=(.125 if arena.room.player.kind=="buggy" else .5)*power
		"intercept": arena.run.intercept_chance=minf(.95,arena.run.intercept_chance+.10*power)
		"speed": apply_speed_upgrade(power)
		"fire": arena.run.fire_multiplier*=1-.15*power; arena.room.player.fire_interval*=1-.15*power
		"weapon_damage":
			arena.run.weapon_mods[arena.run.weapon].damage+=.18*power
			if arena.room.player.kind=="soldier":arena.room.player.apply_weapon()
		"weapon_intercept":arena.run.weapon_mods[arena.run.weapon].intercept+=.05*power
		"weapon_fire":
			arena.run.weapon_mods[arena.run.weapon].interval*=1-.15*power
			if arena.room.player.kind=="soldier":arena.room.player.apply_weapon()
		"range":arena.run.range_multiplier+=.12*power
		"healing":arena.run.healing_multiplier+=.20*power
		"device_power":arena.run.ability_power_multiplier+=.15*power
		"device_cooldown":arena.run.ability_cooldown_multiplier*=pow(.9,power)
		"recovery":arena.abilities.shield_bonus+=power
		"pistol", "smg", "shotgun", "rifle", "sniper", "rpg":
			arena.run.weapon=id
			if arena.room.player.kind=="soldier":arena.room.player.apply_weapon()
		"health":
			arena.run.soldier_max_hp+=roundi(power); arena.run.soldier_hp=minf(arena.run.soldier_max_hp,arena.run.soldier_hp+roundi(power))
			if arena.room.player.kind=="soldier": arena.room.player.max_hp=arena.run.soldier_max_hp;arena.room.player.hp=arena.run.soldier_hp;arena.room.player.refresh_health()
	if is_instance_valid(arena.player) and arena.player.kind in GarageCatalog.VEHICLES:
		var stats=GarageCatalog.stats(arena.player.kind,arena,arena.player.vehicle_origin,arena.player.vehicle_zone)
		arena.player.damage=stats.damage;arena.player.fire_interval=stats.interval;arena.player.speed=stats.speed
	Game.sound("upgrade",arena)
	if is_instance_valid(arena.replay):arena.replay.call_deferred("next");return
	if arena.room.next_is_room:
		arena.room.reward_claimed=true;arena.hud.show_departure()
	else:arena.start_wave(arena.room.wave+1)

func can_extract_recipes() -> bool:
	return not arena.run.lost_run and arena.room.room_cleared

func resolve_recipes_on_return():
	Game.sound("extraction",Game)
	if arena.run.lost_run:arena.run.pending_recipes.clear();return
	# Voluntary extraction always banks the backpack, including from the detached map arena.
	Game.bank_recipes(arena.run.pending_recipes)

func recipe_summary() -> String:
	if arena.run.pending_recipes.is_empty():return "В рюкзаке нет чертежей."
	var names=PackedStringArray()
	for recipe in arena.run.pending_recipes:names.append(Game.recipe_name(recipe))
	return "Чертежи в рюкзаке: "+", ".join(names)

func drop_recipe(cell: Vector2i,_recipe: Dictionary):
	cell=arena.grid_pos(safe_drop_position(arena.world_pos(cell)))
	var elite=_recipe.get("elite",true)
	var node=Node3D.new();arena.add_child(node);node.position=arena.world_pos(cell)
	var visual=Node3D.new();node.add_child(visual)
	Visuals.box(visual,Vector3(0,.25,0),Vector3(.85,.5,.55),Color("637965"))
	Visuals.box(visual,Vector3(0,.52,0),Vector3(.9,.12,.6),Color("839579"))
	for x in [-.28,.28]:Visuals.box(visual,Vector3(x,.3,-.29),Vector3(.09,.5,.03),Color("d4bd73") if elite else Color("879486"))
	Visuals.ring(node,Color("ffd56a") if elite else Color("b7c3ae"),.55)
	var glow=OmniLight3D.new();node.add_child(glow);glow.position.y=.7;glow.light_color=Color("ffd56a");glow.light_energy=1.5 if elite else .3;glow.omni_range=2;glow.shadow_enabled=false;glow.light_volumetric_fog_energy=0;glow.add_to_group("pickup_lights")
	Visuals.label3d(node,"Сундук "+EncounterRules.STARS[2 if arena.room.boss_room else arena.room.difficulty]+" · E",Vector3(0,1.4,0),Color("fff0ac"),40)
	preload("res://scripts/interaction_prompt.gd").attach(node,arena,"Сундук",Vector3.ZERO,1.65)
	arena.room.pickups.append({"kind":"recipe_draft","elite":elite,"final":arena.room.boss_room,"offers":[],"node":node,"visual":visual})
	arena.toast("Трофей командира · подойди и нажми E")
func nearest_recipe() -> Dictionary:
	if not is_instance_valid(arena.room.player):return {}
	for pickup in arena.room.pickups:
		if pickup.kind=="recipe_draft" and arena.flat_distance(arena.room.player.position,pickup.node.position)<1.5:return pickup
	return {}
func open_recipe_draft(pickup: Dictionary):
	Game.sound("chest_open",arena)
	if pickup.offers.is_empty():pickup.offers=chest_offers(pickup.get("elite",true))
	arena.room.draft_pickup=pickup;arena.room.previous_phase=arena.phase;arena.phase="paused";Game.reset_input();arena.hud.show_recipe_draft()
func reroll_recipe_draft():
	if arena.phase!="paused" or arena.room.draft_pickup.is_empty() or arena.run.rerolls_left<=0:return
	Game.sound("reroll",arena);arena.run.rerolls_left-=1;arena.room.draft_pickup.offers=chest_offers(arena.room.draft_pickup.get("elite",true));arena.hud.show_recipe_draft()
func choose_recipe_card(index: int):
	if arena.phase!="paused" or arena.room.draft_pickup.is_empty() or index<0 or index>=3:return
	var offer=arena.room.draft_pickup.offers[index]
	if offer.category=="alloy":Game.earn(offer.amount);arena.run.earned+=offer.amount
	elif offer.category=="secret":apply_secret(offer)
	elif offer.category=="upgrade":apply_trophy_upgrade(offer.id,offer.tier)
	elif arena.run.pending_recipes.size()>=Game.backpack_slots:
		arena.room.recipe_offer=arena.room.draft_pickup;arena.room.recipe_offer.recipe=offer;arena.hud.show_pause();return
	else:arena.run.pending_recipes.append(offer)
	consume_chest(arena.room.draft_pickup);arena.room.draft_pickup={};arena.room.recipe_offer={};Game.sound("pickup",arena)
	if is_instance_valid(arena.replay):arena.replay.call_deferred("next")
	else:arena.pause_battle()
func apply_trophy_upgrade(id: String,tier: int):
	var n=[1.0,1.5,2.0][tier]
	match id:
		"health":
			arena.run.soldier_max_hp+=roundi(n);arena.run.soldier_hp=minf(arena.run.soldier_max_hp,arena.run.soldier_hp+roundi(n))
			if arena.room.player.kind=="soldier":arena.room.player.max_hp=arena.run.soldier_max_hp;arena.room.player.hp=arena.run.soldier_hp;arena.room.player.refresh_health()
		"damage":
			arena.run.damage_bonus+=.5*n
			if arena.room.player.kind=="soldier":arena.room.player.apply_weapon()
			else:arena.room.player.damage+=(.125 if arena.room.player.kind=="buggy" else .5)*n
		"speed":apply_speed_upgrade(n)
		"fire":arena.run.fire_multiplier*=1-.15*n;arena.room.player.fire_interval*=1-.15*n
		"intercept":arena.run.intercept_chance=minf(.95,arena.run.intercept_chance+.1*n)
	if arena.player.kind in GarageCatalog.VEHICLES:
		var stats=GarageCatalog.stats(arena.player.kind,arena,arena.player.vehicle_origin,arena.player.vehicle_zone)
		arena.player.damage=stats.damage;arena.player.fire_interval=stats.interval;arena.player.speed=stats.speed
	Game.sound("upgrade",arena)

func discard_recipe(index: int):
	if arena.phase!="paused" or index<0 or index>=arena.run.pending_recipes.size():return
	arena.run.pending_recipes.remove_at(index);arena.hud.show_pause()
func take_offered_recipe():
	if arena.phase!="paused" or arena.room.recipe_offer.is_empty() or arena.run.pending_recipes.size()>=Game.backpack_slots:return
	arena.run.pending_recipes.append(arena.room.recipe_offer.recipe);consume_chest(arena.room.recipe_offer);arena.room.recipe_offer={};arena.room.draft_pickup={}
	if is_instance_valid(arena.replay):arena.replay.call_deferred("next")
	else:arena.hud.show_pause()
func reroll_cards() -> bool:
	if arena.phase!="upgrade" or arena.room.reward_claimed or arena.run.rerolls_left<=0:return false
	Game.sound("reroll",arena);arena.run.rerolls_left-=1;arena.room.upgrade_offers.clear();arena.hud.show_upgrades();return true

func collect_nearby_pickups(delta):
	if not is_instance_valid(arena.room.player):return
	for pickup in arena.room.pickups.duplicate():
		if arena.flat_distance(arena.room.player.position,pickup.node.position)>1.35:pickup["blocked"]=false
		if pickup.kind!="recipe_draft" and arena.flat_distance(arena.room.player.position,pickup.node.position)<1.1 and arena.clear_shot(arena.room.player.position,pickup.node.position,.05) and not pickup.get("blocked",false):collect_pickup(pickup)
	for pickup in arena.room.pickups:
		pickup.visual.rotation.y+=delta;pickup.visual.position.y=.45+sin(arena.run.elapsed*3)*.07
func chest_offers(_elite:bool=true)->Array:
	var difficulty=2 if arena.room.boss_room else arena.room.difficulty
	var result=[{"category":"alloy","id":"alloy","amount":EncounterRules.chest_alloy(arena.room.room_index,difficulty),"tier":0},{"category":"upgrade","id":"health","tier":difficulty},{"category":"upgrade","id":["damage","speed","fire"][arena.run.combat_rng.randi_range(0,2)],"tier":difficulty}]
	var recipe=EncounterRules.recipe(difficulty,arena.run.combat_rng,arena.run.pending_recipes,Campaign.progress_index(arena.room_index))
	if not recipe.is_empty():result[0]=recipe
	return result

func apply_secret(offer):
	match offer.type:
		"weapon":
			arena.run.weapon_mods[offer.id].damage+=.75
			if arena.room.player.kind=="soldier":arena.room.player.apply_weapon()
		"ability":arena.abilities.select(offer.id);arena.abilities.level.power+=3
		"bonus":arena.run.run_bonus_levels[offer.id]=arena.run.run_bonus_levels.get(offer.id,0)+3
		"stat":
			if offer.id=="health":
				arena.run.soldier_max_hp+=5;arena.run.soldier_hp=arena.run.soldier_max_hp
				if arena.room.player.kind=="soldier":arena.room.player.max_hp=arena.run.soldier_max_hp;arena.room.player.hp=arena.run.soldier_hp;arena.room.player.refresh_health()
			else:arena.run.intercept_chance=minf(.95,arena.run.intercept_chance+.2)
func consume_chest(chest):
	if chest not in arena.room.pickups:return
	# Documents now drop from the final boss, independently of chest selection.
	arena.room.pickups.erase(chest);chest.node.queue_free()
func bonus_strength(id:String)->float:return Game.bonus_power(id)+arena.run.run_bonus_levels.get(id,0)*.1

func effective_bonus_level(id:String)->int:return Game.bonus_level(id)+int(arena.run.run_bonus_levels.get(id,0))


func prepare_upgrade_offers():
	if arena.room.upgrade_offers.is_empty():
		var ids=START_EFFECTS.duplicate()
		for id in BehaviorCards.DATA:
			if id not in arena.run.behavior_cards:ids.append(id)
		if arena.abilities.slots.is_empty():ids.erase("device_power");ids.erase("device_cooldown")
		if arena.speed_multiplier>=1.449 or arena.player.speed>=5.199:ids.erase("speed")
		if arena.run.intercept_chance>=.949:ids.erase("intercept")
		for i in range(ids.size()-1,0,-1):
			var j=arena.run.combat_rng.randi_range(0,i);var swap=ids[i];ids[i]=ids[j];ids[j]=swap
		ids=ids.slice(0,3)
		if arena.room.next_is_room:
			var alternatives=Game.weapon_unlocks.filter(func(id):return id!=arena.run.weapon)
			if not alternatives.is_empty():ids[0]=alternatives[arena.run.combat_rng.randi_range(0,alternatives.size()-1)]
		for id in ids:arena.room.upgrade_offers.append({"id":id,"tier":arena.room.difficulty})

func upgrade_card(offer:Dictionary)->Dictionary:
	if offer.id.begins_with("hq_"):return arena.headquarters.card(offer)
	var id=offer.id;var tier=offer.tier;var power=[1.0,1.5,2.0][tier]
	if id in BehaviorCards.DATA:
		return {"category":"Тактика","title":BehaviorCards.DATA[id].name,"detail":BehaviorCards.DATA[id].text,"icon":"damage" if id=="opening_shot" else "health" if id=="last_stand" else "speed","heading":arena.LOOT.RARITY_NAMES[tier],"color":Color(arena.LOOT.RARITY_COLORS[tier]),"disabled":false,"button":"Выбрать"}
	var names={"weapon_damage":"Урон оружия","weapon_fire":"Скорострельность","weapon_locked":"Нужен чертёж","health":"Здоровье","speed":"Передвижение","recovery":"Защитный щит","damage":"Сила атаки","intercept":"Напор"}
	var desc={"weapon_damage":"+%.0f%% базового урона ствола" % (18*power),"weapon_locked":"Найди и донеси чертёж оружия","weapon_fire":"+%.0f%% выстрелов в секунду" % (100/(1-.15*power)-100),"health":"+%d к максимуму HP и лечение" % roundi(power),"speed":"+%d%% к передвижению" % (4*power),"recovery":"Кулдаун щита −%.0f%%" % (100*(1-pow(.85,power))),"damage":"+%.0f%% базового урона стволов" % (15*power),"intercept":"+%d %% перехвата" % (10*power)}
	names.merge({"fire":"Темп огня","weapon_intercept":"Стабилизатор","range":"Дальность","healing":"Медицина","device_power":"Мощность устройств","device_cooldown":"Перезарядка устройств"})
	desc.merge({"fire":"Темп: +%s%%" % UiKit.number(100/(1-.15*power)-100),"weapon_intercept":"Напор оружия: +%s%%" % UiKit.number(5*power),"range":"Дальность: %s → %s%%" % [UiKit.number(arena.run.range_multiplier*100),UiKit.number((arena.run.range_multiplier+.12*power)*100)],"healing":"Лечение: %s → %s%%" % [UiKit.number(arena.run.healing_multiplier*100),UiKit.number((arena.run.healing_multiplier+.2*power)*100)],"device_power":"Мощность: %s → %s%%" % [UiKit.number(arena.run.ability_power_multiplier*100),UiKit.number((arena.run.ability_power_multiplier+.15*power)*100)],"device_cooldown":"Кулдаун: %s → %s%%" % [UiKit.number(arena.run.ability_cooldown_multiplier*100),UiKit.number(arena.run.ability_cooldown_multiplier*pow(.9,power)*100)]})
	var preview=upgrade_preview(id,power)
	if preview!="":desc[id]=preview
	if id in ["intercept","weapon_intercept"]:desc[id]+="\n{{pressure.description}}"
	if id in arena.LOOT.WEAPONS:
		var data=arena.LOOT.WEAPONS[id];tier=data.rarity;names[id]=data.name;desc[id]=data.role
	return {"category":"Способность" if id.begins_with("device_") else "Оружие" if id.begins_with("weapon_") or id in arena.LOOT.WEAPONS else "Герой","title":names[id],"detail":desc[id],"icon":id,"heading":arena.LOOT.RARITY_NAMES[tier],"color":Color(arena.LOOT.RARITY_COLORS[tier]),"disabled":id=="weapon_locked","button":"Нужен чертёж" if id=="weapon_locked" else "Выбрать"}

func service_offers(branch:String)->Array:
	if branch=="ability" and arena.abilities.slots.is_empty():return []
	if branch=="headquarters":
		var pool=arena.headquarters.offers(true);pool.shuffle();return pool.slice(0,3)
	var offers=[]
	for id in ["damage","hp","speed"] if branch=="vehicle" else ["power","cooldown","utility"]:
		offers.append({"id":id,"tier":Game.rarity_roll(arena.run.combat_rng.randf(),arena.room_index)})
	return offers

func apply_service_reward(branch:String,vehicle:String,index:int,offer:Dictionary):
	if branch=="headquarters":arena.headquarters.apply(offer.id,offer.tier)
	elif branch=="vehicle":arena.vehicle.upgrade_at_service(vehicle,index,offer)
	else:
		arena.abilities.upgrade(offer.id,offer.tier)
		Game.progression.event("upgrade_"+arena.abilities.selected);Game.save_progress()

func award_kill(actor):
	if actor.killed_by_vehicle in GarageCatalog.VEHICLES:Game.progression.event("kills_"+actor.killed_by_vehicle)
	var amount=EncounterRules.kill_alloy(actor.kind,actor.rank,arena.room.room_index,actor.elite,arena.room.difficulty)
	preload("res://scripts/resource_drop.gd").spawn(arena,actor.position,amount,"alloy",actor.resource_blast);arena.run.kills+=1
	Game.progression.event("drones" if actor.kind in ["drone","flyer"] else "armor" if actor.kind in ["tank","apc","buggy"] else "infantry")
	if actor.kind=="boss":
		if not arena.room.actors.any(func(a):return is_instance_valid(a) and not a.dead and a.kind=="boss") and arena.room.spawn_queue.is_empty():
			preload("res://scripts/resource_drop.gd").spawn(arena,actor.position,Campaign.world if not Campaign.endless else 1,"documents",actor.resource_blast)
		Game.progression.event("boss_"+str(Campaign.progress_index(arena.room_index)))
		if Campaign.is_final(arena.room_index) and Game.selected_class not in Game.progression.boss_classes:
			Game.progression.boss_classes.append(Game.selected_class);Game.progression.event("boss_classes",Game.progression.boss_classes.size(),true)
	Game.save_progress()
	if actor.elite:drop_recipe(actor.cell,{"elite":actor.commander_elite});Game.music_stinger("boss_victory");Game.music_context("battle")

func drop_enemy_loot(actor):
	if not arena.room.boss_room and arena.run.combat_rng.randf()<Game.bonus_chance():
		var pool=[]
		for id in Game.bonus_unlocks:
			if id in ["heart","star"]:continue
			for weight in range(Game.TIERS.weight(id,arena.room_index)):pool.append(id)
		if not pool.is_empty():drop_pickup(actor.cell,pool[arena.run.combat_rng.randi_range(0,pool.size()-1)])
	if not arena.room.boss_room and Game.TIERS.weight("star",arena.room_index)>0 and arena.run.combat_rng.randf()<Game.star_chance(arena.room.wave):drop_pickup(actor.cell,"star")
	if arena.run.combat_rng.randf()<Game.heart_chance():drop_pickup(actor.cell,"heart")

func skip_upgrade():
	if arena.phase!="upgrade":return
	arena.hud.close_modal()
	if is_instance_valid(arena.replay):arena.replay.call_deferred("next");return
	if arena.room.next_is_room:
		arena.room.reward_claimed=true;arena.hud.show_departure()
	else:arena.start_wave(arena.room.wave+1)
func skip_chest():
	if arena.room.draft_pickup.is_empty():return
	consume_chest(arena.room.draft_pickup);arena.room.draft_pickup={};arena.room.recipe_offer={}
	if is_instance_valid(arena.replay):arena.replay.call_deferred("next")
	else:arena.pause_battle()

func apply_speed_upgrade(power:float):
	var previous=arena.run.speed_multiplier
	arena.run.speed_multiplier=minf(1.45,previous+.04*power)
	arena.room.player.speed=minf(5.2,arena.room.player.speed*arena.run.speed_multiplier/previous)

func upgrade_preview(id:String,power:float)->String:
	var player=arena.room.player
	match id:
		"health":return UiKit.change_text("HP",arena.soldier_max_hp,arena.soldier_max_hp+roundi(power))
		"speed":
			var next=minf(5.2,player.speed*minf(1.45,arena.speed_multiplier+.04*power)/arena.speed_multiplier)
			if player.kind in GarageCatalog.VEHICLES and player.vehicle_origin=="captured":next=player.speed
			return UiKit.change_text("Скорость",player.speed,next)
		"fire","weapon_fire":
			var rate=preload("res://scripts/ui/weapon_benchmarks.gd").current_weapon(arena).rate if id=="weapon_fire" else 1/player.fire_interval
			var next=rate if id=="fire" and player.kind in GarageCatalog.VEHICLES and player.vehicle_origin=="captured" else rate/(1-.15*power)
			return UiKit.change_text("Темп",rate,next," /с")
		"damage","weapon_damage":
			var changes={"damage_bonus":.5*power} if id=="damage" else {"weapon_damage":.18*power}
			var current=CombatStats.weapon(arena).damage
			var next=CombatStats.weapon(arena,"",changes).damage
			if id=="damage" and player.kind in GarageCatalog.VEHICLES:
				current=GarageCatalog.stats(player.kind,arena,player.vehicle_origin,player.vehicle_zone).damage
				next=GarageCatalog.stats(player.kind,arena,player.vehicle_origin,player.vehicle_zone,changes).damage
			return UiKit.change_text("Урон",current,next)
		"intercept":return UiKit.change_text("Перехват",arena.run.intercept_chance*100,minf(.95,arena.run.intercept_chance+.1*power)*100,"%")
	return ""

func collect_resources():
	for token in arena.room.resource_drops.duplicate():
		if is_instance_valid(token):token.collect()

func drop_cell_open(cell:Vector2i)->bool:
	if not arena.inside(cell) or arena.walls.has(cell) or arena.trenches.has(cell) or arena.generators.has(cell) or (not arena.boss_room and cell==arena.base_cell):return false
	if arena.terrain.blocked(arena.world_pos(cell),.245):return false
	for wreck in arena.wrecks:
		if is_instance_valid(wreck) and not wreck.spent and wreck.cell==cell:return false
	return true

func reachable_drop_cells()->Array[Vector2i]:
	var result:Array[Vector2i]=[]
	if not is_instance_valid(arena.player):return result
	var start=arena.grid_pos(arena.player.position);var queue=[start];var seen={start:true};var head=0
	while head<queue.size():
		var cell=queue[head];head+=1
		if drop_cell_open(cell):result.append(cell)
		for dir in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var next=cell+dir
			if seen.has(next) or not drop_cell_open(next):continue
			seen[next]=true;queue.append(next)
	return result

func safe_drop_position(pos:Vector3)->Vector3:
	var cells=reachable_drop_cells()
	var best=Vector3(arena.player.position.x,0,arena.player.position.z) if is_instance_valid(arena.player) else pos
	var distance=INF
	for cell in cells:
		var candidate=arena.world_pos(cell);var d=arena.flat_distance(pos,candidate)
		if d<distance:best=candidate;distance=d
	return best
