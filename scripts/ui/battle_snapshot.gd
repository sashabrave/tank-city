extends RefCounted
## Plain values only: the HUD cannot mutate actors or run state through this snapshot.
static func capture(arena)->Dictionary:
	var run=arena.run;var room=arena.room;var ability=arena.abilities
	var data={"phase":arena.phase,"bosses":[],"skills":[],"hero_hp":run.soldier_hp,"hero_max":run.soldier_max_hp,"base_hp":room.base_hp,"base_max":room.base_max_hp,"boss_room":room.boss_room,"stage":room.room_index+1,"wave":room.wave+1,"twins":room.twin_boss,"tip":arena.toast_text if arena.toast_time>0 else "","star":room.star_time,"countdown":maxi(1,ceili(room.countdown)),"player":{},"interact_text":"Занять  [E]","interact_disabled":true}
	for actor in room.actors:
		if is_instance_valid(actor) and (actor.kind=="boss" or actor.elite) and not actor.dead:
			data.bosses.append({"hp":actor.hp,"max_hp":actor.max_hp,"title":(BossCatalog.encounter(arena.run_seed,room.room_index).name if actor.kind=="boss" else "★ Элитный командир" if actor.commander_elite else "☆ Командир")+" · %d / %d" % [actor.hp,actor.max_hp]})
	for i in range(3):
		var active=i<ability.slots.size()
		var id=ability.slots[i] if active else ""
		var remaining=(ability.cooldown if id==ability.selected else ability.states[id].cooldown) if active else 0.0
		var active_time=ability.active_seconds(id)
		var total=ability.cooldown_totals.get(id,AbilityCatalog.DATA.get(id,{"cooldown":1}).cooldown)
		data.skills.append({"disabled":not active or arena.phase not in ["combat","countdown"] or remaining>0,"text":"","hint":AbilityCatalog.DATA[id].name if active else "Открой слот в хабе","cooling":remaining>0,"progress":clampf(1.0-remaining/maxf(.01,total),0,1),"active":active_time})

	if is_instance_valid(room.player):
		var actor=room.player;var kind=actor.kind;var infantry=kind=="soldier"
		var weapon=arena.LOOT.WEAPONS[run.weapon]
		data.player={"name":weapon.name if infantry else {"apc":"Бтр","tank":"Танк","boss":"Танк","buggy":"Багги"}[kind],"infantry":infantry,"hp":actor.hp,"max_hp":actor.max_hp,"icon":"res://assets/icons/v1/"+(weapon.icon if infantry else "vehicle")+".png","stats":"Урон %.2f · %.1f выстр./с\nНапор %.2f" % [actor.damage,1.0/actor.fire_interval,arena.combat.player_pressure()]}
		data.interact_text="Занять  [E]" if infantry else "Выйти  [E]"
		data.interact_disabled=arena.phase!="combat" or (infantry and arena.vehicle.nearest_wreck()==null)
		if room.room_cleared and is_instance_valid(room.flag) and arena.flat_distance(actor.position,room.flag.position)<1.8:
			data.interact_text="Флаг [E]";data.interact_disabled=arena.phase!="combat"
	if not arena.reward.nearest_recipe().is_empty() and data.interact_text!="Флаг [E]":
		data.interact_text="Сундук [E]";data.interact_disabled=arena.phase!="combat"
	return data
