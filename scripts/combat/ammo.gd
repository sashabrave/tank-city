class_name Ammo
extends RefCounted
## Ammo (T-109…T-112). The weapon is loaded with ammo items: {type, rarity, stats}. A special ammo card is an
## item with its own rarity and random values; it goes into a slot (over standard first, otherwise over the
## active ammo). Only the active ammo works. Improvement cards of a type (Жар, Дольше…) drop only while that
## type is loaded and add to the item's values; they are kept for the sortie. A second slot is bought per weapon
## in the Arsenal; the active ammo is then switched with R (pad RS, a tap on the HUD cell).
## Weapons share two ammo classes: bullets (pistol, SMG, rifle, shotgun, sniper) and charges (RPG, grenade
## launcher); a type lists the classes it fits.
const STANDARD="standard"
const TYPES=["burn","stun","shock","explosive","ap","ricochet","cryo","cluster","napalm"]
const NAMES={"standard":"Обычные","burn":"Зажигательные","stun":"Контузящие","shock":"ЭМИ","explosive":"Разрывные","ap":"Бронебойные","ricochet":"Рикошет","cryo":"Криогенные","cluster":"Кассетные","napalm":"Напалм"}
const COLORS={"standard":"cfd3c8","burn":"ff8a3d","stun":"f1cf55","shock":"86daec","explosive":"ff5a4a","ap":"b7c2cc","ricochet":"c9a5ff","cryo":"9fe6ff","cluster":"ffcf5a","napalm":"ff6a1a"}
const CLASSES={"bullets":["pistol","smg","rifle","shotgun","sniper"],"charges":["rpg","grenade_launcher"]}
const FITS={"burn":["bullets","charges"],"stun":["bullets"],"shock":["bullets","charges"],"explosive":["bullets"],"ap":["bullets"],"ricochet":["bullets"],"cryo":["bullets","charges"],"cluster":["charges"],"napalm":["charges"]}
## Rolled values per type: [key, label, min, max, unit]. «%» values are stored as shares (0.2 = 20 %).
const STATS={
	"burn":[["chance","Шанс поджога",.12,.4,"%"],["power","Сила огня",.25,.6,"%"]],
	"stun":[["chance","Шанс оглушения",.05,.16,"%"],["time","Оглушение",.6,1.2,"с"]],
	"shock":[["bonus","Урон по технике",.25,.8,"%"],["jolt","Шанс замкнуть технику",.0,.25,"%"]],
	"explosive":[["radius","Радиус взрыва",.5,.9,"кл"],["splash","Урон взрыва",.25,.55,"%"]],
	"ap":[["pierce","Пробой",1,2,""],["armor","Урон по броне",.1,.35,"%"]],
	"ricochet":[["bounces","Отскоков",1,2,""],["bounce_damage","Урон отскока",.45,.75,"%"]],
	"cryo":[["slow","Замедление",.2,.4,"%"],["freeze","Шанс заморозить",.0,.08,"%"]],
	"cluster":[["bomblets","Суббоеприпасов",3,5,""],["bomblet_damage","Урон суббоеприпаса",.25,.5,"%"]],
	"napalm":[["fire_time","Горит",2.0,4.5,"с"],["fire_radius","Радиус пожара",.7,1.2,"кл"]],
}
## Where each rarity rolls inside the range (share of min→max).
const RARITY_SPAN=[[0.0,.35],[.3,.6],[.55,.85],[.8,1.0]]
const RARITY_NAMES=["Обычные","Редкие","Эпические","Легендарные"]
## Legendary twist per type (one line on the card; the effect is wired in CombatMods).
const TWISTS={"burn":"Горящие враги поджигают соседей","stun":"Каждый крит оглушает","shock":"Разряд перескакивает на соседнюю технику","explosive":"Убитый враг тоже взрывается","ap":"Ещё +1 пробитие","ricochet":"Ещё +1 отскок","cryo":"Замёрзший враг разлетается осколками","cluster":"Суббоеприпасы разлетаются шире","napalm":"Горящие враги поджигают соседей"}
## Card art for the new types (the first three have their own upgrade icons).
const ART={"explosive":"upgrades/legend_detonator","ap":"upgrades/pierce","ricochet":"upgrades/legend_ricochet","cryo":"pickups/freeze","cluster":"abilities/grenade","napalm":"upgrades/burn_long"}
## Arsenal price of the second slot for a weapon (alloy).
const SLOT_PRICE=600

static func weapon_class(weapon:String)->String:
	for key in CLASSES:
		if weapon in CLASSES[key]:return key
	return "bullets"
static func fits(type:String,weapon:String)->bool:return type==STANDARD or weapon_class(weapon) in FITS.get(type,[])
static func standard()->Dictionary:return {"type":STANDARD,"rarity":0,"stats":{},"damage":0.0,"twist":false}

## A rolled ammo item. Deterministic for a card: the same seed gives the same item on the card and on pick.
static func roll(type:String,rarity:int,seed:int)->Dictionary:
	var rng=RandomNumberGenerator.new();rng.seed=seed
	rarity=clampi(rarity,0,3);var span:Array=RARITY_SPAN[rarity]
	var stats={}
	for spec in STATS.get(type,[]):
		var t=rng.randf_range(span[0],span[1])
		var value=lerpf(float(spec[2]),float(spec[3]),t)
		stats[spec[0]]=roundi(value) if spec[4]=="" else snappedf(value,.01)
	# Epic and up: a second bonus — more bullet damage. Legendary adds the type's twist.
	var damage=snappedf(rng.randf_range(.05,.12),.01) if rarity>=2 else 0.0
	return {"type":type,"rarity":rarity,"stats":stats,"damage":damage,"twist":rarity>=3}
static func seed_for(arena,type:String,tier:int)->int:
	return hash([arena.run.run_seed,arena.room.room_index,arena.room.wave,arena.run.upgrade_history.size(),type,tier])

static func capacity(weapon:String)->int:return 2 if weapon in Game.ammo_slot_weapons else 1
## Slots hold items; older saves held type names — those become plain common items.
static func ensure(run,weapon:String):
	for i in range(run.ammo_slots.size()):
		if not run.ammo_slots[i] is Dictionary:
			var name=str(run.ammo_slots[i])
			run.ammo_slots[i]=standard() if name not in TYPES else roll(name,0,hash(name))
	var size=capacity(weapon)
	while run.ammo_slots.size()<size:run.ammo_slots.append(standard())
	while run.ammo_slots.size()>size:
		if run.ammo_active>=run.ammo_slots.size()-1:run.ammo_active=0
		run.ammo_slots.pop_back()
	run.ammo_active=clampi(run.ammo_active,0,run.ammo_slots.size()-1)
static func item(run)->Dictionary:
	if run==null or run.ammo_slots.is_empty():return standard()
	var slot=run.ammo_slots[clampi(run.ammo_active,0,run.ammo_slots.size()-1)]
	return slot if slot is Dictionary else standard()
static func active(run)->String:return str(item(run).type)
## The active item if it fits the weapon in hand (bullets vs charges), otherwise standard.
static func effective(arena)->Dictionary:
	var current=item(arena.run)
	return current if fits(str(current.type),str(arena.weapon)) else standard()
static func types_loaded(run)->Array:
	return run.ammo_slots.map(func(s):return str(s.type) if s is Dictionary else str(s)) if run!=null else []
static func loaded(run,type:String)->bool:return type in types_loaded(run)
static func is_on(run,type:String)->bool:return active(run)==type
## Value of a rolled stat of the active ammo (0 when another type is active).
static func stat(run,type:String,key:String)->float:
	var current=item(run)
	return float(current.stats.get(key,0.0)) if current.type==type else 0.0
## Which slot a new item goes to: a standard slot first, otherwise the active one.
static func target_slot(run)->int:
	for i in range(run.ammo_slots.size()):
		if run.ammo_slots[i] is Dictionary and run.ammo_slots[i].type==STANDARD:return i
	return clampi(run.ammo_active,0,run.ammo_slots.size()-1)
## The item a new one would push out ({} when a standard slot takes it).
static func replacing(run,_type:String="")->Dictionary:
	var slot=run.ammo_slots[target_slot(run)]
	return {} if not slot is Dictionary or slot.type==STANDARD else slot
static func load_item(run,new_item:Dictionary)->Dictionary:
	var at=target_slot(run)
	# The same type already loaded is upgraded in place (the old item goes to the bag).
	for i in range(run.ammo_slots.size()):
		if run.ammo_slots[i] is Dictionary and run.ammo_slots[i].type==new_item.type:at=i
	var old=run.ammo_slots[at]
	run.ammo_slots[at]=new_item;run.ammo_active=at
	return old if old is Dictionary and old.type!=STANDARD else {}
static func switch(arena)->bool:
	var run=arena.run
	if run==null or run.ammo_slots.size()<2:return false
	run.ammo_active=(run.ammo_active+1)%run.ammo_slots.size()
	Game.sound("weapon_equip",arena)
	arena.toast(Texts.render("Боеприпасы")+": "+Texts.render(NAMES.get(active(run),"")))
	return true
## The ammo type an effect card belongs to (base or improvement), or "".
static func type_of(card_id:String)->String:
	if card_id in TYPES:return card_id
	var def=UpgradeRegistry.get_def(card_id)
	if def==null:return ""
	for need in def.requires:
		if need.begins_with("card:") and need.trim_prefix("card:") in TYPES:return need.trim_prefix("card:")
	return ""

## Text of one rolled value.
static func value_text(spec:Array,value:float)->String:
	match str(spec[4]):
		"%":return "%d%%" % roundi(value*100)
		"с":return UiKit.number(value)+" с"
		"кл":return UiKit.number(value)+" кл"
	return str(roundi(value))
## Card rows comparing a new item with the one it replaces: [arrow+value, label, old, new].
static func compare_rows(new_item:Dictionary,old:Dictionary)->Array:
	var rows=[]
	for spec in STATS.get(new_item.type,[]):
		var key=spec[0];var value=float(new_item.stats.get(key,0.0))
		var before=float(old.stats.get(key,0.0)) if old.get("type","")==new_item.type else 0.0
		# A rolled 0 (e.g. no short-circuit chance on a common EMP) is noise on the card (T-127).
		if is_zero_approx(value) and is_zero_approx(before):continue
		var arrow="↑ " if value>before+.0001 else "↓ " if value<before-.0001 else "= "
		rows.append([arrow+value_text(spec,value),Texts.render(spec[1]).to_lower(),value_text(spec,before) if old.get("type","")==new_item.type else "—",value_text(spec,value)])
	return rows
static func describe(new_item:Dictionary)->String:
	var parts=[]
	for spec in STATS.get(new_item.type,[]):parts.append(Texts.render(spec[1])+" "+value_text(spec,float(new_item.stats.get(spec[0],0.0))))
	if float(new_item.get("damage",0.0))>0:parts.append(Texts.render("урон пули")+" +%d%%" % roundi(new_item.damage*100))
	if new_item.type=="ap":parts.append(Texts.render("щит пробивает с шансом")+" %d%%" % roundi(shield_pierce(new_item)*100))
	if new_item.get("twist",false):parts.append(Texts.render(TWISTS.get(new_item.type,"")))
	return " · ".join(parts)
## Бронебойные vs the shield trooper's raised shield (T-156): a chance that grows with the box's armor stat
## (rarity), about 30% on a common box up to ~55% on a legendary one.
static func shield_pierce(item:Dictionary)->float:
	if str(item.get("type",""))!="ap":return 0.0
	return clampf(.2+float(item.get("stats",{}).get("armor",.1)),0.0,.6)
## Card strip data «old → new» (T-127): {from:{name,color,texture}, to:{…}, rest}. Same type: rarity names.
static func swap_data(old:Dictionary,new_item:Dictionary,rest:String)->Dictionary:
	var part=func(item:Dictionary)->Dictionary:
		if item.is_empty():return {"name":"Свободный слот","color":"6f7a70"}
		var type=str(item.type)
		var key="ammo/"+type if IconKit.has("ammo/"+type) else {"standard":"stats/damage","burn":"upgrades/burn","stun":"upgrades/stun","shock":"upgrades/shock"}.get(type,ART.get(type,"stats/damage"))
		var label=NAMES.get(type,type)
		if not old.is_empty() and old.get("type","")==new_item.get("type",""):label=RARITY_NAMES[clampi(int(item.get("rarity",0)),0,3)]
		return {"name":label,"color":COLORS.get(type,"cfd3c8"),"texture":UiKit.trimmed(UiKit.icon_texture(key))}
	var result={"from":part.call(old),"to":part.call(new_item)}
	if rest!="":result["rest"]=rest
	return result
