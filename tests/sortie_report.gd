extends Node3D
## «Вылазка» tablet tab (meta stage 2): run counters grow in battle, the report draws live and from
## the saved last run. Profile and settings writes stay disabled.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades();Campaign.configure(1)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=44;add_child(arena);arena.set_physics_process(false);arena.auto_pause_enabled=false
	await get_tree().process_frame
	var hp=arena.player.hp;arena.player.invulnerable=0
	arena.star_time=0;arena.player.take_damage(5.0)
	check(arena.player.hp<hp and is_equal_approx(arena.run.damage_taken,hp-arena.player.hp),"damage taken is counted")
	arena.run.series=0;arena.run.best_series=0
	arena.run.kills_by={"soldier":3,"tank":1};arena.run.best_hit=42.0;arena.run.best_series=4;arena.run.captured=1
	RunUpgrades.apply(arena,"speed",1);RunUpgrades.apply(arena,"health",0)
	var report=load("res://scripts/ui/sortie_report.gd")
	var data=report.snapshot(arena)
	check(data.cards.size()>=1 and data.best_series==4 and data.captured==1 and data.kills_by.size()==2,"snapshot keeps build and moments")
	check(JSON.parse_string(JSON.stringify(data))!=null,"snapshot is plain data for the profile")
	var body=Control.new();add_child(body);report.build(body,data,true)
	check(body.find_child("Kill_tank",true,false)!=null and body.find_child("Moment_3",true,false)!=null,"report shows kills and moments")
	check(body.custom_minimum_size.y>300,"report has height for the scroller")
	body.queue_free()
	var empty=Control.new();add_child(empty);report.build(empty,{},false)
	check(empty.get_child_count()==1,"no last run: a single hint")
	empty.queue_free()
	var saved=JSON.parse_string(JSON.stringify(data));saved.kills_by="broken";saved.erase("cards")
	var restored=Control.new();add_child(restored);report.build(restored,saved,false)
	check(restored.find_child("Moment_0",true,false)!=null and restored.find_child("Kill_tank",true,false)==null,"saved report survives JSON and odd fields")
	restored.queue_free()
	var view=load("res://scripts/ui/field_tablet.gd").new();view.arena=arena;view.tab="fighter";add_child(view)
	await get_tree().process_frame
	check(view.find_child("Moment_0",true,false)!=null,"tablet tab draws the live report")
	view.queue_free();arena.queue_free();await get_tree().process_frame
	print("SORTIE REPORT: %d failures" % failures);get_tree().quit(1 if failures else 0)
