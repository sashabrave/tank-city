extends Node3D
var arena
var timer=1.35
var damage=3.0
var spent=false
var label: Label3D
func _ready():
	Visuals.box(self,Vector3(0,.18,0),Vector3(.42,.30,.42),Color("a4472f"))
	label=Visuals.label3d(self,"Бомба",Vector3(0,.85,0),Color("ffbd84"),27)
func _physics_process(delta):
	if spent or arena.phase!="combat":return
	timer-=delta
	Texts.set_text(label,"%.1f" % maxf(0,timer))
	if timer<=0:detonate()
func detonate():
	if spent:return
	spent=true;arena.bombs.erase(self)
	arena.explosion(position,damage)
	queue_free()
