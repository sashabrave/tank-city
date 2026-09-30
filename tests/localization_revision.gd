extends Node
# Every player-facing text from registries and station tabs renders in English with no Cyrillic left.
# A new card, stat, class or tab without an English line fails here; tools/localization/missing_strings.py
# lists the literal strings in code. Settings writes stay disabled.
var failures=0
var cyrillic=RegEx.new()
func check_text(source:String,where:String):
	if source.strip_edges()=="":return
	var rendered=Texts.render(source)
	if cyrillic.search(rendered)!=null:
		failures+=1;print("FAIL ",where,": ",source," → ",rendered)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;cyrillic.compile("[А-Яа-яЁё]")
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
	Texts.set_language(language)
	print("LOCALIZATION: %d failures" % failures)
	get_tree().quit(failures)
