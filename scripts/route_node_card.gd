extends Control
## Compact card that floats above the map node the car has driven up to. Not modal: driving continues.
const WIDTH=380.0
var route
var anchor:Vector3
var info:Dictionary={}
var branch=""

static func open(route_map,world_anchor:Vector3,node_info:Dictionary,service_branch:="")->Control:
	var card=preload("res://scripts/route_node_card.gd").new()
	card.route=route_map;card.anchor=world_anchor;card.info=node_info;card.branch=service_branch
	route_map.root.add_child(card);card.build();return card

func build():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var lines:Array=[]
	var title=""
	var node_branch=RoutePlan.node_branch(info) if branch=="" else ""
	var titles={"vehicle":"Ангар · механик","ability":"Пункт подготовки","headquarters":"Мастерская штаба","merchant":"Торговец"}
	if branch!="" or node_branch!="":
		title=titles.get(branch if branch!="" else node_branch,"Передышка")
		lines.append("Без боя · одно усиление на выбор")
	elif info.get("type","") in RoutePlan.CHALLENGES:
		title="Этап %d · %s" % [info.stage+1,ChallengeRooms.TITLES.get(info.type,"Испытание")]
		lines.append("Испытание · %s" % EncounterRules.NAMES[info.difficulty])
	else:
		title="Этап %d · %s" % [info.stage+1,Campaign.title(info.stage)]
		lines.append("%s · %s" % [EncounterRules.NAMES[info.difficulty],boss_name()])
		lines.append(EncounterRules.reward_text(info.difficulty))
	var battle=branch=="" and node_branch=="" and info.get("type","") not in RoutePlan.CHALLENGES
	var height=58.0+lines.size()*26.0+(46.0 if battle else 0.0)+54.0
	size=Vector2(WIDTH,height)
	var panel=UiKit.glass(self,Vector2.ZERO,size,Color("232b25f0"))
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	UiKit.label(panel,title,Vector2(16,10),Vector2(WIDTH-32,32),20)
	var y=46.0
	for line in lines:
		UiKit.label(panel,line,Vector2(16,y),Vector2(WIDTH-32,24),15,UiKit.MUTED);y+=26
	if battle:
		var kinds={}
		for wave in route.node_rosters[info.id]:
			for enemy in wave:kinds[preload("res://scripts/ui/enemy_type_icon.gd").index_for(enemy.kind,enemy.get("weapon",""))]=enemy
		var x=16.0
		for enemy in kinds.values():
			var icon=preload("res://scripts/ui/enemy_type_icon.gd").new();icon.kind=enemy.kind;icon.weapon=enemy.get("weapon","")
			panel.add_child(icon);icon.position=Vector2(x,y+2);icon.size=Vector2(38,37);x+=38
		y+=46
	var go=UiKit.button(panel,"В бой [E]" if battle else "Войти [E]",Vector2(16,y+4),Vector2(WIDTH-32,42),enter,true)
	go.mouse_filter=Control.MOUSE_FILTER_STOP
	follow()

func boss_name()->String:
	if info.stage in Campaign.BOSSES:return BossCatalog.encounter(route.wave_seed,info.stage).name
	var entry=WaveDirector.commander_entry(route.wave_seed,info.stage,info.id)
	if entry.weapon=="rpg":return "РПГшник"
	return {"sniper":"Снайпер","soldier":"Стрелок","shield":"Щитовой","grenadier":"Гранатомётчик","tank":"Танк","apc":"БТР","buggy":"Багги","boss":"Генерал"}.get(entry.kind,"Командир")

func enter():
	if branch!="":route.pending_service=branch;route.confirm_service()
	else:route.pending_info=info;route.preview_only=false;route.confirm_entry()

func follow():
	if not is_instance_valid(route) or not is_instance_valid(route.camera):return
	var screen=route.camera.unproject_position(anchor+Vector3(0,1.9,0))
	var view=get_viewport_rect().size
	position=Vector2(clampf(screen.x-size.x*.5,12,view.x-size.x-12),clampf(screen.y-size.y,12,view.y-size.y-12))

func _process(_delta):follow()
