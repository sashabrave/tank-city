extends Node3D
## Guide arrow of the rooms between fields (T-226): yellow over the place where the room's upgrade is taken while
## it is not taken yet, green over the exit once it is. The same soft marker as the hub's build arrows (a chevron
## on a disc), a little bigger, bobbing slowly. Visual only.
const BOB_PERIOD:=1.6
const BOB_HEIGHT:=.16
var arrow:Label3D
var disc:Label3D
var clock:=0.0
var base_y:=0.0
## Which marker shows: "goal" (yellow, take the upgrade here) or "ready" (green, the exit).
var kind:=""
static func attach(parent:Node3D)->Node3D:
	var guide=load("res://scripts/room_guide_arrow.gd").new();guide.name="GuideArrow";parent.add_child(guide);return guide
func _ready():
	arrow=Visuals.label3d(self,"⌄",Vector3.ZERO,Color("fff8e2"),84);arrow.outline_size=0;arrow.no_depth_test=true;arrow.render_priority=2
	disc=Visuals.label3d(arrow,"●",Vector3(0,.03,-.01),UiKit.NOTICE.goal,128);disc.modulate.a=.7;disc.outline_size=0;disc.no_depth_test=true;disc.render_priority=1
	visible=false
## Shows the arrow over `at` (its tip about `height` above the floor) in the colour of `marker`.
func point(at:Vector3,height:float,marker:String):
	position=at;base_y=height;visible=true
	if marker==kind:return
	kind=marker;disc.modulate=Color(UiKit.NOTICE.get(marker,UiKit.NOTICE.goal),.7)
func hide_arrow():visible=false;kind=""
func _process(delta):
	if not visible:return
	clock+=delta
	arrow.position.y=base_y+(1-cos(clock*TAU/BOB_PERIOD))*BOB_HEIGHT
