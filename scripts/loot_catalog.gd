class_name LootCatalog
extends RefCounted
const BONUSES={
 "pressure":{"name":"Напор","color":"f7ca58","shape":"bolt","rarity":1,"effect":"Временно удваивает напор"},
 "freeze":{"name":"Фриз","color":"91cadc","shape":"ice","rarity":1,"effect":"Замораживает всех врагов"},
 "heart":{"name":"Аптечка","color":"e62b36","shape":"cross","rarity":0,"effect":"Лечение героя +10%/ур."},
 "repair":{"name":"Ремонт базы","color":"6ab7da","shape":"cube","rarity":0,"effect":"Ремонт базы +10%/ур."},
 "wall":{"name":"Укрепление","color":"b5b8c5","shape":"brick","rarity":0,"effect":"HP стен +1/ур. На ур. 2 — армированный кирпич, на ур. 3 — неразрушимый забор."},
 "vehicle_repair":{"name":"Броня","color":"71c7a2","shape":"hex","rarity":1,"effect":"Восстановление брони +10%/ур."},
 "turret":{"name":"Турель","color":"b894d9","shape":"pyramid","rarity":1,"effect":"HP турели +1/ур."},
 "vehicle":{"name":"Десант техники","color":"e8b957","shape":"diamond","rarity":2,"effect":"Доставка быстрее на 8%/ур."},
 "star":{"name":"Звезда","color":"f2cb64","shape":"star","rarity":2,"effect":"Неуязвимость, сокрушительный выстрел, разрушение бетона"}}
static var WEAPONS=preload("res://scripts/weapon_catalog.gd").DATA
const RARITY_NAMES=["Обычное","Редкое","Эпическое","Секретное"]
const RARITY_COLORS=["cbd5df","55baff","bc82ff","ffd166"]
static func visual(parent: Node3D,id: String) -> Node3D:
	var path="res://assets/models/bonuses_v6/bonus_"+id+".glb"
	if ResourceLoader.exists(path):
		var wrapper=Node3D.new();parent.add_child(wrapper)
		var art=load(path).instantiate();wrapper.add_child(art)
		var bounds=Visuals.mesh_bounds(art,Transform3D.IDENTITY)
		var factor=.7/maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))
		art.scale=Vector3.ONE*factor
		art.position=-bounds.get_center()*factor
		wrapper.position.y=.55
		EffectLighting.pickup(wrapper,Color(BONUSES[id].color))
		return wrapper
	if id in ["pressure","freeze"]:
		var glyph=Node3D.new();parent.add_child(glyph);glyph.position.y=.55
		var sprite=Sprite3D.new();glyph.add_child(sprite);sprite.texture=load("res://assets/icons/v09/"+id+".png");sprite.pixel_size=.768/float(sprite.texture.get_width());sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		EffectLighting.pickup(glyph,Color(BONUSES[id].color))
		return glyph
	var info=BONUSES[id];var color=Color(info.color)
	var node=Node3D.new();parent.add_child(node);node.position.y=.55
	match info.shape:
		"star":
			var sprite=Sprite3D.new();sprite.texture=load("res://assets/icons/v1/star.png");sprite.pixel_size=.8778/float(sprite.texture.get_width());sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED;node.add_child(sprite)
		"cross":
			Visuals.box(node,Vector3.ZERO,Vector3(.55,.17,.18),color);Visuals.box(node,Vector3.ZERO,Vector3(.18,.17,.55),color)
		"cube":Visuals.box(node,Vector3.ZERO,Vector3(.45,.45,.45),color)
		"brick":
			Visuals.box(node,Vector3.ZERO,Vector3(.65,.2,.32),color)
			Visuals.box(node,Vector3(0,.16,0),Vector3(.3,.12,.32),color.lightened(.2))
		"hex","pyramid":
			var mesh=CylinderMesh.new();mesh.top_radius=.3 if info.shape=="hex" else 0.0;mesh.bottom_radius=.3;mesh.height=.45;mesh.radial_segments=6 if info.shape=="hex" else 4
			var part=MeshInstance3D.new();part.mesh=mesh;part.material_override=Visuals.material(color);node.add_child(part)
		"diamond":
			var part=Visuals.box(node,Vector3.ZERO,Vector3(.38,.38,.38),color);part.rotation=Vector3(.6,0,.7)
	EffectLighting.pickup(node,color)
	return node
