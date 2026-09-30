extends Node
var failures=0
func check(ok:bool,title:String):
	if not ok:failures+=1;push_error(title)
func _ready():call_deferred("run")
func shot(path:String):
	await get_tree().process_frame;await get_tree().process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(path)
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	Settings.values.fullscreen=false;Settings.values.ui_theme="dark";Settings.apply()
	Game.selected_class="recruit";Game.class_unlocks=["recruit"];Game.class_first_slots=[];Game.class_second_slots=[];Game.class_levels={};Game.specializations={};Game.credits=180;Game.cores=20
	var gallery=load("res://scripts/ui/class_gallery.gd").new();add_child(gallery)
	await shot("/tmp/r13-printer-dark.png")
	check(gallery.tab=="shell" and gallery.viewed=="recruit","Equipped shell is default")
	check(not gallery.find_child("BuyFirst",true,false).disabled,"First purchase is explicit and available")
	gallery.buy_first();check(Game.credits==150 and "recruit" in Game.class_first_slots,"First ability purchase")
	gallery.buy_first();check(Game.credits==150,"No duplicate charge")
	check(gallery.find_child("BuyFirst",true,false)==null,"Purchased action removed")
	gallery.show_catalog();gallery.detail("gunner");check(Game.selected_class=="recruit" and Game.credits==150,"Preview is read only")
	gallery.equip();check(Game.selected_class=="gunner" and Game.credits==30,"Buy and equip shell")
	gallery.equip();check(Game.credits==30,"Owned shell not charged")
	gallery.buy_first();check(Game.credits==0,"Own shell ability independent")
	Game.credits=3000;gallery.buy_second();check("gunner" not in Game.class_second_slots,"Second level gate")
	Game.class_levels.gunner=5;gallery.buy_second();check(Game.credits==500 and "gunner" in Game.class_second_slots,"Second purchase")
	gallery.upgrade();check(Game.class_levels.gunner==6 and Game.class_levels.get("recruit",0)==0,"Shell level separate")
	for id in gallery.IDS:
		Game.selected_class=id;Game.class_levels[id]=7;Game.specializations[id]=2
		for weapon in ["shotgun","sniper","pistol"]:
			if weapon not in Game.LOOT.WEAPONS:continue
			Game.selected_weapon=weapon
			var preview=CombatStats.shell_preview(id)
			check(is_equal_approx(preview.health,CombatStats.initial_health()),"Health preview matches combat")
			check(is_equal_approx(preview.speed,CombatStats.soldier_speed()),"Speed preview matches combat")
			check(is_equal_approx(preview.damage,CombatStats.weapon().damage),"Damage preview matches combat")
			check(is_equal_approx(preview.pressure,CombatStats.probability()*100),"Pressure preview matches combat")
		CombatStats.shell_preview("recruit");check(Game.selected_class==id,"Preview does not equip")
	Game.selected_class="recruit";Game.class_first_slots=[];Game.class_levels={};Game.credits=180
	gallery.detail("recruit");Settings.values.ui_theme="light";Settings.changed.emit()
	await shot("/tmp/r13-printer-light.png")
	gallery.show_catalog();await shot("/tmp/r13-printer-catalog.png")
	gallery.tab="base";gallery.refresh();await shot("/tmp/r13-printer-common.png")
	var before=Game.credits;var price=Game.cost("health");gallery.find_child("Common_health",true,false).pressed.emit()
	check(Game.credits==before-price,"Common upgrade works")
	gallery.find_child("ResetCommon",true,false).pressed.emit();check(Game.health_level==0 and "gunner" in Game.class_unlocks,"Reset preserves shells")
	Texts.set_language("en");gallery.tab="shell";gallery.detail("recruit")
	await shot("/tmp/r13-printer-en.png")
	check(gallery.find_child("ShellTab",true,false).text=="Shell","Shell tab localized")
	get_window().content_scale_size=Vector2i(780,650);gallery.refresh()
	await shot("/tmp/r13-printer-narrow.png")
	get_window().content_scale_size=Vector2i(1440,810);Texts.set_language("ru")
	gallery.queue_free();await get_tree().process_frame
	var panel=UiKit.panel(self,Vector2(20,20),Vector2(260,180))
	var health=load("res://scripts/health_meter.gd").new();panel.add_child(health);health.position=Vector2(12,10);health.size=Vector2(220,45)
	var base=load("res://scripts/health_meter.gd").new();base.symbol="base";panel.add_child(base);base.position=Vector2(12,60);base.size=Vector2(220,45)
	var bars=UiKit.stat_bars(panel,Vector2(12,110),220,[["HP",3,5]],30)
	await shot("/tmp/r13-light-health.png")
	check(health.get_theme_color("font_color").v<.4 and base.get_theme_color("font_color").v<.4,"Health digits dark in light theme")
	check(bars.get_theme_color("font_color").v<.4,"Stats dark in light theme")
	Settings.values.ui_theme="dark";Settings.changed.emit();await shot("/tmp/r13-dark-health.png")
	check(health.get_theme_color("font_color").v>.8,"Dark theme restored")
	panel.queue_free();await get_tree().process_frame
	Settings.values.ui_theme="light";Settings.changed.emit()
	var arena=load("res://scenes/arena.tscn").instantiate();arena.auto_pause_enabled=false;add_child(arena);arena.set_physics_process(false);arena.player.set_physics_process(false);arena.phase="combat"
	await get_tree().create_timer(.25).timeout
	await shot("/tmp/r13-battle-light.png")
	check(arena.presentation.heading.get_theme_color("font_color").v>.8,"World announcement keeps contrast")
	check(arena.hud.health.get_theme_color("font_color").v<.4,"Live HUD light theme")
	arena.queue_free();await get_tree().process_frame
	print("PRINTER REVISION: failures=",failures);get_tree().quit(failures)
