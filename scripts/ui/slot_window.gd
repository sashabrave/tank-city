extends Control
## Big slot-machine window: three reels spin and stop left to right on the already decided outcome,
## a short verdict appears, then the window closes by itself. E, Esc or a click skips straight to the end.
## The outcome is rolled by the merchant from the combat RNG; reels only use their own visual RNG.
signal finished
const SYMBOLS=["token","medkit","star1","star2","star3","skull"]
const OUTCOME_SYMBOL={"tokens":"token","heal":"medkit","card0":"star1","card1":"star2","card2":"star3"}
const CELL=Vector2(150,150)
const SPIN=.5
const STAGGER=.17
const HOLD=.75
const GAP=14.0
## The cabinet keeps its physical colours: UiKit.style would recolour light surfaces for the dark theme.
static func flat(color:Color,radius:int,border:Color=Color.TRANSPARENT,width:int=0)->StyleBoxFlat:
	var s=StyleBoxFlat.new();s.bg_color=color;s.set_corner_radius_all(radius);s.border_color=border;s.set_border_width_all(width);return s
var outcome="empty"
var verdict=""
var win=false
var reels:Array=[]
var verdict_label:Label
var visual_rng=RandomNumberGenerator.new()
var done=false
var elapsed=0.0
func setup(result:String,text:String)->Control:
	outcome=result;verdict=text;win=result!="empty";return self
func _ready():
	name="SlotWindow";set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_to_group("selection_scope")
	visual_rng.randomize()
	var shade=ColorRect.new();add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,.45);shade.mouse_filter=Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(func(e):if e is InputEventMouseButton and e.pressed:finish())
	var screen=get_viewport().get_visible_rect().size
	var inner=CELL.x*3+GAP*2+16;var width=inner+40;var height=CELL.y+160
	var frame=Panel.new();add_child(frame);frame.name="Cabinet";frame.size=Vector2(width,height);frame.position=((screen-frame.size)*.5).round()
	frame.add_theme_stylebox_override("panel",flat(Color("8f2f2a"),18,Color("e5b34f"),4))
	frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var title=UiKit.label(frame,"Игровой автомат",Vector2(0,14),Vector2(width,34),24,Color("fff0ce"));title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var glass=Panel.new();frame.add_child(glass);glass.position=Vector2(20,62);glass.size=Vector2(inner,CELL.y+16);glass.add_theme_stylebox_override("panel",flat(Color("1d211f"),10))
	for i in range(3):
		var window=Control.new();glass.add_child(window);window.clip_contents=true;window.position=Vector2(8+i*(CELL.x+GAP),8);window.size=CELL;window.name="Reel%d" % i
		var face=Panel.new();window.add_child(face);face.size=CELL;face.add_theme_stylebox_override("panel",flat(Color("f4ecd6"),8))
		var strip=Control.new();window.add_child(strip)
		reels.append({"strip":strip,"stop":SPIN+i*STAGGER,"stopped":false,"symbols":[]})
	var targets=reel_targets()
	for i in range(3):fill(reels[i],targets[i])
	verdict_label=UiKit.label(frame,"",Vector2(16,CELL.y+90),Vector2(width-32,56),22,Color("fff0ce"));verdict_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;verdict_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;verdict_label.name="Verdict"
	Game.sound("reroll",self)
## A win lands three equal symbols; a miss never does.
func reel_targets()->Array:
	if win:
		var same=OUTCOME_SYMBOL.get(outcome,"token");return [same,same,same]
	var result=[]
	for i in range(3):result.append(SYMBOLS[visual_rng.randi_range(0,SYMBOLS.size()-1)])
	if result[0]==result[1] and result[1]==result[2]:result[2]="skull" if result[0]!="skull" else "token"
	return result
## Strip of random symbols ending on the target; the reel scrolls down to it.
func fill(reel:Dictionary,target:String):
	var count=10
	for j in range(count):
		var id=target if j==count-1 else SYMBOLS[visual_rng.randi_range(0,SYMBOLS.size()-1)]
		var cell=symbol(reel.strip,id);cell.position=Vector2(0,-j*CELL.y);reel.symbols.append(cell)
	reel.distance=(count-1)*CELL.y
func symbol(parent:Control,id:String)->Control:
	var box=Control.new();parent.add_child(box);box.size=CELL;box.mouse_filter=Control.MOUSE_FILTER_IGNORE
	# Drawn reel art (assets/ui/slot/<symbol>.png) when present; built-in symbols otherwise.
	var art="res://assets/ui/slot/%s.png" % id
	if ResourceLoader.exists(art):
		var picture=TextureRect.new();box.add_child(picture);picture.texture=load(art);picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.position=CELL*.08;picture.size=CELL*.84;picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
		return box
	if id.begins_with("star"):
		var tier=int(id.right(1))-1
		var stars=UiKit.label(box,"★".repeat(tier+1),Vector2.ZERO,CELL,[78,56,42][tier],Color(LootCatalog.RARITY_COLORS[tier]).darkened(.15))
		stars.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;stars.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	elif id=="skull":
		var miss=UiKit.label(box,"✕",Vector2.ZERO,CELL,84,Color("6c6f69"));miss.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;miss.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	else:
		var picture=UiKit.icon(box,id,CELL*.18,CELL*.64);picture.modulate=Color("2f3a33") if id=="token" else Color.WHITE
	return box
func _process(delta):
	if done:return
	elapsed+=delta
	var spinning=false
	for reel in reels:
		var t=clampf(elapsed/reel.stop,0,1)
		# Fast linear spin that eases into the final symbol with a tiny overshoot.
		var eased=1.0-pow(1.0-t,3)
		reel.strip.position.y=eased*reel.distance+(sin(t*PI)*CELL.y*.06 if t<1 else 0.0)
		if t>=1 and not reel.stopped:reel.stopped=true;Game.sound("countdown_tick",self)
		spinning=spinning or t<1
	if not spinning and verdict_label.text=="":
		Texts.set_text(verdict_label,verdict)
		verdict_label.add_theme_color_override("font_color",Color("ffe08a") if win else Color("e8dccb"))
		Game.sound("rare_reveal" if win else "ui_denied",self)
	if elapsed>reels[2].stop+HOLD:finish()
func _unhandled_input(event):
	if done:return
	if event.is_action_pressed("interact") or event.is_action_pressed("pause") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled();finish()
func finish():
	if done:return
	done=true;finished.emit();queue_free()
