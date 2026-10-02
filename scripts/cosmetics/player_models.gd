class_name PlayerModels
extends RefCounted
## «Шкаф → Модель игрока»: which cat mesh the player's soldier uses (hub avatar, rooms, battle, death).
## Visual only: the rig, clips, weapon socket and hitbox are the same v6 ones in every file.
## Sources: guides/02_development/09_hero_3d_workflow.md (branch feature/hero-v8).
const DEFAULT="v6"
const MODELS={
	"v6":{"name":"Кот v6","path":"res://assets/models/infantry_v6/soldier.glb","text":"Модель игры. Окрас и форма меняются, как раньше."},
	"v8":{"name":"Кот ручной сборки","path":"res://assets/models/infantry_v6/player/v8.glb","text":"Собран в Blender по листам деталей. Голова крупнее, рюкзак за спиной. Форма из шкафа применяется."},
	"tripo":{"name":"Кот Tripo","path":"res://assets/models/infantry_v6/player/tripo.glb","text":"Опыт с генератором Tripo: своя запечённая текстура, форма из шкафа не применяется."},
	"hunyuan":{"name":"Кот Hunyuan","path":"res://assets/models/infantry_v6/player/hunyuan.glb","text":"Опыт с генератором Hunyuan3D: своя текстура и рюкзак, форма из шкафа не применяется."},
}

static func valid(id:String)->bool:
	return MODELS.has(id) and ResourceLoader.exists(MODELS[id].path)

static func path(id:String)->String:
	return MODELS[id].path if valid(id) else MODELS[DEFAULT].path
