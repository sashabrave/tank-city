extends RefCounted
static func build(route,info:Dictionary)->Control:
	var modal=Control.new();modal.add_to_group("selection_scope");route.root.add_child(modal);modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim=ColorRect.new();modal.add_child(dim);dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);dim.color=Color(0,0,0,.48)
	var size=route.get_viewport().get_visible_rect().size
	var panel=UiKit.glass(modal,(size-Vector2(680,460))*.5,Vector2(680,460))
	UiKit.label(panel,"Этап %d · разведданные" % (info.stage+1),Vector2(28,20),Vector2(630,35),25)
	var banner=UiKit.panel(panel,Vector2(28,65),Vector2(624,58),Color("91a298"))
	UiKit.label(banner,"Поле боя / "+Campaign.title(info.stage),Vector2(16,12),Vector2(595,35),19,Color("eef0e2"))
	var rosters=route.node_rosters[info.id];var total=0;var income=0
	for wave in rosters:
		for enemy in wave:
			total+=1;income+=EncounterRules.kill_alloy(enemy.kind,enemy.get("rank",1),info.stage)
	var major=info.stage in Campaign.BOSSES
	var commander_entry=WaveDirector.commander_entry(route.wave_seed,info.stage,info.id)
	var commander=commander_entry.kind
	var commander_name={"sniper":"Снайпер","soldier":"Стрелок","shield":"Щитовой","grenadier":"Гранатомётчик","tank":"Танк","apc":"БТР","buggy":"Багги","boss":"Генерал"}[commander]
	if commander_entry.weapon=="rpg":commander_name="РПГшник"
	if major:commander_name=BossCatalog.encounter(route.wave_seed,info.stage).name
	if not major:
		total+=1
		income+=EncounterRules.kill_alloy(commander,WaveDirector.max_rank(info.stage),info.stage,true,info.difficulty)+4+info.stage*2
	var reward="≈ %d ◈ · %s" % [income,EncounterRules.reward_text(info.difficulty)]
	if major:reward+=" · документы"
	var rows=[["Бой", "%d врагов + помощь · %s" % [total,EncounterRules.NAMES[info.difficulty]]],["Босс",commander_name+" "+EncounterRules.STARS[info.difficulty]],["Награда",reward]]
	for i in range(rows.size()):
		var y=140+i*33
		UiKit.label(panel,rows[i][0],Vector2(28,y),Vector2(95,28),16,UiKit.MUTED)
		UiKit.label(panel,rows[i][1],Vector2(125,y),Vector2(530,28),15)
	var kinds={}
	for wave in rosters:
		for enemy in wave:
			var key=preload("res://scripts/ui/enemy_type_icon.gd").index_for(enemy.kind,enemy.get("weapon",""))
			kinds[key]=enemy
	var x=30
	for enemy in kinds.values():
		var icon=preload("res://scripts/ui/enemy_type_icon.gd").new();icon.kind=enemy.kind;icon.weapon=enemy.get("weapon","");panel.add_child(icon);icon.position=Vector2(x,242);icon.size=Vector2(44,43)
		x+=44
	UiKit.label(panel,"Оценка до боя. Сундук — одна награда на выбор.",Vector2(28,291),Vector2(624,24),14,UiKit.MUTED)
	var enter=UiKit.button(panel,"Войти [E]",Vector2(352,325),Vector2(300,48),route.confirm_entry,true)
	enter.disabled=info.id not in route.reachable or info.stage!=route.available or route.needs_service
	UiKit.button(panel,"Отказаться",Vector2(28,325),Vector2(308,48),route.cancel_entry)
	if Game.dev_map:
		# Test jump: straight into this room, optionally with every reward of the rooms before it.
		var jump=UiKit.button(panel,"Перейти",Vector2(28,398),Vector2(308,40),func():route.dev_entry(false));jump.name="DevJump";jump.add_theme_font_size_override("font_size",15)
		var full=UiKit.button(panel,"Перейти с прокачкой",Vector2(352,398),Vector2(300,40),func():route.dev_entry(true),true);full.name="DevJumpProgress";full.add_theme_font_size_override("font_size",15)
	else:UiKit.button(panel,"Рюкзак / статы",Vector2(352,398),Vector2(300,40),route.show_pause).add_theme_font_size_override("font_size",15)
	return modal
