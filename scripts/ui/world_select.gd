extends Control
## «В бой»: worlds as collectible cards. Each card shows art, a big number, the name, field progress as pips and
## a medal once the world is cleared; locked worlds are dark with one line on how to open them. The last
## unlocked world is preselected, so E / Enter starts right away; ←/→ switch cards. The daily run and its table («Топ»)
## are buttons under the cards, open from the start (0.8.0). Art: res://assets/ui/worlds/<id>.png when present, a drawn backdrop otherwise.
signal selected(world:int,infinite:bool)
signal daily_selected
signal cancelled
const CARD=Vector2(236,446)
const IDS=["world_1","world_2","world_3","endless"]
const TINTS=[Color("6d8a5a"),Color("8a7a55"),Color("6b6f82"),Color("8a5a4e")]
var cards:Array=[]
## Challenge ladder chosen per world (0 = normal); defaults to the highest open step.
var ladder:={}
const LADDER_TEXT=["Обычный режим","I · враги опытнее · сплав +25%","II · без передышки, штаб слабее · +50%","III · элитные командиры, +1 враг · +100%"]
var current=0

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_to_group("selection_scope")
	var dim=ColorRect.new();add_child(dim);dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);dim.color=Color(0,0,0,.6)
	var size_total=Vector2(CARD.x*4+18*3+52,CARD.y+150)
	var panel=UiKit.glass(self,(get_viewport_rect().size-size_total)*.5,size_total);panel.name="WorldPanel"
	UiKit.accent(UiKit.label(panel,"Куда выдвигаемся",Vector2(26,20),Vector2(340,42),28))
	difficulty_row(panel,Vector2(380,22))
	UiKit.button(panel,"×",Vector2(size_total.x-72,17),Vector2(56,46),func():cancelled.emit())
	if OS.is_debug_build():UiKit.button(panel,"unlock-dev",Vector2(size_total.x-250,22),Vector2(160,38),unlock_worlds).add_theme_font_size_override("font_size",13)
	cards.clear()
	for i in range(4):cards.append(card(panel,i,Vector2(26+i*(CARD.x+18),84)))
	# The newest open world is chosen by default.
	current=0
	for i in range(3):
		if Campaign.unlocked(i+1):current=i
	focus(current)
	UiKit.label(panel,"[E] в бой   ←/→ выбор",Vector2(26,size_total.y-44),Vector2(500,26),14,UiKit.MUTED)
	# 0.8.0 (author): the daily run is open from the start — its own button under the cards, not on Endless.
	var daily=UiKit.button(panel,"Забег дня",Vector2(size_total.x-26-260-12-90,size_total.y-58),Vector2(260,44),func():daily_selected.emit());daily.name="DailyRun"
	daily.tooltip_text=Texts.render("Одно поле на всех на сегодня. "+DailyRun.describe(DailyRun.best(DailyRun.today_key())))
	var board=UiKit.button(panel,"Топ",Vector2(size_total.x-26-90,size_total.y-58),Vector2(90,44),func():show_board());board.name="DailyBoard"
	board.tooltip_text=Texts.localized("Таблица дня")

func open(i:int)->bool:return Campaign.unlocked(i+1) if i<3 else Campaign.infinite_unlocked()

func card(panel:Control,i:int,pos:Vector2)->Button:
	var unlocked=open(i)
	var button=Button.new();button.name="World_"+IDS[i];panel.add_child(button);button.position=pos;button.size=CARD;button.focus_mode=Control.FOCUS_ALL
	button.add_theme_stylebox_override("normal",UiKit.style(Color("1f2822"),14,Color(1,1,1,.08)))
	button.add_theme_stylebox_override("hover",UiKit.style(Color("243029"),14,Color(1,1,1,.2)))
	button.add_theme_stylebox_override("focus",UiKit.style(Color(0,0,0,0),14,UiKit.ORANGE))
	button.add_theme_stylebox_override("pressed",UiKit.style(Color("2b382f"),14,UiKit.ORANGE))
	button.pressed.connect(func():focus(i);launch())
	button.mouse_entered.connect(func():focus(i))
	# Art window.
	var art=Control.new();button.add_child(art);art.position=Vector2(10,10);art.size=Vector2(CARD.x-20,250);art.mouse_filter=Control.MOUSE_FILTER_IGNORE;art.clip_contents=true
	var path="res://assets/ui/worlds/%s.png" % IDS[i]
	if ResourceLoader.exists(path):
		var picture=TextureRect.new();art.add_child(picture);picture.texture=load(path);picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;picture.size=art.size;picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
	else:
		var backdrop=preload("res://scripts/ui/world_backdrop.gd").new();backdrop.tint=TINTS[i];backdrop.kind=i;art.add_child(backdrop);backdrop.size=art.size;backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var number=UiKit.label(art,"0%d" % (i+1) if i<3 else "∞",Vector2(14,4),Vector2(120,80),62,Color(1,1,1,.92));UiKit.accent(number);number.add_theme_constant_override("outline_size",8);number.add_theme_color_override("font_outline_color",Color(0,0,0,.35))
	if not unlocked:
		var shade=ColorRect.new();art.add_child(shade);shade.size=art.size;shade.color=Color(0,0,0,.62);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
		UiKit.icon(art,"lock",art.size*.5-Vector2(26,26),Vector2(52,52))
	# Name and progress.
	UiKit.label(button,Campaign.WORLDS[i+1].name if i<3 else "Бесконечный",Vector2(16,268),Vector2(CARD.x-32,30),22,UiKit.INK if unlocked else UiKit.MUTED)
	# The biomes of the world, in route order, under its name.
	var biomes="все биомы, от леса до пепелища" if i==0 else preload("res://scripts/biome_catalog.gd").world_line(i+1) if i<3 else "все биомы вперемешку"
	var line=UiKit.label(button,biomes,Vector2(14,296),Vector2(CARD.x-26,18),12,UiKit.MUTED);line.name="Biomes";line.clip_text=true
	if not unlocked:
		UiKit.label(button,("В полной версии" if i<3 and not Campaign.in_demo(i+1) else "Пройди мир %d" % i) if i<3 else "Пройди мир 1",Vector2(16,318),Vector2(CARD.x-32,24),15,UiKit.MUTED)
	elif i<3:
		var depth=clampi(int(Game.progression.counters.get("world_depth_%d" % (i+1),0)),0,Campaign.SIZES.size())
		var pips=Control.new();button.add_child(pips);pips.position=Vector2(16,316);pips.mouse_filter=Control.MOUSE_FILTER_IGNORE
		for k in range(Campaign.SIZES.size()):
			var pip=ColorRect.new();pips.add_child(pip);pip.position=Vector2(k*26,0);pip.size=Vector2(20,6);pip.color=UiKit.ORANGE if k<depth else Color(1,1,1,.14)
		if i+1 in Game.progression.cleared_worlds:
			var medal=UiKit.icon(button,"legendary",Vector2(CARD.x-56,270),Vector2(40,40));medal.tooltip_text=Texts.render("Мир пройден")
		ladder_row(button,i+1)
	else:
		var best=int(Game.progression.counters.get("endless_cycle",0))
		UiKit.label(button,"Лучший сектор: %d" % best if best>0 else "Сектор за сектором",Vector2(16,318),Vector2(CARD.x-32,24),15,UiKit.MUTED)
	# Worlds 2 and 3 are not built yet (author, 2 Oct): world 1 carries every biome for now.
	if i in [1,2]:
		var wip=UiKit.label(button,"В разработке",Vector2(16,346),Vector2(CARD.x-32,24),15,UiKit.ORANGE);wip.name="InDevelopment"
	if not unlocked:button.modulate=Color(1,1,1,.85)
	return button

func focus(i:int):
	current=clampi(i,0,cards.size()-1)
	for k in cards.size():
		var c:Button=cards[k];var chosen=k==current
		c.pivot_offset=CARD*.5
		create_tween().tween_property(c,"scale",Vector2.ONE*(1.04 if chosen else 1.0),.12)
		# The chosen world is framed from the first frame (T-018), not only after a key press.
		if not c.has_meta("base_style"):c.set_meta("base_style",c.get_theme_stylebox("normal"))
		var base:StyleBox=c.get_meta("base_style")
		if chosen and base is StyleBoxFlat:
			var framed:StyleBoxFlat=base.duplicate();framed.border_color=UiKit.ORANGE;framed.set_border_width_all(3)
			for key in ["normal","hover","focus"]:c.add_theme_stylebox_override(key,framed)
		elif base:
			for key in ["normal","hover","focus"]:c.add_theme_stylebox_override(key,base)
	if is_instance_valid(cards[current]):cards[current].grab_focus()

func launch():
	if not open(current):Game.sound("route_cancel",self);return
	Game.sound("route_enter",self)
	if current<3:selected.emit(current+1,false)
	else:selected.emit(1,true)

## Modal: keys are taken before the hub sees them (E would otherwise also reach the hub interaction).
func _input(event):
	# The daily table is a small modal: Esc or E closes it and nothing else reacts.
	if has_node("DailyBoardView"):
		if event.is_action_pressed("pause") or event.is_action_pressed("interact"):get_viewport().set_input_as_handled();get_node("DailyBoardView").queue_free()
		return
	if event.is_action_pressed("pause"):get_viewport().set_input_as_handled();cancelled.emit();return
	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER,KEY_KP_ENTER]):
		get_viewport().set_input_as_handled();launch()
	elif event.is_action_pressed("west"):get_viewport().set_input_as_handled();focus(current-1)
	elif event.is_action_pressed("east"):get_viewport().set_input_as_handled();focus(current+1)

func unlock_worlds():
	Game.progression.cleared_worlds=[1,2,3];Game.save_progress()
	for child in get_children():
		remove_child(child);child.queue_free()
	_ready()

## World difficulty (T-266): one switch for every world, kept in the profile, applied when the run starts.
const DIFFICULTY_HINTS={"easy":"Враги: здоровье и урон −25%. Сплав как обычно.","normal":"Враги и сплав без изменений.","hard":"Враги: здоровье и урон +25%. Сплав за врагов и сундуки +20%."}
func difficulty_row(panel:Control,pos:Vector2):
	var old=panel.get_node_or_null("Difficulty")
	if old:panel.remove_child(old);old.queue_free()
	var row=Control.new();row.name="Difficulty";panel.add_child(row);row.position=pos;row.size=Vector2(410,40);row.mouse_filter=Control.MOUSE_FILTER_IGNORE
	UiKit.label(row,"Сложность",Vector2(0,10),Vector2(90,22),14,UiKit.MUTED)
	var tabs=Campaign.DIFFICULTIES.map(func(id):return [id,Campaign.difficulty_name(id)])
	var buttons=UiKit.tab_row(row,Vector2(92,0),318,tabs,Campaign.difficulty_id(Game.world_difficulty),func(id):set_difficulty(panel,pos,id),40)
	for b in buttons:b.tooltip_text=Texts.render(DIFFICULTY_HINTS[str(b.name).trim_prefix("Tab_")])
func set_difficulty(panel:Control,pos:Vector2,id:String):
	if id==Game.world_difficulty:return
	Game.world_difficulty=Campaign.difficulty_id(id);Game.save_progress();Game.sound("ui_confirm",self)
	difficulty_row(panel,pos)

func challenge_for(world:int)->int:return int(ladder.get(world,0))
## Three round steps I II III under the progress pips, and one line on what the chosen step adds.
func ladder_row(card:Button,world:int):
	var open=Campaign.challenge_open(world);var best=int(Game.progression.counters.get("challenge_w%d" % world,0))
	if not ladder.has(world):ladder[world]=open
	var row=Control.new();row.name="Ladder";card.add_child(row);row.position=Vector2(16,338);row.size=Vector2(CARD.x-32,40);row.mouse_filter=Control.MOUSE_FILTER_PASS
	var note=UiKit.label(card,LADDER_TEXT[challenge_for(world)],Vector2(16,382),Vector2(CARD.x-32,40),13,UiKit.MUTED);note.name="LadderNote";note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	for step in range(1,4):
		var dot=Button.new();dot.name="Step%d" % step;row.add_child(dot);dot.position=Vector2((step-1)*48,0);dot.size=Vector2(38,38);dot.focus_mode=Control.FOCUS_NONE
		dot.text=["I","II","III"][step-1];dot.add_theme_font_size_override("font_size",14)
		var locked=step>open;var cleared=step<=best;var chosen=step==challenge_for(world)
		var fill=Color(UiKit.ORANGE,.85) if cleared else Color(1,1,1,.04)
		var style=UiKit.style(fill,19,UiKit.ORANGE if chosen else Color(1,1,1,.18) if locked else Color(UiKit.ORANGE,.55))
		style.set_border_width_all(3 if chosen else 1)
		for key in ["normal","hover","pressed","disabled","focus"]:dot.add_theme_stylebox_override(key,style)
		dot.add_theme_color_override("font_color",Color("1f2822") if cleared else UiKit.INK);dot.add_theme_color_override("font_disabled_color",Color(1,1,1,.25))
		dot.disabled=locked
		dot.tooltip_text=Texts.render(LADDER_TEXT[step] if not locked else "Откроется после ступени %s" % ["мира","I","II"][step-1])
		dot.pressed.connect(func():
			ladder[world]=0 if challenge_for(world)==step else step
			Game.sound("ui_confirm",self);refresh_ladder(card,world))
func refresh_ladder(card:Button,world:int):
	for name in ["Ladder","LadderNote"]:
		var node=card.get_node_or_null(name)
		if node:card.remove_child(node);node.queue_free()
	ladder_row(card,world)

## Today's local leaderboard: every profile on this computer, best first.
func show_board():
	if has_node("DailyBoardView"):return
	var view=Control.new();view.name="DailyBoardView";add_child(view);view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);view.add_to_group("selection_scope")
	var shade=ColorRect.new();view.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,.5)
	shade.gui_input.connect(func(e):if e is InputEventMouseButton and e.pressed:view.queue_free())
	var size=Vector2(620,560);var panel=UiKit.glass(view,((get_viewport_rect().size-size)*.5).round(),size)
	UiKit.label(panel,"Таблица дня",Vector2(26,18),Vector2(400,36),26)
	UiKit.label(panel,DailyRun.today_key()+" · все профили на этом компьютере",Vector2(26,56),Vector2(560,22),14,UiKit.MUTED)
	var close=UiKit.button(panel,"",Vector2(size.x-62,16),Vector2(44,40),func():view.queue_free());close.icon=UiKit.interface_icon("close");close.expand_icon=true;close.add_theme_constant_override("icon_max_width",18)
	var rows=DailyBoard.top(DailyRun.today_key())
	if rows.is_empty():UiKit.label(panel,"Сегодня ещё никто не играл. Будь первым.",Vector2(26,110),Vector2(560,30),17,UiKit.MUTED)
	for i in range(rows.size()):
		var e=rows[i];var y=96+i*44;var mine=int(e.get("slot",0))==Game.profiles.active
		var row=Panel.new();panel.add_child(row);row.position=Vector2(20,y);row.size=Vector2(size.x-40,38)
		row.add_theme_stylebox_override("panel",UiKit.style(Color("4a3f28") if mine else Color("2f3b33"),8,UiKit.ORANGE if mine else Color.TRANSPARENT))
		UiKit.label(row,str(i+1),Vector2(12,6),Vector2(30,26),18,UiKit.ORANGE if i<3 else UiKit.INK)
		UiKit.label(row,"Профиль %d" % int(e.get("slot",1)),Vector2(48,8),Vector2(130,24),15)
		UiKit.label(row,DailyRun.describe(e),Vector2(180,8),Vector2(270,24),14,UiKit.MUTED)
		var score=UiKit.label(row,str(int(e.get("score",0))),Vector2(size.x-200,8),Vector2(150,24),15);score.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
