extends Node
# Every player-facing text from registries and station tabs renders in English with no Cyrillic left.
# A new card, stat, class or tab without an English line fails here; tools/localization/missing_strings.py
# lists the literal strings in code. Also: the auto-fed encyclopedia, video call lines, text templates,
# shared terms and the technical guides reader. Settings and profile writes stay disabled; document saves go
# into a fresh temporary folder.
var failures=0
var cyrillic=RegEx.new()
func check(ok:bool,message:String):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func check_text(source:String,where:String):
	if source.strip_edges()=="":return
	var rendered=Texts.render(source)
	if cyrillic.search(rendered)!=null:
		failures+=1;print("FAIL ",where,": ",source," → ",rendered)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false;cyrillic.compile("[А-Яа-яЁё]")
	var language=Texts.language;Texts.set_language("en")
	for def in UpgradeRegistry.all():
		check_text(def.title,"card "+def.id);check_text(def.detail,"card detail "+def.id)
	for def in StatRegistry.all():
		check_text(def.title,"stat "+def.id);check_text(def.description,"stat text "+def.id)
	for key in RunUpgrades.FAMILIES:check_text(RunUpgrades.FAMILIES[key],"family "+key)
	for name in RunUpgrades.TIER_NAMES:check_text(name,"tier")
	for key in RunUpgrades.PREVIEW_LABELS:check_text(RunUpgrades.PREVIEW_LABELS[key][0],"preview "+key)
	for id in ClassCatalog.ROSTER:
		check_text(Game.CLASSES[id].name,"class "+id);check_text(Game.CLASSES[id].desc,"class text "+id)
		check_text(ClassCatalog.info(id).role,"class role "+id)
		if not ClassCatalog.info(id).unlock.is_empty():check_text(ClassCatalog.info(id).unlock.text,"class unlock "+id)
	for concept in ClassCatalog.CONCEPTS:
		for part in concept:check_text(part,"concept "+concept[0])
	for path in ["res://scripts/ui/stations/fighter_station.gd","res://scripts/ui/stations/arsenal_station.gd","res://scripts/ui/stations/hq_station.gd","res://scripts/ui/stations/garage_station.gd"]:
		var provider=load(path).new()
		check_text(provider.title(),path);check_text(provider.subtitle(),path)
		for tab in provider.tabs():
			check_text(tab[1],path+" tab")
			for item in provider.items(tab[0]):
				check_text(str(item.title),path+" item");check_text(str(item.get("group","")),path+" group")

	# from encyclopedia_feed_revision: every registry entry gets an article; the reference joins the encyclopedia.
	var feed=preload("res://scripts/ui/encyclopedia_feed.gd")
	var ids=feed.articles().map(func(a):return a.id)
	check(UpgradeRegistry.all().filter(func(d):return d.weight>0).all(func(d):return "auto_card_"+d.id in ids),"every offered card has an article")
	check(StatRegistry.all().all(func(d):return "auto_stat_"+d.id in ids),"every characteristic has an article")
	check(BossCatalog.DATA.keys().all(func(id):return "auto_boss_"+id in ids),"every boss has an article")
	var catalog=preload("res://scripts/ui/encyclopedia_catalog.gd")
	check(feed.CATEGORY in catalog.categories() and catalog.entries().size()==Texts.document.articles.size()+ids.size(),"reference joins the encyclopedia")
	var bad=feed.articles().filter(func(a):return a.section in ["Техника","Боссы"] and cyrillic.search(Texts.render(a.text))!=null)
	check(bad.is_empty(),"vehicle and boss articles are fully translated "+str(bad.map(func(a):return Texts.render(a.text)).slice(0,2)))

	# from video_call_revision: every tutorial call line has English.
	var Call=preload("res://scripts/ui/video_call.gd")
	var missing=[]
	for call in Call.CALLS:
		for line in Call.CALLS[call]:
			if not Texts.localization.exact.has(str(line[1]).to_lower()):missing.append(line[1])
	check(missing.is_empty(),"all call lines have English "+str(missing))

	# from arrival_drones_text: number templates translate whole; Roman numerals survive.
	for text in ["База отремонтирована: +1.5 HP","Доставка: 2.5 с · лимит 3","Командир · 420 / 700","+1000 Сплава","Генерал II · 4×4"]:
		var rendered=Texts.render(text)
		check(cyrillic.search(rendered)==null,"English template: "+rendered)
	check(Texts.render("Генерал II · 4×4")=="General II · 4×4","Roman numerals preserved")
	# from arrival_drones_text: Texts.set_text stores the canonical case in both languages, refresh keeps it.
	var label=Label.new();add_child(label)
	for lang in ["ru","en"]:
		Texts.set_language(lang)
		Texts.set_text(label,"пистолет")
		check(label.text==("Pistol" if lang=="en" else "Пистолет"),"canonical text at assignment (%s)" % lang)
		var before=label.text;NumberDisplay.refresh()
		check(label.text==before,"no case change before drawing (%s)" % lang)

	# from tablet_content: encyclopedia search and categories (Russian source).
	Texts.set_language("ru")
	check(catalog.entries().size()>=50,"encyclopedia has at least 50 entries")
	check(catalog.search("ЛЕД").size()>0 and catalog.search("напор столкновение").size()>0,"search finds by word and by several words")
	check(catalog.search("несуществующаястрока").is_empty(),"search for nonsense finds nothing")
	check(catalog.search("","Враги","Пехота").size()==4,"category and section filter (4 infantry entries)")
	check(not catalog.search("Танк",feed.CATEGORY).is_empty(),"search finds reference articles")
	# from tablet_content: a shared term renames everywhere live, saves to disk and restores; validation rejects an empty name.
	var original=Texts.document.duplicate(true);var draft=original.duplicate(true)
	draft.terms.pressure.name="Импульс";draft.terms.pressure.description="Тестовое общее описание."
	label.text="Напор 40%";Texts.update_widget(label)
	var folder=OS.get_temp_dir().path_join("warcats_texts_%d" % Time.get_ticks_usec());DirAccess.make_dir_recursive_absolute(folder)
	var doc_path=folder.path_join("texts.json")
	check(Texts.save_document(draft,doc_path)=="","the edited text document saves")
	Texts.update_widget(label);check(label.text=="Импульс 40%","a shown label follows the renamed term")
	label.text="Напор 55%";Texts.update_widget(label);check(label.text=="Импульс 55%","a new text uses the renamed term")
	check(Texts.render("НАПОР / напор / напористый")=="Импульс / импульс / напористый","case kept, longer words untouched")
	check(Texts.render("{{pressure.description}}")=="Тестовое общее описание.","term description placeholder")
	var saved=JSON.parse_string(FileAccess.get_file_as_string(doc_path))
	check(saved is Dictionary and saved.terms.pressure.name=="Импульс","the saved file holds the new name")
	Texts.document=original;Texts.rebuild();Texts.update_widget(label);check(label.text=="Напор 55%","restoring the document restores the term")
	var broken=original.duplicate(true);broken.terms.pressure.name="";check(Texts.validate(broken)!="","validation rejects an empty term name")
	for file in DirAccess.get_files_at(folder):DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)
	label.queue_free()

	# from technical_guides: the reader scans the guides folders and finds a new document in a fresh folder.
	var reader=preload("res://scripts/ui/technical_guides.gd").new();reader.size=Vector2(1000,600);add_child(reader)
	await get_tree().process_frame
	check(reader.documents.size()>=12,"guide folders scanned (%d documents)" % reader.documents.size())
	if not reader.documents.is_empty():
		var path=reader.documents.back().path;reader.open_document(path);reader.reload()
		check(reader.selected_path==path and reader.body.get_parsed_text().length()>100,"refresh keeps the document and reads it")
	var guides="%s/warcats_guides_%d" % [OS.get_temp_dir(),Time.get_ticks_usec()];DirAccess.make_dir_recursive_absolute(guides)
	var md=FileAccess.open(guides.path_join("added.md"),FileAccess.WRITE);md.store_string("# Added document\nNew contents");md.close()
	reader.documents.clear();reader.tree.clear();reader.scan(guides,reader.tree.create_item(),0)
	check(reader.documents.size()==1,"a new folder is discovered")
	if reader.documents.size()==1:
		reader.open_document(reader.documents[0].path);check("New contents" in reader.body.get_parsed_text(),"the new document is readable")
	DirAccess.remove_absolute(guides.path_join("added.md"));DirAccess.remove_absolute(guides)
	reader.queue_free();await get_tree().process_frame

	Texts.set_language(language)
	print("LOCALIZATION: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
