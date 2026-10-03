extends Node
## Ammo v2 (T-109…T-112): standard ammo at start; an ammo card is an item with rarity and rolled values that
## goes into a slot (over standard, otherwise over the active ammo — the old one goes to the bag); the card
## compares it with what it replaces; improvements only while loaded; classes (bullets / charges); the second
## Arsenal slot and switching; the new effects reach combat.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	Game.ammo_slot_weapons=[]
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=12;add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false)
	await get_tree().create_timer(.8).timeout
	var run=arena.run;Ammo.ensure(run,arena.weapon)
	check(Ammo.active(run)=="standard" and run.ammo_slots.size()==1,"starts with standard ammo")
	# Rolls: rarity moves the values up, the same seed gives the same item.
	var low=Ammo.roll("burn",0,7);var high=Ammo.roll("burn",3,7)
	check(high.stats.chance>low.stats.chance and high.twist and not low.twist and high.damage>0,"rarer ammo rolls higher values, epic+ adds damage, legendary a twist")
	check(Ammo.roll("cryo",1,99)==Ammo.roll("cryo",1,99),"same seed, same item")
	check(Ammo.fits("explosive","pistol") and not Ammo.fits("explosive","rpg") and Ammo.fits("burn","rpg"),"bullets and charges classes")
	var heat=UpgradeRegistry.get_def("burn_heat")
	check(RunUpgrades.eligible(arena,UpgradeRegistry.get_def("burn")) and not RunUpgrades.eligible(arena,heat),"ammo card offered, its improvement not yet")
	var card=RunUpgrades.card(arena,{"id":"burn","tier":2})
	check(str(card.short).contains("Зарядит") and card.rows.size()>=2 and str(card.rows[0][0]).begins_with("↑"),"card loads it and shows rolled values as gains")
	RunUpgrades.apply(arena,"burn",2)
	check(Ammo.active(run)=="burn" and Ammo.item(run).rarity==2,"incendiary item loaded with its rarity")
	check(RunUpgrades.eligible(arena,heat),"improvements of loaded ammo are offered")
	card=RunUpgrades.card(arena,{"id":"cryo","tier":0})
	check(str(card.short).contains("Заменит"),"card shows the replacement")
	RunUpgrades.apply(arena,"cryo",0)
	check(Ammo.active(run)=="cryo" and run.ammo_bag.size()==1 and run.ammo_bag[0].type=="burn","cryo replaces fire; the old ammo goes to the bag")
	check(not RunUpgrades.eligible(arena,heat),"fire improvements stop dropping")
	# Combat: cryo slows the target.
	var enemy=arena.spawn_actor("soldier",Vector2i(4,3),false)
	var bullet=load("res://scenes/projectile.tscn").instantiate();bullet.arena=arena;bullet.owner_actor=arena.player;bullet.friendly=true;bullet.damage=1.0;add_child(bullet)
	CombatMods.outgoing(arena,bullet,enemy)
	check(enemy.slow_time>0 and enemy.slow_factor>=.2,"cryo hit slows the enemy (%.2f)" % enemy.slow_factor)
	bullet.queue_free()
	# Two slots and switching.
	Game.ammo_slot_weapons.append(arena.weapon);Ammo.ensure(run,arena.weapon)
	check(run.ammo_slots.size()==2,"Arsenal second slot gives two cells")
	RunUpgrades.apply(arena,"stun",1)
	check(Ammo.types_loaded(run).has("cryo") and Ammo.active(run)=="stun","two ammo types loaded, the new one active")
	Ammo.switch(arena);check(Ammo.active(run)=="cryo","switching makes the other type active")
	arena.hud.refresh_ammo()
	check(arena.hud.ammo_row!=null and arena.hud.ammo_row.get_child_count()>=2,"HUD shows the ammo cells")
	# Ammo vending machine (T-116): tokens → a fitting rolled item; «Зарядить» swaps, the old one goes to the bag.
	Game.ammo_slot_weapons=[];Ammo.ensure(run,arena.weapon)
	var vendor=preload("res://scripts/ammo_vendor.gd").place(Node3D.new(),arena,Vector3.ZERO)
	run.tokens=2;check(vendor.buy().is_empty() and run.tokens==2,"machine needs tokens")
	run.tokens=10;var got=vendor.buy()
	check(run.tokens==10-vendor.PRICE and Ammo.fits(str(got.type),arena.weapon) and got.has("stats"),"machine sells a fitting rolled item (%s)" % got.get("type",""))
	var ui=Control.new();add_child(ui);ui.size=Vector2(1280,720);run.tokens=10;var bag=run.ammo_bag.size()
	vendor.open(ui,func():pass)
	for b in vendor.modal.find_children("*","Button",true,false):
		if b.text.contains("рюкзак"):b.pressed.emit()
	check(run.ammo_bag.size()==bag+1,"«В рюкзак» keeps the item")
	# Charges (T-114): grenade launcher takes charge ammo; napalm leaves a burning patch, cluster scatters bomblets.
	check(Game.LOOT.WEAPONS.has("grenade_launcher") and Ammo.fits("napalm","grenade_launcher") and not Ammo.fits("napalm","pistol"),"grenade launcher with charge ammo")
	arena.run.weapon="grenade_launcher";arena.weapon="grenade_launcher";Ammo.ensure(run,"grenade_launcher")
	Ammo.load_item(run,Ammo.roll("napalm",1,5))
	var rocket=load("res://scenes/projectile.tscn").instantiate();rocket.arena=arena;rocket.owner_actor=arena.player;rocket.friendly=true;rocket.damage=2.0;rocket.rocket_radius=1.1;rocket.position=arena.world_pos(Vector2i(5,5));add_child(rocket)
	arena.combat.rocket_impact(rocket)
	check(arena.get_children().any(func(n):return n.get_script()==preload("res://scripts/combat/napalm_patch.gd")),"napalm charge leaves a burning patch")
	rocket.queue_free()
	# T-156: armor-piercing rounds break through a raised riot shield with a chance that grows with rarity.
	var ap_low=Ammo.roll("ap",0,7);var ap_high=Ammo.roll("ap",3,7)
	check(Ammo.shield_pierce(ap_low)>=.25 and Ammo.shield_pierce(ap_high)>Ammo.shield_pierce(ap_low) and Ammo.shield_pierce(Ammo.roll("burn",0,1))==0.0,"AP shield chance grows with rarity, other ammo has none")
	check(Ammo.describe(ap_high).contains("%d%%" % roundi(Ammo.shield_pierce(ap_high)*100)),"AP ammo describes its shield chance")
	print("AMMO: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
