extends RefCounted
## Tablet tab «Вылазка» (meta stage 2): a report of the current sortie, or of the last one outside a run.
## snapshot() turns a live arena into plain data (also saved as progression.last_run); build() draws it.
const ICON=preload("res://scripts/ui/enemy_type_icon.gd")
const CHIP=Vector2(166,64)
const DEFAULTS={"field":1,"fields":7,"elapsed":0.0,"earned":0,"tokens":0,"kills":0,"kills_by":{},"cards":[],"ammo":[],"abilities":[],"best_hit":0.0,"best_series":0,"captured":0,"damage_taken":0.0,"lost":false}

static func snapshot(arena)->Dictionary:
	var run=arena.run
	var cards=[]
	for choice in run.upgrade_history:
		var id=str(choice.id)
		if not UpgradeRegistry.has(id):continue
		var def=UpgradeRegistry.get_def(id)
		cards.append({"id":id,"title":def.title,"icon":def.icon,"family":def.family,"tier":int(choice.get("tier",0)),"detail":def.detail})
	var ammo=[]
	for slot in run.ammo_slots:
		if slot is Dictionary and str(slot.get("type",Ammo.STANDARD))!=Ammo.STANDARD:ammo.append({"type":slot.type,"rarity":int(slot.get("rarity",0)),"text":Ammo.describe(slot)})
	var abilities=[]
	if arena.abilities!=null:
		for id in arena.abilities.slots:
			var level=arena.abilities.level if id==arena.abilities.selected else arena.abilities.states.get(id,{}).get("level",{})
			var steps=0
			for key in level:steps+=roundi(float(level[key]))
			abilities.append({"id":id,"name":arena.abilities.NAMES.get(id,id),"level":steps})
	return {"class":Game.selected_class,"weapon":run.weapon,"field":mini(int(arena.room_index)+1,Campaign.SIZES.size()),"fields":Campaign.SIZES.size(),
		"elapsed":float(arena.elapsed),"earned":int(arena.earned),"tokens":int(run.tokens),"kills":int(arena.kills),"kills_by":run.kills_by.duplicate(),
		"cards":cards,"ammo":ammo,"abilities":abilities,"best_hit":float(run.best_hit),"best_series":int(run.best_series),
		"captured":int(run.captured),"damage_taken":float(run.damage_taken),"lost":bool(run.lost_run)}

static func build(body:Control,data:Dictionary,live:bool):
	var width=705.0;var y=0.0
	if data.is_empty():
		UiKit.label(body,"Отчёт появится после первой вылазки",Vector2(0,0),Vector2(width,32),18,UiKit.MUTED)
		body.custom_minimum_size.y=60;return
	# A saved report may come from an older build: missing or odd fields fall back to empty values.
	var full=DEFAULTS.duplicate(true)
	for key in DEFAULTS:
		if not data.has(key):continue
		var numbers=[TYPE_INT,TYPE_FLOAT]  # JSON brings every number back as float
		if typeof(data[key])==typeof(DEFAULTS[key]) or (typeof(data[key]) in numbers and typeof(DEFAULTS[key]) in numbers):full[key]=data[key]
	data=full
	UiKit.label(body,"Сейчас в поле" if live else ("Последняя вылазка · провал" if data.get("lost",false) else "Последняя вылазка"),Vector2(0,y),Vector2(width,24),UiKit.SECTION_SIZE,UiKit.MUTED);y+=30
	# Header tiles: field, time, alloy, tokens, kills.
	var elapsed=float(data.elapsed)
	var tiles=[["Поле","%d из %d" % [int(data.field),int(data.fields)],""],["Время","%d:%02d" % [int(elapsed/60.0),int(elapsed)%60],""],["Сплав",str(int(data.earned)),"alloy"],["Жетоны",str(int(data.tokens)),"token"],["Враги",str(int(data.kills)),""]]
	var tile_w=(width-4*8)/5.0
	for i in range(tiles.size()):
		var tile=UiKit.panel(body,Vector2(i*(tile_w+8),y),Vector2(tile_w,70),Color(1,1,1,.05));tile.name="Head_"+str(i)
		UiKit.label(tile,tiles[i][0],Vector2(10,6),Vector2(tile_w-20,20),13,UiKit.MUTED)
		var value=UiKit.label(tile,tiles[i][1],Vector2(10,28),Vector2(tile_w-20,34),24)
		if tiles[i][2]!="":UiKit.icon(tile,tiles[i][2],Vector2(tile_w-38,32),Vector2(28,28));value.size.x=tile_w-52
	y+=86
	# Kills by enemy type, most first.
	var kinds:Array=data.kills_by.keys()
	kinds.sort_custom(func(a,b):return int(data.kills_by[a])>int(data.kills_by[b]))
	if not kinds.is_empty():
		var per_row=10;var size=Vector2(62,74)
		for i in range(kinds.size()):
			var pos=Vector2((i%per_row)*(size.x+8.5),y+floori(i/float(per_row))*(size.y+8))
			var card=UiKit.panel(body,pos,size,Color(1,1,1,.05));card.name="Kill_"+str(kinds[i]);card.tooltip_text=ICON.title(str(kinds[i]))
			var icon=ICON.new();icon.kind=str(kinds[i]);card.add_child(icon);icon.position=Vector2(6,2);icon.size=Vector2(50,48);icon.mouse_filter=Control.MOUSE_FILTER_PASS
			var count=UiKit.label(card,"×%d" % int(data.kills_by[kinds[i]]),Vector2(0,50),Vector2(size.x,22),15,UiKit.ORANGE);count.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		y+=ceilf(kinds.size()/float(per_row))*(size.y+8)+10
	# Best moments.
	y=section(body,"Лучшие моменты",y)
	var moments=[["Сильнейший удар",UiKit.number(roundf(float(data.best_hit)))],["Лучшая серия",str(int(data.best_series))],["Угнано техники",str(int(data.captured))],["Получено урона",UiKit.number(roundf(float(data.damage_taken)))]]
	for i in range(moments.size()):
		var chip=UiKit.panel(body,Vector2(i*(CHIP.x+13),y),CHIP,Color(1,1,1,.05));chip.name="Moment_"+str(i)
		UiKit.label(chip,moments[i][0],Vector2(10,6),Vector2(CHIP.x-20,20),13,UiKit.MUTED)
		UiKit.label(chip,moments[i][1],Vector2(10,28),Vector2(CHIP.x-20,30),22)
	y+=CHIP.y+18
	# Build: abilities with run levels, loaded ammo, cards grouped by family.
	y=section(body,"Сборка",y)
	var x=0.0
	for ability in data.abilities:
		var chip=UiKit.panel(body,Vector2(x,y),Vector2(CHIP.x,48),Color(1,1,1,.05));chip.tooltip_text=Texts.render(str(ability.name))
		UiKit.icon(chip,str(ability.id),Vector2(8,8),Vector2(32,32))
		UiKit.label(chip,str(ability.name),Vector2(46,3),Vector2(CHIP.x-50,22),14).clip_text=true
		UiKit.label(chip,("Ур. +%d" % int(ability.level)) if int(ability.level)>0 else "Без усилений",Vector2(46,24),Vector2(CHIP.x-50,20),12,UiKit.MUTED)
		x+=CHIP.x+13
		if x>width-CHIP.x:x=0;y+=56
	for item in data.ammo:
		var chip=UiKit.panel(body,Vector2(x,y),Vector2(CHIP.x,48),Color(1,1,1,.05));chip.tooltip_text=Texts.render(str(item.text))
		UiKit.icon(chip,"ammo/"+str(item.type),Vector2(8,8),Vector2(32,32))
		UiKit.label(chip,Ammo.NAMES.get(item.type,item.type),Vector2(46,3),Vector2(CHIP.x-50,22),14).clip_text=true
		UiKit.label(chip,Ammo.RARITY_NAMES[clampi(int(item.rarity),0,3)],Vector2(46,24),Vector2(CHIP.x-50,20),12,UiKit.MUTED)
		x+=CHIP.x+13
		if x>width-CHIP.x:x=0;y+=56
	if x>0:y+=56
	if data.abilities.is_empty() and data.ammo.is_empty() and data.cards.is_empty():
		UiKit.label(body,"Карточки появятся после первого поля",Vector2(0,y),Vector2(width,28),16,UiKit.MUTED);y+=36
	var families={}
	for card in data.cards:
		if not families.has(card.family):families[card.family]=[]
		families[card.family].append(card)
	for family in RunUpgrades.FAMILIES:
		if not families.has(family):continue
		UiKit.label(body,"%s · %d" % [Texts.render(RunUpgrades.FAMILIES[family]),families[family].size()],Vector2(0,y),Vector2(width,22),14,UiKit.MUTED);y+=24
		var i=0
		for card in families[family]:
			var pos=Vector2((i%11)*64,y+floori(i/11.0)*64)
			var tile=UiKit.panel(body,pos,Vector2(56,56),Color(LootCatalog.RARITY_COLORS[clampi(int(card.tier),0,3)]).darkened(.55))
			tile.tooltip_text=Texts.render(str(card.title))+("\n"+Texts.render(str(card.detail)) if str(card.detail)!="" else "");tile.mouse_filter=Control.MOUSE_FILTER_PASS
			UiKit.icon(tile,str(card.icon) if str(card.icon)!="" else str(card.id),Vector2(6,6),Vector2(44,44))
			i+=1
		y+=ceilf(families[family].size()/11.0)*64+6
	# Profile records.
	y=section(body,"Рекорды",y+6)
	var c=Game.progression.counters
	var records=[["Глубже всего","поле %d" % int(c.get("depth",0))],["Больше всего врагов",str(int(c.get("best_kills",0)))],["Вылазок",str(int(c.get("runs",0)))]]
	for i in range(records.size()):
		var chip=UiKit.panel(body,Vector2(i*(225+15),y),Vector2(225,56),Color(1,1,1,.04))
		UiKit.label(chip,records[i][0],Vector2(10,4),Vector2(205,20),13,UiKit.MUTED)
		UiKit.label(chip,records[i][1],Vector2(10,24),Vector2(205,28),20)
	y+=70
	body.custom_minimum_size.y=y

static func section(body:Control,title:String,y:float)->float:
	UiKit.label(body,title,Vector2(0,y),Vector2(705,26),UiKit.SECTION_SIZE)
	return y+32
