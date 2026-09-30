extends Control
var arena
var button:Button
var display:Control
var icon:TextureRect
var automatics:Array=[]
const DISPLAY=preload("res://scripts/ui/skill_display.gd")
func _ready():
	size=Vector2(264,110)
	button=UiKit.button(self,"",Vector2.ZERO,Vector2(76,76),func():arena.headquarters.cast())
	display=DISPLAY.new();button.add_child(display)
	icon=UiKit.icon(button,"vehicle",Vector2(14,14),Vector2(48,48))
	UiKit.label(self,"Штаб",Vector2(0,-22),Vector2(76,20),12).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	for i in range(2):
		var panel=UiKit.panel(self,Vector2.ZERO,Vector2(76,76),UiKit.CREAM)
		var sector=DISPLAY.new();sector.key_hint="";panel.add_child(sector)
		var picture=UiKit.icon(panel,"heart",Vector2(14,14),Vector2(48,48))
		automatics.append({"panel":panel,"display":sector,"icon":picture})
func _process(_delta):
	var hero_count=arena.abilities.slots.size();var total=hero_count+arena.headquarters.loadout().size()
	position=Vector2((get_viewport_rect().size.x-(total*88-12))*.5+hero_count*88,get_viewport_rect().size.y-112)
	var hq=arena.headquarters;var id=hq.active
	visible=arena.phase in ["combat","countdown"] and (id!="" or not hq.modules.is_empty())
	button.visible=id!="" and HQCatalog.DATA[id].mode=="active"
	display.action="hq_ability" if button.visible else "";display.remaining=hq.cooldown
	if button.visible:
		icon.texture=UiKit.icon_texture(id)
		button.tooltip_text=HQCatalog.DATA[id].name+"\n"+HQCatalog.DATA[id].description
		display.cooling=hq.cooldown>0;display.active=hq.shield_time if id=="hq_field" else hq.emp_time if id=="hq_emp" else 0.0
		display.progress=clampf(1-hq.cooldown/HQCatalog.interval(id,hq.level(id)),0,1);display.queue_redraw()
	for i in range(2):
		var slot=automatics[i];slot.panel.visible=i<hq.modules.size()
		if not slot.panel.visible:continue
		var module=hq.modules[i];var data=HQCatalog.DATA[module]
		slot.panel.position=Vector2((i+int(button.visible))*88,0)
		slot.icon.texture=UiKit.icon_texture(module);slot.panel.tooltip_text=data.name+"\n"+data.description
		var exhausted=module=="hq_supply" and int(hq.delivered.get(module,0))>=1+int(hq.level(module)/3)
		var remaining=float(hq.timers.get(module,0))
		slot.display.key_hint="";slot.display.action="";slot.display.active=0
		slot.display.cooling=data.mode=="auto" and remaining>0 and not exhausted;slot.display.remaining=remaining
		slot.display.progress=clampf(1-remaining/HQCatalog.interval(module,hq.level(module)),0,1)
		slot.display.queue_redraw();slot.icon.modulate.a=.45 if exhausted else 1.0
		if exhausted:slot.panel.tooltip_text+="\nЛимит поля боя исчерпан"
