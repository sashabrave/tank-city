extends Control
## «Захваченный КП» on the route map: the enemy command post is taken, its war chest holds legendary rules.
## Three legendary cards open over the map; take one (or none) and drive on. Legendary cards never appear in
## ordinary offers (weight 0); this stop is their source.
signal done
var arena
var index=0
var offers:Array=[]
var modal:Control
static func legendary_ids()->Array:
	return UpgradeRegistry.all().filter(func(def):return "legendary" in def.tags).map(func(def):return def.id)
func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_to_group("selection_scope")
	var pool=legendary_ids().filter(func(id):return id not in arena.run.behavior_cards)
	var rng=arena.run.combat_rng
	while offers.size()<3 and not pool.is_empty():offers.append(pool.pop_at(rng.randi_range(0,pool.size()-1)))
	build()
func build():
	modal=preload("res://scenes/ui/service_rewards.tscn").instantiate();add_child(modal);modal.add_to_group("selection_scope")
	var panel=modal.get_node("Panel")
	Texts.set_text(panel.get_node("Heading"),"Захваченный КП · легендарное правило")
	panel.get_node("CloseButton").pressed.connect(ask_skip)
	for i in range(3):
		if i>=offers.size():panel.get_node("Card"+str(i+1)).hide();continue
		var pick=i
		preload("res://scripts/ui/choice_card.gd").configure(panel.get_node("Card"+str(i+1)),RunUpgrades.card(arena,{"id":offers[i],"tier":3}),func():claim(pick))
	panel.get_node("RerollButton").hide()
	UiKit.button(panel,"Дальше без правила",Vector2(590,panel.get_node("RerollButton").position.y),Vector2(320,44),ask_skip)
	Game.sound("rare_reveal",self)
func claim(i:int):
	if i<0 or i>=offers.size():return
	RunUpgrades.apply(arena,offers[i],3)
	Game.progression.event("legend_taken")
	Game.sound("upgrade",self);finish()
## Leaving without a rule asks first (T-217): the post closes after this visit.
func ask_skip():
	if has_node("SkipConfirm"):return
	preload("res://scripts/ui/skip_confirm.gd").open(self,finish,{"heading":"Не взял правило","body":"Легендарное правило можно взять только здесь: после ухода КП закроется.","stay_text":"Выбрать правило","leave_text":"Уйти без правила"})
func finish():
	Game.reset_input();done.emit();queue_free()
