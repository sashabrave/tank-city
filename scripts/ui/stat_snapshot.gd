extends RefCounted
## One presentation catalog; values always come from combat calculations, not UI copies.
static func row(title:String,base:float,current:float,unit:String="")->Dictionary:
	return {"title":title,"base":base,"current":current,"unit":unit}
static func weapon(arena=null,id:String="")->Array:
	var base=CombatStats.weapon(null,id);var current=CombatStats.weapon(arena,id)
	var result=[]
	for spec in [["damage","Урон",""],["rate","Темп"," /с"],["range","Дальность"," м"],["intercept","Напор","%"]]:
		result.append(row(spec[1],base[spec[0]],current[spec[0]],spec[2]))
	return result
static func fighter(arena=null)->Array:
	var run=arena.run if is_instance_valid(arena) else null
	var rows=[row("Максимум здоровья",CombatStats.initial_health(),run.soldier_max_hp if run!=null else CombatStats.initial_health()),row("Скорость пешком",CombatStats.soldier_speed(),CombatStats.soldier_speed(run)," м/с")]
	rows.append_array(weapon(arena,run.weapon if run!=null else Game.selected_weapon))
	for spec in [["healing_multiplier","Эффективность лечения"],["ability_power_multiplier","Сила способностей"],["ability_cooldown_multiplier","Время перезарядки способностей"]]:
		rows.append(row(spec[1],100,100*float(run.get(spec[0])) if run!=null else 100,"%"))
	if is_instance_valid(arena) and is_instance_valid(arena.player):
		var actor=arena.player
		if actor.kind=="soldier":
			rows[1].current=actor.speed
			rows[2].current=actor.damage
			rows[3].current=1.0/actor.fire_interval*BehaviorCards.rate_multiplier(arena)
	return rows
static func add_bars(parent:Control,pos:Vector2,width:float,rows:Array,row_height:float=48,adaptive:bool=false):
	var bars=preload("res://scripts/ui/comparison_bars.gd").new();bars.rows=rows;bars.row_height=row_height;bars.adaptive_columns=adaptive;parent.add_child(bars);bars.position=pos;bars.size=Vector2(width,0);bars.reflow();return bars
static func status(arena=null)->Array:
	var result=["Уровень персонажа: %d · Уровень класса: %d" % [Game.character_level(),Game.class_level()],"Постоянный бонус урона: %s%% · Ячеек рюкзака: %d" % [UiKit.number(Game.damage_level*5),Game.backpack_slots],"Потеря сплава при гибели: %s%%" % UiKit.number(Game.death_loss_fraction()*100)]
	if not is_instance_valid(arena):return result
	result.append("Здоровье: %s / %s · Прочность штаба: %s" % [UiKit.number(arena.soldier_hp),UiKit.number(arena.soldier_max_hp),UiKit.number(arena.base_hp)])
	result.append("Перебросов: %d · Уничтожено врагов: %d · Сплава за вылазку: %d" % [arena.run.rerolls_left,arena.run.kills,arena.run.earned])
	if is_instance_valid(arena.player) and arena.player.kind!="soldier":
		var actor=arena.player
		result.append("Техника · Броня: %s · Урон: %s · Темп: %s /с · Скорость: %s" % [UiKit.number(actor.hp),UiKit.number(actor.damage),UiKit.number(1.0/actor.fire_interval),UiKit.number(actor.speed)])
	# A separate read-only ability instance uses the same formulas without selecting a live slot.
	for id in arena.abilities.slots:
		var ability=preload("res://scripts/run_ability.gd").new();ability.arena=arena;ability.selected=id
		ability.level=(arena.abilities.level if id==arena.abilities.selected else arena.abilities.states[id].level).duplicate()
		result.append("%s · Сила: %s · Перезарядка: %s с" % [AbilityCatalog.DATA[id].name,UiKit.number(ability.power()),UiKit.number(ability.interval())])
	return result

static func follow_grid(parent:Control,bars:Control):
	var base_height=bars.content_height();var minimum=parent.custom_minimum_size.y;var following=[]
	for child in parent.get_children():
		if child is Control and child!=bars and child.position.y>=bars.position.y+base_height:following.append([child,child.position.y])
	bars.resized.connect(func():
		var shift=bars.content_height()-base_height
		for item in following:
			if is_instance_valid(item[0]):item[0].position.y=item[1]+shift
		parent.custom_minimum_size.y=minimum+shift)
