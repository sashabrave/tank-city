extends Node
## Auto-fed encyclopedia: each registry entry has an article, the reference is listed and reads in English.
var errors=0
func check(value:bool,message:String):
	if value:print("PASS ",message)
	else:errors+=1;push_error("FAIL: "+message)
func _ready():
	Settings.persistence_enabled=false;Game.save_enabled=false
	var feed=preload("res://scripts/ui/encyclopedia_feed.gd")
	var ids=feed.articles().map(func(a):return a.id)
	check(UpgradeRegistry.all().filter(func(d):return d.weight>0).all(func(d):return "auto_card_"+d.id in ids),"every offered card has an article")
	check(StatRegistry.all().all(func(d):return "auto_stat_"+d.id in ids),"every characteristic has an article")
	check(BossCatalog.DATA.keys().all(func(id):return "auto_boss_"+id in ids),"every boss has an article")
	var catalog=preload("res://scripts/ui/encyclopedia_catalog.gd")
	check(feed.CATEGORY in catalog.categories() and catalog.entries().size()==Texts.document.articles.size()+ids.size(),"reference joins the encyclopedia")
	check(not catalog.search("Танк",feed.CATEGORY).is_empty(),"search finds reference articles")
	Texts.set_language("en")
	var cyrillic=RegEx.new();cyrillic.compile("[А-Яа-яЁё]")
	var bad=feed.articles().filter(func(a):return a.section in ["Техника","Боссы"] and cyrillic.search(Texts.render(a.text))!=null)
	check(bad.is_empty(),"vehicle and boss articles are fully translated "+str(bad.map(func(a):return Texts.render(a.text)).slice(0,2)))
	Texts.set_language("ru")
	print("ENCYCLOPEDIA FEED: %d failures" % errors);get_tree().quit(1 if errors else 0)
