extends Node3D
## Typography audit: opens the main screens in Russian and English, saves window shots and lists every
## visible label or button whose text does not fit its box (clipped width, cut lines, spill below).
## Output folder: $TYPO_OUT or /tmp/typography. Profile writes go to a fresh temp folder; settings are not saved.
var out="/tmp/typography"
var problems:Array=[]
var screen=""
func settle(n:=3):
	for i in n:await get_tree().process_frame
func shot():
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s-%s.png" % [out,Texts.language,screen])
func _ready():call_deferred("run")

func audit(root:Node):
	for node in root.find_children("*","Control",true,false):
		if not node.is_visible_in_tree() or not (node is Label or node is Button):continue
		if node is OptionButton or node.text.strip_edges()=="" or node.size.x<4:continue
		var font:Font=node.get_theme_font("font");var size=node.get_theme_font_size("font_size");var text:String=node.text
		var width=node.size.x;var height=node.size.y
		if node is Button:
			var box=node.get_theme_stylebox("normal")
			width-=box.get_margin(SIDE_LEFT)+box.get_margin(SIDE_RIGHT);height-=box.get_margin(SIDE_TOP)+box.get_margin(SIDE_BOTTOM)
			if node.icon:width-=node.icon.get_width()*minf(1.0,height/maxf(1.0,node.icon.get_height()))+node.get_theme_constant("h_separation")
		var issue=""
		if node is Label and node.autowrap_mode!=TextServer.AUTOWRAP_OFF:
			var lines=node.get_line_count();var shown=node.get_visible_line_count()
			var needed=lines*node.get_line_height()+(lines-1)*node.get_theme_constant("line_spacing")
			if node.max_lines_visible<0 and needed>height+2:issue="lines %d need %dpx of %dpx" % [lines,needed,height]
			elif shown<lines and node.max_lines_visible<0:issue="shows %d of %d lines" % [shown,lines]
		else:
			var widest=0.0
			for line in text.split("\n"):widest=maxf(widest,font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x)
			if widest>width+1:issue="width %d of %d at %dpx" % [widest,width,size]
			var lines=text.split("\n").size()
			if lines*font.get_height(size)>height+4 and node is Label:issue+=(" · " if issue else "")+"height %d of %d" % [lines*font.get_height(size),height]
		if issue!="" and node.text_overrun_behavior!=TextServer.OVERRUN_NO_TRIMMING:issue+=" · ellipsis"
		if issue!="":
			var entry="[%s/%s] %s — «%s» (%s)" % [Texts.language,screen,issue,text.replace("\n"," ⏎ ").left(70),str(node.get_parent().name)+"/"+str(node.name)]
			if entry not in problems:problems.append(entry);print("FIT ",entry)

func capture(name:String,root:Node,wait:=.5):
	screen=name;print("SCREEN ",Texts.language," ",name);await get_tree().create_timer(wait).timeout;await settle(4)
	audit(root);await shot()

func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Settings.values.fullscreen=false;Settings.values.ui_motion=false;Settings.apply()
	if OS.get_environment("TYPO_OUT")!="":out=OS.get_environment("TYPO_OUT")
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size=Vector2i(1600,900)
	Game.save_blocked=false;Game.reset_upgrades();Campaign.configure(1)
	Game.profiles.directory="/tmp/typography-profiles-%d" % Time.get_ticks_usec();Game.profiles.active=1
	Game.ProfileStore.write_file(Game.profiles.path(1),Game.serialize_progress(),Game.ProfileSchema.validate)
	Game.credits=4200
	for id in Game.BUILD_COST:if id not in Game.built_workshops:Game.built_workshops.append(id)
	var memory=preload("res://scripts/ui/tablet_memory.gd");memory.loaded=true;memory.state={}
	for language in ["ru","en"]:
		Texts.set_language(language)
		var hub=preload("res://scripts/hub.gd").open_practice(self)
		await get_tree().create_timer(1.0).timeout;hub.phase="combat";hub.set_physics_process(false)
		await capture("hub",hub)
		for kind in hub.STATIONS:
			hub.open_station(kind);await capture("station-"+kind,hub);hub.close_station()
		hub.show_build_menu();await capture("build",hub);hub.close_station()
		hub.show_command();await capture("command",hub)
		var command=hub.find_children("*","Control",true,false).filter(func(n):return n.has_method("telegram_offer_card"))
		if not command.is_empty():
			command[0].nav_collapsed=true;command[0].refresh();await capture("command-collapsed",hub)
			var feed=command[0].find_child("QuestFeed",true,false);var panel_rect=command[0].content.get_global_rect()
			for bubble in feed.find_children("Bubble","Control",true,false):
				if bubble.get_global_rect().end.x>panel_rect.end.x+1:problems.append("[%s/command-collapsed] bubble ends at %d past %d" % [Texts.language,bubble.get_global_rect().end.x,panel_rect.end.x]);print("FIT ",problems[-1])
			command[0].nav_collapsed=false
		hub.close_station()
		ProfileMenu.hub=hub;ProfileMenu.open();await capture("profiles",get_tree().root);ProfileMenu.close()
		hub.queue_free();await settle(3)
		var picker=preload("res://scripts/ui/world_select.gd").new();add_child(picker);await capture("worlds",picker);picker.queue_free();await settle(2)
		# The route map is shot once: a second map in the same process waits on the finished run state.
		if language=="ru":
			var route=load("res://scripts/route_map.gd").new();route.wave_seed=92;add_child(route)
			await capture("route",route,1.0)
			route.modal=preload("res://scripts/route_room_dialog.gd").build(route,route.plan[0][0]);await capture("route-room",route)
			route.queue_free();await settle(3)
		var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=41;add_child(arena);arena.auto_pause_enabled=false
		await settle(30);arena.set_physics_process(false)
		await capture("battle-hud",arena)
		arena.presentation.announce("Волна 2","Пехота с фланга",2.0);await capture("phase-steps",arena,.12)
		await capture("phase-title",arena,.6)
		arena.phase="upgrade";arena.upgrade_offers=[{"id":"last_stand","tier":1},{"id":"opening_shot","tier":1},{"id":"exit_dash","tier":1}]
		arena.hud._show_upgrades_now();await capture("upgrade-cards",arena)
		arena.hud.close_modal();arena.phase="combat"
		for tab in ["inventory","fighter","quests","notifications","music","settings","guide","about","tech"]:
			var view=preload("res://scripts/ui/field_tablet.gd").new();view.tab=tab;view.arena=arena;add_child(view)
			await capture("tablet-"+tab,view);view.queue_free();await settle(2)
		arena.run.earned=184;arena.run.kills=23;arena.run.elapsed=402;arena.run.kills_by={"rifle":8,"smg":5,"buggy":2}
		arena.hud.show_result(true,"Поле 4 · Тихий двор");await capture("result",arena,3.2)
		arena.queue_free();await settle(3)
	Texts.set_language("ru")
	print("TYPOGRAPHY: %d problems, shots in %s" % [problems.size(),out])
	get_tree().quit()
