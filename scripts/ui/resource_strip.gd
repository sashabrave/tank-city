extends CanvasLayer
var label:Label
var documents:Label
var panel:Panel
var document_icon:Control
## Run-only token counter, shown while a run is alive (weak reference to its RunState).
var token_icon:TextureRect
var tokens:Label
var run_ref:WeakRef
var pickup_targets:Dictionary={}
var pickup_flights:Array=[]
var previous=Vector2i(-1,-1)
var pending=Vector2i.ZERO
var delay=0.0
## Token part of the strip fades in and out (T-090): 0 hidden … 1 shown; the strip width follows it.
var token_shown=0.0
var token_last=0
## Set while the defeat screen drops the run tokens: the counter falls to zero and the part folds away.
var tokens_lost=false
func _ready():
	Game.profile_changed.connect(func():previous=Vector2i(Game.credits,Game.cores);pending=Vector2i.ZERO;delay=0)
	layer=90;process_mode=Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(decorate_currency)
	panel=UiKit.panel(self,Vector2.ZERO,Vector2(212,38),Color("e4e9dc"));panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label=UiKit.label(panel,"",Vector2(46,3),Vector2(70,32),17)
	pickup_targets["alloy"]=UiKit.icon(panel,"alloy",Vector2(10,4),Vector2(30,30))
	document_icon=UiKit.icon(panel,"documents",Vector2(114,4),Vector2(30,30))
	pickup_targets["documents"]=pickup_targets["alloy"]
	documents=UiKit.label(panel,"",Vector2(147,3),Vector2(60,32),17)
	token_icon=UiKit.icon(panel,"token",Vector2(0,5),Vector2(28,28));token_icon.name="TokenIcon"
	pickup_targets["tokens"]=token_icon
	# Hover (mouse) or tap (touch) explains each currency.
	for pair in [[pickup_targets["alloy"],"Сплав — покупки и прокачка. При выбывании теряется часть добытого за вылазку."],[token_icon,"Жетоны — валюта торговца. Сгорают после вылазки."]]:
		pair[0].mouse_filter=Control.MOUSE_FILTER_PASS;pair[0].tooltip_text=Texts.localized(pair[1])
	tokens=UiKit.label(panel,"",Vector2(0,3),Vector2(40,32),17);tokens.name="Tokens"
func track_run(run):run_ref=weakref(run) if run!=null else null
func run_tokens()->int:
	var run=run_ref.get_ref() if run_ref!=null else null
	return -1 if run==null else int(run.tokens)
func _process(_delta):
	var now=Vector2i(Game.credits,Game.cores)
	if previous.x>=0 and now!=previous:pending+=now-previous;delay=.12 if delay<=0 else delay
	previous=now
	if delay>0:
		delay-=_delta
		if delay<=0:
			if pending.x:change(pending.x,false)
			if pending.y:change(pending.y,true)
			pending=Vector2i.ZERO
	panel.position=Vector2((get_viewport().get_visible_rect().size.x-212)*.5,10)
	Texts.set_text(label,str(Game.credits));Texts.set_text(documents,str(Game.cores))
	label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;documents.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	var font=label.get_theme_font("font")
	label.size.x=maxf(35,font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x+8)
	# Documents were merged into alloy in 0.7; the strip keeps alloy and run tokens only.
	document_icon.visible=false;documents.visible=false
	# T-031: a little air between each icon and its number; the strip grows smoothly when tokens appear.
	var target=label.position.x+label.size.x+12
	var run_value=run_tokens()
	var wanted=1.0 if run_value>=0 and not tokens_lost else 0.0
	if run_value>=0:token_last=run_value
	if tokens_lost:token_last=0
	token_shown=move_toward(token_shown,wanted,_delta*4.0)
	token_icon.visible=token_shown>0.01;tokens.visible=token_shown>0.01
	if token_shown>0.01:
		Texts.set_text(tokens,str(token_last));tokens.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		token_icon.position.x=target+6;tokens.position.x=token_icon.position.x+36
		tokens.size.x=maxf(24,font.get_string_size(tokens.text,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x+8)
		var ease_shown=token_shown*token_shown*(3.0-2.0*token_shown)
		token_icon.modulate.a=ease_shown;tokens.modulate.a=ease_shown
		target+=(tokens.position.x+tokens.size.x+12-target)*ease_shown
	if run_value<0:tokens_lost=false
	panel.size.x=lerpf(panel.size.x,target,minf(1.0,_delta*14.0)) if absf(panel.size.x-target)>.5 else target
	panel.position.x=(get_viewport().get_visible_rect().size.x-panel.size.x)*.5

func change(amount:int,documents:bool):
	var popup=UiKit.label(panel,("+" if amount>0 else "")+str(amount),Vector2(109 if documents else 5,35),Vector2(98,32),22,Color("61955e") if amount>0 else Color("b66551"))
	popup.mouse_filter=Control.MOUSE_FILTER_IGNORE;popup.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var tween=create_tween().set_parallel(true)
	popup.modulate.a=0
	tween.tween_property(popup,"modulate:a",1.0,.1)
	tween.tween_property(popup,"position:y",48.0 if amount>0 else 67.0,.7).set_trans(Tween.TRANS_QUAD)
	tween.chain().tween_property(popup,"modulate:a",0.0,.25)
	tween.chain().tween_callback(popup.queue_free)

func decorate_currency(node:Node):
	if node is Label or node is Button:call_deferred("attach_currency",node)
func attach_currency(node):
	if not is_instance_valid(node) or node.get_meta("literal_text",false):return
	for child in node.get_children():
		if child.get_script()==preload("res://scripts/ui/currency_icons.gd"):return
	node.add_child(preload("res://scripts/ui/currency_icons.gd").new())

# Shared presentation for current and future currencies; rewards are already granted.
func fly_pickup(kind:String,from:Vector2):
	var key="documents" if kind in ["document","core","cores"] else kind
	if not pickup_targets.has(key):return
	pickup_flights=pickup_flights.filter(is_instance_valid)
	if pickup_flights.size()>=32:pickup_flights.pop_front().queue_free()
	# The flying icon is the same picture as its counter (tokens used the generic «tokens» art, T-089).
	var icon=UiKit.icon(self,"token" if key=="tokens" else key,from-Vector2(15,15),Vector2(30,30))
	icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;pickup_flights.append(icon)
	var destination:Control=pickup_targets[key]
	var tween=create_tween().set_pause_mode(Tween.TWEEN_PAUSE_BOUND)
	tween.tween_method(func(progress:float):
		if not is_instance_valid(icon) or not is_instance_valid(destination):return
		var target=destination.get_global_rect().get_center()
		var bend=Vector2(lerpf(from.x,target.x,.35),minf(from.y,target.y)-65)
		var point=from.lerp(bend,progress).lerp(bend.lerp(target,progress),progress)
		icon.position=point-icon.size*.5
		icon.scale=Vector2.ONE*lerpf(1.15,.7,progress),0.0,1.0,.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		if is_instance_valid(icon):icon.queue_free())
