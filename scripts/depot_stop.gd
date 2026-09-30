extends Control
## Pit stop on the route map: the HQ vehicle is in the depot, its cards open right over the map —
## no separate room. Pick one (or reroll / skip) and drive on.
signal done
var arena
var index=0
var offers:Array=[]
var modal:Control
## Without HQ technologies the depot still refuels: base repair, a reroll or a token box.
const SUPPLIES=[{"id":"repair","title":"Ремонт штаба","detail":"Прочность базы +1 до конца забега","icon":"repair"},{"id":"refuel","title":"Заправка","detail":"Перебросы карточек +1","icon":"reroll"},{"id":"tokens","title":"Ящик жетонов","detail":"Жетоны +4 для торговца","icon":"token"}]
var supplies=false
func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_to_group("selection_scope")
	offers=arena.reward.service_offers("headquarters")
	supplies=offers.is_empty()
	if supplies:offers=SUPPLIES.duplicate()
	build()
func build():
	if is_instance_valid(modal):modal.queue_free()
	modal=preload("res://scenes/ui/service_rewards.tscn").instantiate();add_child(modal);modal.add_to_group("selection_scope")
	var panel=modal.get_node("Panel")
	Texts.set_text(panel.get_node("Heading"),"Депо · Штаб")
	panel.get_node("CloseButton").pressed.connect(finish)
	for i in range(3):
		if i>=offers.size():panel.get_node("Card"+str(i+1)).hide();continue
		var pick=i
		var view=arena.headquarters.card(offers[i]) if not supplies else {"category":"Депо","title":offers[i].title,"detail":offers[i].detail,"icon":offers[i].icon,"heading":"","color":Color(LootCatalog.RARITY_COLORS[0]),"disabled":false,"button":"Выбрать"}
		preload("res://scripts/ui/choice_card.gd").configure(panel.get_node("Card"+str(i+1)),view,func():claim(pick))
	var reroll=panel.get_node("RerollButton");Texts.set_text(reroll,"Переброс · осталось %d" % arena.rerolls_left);reroll.pressed.connect(reroll_cards)
	reroll.disabled=arena.rerolls_left<=0 or supplies;reroll.position.x=25;reroll.size.x=540
	UiKit.button(panel,"Дальше без карточки",Vector2(590,reroll.position.y),Vector2(320,44),finish)
func reroll_cards():
	if arena.rerolls_left<=0:return
	if supplies:return
	arena.rerolls_left-=1;offers=arena.reward.service_offers("headquarters");build()
func claim(i:int):
	if i<0 or i>=offers.size():return
	if supplies:
		match offers[i].id:
			"repair":arena.headquarters.basic_hp+=1
			"refuel":arena.rerolls_left+=1
			"tokens":arena.run.tokens+=4
	else:arena.reward.apply_service_reward("headquarters","",index,offers[i])
	Game.sound("upgrade",self);finish()
func finish():
	Game.reset_input();done.emit();queue_free()
