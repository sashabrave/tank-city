extends Control
## Barracks → «Классы» (0.8.0, T-106/T-147/T-154): one page for everything about a class. Top: classes as tabs.
## Then the chosen class — portrait and role, a level track with its milestones (3 slot 1, 5 perk, 7 stronger Q,
## 10 mastery) and one level button, four stats, the perk lines. Bottom row: the two ability cells (Q comes
## with the class; slot 1 swaps between its two options by a tap, free, from level 3) and the one button to take
## the class or why it is closed. Nothing that looks like a purchase but is not.
const MILESTONE={3:["Слот 1","abilities"],5:["Перк","rare"],7:["Q сильнее","star"],10:["Мастерство","legendary"]}
var screen  # StationScreen: rebuild + notice
var viewed:=""

func setup(owner,area:Vector2):
	screen=owner;size=area
	if viewed=="":viewed=screen.selected if screen.selected in ClassCatalog.ROSTER else Game.selected_class
	build()

func build():
	for child in get_children():child.queue_free()
	class_tabs()
	details(Vector2(0,88),Vector2(size.x,size.y-88))

## Classes as a row of tabs (T-154): portrait, name, level or unlock progress.
func class_tabs():
	var n=ClassCatalog.ROSTER.size();var w=(size.x-8*(n-1))/n
	for i in range(n):
		var id=ClassCatalog.ROSTER[i];var owned=id in Game.class_unlocks;var chosen=id==viewed
		var b=Button.new();add_child(b);b.position=Vector2(i*(w+8),0);b.size=Vector2(w,76);b.name="Class_"+id;b.focus_mode=Control.FOCUS_ALL
		var style=UiKit.style(Color("2c352e") if owned else Color("232a25"),12,UiKit.ORANGE if chosen else Color(1,1,1,.08));style.set_border_width_all(3 if chosen else 1)
		for state in ["normal","hover","pressed","focus"]:b.add_theme_stylebox_override(state,style)
		var shell=id
		b.pressed.connect(func():screen.selected=shell;screen.notice="";screen.build())
		var art=TextureRect.new();b.add_child(art);art.texture=preload("res://scripts/ui/class_gallery.gd").texture(id,true);art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;art.position=Vector2(6,10);art.size=Vector2(52,56);art.mouse_filter=Control.MOUSE_FILTER_IGNORE
		UiKit.locked_preview(art,not owned)
		var title=UiKit.label(b,Game.CLASSES[id].name,Vector2(62,14),Vector2(w-66,22),15,UiKit.INK if owned else UiKit.MUTED);title.mouse_filter=Control.MOUSE_FILTER_IGNORE;title.clip_text=true
		var p=ClassCatalog.progress(id)
		var caption=("Выбран · ур. %d" % ClassCatalog.level(id) if id==Game.selected_class else "ур. %d" % ClassCatalog.level(id)) if owned else ("можно открыть" if Game.can_select_class(id) else "%d / %d" % [p[0],p[1]])
		var sub=UiKit.label(b,caption,Vector2(62,40),Vector2(w-66,20),12,UiKit.ORANGE if id==Game.selected_class else UiKit.MUTED);sub.mouse_filter=Control.MOUSE_FILTER_IGNORE;sub.clip_text=true
	if is_instance_valid(screen) and screen.station_kind!="":preload("res://scripts/ui/station_notices.gd").mark_item_seen(screen.station_kind,"shells",viewed)

func details(pos:Vector2,area:Vector2):
	var id=viewed;var owned=id in Game.class_unlocks;var level=ClassCatalog.level(id)
	var root=Control.new();add_child(root);root.position=pos;root.size=area
	var portrait=TextureRect.new();root.add_child(portrait);portrait.texture=preload("res://scripts/ui/class_gallery.gd").texture(id);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.size=Vector2(72,72)
	UiKit.locked_preview(portrait,not owned)
	UiKit.accent(UiKit.label(root,Game.CLASSES[id].name,Vector2(86,0),Vector2(420,32),22))
	UiKit.label(root,"%s · любимая семья карточек: %s" % [ClassCatalog.info(id).role,RunUpgrades.FAMILIES[ClassCatalog.info(id).family]],Vector2(86,34),Vector2(area.x-86,20),14,UiKit.MUTED).clip_text=true
	var lines=ClassCatalog.modifier_lines(id)
	if not lines.is_empty():UiKit.label(root,"Всегда: "+", ".join(lines),Vector2(86,54),Vector2(area.x-86,20),13,UiKit.MUTED).clip_text=true
	track(root,Vector2(0,86),area.x,id,owned,level)
	stats(root,Vector2(0,232),area.x,id)
	var perks=ClassCatalog.PERKS.get(id,[])
	for n in range(perks.size()):
		var on=ClassCatalog.perk_on(id,n)
		UiKit.label(root,("✓ " if on else "")+("Перк, ур. 5: " if n==0 else "Мастерство, ур. 10: ")+Texts.render(perks[n][0]),Vector2(0,298+n*20),Vector2(area.x,20),13,Color("8fe895") if on else UiKit.MUTED)
	bottom_row(root,Vector2(0,area.y-92),area.x,id,owned,level)

## Bottom row (T-154): the two ability cells and the one button to take the class (or why it is closed).
func bottom_row(root:Control,pos:Vector2,width:float,id:String,owned:bool,level:int):
	var q=Game.CLASS_SKILLS[id]
	ability_card(root,pos,Vector2(200,92),q,"Q · есть сразу"+(" · сильнее" if level>=7 else ""),"q",true,false,Callable())
	var open=owned and level>=3;var current=Game.class_second(id);var other=Game.CLASS_CHOICES[id].filter(func(a):return a!=current)[0]
	var caption="1 · тап — сменить на «%s»" % AbilityCatalog.DATA[other].name if open else "1 · с 3 уровня: %s или %s" % [AbilityCatalog.DATA[current].name,AbilityCatalog.DATA[other].name]
	ability_card(root,pos+Vector2(212,0),Vector2(260,92),current,caption,"slot",open,open,(func():act(Game.choose_class_second(id,other),"Слот 1 · "+AbilityCatalog.DATA[other].name)) if open else Callable())
	var bx=width-300
	if id==Game.selected_class:
		var b=UiKit.button(root,"Выбран",Vector2(bx,pos.y+18),Vector2(300,56),func():pass);b.disabled=true;b.name="Take";UiKit.muted_locked_button(b)
	elif owned or Game.can_select_class(id):
		UiKit.button(root,"Взять класс" if owned else "Открыть и взять",Vector2(bx,pos.y+18),Vector2(300,56),func():act(Game.select_class(id),"Класс выбран"),true).name="Take"
	else:
		var b=UiKit.button(root,"Закрыто · "+ClassCatalog.unlock_text(id),Vector2(bx,pos.y+18),Vector2(300,56),func():pass);b.disabled=true;b.name="Take";UiKit.muted_locked_button(b);b.clip_text=true;b.add_theme_font_size_override("font_size",14)

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
			var cap=UiKit.label(root,"%d · %s" % [n,MILESTONE[n][0]],Vector2(minf(cx-60,width-120),y+18),Vector2(120,20),12,UiKit.INK if reached else UiKit.MUTED);cap.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;cap.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
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

func ability_card(root:Control,pos:Vector2,dims:Vector2,ability:String,caption:String,key:String,active:bool,picked:bool,action:Callable):
	var b=Button.new();root.add_child(b);b.position=pos;b.size=dims;b.name="Ability_"+key;b.focus_mode=Control.FOCUS_ALL
	var style=UiKit.style(Color("2c352e") if active else Color("232a25"),12,Color("8fe895") if picked else Color(1,1,1,.1));style.set_border_width_all(2 if picked else 1)
	for state in ["normal","hover","pressed","focus"]:b.add_theme_stylebox_override(state,style)
	b.tooltip_text=Texts.render(AbilityCatalog.DATA[ability].get("description",""))
	if action.is_valid():b.pressed.connect(action)
	var icon=UiKit.icon(b,"abilities/"+ability if active else "lock",Vector2(10,dims.y*.5-28),Vector2(56,56));icon.modulate=Color(1,1,1,1.0 if active else .6)
	var name=UiKit.label(b,AbilityCatalog.DATA[ability].name if active else "Слот 1",Vector2(74,dims.y*.5-26),Vector2(dims.x-80,24),16,UiKit.INK if active else UiKit.MUTED);name.clip_text=true;name.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var cap=UiKit.label(b,caption,Vector2(74,dims.y*.5),Vector2(dims.x-80,36),12,UiKit.MUTED);cap.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;cap.mouse_filter=Control.MOUSE_FILTER_IGNORE

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
