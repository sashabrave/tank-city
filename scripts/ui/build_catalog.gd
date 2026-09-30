extends RefCounted
## Buildable stations. ATLAS keeps the order of the workshop illustration sheet.
const IDS=["weapons","headquarters","garage","range"]
const ATLAS=["character","weapons","bonuses","headquarters","garage","range"]
const INFO={"weapons":["Арсенал","Оружие, бонусы боя и гаджеты: выбирай ствол в бой и развивай найденное."],"headquarters":["Штаб","Технологии поддержки, оборона базы, страховка добычи и постройки."],"garage":["Стоянка","Своя техника у старта вылазки и её оборудование."],"range":["Полигон","Мишень в хабе, чтобы опробовать оружие."],"character":["Прокачка базы","Больше не строится: улучшения переехали в «Бойца» и «Штаб»."],"bonuses":["Верстак бонусов","Больше не строится: бонусы переехали в «Арсенал»."]}
static func image(id:String)->Texture2D:
	if id not in ATLAS or not ResourceLoader.exists("res://assets/ui/workshops/atlas.png"):return UiKit.icon_texture(id)
	var atlas=AtlasTexture.new();atlas.atlas=load("res://assets/ui/workshops/atlas.png");var size=atlas.atlas.get_size()/Vector2(3,2);var index=ATLAS.find(id);atlas.region=Rect2(Vector2(index%3,index/3)*size,size);return atlas
static func preview(parent:Node,id:String,pos:Vector2,size:Vector2):
	var texture=TextureRect.new();parent.add_child(texture);texture.texture=image(id);texture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;texture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;texture.position=pos;texture.size=size;texture.mouse_filter=Control.MOUSE_FILTER_IGNORE;return texture
static func fresh(id:String)->bool:return id in Game.research_unlocks and "build:"+id not in Game.progression.seen
static func mark(id:String):
	if "build:"+id not in Game.progression.seen:Game.progression.seen.append("build:"+id);Game.save_progress()
static func dot(parent:Control,pos:Vector2):
	var label=UiKit.label(parent,"●",pos,Vector2(18,22),17,Color("d9664c"));label.mouse_filter=Control.MOUSE_FILTER_IGNORE;return label
static func open_bench(hub,id:String):
	mark(id)
	match id:
		"weapons":hub.open_station("arsenal")
		"headquarters":hub.open_station("hq")
		"garage":hub.open_station("garage")
		_:hub.close_station()
static func discoveries(id:String)->Array:
	match id:
		"weapons":return Game.weapon_unlocks
		"bonuses":return Game.bonus_unlocks
		"headquarters":return Game.hq_unlocks
		"garage":return Game.garage.unlocks
	return []
static func has_news(id:String)->bool:
	return fresh(id) or (id in Game.built_workshops and discoveries(id).any(func(item):return "bench:"+id+":"+str(item) not in Game.progression.seen))
static func item_dot(card:Control,id:String,item:String,pos:Vector2):
	var key="bench:"+id+":"+item
	if key in Game.progression.seen:return
	var badge=dot(card,pos)
	card.mouse_entered.connect(func():
		if key not in Game.progression.seen:Game.progression.seen.append(key);Game.save_progress()
		badge.hide())
