class_name KitIcon extends Control
## Design-system icon motion (guides/03_release/07_icon_kit_brief.md, «Движение иконок»). IconMotion attaches
## one to every TextureRect that shows a UiKit icon. It draws the icon as parallax layers when the kit has it,
## or as the plain picture otherwise, and gives every icon the same light bounce: appear, hover, select, leave.
## It is an internal child drawn under the host's own children (rarity frames, chevrons stay on top).
const DEPTH={"aura":.15,"face":.3,"symbol":.6,"rim":1.0,"badge":1.15,"flat":.5}
const APPEAR:=.32
const LEAVE:=.22
const STAGGER:=.035
const PUNCH:=.3
## Parallax shift at full tilt, as a share of the icon side, for depth 1.
const SHIFT:=.055

var host:TextureRect
var key:=""
var parts:Array=[]
var tint:=Color.WHITE
var hover_target:Control
var press_source:BaseButton
var hovered:=false
var hover_from:Dictionary={}
var hover:=0.0
var tilt:=Vector2.ZERO
var clock:=-1.0
var leave_clock:=-1.0
var punch:=-1.0
var hidden_since:=-1.0

static func attach(rect:TextureRect,id:String)->KitIcon:
	var icon:KitIcon=rect.get_meta("kit_icon") if rect.has_meta("kit_icon") else null
	if not is_instance_valid(icon):
		icon=KitIcon.new();icon.name="KitIcon";icon.host=rect
		icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
		rect.add_child(icon,false,Node.INTERNAL_MODE_FRONT)
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rect.set_meta("kit_icon",icon)
	icon.show_icon(id)
	return icon

## Removes the icon and gives the host its own picture back (the host now shows something else).
func detach():
	if is_instance_valid(host):
		host.self_modulate=tint;host.remove_meta("kit_icon")
	queue_free()

## Plays the leave motion on every icon inside `node` (UiKit.leave calls this).
static func vanish_all(node:Node):
	if node is TextureRect and node.has_meta("kit_icon") and is_instance_valid(node.get_meta("kit_icon")):node.get_meta("kit_icon").vanish()
	for child in node.get_children():vanish_all(child)

func show_icon(id:String):
	if id==key:return
	key=id
	for part in parts:part.node.queue_free()
	parts.clear()
	var layers=IconKit.layers(id)
	if layers.is_empty():layers=[{"kind":"flat","texture":host.texture,"rect":Rect2(0,0,1,1)}]
	for layer in layers:
		var node=TextureRect.new();node.set_meta("kit_layer",true)
		node.texture=layer.texture;node.mouse_filter=Control.MOUSE_FILTER_IGNORE
		node.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		node.stretch_mode=host.stretch_mode if layer.kind=="flat" else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		node.flip_h=host.flip_h;node.texture_filter=host.texture_filter
		add_child(node)
		parts.append({"node":node,"kind":layer.kind,"rect":layer.rect})
	take_tint()
	if not resized.is_connected(layout):resized.connect(layout)
	layout()
	appear()

## The host keeps its texture for size and lookups but stops drawing it; its tint moves to the layers.
func take_tint():
	if host.self_modulate.a>0.0:tint=host.self_modulate
	host.self_modulate=Color(tint,0.0)
	apply()

func _ready():
	find_targets.call_deferred()

func _notification(what):
	if what==NOTIFICATION_VISIBILITY_CHANGED:
		var now=Time.get_ticks_msec()/1000.0
		if not is_visible_in_tree():hidden_since=now
		elif hidden_since>=0.0 and now-hidden_since>.25:hidden_since=-1.0;appear()

## Hover follows the nearest button above the icon, else the nearest mouse-aware panel that is not much
## bigger than the icon (a reward card, a station tile). Select follows that button, or the biggest button
## lying directly in that panel (cards keep their button as a sibling of the icon).
func find_targets():
	await get_tree().process_frame
	if not is_instance_valid(host) or not is_inside_tree():return
	var node:Node=host
	while node is Control:
		if node is BaseButton:press_source=node;hover_target=node;break
		node=node.get_parent()
	if hover_target==null:
		node=host
		while node is Control:
			var control:Control=node
			if control.mouse_filter!=Control.MOUSE_FILTER_IGNORE:
				if control.size.x*control.size.y<=maxf(host.size.x*host.size.y,1.0)*16.0:hover_target=control
				break
			node=node.get_parent()
		if hover_target:
			for child in hover_target.get_children():
				if child is BaseButton and (press_source==null or child.size.x*child.size.y>press_source.size.x*press_source.size.y):press_source=child
	# A button lying over the panel takes the mouse, so both report hover.
	var sources=[]
	for source in [hover_target,press_source]:
		if source!=null and source not in sources:sources.append(source)
	for source in sources:
		source.mouse_entered.connect(func():hover_from[source]=true;hovered=true;wake())
		source.mouse_exited.connect(func():hover_from.erase(source);hovered=not hover_from.is_empty();wake())
	if press_source:press_source.button_down.connect(select)

func appear():
	leave_clock=-1.0
	if not UiKit.motion_enabled():clock=-1.0;apply();return
	clock=0.0;wake()

func select():
	if not UiKit.motion_enabled():return
	punch=0.0;wake()

func vanish():
	if not UiKit.motion_enabled():return
	leave_clock=0.0;wake()

func wake():
	set_process(true)

## A host can ask for room around the picture: meta "icon_inset" is the share of the side left free on each
## edge (cards inset the icon inside the rarity frame).
func layout():
	var side=minf(size.x,size.y)*(1.0-2.0*float(host.get_meta("icon_inset",0.0)))
	var origin=(size-Vector2.ONE*side)*.5
	for part in parts:
		var rect:Rect2=part.rect
		part["base"]=Rect2(origin+rect.position*side,rect.size*side)
	apply()

func _process(delta):
	if clock>=0.0:
		clock+=delta
		if clock>APPEAR+STAGGER*parts.size():clock=-1.0
	if leave_clock>=0.0:leave_clock=minf(leave_clock+delta,LEAVE+STAGGER*parts.size())
	if punch>=0.0:
		punch+=delta
		if punch>PUNCH:punch=-1.0
	hover=move_toward(hover,1.0 if hovered else 0.0,delta*6.0)
	var aim=Vector2.ZERO
	if hovered and is_instance_valid(hover_target) and hover_target.size.x>0:
		aim=((hover_target.get_local_mouse_position()/hover_target.size)-Vector2.ONE*.5)*2.0
		aim=aim.clamp(-Vector2.ONE,Vector2.ONE)
	tilt=tilt.lerp(aim,minf(1.0,delta*10.0))
	apply()
	if clock<0.0 and punch<0.0 and not hovered and hover<=0.0 and tilt.length()<.002 and leave_clock<0.0:
		tilt=Vector2.ZERO;apply();set_process(false)

static func back_out(t:float)->float:
	var c=1.70158;t-=1.0
	return 1.0+(c+1.0)*t*t*t+c*t*t

func apply():
	var side=minf(size.x,size.y)*(1.0-2.0*float(host.get_meta("icon_inset",0.0)))
	var count=parts.size()
	var hit=sin(PI*punch/PUNCH) if punch>=0.0 else 0.0
	for i in count:
		var part=parts[i]
		if not part.has("base"):continue
		var base:Rect2=part.base
		var kind:String=part.kind
		var scale_k=1.0;var alpha=1.0;var offset=Vector2.ZERO;var bright=1.0
		if clock>=0.0:
			var p=clampf((clock-i*STAGGER)/APPEAR,0.0,1.0);var e=back_out(p)
			var start={"face":.7,"symbol":.85,"rim":1.18,"badge":.4,"aura":.6,"flat":.7}.get(kind,.8)
			scale_k=lerpf(start,1.0,e);alpha=clampf(p*1.8,0.0,1.0)
			if kind=="symbol":offset.y-=side*.2*(1.0-e)
			elif kind=="flat":offset.y-=side*.06*(1.0-e)
		if leave_clock>=0.0:
			var q=clampf((leave_clock-(count-1-i)*STAGGER)/LEAVE,0.0,1.0);var e2=q*q
			scale_k*=lerpf(1.0,.72,e2);alpha*=1.0-e2;offset.y+=side*.1*e2
		offset+=tilt*DEPTH.get(kind,.5)*side*SHIFT*hover
		if kind in ["symbol","flat"]:scale_k*=1.0+.05*hover+.14*hit
		elif kind=="badge":scale_k*=1.0+.08*hover+.1*hit
		elif kind=="face":scale_k*=1.0-.05*hit
		elif kind=="rim":bright=1.0+.5*hit
		if kind=="aura":alpha*=clampf(.5*hover+.7*hit,0.0,1.0)
		var node:TextureRect=part.node
		node.position=base.position+offset;node.size=base.size
		node.pivot_offset=base.size*.5;node.scale=Vector2.ONE*scale_k
		node.modulate=Color(tint.r*bright,tint.g*bright,tint.b*bright,tint.a*alpha)
