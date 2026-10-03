extends Node3D
## Closed fortune booth (RoomLayout): a shuttered kiosk with a dim lamp; E says the fortune is closed today.
func _ready():
	var olive=Color("59603f")
	Visuals.box(self,Vector3(0,.8,0),Vector3(1.0,1.6,.7),olive,"paint")
	Visuals.box(self,Vector3(0,.95,.36),Vector3(.8,.9,.04),Color("6c777b"),"steel")
	for i in range(5):Visuals.box(self,Vector3(0,.6+i*.18,.39),Vector3(.8,.03,.02),Color("4a5257"),"gunmetal")
	Visuals.box(self,Vector3(0,1.72,0),Vector3(1.1,.16,.8),olive.darkened(.2),"paint")
	var lamp=Visuals.box(self,Vector3(.32,1.55,.38),Vector3(.12,.08,.04),Color("ffd27a"));lamp.material_override=Visuals.material(Color("8a6a2a"),true)
func near(avatar:Node3D)->bool:return avatar.global_position.distance_to(global_position)<1.5
func use(_root:Control,done:Callable):
	var room=get_parent()
	if room and "arena" in room and is_instance_valid(room.arena):room.arena.toast(Texts.render("Фортуна сегодня закрыта"))
	done.call()
