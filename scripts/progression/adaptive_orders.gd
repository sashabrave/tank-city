extends RefCounted
const BASE={"infantry":12,"armor":4,"waves":4,"drones":6,"kills_buggy":8,"kills_apc":11,"kills_tank":14}
const TITLES={"infantry":"Уничтожь %d пехотинцев","armor":"Уничтожь %d машин","waves":"Зачисти %d волн","drones":"Уничтожь %d дронов","kills_buggy":"Уничтожь %d врагов на багги","kills_apc":"Уничтожь %d врагов на БТР","kills_tank":"Уничтожь %d врагов на танке"}
static func create(p,rng:RandomNumberGenerator)->Array:
	var depth=int(p.counters.get("depth",0))
	var pool=p.QUESTS.TELEGRAMS.filter(func(q):return (not q.has("vehicle") or q.vehicle in Game.garage.owned) and (q.event!="armor" or depth>=2))
	var result=[]
	for difficulty in range(3):
		var source=pool.pop_at(rng.randi_range(0,pool.size()-1));var q=source.duplicate(true)
		var baseline=float(BASE[q.event]);var observed=0.0;var samples=0
		for sortie in p.recent_sorties:
			if sortie.get(q.event,0)>0:observed+=float(sortie[q.event]);samples+=1
		if samples>0:observed/=samples
		var growth=1+.045*mini(depth,16)+.015*mini(maxi(0,p.level-1),8)
		var reference=maxf(baseline*growth,minf(observed,baseline*growth*1.6))
		q.goal=maxi(1,roundi(reference*[.75,1.0,1.15][difficulty]))
		q.text=TITLES[q.event] % q.goal;q.difficulty=["Лёгкий","Обычный","Сложный"][difficulty];q.adaptive_version=2
		q.run_limit=2 if difficulty<2 else 3; q.goal=roundi(q.goal*(1.5 if difficulty<2 else 2.0));q.text=TITLES[q.event] % q.goal
		q.hint="Счётчик общий на %d вылазки. Награду забери в командном центре." % q.run_limit
		q.alloy=maxi(20,roundi(float(source.alloy)*float(q.goal)/float(source.goal)*[.95,1.0,1.18][difficulty]))
		q.xp=maxi(15,roundi(float(source.xp)*float(q.goal)/float(source.goal)*[.95,1.0,1.12][difficulty]))
		result.append(q)
	return result
