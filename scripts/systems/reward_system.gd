extends RefCounted
## Seconds a landed field bonus stays before it disappears (T-046).
const BONUS_LIFETIME=25.0
## Reward system. Owns rules; Arena remains the scene coordinator.
var arena
var thieves

func _init(context):
	arena=context;thieves=preload("res://scripts/systems/bonus_thieves.gd").new(context)

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
	place_pickup(cell,kind)
## A field bonus on a given cell, parachuting down for `fall` seconds (also used when a thief drops one, T-072).
func place_pickup(cell:Vector2i,kind:String,fall:=1.1):
	var node=Node3D.new();arena.add_child(node);node.position=arena.world_pos(cell)
	var visual=arena.LOOT.visual(node,kind)
	var info=arena.LOOT.BONUSES[kind]
	# No labels: each bonus reads by its model and colour; the ring takes the bonus colour, rare ones pulse.
	var ring=Visuals.ring(node,Color(info.color),.42)
	if int(info.rarity)>=1:
		var pulse=node.create_tween().set_loops();pulse.tween_property(ring,"scale",Vector3.ONE*1.18,.6);pulse.tween_property(ring,"scale",Vector3.ONE,.6)
	# Arrival: it floats down under a small parachute, the canopy folds on landing with a puff of dust.
	var chute=parachute(visual,Color(info.color))
	arena.room.pickups.append({"node":node,"visual":visual,"kind":kind,"land_at":arena.run.elapsed+fall,"chute":chute})

## The one parachute of the game (Visuals.parachute) over a falling bonus.
func parachute(visual:Node3D,_tint:Color)->Node3D:return Visuals.parachute(visual)
## An army sack with dropped backpack items (T-113): it stays until the soldier walks over it with room to spare.
func place_sack(cell:Vector2i,content:Dictionary):
	var node=Node3D.new();arena.add_child(node);node.position=arena.world_pos(cell)+Vector3(randf_range(-.2,.2),0,randf_range(-.2,.2))
	var visual=Node3D.new();node.add_child(visual)
	# One item dropped: the item itself lies there with a glow in its rarity colour (author, 2026-10-03);
	# several at once still go into an army sack.
	var items=content.get("recipes",[]).size()+content.get("ammo",[]).size()+content.get("supplies",[]).size()+content.get("weapons",[]).size()
	if items==1:
		var tier=dropped_item(visual,content)
		# Not picked up by walking over: a small card offers E (use now) and C (into the backpack).
		var card=preload("res://scripts/ui/drop_prompt.gd").new();card.arena=arena;node.add_child(card)
		var glow=Color(LootCatalog.RARITY_COLORS[clampi(tier,0,3)])
		Visuals.ring(node,glow if tier>0 else Color("cfd3a0"),.38)
		var light=OmniLight3D.new();light.name="RarityGlow";visual.add_child(light);light.position.y=.25;light.omni_range=1.3;light.light_color=glow;light.light_energy=.9 if tier>0 else .35;light.shadow_enabled=false
		light.add_to_group("pickup_lights")
	else:
		var olive=Color("6b6a45")
		Visuals.box(visual,Vector3(0,.16,0),Vector3(.36,.32,.28),olive,"fabric")
		Visuals.box(visual,Vector3(0,.34,0),Vector3(.22,.06,.18),olive.darkened(.25),"fabric")
		Visuals.box(visual,Vector3(0,.2,.145),Vector3(.06,.3,.02),Color("3e3a2a"),"rubber")
		Visuals.ring(node,Color("cfd3a0"),.38)
	var entry={"node":node,"visual":visual,"kind":"item" if items==1 else "sack","content":content,"blocked":true}
	arena.room.pickups.append(entry)
	for child in node.get_children():
		if child.get_script()==preload("res://scripts/ui/drop_prompt.gd"):child.pickup=entry
	Game.sound("debris",arena)
## The model of a single dropped item; returns its rarity tier (0..3) for the glow.
func dropped_item(visual:Node3D,content:Dictionary)->int:
	if not content.get("weapons",[]).is_empty():
		var gun:Dictionary=content.weapons[0];var path="res://assets/models/infantry_v6/weapon_"+str(gun.get("id","pistol"))+".glb"
		if ResourceLoader.exists(path):
			var model=load(path).instantiate();visual.add_child(model);model.scale=Vector3.ONE*1.6;model.rotation=Vector3(0,randf()*TAU,PI*.5);model.position.y=.08
			Visuals.refresh_cozy_materials(model)
		return int(gun.get("rarity",0))
	if not content.get("ammo",[]).is_empty():
		# The simplest ammo can (author, 2026-10-03): an olive box, a band in the ammo effect's colour, a steel handle.
		var box:Dictionary=content.ammo[0];var color=Color(Ammo.COLORS.get(str(box.get("type","")),"cfd3c8"))
		var can=Node3D.new();visual.add_child(can);can.rotation.y=randf_range(-.6,.6)
		Visuals.box(can,Vector3(0,.12,0),Vector3(.36,.24,.2),Color("5d6147"),"paint")
		Visuals.box(can,Vector3(0,.12,0),Vector3(.372,.07,.212),color,"paint")
		Visuals.box(can,Vector3(0,.255,0),Vector3(.38,.03,.22),Color("4f5340"),"paint")
		Visuals.box(can,Vector3(0,.29,0),Vector3(.16,.025,.03),Color("9aa1a4"),"steel")
		return int(box.get("rarity",0))
	if not content.get("supplies",[]).is_empty():
		LootCatalog.visual(visual,"heart");return 0
	var recipe:Dictionary=content.get("recipes",[{}])[0]
	var board=Visuals.box(visual,Vector3(0,.04,0),Vector3(.3,.03,.4),Color("3f6fb0"),"paint");board.rotation.y=randf_range(-.4,.4)
	Visuals.box(board,Vector3(0,.025,.0),Vector3(.24,.01,.3),Color("e8ecf2"))
	return Game.TIERS.tier(str(recipe.get("id",""))) if recipe.has("id") else 0
func collect_pickup(pickup: Dictionary):
	if pickup.kind=="item":return  # a single dropped item answers its card (E / C), not walking over it
	if pickup.kind=="sack":
		if Backpack.pick_sack(arena,pickup.content):
			arena.room.pickups.erase(pickup);preload("res://scripts/battle_stage.gd").vanish(pickup.node);Game.sound("pickup",arena);arena.toast(Texts.render("Мешок подобран"))
		else:pickup["blocked"]=true
		return
	if pickup.kind=="recipe":
		if Backpack.full(arena.run):
			arena.room.recipe_offer=pickup;pickup["blocked"]=true;arena.pause_battle();return
		arena.run.pending_recipes.append(pickup.recipe);arena.toast("В рюкзаке: "+Game.recipe_name(pickup.recipe))
		arena.room.pickups.erase(pickup);preload("res://scripts/battle_stage.gd").vanish(pickup.node);Game.sound("pickup",arena);return
	var detail=""
	match pickup.kind:
		"star":
			arena.room.star_time=6+effective_bonus_level("star")*1.5;detail="Неуязвимость и мощный огонь · %d с" % int(arena.room.star_time)
		"heart":
			# Full health (T-115): the aid kit goes into the backpack for later, if there is a free cell.
			var amount=float(pickup.get("hq_heal",Game.heal_amount()*bonus_strength("heart")))
			if arena.run.soldier_hp>=arena.run.soldier_max_hp-.01 and is_instance_valid(arena.room.player) and arena.room.player.kind=="soldier" and not Backpack.full(arena.run):
				arena.run.supplies.append({"type":"medkit","heal":amount})
				arena.room.pickups.erase(pickup);preload("res://scripts/battle_stage.gd").vanish(pickup.node);Game.sound("pickup",arena)
				arena.toast(Texts.render("Аптечка в рюкзаке · H — использовать"));Backpack.refresh(arena);return
			var healed=minf(amount*arena.run.healing_multiplier,arena.run.soldier_max_hp-arena.run.soldier_hp)
			arena.run.soldier_hp+=healed;detail="+%s здоровья" % str(snappedf(healed,.1))
			if is_instance_valid(arena.room.player) and arena.room.player.kind=="soldier":arena.room.player.hp=arena.run.soldier_hp;arena.room.player.refresh_health()
		"pressure":arena.room.pressure_time=8+effective_bonus_level("pressure")*2;detail="Ярость · напор ×2 · %d с" % int(arena.room.pressure_time)
		"freeze":arena.room.freeze_time=3+effective_bonus_level("freeze");detail="Враги заморожены · %d с" % int(arena.room.freeze_time)
		"turret":
			arena.install_turret();detail="Турель у базы"
		"vehicle_repair":
			if arena.room.player.kind=="soldier":arena.toast("Для ремонта займи технику");return
			var healed=minf((3+Game.heal_level*.15)*bonus_strength("vehicle_repair"),arena.room.player.max_hp-arena.room.player.hp)
			arena.room.player.hp+=healed;arena.room.player.refresh_health();detail="+%s брони" % str(snappedf(healed,.1))
		"repair":
			var healed=minf((2+Game.heal_level*.15)*bonus_strength("repair"),arena.room.base_max_hp-arena.room.base_hp)
			arena.room.base_hp+=healed;detail="База +%s" % str(snappedf(healed,.1))
			if is_instance_valid(arena.room.base_bar):arena.room.base_bar.set_health(arena.room.base_hp,arena.room.base_max_hp)
		"wall":
			# Level 0-1: brick; 2: reinforced brick; 3+: indestructible PO-2 fence halves.
			var level=effective_bonus_level("wall")
			for cell in [Vector2i(arena.room.base_cell.x-1,arena.room.grid_size-2),Vector2i(arena.room.base_cell.x,arena.room.grid_size-2),Vector2i(arena.room.base_cell.x+1,arena.room.grid_size-2),Vector2i(arena.room.base_cell.x-1,arena.room.grid_size-1),Vector2i(arena.room.base_cell.x+1,arena.room.grid_size-1)]:
				var existing=arena.room.walls.get(cell)
				if existing!=null and existing.hp<0:continue
				var upgrade=level>=3 or (level==2 and existing!=null and not existing.get("reinforced",false))
				if upgrade or (existing==null and level>=2):
					if existing==null and not arena.can_enter(cell):continue
					if existing!=null:existing.node.queue_free();arena.room.walls.erase(cell)
					if level>=3:arena.board.add_wall(cell,-1,"concrete_0")
					else:arena.board.add_reinforced_wall(cell,(4+level)*4.0)
					arena.board.shape_base_wall(cell)
				elif arena.room.walls.has(cell) and arena.room.walls[cell].hp>0 and arena.room.base_hp>=arena.room.base_max_hp:
					arena.room.walls[cell].hp*=1.5;arena.room.walls[cell].max_hp*=1.5
					arena.room.walls[cell]["armor_level"]=arena.room.walls[cell].get("armor_level",0)+1
					if arena.room.walls[cell].has("sections"):
						for i in range(16):arena.room.walls[cell].sections[i]*=1.5
				elif arena.room.walls.has(cell) or arena.can_enter(cell):
					arena.add_wall(cell,4+effective_bonus_level("wall"));arena.board.shape_base_wall(cell)
			detail="Стены у базы укреплены"
		"vehicle":
			var kind=arena.unlocked_vehicle()
			if kind!="":
				var cell=arena.find_free_near(Vector2i(arena.room.base_cell.x-2,arena.room.grid_size-3))
				var delivery=arena.make_wreck(kind,cell,Vector2i.UP,false,arena.vehicle.player_armor(kind))
				delivery.start_delivery((arena.room.grid_size-1)/3.8*.85*pow(.92,effective_bonus_level("vehicle")))
				arena.toast({"buggy":"Багги","apc":"БТР","tank":"Танк"}[kind]+" доставлен к базе. Садись в любое время.");detail="Техника едет к базе"
	if is_instance_valid(pickup.get("node")):bonus_popup(pickup.node.global_position,pickup.kind,detail)
	Game.sound({"heart":"heal","repair":"repair","vehicle_repair":"armor_recover","star":"rare_reveal","wall":"barrier_deploy","freeze":"shield_restore","pressure":"pressure"}.get(pickup.kind,"pickup"),arena)
	arena.room.pickups.erase(pickup)
	preload("res://scripts/battle_stage.gd").vanish(pickup.node)

## Pickup popup: bonus name in its colour, the effect in plain words under it; rises and fades.
func bonus_popup(pos:Vector3,kind:String,detail:String):
	var info=arena.LOOT.BONUSES.get(kind,{})
	if info.is_empty():return
	var holder=Node3D.new();arena.add_child(holder);holder.global_position=pos+Vector3.UP*.9
	var title=Visuals.label3d(holder,str(info.name),Vector3(0,.2,0),Color(info.color).lightened(.2),36);title.no_depth_test=true;title.render_priority=10
	if detail!="":
		var line=Visuals.label3d(holder,detail,Vector3(0,-.05,0),Color("f4f0e2"),26);line.no_depth_test=true;line.render_priority=10
	holder.scale=Vector3.ONE*.6
	var tween=holder.create_tween()
	tween.tween_property(holder,"scale",Vector3.ONE,.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(holder,"position:y",holder.position.y+.75,1.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_method(func(a:float):
		for label in holder.get_children():label.modulate.a=a;label.outline_modulate.a=a,1.0,0.0,.45).set_delay(1.05)
	tween.tween_callback(holder.queue_free)

# Stat and behaviour cards come from UpgradeRegistry; weapons and headquarters offers keep their own catalogs.
func apply_upgrade(id: String,tier: int=0):
	if arena.phase!="upgrade": return
	if id.begins_with("hq_"):arena.headquarters.apply(id,tier)
	elif id in arena.LOOT.WEAPONS:
		arena.run.upgrade_history.append({"id":id,"tier":tier})
		arena.run.weapon=id;RunUpgrades.refresh_player(arena)
	else:RunUpgrades.apply(arena,id,tier)
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
	# Chest by rank (tools/build_props_v6.py): still, unlit; a soft light pillar marks it instead.
	var tier=3 if arena.room.boss_room else EncounterRules.difficulty(arena.room.difficulty)
	var visual=load("res://assets/models/chests_v6/chest_%d.glb" % tier).instantiate();node.add_child(visual)
	visual.rotation.y=PI;visual.scale=Vector3.ONE*.95
	var tint=[Color("c9d3bd"),Color("9fd4ff"),Color("ffd56a"),Color("ffb347")][tier]
	Visuals.ring(node,tint,.55)
	var beam=MeshInstance3D.new();beam.name="LootBeam";var column=CylinderMesh.new()
	column.top_radius=.26;column.bottom_radius=.3;column.height=2.6;column.radial_segments=12;column.rings=1;column.cap_top=false;column.cap_bottom=false
	beam.mesh=column;beam.position.y=1.3;beam.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.add_child(beam)
	var beam_mat=ShaderMaterial.new();beam_mat.shader=preload("res://shaders/fx/loot_beam.gdshader");beam_mat.set_shader_parameter("tint",tint)
	beam_mat.set_shader_parameter("strength",[.6,.75,.9,1.0][tier]);beam.material_override=beam_mat
	Visuals.label3d(node,"Сундук "+EncounterRules.STARS[2 if arena.room.boss_room else arena.room.difficulty]+" · E",Vector3(0,1.4,0),Color("fff0ac"),40)
	preload("res://scripts/interaction_prompt.gd").attach(node,arena,"Сундук",Vector3.ZERO,1.65)
	arena.room.pickups.append({"kind":"recipe_draft","elite":elite,"final":arena.room.boss_room,"offers":[],"node":node,"visual":visual})
	# Arrival: the chest drops in with a bounce and the camera leans in a little (T-022).
	visual.scale=Vector3.ONE*.2;var arrive=node.create_tween();arrive.tween_property(visual,"scale",Vector3.ONE*1.08,.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT);arrive.tween_property(visual,"scale",Vector3.ONE*.95,.12)
	var feel=arena.get_node_or_null("CombatFeel");if feel:feel.punch_in()
	arena.toast("Трофей командира · подойди и нажми E")
func nearest_recipe() -> Dictionary:
	if not is_instance_valid(arena.room.player):return {}
	for pickup in arena.room.pickups:
		if pickup.kind=="recipe_draft" and arena.flat_distance(arena.room.player.position,pickup.node.position)<1.5:return pickup
	return {}
func open_recipe_draft(pickup: Dictionary):
	Game.sound("chest_open",arena)
	# Opening: the chest jumps, the lid side flashes and a burst of light rises (T-022); runs under the pause.
	if is_instance_valid(pickup.get("visual")):
		var v:Node3D=pickup.visual;var pop=v.create_tween();pop.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		pop.tween_property(v,"scale",Vector3(1.15,.8,1.15),.08);pop.tween_property(v,"scale",Vector3(.9,1.25,.9),.12);pop.tween_property(v,"scale",Vector3.ONE*.95,.18)
		arena.burst(pickup.node.position+Vector3.UP*.6,Color("ffd56a"),.6)
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
	elif offer.category=="documents":Game.earn(int(offer.amount)*Game.DOC_ALLOY);arena.run.earned+=int(offer.amount)*Game.DOC_ALLOY
	elif offer.category=="upgrade":apply_trophy_upgrade(offer.id,offer.tier)
	elif Backpack.full(arena.run):
		arena.room.recipe_offer=arena.room.draft_pickup;arena.room.recipe_offer.recipe=offer;arena.hud.show_pause();return
	else:arena.run.pending_recipes.append(offer)
	consume_chest(arena.room.draft_pickup);arena.room.draft_pickup={};arena.room.recipe_offer={};Game.sound("pickup",arena)
	if is_instance_valid(arena.replay):arena.replay.call_deferred("next")
	else:arena.pause_battle()
func apply_trophy_upgrade(id: String,tier: int):
	RunUpgrades.apply(arena,id,tier)
	Game.sound("upgrade",arena)

func discard_recipe(index: int):
	if arena.phase!="paused" or index<0 or index>=arena.run.pending_recipes.size():return
	arena.run.pending_recipes.remove_at(index);arena.hud.show_pause()
func take_offered_recipe():
	if arena.phase!="paused" or arena.room.recipe_offer.is_empty() or Backpack.full(arena.run):return
	arena.run.pending_recipes.append(arena.room.recipe_offer.recipe);consume_chest(arena.room.recipe_offer);arena.room.recipe_offer={};arena.room.draft_pickup={}
	if is_instance_valid(arena.replay):arena.replay.call_deferred("next")
	else:arena.hud.show_pause()
func reroll_cards() -> bool:
	if arena.phase!="upgrade" or arena.room.reward_claimed or arena.run.rerolls_left<=0:return false
	Game.sound("reroll",arena);arena.run.rerolls_left-=1;arena.room.upgrade_offers.clear();arena.hud.show_upgrades();return true

func collect_nearby_pickups(delta):
	if not is_instance_valid(arena.room.player):return
	thieves.tick(delta)
	for pickup in arena.room.pickups.duplicate():
		if arena.flat_distance(arena.room.player.position,pickup.node.position)>1.35:pickup["blocked"]=false
		if arena.run.elapsed<float(pickup.get("land_at",0.0)):continue
		if pickup.kind not in ["recipe_draft","cache","item"] and arena.flat_distance(arena.room.player.position,pickup.node.position)<1.1 and arena.clear_shot(arena.room.player.position,pickup.node.position,.05) and not pickup.get("blocked",false):collect_pickup(pickup)
	for pickup in arena.room.pickups.duplicate():
		if pickup.kind=="recipe_draft":continue  # chests stand still on the ground
		var falling=float(pickup.get("land_at",0.0))-arena.run.elapsed
		if falling>0:
			pickup.visual.position.y=.45+falling/1.1*4.2;pickup.visual.rotation.y+=delta*.6;continue
		if is_instance_valid(pickup.get("chute")):
			pickup.chute.queue_free();pickup.erase("chute");arena.burst(pickup.node.position+Vector3.UP*.2,Color("d8cfb4"),.45);Game.sound("delivery_land",arena)
		pickup.visual.rotation.y+=delta;pickup.visual.position.y=.45+sin(arena.run.elapsed*3)*.07
		# T-046: a field bonus does not lie forever — it blinks for its last 5 seconds and is gone after 25.
		if pickup.kind!="cache" and pickup.has("land_at"):
			var left=float(pickup.land_at)+BONUS_LIFETIME-arena.run.elapsed
			if left<5.0:pickup.node.visible=fposmod(arena.run.elapsed*(3.0 if left>2.0 else 7.0),1.0)<.6
			if left<=0:
				arena.room.pickups.erase(pickup);arena.burst(pickup.node.position+Vector3.UP*.3,Color("d8cfb4"),.35);pickup.node.queue_free()
func chest_offers(_elite:bool=true)->Array:
	var difficulty=2 if arena.room.boss_room else arena.room.difficulty
	# Chest cards come from the same registry and rarity roll as wave offers, never below the room difficulty.
	var result=[{"category":"alloy","id":"alloy","amount":EncounterRules.chest_alloy(arena.room.room_index,difficulty),"tier":0}]
	for offer in RunUpgrades.roll_offers(arena,2):result.append({"category":"upgrade","id":offer.id,"tier":maxi(int(offer.tier),difficulty)})
	var recipe=EncounterRules.guaranteed(Campaign.progress_index(arena.room_index),arena.run.pending_recipes)
	if recipe.is_empty():recipe=EncounterRules.recipe(difficulty,arena.run.combat_rng,arena.run.pending_recipes,Campaign.progress_index(arena.room_index))
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
	arena.room.pickups.erase(chest);preload("res://scripts/battle_stage.gd").vanish(chest.node,.2,.2)
	arena.flow.release_flag()
func bonus_strength(id:String)->float:return Game.bonus_power(id)+arena.run.run_bonus_levels.get(id,0)*.1

func effective_bonus_level(id:String)->int:return Game.bonus_level(id)+int(arena.run.run_bonus_levels.get(id,0))


func prepare_upgrade_offers():
	if arena.room.upgrade_offers.is_empty():
		var offers=RunUpgrades.roll_offers(arena,3)
		# At the flag the first card offers switching to another unlocked weapon.
		if arena.room.next_is_room and not offers.is_empty():
			var alternatives=Game.weapon_unlocks.filter(func(id):return id!=arena.run.weapon)
			if not alternatives.is_empty():offers[0]={"id":alternatives[arena.run.combat_rng.randi_range(0,alternatives.size()-1)],"tier":arena.room.difficulty}
		for offer in offers:arena.room.upgrade_offers.append(offer)

func upgrade_card(offer:Dictionary)->Dictionary:
	if offer.id.begins_with("hq_"):return arena.headquarters.card(offer)
	if offer.id in arena.LOOT.WEAPONS:
		var data=arena.LOOT.WEAPONS[offer.id];var tier=data.rarity
		return {"category":"Оружие","title":data.name,"detail":data.role,"icon":offer.id,"heading":arena.LOOT.RARITY_NAMES[tier],"color":Color(arena.LOOT.RARITY_COLORS[tier]),"disabled":false,"button":"Выбрать"}
	return RunUpgrades.card(arena,offer)

func service_offers(branch:String)->Array:
	if branch=="ability" and arena.abilities.slots.is_empty():return []
	if branch=="headquarters":
		var pool=arena.headquarters.offers(true)
		# Seeded shuffle: the same run seed (daily runs) gives the same workshop stops.
		for i in range(pool.size()-1,0,-1):
			var j=arena.run.combat_rng.randi_range(0,i);var swap=pool[i];pool[i]=pool[j];pool[j]=swap
		return pool.slice(0,3)
	var offers=[]
	var ids=["power","cooldown","utility"]
	if branch=="vehicle":
		# Five vehicle cards, three of them per visit (T-184): the stop does not repeat the same trio.
		ids=["damage","hp","speed","rate","overhaul"]
		for i in range(ids.size()-1,0,-1):
			var j=arena.run.combat_rng.randi_range(0,i);var keep=ids[i];ids[i]=ids[j];ids[j]=keep
		ids=ids.slice(0,3)
	for id in ids:
		offers.append({"id":id,"tier":Game.rarity_roll(arena.run.combat_rng.randf(),arena.room_index)})
	return offers

func apply_service_reward(branch:String,vehicle:String,index:int,offer:Dictionary):
	if branch=="headquarters":arena.headquarters.apply(offer.id,offer.tier)
	elif branch=="vehicle":arena.vehicle.upgrade_at_service(vehicle,index,offer)
	else:
		arena.abilities.upgrade(offer.id,offer.tier)
		Game.progression.event("upgrade_"+arena.abilities.selected);Game.save_progress()

const KILL_SERIES_WINDOW=1.6
func award_kill(actor):
	arena.effects.emit("kill",{"actor":actor})
	kill_series(actor)
	if actor.killed_by_vehicle in GarageCatalog.VEHICLES:Game.progression.event("kills_"+actor.killed_by_vehicle)
	var amount=roundi(EncounterRules.kill_alloy(actor.kind,actor.rank,arena.room.room_index,actor.elite,arena.room.difficulty)*CombatMods.loot_multiplier(arena))
	CombatMods.on_kill(arena,actor)
	preload("res://scripts/resource_drop.gd").spawn(arena,actor.position,amount,"alloy",actor.resource_blast);arena.run.kills+=1
	var icon_id="commander" if actor.elite else preload("res://scripts/ui/enemy_type_icon.gd").IDS[preload("res://scripts/ui/enemy_type_icon.gd").index_for(actor.kind,actor.enemy_weapon)]
	arena.run.kills_by[icon_id]=int(arena.run.kills_by.get(icon_id,0))+1
	var tokens=token_drop(actor)
	if tokens>0:preload("res://scripts/resource_drop.gd").spawn(arena,actor.position,tokens,"tokens",actor.resource_blast)
	Game.progression.event("drones" if UnitKinds.is_flying(actor.kind) else "armor" if UnitKinds.is_vehicle(actor.kind) else "infantry")
	if actor.kind=="boss":
		if not arena.room.actors.any(func(a):return is_instance_valid(a) and not a.dead and a.kind=="boss") and arena.room.spawn_queue.is_empty():
			preload("res://scripts/resource_drop.gd").spawn(arena,actor.position,(Campaign.world if not Campaign.endless else 1)*Game.DOC_ALLOY,"alloy",actor.resource_blast)
		Game.progression.event("boss_"+str(Campaign.progress_index(arena.room_index)))
		Game.progression.event("boss_wins")  # the HQ wall number (T-174)
		if (Campaign.is_final(arena.room_index) or (Campaign.unified_content() and arena.room_index in Campaign.BOSSES)) and Game.selected_class not in Game.progression.boss_classes:
			Game.progression.boss_classes.append(Game.selected_class);Game.progression.event("boss_classes",Game.progression.boss_classes.size(),true)
	Game.save_progress()
	if actor.elite:
		drop_recipe(actor.cell,{"elite":actor.commander_elite});Game.music_stinger("boss_victory");Game.music_context("battle")
		# Rare uniform from a commander, visual only; uses a visual RNG so combat rolls stay untouched.
		if randf()<.12:
			var skin=Skins.grant("chest",RandomNumberGenerator.new())
			if skin!="":arena.toast("Новая форма: "+Skins.UNIFORMS[skin].name)
	if actor.kind=="boss" and not arena.room.actors.any(func(a):return is_instance_valid(a) and not a.dead and a.kind=="boss"):
		var parade=Skins.grant("boss",RandomNumberGenerator.new())
		if parade!="":arena.toast("Новая форма: "+Skins.UNIFORMS[parade].name)

## Merchant tokens: rare from any enemy, more often from vehicles and veterans, guaranteed from commanders.
func token_drop(actor)->int:
	var economy=Balance.CONFIG.economy
	if actor.elite:return economy.token_commander
	var chance=economy.token_vehicle_chance if actor.kind in ["buggy","apc","tank","mortar"] else economy.token_chance
	if actor.rank>=2:chance+=economy.token_rank_bonus
	return 1 if arena.run.combat_rng.randf()<chance*CombatMods.loot_multiplier(arena) else 0

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
	RunUpgrades.apply_power(arena,UpgradeRegistry.get_def("speed"),power)

func upgrade_preview(id:String,tier:int)->String:
	return RunUpgrades.preview_text(arena,id,tier)

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

## Kills close together build a series: a gold ×N over the target and a small alloy bonus from ×3.
func kill_series(actor):
	var run=arena.run
	run.series=run.series+1 if arena.elapsed-run.series_at<=KILL_SERIES_WINDOW else 1
	run.best_series=maxi(run.best_series,run.series)
	run.series_at=arena.elapsed
	if run.series<2:return
	var label=Visuals.label3d(arena,"×%d" % run.series,actor.position+Vector3(0,2.2,0),Color("ffd26b"),44+mini(run.series,6)*4)
	label.scale=Vector3.ONE*.6
	var tween=arena.create_tween()
	tween.tween_property(label,"scale",Vector3.ONE*1.15,.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label,"scale",Vector3.ONE,.1)
	tween.parallel().tween_property(label,"position:y",label.position.y+.6,.8)
	tween.tween_property(label,"modulate:a",0.0,.35)
	tween.tween_callback(label.queue_free)
	if run.series>=3:
		preload("res://scripts/resource_drop.gd").spawn(arena,actor.position,run.series-1,"alloy",actor.resource_blast)
		Game.sound("reward_reveal_%d" % clampi(run.series-2,1,3) if run.series<=5 else "rare_reveal",arena)

