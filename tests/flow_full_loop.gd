extends Node
## The whole sortie loop on a fresh profile in a new temp folder: hub → world map → battle → forced death →
## result window → «В хаб» → hub. After the loop: the run checkpoint is cleared, alloy is credited exactly once
## (earned minus the death loss, nothing more on the hub or on a reload), blueprints follow the death policy (the
## one in the safe cell is banked, the other is lost), the runs/deaths/extracted counters grow by one sortie, the
## profile on disk matches memory. Then the profile is reloaded from disk and a second loop runs on it.
var failures=0
var main
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func settle(frames:int=3):
	for i in range(frames):await get_tree().process_frame
func wait_until(condition:Callable,seconds:float)->bool:
	var until=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<until:
		if condition.call():return true
		await get_tree().process_frame
	return condition.call()
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	# Fresh profile in a new temp folder (slots, index and backups all live there); never the author's user://.
	var dir="/tmp/warcats-flow-%d" % Time.get_ticks_usec();DirAccess.make_dir_recursive_absolute(dir)
	Game.profiles.directory=dir;Game.profiles.selected=false;Game.save_enabled=true
	check(Game.profiles.choose(1,true) and Game.save_path.begins_with(dir),"a fresh profile is created explicitly in the temp folder")
	main=load("res://scenes/main.tscn").instantiate();add_child(main)
	await settle(4)
	check(is_hub(),"the new profile starts in the hub")
	var weapons=Game.recipe_catalog("weapon").keys().filter(func(id):return id not in Game.recipe_owned("weapon"))
	check(weapons.size()>=3,"fresh profile has weapon blueprints to find")
	await loop(1,weapons[0],weapons[1])
	# Save → load from disk → the second loop runs on the reloaded profile.
	var credits=Game.credits;var deaths=int(Game.progression.counters.get("deaths",0))
	check(Game.load_progress() and Game.credits==credits and int(Game.progression.counters.get("deaths",0))==deaths,"the profile reloads from disk unchanged")
	check(weapons[0] in Game.recipe_owned("weapon"),"the banked blueprint survives the reload")
	main.reload_profile_hub();await settle(4)
	await loop(2,weapons[2],"")
	Game.save_enabled=false;main.queue_free();await settle()
	print("FLOW FULL LOOP: %d failures" % failures);get_tree().quit(1 if failures else 0)
func is_hub()->bool:
	return is_instance_valid(main.current) and main.current.get_script()!=null and main.current.get_script().resource_path.ends_with("hub.gd")
## One sortie. safe_id goes into the safe cell (kept); lost_id (if any) lies in an ordinary cell (lost).
func loop(n:int,safe_id:String,lost_id:String):
	var counters=Game.progression.counters
	var runs=int(counters.get("runs",0));var deaths=int(counters.get("deaths",0));var extracted=int(counters.get("extracted",0))
	var credits=Game.credits
	Campaign.configure(1,false);Campaign.challenge=0
	main.start_run();await settle()
	check(main.current.get_script()==load("res://scripts/route_map.gd") and Game.run_checkpoint.get("mode","")=="map","loop %d: the world map opens with a map checkpoint" % n)
	check(int(Game.progression.counters.get("runs",0))==runs+1,"loop %d: the sortie is counted once" % n)
	main.enter_room(0);await settle()
	var arena=main.run_arena
	check(arena!=null and main.current==arena and Game.run_checkpoint.get("mode","")=="room","loop %d: the battle opens with a room checkpoint" % n)
	if arena==null:return
	arena.auto_pause_enabled=false
	await get_tree().create_timer(.8).timeout
	arena.spawn_queue.clear();arena.phase="combat"
	# Alloy found in the field (what clearing a field pays) and two blueprints in the backpack.
	var earned=150*n;Game.earn(earned);arena.run.earned+=earned
	var r=arena.run;r.safe_slots=1;r.pending_recipes.clear()
	r.pending_recipes.append({"id":safe_id,"category":"weapon"})
	if lost_id!="":r.pending_recipes.append({"id":lost_id,"category":"weapon"})
	var cells=Backpack.layout(r)
	for c in range(Backpack.CELLS):
		if cells[c]!=null and cells[c].kind=="recipe" and str(cells[c].item.id)==safe_id and c!=0:Backpack.place(r,c,0)
	check(str(Backpack.layout(r)[0].item.id)==safe_id,"loop %d: the safe blueprint lies in the safe cell" % n)
	# Forced death: the first lethal hit leaves 1 HP («На волоске»), the second one ends the sortie.
	var player=arena.player
	player.invulnerable=0;player.take_damage(9999.0)
	check(player.hp==1.0 and arena.phase=="combat","loop %d: the first lethal hit leaves 1 HP" % n)
	player.invulnerable=0;player.take_damage(9999.0)
	check(await wait_until(func():return arena.phase=="result",5.0),"loop %d: the second hit ends the sortie" % n)
	check(Game.run_checkpoint.is_empty(),"loop %d: the run checkpoint is cleared on death" % n)
	var lost=int(r.lost_alloy);var share=Game.death_loss_fraction()
	check(r.lost_run and lost>=floori(earned*share*.9)-1 and lost<=ceili(earned*share*1.1)+1,"loop %d: death takes %d of %d alloy (share %.2f ±10%%)" % [n,lost,earned,share])
	check(Game.credits==credits+earned-lost,"loop %d: alloy after death = before + earned − loss" % n)
	# The result window and its «В хаб» button.
	var to_hub=[null]
	await wait_until(func():
		for b in get_tree().root.find_children("*","Button",true,false):
			if b.is_visible_in_tree() and str(b.text).to_lower().contains("в хаб"):to_hub[0]=b;return true
		return false,6.0)
	check(to_hub[0]!=null,"loop %d: the result window offers «В хаб»" % n)
	if to_hub[0]!=null:to_hub[0].pressed.emit()
	else:arena.leave()
	check(await wait_until(is_hub,5.0),"loop %d: «В хаб» returns to the hub" % n)
	await settle()
	counters=Game.progression.counters
	check(Game.run_checkpoint.is_empty() and main.run_arena==null,"loop %d: no run is left behind in the hub" % n)
	check(Game.credits==credits+earned-lost,"loop %d: the hub credits nothing twice (%d)" % [n,Game.credits])
	check(int(counters.get("deaths",0))==deaths+1,"loop %d: deaths +1" % n)
	check(int(counters.get("extracted",0))==extracted+earned-lost,"loop %d: delivered alloy counted once" % n)
	check(safe_id in Game.recipe_owned("weapon"),"loop %d: the blueprint in the safe cell is banked" % n)
	if lost_id!="":check(lost_id not in Game.recipe_owned("weapon"),"loop %d: the blueprint outside the safe cell is lost" % n)
	var disk=Game.ProfileStore.load_file(Game.save_path,Game.ProfileSchema.validate)
	check(disk.ok and int(disk.data.credits)==Game.credits and disk.data.get("run_checkpoint",{}).is_empty(),"loop %d: the profile on disk matches (credits, no checkpoint)" % n)
	check(disk.ok and int(disk.data.progression.counters.get("deaths",0))==deaths+1,"loop %d: deaths saved to disk" % n)
