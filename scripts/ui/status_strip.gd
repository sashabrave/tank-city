extends HBoxContainer
## The soldier's active effects as small chips next to the health panel: icon with a cooldown-style sector
## (scripts/ui/timer_sector.gd). Timers are read from the arena; the full length of a timer is remembered when
## it starts, so the sector drains correctly without each system reporting durations. A chip fades in and out, never pops.
const CHIP=Vector2(34,34)
var arena
var chips:={}
var totals:={}

## id → [icon, getter returning remaining seconds (or -1 for "active, no timer")]. «until − now» timers are
## clamped at 0: a negative leftover would read as "active" and keep the chip forever.
func entries()->Dictionary:
	var run=arena.run;var p=arena.player;var ab=arena.abilities
	return {
		"invulnerable":["shield",func():return p.invulnerable if is_instance_valid(p) and p.invulnerable>.7 else 0.0],
		"star":["star",func():return arena.star_time],
		"shield":["barrier",func():return ab.shield_time],
		"cloak":["cloak",func():return ab.cloak_time],
		"freeze":["freeze",func():return arena.freeze_time],
		"landing":["vehicle",func():return maxf(0.0,run.landing_until-arena.elapsed)],
		"opening":["damage",func():return maxf(0.0,run.opening_until-arena.elapsed)],
		"dash":["speed",func():return maxf(0.0,run.dash_until-arena.elapsed)],
		"trench":["wall",func():return -1.0 if is_instance_valid(p) and (p.hidden_in_trench or p.occupying_trench) else 0.0],
	}

func _ready():
	add_theme_constant_override("separation",6);mouse_filter=Control.MOUSE_FILTER_PASS

func _process(delta):
	if not is_instance_valid(arena) or arena.run==null:return
	var shown=arena.phase in ["combat","countdown"]
	for id in entries():
		var entry=entries()[id]
		var left=float(entry[1].call()) if shown else 0.0
		var active=left>0 or left<0
		if active and not chips.has(id):add_chip(id,entry[0])
		if not chips.has(id):continue
		var chip:Control=chips[id]
		if active:
			if left>0:totals[id]=maxf(float(totals.get(id,0.0)),left)
			chip.get_node("Sector").set_remaining(clampf(left/float(totals.get(id,left)),0,1) if left>0 else -1.0)
			chip.modulate.a=minf(1.0,chip.modulate.a+delta*8.0)
			# The last second blinks so the end is never a surprise.
			if left>0 and left<1.0:chip.modulate.a=.45+.55*absf(sin(arena.elapsed*10.0))
		else:
			totals.erase(id)
			chip.modulate.a-=delta*6.0
			if chip.modulate.a<=0:chips.erase(id);chip.queue_free()

const HINTS={"invulnerable":"Неуязвимость","star":"Звезда: неуязвимость и мощный огонь","shield":"Щит: блокирует попадания","cloak":"Маскировка: враги не видят","freeze":"Враги заморожены","landing":"Десант: пули мимо, крит выше","opening":"Выдержка: первый выстрел сильнее","dash":"Рывок","trench":"В окопе: урон меньше"}
func add_chip(id:String,icon:String):
	var chip=Panel.new();chip.name="Chip_"+id;chip.custom_minimum_size=CHIP;chip.mouse_filter=Control.MOUSE_FILTER_PASS;chip.tooltip_text=Texts.localized(HINTS.get(id,""))
	chip.add_theme_stylebox_override("panel",UiKit.style(Color("1f2822e6"),8,Color(1,1,1,.12)));chip.modulate.a=0
	var art=TextureRect.new();chip.add_child(art);art.texture=UiKit.icon_texture(icon);art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.position=Vector2(7,7);art.size=Vector2(20,20);art.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var sector=preload("res://scripts/ui/timer_sector.gd").new();sector.name="Sector";chip.add_child(sector);sector.position=Vector2(2,2);sector.size=CHIP-Vector2(4,4);sector.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(chip);chips[id]=chip
