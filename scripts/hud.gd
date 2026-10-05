extends CanvasLayer
const LOOT=preload("res://scripts/loot_catalog.gd")
var arena
var root: Control
var top: Panel
var health: Control
var base_health: Control
var armor_meter: Control
var wave_label: Label
var enemy_label: Label
var stage_pips:Control
var star_mark:Label
## Ammo cells in the weapon panel (scripts/combat/ammo.gd): the loaded types, the active one framed.
var ammo_row:HBoxContainer
var ammo_signature:=""
var wave_pips:Control
var credits: Label
var tip: Label
var countdown: Label
var vehicle_label: Label
var interact_button: Button
var dpad: Control
var fire_pad: Control
var modal: Control
var choice_epoch=0
var choice_tween:Tween
var left_info: Panel
var right_info: Panel
var footer: Label
var title: Label
var pause_button: Button
var last_size=Vector2.ZERO
var intercept_label: Label
var skill_buttons:Array=[]
## HQ modules as round icons at the end of the ability row (T-299).
var hq_strip:Control
var weapon_bars:Control
var transport_panel:Panel
var transport_title:Label
var transport_bars:Control
var transport_tween:Tween
var showing_transport=false
var boss_bar2:ProgressBar
var boss_title2:Label
var boss_bar: ProgressBar
var boss_title: Label
var ability_button: Button
var star_label: Label
var biome_panel:Panel
var biome_label:Label
var weapon_icon: TextureRect
var ability_icon: TextureRect

var status_strip:HBoxContainer
## One HUD on every playground (one field engine): the view follows the arena's playground (sync_view).
##   "battle" — a field of a sortie or the sandbox: everything, with the field/wave panel and the biome card;
##   "room"   — a room between fields (service): no field/wave panel or biome card, the room's heading stands there;
##   "hub"    — the hub's practice run: health, weapon panel and the ability row with the HQ module circles set under
##              the hub's logo and tools, no field panel, no pause button or task tracker (Esc opens the tablet,
##              tasks live on the command screen), no HQ row in the health panel.
var view:="battle"
const HUB_DROP:=236.0
## No HQ on the hub field: the health panel keeps only the hero's row.
const HUB_TRIM:=45.0
static func view_for(mode:String)->String:return {"service":"room","hub":"hub"}.get(mode,"battle")
func sync_view():
	var next:=view_for(arena.ground_mode())
	if next==view:return
	var s=(1.0 if next=="hub" else 0.0)-(1.0 if view=="hub" else 0.0)
	view=next
	if s!=0.0:
		top.offset_top+=s*HUB_DROP;top.offset_bottom+=s*(HUB_DROP-HUB_TRIM)
		left_info.offset_top+=s*(HUB_DROP-HUB_TRIM);left_info.offset_bottom+=s*(HUB_DROP-HUB_TRIM)
		transport_panel.position.y+=s*(HUB_DROP-HUB_TRIM)
	pause_button.visible=view!="hub"
	right_info.visible=view=="battle"
## How far the left column sits lower than in battle (the hub's logo and tools are above it).
func panel_drop()->float:return HUB_DROP-HUB_TRIM if view=="hub" else 0.0
## Ability tiles follow the slots (a practice run rebuilt after a station change, the sandbox's own loadout).
func refresh_skill_icons():
	for i in range(skill_buttons.size()):
		skill_buttons[i].visible=i<arena.abilities.slots.size()
		if skill_buttons[i].visible:skill_buttons[i].get_node("Icon").texture=UiKit.trimmed(UiKit.icon_texture("abilities/"+str(arena.abilities.slots[i])))
func _ready():
	add_to_group("battle_message_anchor")
	root=$Layout
	top=root.get_node("HealthPanel");health=top.get_node("HeroHealth");base_health=top.get_node("BaseHealth")
	# Active effects of the soldier: chips with draining bars to the right of the health panel.
	status_strip=preload("res://scripts/ui/status_strip.gd").new();status_strip.name="StatusStrip";status_strip.arena=arena;root.add_child(status_strip)
	left_info=root.get_node("WeaponPanel");weapon_icon=left_info.get_node("WeaponIcon");vehicle_label=left_info.get_node("WeaponName");intercept_label=left_info.get_node("WeaponStats");armor_meter=left_info.get_node("VehicleHealth")
	right_info=root.get_node("RoomPanel");wave_label=right_info.get_node("StageLabel");enemy_label=right_info.get_node("WaveLabel");right_info.get_node("EnemyRoster").arena=arena
	star_mark=Label.new();right_info.add_child(star_mark);star_mark.name="StarMark";star_mark.mouse_filter=Control.MOUSE_FILTER_IGNORE
	star_mark.add_theme_font_size_override("font_size",15);star_mark.add_theme_color_override("font_color",Color("f1eedb"))
	stage_pips=preload("res://scripts/ui/pip_strip.gd").new();right_info.add_child(stage_pips);wave_pips=preload("res://scripts/ui/pip_strip.gd").new();right_info.add_child(wave_pips)
	pause_button=root.get_node("PauseButton");pause_button.pressed.connect(func():arena.pause_battle())
	pause_button.text="";pause_button.icon=UiKit.interface_icon("pause");pause_button.expand_icon=true;pause_button.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER;pause_button.add_theme_constant_override("icon_max_width",22)
	dpad=root.get_node("MovePad");dpad.apply_movement_layout();fire_pad=root.get_node("FirePad")
	ability_button=root.get_node("LegacyAbility")
	star_label=root.get_node("StarLabel");interact_button=root.get_node("InteractButton");interact_button.pressed.connect(func():arena.interact());interact_button.hide()
	tip=root.get_node("TipLabel");countdown=root.get_node("CountdownLabel");footer=root.get_node("FooterLabel")
	boss_bar=root.get_node("BossHealth");boss_title=root.get_node("BossName");boss_bar2=root.get_node("SecondBossHealth");boss_title2=root.get_node("SecondBossName")
	for widget in [boss_bar,boss_title,boss_bar2,boss_title2]:widget.position.y+=52
	# Labels over the 3D field keep their own contrast, independently of panel theme.
	for label in [boss_title,boss_title2,countdown,star_label,tip,footer]:
		label.set_meta("keep_theme_colors",true)
		label.add_theme_color_override("font_color",UiKit.INK)
		label.add_theme_color_override("font_shadow_color",Color(0,0,0,.8))
		label.add_theme_constant_override("shadow_offset_y",2)
	for bar in [boss_bar,boss_bar2]:
		bar.set_meta("keep_theme_colors",true)
		var background=StyleBoxFlat.new();background.bg_color=Color(1,1,1,.32);background.set_corner_radius_all(5)
		var fill=StyleBoxFlat.new();fill.bg_color=Color("e34e4b");fill.set_corner_radius_all(5)
		bar.add_theme_stylebox_override("background",background);bar.add_theme_stylebox_override("fill",fill)

	# Two hero buttons: the class ability on Q and the gadget on F (one class slot since 4 Oct 2026).
	root.get_node("Skills").add_theme_constant_override("separation",12)
	for i in range(2):
		var button=root.get_node("Skills/Skill"+str(i+1));skill_buttons.append(button);button.pressed.connect(func():arena.abilities.cast_slot(i))
		button.visible=i<arena.abilities.slots.size()
		if i<arena.abilities.slots.size():button.get_node("Icon").texture=UiKit.trimmed(UiKit.icon_texture("abilities/"+str(arena.abilities.slots[i])))
	intercept_label.hide();left_info.size.y=168;armor_meter.hide()
	weapon_bars=UiKit.stat_bars(left_info,Vector2(14,66),205,[],32)
	transport_panel=UiKit.panel(root,Vector2(-250,135),Vector2(235,194));transport_panel.name="TransportPanel";transport_panel.hide()
	UiKit.icon(transport_panel,"vehicle",Vector2(14,8),Vector2(42,42))
	transport_title=UiKit.label(transport_panel,"",Vector2(65,12),Vector2(155,34),16)
	transport_bars=UiKit.stat_bars(transport_panel,Vector2(14,58),205,[],25)
	transport_bars.mouse_filter=Control.MOUSE_FILTER_PASS

	for i in range(skill_buttons.size()):
		var button=skill_buttons[i];Texts.set_text(button,"")
		var display=preload("res://scripts/ui/skill_display.gd").new();display.name="CooldownDisplay";button.add_child(display);button.move_child(display,0)
		display.action=Game.ability_action(i)
		button.get_node("Icon").position=Vector2(14,14);button.get_node("Icon").size=Vector2(48,48)
	hq_strip=preload("res://scripts/headquarters/battle_panel.gd").new();hq_strip.name="HQModules";hq_strip.arena=arena;root.add_child(hq_strip)
	var tracker=preload("res://scripts/progression/quest_tracker.gd").new();tracker.hud=self;root.add_child(tracker)

	biome_panel=UiKit.panel(root,Vector2(20,320),Vector2(235,78))
	biome_label=UiKit.label(biome_panel,"",Vector2(12,8),Vector2(211,62),13)
	biome_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	# Every top-level HUD panel is frosted glass, like the rest of the interface (T-042).
	for child in root.get_children():
		if child is Panel:UiKit.glassify(child)
	_layout()

func _layout():
	last_size=get_viewport().get_visible_rect().size
	# Anchors and authored offsets own layout. Only platform safe area is applied here.
	if OS.has_feature("ios"):
		var safe=DisplayServer.get_display_safe_area();var screen=DisplayServer.screen_get_size()
		if screen.x>0:
			root.offset_left=safe.position.x*last_size.x/screen.x
			root.offset_right=-(screen.x-safe.end.x)*last_size.x/screen.x

var refresh_elapsed=0.0
func _process(_delta):
	if is_instance_valid(status_strip) and is_instance_valid(top):status_strip.position=top.position+Vector2(top.size.x+10,top.size.y*.5-17)
	refresh_elapsed+=_delta
	if refresh_elapsed<.05:return
	refresh_elapsed=0.0
	update_challenge_timer()
	var hero_count=arena.abilities.slots.size()
	# The row is centred as a whole: hero tiles, then the round HQ module icons (T-299).
	var tiles_w=maxi(0,hero_count*88-12);var total_w=tiles_w+hq_strip.strip_width(arena,hero_count>0)
	var strip=root.get_node("Skills");strip.set_anchors_preset(Control.PRESET_TOP_LEFT);strip.position=Vector2((get_viewport().get_visible_rect().size.x-total_w)*.5,get_viewport().get_visible_rect().size.y-112);strip.size=Vector2(tiles_w,76)
	hq_strip.strip_origin=strip.position+Vector2(tiles_w+(hq_strip.GAP if hero_count>0 else 0.0),0);hq_strip.strip_height=76.0
	for i in range(skill_buttons.size()):skill_buttons[i].visible=i<hero_count
	var data=preload("res://scripts/ui/battle_snapshot.gd").capture(arena)
	boss_bar.hide();boss_title.hide();boss_bar2.hide();boss_title2.hide()
	for i in range(mini(2,data.bosses.size())):
		var boss=data.bosses[i];var bar=boss_bar if i==0 else boss_bar2;var label=boss_title if i==0 else boss_title2
		bar.show();label.show();bar.max_value=boss.max_hp;bar.value=boss.hp;Texts.set_text(label,boss.title)
	if get_viewport().get_visible_rect().size!=last_size:_layout()
	health.set_health(data.hero_hp,data.hero_max);base_health.visible=not arena.hq_off_field();base_health.set_health(data.base_hp,data.base_max)
	dpad.visible=InputScheme.touch();fire_pad.visible=InputScheme.touch();biome_panel.visible=Settings.values.biome_info and view=="battle"
	# A room or the hub: the playground's own heading stands where the field and waves are shown.
	right_info.visible=view=="battle"
	Texts.set_text(biome_label,arena.BIOMES.caption(arena.run_seed,arena.room_index,arena.room_lane()))
	# Progress reads as pips: fields of the route and waves of the room; words only where they add meaning.
	var plain=not arena.sandbox and not data.boss_room and not Campaign.endless
	# The arena's difficulty stars sit right after the title (T-023), before the stage pips.
	var stars=EncounterRules.STARS[clampi(arena.room.difficulty,0,2)] if not arena.sandbox and not data.boss_room else ""
	Texts.set_text(wave_label,"Песочница" if arena.sandbox else "Босс мира" if data.boss_room else "Поле" if plain else "Поле %d" % data.stage)
	# Stars are a smaller mark after the title; the pips take whatever width is left in the panel (T-078).
	star_mark.visible=stars!="";star_mark.text=stars
	star_mark.position=Vector2(wave_label.position.x+text_width(wave_label)+6,wave_label.position.y+wave_label.size.y*.5-star_mark.size.y*.5)
	var after_title=(star_mark.position.x+star_mark.get_minimum_size().x if star_mark.visible else wave_label.position.x+text_width(wave_label))+12
	stage_pips.visible=plain;stage_pips.set_state(6,data.stage-1,data.stage-1,-1,right_info.size.x-20-after_title)
	stage_pips.position=Vector2(after_title,wave_label.position.y+wave_label.size.y*.5-stage_pips.size.y*.5)
	var waves=not arena.sandbox and not arena.challenges.active() and not data.boss_room
	wave_pips.visible=waves
	if arena.sandbox and not arena.challenges.active():Texts.set_text(enemy_label,"F2 — админ")
	elif arena.challenges.active():Texts.set_text(enemy_label,arena.challenges.status())
	elif data.boss_room:Texts.set_text(enemy_label,BossCatalog.encounter(arena.run_seed,arena.room_index).name)
	else:
		Texts.set_text(enemy_label,"Волна")
		var wave_x=enemy_label.position.x+text_width(enemy_label)+12
		# The commander comes after the last wave: a big dot at the end; waves count as done while he is out.
		var fighting_commander=data.commander>0
		wave_pips.set_state(3,3 if fighting_commander else data.wave-1,-1 if fighting_commander else data.wave-1,data.commander,right_info.size.x-20-wave_x)
		wave_pips.position=Vector2(wave_x,enemy_label.position.y+enemy_label.size.y*.5-wave_pips.size.y*.5)
	tip.hide();Texts.set_text(star_label,"★ Звезда · %.1f с" % data.star);star_label.visible=data.star>0
	refresh_ammo()
	ability_button.hide()
	for i in range(skill_buttons.size()):
		var button=skill_buttons[i];var skill=data.skills[i]
		button.disabled=skill.disabled;Texts.set_text(button,"");button.tooltip_text=skill.hint
		var display=button.get_node("CooldownDisplay");display.action=arena.abilities.action_for(i);display.progress=skill.progress;display.cooling=skill.cooling;display.remaining=skill.get("remaining",0.0);display.active=skill.active;display.detonate=skill.get("detonate",false);display.queue_redraw()
	# The digits wait for the arrival: they start once the soldier has landed (battle_stage.hop_out).
	countdown.visible=data.phase=="countdown" and not arena.get_meta("intro_lock",false)
	if countdown.visible:Texts.set_text(countdown,str(data.countdown))
	if not data.player.is_empty():
		var player=data.player
		var weapon=LOOT.WEAPONS[arena.weapon];Texts.set_text(vehicle_label,weapon.name);armor_meter.hide()
		# Same weapon art as the tablet and arsenal (illustration set, transparent margins trimmed).
		var art=UiKit.trimmed(UiKit.icon_texture(arena.weapon))
		if weapon_icon.texture!=art:weapon_icon.texture=art;weapon_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;weapon_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var benchmark=preload("res://scripts/ui/weapon_benchmarks.gd").weapon(arena.weapon)
		var actual=preload("res://scripts/ui/weapon_benchmarks.gd").current_weapon(arena)
		weapon_bars.set_rows([["Урон",actual.damage,benchmark.damage],["Темп",actual.rate,benchmark.rate," /с"],["Напор",actual.intercept,benchmark.intercept,"%"]])
		weapon_bars.mouse_filter=Control.MOUSE_FILTER_PASS
		weapon_bars.tooltip_text=preload("res://scripts/ui/weapon_benchmarks.gd").hint(arena.weapon)+" Напор: шанс против снаряда с силой 1."
		set_transport_visible(not player.infantry)
		if not player.infantry:
			var vehicle_benchmark=preload("res://scripts/ui/weapon_benchmarks.gd").vehicle(arena.player.kind)
			Texts.set_text(transport_title,player.name+(" · трофей" if arena.player.vehicle_origin=="captured" else ""))
			transport_bars.set_rows([["Броня",player.hp,player.max_hp," / "+UiKit.number(player.max_hp)],["Урон",arena.player.damage,vehicle_benchmark.damage],["Темп",1.0/arena.player.fire_interval,vehicle_benchmark.rate," /с"],["Напор",arena.combat.current_intercept()*100,vehicle_benchmark.intercept,"%"],["Скорость",arena.player.speed,vehicle_benchmark.speed]])
			transport_bars.tooltip_text="Ориентир сильной сборки: %s урона, %s выстр./с, %s скорости. Полный хаб, танкист и доступные передышки. Шкала может быть превышена; броня показывает текущий запас защиты." % [UiKit.number(vehicle_benchmark.damage),UiKit.number(vehicle_benchmark.rate),UiKit.number(vehicle_benchmark.speed)]

	Texts.set_text(interact_button,data.interact_text);interact_button.disabled=data.interact_disabled
	dpad.enabled=data.phase in ["combat","countdown"];fire_pad.enabled=dpad.enabled

func text_width(label:Label)->float:
	return label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x
## Big countdown at the top centre in timed challenges (hold, survive).
var challenge_timer:Panel
func update_challenge_timer():
	var info=arena.challenges.timer() if arena.challenges!=null else {}
	if info.is_empty():
		if is_instance_valid(challenge_timer):challenge_timer.hide()
		return
	if not is_instance_valid(challenge_timer):
		challenge_timer=UiKit.glass(root,Vector2.ZERO,Vector2(260,76));challenge_timer.name="ChallengeTimer";challenge_timer.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var title=UiKit.label(challenge_timer,"",Vector2(16,8),Vector2(228,20),13,UiKit.MUTED);title.name="Title";title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var time=UiKit.label(challenge_timer,"",Vector2(16,26),Vector2(228,32),26);time.name="Time";time.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var track=ColorRect.new();track.name="Track";challenge_timer.add_child(track);track.position=Vector2(16,62);track.size=Vector2(228,4);track.color=Color(1,1,1,.14);track.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var fill=ColorRect.new();fill.name="Fill";track.add_child(fill);fill.size=Vector2(0,4);fill.color=UiKit.ORANGE;fill.mouse_filter=Control.MOUSE_FILTER_IGNORE
	challenge_timer.show()
	challenge_timer.position=Vector2((get_viewport().get_visible_rect().size.x-challenge_timer.size.x)*.5,54)
	var seconds=ceili(info.left)
	Texts.set_text(challenge_timer.get_node("Title"),info.title+(" · пауза" if info.paused else ""))
	challenge_timer.get_node("Time").text="%d:%02d" % [seconds/60,seconds%60]
	challenge_timer.get_node("Time").add_theme_color_override("font_color",UiKit.MUTED if info.paused else UiKit.INK)
	challenge_timer.get_node("Track/Fill").size.x=228.0*info.ratio
func close_modal():
	choice_epoch+=1
	if choice_tween and choice_tween.is_valid():choice_tween.kill()
	CardNavigation.transition_locked=false
	if is_instance_valid(modal):modal.get_parent().remove_child(modal);modal.queue_free();modal=null
	dpad.clear();fire_pad.clear()

func modal_base(kicker: String,heading: String,subtitle: String,height=410) -> Panel:
	close_modal()
	modal=Control.new();modal.add_to_group("selection_scope");root.add_child(modal);modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim=ColorRect.new();modal.add_child(dim);dim.color=Color(.10,.16,.12,.62);dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=get_viewport().get_visible_rect().size
	var panel=UiKit.glass(modal,Vector2(s.x/2-470,s.y/2-height/2.0),Vector2(940,height),UiKit.CREAM)
	UiKit.label(panel,kicker,Vector2(30,23),Vector2(850,25),14,UiKit.MUTED)
	UiKit.accent(UiKit.label(panel,heading,Vector2(30,60),Vector2(880,52),36))
	UiKit.label(panel,subtitle,Vector2(30,119),Vector2(880,30),18,UiKit.MUTED)
	return panel

func choice_screen(scene:String,kicker:String,heading:String,subtitle:String)->Panel:
	close_modal();modal=load("res://scenes/ui/"+scene+".tscn").instantiate();root.add_child(modal);modal.add_to_group("selection_scope")
	var panel=modal.get_node("Panel")
	panel.get_node("Kicker").text=kicker;panel.get_node("Heading").text=heading;UiKit.accent(panel.get_node("Heading"));panel.get_node("Subtitle").text=""
	return panel

func show_upgrades():
	close_modal()
	CardNavigation.lock_confirmation()
	var epoch=choice_epoch
	if is_instance_valid(arena.presentation) and arena.presentation.text_tween and arena.presentation.text_tween.is_running():
		await arena.presentation.text_tween.finished
	if not is_inside_tree() or epoch!=choice_epoch or arena.phase!="upgrade":
		if epoch==choice_epoch:CardNavigation.transition_locked=false
		return
	_show_upgrades_now()

func animate_choices(panel:Panel):
	CardNavigation.lock_confirmation()
	var buttons=panel.find_children("*","BaseButton",true,false)
	var disabled=[]
	for button in buttons:
		disabled.append(button.disabled);button.disabled=true
	panel.modulate.a=0
	choice_tween=create_tween().set_parallel(true)
	choice_tween.tween_property(panel,"modulate:a",1.0,.18)
	for i in range(3):
		var card=panel.get_node("Card"+str(i+1))
		var destination=card.position
		card.position.y+=24;card.modulate.a=0
		var delay=.09+i*.10
		choice_tween.tween_property(card,"position",destination,.30).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		choice_tween.tween_property(card,"modulate:a",1.0,.23).set_delay(delay)
	for i in range(buttons.size()):
		var button=buttons[i]
		var destination=button.position
		button.position.y+=14;button.modulate.a=0
		choice_tween.tween_property(button,"position",destination,.22).set_delay(.60+i*.025).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		choice_tween.tween_property(button,"modulate:a",1.0,.18).set_delay(.60+i*.025)
	var highest_tier=0
	for i in range(3):highest_tier=maxi(highest_tier,panel.get_node("Card"+str(i+1)).get_meta("reward_tier",0))
	choice_tween.tween_callback(func():Game.sound("reward_reveal_"+str(highest_tier),panel)).set_delay(.09)
	choice_tween.chain().tween_callback(func():
		for i in range(buttons.size()):buttons[i].disabled=disabled[i]
		CardNavigation.transition_locked=false)

func _show_upgrades_now():
	var panel=choice_screen("rewards_screen","","Выбери усиление",("Текущий ствол: "+LOOT.WEAPONS[arena.weapon].name) if arena.next_is_room else "Улучшение персонажа до конца вылазки.")
	arena.reward.prepare_upgrade_offers()
	panel.get_node("ReturnButton").visible=arena.next_is_room and not Campaign.endless
	panel.get_node("ReturnButton").pressed.connect(func():arena.return_to_field())
	for i in range(3):
		var offer=arena.upgrade_offers[i];var id=offer.id;var tier=offer.tier
		preload("res://scripts/ui/choice_card.gd").configure(panel.get_node("Card"+str(i+1)),arena.reward.upgrade_card(offer),func():arena.apply_upgrade(id,tier))
	var reroll=panel.get_node("RerollButton");Texts.set_text(reroll,"Переброс · осталось %d" % arena.rerolls_left)
	reroll.pressed.connect(func():arena.reroll_cards());reroll.disabled=arena.rerolls_left<=0
	add_skip(panel,arena.reward.skip_upgrade)
	animate_choices(panel)

func show_pause():
	close_modal()
	# The hub's practice run has nothing to leave: the tablet opens over the hub as it always did.
	preload("res://scripts/ui/pause_tablet.gd").open(arena,arena.pause_battle,Callable() if arena.get("practice") else retreat)
## «В хаб» from the pause (author, 4 Oct 2026): leaving a field that is not cleared counts as a defeat — the
## same losses as being knocked out. A cleared field (or the sandbox) is left freely, as before.
func retreat():
	if arena.room_cleared or arena.sandbox or arena.phase=="result":arena.leave();return
	var root=Control.new();root.name="RetreatConfirm";root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(root)
	var dialog=preload("res://scripts/ui/skip_confirm.gd").open(root,func():arena.finish_run(false,"Отступление с поля"),{"heading":"Уйти с поля?","body":"Поле не зачищено: уход засчитается как поражение. Часть сплава и чертежи вне сейфа и без страховки пропадут.","stay_text":"Остаться","leave_text":"Уйти — поражение"})
	dialog.tree_exited.connect(func():
		if is_instance_valid(root):root.queue_free()
		if is_instance_valid(arena) and arena.phase=="paused":show_pause())

## Run summary: rows arrive one by one like a ladder — numbers count up, bars fill, each row clicks;
## blueprints are shown as backpack cards (lost ones dimmed). Records get a badge.
## End of a sortie: the loot ledger and the kill staircase live in scripts/ui/run_result.gd.
func show_result(won:bool,reason:String):
	preload("res://scripts/ui/run_result.gd").show(self,arena,won,reason)

func show_departure():
	if Campaign.endless:arena.depart_room();return
	# Stash (T-214): the exit is open from the start, so the window says what is left behind instead of «cleared».
	if arena.room.mode=="cache" and not arena.challenges.rewarded:
		var ambush=arena.challenges.opened
		var stash=modal_base("Тайник","Засада ещё идёт" if ambush else "Тайник не открыт","Отбейся — после засады выпадет сундук с наградой." if ambush else "Сундук в центре поля. Откроешь — засада ветеранов, за неё сундук с наградой. Можно уйти и без него.",315)
		UiKit.button(stash,"Вернуться к тайнику",Vector2(30,190),Vector2(410,66),func():arena.return_to_field(),true)
		UiKit.button(stash,"Уйти без награды",Vector2(465,190),Vector2(445,66),func():arena.depart_room())
		return
	var panel=modal_base("Поле боя зачищено","Путь открыт","Можно вернуться и собрать оставшиеся бонусы.",315)
	UiKit.button(panel,"Вернуться на поле",Vector2(30,190),Vector2(410,66),func():arena.return_to_field())
	UiKit.button(panel,"Пойти дальше",Vector2(465,190),Vector2(445,66),func():arena.depart_room(),true)

func show_recipe_draft():
	# A blueprint from the chest gets its own celebration first (author, 4 Oct 2026), then the cards.
	var fresh:Dictionary=arena.draft_pickup.get("recipe_given",{})
	if not fresh.is_empty() and not arena.draft_pickup.get("recipe_seen",false):show_blueprint_reveal(fresh);return
	var difficulty=2 if arena.room.boss_room else arena.room.difficulty
	var panel=choice_screen("chest_screen","Сундук "+EncounterRules.STARS[difficulty],"Выбери награду",EncounterRules.reward_text(difficulty)+". Одна карточка на выбор.")
	panel.get_node("ReturnButton").pressed.connect(func():arena.pause_battle())
	# What these cards are (T-170): one line under the heading, small, above the cards.
	var why=panel.get_node("Subtitle")
	var given:Dictionary=arena.draft_pickup.get("recipe_given",{})
	if given.is_empty():Texts.set_text(why,("Награда за командира. " if arena.room.boss_room else "")+"Возьми одну: трофей действует до конца вылазки")
	else:Texts.set_text(why,Texts.render("Чертёж «%s» лежит рядом с сундуком — не забудь подобрать. А теперь возьми одну карточку") % Texts.render(Game.recipe_name(given)))
	why.add_theme_font_size_override("font_size",14);why.add_theme_color_override("font_color",UiKit.MUTED);why.position.y=110;why.size.y=24;why.clip_text=true
	for i in range(3):
		var offer=arena.draft_pickup.offers[i];var special=offer.category in ["secret","alloy","upgrade","documents"]
		var tier=offer.get("tier",0) if special else Game.TIERS.tier(offer.id)
		var card_name=Game.recipe_name(offer) if not special else "+%d сплава" % offer.amount if offer.category=="alloy" else "+%d сплава" % (offer.amount*Game.DOC_ALLOY) if offer.category=="documents" else "Секретное усиление" if offer.category=="secret" else UpgradeRegistry.get_def(offer.id).title if UpgradeRegistry.has(offer.id) else "Улучшение героя"
		var detail="Откроется после возврата в хаб"
		if offer.category=="alloy":detail="Сохрани при возврате в хаб"
		elif offer.category=="documents":detail="Переплавленные документы"
		elif offer.category=="secret":
			detail=preload("res://scripts/ui/sortie_report.gd").trophy_text(offer)
		elif offer.category=="upgrade":detail=arena.reward.upgrade_preview(offer.id,offer.get("tier",0))
		if offer.get("duplicate",false):detail="Уже открыт. Донеси в хаб и продай в урне за %d сплава." % Game.duplicate_price(offer)
		var view={"category":"Транспорт" if offer.category=="garage" else "Штаб" if offer.category=="hq" or offer.id=="headquarters" else "Чертёж" if not special else "Трофей","title":card_name,"detail":detail,"icon":offer.id if special else "recipe","heading":LOOT.RARITY_NAMES[tier],"color":Color(LOOT.RARITY_COLORS[tier])}
		# A run card in the chest looks like the same card between waves (T-242, T-251): rarity plate, family, values.
		if offer.category=="upgrade" and UpgradeRegistry.has(str(offer.id)):view=arena.reward.upgrade_card({"id":offer.id,"tier":int(offer.get("tier",0))})
		preload("res://scripts/ui/choice_card.gd").configure(panel.get_node("Card"+str(i+1)),view,func():arena.choose_recipe_card(i))
	var roll=panel.get_node("RerollButton");Texts.set_text(roll,"Переброс · осталось %d" % arena.rerolls_left);roll.pressed.connect(func():arena.reroll_recipe_draft());roll.disabled=arena.rerolls_left<=0
	add_skip(panel,arena.reward.skip_chest)
	animate_choices(panel)

const RECIPE_KINDS={"research":"Постройка","weapon":"Оружие","bonus":"Бонус поля","ability":"Гаджет","hq":"Технология штаба","garage":"Транспорт"}
func show_blueprint_reveal(recipe:Dictionary):
	var panel=modal_base("Сундук командира","Новый чертёж!","",440)
	var tier=Game.TIERS.tier(recipe.id);var color=Color(LOOT.RARITY_COLORS[tier])
	var glow=Panel.new();panel.add_child(glow);glow.position=Vector2(60,140);glow.size=Vector2(200,200)
	var style=StyleBoxFlat.new();style.bg_color=Color(color,.16);style.border_color=color;style.set_border_width_all(3);style.set_corner_radius_all(18);glow.add_theme_stylebox_override("panel",style)
	var icon=TextureRect.new();glow.add_child(icon);icon.position=Vector2(24,24);icon.size=Vector2(152,152);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var art=UiKit.icon_texture(recipe.id);icon.texture=UiKit.trimmed(art if art else UiKit.icon_texture("recipe"))
	UiKit.label(panel,LOOT.RARITY_NAMES[tier]+" · "+RECIPE_KINDS.get(str(recipe.category),"Чертёж"),Vector2(300,150),Vector2(600,26),16,color)
	UiKit.label(panel,Game.recipe_name(recipe),Vector2(300,180),Vector2(600,50),34)
	var stowed=bool(arena.draft_pickup.get("recipe_stowed",false))
	var where="Чертёж уже в рюкзаке." if stowed else "Рюкзак полон — чертёж лежит у сундука, освободи ячейку и подбери (C)."
	var note=UiKit.label(panel,Texts.render(where)+" "+(Texts.render("Донеси его до хаба — там он откроется навсегда.") if not recipe.get("duplicate",false) else Texts.render("Уже открыт. Донеси в хаб и продай в урне за %d сплава.") % Game.duplicate_price(recipe)),Vector2(300,240),Vector2(600,60),18,UiKit.MUTED)
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var go=UiKit.button(panel,"К наградам",Vector2(300,350),Vector2(320,56),blueprint_seen,true)
	go.focus_mode=Control.FOCUS_ALL;(func():if is_instance_valid(go):go.grab_focus()).call_deferred()
	Game.sound("rare_reveal",arena)
	panel.pivot_offset=panel.size*.5;panel.scale=Vector2(.82,.82);panel.modulate.a=0
	var pop=panel.create_tween().set_parallel();pop.tween_property(panel,"scale",Vector2.ONE,.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT);pop.tween_property(panel,"modulate:a",1.0,.18)
	glow.pivot_offset=glow.size*.5
	var pulse=glow.create_tween().set_loops();pulse.tween_property(glow,"scale",Vector2.ONE*1.05,.7);pulse.tween_property(glow,"scale",Vector2.ONE,.7)

func blueprint_seen():
	arena.draft_pickup["recipe_seen"]=true;show_recipe_draft()

func add_skip(panel:Panel,callback:Callable):
	var reroll=panel.get_node("RerollButton")
	reroll.position.x=30;reroll.size.x=540
	UiKit.button(panel,"Отказаться",Vector2(590,reroll.position.y),Vector2(320,44),callback)

func set_transport_visible(value:bool):
	if showing_transport==value:return
	showing_transport=value
	weapon_bars.visible=not value;vehicle_label.visible=not value
	left_info.size=Vector2(76,76) if value else Vector2(235,168)
	weapon_icon.position=Vector2(12,10) if value else Vector2(10,10);weapon_icon.size=Vector2(52,52) if value else Vector2(74,52)
	left_info.tooltip_text=LOOT.WEAPONS[arena.weapon].name if value else ""
	place_ammo_row()
	if transport_tween and transport_tween.is_valid():transport_tween.kill()
	transport_panel.show()
	transport_tween=create_tween().set_parallel(true)
	transport_tween.tween_property(transport_panel,"position:x",28.0 if value else -250.0,.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	transport_tween.tween_property(left_info,"position:y",(339.0 if value else 135.0)+panel_drop(),.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if not value:transport_tween.chain().tween_callback(transport_panel.hide)

func show_final_preparation():
	var panel=modal_base("Генерал повержен","Впереди — Цитадель","Выбери комнату усиления на карте, затем брось вызов гигабоссу.",335)
	UiKit.button(panel,"В хаб с наградами",Vector2(30,215),Vector2(410,65),func():arena.leave())
	UiKit.button(panel,"К последней подготовке",Vector2(465,215),Vector2(445,65),func():arena.depart_room(),true)

## Ammo cells: one per slot, colour of the ammo type, the active one framed; with two slots a tap (or R / RS)
## switches. Rebuilt only when the loaded set changes.
func refresh_ammo():
	if arena==null or arena.run==null or not is_instance_valid(left_info):return
	Ammo.ensure(arena.run,arena.weapon)
	var run=arena.run
	var signature=str(run.ammo_slots)+str(run.ammo_active)
	if signature==ammo_signature and is_instance_valid(ammo_row):return
	ammo_signature=signature
	if is_instance_valid(ammo_row):ammo_row.queue_free()
	ammo_row=HBoxContainer.new();ammo_row.name="AmmoRow";left_info.add_child(ammo_row);ammo_row.add_theme_constant_override("separation",5)
	ammo_row.mouse_filter=Control.MOUSE_FILTER_PASS
	# Under the weapon name, next to the picture: round cells, then the active ammo's name in its colour
	# (place_ammo_row; folded card — the cells only, in the square's corner).
	for i in range(run.ammo_slots.size()):
		var slot=run.ammo_slots[i];var type=str(slot.type) if slot is Dictionary else str(slot);var on=i==run.ammo_active;var color=Color(Ammo.COLORS.get(type,"cfd3c8"))
		var cell=Panel.new();ammo_row.add_child(cell);cell.custom_minimum_size=Vector2(18,18);cell.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		var style=UiKit.style(color if on else Color(color,.28),9,Color.WHITE if on else Color(color,.6));style.set_border_width_all(2 if on else 1)
		cell.add_theme_stylebox_override("panel",style)
		cell.tooltip_text=Texts.render("Боеприпасы")+": "+Texts.render(Ammo.NAMES.get(type,type))+(" · "+Texts.render("активные") if on else "")+(" · R" if run.ammo_slots.size()>1 else "")
		if slot is Dictionary and type!=Ammo.STANDARD:cell.tooltip_text+="\n"+Ammo.describe(slot)
		cell.gui_input.connect(func(event):
			var tap=(event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed)
			if tap and Ammo.switch(arena):refresh_ammo())
	var name_label=Label.new();ammo_row.add_child(name_label);Texts.set_text(name_label,Ammo.NAMES.get(Ammo.active(run),""))
	name_label.add_theme_font_size_override("font_size",12);name_label.add_theme_color_override("font_color",Color(Ammo.COLORS.get(Ammo.active(run),"cfd3c8")))
	name_label.name="AmmoName"
	place_ammo_row()
## Expanded card: the ammo cells and the active ammo's name under the weapon name. Folded to the weapon square
## (a vehicle is driven, T-222): only the coloured cells, without the name, inside its bottom-right corner.
func place_ammo_row():
	if not is_instance_valid(ammo_row):return
	var name_label=ammo_row.get_node_or_null("AmmoName")
	if name_label:name_label.visible=not showing_transport
	ammo_row.reset_size()
	if showing_transport:ammo_row.position=left_info.size-ammo_row.get_combined_minimum_size()-Vector2(7,7)
	else:ammo_row.position=Vector2(vehicle_label.position.x,vehicle_label.position.y+28)
