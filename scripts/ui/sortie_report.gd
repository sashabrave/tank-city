extends RefCounted
## Tablet tab «Вылазка» (meta stage 2): a report of the current sortie, or of the last one outside a run.
## snapshot() turns a live arena into plain data (also saved as progression.last_run); build() draws it.
## Order (T-245): the build first — everything that acts now — then the field, best moments and records.
const ICON=preload("res://scripts/ui/enemy_type_icon.gd")
const STATS=preload("res://scripts/ui/stat_snapshot.gd")
const CHIP=Vector2(166,64)
## Build chips: three in a row across the page, wide enough for «+75% базового урона: …».
const PIECE=Vector2(226,50)
const GAP=13.5
const PER_ROW=3
const WIDTH=705.0
const DEFAULTS={"field":1,"fields":7,"elapsed":0.0,"earned":0,"tokens":0,"kills":0,"kills_by":{},"cards":[],"ammo":[],"abilities":[],"best_hit":0.0,"best_series":0,"captured":0,"damage_taken":0.0,"lost":false,
	"weapon":"","values":{},"hq":[],"vehicles":[],"trophies":[],"states":[]}
const VEHICLE_NAMES={"buggy":"Багги","apc":"БТР","tank":"Танк"}

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
		if slot is Dictionary and str(slot.get("type",Ammo.STANDARD)) not in [Ammo.STANDARD,Ammo.EMPTY]:ammo.append({"type":slot.type,"rarity":int(slot.get("rarity",0)),"text":Ammo.describe(slot),"first":first_value(slot)})
	var abilities=[]
	if arena.abilities!=null:
		for id in arena.abilities.slots:
			var level=arena.abilities.level if id==arena.abilities.selected else arena.abilities.states.get(id,{}).get("level",{})
			var steps=0
			for key in level:steps+=roundi(float(level[key]))
			abilities.append({"id":id,"name":arena.abilities.NAMES.get(id,id),"level":steps})
	var hq=[]
	if arena.headquarters!=null:
		for id in arena.headquarters.loadout():
			if HQCatalog.DATA.has(id):hq.append({"id":id,"name":HQCatalog.DATA[id].name,"icon":HQCatalog.DATA[id].icon,"text":HQCatalog.stat(id,arena.headquarters.level(id)),"level":roundi(arena.headquarters.level(id))})
	var vehicles=[]
	for kind in VEHICLE_NAMES:
		var mods:Dictionary=run.vehicle_mods.get(kind,{})
		var parts=[]
		if float(mods.get("damage",0.0))>0.001:parts.append(Texts.render("урон")+" +"+UiKit.number(snappedf(float(mods.damage),.01)))
		if float(mods.get("hp",0.0))>0.001:parts.append(Texts.render("броня")+" +"+UiKit.number(snappedf(float(mods.hp),.1)))
		if float(mods.get("speed",1.0))>1.001:parts.append(Texts.render("скорость")+" ×"+UiKit.number(snappedf(float(mods.speed),.01)))
		if float(mods.get("rate",1.0))<.999:parts.append(Texts.render("перезарядка")+" ×"+UiKit.number(snappedf(float(mods.rate),.01)))
		if not parts.is_empty():vehicles.append({"kind":kind,"name":VEHICLE_NAMES[kind],"text":" · ".join(parts)})
	var trophies=[]
	for trophy in run.trophies:
		if trophy is Dictionary:trophies.append({"text":trophy_text(trophy),"name":trophy_name(trophy),"icon":trophy_icon(trophy)})
	var states=[]
	for entry in STATS.state(arena):
		if entry.get("remaining")!=null:states.append({"icon":str(entry.icon),"title":str(entry.title),"value":str(entry.value)})
	return {"class":Game.selected_class,"weapon":run.weapon,"field":mini(int(arena.room_index)+1,Campaign.SIZES.size()),"fields":Campaign.SIZES.size(),
		"elapsed":float(arena.elapsed),"earned":int(arena.earned),"tokens":int(run.tokens),"kills":int(arena.kills),"kills_by":run.kills_by.duplicate(),
		"cards":cards,"ammo":ammo,"abilities":abilities,"best_hit":float(run.best_hit),"best_series":int(run.best_series),
		"captured":int(run.captured),"damage_taken":float(run.damage_taken),"lost":bool(run.lost_run),
		"values":values(arena),"hq":hq,"vehicles":vehicles,"trophies":trophies,"states":states}

## What changed in each family since the start of the sortie: [[title, «was → now»]] by family key. Same rows
## as the gear page (stat_snapshot.fighter_groups); unchanged values are left out.
static func values(arena)->Dictionary:
	var groups=STATS.fighter_groups(arena);var result={}
	for key in groups:
		var lines=[]
		for row in groups[key]:
			var base=float(row.base);var now=float(row.current)
			if absf(now-base)<.005 or str(row.title) in ["Прочность штаба","Перебросы","Ячейки рюкзака"]:continue
			lines.append([str(row.title),amount(base,str(row.unit))+" → "+amount(now,str(row.unit))])
		if not lines.is_empty():result[key]=lines
	return result
static func amount(value:float,unit:String)->String:
	match unit.strip_edges():
		"%":return "%d%%" % roundi(value)
		"×":return "×"+UiKit.number(snappedf(value,.01))
		"":return UiKit.number(snappedf(value,.01))
	return UiKit.number(snappedf(value,.01))+" "+unit.strip_edges()
## The first rolled value of an ammo box, for its chip: «урон по технике 49%».
static func first_value(item:Dictionary)->String:
	var specs:Array=Ammo.STATS.get(str(item.type),[])
	if specs.is_empty():return ""
	return Texts.render(str(specs[0][1]))+" "+Ammo.value_text(specs[0],float(item.get("stats",{}).get(specs[0][0],0.0)))

## A chest trophy (secret offer) in words — the same line as on its chest card.
static func trophy_text(offer:Dictionary)->String:
	match str(offer.get("type","")):
		"weapon":return Texts.render("+75% базового урона: ")+Texts.render(str(LootCatalog.WEAPONS.get(offer.id,{"name":""}).name))
		"ability":return Texts.render("+3 уровня силы: ")+Texts.render(str(AbilityCatalog.DATA.get(offer.id,{"name":""}).name))
		"bonus":return Texts.render("+3 уровня: ")+Texts.render(str(LootCatalog.BONUSES.get(offer.id,{"name":""}).name))
		"stat":return Texts.render("+5 HP") if str(offer.get("id",""))=="health" else Texts.render("Напор: +20 % против равных")
	return ""
## What a trophy improved (weapon, ability or bonus name); "" for the hero's own stats.
static func trophy_name(offer:Dictionary)->String:
	match str(offer.get("type","")):
		"weapon":return Texts.render(str(LootCatalog.WEAPONS.get(offer.id,{"name":""}).name))
		"ability":return Texts.render(str(AbilityCatalog.DATA.get(offer.id,{"name":""}).name))
		"bonus":return Texts.render(str(LootCatalog.BONUSES.get(offer.id,{"name":""}).name))
	return ""
static func trophy_icon(offer:Dictionary)->String:
	match str(offer.get("type","")):
		"weapon","ability","bonus":return str(offer.get("id","trophy"))
		"stat":return "health" if str(offer.get("id",""))=="health" else "pressure"
	return "trophy"

static func build(body:Control,data:Dictionary,live:bool):
	var width=WIDTH;var y=0.0
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
	y=build_block(body,data,live,y)
	UiKit.label(body,"Сейчас в поле" if live else ("Последняя вылазка · провал" if data.get("lost",false) else "Последняя вылазка"),Vector2(0,y),Vector2(width,26),UiKit.SECTION_SIZE);y+=32
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

## «Сборка» (T-245, T-246): everything that acts on the fighter now, grouped like the card families. Each group:
## a coloured name, what changed («было → стало»), then the pieces that did it.
static func build_block(body:Control,data:Dictionary,live:bool,y:float)->float:
	var block=Control.new();block.name="BuildBlock";body.add_child(block);block.position=Vector2(0,y);block.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var top=y;y=0.0
	UiKit.label(block,"Сборка",Vector2(0,y),Vector2(WIDTH,30),22)
	UiKit.label(block,"Всё, что действует сейчас" if live else "С чем закончилась вылазка",Vector2(0,y+30),Vector2(WIDTH,20),13,UiKit.MUTED)
	y+=58
	var empty=true
	# Weapon and ammo boxes in its slots.
	var pieces=[]
	if str(data.weapon)!="" and LootCatalog.WEAPONS.has(str(data.weapon)):
		pieces.append({"icon":str(data.weapon),"title":LootCatalog.WEAPONS[data.weapon].name,"line":"Оружие","color":UiKit.MUTED,"tip":LootCatalog.WEAPONS[data.weapon].name})
	for item in data.ammo:
		var type=str(item.get("type",""))
		pieces.append({"icon":"ammo/"+type,"title":Ammo.NAMES.get(type,type),"line":Ammo.RARITY_NAMES[clampi(int(item.get("rarity",0)),0,3)]+(" · "+str(item.get("first","")) if str(item.get("first",""))!="" else ""),"color":Color(LootCatalog.RARITY_COLORS[clampi(int(item.get("rarity",0)),0,3)]),"tip":str(item.get("text",""))})
	if not data.ammo.is_empty():empty=false
	y=group(block,"В руках",UiKit.MUTED,[],pieces,y)
	# Card families: changed values, then the cards (the same card taken twice is one chip «×2»).
	var families={}
	for card in data.cards:
		if str(card.id) in Ammo.TYPES:continue  # the box is shown in the slot above
		if not families.has(card.family):families[card.family]=[]
		families[card.family].append(card)
	for family in RunUpgrades.FAMILIES:
		var cards:Array=families.get(family,[])
		var lines:Array=data.values.get(family,[])
		if cards.is_empty() and lines.is_empty():continue
		empty=false
		var merged={};var order=[]
		for card in cards:
			if not merged.has(card.id):merged[card.id]={"card":card,"count":0,"tier":0};order.append(card.id)
			merged[card.id].count+=1;merged[card.id].tier=maxi(int(merged[card.id].tier),int(card.tier))
		pieces=[]
		for id in order:
			var entry=merged[id];var card=entry.card;var tier=clampi(int(entry.tier),0,3)
			var art="upgrades/"+str(id) if IconKit.has("upgrades/"+str(id)) else str(card.icon) if str(card.icon)!="" else str(id)
			pieces.append({"icon":art,"title":str(card.title),"line":(("×%d · " % int(entry.count)) if int(entry.count)>1 else "")+RunUpgrades.TIER_NAMES[tier],"color":Color(LootCatalog.RARITY_COLORS[tier]),"tip":Texts.render(str(card.title))+("\n"+Texts.render(str(card.detail)) if str(card.detail)!="" else "")})
		var title=Texts.render(RunUpgrades.FAMILIES[family])+(" · "+Texts.render("карточек")+": %d" % cards.size() if not cards.is_empty() else "")
		y=group(block,title,preload("res://scripts/ui/choice_card.gd").FAMILY_COLORS.get(family,UiKit.MUTED),lines,pieces,y)
	# Abilities with their run levels and what changed in them.
	pieces=[]
	for ability in data.abilities:
		pieces.append({"icon":str(ability.id),"title":str(ability.name),"line":("Ур. +%d" % int(ability.level)) if int(ability.level)>0 else "Без усилений","color":UiKit.MUTED,"tip":str(ability.name)})
	if not pieces.is_empty() or data.values.has("abilities"):
		empty=false;y=group(block,"Способности",Color("9fb6e0"),data.values.get("abilities",[]),pieces,y)
	# Headquarters modules and vehicle upgrades from the service stops.
	pieces=[]
	for module in data.hq:pieces.append({"icon":str(module.icon),"title":str(module.name),"line":str(module.text),"color":UiKit.MUTED,"tip":Texts.render(str(module.name))+"\n"+Texts.render(str(module.text))})
	for vehicle in data.vehicles:pieces.append({"icon":str(vehicle.kind),"title":str(vehicle.name),"line":str(vehicle.text),"color":UiKit.MUTED,"tip":Texts.render(str(vehicle.name))+": "+str(vehicle.text)})
	if not pieces.is_empty():empty=false;y=group(block,"Штаб и техника",Color("c4a878"),[],pieces,y)
	# Chest trophies (secret rewards), kept until the end of the sortie.
	pieces=[]
	for trophy in data.trophies:
		# «Пистолет / +75% базового урона»; a hero stat trophy is its own title.
		var named=str(trophy.get("name",""))!=""
		pieces.append({"icon":str(trophy.get("icon","trophy")),"title":str(trophy.name) if named else str(trophy.get("text","")),"line":str(trophy.get("text","")).get_slice(":",0) if named else "Трофей сундука","color":Color(LootCatalog.RARITY_COLORS[3]),"tip":str(trophy.get("text",""))})
	if not pieces.is_empty():empty=false;y=group(block,"Трофеи",Color(LootCatalog.RARITY_COLORS[3]),[],pieces,y)
	# Live effects with a timer (shield, freeze…): only in a running sortie.
	if live:
		pieces=[]
		for state in data.states:pieces.append({"icon":str(state.icon),"title":str(state.title),"line":str(state.value),"color":UiKit.ORANGE,"tip":Texts.render(str(state.title))})
		if not pieces.is_empty():y=group(block,"Сейчас действует",UiKit.ORANGE,[],pieces,y)
	if empty:
		UiKit.label(block,"Карточки появятся после первой волны",Vector2(0,y),Vector2(WIDTH,26),16,UiKit.MUTED);y+=34
	var line=ColorRect.new();block.add_child(line);line.position=Vector2(0,y+4);line.size=Vector2(WIDTH,1);line.color=Color(1,1,1,.08);line.mouse_filter=Control.MOUSE_FILTER_IGNORE
	block.size=Vector2(WIDTH,y+18)
	return top+y+22

## One build group: name, «parameter was → now» pairs in two columns, then chips (icon, name, one quiet line).
static func group(parent:Control,title:String,color:Color,lines:Array,pieces:Array,y:float)->float:
	if lines.is_empty() and pieces.is_empty():return y
	var dot=Panel.new();parent.add_child(dot);dot.position=Vector2(0,y+8);dot.size=Vector2(8,8);dot.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var dot_style=StyleBoxFlat.new();dot_style.bg_color=color;dot_style.set_corner_radius_all(4);dot.add_theme_stylebox_override("panel",dot_style)
	var head=UiKit.label(parent,title,Vector2(16,y),Vector2(WIDTH-16,24),15);head.add_theme_color_override("font_color",color.lightened(.25));head.name="Group"
	y+=28
	# Values as the ammo card shows them: parameter on the left, «was → now» on the right, a thin rule under.
	var column=(WIDTH-24)*.5
	for i in lines.size():
		var x=(i%2)*(column+24);var row_y=y+floori(i/2.0)*28
		var name=UiKit.label(parent,str(lines[i][0]),Vector2(x,row_y),Vector2(column*.58,22),14,UiKit.MUTED);name.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		var value=UiKit.label(parent,str(lines[i][1]),Vector2(x+column*.58,row_y),Vector2(column*.42,22),15);value.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;value.name="Value"
		var rule=ColorRect.new();parent.add_child(rule);rule.position=Vector2(x,row_y+24);rule.size=Vector2(column,1);rule.color=Color(1,1,1,.06);rule.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if not lines.is_empty():y+=ceilf(lines.size()/2.0)*28+8
	for i in pieces.size():
		var piece:Dictionary=pieces[i]
		var pos=Vector2((i%PER_ROW)*(PIECE.x+GAP),y+floori(i/float(PER_ROW))*(PIECE.y+8))
		var chip=UiKit.panel(parent,pos,PIECE,Color(1,1,1,.05));chip.name="Piece";chip.tooltip_text=Texts.render(str(piece.get("tip","")));chip.mouse_filter=Control.MOUSE_FILTER_PASS
		var stripe=ColorRect.new();chip.add_child(stripe);stripe.position=Vector2(0,10);stripe.size=Vector2(3,PIECE.y-20);stripe.color=piece.get("color",UiKit.MUTED);stripe.mouse_filter=Control.MOUSE_FILTER_IGNORE
		UiKit.icon(chip,str(piece.icon),Vector2(9,9),Vector2(32,32))
		var name=UiKit.label(chip,str(piece.title),Vector2(48,5),Vector2(PIECE.x-54,22),14);name.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		var info=UiKit.label(chip,str(piece.line),Vector2(48,26),Vector2(PIECE.x-54,18),12,UiKit.MUTED);info.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	if not pieces.is_empty():y+=ceilf(pieces.size()/float(PER_ROW))*(PIECE.y+8)
	return y+12

static func section(body:Control,title:String,y:float)->float:
	UiKit.label(body,title,Vector2(0,y),Vector2(WIDTH,26),UiKit.SECTION_SIZE)
	return y+32
