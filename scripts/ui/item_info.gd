extends RefCounted
## One info card for every item window (author, 2026-10-03: inventory like military games, but arcade and
## cosy): a miniature, the name in its rarity colour, ONE plain sentence of what it does, then its numbers
## next to what is equipped — green ▲ better, red ▼ worse. Used by the gear tooltip and info line, the card
## over a dropped item and the ammo machine result.
const AMMO_EFFECT={
	"standard":"Обычные пули: без эффектов, никогда не кончаются.",
	"burn":"Поджигают: враг горит и теряет здоровье несколько секунд. Бочки взрываются с одного попадания.",
	"stun":"Оглушают: враг замирает — не двигается и не стреляет.",
	"shock":"ЭМИ: сильнее бьют технику и дронов, могут замкнуть машину.",
	"explosive":"Разрывные: пуля взрывается и задевает врагов рядом.",
	"ap":"Бронебойные: прошивают нескольких врагов подряд и могут пробить щит.",
	"ricochet":"Рикошет: пуля отскакивает к следующему врагу.",
	"cryo":"Холод: враги замедляются и могут замёрзнуть.",
	"cluster":"Кассетные: заряд разлетается мелкими бомбами.",
	"napalm":"Напалм: на месте взрыва остаётся горящее пятно."}

## kind: "weapon" (a gun item or the one in hand), "ammo" (a box, or a loaded slot with equipped=true),
## "supply", "recipe". Rows: [label, new value, equipped value or "", +1 better / -1 worse / 0].
static func of(kind:String,item:Dictionary,arena,equipped:=false)->Dictionary:
	var info={"title":"","tier":0,"icon":null,"summary":"","rows":[],"note":""}
	match kind:
		"weapon":
			var id=str(item.get("id","pistol"));var data=Game.LOOT.WEAPONS.get(id,Game.LOOT.WEAPONS["pistol"])
			info.title=data.name;info.tier=int(item.get("rarity",0));info.icon=UiKit.trimmed(UiKit.icon_texture(id))
			info.summary=str(data.get("role","")) if str(data.get("role",""))!="" else "Оружие"
			var hand=str(arena.weapon) if is_instance_valid(arena) else Game.selected_weapon
			var ctx=arena if is_instance_valid(arena) else null
			var new=CombatStats.weapon(ctx,id,{"item_stats":item.get("stats",{})} if not equipped else {});var old=CombatStats.weapon(ctx,hand)
			if equipped and ctx!=null:info.tier=int(ctx.run.weapon_rarity)
			var shot=func(stats:Dictionary,gun:String)->float:return float(stats.damage)*int(Game.LOOT.WEAPONS[gun].get("pellets",1))
			# Only the gun in hand itself has nothing to compare with: a second pistol of another rarity or with
			# rolled stats is compared with the one in hand (T-247).
			var same=equipped
			for spec in [["Урон за выстрел",shot.call(new,id),shot.call(old,hand),""],["Темп",new.rate,old.rate," /с"],["Дальность",new.range,old.range," м"],["Напор",new.intercept,old.intercept,"%"]]:
				info.rows.append(row(spec[0],spec[1],spec[2],spec[3],same))
			if same:info.note="В руках"
		"ammo":
			var type=str(item.get("type",Ammo.STANDARD));info.tier=int(item.get("rarity",0)) if type!=Ammo.STANDARD else 0
			info.title=Texts.render(Ammo.NAMES.get(type,type)+" боеприпасы");info["rank"]=Ammo.RARITY_NAMES[clampi(info.tier,0,3)]
			info.icon=UiKit.trimmed(UiKit.icon_texture("ammo/"+type if IconKit.has("ammo/"+type) else "stats/damage"))
			info.summary=AMMO_EFFECT.get(type,"")
			# Compared with the same ammo already loaded; another type has nothing to compare with.
			var loaded={}
			if not equipped and is_instance_valid(arena) and arena.run!=null:
				for slot in arena.run.ammo_slots:
					if slot is Dictionary and str(slot.type)==type:loaded=slot
			for spec in Ammo.STATS.get(type,[]):
				var value=float(item.get("stats",{}).get(spec[0],0.0))
				if is_zero_approx(value) and loaded.is_empty():continue
				var before=float(loaded.get("stats",{}).get(spec[0],0.0)) if not loaded.is_empty() else value
				info.rows.append([Texts.render(spec[1]),Ammo.value_text(spec,value),Ammo.value_text(spec,before) if not loaded.is_empty() else "",signi(roundi((value-before)*1000)) if not loaded.is_empty() else 0])
			if float(item.get("damage",0.0))>0:info.rows.append([Texts.render("Урон пули"),"+%d%%" % roundi(item.damage*100),"",0])
			if type=="ap":info.rows.append([Texts.render("Пробить щит"),"%d%%" % roundi(Ammo.shield_pierce(item)*100),"",0])
			if item.get("twist",false):info.note=Texts.render(Ammo.TWISTS.get(type,""))
			elif equipped:info.note="Заряжены"
			elif not loaded.is_empty():info.note="Сравнение с заряженными"
		"supply":
			info.title="Аптечка";info.icon=UiKit.trimmed(UiKit.icon_texture("heart"))
			info.summary="Лечит бойца сразу. H — использовать из рюкзака."
			info.rows.append([Texts.render("Лечение"),"+"+UiKit.number(snappedf(float(item.get("heal",1.0)),.1)),"",0])
			if is_instance_valid(arena) and arena.run!=null:info.rows.append([Texts.render("Здоровье"),"%s / %s" % [UiKit.number(snappedf(arena.run.soldier_hp,.1)),UiKit.number(snappedf(arena.run.soldier_max_hp,.1))],"",0])
		_:
			info.title=Game.recipe_name(item);info.tier=Game.TIERS.tier(str(item.get("id","")))
			var sheet=blueprint_key(item)
			info.icon=UiKit.trimmed(UiKit.icon_texture(sheet if IconKit.has(sheet) else "blueprint"))
			info.summary="Чертёж: донеси до хаба — откроется навсегда."
	return info
## Blueprint picture with its rarity chevron baked in (the chevron travels with the item): «blueprint/<cat>/<rarity>»,
## falling back to the plain «blueprint/<cat>».
static func blueprint_key(item:Dictionary)->String:
	var cat=str(item.get("category",""))
	var rarity=clampi(int(Game.recipe_catalog(cat).get(str(item.get("id","")),{}).get("rarity",0)),0,3) if cat!="" else 0
	var key="blueprint/%s/%d" % [cat,rarity]
	return key if IconKit.has(key) else "blueprint/"+cat
static func row(label:String,new:float,old:float,unit:String,same:bool)->Array:
	var text=func(v:float)->String:return UiKit.number(snappedf(v,.01))+unit
	# Equal as shown is equal: no arrow for a difference hidden by rounding.
	if same or text.call(new)==text.call(old):return [Texts.render(label),text.call(new),"",0]
	return [Texts.render(label),text.call(new),text.call(old),1 if new>old else -1]

## The card itself, `width` wide; the caller adds keys or buttons under it.
static func card(info:Dictionary,width:float)->VBoxContainer:
	var box=VBoxContainer.new();box.name="ItemCard";box.custom_minimum_size.x=width;box.add_theme_constant_override("separation",4);box.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var head=HBoxContainer.new();box.add_child(head);head.add_theme_constant_override("separation",10);head.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var pic=TextureRect.new();head.add_child(pic);pic.texture=info.icon;pic.custom_minimum_size=Vector2(48,48);pic.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;pic.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;pic.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var names=VBoxContainer.new();head.add_child(names);names.size_flags_horizontal=Control.SIZE_EXPAND_FILL;names.add_theme_constant_override("separation",0);names.alignment=BoxContainer.ALIGNMENT_CENTER
	var tier=clampi(int(info.tier),0,3);var color=Color(LootCatalog.RARITY_COLORS[tier])
	var title=Label.new();names.add_child(title);Texts.set_text(title,str(info.title));title.add_theme_font_size_override("font_size",16);title.add_theme_color_override("font_color",color.lightened(.2) if tier>0 else UiKit.INK);title.clip_text=true
	var rank=Label.new();names.add_child(rank);Texts.set_text(rank,str(info.get("rank",LootCatalog.RARITY_NAMES[tier])));rank.add_theme_font_size_override("font_size",11);rank.add_theme_color_override("font_color",color if tier>0 else UiKit.MUTED)
	if str(info.summary)!="":
		var line=Label.new();box.add_child(line);Texts.set_text(line,str(info.summary));line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;line.custom_minimum_size.x=width;line.add_theme_font_size_override("font_size",12);line.add_theme_color_override("font_color",UiKit.MUTED)
	if not info.rows.is_empty():box.add_child(compare_grid(info.rows))
	if str(info.note)!="":
		var note=Label.new();box.add_child(note);Texts.set_text(note,str(info.note));note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;note.custom_minimum_size.x=width;note.add_theme_font_size_override("font_size",11);note.add_theme_color_override("font_color",UiKit.ORANGE)
	return box
## Comparison rows in four aligned columns (T-200): parameter · was · arrow · now. The arrow column keeps its
## width when a value is unchanged or has nothing to compare with, so the numbers stand in one line.
const BETTER:=Color("8fe895")
const WORSE:=Color("e0806b")
const WAS:=Color("8d9589")
const ARROW_W:=18.0
static func compare_grid(rows:Array)->GridContainer:
	var grid=GridContainer.new();grid.name="Compare";grid.columns=4;grid.mouse_filter=Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation",6);grid.add_theme_constant_override("v_separation",2)
	for r in rows:
		var sign=int(r[3]);var was=str(r[2])
		var color=BETTER if sign>0 else WORSE if sign<0 else UiKit.INK
		var name=cell_label(grid,str(r[0]),UiKit.MUTED,HORIZONTAL_ALIGNMENT_LEFT);name.size_flags_horizontal=Control.SIZE_EXPAND_FILL;name.name="Param"
		cell_label(grid,was if sign!=0 else "",WAS,HORIZONTAL_ALIGNMENT_RIGHT).name="Was"
		var arrow=cell_label(grid,"▲" if sign>0 else "▼" if sign<0 else "",color,HORIZONTAL_ALIGNMENT_CENTER);arrow.custom_minimum_size.x=ARROW_W;arrow.name="Arrow"
		cell_label(grid,str(r[1]),color,HORIZONTAL_ALIGNMENT_RIGHT).name="Now"
	return grid
static func cell_label(parent:Control,text:String,color:Color,align:HorizontalAlignment)->Label:
	var label=Label.new();parent.add_child(label);label.text=text;label.horizontal_alignment=align;label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font",UiKit.field_font());label.add_theme_font_size_override("font_size",12);label.add_theme_color_override("font_color",color)
	return label
## A ready tooltip panel around the card (custom tooltips in the gear page).
static func tooltip(info:Dictionary,width:=260.0)->Control:
	var panel=PanelContainer.new();var style=UiKit.style(Color("1d2420"),10,Color(1,1,1,.14));style.content_margin_left=12;style.content_margin_right=12;style.content_margin_top=10;style.content_margin_bottom=10
	panel.add_theme_stylebox_override("panel",style);panel.add_child(card(info,width));return panel
