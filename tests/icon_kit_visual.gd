extends Node3D
## Static icon symbols (guides/03_release/07_icon_kit_brief.md): run cards show one drawn symbol without a frame,
## on a rarity-tinted background; every id in data/icon_kit.json resolves to its symbol. Window shots:
## /tmp/r13-icon-kit-cards.png and /tmp/r13-icon-kit-grid.png. No profile or settings writes.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func shot(path:String):
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png(path)
func source(texture:Texture2D)->String:
	if texture is AtlasTexture:return texture.atlas.resource_path
	return texture.resource_path if texture else ""
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	get_window().size=Vector2i(1600,900)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=4;add_child(arena);arena.auto_pause_enabled=false
	await get_tree().create_timer(1.0).timeout;arena.set_physics_process(false)
	arena.room.upgrade_offers=[{"id":"guard_blast","tier":1},{"id":"burn_long","tier":2},{"id":"health","tier":3}]
	arena.hud._show_upgrades_now()
	await get_tree().create_timer(1.2).timeout
	var icons=arena.hud.modal.find_children("Icon","TextureRect",true,false)
	check(icons.size()>=3,"three run cards with icons (%d)" % icons.size())
	for rect in icons:
		check(source(rect.texture).begins_with(IconKit.ROOT),"card icon is a drawn symbol (%s)" % source(rect.texture).get_file())
		check(rect.find_children("RarityFrame","",true,false).is_empty(),"no frame around the icon")
		var glow=rect.get_parent().get_node_or_null("RarityGlow")
		check(glow!=null and glow.material is ShaderMaterial and glow.get_index()==0,"rarity-tinted background under the content")
	await shot("/tmp/r13-icon-kit-cards.png")
	var holder=Control.new();arena.hud.modal.add_child(holder);holder.position=Vector2(40,40)
	var reward=preload("res://scripts/ui/choice_card.gd").create(holder,Vector2.ZERO,Vector2(280,390),{"color":Color("4aa3ff"),"heading":"Редкое","category":"Штаб","title":"Медблок","detail":"Лечит штаб","icon":"hq_medbay"},func():pass,"upgrade")
	var category:TextureRect=reward.get_node("CategoryIcon")
	check(source(category.texture).begins_with(IconKit.ROOT) and category.modulate==Color.WHITE,"reward card category is a drawn symbol, not a tinted line glyph")
	for key in ["quests","guide","notifications"]:check(IconKit.has("sender/"+key),"sender emblem drawn: "+key)
	for key in ["buggy","apc","tank","vehicle_apc"]:check(source(UiKit.icon_texture(key)).get_file().begins_with("veh_"),"vehicle picture is the detailed drawing: "+key)
	holder.queue_free()
	arena.queue_free()
	await get_tree().process_frame
	var layer=CanvasLayer.new();add_child(layer)
	var back=ColorRect.new();back.color=Color("232c29");back.size=Vector2(1600,900);layer.add_child(back)
	var ids:Array=IconKit.table().icons.keys()
	var drawn=0
	for i in ids.size():
		var rect=UiKit.icon(back,ids[i],Vector2(16+(i%20)*78,16+(i/20)*84),Vector2(64,64))
		if source(rect.texture).begins_with(IconKit.ROOT):drawn+=1
	check(drawn==ids.size(),"every kit id shows its drawn symbol (%d / %d)" % [drawn,ids.size()])
	var symbols={}
	for id in ids:
		if id.begins_with("upgrades/"):symbols[IconKit.table().icons[id]]=symbols.get(IconKit.table().icons[id],[])+[id]
	var shared=symbols.keys().filter(func(s):return symbols[s].size()>1)
	check(shared.is_empty(),"run cards do not share a symbol %s" % [shared])
	await get_tree().create_timer(.3).timeout
	await shot("/tmp/r13-icon-kit-grid.png")
	print("ICON KIT: %d failures" % failures);get_tree().quit(1 if failures else 0)
