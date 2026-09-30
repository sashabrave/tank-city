class_name SentenceCase
extends RefCounted
static var capitals:RegEx
static var initial:RegEx
const KEEP=["ПП","РПГ","ОФ","ББ","БТР","HP","FPS","MSAA","UI","WASD","ESC","OK","ПК","ИИ","DPS","GL","CPU","GPU","HUD","ID","API","PNG","JSON","GLB","APC","SMG","RPG","HQ","AI","AP","HE","II","III","IV","VI","VII","VIII","IX","XII"]
static func normalize(value:String)->String:
	if capitals==null:
		capitals=RegEx.new();capitals.compile("[А-ЯЁA-Z]{2,}")
		initial=RegEx.new();initial.compile("[А-Яа-яЁёA-Za-z]")
	var lines=value.split("\n")
	for i in range(lines.size()):
		var line=lines[i];var matches=capitals.search_all(line);matches.reverse()
		for found in matches:
			var word=found.get_string()
			if word in KEEP:continue
			line=line.substr(0,found.get_start())+word.to_lower()+line.substr(found.get_end())
		var first=initial.search(line)
		# BBCode tags are markup, not the first word of a sentence.
		while first!=null and line.rfind("[",first.get_start())>line.rfind("]",first.get_start()):
			var closing=line.find("]",first.get_start())
			if closing<0:break
			first=initial.search(line,closing+1)
		if first!=null:line=line.substr(0,first.get_start())+first.get_string().to_upper()+line.substr(first.get_end())
		lines[i]=line
	return "\n".join(lines)
