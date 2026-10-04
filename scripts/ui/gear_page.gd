extends RefCounted
## «Снаряжение» (T-113, layout from the author's sketch). Two columns on one grid computed from the page
## width: left — the fighter (title, doll facing right with live status icons, stats), right — loadout cells
## (abilities, gadget, HQ, weapon, ammo slots) and the backpack grid with a discard zone and a detail line.
## Gestures (GearCell): tap selects, tap again / double tap / E uses, drag moves, right click drops.
const PAD:=22.0
const GUTTER:=24.0
const GAP:=12.0
const LABEL:=26.0
const UNDER_LABEL:=8.0
const SECTION:=18.0
const STATS=preload("res://scripts/ui/stat_snapshot.gd")
const ITEM=preload("res://scripts/ui/item_info.gd")
const INFO_H:=190.0
static var selected:=""
## The class gallery art looks to the left; the doll is mirrored so it always faces right.
const DOLL_FACES_LEFT:=true
var view
var arena
var body:Control
## The fighter column scrolls on its own (T-163): full stats by groups can be long.
var left_body:Control
var cells:={}
var C:=92.0
var left_w:=300.0
var right_x:=324.0

## The gear page's cell side for this screen: the tablet content width gives the grid (see build()).
## 775 is the tablet content width with the side menu open (field_tablet.gd).
static func cell_size(_node:Node=null)->float:
	var inner=775.0-PAD-8-14.0;var left=floorf(inner*.42)
	return floorf((inner-(left+GUTTER)-3*GAP)/4.0)
## The picture and the name of a backpack item, shared with the run result screen.
static func icon_key(kind:String,item:Dictionary)->String:
	match kind:
		"weapon":return str(item.get("id","pistol"))
		"supply":return "heart"
		"ammo":
			var type=str(item.get("type",Ammo.STANDARD))
			return "ammo/"+type if IconKit.has("ammo/"+type) else Ammo.ART.get(type,"stats/damage")
	var sheet=ITEM.blueprint_key(item)
	return sheet if IconKit.has(sheet) else str(item.get("id",""))
static func item_name(kind:String,item:Dictionary)->String:
	match kind:
		"weapon":
			var tier=clampi(int(item.get("rarity",0)),0,3)
			return Texts.render(Game.LOOT.WEAPONS[str(item.get("id","pistol"))].name)+(" · "+Texts.render(LootCatalog.RARITY_NAMES[tier]) if tier>0 else "")
		"supply":return Texts.render("Аптечка")
		"ammo":return Texts.render(Ammo.NAMES.get(str(item.get("type","")),"")+" боеприпасы")
	return Texts.render(Game.recipe_name(item))
func _init(tablet):view=tablet;arena=tablet.arena if "arena" in tablet else null
func run()->Object:return arena.run if is_instance_valid(arena) else null

func build():
	var content:Control=view.content
	# No page title: the selected tab already says «Снаряжение»; the fighter's name heads the page (sketch).
	var scroll=ScrollContainer.new();scroll.name="GearScroll";content.add_child(scroll);scroll.position=Vector2(PAD,20);scroll.size=Vector2(content.size.x-PAD-8,content.size.y-32)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	# No visible scroll bars on this page (author, 2026-10-03): wheel and drag still scroll.
	scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
	body=Control.new();body.name="GearBody";scroll.add_child(body)
	# Grid: inner width minus a 14 px lane for the scrollbar; the left column takes ~42 %, cells fill the rest.
	var inner=scroll.size.x-14.0
	left_w=floorf(inner*.42);right_x=left_w+GUTTER
	C=floorf((inner-right_x-3*GAP)/4.0)
	body.custom_minimum_size=Vector2(inner,10)
	if is_instance_valid(arena) and run()!=null:Ammo.ensure(run(),str(arena.weapon))
	# The left column lives in its own scroll over the left part of the page.
	var left_scroll=ScrollContainer.new();left_scroll.name="FighterScroll";content.add_child(left_scroll);left_scroll.position=scroll.position;left_scroll.size=Vector2(left_w+10,scroll.size.y)
	left_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;left_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
	left_body=Control.new();left_body.name="FighterBody";left_scroll.add_child(left_body)
	var left_bottom=build_left()
	left_body.custom_minimum_size=Vector2(left_w,left_bottom+16)
	var bottom=build_right()
	body.custom_minimum_size.y=bottom+16
	if selected!="" and not cells.has(selected):selected=""
	highlight()

func col(i:int)->float:return right_x+i*(C+GAP)

# ── Left: fighter ──────────────────────────────────────────────────────────────────────────────────────────
func build_left()->float:
	var level=Game.class_level()
	UiKit.label(left_body,"%s, ур. %d" % [Game.CLASSES[Game.selected_class].name,level],Vector2(0,0),Vector2(left_w,LABEL+4),22).name="FighterTitle"
	var doll_h=2*C+LABEL+UNDER_LABEL+SECTION
	var doll=Panel.new();doll.name="Doll";left_body.add_child(doll);doll.position=Vector2(0,LABEL+UNDER_LABEL);doll.size=Vector2(left_w,doll_h)
	doll.add_theme_stylebox_override("panel",UiKit.style(Color(1,1,1,.03),14,Color(1,1,1,.12)))
	var picture=TextureRect.new();picture.name="DollArt";doll.add_child(picture);picture.texture=preload("res://scripts/ui/class_gallery.gd").texture(Game.selected_class,true)
	picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
	# Centred in the block (T-146); the state icons overlay its left edge.
	picture.position=Vector2(12,12);picture.size=Vector2(left_w-24,doll_h-24)
	# The doll always faces right (the gallery art looks left).
	picture.flip_h=DOLL_FACES_LEFT
	# Live states: a column of round icons with their timer sector; hover tells the details.
	# Only live effects (with a timer or «active»); no placeholder icons when nothing is on (T-126).
	var states=STATS.state(arena if is_instance_valid(arena) else null).filter(func(item):return item.remaining!=null)
	var y=12.0
	for item in states.slice(0,int((doll_h-24)/48.0)):
		var chip=Panel.new();doll.add_child(chip);chip.position=Vector2(12,y);chip.size=Vector2(40,40);chip.mouse_filter=Control.MOUSE_FILTER_PASS
		chip.add_theme_stylebox_override("panel",UiKit.style(Color(1,1,1,.06),20,Color(1,1,1,.14)));chip.tooltip_text=Texts.render(str(item.title)+": "+str(item.value))
		var art=TextureRect.new();chip.add_child(art);art.texture=UiKit.icon_texture(str(item.icon));art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;art.position=Vector2(8,8);art.size=Vector2(24,24);art.mouse_filter=Control.MOUSE_FILTER_IGNORE
		if item.remaining!=null:
			var sector=preload("res://scripts/ui/timer_sector.gd").new();chip.add_child(sector);sector.size=Vector2(40,40);sector.mouse_filter=Control.MOUSE_FILTER_IGNORE;sector.set_remaining(float(item.remaining))
		y+=48
	# Stats under the doll: weapon numbers, then the active ammo in words.
	var top=doll.position.y+doll_h+SECTION
	UiKit.label(left_body,"Характеристики",Vector2(0,top),Vector2(left_w,LABEL),UiKit.SECTION_SIZE)
	# Every characteristic, grouped (fire, survival, abilities, ammo, recon, logistics), T-163.
	# Bars at 80% of the column (author, 2026-10-03), left-aligned.
	var bars=STATS.add_bars(left_body,Vector2(0,top+LABEL+UNDER_LABEL),floorf(left_w*.8),STATS.fighter(arena if is_instance_valid(arena) else null),46,false);bars.name="FighterStats"
	var after=top+LABEL+UNDER_LABEL+bars.content_height()+GAP
	var ammo=Ammo.item(run()) if run()!=null else Ammo.standard()
	var line=Texts.render("Боеприпасы")+": "+Texts.render(Ammo.NAMES.get(str(ammo.type),""))
	if ammo.type!=Ammo.STANDARD:line+=" — "+Ammo.describe(ammo)
	var note=UiKit.label(left_body,line,Vector2(0,after),Vector2(left_w,44),14,Color(Ammo.COLORS.get(str(ammo.type),"cfd3c8")));note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;note.name="AmmoLine"
	return after+note.get_minimum_size().y+8

# ── Right: loadout and backpack ────────────────────────────────────────────────────────────────────────────
func build_right()->float:
	var y=0.0
	y=ability_block(y)
	y=loadout_block(y)
	y=backpack_block(y)+GAP
	# Discard zone: drag anything here; it lands on the floor (field or room) — on the route map it is destroyed (T-202).
	var zone=GearCell.new();zone.name="DiscardZone";body.add_child(zone);zone.key="discard";zone.position=Vector2(right_x,y);zone.size=Vector2(4*C+3*GAP,40)
	Texts.set_text(zone,"Выбросить" if Backpack.can_drop(arena) or run()==null else "Уничтожить");zone.disabled=run()==null
	zone.add_theme_font_size_override("font_size",13);zone.on_drop=move
	for state in ["normal","hover","disabled"]:
		var style=UiKit.style(Color(1,1,1,.02),10,Color(1,1,1,.18));style.set_border_width_all(1)
		zone.add_theme_stylebox_override(state,style)
	cells["discard"]=zone
	y+=40+GAP
	# Detail line of the selected item with the same actions as the gestures (touch has no right click).
	var info=Panel.new();info.name="GearInfo";body.add_child(info);info.position=Vector2(right_x,y);info.size=Vector2(4*C+3*GAP,INFO_H)
	info.add_theme_stylebox_override("panel",UiKit.style(Color(1,1,1,.03),12,Color(1,1,1,.1)))
	fill_info(info)
	return y+INFO_H

## Abilities, gadget and HQ support — pinned cells, the same on the gear screen and the run result.
func ability_block(y:float)->float:
	section("Способности",0,y,2);section("Гаджет",2,y,1);section("Штаб",3,y,1)
	y+=LABEL+UNDER_LABEL
	var abilities=Game.class_loadout()
	for i in range(2):
		var id=abilities[i] if i<abilities.size() else ""
		var info=AbilityCatalog.DATA.get(id,{})
		fixed_cell("ability:%d" % i,col(i),y,Vector2(C,C),"abilities/"+id if id!="" else "",info.get("name","Второй навык класса"),info.get("description","Открывается в «Казарме»: уровень класса 5, затем 2500 сплава."),id=="",["Q","1"][i])
	var gadget=AbilityCatalog.DATA.get(Game.gadget,{})
	fixed_cell("gadget",col(2),y,Vector2(C,C),"abilities/"+Game.gadget if Game.gadget!="" else "",gadget.get("name","Гаджет"),gadget.get("description","Выбирается в «Арсенале» → Гаджеты."),Game.gadget=="","F")
	var hq=Game.hq_loadout();var module=hq[0] if not hq.is_empty() else ""
	fixed_cell("hq",col(3),y,Vector2(C,C),module,HQCatalog.DATA.get(module,{}).get("name","Поддержка штаба"),HQCatalog.DATA.get(module,{}).get("description","Выбери модуль в «Штабе» → Технологии."),module=="","2")
	y+=C+SECTION
	return y

## The equipped weapon and the ammo slots — one block for the gear screen and the run result (2026-10-03).
func loadout_block(y:float)->float:
	section("Оружие",0,y,2);section("Боеприпасы",2,y,2)
	y+=LABEL+UNDER_LABEL
	var weapon=str(arena.weapon) if is_instance_valid(arena) else Game.selected_weapon
	var w=fixed_cell("weapon",col(0),y,Vector2(2*C+GAP,C),weapon,Game.LOOT.WEAPONS[weapon].name,"",false,"")
	w.info=ITEM.of("weapon",{"id":weapon},arena,true)
	if Backpack.holstered(run()):
		# Empty hands (2026-10-03): the paws fight (Space, V); the cell reminds to take a gun from the backpack.
		var hint=UiKit.label(w,"Руки пусты — возьми оружие",Vector2(C*.9,0),Vector2(w.size.x-C*.9-8,C),14,UiKit.ORANGE);hint.name="EmptyHands";hint.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var picture=w.get_node_or_null("Art")
		if picture:picture.size.x=C*.8
		var frame=UiKit.style(Color(UiKit.ORANGE,.08),12,UiKit.ORANGE);frame.set_border_width_all(2)
		for state in ["normal","hover","pressed","focus"]:w.add_theme_stylebox_override(state,frame)
	else:
		# The gun in hand drags like any item (author, 2026-10-03): onto a backpack weapon to swap, or into a free
		# cell — then the hands are empty and the cat scratches with its paws.
		w.item_kind="weapon";w.draggable=run()!=null
		if run()!=null:rarity_frame(w,int(run().weapon_rarity))
	w.set_meta("inset",.08)
	var slots:Array=run().ammo_slots if run()!=null else [Ammo.standard()]
	for i in range(2):
		var locked=i>=slots.size()
		var cell=item_cell("slot:%d" % i,col(2+i),y,null if locked else slots[i],locked)
		if locked:cell.tooltip_text=Texts.render("Второй слот боеприпасов — «Арсенал», для этого оружия")
	y+=C+SECTION
	return y
## The backpack grid (4×2 GearCells) — the same block on the gear screen and the run result; `entries` lets the
## result screen show blueprints that were already taken away (Backpack.layout otherwise).
func backpack_block(y:float,entries:Array=[])->float:
	var r=run()
	var used=Backpack.used(r) if r!=null else 0
	section("Рюкзак · %d / %d" % [used if entries.is_empty() else entries.filter(func(e):return e!=null).size(),Backpack.capacity()],0,y,4)
	y+=LABEL+UNDER_LABEL
	if entries.is_empty():entries=Backpack.layout(r)
	var safe=Backpack.safe_cells(r)
	for i in range(Backpack.CELLS):
		var x=col(i%4);var cy=y+floorf(i/4.0)*(C+GAP)
		var locked=i>=Backpack.capacity()
		var entry=entries[i]
		var cell=item_cell("bag:%d" % i,x,cy,entry,locked)
		if locked:cell.tooltip_text=Texts.render("Ячейка закрыта — «Казарма» → Рюкзак")
		elif i<safe:
			# «Сейф рюкзака» (T-196): an insured cell — a small shield in the corner, the rule in the tooltip.
			var badge=UiKit.icon(cell,"shield",Vector2(C-26,6),Vector2(20,20));badge.name="Safe";badge.mouse_filter=Control.MOUSE_FILTER_IGNORE
			var rule=Texts.render("Сейф: чертёж не пропадёт при выбывании")
			cell.tooltip_text=rule if cell.tooltip_text=="" else cell.tooltip_text+"\n"+rule
	return y+2*C+GAP
## Cells shown as a record (the run result): no menu, no drag, no drop; the hover card stays.
func freeze():
	for key in cells:
		var cell:GearCell=cells[key]
		cell.draggable=false;cell.on_drop=Callable();cell.on_activate=Callable();cell.on_discard=Callable();cell.focus_mode=Control.FOCUS_NONE;cell.release_focus()
		for link in cell.pressed.get_connections():cell.pressed.disconnect(link.callable)

func section(text:String,column:int,y:float,span:int):
	var label=UiKit.label(body,text,Vector2(col(column),y),Vector2(span*C+(span-1)*GAP,LABEL),UiKit.SECTION_SIZE);label.clip_text=true
	return label
func base_cell(key:String,x:float,y:float,size:Vector2,locked:bool)->GearCell:
	var cell=GearCell.new();cell.name="Cell_"+key.replace(":","_");body.add_child(cell);cell.key=key;cell.position=Vector2(x,y);cell.size=size;cell.custom_minimum_size=size
	var style=UiKit.style(Color(1,1,1,.04) if not locked else Color(0,0,0,.18),12,Color(1,1,1,.16) if not locked else Color(1,1,1,.08));style.set_border_width_all(1)
	for state in ["normal","hover","pressed","disabled","focus"]:cell.add_theme_stylebox_override(state,style)
	cell.on_drop=move;cell.on_discard=discard;cell.on_activate=activate
	cell.pressed.connect(func():tapped(key))
	if locked:
		cell.disabled=true
		var lock=TextureRect.new();lock.name="Lock";cell.add_child(lock);lock.texture=UiKit.interface_icon("lock") if ResourceLoader.exists("res://assets/icons/interface_straight/lock.svg") else null
		lock.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;lock.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;lock.size=Vector2(24,24);lock.position=(size-lock.size)*.5;lock.modulate=Color(1,1,1,.45);lock.mouse_filter=Control.MOUSE_FILTER_IGNORE
		if lock.texture==null:lock.queue_free();Texts.set_text(cell,"🔒")
	cells[key]=cell
	return cell
## A gun's cell shows its rarity (T-225): the background and the frame softly tinted in the rarity colour
## (LootCatalog.RARITY_COLORS, as on the item card); common guns keep the plain cell.
static func rarity_frame(cell:Control,tier:int):
	tier=clampi(tier,0,3)
	if tier<=0:return
	var color=Color(LootCatalog.RARITY_COLORS[tier])
	var frame=UiKit.style(Color(color,.17),12,color);frame.set_border_width_all(2)
	for state in ["normal","hover","pressed","focus"]:cell.add_theme_stylebox_override(state,frame)
func art(cell:Control,texture:Texture2D,inset:=.12):
	if texture==null:return
	var picture=TextureRect.new();picture.name="Art";cell.add_child(picture);picture.texture=texture;picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
	picture.position=cell.size*inset;picture.size=cell.size*(1.0-2*inset)
func fixed_cell(key:String,x:float,y:float,size:Vector2,icon_id:String,title:String,info:String,locked:bool,hotkey:String)->GearCell:
	var cell=base_cell(key,x,y,size,locked)
	if not locked and icon_id!="":art(cell,UiKit.trimmed(UiKit.icon_texture(icon_id)),.14 if size.x==size.y else .1)
	cell.tooltip_text=Texts.render(title)+"\n"+Texts.render(info);cell.set_meta("title",title);cell.set_meta("info",info)
	if hotkey!="" and not locked:UiKit.label(cell,hotkey,Vector2(8,size.y-22),Vector2(30,18),12,UiKit.MUTED)
	return cell
## A cell holding an ammo item, a blueprint or nothing.
func item_cell(key:String,x:float,y:float,entry,locked:bool)->GearCell:
	var cell=base_cell(key,x,y,Vector2(C,C),locked)
	if locked or entry==null or Ammo.is_empty_slot(entry):
		# An unloaded slot (T-197): an empty cell that waits for ammo.
		if Ammo.is_empty_slot(entry):cell.tooltip_text=Texts.render("Пусто — перетащи сюда боеприпасы")
		return cell
	var is_slot=key.begins_with("slot:")
	var ammo:Dictionary=entry if is_slot else (entry.item if entry.kind=="ammo" else {})
	if is_slot or entry.kind=="ammo":
		var type=str(ammo.get("type",Ammo.STANDARD));var color=Color(Ammo.COLORS.get(type,"cfd3c8"))
		var rarity=clampi(int(ammo.get("rarity",0)),0,3)
		var style=UiKit.style(Color(color,.12),12,Color(LootCatalog.RARITY_COLORS[rarity]) if type!=Ammo.STANDARD else Color(1,1,1,.16));style.set_border_width_all(2 if type!=Ammo.STANDARD else 1)
		for state in ["normal","hover","pressed","focus"]:cell.add_theme_stylebox_override(state,style)
		# Ammo series (box + cartridge, data/icon_kit.json «ammo/…»); older effect art as the fallback.
		var key_art="ammo/"+type if IconKit.has("ammo/"+type) else {"standard":"stats/damage","burn":"upgrades/burn","stun":"upgrades/stun","shock":"upgrades/shock"}.get(type,Ammo.ART.get(type,"stats/damage"))
		art(cell,UiKit.trimmed(UiKit.icon_texture(key_art)),.1 if key_art.begins_with("ammo/") else .18)
		var name_label=UiKit.label(cell,Texts.render(Ammo.NAMES.get(type,type)),Vector2(4,C-20),Vector2(C-8,18),11 if C>=100 else 9,color);name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;name_label.clip_text=true
		# Plain rounds are an item too (T-197): they can be taken out, dropped or moved.
		cell.item_kind="ammo";cell.draggable=true
		cell.info=ITEM.of("ammo",ammo,arena,is_slot)
		cell.tooltip_text=Texts.render(Ammo.NAMES.get(type,type)+" боеприпасы")+("\n"+Ammo.describe(ammo) if type!=Ammo.STANDARD else "")
		if is_slot and run()!=null and int(key.get_slice(":",1))==run().ammo_active and run().ammo_slots.size()>1:
			UiKit.label(cell,"R",Vector2(C-18,4),Vector2(14,16),11,UiKit.MUTED)
	elif entry.kind=="weapon":
		# A spare gun for this run: double tap, «Взять» or a drag onto the weapon cell takes it in hand.
		var gun=str(entry.item.get("id","pistol"));var tier=clampi(int(entry.item.get("rarity",0)),0,3)
		rarity_frame(cell,tier)
		art(cell,UiKit.trimmed(UiKit.icon_texture(gun)),.1)
		var name_label=UiKit.label(cell,Texts.render(Game.LOOT.WEAPONS[gun].name),Vector2(4,C-20),Vector2(C-8,18),11 if C>=100 else 9,UiKit.INK);name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;name_label.clip_text=true
		cell.item_kind="weapon";cell.draggable=true;cell.info=ITEM.of("weapon",entry.item,arena)
		cell.tooltip_text=Texts.render(Game.LOOT.WEAPONS[gun].name)+"\n"+Texts.render("Запасное оружие")
	elif entry.kind=="supply":
		# Aid kit (T-115): tap twice / E / H heals.
		art(cell,UiKit.trimmed(UiKit.icon_texture("heart")),.16)
		cell.item_kind="supply";cell.draggable=true;cell.info=ITEM.of("supply",entry.item,arena)
		cell.tooltip_text=Texts.render("Аптечка")+"\n"+Texts.render("+%s здоровья · ещё нажатие или H — вылечиться") % str(snappedf(float(entry.item.get("heal",1.0)),.1))
	else:
		# Blueprint series: the same clipboard, the silhouette tells the category (data/icon_kit.json «blueprint/…»).
		var sheet=ITEM.blueprint_key(entry.item)
		art(cell,UiKit.trimmed(UiKit.icon_texture(sheet if IconKit.has(sheet) else str(entry.item.get("id","")))),.1 if IconKit.has(sheet) else .16)
		cell.item_kind="recipe";cell.draggable=true;cell.info=ITEM.of("recipe",entry.item,arena)
		cell.tooltip_text=Texts.render(Game.recipe_name(entry.item))+"\n"+Texts.render("Чертёж — донеси до хаба")
	return cell

# ── Gestures ───────────────────────────────────────────────────────────────────────────────────────────────
## Tap: select; tap the selected cell again (or double tap / E) to use it.
## One tap: the item's actions as a small menu under it (a second tap closes it); a double tap uses it
## (equip / load / heal / take in hand); hover shows its card against what is equipped (2026-10-03).
func tapped(key:String):
	var cell=cells.get(key)
	if cell and cell.skip_tap:cell.skip_tap=false;return
	selected="" if key==selected else key
	highlight();refresh_info()
func activate(key:String):
	var r=run()
	if key=="weapon" and Backpack.holstered(r):return
	if key=="weapon":
		preload("res://scripts/ui/tablet_pages.gd").new(view).weapon_details(str(arena.weapon) if is_instance_valid(arena) else Game.selected_weapon);return
	if not key.begins_with("bag:") and not key.begins_with("slot:"):
		var cell=cells.get(key)
		if cell:preload("res://scripts/ui/tablet_pages.gd").new(view).details(str(cell.get_meta("title","")),str(cell.get_meta("info","")))
		return
	if r==null:return
	if key.begins_with("bag:"):
		var e=entry(key)
		if e==null:return
		match e.kind:
			"supply":
				if Backpack.use_medkit(arena,e.index):done("")
			"weapon":
				if Backpack.equip_weapon(arena,e.index):done("Оружие в руках")
			"ammo":
				if Backpack.equip(arena,e.index):done("Боеприпасы заряжены")
				else:arena.toast(Texts.render("Эти боеприпасы не подходят к оружию"))
			_:arena.toast(Texts.render("Чертёж донеси до хаба, чтобы открыть"))
	elif key.begins_with("slot:"):
		var slot=int(key.get_slice(":",1))
		if Backpack.full(r):arena.toast(Texts.render("Рюкзак полон"));return
		if Backpack.unequip(arena,slot):done("Боеприпасы сняты в рюкзак")
## The bag entry behind a «bag:N» cell key: {kind, index, item} or null.
func entry(key:String):
	var cells=Backpack.layout(run());var n=int(key.get_slice(":",1))
	return cells[n] if n>=0 and n<cells.size() else null
func move(from:String,to:String):
	var r=run()
	if r==null:return
	if to=="discard":discard(from);return
	if from.begins_with("bag:") and to=="weapon":
		var e=entry(from)
		if e!=null and e.kind=="weapon" and Backpack.equip_weapon(arena,e.index):done("Оружие в руках")
		elif e!=null:arena.toast(Texts.render("Сюда кладётся только оружие"))
		return
	if from=="weapon" and to.begins_with("bag:"):
		var e=entry(to)
		if e!=null and e.kind=="weapon":
			if Backpack.equip_weapon(arena,e.index):done("Оружие в руках")
		elif e==null and Backpack.holster(arena,int(to.get_slice(":",1))):selected="";done("Оружие в рюкзаке — руки пусты, бьёшь лапой")
		elif e==null:arena.toast(Texts.render("Рюкзак полон"))
		return
	if from.begins_with("bag:") and to.begins_with("slot:"):
		var e=entry(from)
		if e!=null and e.kind=="ammo" and Backpack.equip(arena,e.index,int(to.get_slice(":",1))):done("Боеприпасы заряжены")
		elif e!=null:arena.toast(Texts.render("В слот боеприпасов кладутся только боеприпасы"))
	elif from.begins_with("slot:") and to.begins_with("bag:"):
		var target=int(to.get_slice(":",1))
		if Backpack.unequip(arena,int(from.get_slice(":",1))):
			# Lands in the cell it was dropped on when that cell is open and free.
			if target<Backpack.capacity() and Backpack.layout(r)[target]==null:r.ammo_bag.back()["cell"]=target
			done("Боеприпасы сняты в рюкзак")
		else:arena.toast(Texts.render("Рюкзак полон"))
	elif from.begins_with("bag:") and to.begins_with("bag:"):
		# Free layout (T-196): any item to any open cell; an item already there swaps places.
		if Backpack.place(r,int(from.get_slice(":",1)),int(to.get_slice(":",1))):selected=to;done("")
	elif from.begins_with("slot:") and to.begins_with("slot:"):
		var a=int(from.get_slice(":",1));var b=int(to.get_slice(":",1))
		if b<r.ammo_slots.size():
			var keep=r.ammo_slots[a];r.ammo_slots[a]=r.ammo_slots[b];r.ammo_slots[b]=keep;r.ammo_active=b;done("")
## Throw away (T-202): onto the floor of the field or the room the hero stands in; where there is no floor (the
## route map) the item is destroyed after the same confirmation as «Уничтожить».
func discard(key:String):
	var r=run()
	if r==null:return
	var ok=false
	# The gun in hand is not thrown away from its cell (put it into the backpack first); any loaded ammo can go.
	if key=="weapon":arena.toast(Texts.render("Нельзя выбросить последнее оружие — нечем будет воевать"));Game.sound("ui_denied",arena);return
	if not Backpack.can_drop(arena):confirm_destroy(key);return
	if key.begins_with("slot:"):
		var slot=r.ammo_slots[int(key.get_slice(":",1))] if int(key.get_slice(":",1))<r.ammo_slots.size() else null
		if not slot is Dictionary or Ammo.is_empty_slot(slot):return
	if key.begins_with("bag:"):
		var e=entry(key)
		ok=e!=null and Backpack.drop(arena,e.kind,e.index)
	elif key.begins_with("slot:"):ok=Backpack.drop(arena,"slot",int(key.get_slice(":",1)))
	if ok:selected="";done("Выброшено рядом с бойцом","drop")
## «Уничтожить» (T-203): any item, after a confirmation; a slot becomes empty, the gun in hand leaves the paws.
func destroy(key:String):
	var r=run()
	if r==null:return
	var ok=false
	if key=="weapon":ok=Backpack.destroy(arena,"hand")
	elif key.begins_with("slot:"):ok=Backpack.destroy(arena,"slot",int(key.get_slice(":",1)))
	elif key.begins_with("bag:"):
		var e=entry(key)
		ok=e!=null and Backpack.destroy(arena,e.kind,e.index)
	if ok:selected="";done("Предмет уничтожен","destroy")
## What a destroy would take away, for the confirmation: the item's name.
func destroy_target(key:String)->String:
	var r=run()
	if r==null:return ""
	if key=="weapon":return Texts.render(Game.LOOT.WEAPONS.get(str(r.weapon),{}).get("name",""))
	if key.begins_with("slot:"):
		var n=int(key.get_slice(":",1))
		return item_name("ammo",r.ammo_slots[n]) if n<r.ammo_slots.size() and r.ammo_slots[n] is Dictionary else ""
	var e=entry(key)
	return item_name(e.kind,e.item) if e!=null else ""
func confirm_destroy(key:String):
	if view.get_node_or_null("DestroyConfirm"):return
	var name=destroy_target(key)
	if name=="":return
	var dialog=DestroyDialog.new();dialog.name="DestroyConfirm";view.add_child(dialog);dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);dialog.add_to_group("guide_confirmation")
	var shade=ColorRect.new();dialog.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,.6)
	var area=view.get_viewport_rect().size;var width=minf(520,area.x-40);var height=230.0
	var box=UiKit.panel(dialog,(area-Vector2(width,height))*.5-view.global_position,Vector2(width,height))
	UiKit.label(box,"Уничтожить предмет?",Vector2(24,20),Vector2(width-48,40),26)
	var what=UiKit.label(box,name,Vector2(24,68),Vector2(width-48,30),20);what.clip_text=true;what.name="DestroyItem"
	UiKit.label(box,"Пропадёт навсегда, вернуть нельзя.",Vector2(24,100),Vector2(width-48,30),17)
	var cancel=UiKit.button(box,"Отмена",Vector2(width*.5+6,height-74),Vector2((width-60)*.5,50),dialog.queue_free,true);cancel.name="DestroyCancel"
	var accept=UiKit.button(box,"Уничтожить",Vector2(24,height-74),Vector2((width-60)*.5,50),func():dialog.queue_free();destroy(key));accept.name="DestroyAccept"
	cancel.grab_focus.call_deferred()
## The confirmation closes on Esc / back like any window (and does not close the tablet under it).
class DestroyDialog extends Control:
	func _input(event):
		if (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")) and not event.is_echo():
			get_viewport().set_input_as_handled();queue_free()
func done(message:String,_sound:="equip"):
	Game.sound("weapon_equip",arena if is_instance_valid(arena) else view)
	if message!="" and is_instance_valid(arena):arena.toast(Texts.render(message))
	view.refresh()
func highlight():
	for key in cells:
		var cell:Control=cells[key];if not is_instance_valid(cell):continue
		cell.modulate=Color(1.12,1.08,.95) if key==selected else Color.WHITE
		var ring=cell.get_node_or_null("SelectRing")
		if key==selected and ring==null:
			ring=Panel.new();ring.name="SelectRing";cell.add_child(ring);ring.mouse_filter=Control.MOUSE_FILTER_IGNORE;ring.position=Vector2(-3,-3);ring.size=cell.size+Vector2(6,6)
			var style=UiKit.style(Color.TRANSPARENT,14,UiKit.ORANGE);style.set_border_width_all(3);ring.add_theme_stylebox_override("panel",style)
		elif key!=selected and ring!=null:ring.queue_free()
	popover()
## The actions of the selected item float right under it (T-172), so the buttons are where the eyes are.
func popover():
	var old=body.get_node_or_null("GearActions")
	if old:old.queue_free()
	if selected=="" or not cells.has(selected):return
	var actions=actions_for(selected)
	if actions.is_empty():return
	var cell:Control=cells[selected]
	# A vertical list (T-203): one button per line, the main action first.
	var bw=maxf(150.0,C*1.4);var h=36.0;var pad=6.0
	var box=Panel.new();box.name="GearActions";body.add_child(box);box.z_index=5
	box.size=Vector2(bw+pad*2,actions.size()*h+(actions.size()+1)*pad)
	box.add_theme_stylebox_override("panel",UiKit.style(Color("1d2420"),12,UiKit.ORANGE))
	var x=clampf(cell.position.x+(cell.size.x-box.size.x)*.5,right_x,right_x+4*C+3*GAP-box.size.x)
	box.position=Vector2(x,cell.position.y+cell.size.y+6)
	for i in range(actions.size()):
		var b=UiKit.button(box,actions[i][0],Vector2(pad,pad+i*(h+pad)),Vector2(bw,h),actions[i][1],i==0);b.add_theme_font_size_override("font_size",14);b.name="Act_%d" % i;b.clip_text=true
		if actions[i][0]=="Уничтожить":b.add_theme_color_override("font_color",Color("e0806b"));b.add_theme_color_override("font_hover_color",Color("f09a86"))
	if UiKit.motion_enabled():
		box.modulate.a=0;box.pivot_offset=Vector2(box.size.x*.5,0);box.scale=Vector2(.9,.9)
		var t=box.create_tween().set_parallel();t.tween_property(box,"modulate:a",1.0,.12);t.tween_property(box,"scale",Vector2.ONE,.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
func actions_for(key:String)->Array:
	var cell:GearCell=cells[key];var actions=[]
	if key.begins_with("bag:") and cell.item_kind=="ammo":actions.append(["Надеть",func():activate(key)])
	if key.begins_with("bag:") and cell.item_kind=="supply":actions.append(["Вылечиться",func():activate(key)])
	if key.begins_with("bag:") and cell.item_kind=="weapon":actions.append(["Взять",func():activate(key)])
	if key.begins_with("slot:") and cell.draggable:actions.append(["Снять",func():activate(key)])
	if key=="weapon" and cell.draggable and run()!=null and not Backpack.full(run()):actions.append(["Снять",func():move("weapon","bag:-1")])
	# Throw away onto the floor where there is one (field, room); destroy anything, after a confirmation (T-203).
	if (key.begins_with("bag:") or key.begins_with("slot:")) and cell.draggable and Backpack.can_drop(arena):actions.append(["Выбросить",func():discard(key)])
	if (key.begins_with("bag:") or key.begins_with("slot:") or key=="weapon") and cell.draggable and run()!=null:actions.append(["Уничтожить",func():confirm_destroy(key)])
	return actions
func refresh_info():
	var info=body.get_node_or_null("GearInfo")
	if info:
		for child in info.get_children():child.queue_free()
		fill_info(info)
func fill_info(info:Panel):
	var w=info.size.x
	var cell:GearCell=cells.get(selected) if selected!="" else null
	if Backpack.holstered(run()):
		UiKit.label(info,"Руки пусты — бьёшь лапой. Возьми оружие из рюкзака.",Vector2(14,10),Vector2(w-28,76),14,UiKit.ORANGE).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		if cell==null or cell.info.is_empty():return
		var spare=ITEM.card(cell.info,w-28);info.add_child(spare);spare.position=Vector2(14,86);return
	if cell==null or cell.info.is_empty():
		UiKit.label(info,"Нажми — действия, дважды — надеть.",Vector2(14,10),Vector2(w-28,76),13,UiKit.MUTED).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		return
	# The same card as the hover tooltip: on touch there is no hover, so the selected item shows it here.
	var card=ITEM.card(cell.info,w-28);info.add_child(card);card.position=Vector2(14,10)
