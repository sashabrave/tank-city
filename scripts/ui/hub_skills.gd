extends Control
var hub
var buttons:Array=[]
var support:Array=[]
var cooldowns:Dictionary={}
var active_times:Dictionary={}
func _ready():
	size=Vector2(170,105)
	for i in range(3):
		var button=UiKit.button(self,"",Vector2(i*88,0),Vector2(76,76),func():cast(i));buttons.append(button)
		var display=preload("res://scripts/ui/skill_display.gd").new();display.name="CooldownDisplay";button.add_child(display)
		UiKit.icon(button,"barrier",Vector2(14,14),Vector2(48,48)).name="Icon"
	for i in range(3):
		var tile=UiKit.panel(self,Vector2.ZERO,Vector2(76,76));support.append(tile)
		var display=preload("res://scripts/ui/skill_display.gd").new();display.name="CooldownDisplay";tile.add_child(display)
		UiKit.icon(tile,"heart",Vector2(14,14),Vector2(48,48)).name="Icon"
func _process(delta):
	var hero_count=Game.hero_loadout().size();var loadout=Game.hq_loadout()
	position=Vector2((get_viewport_rect().size.x-((hero_count+loadout.size())*88-12))*.5,get_viewport_rect().size.y-112)
	for i in range(support.size()):
		var tile=support[i];tile.visible=i<loadout.size()
		if not tile.visible:continue
		var id=loadout[i];tile.position=Vector2((hero_count+i)*88,0);tile.get_node("Icon").texture=UiKit.icon_texture(id)
		var display=tile.get_node("CooldownDisplay");display.key_hint="";display.queue_redraw();tile.tooltip_text=HQCatalog.DATA[id].name+" / в вылазке"
	for id in cooldowns:cooldowns[id]=maxf(0,cooldowns[id]-delta)
	for id in active_times:active_times[id]=maxf(0,active_times[id]-delta)
	visible=hub.phase=="combat"
	for i in range(3):
		var button=buttons[i];button.visible=i<Game.hero_loadout().size()
		if not button.visible:continue
		var id=Game.hero_loadout()[i];var data=AbilityCatalog.DATA[id];var remaining=cooldowns.get(id,0.0)
		button.get_node("Icon").texture=UiKit.icon_texture(id);button.tooltip_text=data.name+"\n"+data.description
		var display=button.get_node("CooldownDisplay");display.key_hint=OS.get_keycode_string(Settings.keys[Game.ability_action(i)])
		display.cooling=remaining>0;display.progress=1-remaining/(data.cooldown+(4.0 if id=="shield" else 0));display.active=active_times.get(id,0.0);display.queue_redraw()
		if i==0:hub.training_ability_cooldown=remaining
func cast(slot:int):
	if hub.phase!="combat" or slot>=Game.hero_loadout().size():return
	var id=Game.hero_loadout()[slot]
	if cooldowns.get(id,0)>0 or not Game.ability_available(id):return
	var effect=load("res://scripts/hub_ability_effect.gd").new();effect.hub=hub;effect.kind=id;hub.add_child(effect)
	if not effect.accepted:effect.queue_free();return
	var duration=4.0 if id=="shield" else float(AbilityCatalog.DATA[id].power) if id=="cloak" else 0.0
	active_times[id]=duration;cooldowns[id]=AbilityCatalog.DATA[id].cooldown+(duration if id=="shield" else 0.0)
	hub.training_ability_cooldown=cooldowns[id]
