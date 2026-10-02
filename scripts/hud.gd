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
func _ready():
	add_to_group("battle_message_anchor")
	root=$Layout
	top=root.get_node("HealthPanel");health=top.get_node("HeroHealth");base_health=top.get_node("BaseHealth")
	# Active effects of the soldier: chips with draining bars to the right of the health panel.
	status_strip=preload("res://scripts/ui/status_strip.gd").new();status_strip.name="StatusStrip";status_strip.arena=arena;root.add_child(status_strip)
	left_info=root.get_node("WeaponPanel");weapon_icon=left_info.get_node("WeaponIcon");vehicle_label=left_info.get_node("WeaponName");intercept_label=left_info.get_node("WeaponStats");armor_meter=left_info.get_node("VehicleHealth")
	right_info=root.get_node("RoomPanel");wave_label=right_info.get_node("StageLabel");enemy_label=right_info.get_node("WaveLabel");right_info.get_node("EnemyRoster").arena=arena
	stage_pips=preload("res://scripts/ui/pip_strip.gd").new();right_info.add_child(stage_pips);wave_pips=preload("res://scripts/ui/pip_strip.gd").new();right_info.add_child(wave_pips)
	pause_button=root.get_node("PauseButton");pause_button.pressed.connect(func():arena.pause_battle())
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

	var extra=root.get_node("Skills/Skill1").duplicate();extra.name="Skill3";root.get_node("Skills").add_child(extra)
	root.get_node("Skills").add_theme_constant_override("separation",12)
	for i in range(3):
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
	var support_ui=preload("res://scripts/headquarters/battle_panel.gd").new();support_ui.arena=arena;root.add_child(support_ui)
	var tracker=preload("res://scripts/progression/quest_tracker.gd").new();tracker.hud=self;root.add_child(tracker)

	biome_panel=UiKit.panel(root,Vector2(20,320),Vector2(235,78))
	biome_label=UiKit.label(biome_panel,"",Vector2(12,8),Vector2(211,62),13)
	biome_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
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
	var hero_count=arena.abilities.slots.size();var total=hero_count+arena.headquarters.loadout().size()
	var strip=root.get_node("Skills");strip.set_anchors_preset(Control.PRESET_TOP_LEFT);strip.position=Vector2((get_viewport().get_visible_rect().size.x-(total*88-12))*.5,get_viewport().get_visible_rect().size.y-112);strip.size=Vector2(maxi(0,hero_count*88-12),76)
	for i in range(skill_buttons.size()):skill_buttons[i].visible=i<hero_count
	var data=preload("res://scripts/ui/battle_snapshot.gd").capture(arena)
	boss_bar.hide();boss_title.hide();boss_bar2.hide();boss_title2.hide()
	for i in range(mini(2,data.bosses.size())):
		var boss=data.bosses[i];var bar=boss_bar if i==0 else boss_bar2;var label=boss_title if i==0 else boss_title2
		bar.show();label.show();bar.max_value=boss.max_hp;bar.value=boss.hp;Texts.set_text(label,boss.title)
	if get_viewport().get_visible_rect().size!=last_size:_layout()
	health.set_health(data.hero_hp,data.hero_max);base_health.visible=not data.boss_room;base_health.set_health(data.base_hp,data.base_max)
	dpad.visible=InputScheme.touch();fire_pad.visible=InputScheme.touch();biome_panel.visible=Settings.values.biome_info
	Texts.set_text(biome_label,arena.BIOMES.caption(arena.run_seed,arena.room_index))
	# Progress reads as pips: fields of the route and waves of the room; words only where they add meaning.
	var plain=not arena.sandbox and not data.boss_room and not Campaign.endless
	Texts.set_text(wave_label,"Песочница" if arena.sandbox else "Босс мира" if data.boss_room else "Поле" if plain else "Поле %d" % data.stage)
	stage_pips.visible=plain;stage_pips.set_state(6,data.stage-1,data.stage-1);stage_pips.position=Vector2(wave_label.position.x+text_width(wave_label)+12,wave_label.position.y+wave_label.size.y*.5-3)
	var waves=not arena.sandbox and not arena.challenges.active() and not data.boss_room
	wave_pips.visible=waves
	if arena.sandbox and not arena.challenges.active():Texts.set_text(enemy_label,"F2 — админ")
	elif arena.challenges.active():Texts.set_text(enemy_label,arena.challenges.status())
	elif data.boss_room:Texts.set_text(enemy_label,BossCatalog.encounter(arena.run_seed,arena.room_index).name)
	else:
		Texts.set_text(enemy_label,"Волна");wave_pips.set_state(3,data.wave-1,data.wave-1)
		wave_pips.position=Vector2(enemy_label.position.x+text_width(enemy_label)+12,enemy_label.position.y+enemy_label.size.y*.5-3)
	tip.hide();Texts.set_text(star_label,"★ Звезда · %.1f с" % data.star);star_label.visible=data.star>0
	ability_button.hide()
	for i in range(skill_buttons.size()):
		var button=skill_buttons[i];var skill=data.skills[i]
		button.disabled=skill.disabled;Texts.set_text(button,"");button.tooltip_text=skill.hint
		var display=button.get_node("CooldownDisplay");display.progress=skill.progress;display.cooling=skill.cooling;display.remaining=skill.get("remaining",0.0);display.active=skill.active;display.queue_redraw()
	countdown.visible=data.phase=="countdown"
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
	UiKit.label(panel,heading,Vector2(30,60),Vector2(880,52),36)
	UiKit.label(panel,subtitle,Vector2(30,119),Vector2(880,30),18,UiKit.MUTED)
	return panel

func choice_screen(scene:String,kicker:String,heading:String,subtitle:String)->Panel:
	close_modal();modal=load("res://scenes/ui/"+scene+".tscn").instantiate();root.add_child(modal);modal.add_to_group("selection_scope")
	var panel=modal.get_node("Panel")
	panel.get_node("Kicker").text=kicker;panel.get_node("Heading").text=heading;panel.get_node("Subtitle").text=""
	return panel

func show_upgrades():
	close_modal()
	CardNavigation.lock_confirmation()
	var epoch=choice_epoch
	if is_instance_valid(arena.presentation) and arena.presentation.text_tween and arena.presentation.text_tween.is_running():
		await arena.presentation.text_tween.finished
	if not is_inside_tree() or epoch!=choice_epoch or arena.phase!="upgrade":return
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
	preload("res://scripts/ui/pause_tablet.gd").open(arena,arena.pause_battle,arena.leave)

## Run summary: rows arrive one by one like a ladder — numbers count up, bars fill, each row clicks;
## blueprints are shown as backpack cards (lost ones dimmed). Records get a badge.
## End of a sortie: the loot ledger and the kill staircase live in scripts/ui/run_result.gd.
func show_result(won:bool,reason:String):
	preload("res://scripts/ui/run_result.gd").show(self,arena,won,reason)

func show_departure():
	if Campaign.endless:arena.depart_room();return
	var panel=modal_base("Поле боя зачищено","Путь открыт","Можно вернуться и собрать оставшиеся бонусы.",315)
	UiKit.button(panel,"Вернуться на поле",Vector2(30,190),Vector2(410,66),func():arena.return_to_field())
	UiKit.button(panel,"Пойти дальше",Vector2(465,190),Vector2(445,66),func():arena.depart_room(),true)

func show_recipe_draft():
	var difficulty=2 if arena.room.boss_room else arena.room.difficulty
	var panel=choice_screen("chest_screen","Сундук "+EncounterRules.STARS[difficulty],"Выбери награду",EncounterRules.reward_text(difficulty)+". Один предмет на выбор.")
	panel.get_node("ReturnButton").pressed.connect(func():arena.pause_battle())
	for i in range(3):
		var offer=arena.draft_pickup.offers[i];var special=offer.category in ["secret","alloy","upgrade","documents"]
		var tier=offer.get("tier",0) if special else Game.TIERS.tier(offer.id)
		var card_name=Game.recipe_name(offer) if not special else "+%d сплава" % offer.amount if offer.category=="alloy" else "+%d сплава" % (offer.amount*Game.DOC_ALLOY) if offer.category=="documents" else "Секретное усиление" if offer.category=="secret" else UpgradeRegistry.get_def(offer.id).title if UpgradeRegistry.has(offer.id) else "Улучшение героя"
		var detail="Откроется после возврата в хаб"
		if offer.category=="alloy":detail="Сохрани при возврате в хаб"
		elif offer.category=="documents":detail="Переплавленные документы"
		elif offer.category=="secret":
			detail={"weapon":"+75% базового урона: "+LOOT.WEAPONS.get(offer.id,{"name":""}).name,"ability":"+3 уровня силы: "+AbilityCatalog.DATA.get(offer.id,{"name":""}).name,"bonus":"+3 уровня: "+LOOT.BONUSES.get(offer.id,{"name":""}).name,"stat":"+5 HP" if offer.id=="health" else "Напор: +20 % против равных"}[offer.type]
		elif offer.category=="upgrade":detail=arena.reward.upgrade_preview(offer.id,offer.get("tier",0))
		if offer.get("duplicate",false):detail="Уже открыт. Донеси в хаб и продай в урне за %d сплава." % Game.duplicate_price(offer)
		var view={"category":"Транспорт" if offer.category=="garage" else "Штаб" if offer.category=="hq" or offer.id=="headquarters" else "Чертёж" if not special else "Трофей","title":card_name,"detail":detail,"icon":offer.id if special else "recipe","heading":LOOT.RARITY_NAMES[tier],"color":Color(LOOT.RARITY_COLORS[tier])}
		preload("res://scripts/ui/choice_card.gd").configure(panel.get_node("Card"+str(i+1)),view,func():arena.choose_recipe_card(i))
	var roll=panel.get_node("RerollButton");Texts.set_text(roll,"Переброс · осталось %d" % arena.rerolls_left);roll.pressed.connect(func():arena.reroll_recipe_draft());roll.disabled=arena.rerolls_left<=0
	add_skip(panel,arena.reward.skip_chest)
	animate_choices(panel)


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
	if transport_tween and transport_tween.is_valid():transport_tween.kill()
	transport_panel.show()
	transport_tween=create_tween().set_parallel(true)
	transport_tween.tween_property(transport_panel,"position:x",28.0 if value else -250.0,.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	transport_tween.tween_property(left_info,"position:y",339.0 if value else 135.0,.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if not value:transport_tween.chain().tween_callback(transport_panel.hide)

func show_final_preparation():
	var panel=modal_base("Генерал повержен","Впереди — Цитадель","Выбери комнату усиления на карте, затем брось вызов гигабоссу.",335)
	UiKit.button(panel,"В хаб с наградами",Vector2(30,215),Vector2(410,65),func():arena.leave())
	UiKit.button(panel,"К последней подготовке",Vector2(465,215),Vector2(445,65),func():arena.depart_room(),true)
