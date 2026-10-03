extends RefCounted
## Route dialog for challenge rooms: rules and the reward that the stars promise.
const RULES={"maze":"Поле — тёмный бетонный лабиринт, свет только вокруг бойца. Дойди до зелёного флага до конца отсчёта. Чем больше звёзд, тем меньше обходных путей и времени. Не успел — включат свет, но без награды.","cache":"Сундук в центре поля. Откроешь — с двух сторон придёт засада ветеранов. Можно уйти через выход, не открывая.","hold":"Займи точку и стой в ней, пока враги наступают. Шкала растёт, только если в зоне нет врагов. Штаб тоже нужно беречь.","survive":"Поле под артобстрелом. Продержись, пока не выйдет время: уходи из красных меток. Стрелять и применять способности можно."}
const REWARDS=["Сплав и обычные карты","Редкие карты или чертёж","Эпические карты, много сплава или редкий чертёж"]
static func build(route,info:Dictionary,confirm:Callable)->Control:
	var modal=Control.new();route.root.add_child(modal);modal.add_to_group("selection_scope");modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade=ColorRect.new();modal.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,.48)
	var panel=UiKit.glass(modal,(route.get_viewport().get_visible_rect().size-Vector2(640,350))*.5,Vector2(640,350))
	UiKit.accent(UiKit.label(panel,("%s %s" % [ChallengeRooms.TITLES.get(info.type,"Испытание"),EncounterRules.STARS[info.difficulty]]).strip_edges(),Vector2(25,20),Vector2(590,40),27))
	var rules=UiKit.label(panel,RULES.get(info.type,""),Vector2(25,80),Vector2(590,90),19);rules.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	UiKit.label(panel,"Награда: "+REWARDS[clampi(info.difficulty,0,2)],Vector2(25,190),Vector2(590,32),17,UiKit.MUTED)
	UiKit.button(panel,"Войти [E]",Vector2(330,265),Vector2(285,52),confirm,true)
	UiKit.button(panel,"Отказаться",Vector2(25,265),Vector2(285,52),route.cancel_entry)
	return modal
