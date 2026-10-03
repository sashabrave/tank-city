extends Node3D
## Material library (2026-10-03): data/materials.json is the one place for surfaces; palette parts get metal
## only on metal cells; procedural boxes ask for a surface; live edits apply and «Сбросить» restores.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false
	MaterialLibrary.reset()
	for kind in ["steel","gunmetal","brass","paint","rubber","wood","fabric","concrete","glass"]:check(not MaterialLibrary.surface(kind).is_empty(),"surface «%s» is in the library" % kind)
	check(MaterialLibrary.by_name("hq steel")=="steel" and MaterialLibrary.by_name("graphite frames")=="gunmetal" and MaterialLibrary.by_name("warm canvas")=="","imported names find their surface")
	var orm=Visuals.palette_orm().get_image();var cell=InfantryPalette.CELL
	var at=func(name:String)->Color:return orm.get_pixel(InfantryPalette.NAMES.find(name)*cell+1,1)
	check(at.call("gun").b>.8 and at.call("steel").b>.8,"gun and steel palette cells are metal")
	check(at.call("fur").b<.01 and at.call("camo_a").b<.01,"fur and camo stay matte — metal only on metal parts")
	var box=Visuals.box(self,Vector3.ZERO,Vector3.ONE,Color("8a9196"),"steel")
	var mat:StandardMaterial3D=box.material_override
	check(mat.resource_name=="srf_steel" and mat.metallic>.8,"a steel box is metal")
	MaterialLibrary.surface("steel").metallic=.1;MaterialLibrary.apply_live(get_tree())
	check(absf(mat.metallic-.1)<.01,"a live edit reaches the box")
	MaterialLibrary.reset();MaterialLibrary.apply_live(get_tree())
	check(mat.metallic>.8,"«Сбросить» brings the saved value back")
	print("MATERIAL LIBRARY: %d failures" % failures);get_tree().quit(1 if failures else 0)
