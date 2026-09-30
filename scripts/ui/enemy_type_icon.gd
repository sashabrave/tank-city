extends Control
const ATLAS=preload("res://assets/ui/enemies/enemy_atlas_v1.png")
const IDS=["pistol","shotgun","smg","rifle","shield","grenade_launcher","sniper","rpg","buggy","mortar","apc","tank","boss","flyer","drone","commander"]
const NAMES=["Стрелок · пистолет","Стрелок · дробовик","Стрелок · ПП","Стрелок · автомат","Щитовик","Гранатомётчик","Снайпер","Рпгшник","Багги","Турель с гранатами","Бтр","Танк","Командир","Летающий дрон","Дрон-хлопушка","Командир"]
var kind="soldier"
var weapon=""
static func index_for(type:String,loadout:String="")->int:
	var id=loadout if type=="soldier" and loadout in EnemyLoadouts.BASIC else "rifle" if type=="soldier" else "rpg" if type=="grenadier" and loadout=="rpg" else "grenade_launcher" if type=="grenadier" else type
	return maxi(0,IDS.find(id))
static func title(type:String,loadout:String="")->String:return NAMES[index_for(type,loadout)]
func _ready():
	mouse_filter=Control.MOUSE_FILTER_PASS;tooltip_text=title(kind,weapon)
func _draw():draw_icon(self,kind,size*.5,Color.WHITE,weapon,"",40)
static func draw_icon(canvas:CanvasItem,type:String,p:Vector2,c:Color=Color.WHITE,loadout:String="",state:String="",extent:float=30):
	var index=index_for(type,loadout);var cell=Vector2(ATLAS.get_width()/4.0,ATLAS.get_height()/4.0)
	var tint=Color(.63,.67,.60,.40) if state=="dead" else Color.WHITE
	canvas.draw_texture_rect_region(ATLAS,Rect2(p-Vector2.ONE*extent*.5,Vector2.ONE*extent),Rect2(Vector2(index%4,int(index/4))*cell,cell),tint)
	if state.is_empty():return
	var badge=p+Vector2(extent*.35,extent*.35)
	canvas.draw_circle(badge,5.5,Color("263129"))
	if state=="active":canvas.draw_circle(badge,3.5,Color("f4a348"))
	elif state=="dead":
		canvas.draw_line(badge+Vector2(-3,0),badge+Vector2(-.5,2),Color("c3d2b9"),1.5,true)
		canvas.draw_line(badge+Vector2(-.5,2),badge+Vector2(3,-2),Color("c3d2b9"),1.5,true)
	else:
		canvas.draw_arc(badge,3.5,0,TAU,16,Color("eae5cb"),1,true)
		canvas.draw_line(badge+Vector2(0,-2.5),badge,Color("eae5cb"),1,true)
		canvas.draw_line(badge,badge+Vector2(2,0),Color("eae5cb"),1,true)
