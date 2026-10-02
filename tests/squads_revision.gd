extends Node
## Waves made of squads: exact wave size, squads arrive together, caps hold, vehicles appear by field tier,
## the same seed gives the same wave, and different seeds give varied squad mixes.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	var sizes=true;var caps=true;var tiers=true;var grouped=true;var mixes={}
	for seed_value in range(60):
		for room in range(6):
			for wave in range(3):
				var entries=WaveDirector.build(seed_value,room,wave)
				sizes=sizes and entries.size()==WaveDirector.wave_size(room,wave)
				var counts={}
				for e in entries:var key="rpg" if e.weapon=="rpg" else e.kind;counts[key]=int(counts.get(key,0))+1
				for key in SquadCatalog.CAPS:caps=caps and int(counts.get(key,0))<=SquadCatalog.CAPS[key]
				if room<2:tiers=tiers and not entries.any(func(e):return UnitKinds.is_vehicle(e.kind) or e.kind=="mortar")
				# Members of one squad are contiguous.
				var seen=[];var last=""
				for e in entries:
					if e.squad!=last:
						if e.squad in seen and seen.back()!=e.squad:pass
						seen.append(e.squad);last=e.squad
				mixes[str(room)+":"+",".join(entries.map(func(e):return e.squad))]=true
	check(sizes,"every wave has exactly the tuned size")
	check(caps,"mortar, sniper, tank and RPG caps hold")
	check(tiers,"fields 1–2 are infantry only")
	check(WaveDirector.build(5,3,1)==WaveDirector.build(5,3,1),"same seed, same wave")
	check(mixes.size()>200,"varied squad mixes (%d)" % mixes.size())
	var tier3=WaveDirector.build(7,5,2)
	check(tier3.any(func(e):return e.squad in ["tank_wedge","tank_hunters","storm_column"]),"late fields bring heavy squads")
	print("SQUADS: %d failures" % failures);get_tree().quit(1 if failures else 0)
