extends Node3D
## Visual/audio warning owns no gameplay randomness or damage state.
var remaining=0.0
var cooldown=0.0
var clock=0.0
var bulbs:Array=[]
var lights:Array=[]
func _ready():
	name="BaseAlert"
	for x in [-.37,.37]:
		var bulb=Visuals.box(self,Vector3(x,1.23,.18),Vector3(.12,.10,.12),Color("651c19"))
		bulb.material_override=Visuals.material(Color("651c19"),true);bulb.material_override.emission_energy_multiplier=0;bulbs.append(bulb)
		var light=OmniLight3D.new();light.position=bulb.position;light.light_color=Color("ff3020");light.omni_range=1.8;light.shadow_enabled=false;light.hide();add_child(light);lights.append(light)
	set_process(false)
func trigger():
	remaining=4.2
	if cooldown<=0:Game.sound("base_alert",self);cooldown=5.0
	set_process(true)
func _process(delta):
	clock+=delta;cooldown=maxf(0,cooldown-delta);remaining=maxf(0,remaining-delta)
	var context=get_parent().get_parent()
	if context.get("phase")!=null and context.get("phase")!="combat":remaining=0
	for i in range(lights.size()):
		var pulse=pow(.5+.5*sin(clock*TAU*1.1+i*PI),3) if remaining>0 else 0.0
		lights[i].visible=remaining>0;lights[i].light_energy=pulse*.85
		bulbs[i].material_override.emission_energy_multiplier=pulse*2.5
	if remaining<=0 and cooldown<=0:set_process(false)
