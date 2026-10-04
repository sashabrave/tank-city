extends Node3D
## Class path (author, 4 Oct 2026; guides/01_design/10_abilities_proposal.md): one slot Q, 20 levels with growth on every
## level, «рывок» at 4/10/18, perks at 5/11/16/20, the Q choice at 8 and 14; the power budget stays near the 0.8.0
## path; the new perks work; the path window is one column like «Развитие заставы»; the battle HUD has one class
## button. Profile and settings writes stay disabled.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
## The 0.8.0 path in run-card units, written down from the constants it replaced (GROWTH × 19 levels plus the
## stat perks of levels 5 and 12; health left out — it still grows 0.3 per level, Штурмовик 0.5). Card units:
## crit .07, crit damage .3, bullet guard .12, blast guard .15, weapon damage .18 (shotgun ×1.1, sniper ×1.15),
## health card 1 HP, burn power .5, stealth .1, field repair .25, «Быстрые способности» −10%, dodge .08.
##   Стрелок: crit .004×19/.07 + crit dmg .02×19/.3 + perk crit .05/.07 + crit dmg .25/.3 = 3.900
##   Штурмовик: guard .006×19/.12 + shotgun .1/.18 + mastery HP 2/1 = 3.506
##   Подрывник: burn .02×19/.5 + blast .005×19/.15 + burn .25/.5 + blast .15/.15 = 2.893
##   Разведчик: crit dmg .025×19/.3 + stealth .004×19/.1 + sniper .15/.18 + stealth .08/.1 = 3.977
##   Инженер: repair .02×19/.25 + dodge .003×19/.08 + cooldown 1 + repair .3/.25 = 4.433
const OLD_UNITS={"recruit":3.900,"heavy":3.506,"gunner":2.893,"marksman":3.977,"engineer":4.433}
const OLD_HP={"recruit":.3*19,"heavy":.5*19,"gunner":.3*19,"marksman":.3*19,"engineer":.3*19}
func settle():
	for i in range(3):await get_tree().process_frame
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades();Campaign.configure(1)
	data_checks()
	await perk_checks()
	await hud_checks()
	await window_checks()
	Game.reset_upgrades();Campaign.configure(1)
	print("CLASS PATH: %d failures" % failures);get_tree().quit(1 if failures else 0)

func data_checks():
	check(ClassCatalog.ABILITY_LEVELS==[3,8,14] and ClassCatalog.PERK_LEVELS==[5,11,16,20] and ClassCatalog.BURST_LEVELS==[4,10,18],"milestones: Q 3/8/14, perks 5/11/16/20, bursts 4/10/18")
	for id in ClassCatalog.ROSTER:
		var p=ClassCatalog.path(id)
		check(p.stats.size()==5 and p.stats[0]=="health" and p.stats.all(func(s):return ClassCatalog.STATS.has(s)),"%s: five known stats, health first" % id)
		check(ClassCatalog.perks(id).map(func(k):return int(k.level))==[5,11,16,20],"%s: perks at 5, 11, 16, 20" % id)
		var m8=ClassCatalog.milestone(id,8);var m14=ClassCatalog.milestone(id,14)
		check(m8.get("kind")=="ability" and m8.ability==ClassCatalog.abilities(id)[1] and str(m8.title).begins_with("Выбор для Q"),"%s: level 8 is the Q choice" % id)
		check(m14.get("kind")=="ability" and str(m14.text).contains("Модификация Q — позже"),"%s: level 14 joins the choice, Q modification later" % id)
		var empty=[];var grown={}
		for n in range(2,ClassCatalog.MAX_LEVEL+1):
			var gain=ClassCatalog.level_gain(id,n)
			if gain.size()!=2 or not gain.has("health"):empty.append(n)
			for stat in gain:grown[stat]=true
		check(empty.is_empty(),"%s: every level 2–20 grows health and one class stat %s" % [id,str(empty)])
		check(p.stats.all(func(s):return grown.has(s)),"%s: all five stats grow" % id)
		for n in ClassCatalog.BURST_LEVELS:
			var gain=ClassCatalog.level_gain(id,n);var stat=p.bursts[n][0]
			check(ClassCatalog.burst(id,n) and float(gain[stat])>=2.5*float(p.step[stat]) and ClassCatalog.level_line(id,n).begins_with("Рывок"),"%s: level %d is a burst of %s" % [id,n,stat])
		var units=ClassCatalog.power_units(id)
		check(absf(units/OLD_UNITS[id]-1.0)<=.15,"%s: power at 20 is %.2f card units, old %.2f (±15%%)" % [id,units,OLD_UNITS[id]])
		check(is_equal_approx(float(ClassCatalog.totals(id,20).health),OLD_HP[id]),"%s: health growth as before" % id)
		check(ClassCatalog.level_gain(id,1).is_empty(),"%s: level 1 is the start" % id)
	var hp="+"+UiKit.number(.3)+" здоровья"
	check(ClassCatalog.level_line("recruit",2)=="+1% шанс крита · "+hp,"a level line reads «+1% шанс крита · +0,3 здоровья»: "+ClassCatalog.level_line("recruit",2))
	check(ClassCatalog.level_line("recruit",4)=="Рывок · +15% крит-урон · "+hp,"a burst line leads with «Рывок»: "+ClassCatalog.level_line("recruit",4))

func arena_for(id:String,level:int):
	Game.reset_upgrades();Campaign.configure(1)
	if id not in Game.class_unlocks:Game.class_unlocks.append(id)
	Game.selected_class=id;Game.class_levels[id]=level-1;Game.gadget=""
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=17;add_child(arena);arena.set_physics_process(false);arena.auto_pause_enabled=false
	await settle()
	arena.phase="combat";arena.run.landing_until=-1.0;arena.run.crit_chance=0.0
	return arena
func clear_field(arena):
	for actor in arena.room.actors.duplicate():
		if is_instance_valid(actor) and not actor.player_owned and not actor.allied:actor.dead=true;actor.queue_free()
	arena.room.actors=arena.room.actors.filter(func(a):return is_instance_valid(a) and (a.player_owned or a.allied))
func enemy_near(arena,offset:Vector2i):
	var enemy=arena.spawn_actor("soldier",arena.player.cell+offset,false);enemy.set_physics_process(false);enemy.hp=50;enemy.max_hp=50
	enemy.position=arena.player.position+Vector3(offset.x,0,offset.y)
	return enemy
func shot(arena,target,sure:bool=false)->float:
	var bullet=arena.spawn_bullet(arena.player,arena.player.position,Vector2i.UP,1.0,true)
	bullet.opening=false;bullet.sure_crit=sure
	var amount=CombatMods.outgoing(arena,bullet,target)
	bullet.queue_free()
	return amount

func perk_checks():
	# Стрелок 20: every perk is on.
	var arena=await arena_for("recruit",20)
	clear_field(arena)
	var enemy=enemy_near(arena,Vector2i(0,-2))
	check("opening_shot" in arena.run.behavior_cards,"Стрелок: «Выдержка» rides along as a class passive")
	var plain=shot(arena,enemy);var forced=shot(arena,enemy,true)
	check(is_equal_approx(plain,1.0) and forced>plain*1.5,"«Глаз-алмаз»: a marked bullet always crits (%.2f → %.2f)" % [plain,forced])
	arena.run.sure_crit_until=-10.0
	for i in range(5):arena.effects.emit("shot",{"actor":arena.player})
	check(arena.run.sure_crit_until>=arena.run.elapsed,"«Глаз-алмаз»: the 5th volley is marked")
	var next=arena.spawn_bullet(arena.player,arena.player.position,Vector2i.UP,1.0,true);check(next.sure_crit,"the 5th volley's bullet carries the mark");next.queue_free()
	enemy.set_meta("crit_hit",true);arena.effects.emit("kill",{"actor":enemy})
	check(is_equal_approx(arena.effects.modify("fire_rate",1.0),1.15),"«Кураж»: a crit kill gives +15% fire rate")
	arena.run.elapsed+=3.5;check(is_equal_approx(arena.effects.modify("fire_rate",1.0),1.0),"«Кураж» ends after 3 s")
	arena.run.soldier_hp=arena.run.soldier_max_hp*.2
	check(shot(arena,enemy)>1.4,"«Последний рубеж»: at ≤25% health every shot crits")
	arena.run.soldier_hp=arena.run.soldier_max_hp
	var offers=[]
	for def in UpgradeRegistry.all():
		if RunUpgrades.eligible(arena,def,3):offers.append(def.id)
	check("opening_shot" not in offers and "last_stand" not in offers,"perk cards (and the same-named «Последний рубеж») never drop for the class")
	arena.queue_free();await settle()
	# Стрелок 10: the level 11+ perks are not on yet.
	arena=await arena_for("recruit",10);clear_field(arena);enemy=enemy_near(arena,Vector2i(0,-2))
	arena.run.soldier_hp=arena.run.soldier_max_hp*.2
	check(is_equal_approx(shot(arena,enemy),1.0),"before level 20 low health does not force a crit")
	arena.run.sure_crit_until=-10.0
	for i in range(5):arena.effects.emit("shot",{"actor":arena.player})
	check(arena.run.sure_crit_until<0,"before level 11 no volley is marked")
	arena.queue_free();await settle()
	# Штурмовик 16: «Отдача» staggers infantry near the soldier, once per 4 s; «урон вблизи» hits harder up close.
	arena=await arena_for("heavy",16);clear_field(arena)
	var near=enemy_near(arena,Vector2i(1,0));var far=enemy_near(arena,Vector2i(0,-4))
	check(arena.run.close_damage>0 and shot(arena,near)>shot(arena,far),"«Урон вблизи» counts within 2.5 cells")
	check(arena.run.guard_bullet>=.10+.12+.12,"«Бронежилет» and «Крепость» add their protection")
	arena.effects.emit("player_damaged",{"actor":arena.player,"amount":1.0})
	check(near.stun_time>0 and far.stun_time<=0,"«Отдача»: infantry within 1.5 cells is staggered, the far one is not")
	near.stun_time=0.0;arena.effects.emit("player_damaged",{"actor":arena.player,"amount":1.0})
	check(near.stun_time<=0,"«Отдача» waits 4 s")
	var offers_heavy=[]
	for def in UpgradeRegistry.all():
		if RunUpgrades.eligible(arena,def,3):offers_heavy.append(def.id)
	check("guard_bullet" not in offers_heavy and "fortress" not in offers_heavy,"Штурмовик: «Бронежилет» and «Крепость» cards do not drop")
	arena.queue_free();await settle()
	# Инженер 20: armour on vehicles, faster Q, workshop and boarding switches.
	arena=await arena_for("engineer",20)
	check("boarding" in arena.run.behavior_cards and "legend_field_workshop" in arena.run.behavior_cards and arena.run.marauder>=.2,"Инженер: «Абордаж», «Мастерская на колёсах», «Запасливый» are on")
	var armoured=GarageCatalog.stats("tank",arena).hp;var keep=arena.run.vehicle_armor;arena.run.vehicle_armor=0.0
	check(armoured>GarageCatalog.stats("tank",arena).hp,"«Броня техники» adds vehicle armour")
	arena.run.vehicle_armor=keep
	var q=Game.class_loadout()[0];arena.abilities.select(q);var fast=arena.abilities.interval();var cd=arena.run.class_cooldown;arena.run.class_cooldown=0.0
	check(cd>0 and fast<arena.abilities.interval(),"«Перезарядка Q» shortens the class ability")
	arena.queue_free();await settle()

func hud_checks():
	var arena=await arena_for("recruit",20)
	arena.hud._process(.1)
	var shown=arena.hud.skill_buttons.filter(func(b):return b.visible).size()
	check(arena.hud.skill_buttons.size()==2 and shown==1 and arena.abilities.slots==Game.class_loadout(),"battle HUD: one class ability button (%d shown)" % shown)
	arena.queue_free();await settle()

func window_checks():
	Game.reset_upgrades();Game.credits=100000;Game.profiles.selected=true;Game.selected_class="recruit";Game.class_levels["recruit"]=5
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub);await settle()
	hub.phase="combat";hub.open_station("fighter");await settle()
	var page=hub.build_menu.find_child("Page",true,false)
	check(page.find_children("Slot_*","Button",true,false).size()==1,"the class page has one slot, Q")
	page.open_path();await settle()
	var view=page.get_node("ClassPathView")
	var rows=view.find_children("Item_*","",true,false)
	check(rows.size()==20 and view.find_children("Header_*","",true,false).size()==4,"«Все уровни»: 20 rows in four chapters")
	var xs={}
	for row in rows:xs[roundi(row.position.x)]=true
	check(xs.size()==1,"rows sit in one column on one side of the track")
	check(view.find_child("Buy_7",true,false)!=null and view.find_children("Buy_*","",true,false).size()==1,"only the nearest level has a buy button")
	check(view.find_children("StatTile_*","",true,false).size()==5 and view.find_child("PathSummary",true,false).text.contains("ловит момент"),"summary: motto and five stat tiles")
	var level=ClassCatalog.level("recruit")
	view.find_child("Buy_7",true,false).pressed.emit();await settle()
	check(ClassCatalog.level("recruit")==level+1 and page.get_node_or_null("ClassPathView")!=null,"buying a level keeps the path open")
	hub.queue_free();await settle()
