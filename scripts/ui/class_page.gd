extends Control
## Barracks → «Классы» (0.8.0, T-106/T-147): one page for everything about a class. Left: a scrolling column
## of classes. Right: the chosen class — portrait and role, a level track with its milestones (3 second
## ability, 5 perk, 7 stronger Q, 10 mastery) and one level button, the two ability slots (Q fixed, «1» one of
## two, picked by a tap, free), and four stats. No list of lines, nothing that looks like a purchase but is not.
const MILESTONE={3:["Слот 1","abilities"],5:["Перк","rare"],7:["Q сильнее","star"],10:["Мастерство","legendary"]}
var screen  # StationScreen: rebuild + notice
var viewed:=""

func setup(owner,area:Vector2):
	screen=owner;size=area
	if viewed=="":viewed=screen.selected if screen.selected in ClassCatalog.ROSTER else Game.selected_class
	build()

func build():
	for child in get_children():child.queue_free()
	classes_column()
	details(Vector2(170,0),Vector2(size.x-170,size.y))

## Left column: every playable class, scrolling; level or unlock progress under the name.
func classes_column():
	var scroll=ScrollContainer.new();add_child(scroll);scroll.position=Vector2.ZERO;scroll.size=Vector2(156,size.y);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	var list=VBoxContainer.new();scroll.add_child(list);list.add_theme_constant_override("separation",8)
	for id in ClassCatalog.ROSTER:
		var owned=id in Game.class_unlocks;var chosen=id==viewed
		var b=Button.new();list.add_child(b);b.custom_minimum_size=Vector2(144,104);b.name="Class_"+id;b.focus_mode=Control.FOCUS_ALL
		var style=UiKit.style(Color("2c352e") if owned else Color("232a25"),12,UiKit.ORANGE if chosen else Color(1,1,1,.08));style.set_border_width_all(3 if chosen else 1)
		for state in ["normal","hover","pressed","focus"]:b.add_theme_stylebox_override(state,style)
		var shell=id
		b.pressed.connect(func():screen.selected=shell;screen.notice="";screen.build())
		var art=TextureRect.new();b.add_child(art);art.texture=preload("res://scripts/ui/class_gallery.gd").texture(id,true);art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;art.position=Vector2(44,6);art.size=Vector2(56,56);art.mouse_filter=Control.MOUSE_FILTER_IGNORE
		UiKit.locked_preview(art,not owned)
		var title=UiKit.label(b,Game.CLASSES[id].name,Vector2(4,62),Vector2(136,22),15,UiKit.INK if owned else UiKit.MUTED);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var p=ClassCatalog.progress(id)
		var caption="ур. %d" % ClassCatalog.level(id) if owned else ("можно открыть" if Game.can_select_class(id) else "%d / %d" % [p[0],p[1]])
		var sub=UiKit.label(b,caption,Vector2(4,82),Vector2(136,18),12,UiKit.ORANGE if id==Game.selected_class else UiKit.MUTED);sub.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;sub.mouse_filter=Control.MOUSE_FILTER_IGNORE
		if id==Game.selected_class:UiKit.badge(b,"ready")
	if is_instance_valid(screen) and screen.station_kind!="":preload("res://scripts/ui/station_notices.gd").mark_item_seen(screen.station_kind,"shells",viewed)

func details(pos:Vector2,area:Vector2):
	var id=viewed;var owned=id in Game.class_unlocks;var level=ClassCatalog.level(id)
	var root=Control.new();add_child(root);root.position=pos;root.size=area
	# Header: portrait, name, role; the one main action of the header (choose / open).
	var portrait=TextureRect.new();root.add_child(portrait);portrait.texture=preload("res://scripts/ui/class_gallery.gd").texture(id);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.size=Vector2(88,88)
	UiKit.locked_preview(portrait,not owned)
	UiKit.accent(UiKit.label(root,Game.CLASSES[id].name,Vector2(102,0),Vector2(380,36),24))
	var role=UiKit.label(root,"%s · любимая семья карточек: %s" % [ClassCatalog.info(id).role,RunUpgrades.FAMILIES[ClassCatalog.info(id).family]],Vector2(102,38),Vector2(area.x-330,44),14,UiKit.MUTED);role.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var lines=ClassCatalog.modifier_lines(id)
	if not lines.is_empty():UiKit.label(root,"Всегда: "+", ".join(lines),Vector2(102,64),Vector2(area.x-330,22),13,UiKit.MUTED).clip_text=true
	if id==Game.selected_class:
		var chip=UiKit.label(root,"Выбран",Vector2(area.x-210,6),Vector2(200,36),18,Color("8fe895"));chip.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	elif owned or Game.can_select_class(id):
		UiKit.button(root,"Выбрать" if owned else "Открыть и выбрать",Vector2(area.x-210,4),Vector2(200,46),func():act(Game.select_class(id),"Класс выбран"),true).name="Choose"
	else:
		var why=UiKit.label(root,ClassCatalog.unlock_text(id),Vector2(area.x-260,6),Vector2(250,44),14,UiKit.MUTED);why.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;why.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	track(root,Vector2(0,104),area.x,id,owned,level)
	abilities(root,Vector2(0,252),area.x,id,owned,level)
	stats(root,Vector2(0,area.y-62),area.x,id)

## Level track: ten nodes on one line, filled up to the current level, milestones with an icon and a caption;
## under it one button for the next level (grey with «не хватает N ◈» when short of alloy).
func track(root:Control,pos:Vector2,width:float,id:String,owned:bool,level:int):
	UiKit.label(root,"Уровень класса %d из 10" % level,pos,Vector2(300,24),16)
	var x0=pos.x+18;var span=width-36;var y=pos.y+44
	var line=ColorRect.new();root.add_child(line);line.position=Vector2(x0,y-2);line.size=Vector2(span,4);line.color=Color(1,1,1,.12);line.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var done=ColorRect.new();root.add_child(done);done.position=Vector2(x0,y-2);done.size=Vector2(span*clampf((level-1)/9.0,0,1),4);done.color=Color("8fe895");done.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for n in range(1,11):
		var cx=x0+span*(n-1)/9.0;var reached=owned and level>=n;var next=owned and n==level+1
		var r=(16.0 if MILESTONE.has(n) else 9.0)
		var dot=Panel.new();root.add_child(dot);dot.position=Vector2(cx-r,y-r);dot.size=Vector2(r*2,r*2);dot.mouse_filter=Control.MOUSE_FILTER_IGNORE;dot.name="Level_%d" % n
		var ring=UiKit.style(Color("8fe895") if reached else UiKit.ORANGE if next else Color("2c352e"),int(r),Color("8fe895") if reached else UiKit.ORANGE if next else Color(1,1,1,.3));ring.set_border_width_all(2)
		dot.add_theme_stylebox_override("panel",ring)
		if MILESTONE.has(n):
			var icon=UiKit.icon(dot,str(MILESTONE[n][1]),Vector2(6,6),Vector2(r*2-12,r*2-12));icon.modulate=Color(1,1,1,1.0 if reached or next else .5)
			var cap=UiKit.label(root,"%d · %s" % [n,MILESTONE[n][0]],Vector2(cx-60,y+18),Vector2(120,20),12,UiKit.INK if reached else UiKit.MUTED);cap.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;cap.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	if not owned:return
	var bx=0.0;var by=pos.y+92
	if level>=10:
		UiKit.label(root,"Максимальный уровень",Vector2(bx,by),Vector2(320,44),17,Color("8fe895"));return
	var cost=Game.class_upgrade_cost(id,false);var short=cost-Game.credits
	var gain=ClassCatalog.milestone_suffix(level+1)
	var text=("Уровень %d%s · %d ◈" % [level+1,gain,cost]) if short<=0 else ("Уровень %d · не хватает %d ◈" % [level+1,short])
	var b=UiKit.button(root,text,Vector2(bx,by),Vector2(360,46),func():act(Game.upgrade_class(id,false),"Уровень %d" % (level+1)),short<=0)
	b.name="LevelUp";b.disabled=short>0;b.add_theme_font_size_override("font_size",16);UiKit.muted_locked_button(b)
	UiKit.label(root,"+0,5 здоровья за каждый уровень",Vector2(bx+376,by+12),Vector2(300,22),13,UiKit.MUTED)

## Two slots. Q: the class's own ability, always there. «1»: one of two, chosen by a tap, free, from level 3.
func abilities(root:Control,pos:Vector2,width:float,id:String,owned:bool,level:int):
	UiKit.label(root,"Способности · два слота",pos,Vector2(400,24),16)
	var q=Game.CLASS_SKILLS[id]
	ability_card(root,pos+Vector2(0,32),Vector2(190,130),q,"Q · всегда в слоте"+(" · сильнее" if level>=7 else ""),"q",true,false,Callable())
	var open=owned and level>=3;var current=Game.class_second(id)
	UiKit.label(root,"Слот 1 — одна на выбор, бесплатно" if open else "Слот 1 — откроется на 3 уровне класса",pos+Vector2(214,32),Vector2(width-214,22),13,UiKit.MUTED)
	var x=214.0
	for option in Game.CLASS_CHOICES[id]:
		var picked=option==current
		var pick=func():act(Game.choose_class_second(id,option),"Слот 1 · "+AbilityCatalog.DATA[option].name)
		ability_card(root,pos+Vector2(x,56),Vector2(190,106),option,("В слоте" if picked else "Взять в слот") if open else "Ур. 3","s_"+option,open,open and picked,pick if open and not picked else Callable())
		x+=204
	# Perks under the slots, one compact line each.
	var perks=ClassCatalog.PERKS.get(id,[])
	for n in range(perks.size()):
		var on=ClassCatalog.perk_on(id,n)
		UiKit.label(root,("✓ " if on else "")+("Перк, ур. 5: " if n==0 else "Мастерство, ур. 10: ")+Texts.render(perks[n][0]),pos+Vector2(0,172+n*22),Vector2(width,22),13,Color("8fe895") if on else UiKit.MUTED)

func ability_card(root:Control,pos:Vector2,dims:Vector2,ability:String,caption:String,key:String,active:bool,picked:bool,action:Callable):
	var b=Button.new();root.add_child(b);b.position=pos;b.size=dims;b.name="Ability_"+key;b.focus_mode=Control.FOCUS_ALL
	var style=UiKit.style(Color("2c352e") if active else Color("232a25"),12,Color("8fe895") if picked else Color(1,1,1,.1));style.set_border_width_all(3 if picked else 1)
	for state in ["normal","hover","pressed","focus"]:b.add_theme_stylebox_override(state,style)
	b.tooltip_text=Texts.render(AbilityCatalog.DATA[ability].get("description",""))
	if action.is_valid():b.pressed.connect(action)
	var icon=UiKit.icon(b,"abilities/"+ability,Vector2(dims.x*.5-30,10),Vector2(60,60));icon.modulate=Color(1,1,1,1.0 if active else .45)
	var name=UiKit.label(b,AbilityCatalog.DATA[ability].name,Vector2(6,dims.y-56),Vector2(dims.x-12,24),15,UiKit.INK if active else UiKit.MUTED);name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;name.clip_text=true
	var cap=UiKit.label(b,caption,Vector2(6,dims.y-30),Vector2(dims.x-12,22),12,Color("8fe895") if picked else UiKit.MUTED);cap.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER

## Four numbers a run starts with for this class (general upgrades + class + its perks + the equipped weapon).
func stats(root:Control,pos:Vector2,width:float,id:String):
	var s=CombatStats.shell_preview(id)
	var cells=[["Здоровье",UiKit.number(s.health)],["Урон",UiKit.number(s.damage)],["Скорость",UiKit.number(s.speed)],["Напор",UiKit.number(s.pressure)+"%"]]
	var w=(width-30)/4.0
	for i in range(cells.size()):
		var tile=UiKit.panel(root,pos+Vector2(i*(w+10),0),Vector2(w,58),Color(1,1,1,.05))
		UiKit.label(tile,cells[i][0],Vector2(12,4),Vector2(w-24,20),13,UiKit.MUTED)
		UiKit.label(tile,cells[i][1],Vector2(12,24),Vector2(w-24,30),20)

func act(ok:bool,message:String):
	if not ok:return
	Game.sound("upgrade",self);screen.notice=message;screen.selected=viewed;screen.changed.emit();screen.build()
