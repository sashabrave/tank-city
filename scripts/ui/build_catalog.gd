extends RefCounted
## Buildable stations. ATLAS keeps the order of the workshop illustration sheet.
const IDS=["weapons","headquarters","yard","garage","range"]
const ATLAS=["character","weapons","bonuses","headquarters","garage","range"]
const INFO={"yard":["Площадка","Место снаружи ангара с испытательной трассой. Открывает постройку «Стоянки» и «Полигона»."],"weapons":["Арсенал","Оружие, бонусы боя и гаджеты: выбирай ствол в бой и развивай найденное."],"headquarters":["Штаб","Технологии поддержки, оборона базы, страховка добычи и постройки."],"garage":["Стоянка","Своя техника у старта вылазки и её оборудование."],"range":["Полигон","Мишень в хабе, чтобы опробовать оружие."],"character":["Прокачка базы","Больше не строится: улучшения переехали в «Казарму» и «Штаб»."],"bonuses":["Верстак бонусов","Больше не строится: бонусы переехали в «Арсенал»."]}
static func image(id:String)->Texture2D:
	# One miniature set for every building (assets/ui/buildings, GPT Image 2.5 sheet).
	if ResourceLoader.exists("res://assets/ui/buildings/%s.png" % id):return load("res://assets/ui/buildings/%s.png" % id)
	if id=="yard":return UiKit.icon_texture("base")
	if id not in ATLAS or not ResourceLoader.exists("res://assets/ui/workshops/atlas.png"):return UiKit.icon_texture(id)
	var atlas=AtlasTexture.new();atlas.atlas=Illustrations.texture("res://assets/ui/workshops/atlas.png");var size=atlas.atlas.get_size()/Vector2(3,2);var index=ATLAS.find(id);atlas.region=Rect2(Vector2(index%3,index/3)*size,size);return atlas
static func preview(parent:Node,id:String,pos:Vector2,size:Vector2):
	var texture=TextureRect.new();parent.add_child(texture);texture.texture=image(id);texture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;texture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;texture.position=pos;texture.size=size;texture.mouse_filter=Control.MOUSE_FILTER_IGNORE;return texture
static func fresh(id:String)->bool:return id in Game.research_unlocks and "build:"+id not in Game.progression.seen
static func mark(id:String):
	if "build:"+id not in Game.progression.seen:Game.progression.seen.append("build:"+id);Game.save_progress()
static func dot(parent:Control,_pos:=Vector2.ZERO):return UiKit.badge(parent,"news")
static func open_bench(hub,id:String):
	mark(id)
	match id:
		"weapons":hub.open_station("arsenal")
		"headquarters":hub.open_station("hq")
		"garage":hub.open_station("garage")
		_:hub.close_station()
## Build news is only about the building itself. Finds inside a built station light that station's
## bench dot (station_notices); the old per-item «bench:» keys are no longer marked by station screens.
static func has_news(id:String)->bool:return fresh(id)
static func item_dot(card:Control,id:String,item:String,pos:Vector2):
	var key="bench:"+id+":"+item
	if key in Game.progression.seen:return
	var badge=dot(card,pos)
	card.mouse_entered.connect(func():
		if key not in Game.progression.seen:Game.progression.seen.append(key);Game.save_progress()
		badge.hide())
