extends Control
## Barracks → «Классы» (author's layout, 2026-10-03: T-204, T-208, T-211, T-220). The Barracks' main tabs run along
## the top (StationScreen with tabs_on_top); this page puts the class list on the left — vertical, scrolling down
## to the last class in development, «Все классы» at its end — and on the right the class, big and pinned:
## portrait, name and one-line role, level N of 20 with a bar and the next price, the four key stats as large bars,
## the two ability cells. Under it a short path strip like «Развитие заставы»: what opens at which level, the
## upgrade button, the total to the next ability and «Выбрать». A locked class shows «Как открыть» with progress
## instead. The detailed 20-level path stays behind «Все уровни»; the long description is a hint on the portrait.
const STATS=preload("res://scripts/ui/stat_snapshot.gd")
var screen  # StationScreen: rebuild, notice, close
var viewed:=""
var slot_focus:=0
var ability_area:=Rect2()
const LIST_W:=212.0
const GAP:=16.0
const HERO_H:=236.0
const ITEM_H:=58.0

func setup(owner,area:Vector2):
	screen=owner;size=area
	if viewed=="":viewed=screen.selected if screen.selected in ClassCatalog.ROSTER or str(screen.selected).begins_with("concept_") else Game.selected_class
	slot_focus=int(screen.get_meta("slot_focus",0))
	build()

func build():
	for child in get_children():child.queue_free()
	class_list()
	var x=LIST_W+GAP;var w=size.x-x
	if viewed.begins_with("concept_"):concept_view(Vector2(x,0),Vector2(w,size.y));return
	hero(Vector2(x,0),Vector2(w,HERO_H))
	var y=HERO_H+12
	if viewed in Game.class_unlocks:path_strip(Vector2(x,y),Vector2(w,size.y-y))
	else:unlock_panel(Vector2(x,y),Vector2(w,size.y-y))
	if is_instance_valid(screen) and screen.has_meta("class_just_reached"):screen.remove_meta("class_just_reached")

## The class list (T-220): playable classes, then «В разработке», then «Все классы»; scrolls to the last one and
## keeps the viewed class in sight.
func class_list():
	var scroll=ScrollContainer.new();add_child(scroll);scroll.name="ClassList";scroll.position=Vector2.ZERO;scroll.size=Vector2(LIST_W,size.y)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	var column=Control.new();scroll.add_child(column)
	var w=LIST_W-14;var y=0.0;var viewed_y=0.0
	for id in all_ids():
		if id=="concept_0":
			UiKit.label(column,"В разработке",Vector2(4,y+6),Vector2(w-4,22),13,UiKit.MUTED).name="ConceptsHeader";y+=32
		if id==viewed:viewed_y=y
		class_tab(column,id,Vector2(0,y),Vector2(w,ITEM_H));y+=ITEM_H+6
	var all=UiKit.button(column,"Все классы",Vector2(0,y+4),Vector2(w,44),open_roster);all.name="AllClasses";all.add_theme_font_size_override("font_size",15);all.tooltip_text=Texts.localized("Все классы на одном экране")
	column.custom_minimum_size=Vector2(w,y+52)
	scroll.set_deferred("scroll_vertical",int(maxf(0,viewed_y-(size.y-ITEM_H)*.5)))
	if is_instance_valid(screen) and screen.station_kind!="" and viewed in ClassCatalog.ROSTER:preload("res://scripts/ui/station_notices.gd").mark_item_seen(screen.station_kind,"shells",viewed)
static func all_ids()->Array:
	var ids=ClassCatalog.ROSTER.duplicate()
	for i in range(ClassCatalog.CONCEPTS.size()):ids.append("concept_%d" % i)
	return ids
## One class button (list and «Все классы»): doll, name, level or unlock progress, the green «new» lamp.
func class_tab(parent:Control,id:String,pos:Vector2,dims:Vector2)->Button:
	var concept=id.begins_with("concept_");var owned=id in Game.class_unlocks;var chosen=id==viewed
	var b=Button.new();parent.add_child(b);b.position=pos;b.size=dims;b.name="Class_"+id;b.focus_mode=Control.FOCUS_ALL
	var style=UiKit.style(Color("2c352e") if owned else Color("1e2420") if concept else Color("232a25"),12,UiKit.ORANGE if chosen else Color(1,1,1,.08));style.set_border_width_all(3 if chosen else 1)
	for state in ["normal","hover","pressed","focus"]:b.add_theme_stylebox_override(state,style)
	var shell=id
	b.pressed.connect(func():pick(shell))
	var art_h=dims.y-12;var art_w=roundf(art_h*.9)
	var art=TextureRect.new();b.add_child(art);art.texture=preload("res://scripts/ui/class_gallery.gd").texture("recruit" if concept else id,true);art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;art.position=Vector2(6,6);art.size=Vector2(art_w,art_h);art.mouse_filter=Control.MOUSE_FILTER_IGNORE;art.flip_h=preload("res://scripts/ui/gear_page.gd").DOLL_FACES_LEFT
	UiKit.locked_preview(art,not owned)
	var tx=art_w+14;var lamp=26.0
	var title=UiKit.label(b,class_name_of(id),Vector2(tx,dims.y*.5-21),Vector2(dims.x-tx-lamp,22),15,UiKit.INK if owned else UiKit.MUTED);title.mouse_filter=Control.MOUSE_FILTER_IGNORE;title.clip_text=true
	var sub=UiKit.label(b,caption_of(id),Vector2(tx,dims.y*.5+2),Vector2(dims.x-tx-8,18),12,UiKit.ORANGE if id==Game.selected_class else UiKit.MUTED);sub.mouse_filter=Control.MOUSE_FILTER_IGNORE;sub.clip_text=true
	# A class that just became available carries a green lamp until it is viewed once (T-219).
	if not concept and not owned and not chosen and Game.can_select_class(id) and preload("res://scripts/ui/station_notices.gd").is_new("fighter","shells",id):UiKit.badge(b,"ready")
	return b
func pick(id:String):
	screen.selected=id;screen.notice="";viewed=id;screen.build()
static func class_name_of(id:String)->String:
	if id.begins_with("concept_"):return str(ClassCatalog.CONCEPTS[int(id.trim_prefix("concept_"))][0])
	return Game.CLASSES[id].name
static func caption_of(id:String)->String:
	if id.begins_with("concept_"):return "в разработке"
	var p=ClassCatalog.progress(id)
	if id in Game.class_unlocks:return "Выбран · ур. %d" % ClassCatalog.level(id) if id==Game.selected_class else "ур. %d" % ClassCatalog.level(id)
	return "можно открыть" if Game.can_select_class(id) else "%d / %d" % [p[0],p[1]]

## Every class on one screen: playable ones first, then the ones in development; a tap opens the class.
func open_roster():
	var o=overlay("ClassRoster")
	var w=minf(980.0,o.size.x-40);var h=minf(640.0,o.size.y-40)
	var panel=UiKit.glass(o,((o.size-Vector2(w,h))*.5).round(),Vector2(w,h))
	UiKit.accent(UiKit.label(panel,"Все классы",Vector2(22,14),Vector2(w-100,36),22))
	UiKit.button(panel,"×",Vector2(w-62,14),Vector2(46,42),o.queue_free).name="Close"
	var scroll=ScrollContainer.new();panel.add_child(scroll);scroll.position=Vector2(16,64);scroll.size=Vector2(w-32,h-80);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	var grid=GridContainer.new();scroll.add_child(grid);var cols=maxi(2,int((w-32)/204.0));grid.columns=cols
	grid.add_theme_constant_override("h_separation",10);grid.add_theme_constant_override("v_separation",10)
	var cell=Vector2(floorf((w-32-14-(cols-1)*10)/cols),76)
	for id in all_ids():
		var holder=Control.new();grid.add_child(holder);holder.custom_minimum_size=cell
		var b=class_tab(holder,id,Vector2.ZERO,cell);b.name="Roster_"+id
		var shell=id
		for c in b.pressed.get_connections():b.pressed.disconnect(c.callable)
		b.pressed.connect(func():o.queue_free();pick(shell))
	# A tap on the dimmed background closes it.
	o.get_child(0).mouse_filter=Control.MOUSE_FILTER_STOP
	o.get_child(0).gui_input.connect(func(e):if e is InputEventMouseButton and e.pressed:o.queue_free())

## A class in development: the sketch — role, numbers, the abilities it would get. Nothing to buy yet.
func concept_view(pos:Vector2,area:Vector2):
	var concept=ClassCatalog.CONCEPTS[int(viewed.trim_prefix("concept_"))]
	var back=UiKit.panel(self,pos,area,Color(1,1,1,.04));back.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var frame=UiKit.panel(self,pos+Vector2(12,12),Vector2(170,212),Color(1,1,1,.04))
	var doll=TextureRect.new();frame.add_child(doll);doll.texture=preload("res://scripts/ui/class_gallery.gd").texture("recruit",true);doll.flip_h=preload("res://scripts/ui/gear_page.gd").DOLL_FACES_LEFT;doll.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;doll.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;doll.position=Vector2(8,8);doll.size=frame.size-Vector2(16,16)
	UiKit.locked_preview(doll,true)
	var x=pos.x+206;var w=area.x-206-16
	UiKit.accent(UiKit.label(self,str(concept[0]),Vector2(x,pos.y+14),Vector2(w,40),28))
	UiKit.label(self,"«%s» · в разработке" % concept[1],Vector2(x,pos.y+54),Vector2(w,22),15,UiKit.MUTED)
	UiKit.label(self,"Характеристики",Vector2(x,pos.y+100),Vector2(w,24),16,UiKit.MUTED)
	UiKit.label(self,str(concept[2]),Vector2(x,pos.y+126),Vector2(w,26),18,UiKit.INK).name="ConceptStats"
	UiKit.label(self,"Способности",Vector2(x,pos.y+170),Vector2(w,24),16,UiKit.MUTED)
	UiKit.label(self,str(concept[3]),Vector2(x,pos.y+196),Vector2(w,26),18,UiKit.INK)
	var note=UiKit.label(self,"Класс ещё в работе: цифры и способности — набросок, могут поменяться.",Vector2(pos.x+16,pos.y+250),Vector2(area.x-32,48),15,UiKit.MUTED);note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var soon=UiKit.button(self,"В разработке",pos+Vector2(area.x-252,area.y-64),Vector2(236,48),func():pass);soon.disabled=true;soon.name="Take";UiKit.muted_locked_button(soon)

## The class, big and pinned (T-204): portrait (the long description is its hint), name and role, the level with a
## bar and the next price, the four key stats as large bars, the class's own stats in one line, two ability cells.
func hero(pos:Vector2,area:Vector2):
	var id=viewed;var owned=id in Game.class_unlocks;var level=ClassCatalog.level(id)
	var back=UiKit.panel(self,pos,area,Color(1,1,1,.04));back.name="Hero";back.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var frame=UiKit.panel(self,pos+Vector2(12,12),Vector2(150,area.y-24),Color(1,1,1,.04));frame.name="Portrait";frame.mouse_filter=Control.MOUSE_FILTER_PASS
	var bio:Array=ClassCatalog.BIO.get(id,["","",""])
	frame.tooltip_text="%s\n\n+ %s\n− %s" % [Texts.localized(bio[0]),Texts.localized(bio[1]),Texts.localized(bio[2])]
	# The full-body doll, facing right like every doll in the interface (author).
	var portrait=TextureRect.new();frame.add_child(portrait);portrait.name="Doll";portrait.texture=preload("res://scripts/ui/class_gallery.gd").texture(id,true);portrait.flip_h=preload("res://scripts/ui/gear_page.gd").DOLL_FACES_LEFT;portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.position=Vector2(8,8);portrait.size=frame.size-Vector2(16,16);portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
	UiKit.locked_preview(portrait,not owned)
	const ABIL_W:=236.0
	var x=pos.x+178;var w=area.x-178-ABIL_W-28
	var name_label=UiKit.label(self,Game.CLASSES[id].name,Vector2(x,pos.y+8),Vector2(w,36),26);UiKit.accent(name_label);name_label.name="ClassName"
	UiKit.label(self,ClassCatalog.info(id).role,Vector2(x,pos.y+44),Vector2(w,20),15,UiKit.MUTED).name="Role"
	var extra=UiKit.label(self,own_stats_line(id),Vector2(x,pos.y+66),Vector2(w,18),13,Color("8fe895"));extra.name="OwnStats"
	# Level: «Уровень N из 20», the next price on the right, a bar of the whole path.
	var ly=pos.y+92
	if owned:
		UiKit.label(self,"Уровень %d из %d" % [level,ClassCatalog.MAX_LEVEL],Vector2(x,ly),Vector2(w*.5,22),16).name="LevelText"
		var cost=Game.class_upgrade_cost(id,false)
		var next=UiKit.label(self,("Следующий · %d ◈" % cost) if cost>0 else "Максимум",Vector2(x+w*.5,ly),Vector2(w*.5,22),15,UiKit.INK if cost>0 and Game.credits>=cost else UiKit.MUTED);next.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;next.name="NextCost"
		var track=Panel.new();add_child(track);track.name="LevelBar";track.mouse_filter=Control.MOUSE_FILTER_IGNORE;track.position=Vector2(x,ly+26);track.size=Vector2(w,10);track.add_theme_stylebox_override("panel",bar_style(Color(1,1,1,.08),5))
		var fill=Panel.new();track.add_child(fill);fill.mouse_filter=Control.MOUSE_FILTER_IGNORE;fill.size=Vector2(maxf(10,w*float(level)/ClassCatalog.MAX_LEVEL),10);fill.add_theme_stylebox_override("panel",bar_style(Color("8fe895"),5))
	else:
		UiKit.label(self,"Класс ещё не открыт",Vector2(x,ly),Vector2(w,22),16,UiKit.ORANGE).name="LevelText"
	# Four key stats as large bars, two columns; the scale is the best class in the roster.
	var rows=class_rows(id).slice(0,4);var best=key_stat_max()
	var col=(w-20)*.5
	for k in range(rows.size()):
		var cx=x+(k%2)*(col+20);var cy=pos.y+142+floori(k/2.0)*46
		UiKit.label(self,str(rows[k].title),Vector2(cx,cy),Vector2(col-90,20),14,UiKit.MUTED)
		var v=UiKit.label(self,UiKit.number(snappedf(float(rows[k].current),.01))+str(rows[k].unit),Vector2(cx+col-90,cy),Vector2(90,20),16);v.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		var track=Panel.new();add_child(track);track.name="Stat_%d" % k;track.mouse_filter=Control.MOUSE_FILTER_IGNORE;track.position=Vector2(cx,cy+24);track.size=Vector2(col,10);track.add_theme_stylebox_override("panel",bar_style(Color(1,1,1,.08),5))
		var share=clampf(float(rows[k].current)/maxf(.001,float(best[k])*1.1),.06,1.0)
		var fill=Panel.new();track.add_child(fill);fill.mouse_filter=Control.MOUSE_FILTER_IGNORE;fill.size=Vector2(col*share,10);fill.add_theme_stylebox_override("panel",bar_style(Color(UiKit.INK,.78) if owned else Color(UiKit.MUTED,.55),5))
	abilities_cells(Vector2(pos.x+area.x-ABIL_W-12,pos.y),Vector2(ABIL_W,area.y))

## The class's own numbers (start bonus + level growth) in one line: «Шанс крита 5,4% · Крит-урон 152%».
static func own_stats_line(id:String)->String:
	var parts=[]
	for row in class_rows(id).slice(4):
		if is_equal_approx(float(row.current),float(row.base)):continue  # nothing yet (a growth stat at level 1)
		parts.append("%s %s%s" % [row.title,UiKit.number(snappedf(float(row.current),.1)),row.unit])
	return " · ".join(parts)
## The best value of each key stat across the roster: the bars compare classes, not a fixed scale.
static func key_stat_max()->Array:
	var best=[0.0,0.0,0.0,0.0]
	for id in ClassCatalog.ROSTER:
		var rows=class_rows(id)
		for k in range(4):best[k]=maxf(best[k],float(rows[k].current))
	return best

## The numbers this class starts a run with: the four base ones plus its own stats (class bonus + level growth),
## each bar from the plain start value to the class value.
static func class_rows(id:String)->Array:
	var s=CombatStats.shell_preview(id)
	var rows=[STATS.row("Здоровье",s.health,s.health),STATS.row("Урон",s.damage,s.damage),STATS.row("Скорость",s.speed,s.speed," м/с"),STATS.row("Напор",s.pressure,s.pressure,"%")]
	var extra={}
	for m in ClassCatalog.info(id).modifiers:
		if str(m.get("op","add"))=="add":extra[m.stat]=float(extra.get(m.stat,0.0))+float(m.value)
	for g in ClassCatalog.growth(id):extra[g[0]]=float(extra.get(g[0],0.0))+float(g[1])
	for def in StatRegistry.all():
		if not extra.has(def.run_field) or def.run_field=="soldier_max_hp":continue
		var base=StatRegistry.base_value(def)
		var mult=100.0 if def.format=="percent" else 1.0
		rows.append(STATS.row(def.title,base*mult,(base+float(extra[def.run_field]))*mult,"%" if def.format=="percent" else ""))
	return rows

## Two slot cells (an ability, an empty slot with a yellow «+», or locked «С N уровня»), the name under each and
## one short line; the ability's full text is the cell's hint. A tap on an open cell opens the ability list.
func abilities_cells(pos:Vector2,area:Vector2):
	var id=viewed;var owned=id in Game.class_unlocks
	ability_area=Rect2(pos+Vector2(0,6),area)
	UiKit.label(self,"Способности",pos+Vector2(0,10),Vector2(area.x,24),16)
	var layout=Game.class_slot_layout(id) if owned else []
	slot_focus=clampi(slot_focus,0,1)
	var gap=16.0;var cell=(area.x-gap)*.5;var top=40.0
	var abilities=ClassCatalog.abilities(id)
	for slot in range(2):
		var x=pos.x+slot*(cell+gap)
		var b=Button.new();add_child(b);b.position=Vector2(x,pos.y+top);b.size=Vector2(cell,cell);b.name="Slot_%d" % slot;b.focus_mode=Control.FOCUS_ALL
		var open=slot<layout.size();var filled=open and layout[slot]!=""
		var focused=slot==slot_focus and open
		var style=UiKit.style(Color("2c352e") if open else Color("232a25"),14,UiKit.ORANGE if focused else Color(1,1,1,.1));style.set_border_width_all(2 if focused else 1)
		for state in ["normal","hover","pressed","focus"]:b.add_theme_stylebox_override(state,style)
		var at=slot
		if owned and open:b.pressed.connect(func():slot_focus=at;screen.set_meta("slot_focus",at);build();open_popup(at))
		if filled:UiKit.icon(b,"abilities/"+str(layout[slot]),Vector2(cell*.18,cell*.12),Vector2(cell*.64,cell*.64))
		elif open:plus_mark(b,Vector2(cell*.3,cell*.26),cell*.4)
		else:UiKit.icon(b,"lock",Vector2(cell*.3,cell*.26),Vector2(cell*.4,cell*.4)).modulate=Color(1,1,1,.45)
		var key=UiKit.label(b,"Q" if slot==0 else "1",Vector2(10,cell-26),Vector2(30,20),13,UiKit.ORANGE);key.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var title="";var body=""
		if filled:
			var info=AbilityCatalog.DATA[str(layout[slot])];title=info.name;body="Нажми, чтобы сменить";b.tooltip_text=Texts.localized(str(info.get("description","")))
		elif open:title="Пусто";body="Нажми, чтобы взять"
		else:
			var lv=ClassCatalog.ABILITY_LEVELS[slot];title="С %d уровня" % lv
			body=AbilityCatalog.DATA[abilities[0]].name if slot==0 and abilities.size()>0 else "Второй слот"
		var name_label=UiKit.label(self,title,Vector2(x,pos.y+top+cell+8),Vector2(cell,20),14,UiKit.INK if filled else UiKit.MUTED);name_label.clip_text=true;name_label.name="SlotTitle_%d" % slot
		var desc=UiKit.label(self,body,Vector2(x,pos.y+top+cell+28),Vector2(cell,36),12,UiKit.MUTED);desc.name="SlotText_%d" % slot
		desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;desc.vertical_alignment=VERTICAL_ALIGNMENT_TOP;desc.clip_text=true

## The path strip (T-204, like «Развитие заставы»): one node per milestone — level above, what it gives below —
## a rail filled up to the current level, the upgrade button, the total to the next ability (T-211), «Выбрать».
func path_strip(pos:Vector2,area:Vector2):
	var id=viewed;var level=ClassCatalog.level(id)
	var back=UiKit.panel(self,pos,area,Color(1,1,1,.04));back.name="PathStrip";back.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var head=UiKit.label(self,"Путь класса",pos+Vector2(16,12),Vector2(300,24),16)
	var head_w=head.get_theme_font("font").get_string_size(Texts.render("Путь класса"),HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
	var more=UiKit.button(self,"Все уровни",pos+Vector2(16+head_w+16,8),Vector2(140,30),open_path);more.name="ClassPath";more.add_theme_font_size_override("font_size",14);more.tooltip_text=Texts.localized("Все 20 уровней с ростом характеристик")
	var marks=ClassCatalog.TRACK.keys();marks.sort()
	var left=pos.x+64.0;var right=pos.x+area.x-64.0;var step=(right-left)/(marks.size()-1)
	var cy=pos.y+84.0;var start=pos.x+20.0
	# The rail starts at level 1 (left edge) and is green up to the current level.
	var rail=Panel.new();add_child(rail);rail.name="PathRail";rail.mouse_filter=Control.MOUSE_FILTER_IGNORE;rail.position=Vector2(start,cy-3);rail.size=Vector2(right-start,6);rail.add_theme_stylebox_override("panel",bar_style(Color(1,1,1,.08),3))
	var reach=start+(left-start)*clampf((level-1)/float(marks[0]-1),0,1)
	for i in range(marks.size()-1):
		if level>=marks[i]:reach=left+step*i+step*clampf(float(level-marks[i])/(marks[i+1]-marks[i]),0,1)
	if level>1:
		var fill=Panel.new();add_child(fill);fill.name="PathFill";fill.mouse_filter=Control.MOUSE_FILTER_IGNORE;fill.position=rail.position;fill.size=Vector2(reach-start,6);fill.add_theme_stylebox_override("panel",bar_style(Color("8fe895"),3))
	var goal_set=false;var just=int(screen.get_meta("class_just_reached",0)) if is_instance_valid(screen) else 0
	for i in range(marks.size()):
		var n=int(marks[i]);var x=left+step*i
		var status="done" if level>=n else "later"
		if status=="later" and not goal_set:status="goal";goal_set=true
		var spec=milestone(id,n)
		var hint=Control.new();add_child(hint);hint.name="Mark_%d" % n;hint.position=Vector2(x-step*.5+4,pos.y+44);hint.size=Vector2(step-8,area.y-44-70);hint.mouse_filter=Control.MOUSE_FILTER_PASS;hint.tooltip_text=Texts.localized(spec[2])
		var lv=UiKit.label(self,"Ур. %d" % n,Vector2(x-40,cy-38),Vector2(80,18),13,UiKit.ORANGE if status=="goal" else UiKit.INK if status=="done" else UiKit.MUTED);lv.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;lv.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var node=preload("res://scripts/ui/track_node.gd").new();node.name="Node_%d" % n;node.status=status;node.milestone=true;node.size=Vector2(40,40);node.position=Vector2(x-20,cy-20)
		node.icon=UiKit.trimmed(UiKit.icon_texture(spec[3]))
		if status=="goal":node.progress=float(Game.credits)/maxf(1.0,total_to(id,n))
		add_child(node)
		if n==just:node.celebrate.call_deferred()
		var kind=UiKit.label(self,spec[0],Vector2(x-step*.5+4,cy+24),Vector2(step-8,16),12,UiKit.MUTED);kind.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;kind.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var what=UiKit.label(self,spec[1],Vector2(x-step*.5+4,cy+40),Vector2(step-8,50),12,UiKit.INK if status!="later" else Color(UiKit.INK,.6));what.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;what.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;what.vertical_alignment=VERTICAL_ALIGNMENT_TOP;what.mouse_filter=Control.MOUSE_FILTER_IGNORE;what.name="MarkName_%d" % n
	# Bottom row: the next level, the total to the next ability, «Выбрать».
	var by=pos.y+area.y-56;var cost=Game.class_upgrade_cost(id,false)
	var up
	if cost<0:
		up=UiKit.button(self,"Путь класса пройден",Vector2(pos.x+16,by),Vector2(300,44),func():pass);up.disabled=true
	elif Game.credits>=cost:
		up=UiKit.button(self,"Улучшить до %d ур. · %d ◈" % [level+1,cost],Vector2(pos.x+16,by),Vector2(300,44),level_up,true)
	else:
		up=UiKit.button(self,"Ур. %d · не хватает %d ◈" % [level+1,cost-Game.credits],Vector2(pos.x+16,by),Vector2(300,44),func():pass);up.disabled=true
	up.name="LevelUp";up.add_theme_font_size_override("font_size",17);UiKit.muted_locked_button(up)
	var target=total_target(level)
	if target>0:
		var sum=UiKit.label(self,"Всего до %d ур.: %d ◈" % [target,total_to(id,target)],Vector2(pos.x+332,by+2),Vector2(area.x-332-268,22),15,UiKit.MUTED);sum.name="TotalCost"
		sum.tooltip_text=Texts.localized("Сколько сплава нужно на все уровни до следующей способности");sum.mouse_filter=Control.MOUSE_FILTER_PASS
	if is_instance_valid(screen) and screen.notice!="":
		UiKit.label(self,screen.notice,Vector2(pos.x+332,by+26),Vector2(area.x-332-268,20),14,Color("8fe895")).name="Notice"
	take_button(Vector2(pos.x+area.x-252,by),Vector2(236,44))

## What a milestone gives: [kind, name, hint, icon].
static func milestone(id:String,n:int)->Array:
	var kind=str(ClassCatalog.TRACK[n][0]);var abilities=ClassCatalog.abilities(id);var index=ClassCatalog.ABILITY_LEVELS.find(n)
	var perks=ClassCatalog.PERKS.get(id,[])
	match kind:
		"ability":
			if index>=0 and index<abilities.size():
				var info=AbilityCatalog.DATA[abilities[index]]
				return ["Второй слот" if n==ClassCatalog.ABILITY_LEVELS[1] else "Способность",info.name,"%s. %s" % [info.name,info.get("description","")],"abilities/"+str(abilities[index])]
			return ["Способность","В разработке",ClassCatalog.track_title(n),"lock"]
		"perk":return ["Перк",perks[0][0] if perks.size()>0 else "Перк",ClassCatalog.track_title(n),"rare"]
		"mastery":return ["Мастерство",perks[1][0] if perks.size()>1 else "Мастерство",ClassCatalog.track_title(n),"legendary"]
		"power":return ["Способность","Q сильнее",ClassCatalog.track_title(n),"star"]
	return ["Секрет","В разработке",ClassCatalog.track_title(n),"lock"]
## The level the «Всего до N ур.» line counts to (T-211): the next ability level past the very next level.
static func total_target(level:int)->int:
	for at in ClassCatalog.ABILITY_LEVELS:
		if at>level+1:return at
	return 0
## Alloy for every level from the current one up to `target` (the same ladder as Game.class_upgrade_cost).
static func total_to(id:String,target:int)->int:
	var total=0
	for stored in range(int(Game.class_levels.get(id,0)),target-1):total+=maxi(0,Game.class_step_cost(stored))
	return total

## A locked class (T-208): what to do to open it, big, with progress; nothing cut off.
func unlock_panel(pos:Vector2,area:Vector2):
	var id=viewed;var unlock=ClassCatalog.info(id).unlock;var p=ClassCatalog.progress(id);var ready=Game.can_select_class(id)
	var back=UiKit.panel(self,pos,area,Color(1,1,1,.04));back.name="UnlockPanel";back.mouse_filter=Control.MOUSE_FILTER_IGNORE
	UiKit.label(self,"Как открыть",pos+Vector2(20,16),Vector2(area.x-40,22),16,UiKit.MUTED)
	var goal=UiKit.label(self,str(unlock.get("text","")),pos+Vector2(20,44),Vector2(area.x-40,40),26,UiKit.INK);goal.name="UnlockText";goal.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	# The goal is as tall as its text (two lines in a long translation); the bar follows it.
	goal.size.y=preload("res://scripts/ui/station_screen.gd").wrapped_height(goal,area.x-40,26)
	var by=pos.y+44+goal.size.y+14
	var bar_w=area.x-40-120
	var track=Panel.new();add_child(track);track.name="UnlockBar";track.mouse_filter=Control.MOUSE_FILTER_IGNORE;track.position=Vector2(pos.x+20,by+8);track.size=Vector2(bar_w,14);track.add_theme_stylebox_override("panel",bar_style(Color(1,1,1,.08),7))
	var share=clampf(float(p[0])/maxf(1.0,float(p[1])),0,1)
	if share>0:
		var fill=Panel.new();track.add_child(fill);fill.mouse_filter=Control.MOUSE_FILTER_IGNORE;fill.size=Vector2(maxf(14,bar_w*share),14);fill.add_theme_stylebox_override("panel",bar_style(Color("8fe895") if ready else UiKit.ORANGE,7))
	var count=UiKit.label(self,"%d / %d" % [p[0],p[1]],Vector2(pos.x+area.x-128,by),Vector2(108,28),22,Color("8fe895") if ready else UiKit.INK);count.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;count.name="UnlockCount"
	var note=UiKit.label(self,"Условие выполнено — класс можно открыть." if ready else "Открытие бесплатное: выполни условие в вылазке, и класс станет доступен здесь.",Vector2(pos.x+20,by+36),Vector2(area.x-40,40),15,Color("8fe895") if ready else UiKit.MUTED);note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;note.name="UnlockNote"
	var more=UiKit.button(self,"Все уровни",pos+Vector2(16,area.y-62),Vector2(200,48),open_path);more.name="ClassPath";more.add_theme_font_size_override("font_size",16);more.tooltip_text=Texts.localized("Все 20 уровней с ростом характеристик")
	take_button(pos+Vector2(area.x-252,area.y-62),Vector2(236,48))

## «Выбран» / «Выбрать» / «Открыть и выбрать» / «Закрыто».
func take_button(pos:Vector2,dims:Vector2)->Button:
	var id=viewed;var owned=id in Game.class_unlocks;var take
	if id==Game.selected_class:
		take=UiKit.button(self,"Выбран",pos,dims,func():pass);take.disabled=true;UiKit.muted_locked_button(take)
	elif owned or Game.can_select_class(id):
		take=UiKit.button(self,"Выбрать" if owned else "Открыть и выбрать",pos,dims,choose,true)
	else:
		take=UiKit.button(self,"Закрыто",pos,dims,func():pass);take.disabled=true;UiKit.muted_locked_button(take)
	take.name="Take";take.add_theme_font_size_override("font_size",20)
	return take

## The next level right from the page; it rebuilds at once (abilities, path, prices).
func level_up():
	var level=ClassCatalog.level(viewed)
	if not Game.upgrade_class(viewed,false):return
	Game.sound("upgrade",self);screen.set_meta("class_just_reached",level+1)
	screen.notice="Уровень %d" % (level+1);screen.selected=viewed;screen.changed.emit();screen.build()

## A yellow outlined square with «+»: an empty slot, or «put this ability in».
static func plus_mark(parent:Control,pos:Vector2,side:float)->Panel:
	var box=Panel.new();parent.add_child(box);box.position=pos;box.size=Vector2(side,side);box.mouse_filter=Control.MOUSE_FILTER_IGNORE;box.name="Plus"
	var frame=StyleBoxFlat.new();frame.bg_color=Color(UiKit.ORANGE,.08);frame.border_color=UiKit.ORANGE;frame.set_border_width_all(3);frame.set_corner_radius_all(10)
	box.add_theme_stylebox_override("panel",frame)
	for vertical in [false,true]:
		var bar=ColorRect.new();box.add_child(bar);bar.color=UiKit.ORANGE;bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var t=maxf(3.0,side*.07);var l=side*.46
		bar.size=Vector2(t,l) if vertical else Vector2(l,t);bar.position=(box.size-bar.size)*.5
	return box

## «Выбрать»: take the class and close the Barracks (author's sketch).
func choose():
	if not Game.select_class(viewed):return
	Game.sound("upgrade",self)
	screen.changed.emit();screen.closed.emit()

func overlay(name:String)->Control:
	var o=Control.new();o.name=name;add_child(o);o.set_as_top_level(true);o.position=Vector2.ZERO;o.size=get_viewport_rect().size;o.add_to_group("selection_scope")
	o.z_index=60  # above the station tab dots
	var dim=ColorRect.new();o.add_child(dim);dim.size=o.size;dim.color=Color(0,0,0,.6)
	return o

## Ability list for a slot (author's sketch): a panel beside the slots with a pointer to them, one row per ability
## of the class — picture, name, short text, numbers as bars — and on the right its state: a big yellow «+»
## (put it in), «В слоте» with «Убрать», «На N-м уровне», or a secret. No ×: a tap outside closes it.
func open_popup(slot:int):
	var id=viewed;var o=overlay("AbilityPopup")
	var dim=o.get_child(0);dim.color=Color(0,0,0,.35);dim.mouse_filter=Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(e):if e is InputEventMouseButton and e.pressed:o.queue_free())
	var all=ClassCatalog.abilities(id)+["secret"]
	const ROW=132.0
	# The page is scaled with the station (StationScreen.fit): the list takes the same scale and sits beside the
	# slots in screen space, so it lines up at any window size.
	var k=get_global_transform().get_scale().x
	var w=minf(560.0,ability_area.position.x-30);var h=minf(ROW*all.size()+64,size.y+40)
	var anchor=get_global_transform()*(ability_area.position+Vector2(0,34))
	var panel=UiKit.glass(o,Vector2.ZERO,Vector2(w,h));panel.name="List";panel.scale=Vector2(k,k)
	panel.position=Vector2(anchor.x-(w+18)*k,clampf(anchor.y-60*k,8,o.size.y-h*k-8))
	var notch=Panel.new();o.add_child(notch);notch.size=Vector2(22,22)*k;notch.pivot_offset=notch.size*.5;notch.rotation=PI*.25;notch.position=Vector2(anchor.x-30*k,anchor.y+((ability_area.size.x-12)*.25-11)*k);notch.mouse_filter=Control.MOUSE_FILTER_IGNORE
	notch.add_theme_stylebox_override("panel",bar_style(Color("2b332d"),3))
	UiKit.label(panel,"Выбери способность · слот %s" % ("Q" if slot==0 else "1"),Vector2(20,16),Vector2(w-40,28),18)
	var scroll=ScrollContainer.new();panel.add_child(scroll);scroll.position=Vector2(12,56);scroll.size=Vector2(w-24,h-66);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	var list=Control.new();scroll.add_child(list);list.custom_minimum_size=Vector2(w-36,ROW*all.size())
	var layout=Game.class_slot_layout(id);var open_list=ClassCatalog.unlocked_abilities(id)
	var max_power=0.0
	for a in ClassCatalog.abilities(id):max_power=maxf(max_power,float(AbilityCatalog.DATA[a].get("power",1.0)))
	for i in range(all.size()):
		var ability=str(all[i]);var y=i*ROW;var secret=ability=="secret"
		var need=ClassCatalog.ABILITY_LEVELS[i];var open=not secret and ability in open_list
		var here=open and slot<layout.size() and layout[slot]==ability
		var row=UiKit.panel(list,Vector2(0,y),Vector2(w-36,ROW-10),Color(1,1,1,.06) if open else Color(0,0,0,.12));row.name="Row_"+ability
		if here:
			var mark=StyleBoxFlat.new();mark.bg_color=Color("2a3a2e");mark.border_color=Color("8fe895");mark.set_border_width_all(2);mark.set_corner_radius_all(12);row.add_theme_stylebox_override("panel",mark)
		var pic=UiKit.panel(row,Vector2(10,10),Vector2(ROW-30,ROW-30),Color("1f2621"))
		UiKit.icon(pic,"abilities/"+ability if open else "lock",Vector2(12,12),pic.size-Vector2(24,24)).modulate=Color(1,1,1,1.0 if open else .7)
		var tx=ROW-6;var tw=row.size.x-tx-ROW-6
		if secret:
			UiKit.label(row,"???",Vector2(tx,12),Vector2(tw,26),18,UiKit.MUTED)
			UiKit.label(row,"Секретная способность класса · в разработке",Vector2(tx,42),Vector2(tw,36),13,UiKit.MUTED).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		else:
			var info=AbilityCatalog.DATA[ability]
			UiKit.label(row,info.name,Vector2(tx,10),Vector2(tw,24),17,UiKit.INK if open else UiKit.MUTED)
			var d=UiKit.label(row,info.get("description",""),Vector2(tx,34),Vector2(tw,34),12,UiKit.MUTED);d.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;d.clip_text=true
			# Numbers as bars: cooldown (shorter is better) and power against the class's strongest ability.
			var cd=float(info.get("cooldown",30.0));var pw=float(info.get("power",1.0))
			stat_bar(row,Vector2(tx,72),tw*.5-6,"Перезарядка","%s с" % UiKit.number(cd),clampf(1.0-cd/60.0,.08,1.0),open)
			stat_bar(row,Vector2(tx+tw*.5+6,72),tw*.5-6,"Сила",UiKit.number(pw),clampf(pw/maxf(1.0,max_power),.08,1.0),open)
		# State on the right.
		var ax=row.size.x-ROW+14;var side=ROW-38
		if here:
			UiKit.label(row,"✓ В слоте",Vector2(ax-10,14),Vector2(side+20,22),14,Color("8fe895")).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			var out=UiKit.button(row,"Убрать",Vector2(ax,48),Vector2(side,40),func():o.queue_free();act(Game.set_class_slot(id,slot,""),"Слот %s пуст" % ("Q" if slot==0 else "1")));out.name="Remove_"+ability
		elif open:
			var put=Button.new();row.add_child(put);put.position=Vector2(ax,(ROW-10-side)*.5);put.size=Vector2(side,side);put.name="Put_"+ability;put.focus_mode=Control.FOCUS_ALL
			put.tooltip_text=Texts.render("Взять в слот")
			for state in ["normal","hover","pressed","focus"]:put.add_theme_stylebox_override(state,StyleBoxEmpty.new())
			put.pressed.connect(func():o.queue_free();act(Game.set_class_slot(id,slot,ability),"Слот %s · %s" % ["Q" if slot==0 else "1",AbilityCatalog.DATA[ability].name]))
			plus_mark(put,Vector2.ZERO,side)
			UiKit.press_bounce(put)
		else:
			var lock=UiKit.panel(row,Vector2(ax-14,(ROW-10)*.5-24),Vector2(side+28,48),Color("1f2621"))
			var t=UiKit.label(lock,("Секрет · %d ур." if secret else "На %d-м уровне") % need,Vector2.ZERO,lock.size,13,UiKit.MUTED);t.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;t.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;t.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART

static func stat_bar(parent:Control,pos:Vector2,width:float,title:String,value:String,share:float,open:bool):
	UiKit.label(parent,title,pos,Vector2(width-50,16),11,UiKit.MUTED)
	var v=UiKit.label(parent,value,pos+Vector2(width-60,0),Vector2(60,16),11,UiKit.INK if open else UiKit.MUTED);v.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	var track=ColorRect.new();parent.add_child(track);track.position=pos+Vector2(0,20);track.size=Vector2(width,6);track.color=Color(1,1,1,.08);track.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var bar=ColorRect.new();track.add_child(bar);bar.size=Vector2(width*share,6);bar.color=UiKit.ORANGE if open else Color(1,1,1,.2);bar.mouse_filter=Control.MOUSE_FILTER_IGNORE

## The class path (author's draft, 0.8.0): a centre track from level 1 at the top down to 20, green up to the
## current level; level cards alternate left and right with a pointer to the track — title, a medium picture of
## the reward, the stat growth as small bars in two columns. Only the nearest level can be bought, by the
## button at the bottom of its card; the rest show their price. At the very bottom: «20+», locked.
func open_path():
	var id=viewed;var level=ClassCatalog.level(id);var owned=id in Game.class_unlocks;var o=overlay("ClassPathView")
	var w=minf(940.0,o.size.x-40);var h=minf(720.0,o.size.y-40)
	var panel=UiKit.glass(o,(o.size-Vector2(w,h))*.5,Vector2(w,h))
	UiKit.accent(UiKit.label(panel,"Путь класса · %s" % Game.CLASSES[id].name,Vector2(22,14),Vector2(w-100,36),22))
	UiKit.button(panel,"×",Vector2(w-62,14),Vector2(46,42),o.queue_free).name="Close"
	UiKit.label(panel,"Уровень %d из %d · каждый уровень: %s" % [level,ClassCatalog.MAX_LEVEL,ClassCatalog.growth_line(id)],Vector2(22,52),Vector2(w-44,20),13,UiKit.MUTED).clip_text=true
	var scroll=ScrollContainer.new();panel.add_child(scroll);scroll.position=Vector2(16,80);scroll.size=Vector2(w-32,h-96);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.name="PathScroll"
	var inner=scroll.size.x-14;var axis=inner*.5
	var card_w=minf(380.0,axis-46);const CARD_H=214.0;const STEP=130.0;const TOP=34.0
	var body=Control.new();scroll.add_child(body)
	var node_y=func(n:int)->float:return TOP+(n-1)*STEP+44
	var bottom=node_y.call(ClassCatalog.MAX_LEVEL)+CARD_H*.5+40
	body.custom_minimum_size=Vector2(inner,bottom+190)
	# The track: wide rounded bar, green from the top to the current level.
	var rail=Panel.new();body.add_child(rail);rail.mouse_filter=Control.MOUSE_FILTER_IGNORE;rail.position=Vector2(axis-8,node_y.call(1));rail.size=Vector2(16,bottom-node_y.call(1))
	rail.add_theme_stylebox_override("panel",bar_style(Color("1f2621"),8))
	if owned:
		var fill=Panel.new();body.add_child(fill);fill.mouse_filter=Control.MOUSE_FILTER_IGNORE;fill.name="TrackFill";fill.position=Vector2(axis-8,node_y.call(1)-8);fill.size=Vector2(16,node_y.call(level)-node_y.call(1)+16)
		fill.add_theme_stylebox_override("panel",bar_style(Color("8fe895"),8))
	var cost=Game.class_upgrade_cost(id,false)
	for n in range(1,ClassCatalog.MAX_LEVEL+1):
		var status="done" if owned and level>=n else ("goal" if owned and n==level+1 else "later")
		var left=n%2==0;var y=node_y.call(n)
		var node=preload("res://scripts/ui/track_node.gd").new();node.name="Node_%d" % n;node.status=status;node.milestone=ClassCatalog.TRACK.has(n)
		var side=30.0 if ClassCatalog.TRACK.has(n) else 22.0;node.size=Vector2(side,side);node.position=Vector2(axis-side*.5,y-side*.5)
		if status=="goal" and cost>0:node.progress=float(Game.credits)/cost
		body.add_child(node)
		if n==int(get_meta("just_reached",0)):node.celebrate.call_deferred()
		var x=axis-28-card_w if left else axis+28
		level_card(body,Vector2(x,y-46),Vector2(card_w,CARD_H),n,status,left,id,cost)
	# Capstone under the track's end.
	var cap=UiKit.panel(body,Vector2(axis-170,bottom+24),Vector2(340,150),Color("232a25"));cap.name="Level_20plus"
	var notch=Panel.new();body.add_child(notch);notch.position=Vector2(axis-10,bottom+16);notch.size=Vector2(20,20);notch.rotation=PI*.25;notch.pivot_offset=Vector2(10,10);notch.mouse_filter=Control.MOUSE_FILTER_IGNORE
	notch.add_theme_stylebox_override("panel",UiKit.style(Color("232a25"),2))
	var end=preload("res://scripts/ui/track_node.gd").new();end.size=Vector2(34,34);end.position=Vector2(axis-17,bottom-17);end.milestone=true;end.icon=UiKit.icon_texture("lock");body.add_child(end)
	var t=UiKit.label(cap,"20+ уровень",Vector2(0,14),Vector2(340,30),20);t.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var locked=UiKit.button(cap,"Недоступно",Vector2(70,56),Vector2(200,44),func():pass);locked.disabled=true;UiKit.muted_locked_button(locked)
	var why=UiKit.label(cap,"Пройди игру",Vector2(0,110),Vector2(340,22),14,UiKit.MUTED);why.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	scroll.set_deferred("scroll_vertical",int(maxf(0,node_y.call(mini(level+1,ClassCatalog.MAX_LEVEL))-scroll.size.y*.4)))

## One level card: a pointer to the track, title and state, a medium picture, growth bars in two columns,
## and for the nearest level the buy button at the bottom.
func level_card(body:Control,pos:Vector2,dims:Vector2,n:int,status:String,left:bool,id:String,cost:int):
	var key=ClassCatalog.TRACK.has(n);var kind=str(ClassCatalog.TRACK[n][0]) if key else "stub"
	var bg=Color("2a3a2e") if status=="done" else Color("3b3323") if status=="goal" else Color("232a25")
	var notch=Panel.new();body.add_child(notch);notch.mouse_filter=Control.MOUSE_FILTER_IGNORE;notch.size=Vector2(20,20);notch.pivot_offset=Vector2(10,10);notch.rotation=PI*.25
	notch.position=Vector2(pos.x+dims.x-12 if left else pos.x-8,pos.y+36);notch.add_theme_stylebox_override("panel",UiKit.style(bg,2))
	var card=UiKit.panel(body,pos,dims,bg);card.name="Level_%d" % n
	var border=UiKit.style(bg,16,UiKit.ORANGE if status=="goal" else Color(1,1,1,.06));border.set_border_width_all(2 if status=="goal" else 1);card.add_theme_stylebox_override("panel",border)
	# Picture: the reward of a milestone, otherwise the class's main growing stat.
	var abilities=ClassCatalog.abilities(id);var ability_index=ClassCatalog.ABILITY_LEVELS.find(n)
	var picture={"perk":"rare","power":"star","mastery":"legendary","secret":"lock"}.get(kind,"")
	if kind=="ability" and ability_index>=0 and ability_index<abilities.size():picture="abilities/"+str(abilities[ability_index])
	if picture=="" and not ClassCatalog.GROWTH.get(id,[]).is_empty():picture="stats/"+str(ClassCatalog.GROWTH[id][0][0])
	var pic_side=64.0
	if picture!="":
		var art=UiKit.icon(card,picture,Vector2(dims.x-pic_side-14,12),Vector2(pic_side,pic_side));art.modulate=Color(1,1,1,1.0 if status!="later" else .45)
	UiKit.label(card,"%d уровень" % n,Vector2(16,10),Vector2(dims.x-pic_side-40,28),20,UiKit.INK if status!="later" else UiKit.MUTED)
	var reward=""
	if kind=="ability" and ability_index>=0 and ability_index<abilities.size():reward="Способность · "+AbilityCatalog.DATA[abilities[ability_index]].name+(" · второй слот" if n==ClassCatalog.ABILITY_LEVELS[1] else "")
	elif kind=="perk" and ClassCatalog.PERKS.has(id):reward="Перк · "+Texts.render(ClassCatalog.PERKS[id][0][0])
	elif kind=="mastery" and ClassCatalog.PERKS.has(id):reward="Мастерство · "+Texts.render(ClassCatalog.PERKS[id][1][0])
	elif kind=="power":reward="Q сильнее"
	elif kind=="secret":reward="Секретная способность · в разработке"
	else:reward="Улучшение класса · в разработке"
	var r=UiKit.label(card,reward,Vector2(16,40),Vector2(dims.x-pic_side-40,38),13,UiKit.ORANGE if key and status!="later" else UiKit.MUTED);r.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	# Growth as bars in two columns: health and the class stats, value after this level, bar toward level 20.
	var stats=[["Здоровье",ClassCatalog.hp_per_level(id),""]]
	for g in ClassCatalog.GROWTH.get(id,[]):stats.append([str(g[2]).left(1).to_upper()+str(g[2]).substr(1),float(g[1])*100,"%"])
	var col_w=(dims.x-40)*.5
	var current=ClassCatalog.level(id) if id in Game.class_unlocks else 1
	for k in range(stats.size()):
		var cx=16+(k%2)*(col_w+8);var cy=88+floori(k/2.0)*40
		var total=stats[k][1]*(n-1)
		var name=UiKit.label(card,str(stats[k][0]),Vector2(cx,cy),Vector2(col_w-60,18),12,UiKit.MUTED);name.clip_text=true
		var value=UiKit.label(card,"+%s%s" % [UiKit.number(snappedf(total,.01)),stats[k][2]],Vector2(cx+col_w-70,cy),Vector2(70,18),12,Color("8fe895") if status=="done" else UiKit.INK if status=="goal" else UiKit.MUTED);value.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		var track=ColorRect.new();card.add_child(track);track.position=Vector2(cx,cy+22);track.size=Vector2(col_w,6);track.color=Color(1,1,1,.08);track.mouse_filter=Control.MOUSE_FILTER_IGNORE
		# What the class has now (light), and in green what this level adds on top of it (T-173).
		var per=col_w/(ClassCatalog.MAX_LEVEL-1);var now=mini(n,current)-1
		var base=ColorRect.new();track.add_child(base);base.size=Vector2(per*now,6);base.color=Color(1,1,1,.5);base.mouse_filter=Control.MOUSE_FILTER_IGNORE
		if n>current:
			var gain=ColorRect.new();track.add_child(gain);gain.position.x=per*now;gain.size=Vector2(per*(n-current),6);gain.color=Color("8fe895",1.0 if status=="goal" else .55);gain.mouse_filter=Control.MOUSE_FILTER_IGNORE
	# Bottom: bought / buy (nearest level only) / price.
	var by=dims.y-46
	if status=="done":
		UiKit.label(card,"✓ Получено",Vector2(16,by+8),Vector2(dims.x-32,26),15,Color("8fe895"))
	elif status=="goal":
		var short=cost-Game.credits
		var b=UiKit.button(card,("Получить · %d ◈" % cost) if short<=0 else ("Не хватает %d ◈" % short),Vector2(16,by),Vector2(dims.x-32,38),func():
			if Game.upgrade_class(id,false):
				Game.sound("upgrade",self);set_meta("just_reached",n);screen.notice="Уровень %d" % n;screen.changed.emit()
				var old=get_node_or_null("ClassPathView")
				if old:remove_child(old);old.queue_free()
				# The page under the path refreshes too (T-206): a level-3 purchase unlocks the ability cell at once.
				build();open_path()
		,short<=0)
		b.name="Buy_%d" % n;b.disabled=short>0;UiKit.muted_locked_button(b)
	else:
		var price=UiKit.label(card,str(Game.class_step_cost(n-2)) if n>=2 else "",Vector2(16,by+8),Vector2(dims.x-60,26),15,UiKit.MUTED)
		if n>=2:UiKit.icon(card,"alloy",Vector2(16+price.get_theme_font("font").get_string_size(price.text,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x+6,by+10),Vector2(20,20)).modulate=Color(1,1,1,.6)

## Esc closes the open list or path first, not the whole Barracks (T-189).
func _input(event):
	if not event.is_action_pressed("pause") or event.is_echo():return
	for name in ["AbilityPopup","ClassPathView","ClassRoster"]:
		var o=get_node_or_null(name)
		if o:o.queue_free();get_viewport().set_input_as_handled();return
func act(ok:bool,message:String):
	if not ok:return
	Game.sound("upgrade",self);screen.notice=message;screen.selected=viewed;screen.changed.emit();screen.build()
## Exact-colour rounded bar (UiKit.style maps light colours to theme surfaces, which turned the green fill dark).
static func bar_style(color:Color,radius:int)->StyleBoxFlat:
	var b=StyleBoxFlat.new();b.bg_color=color;b.set_corner_radius_all(radius);return b
