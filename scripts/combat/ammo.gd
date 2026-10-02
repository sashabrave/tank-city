class_name Ammo
extends RefCounted
## Ammo slots (T-109…T-111). The weapon is loaded with one ammo type at a time; a picked special ammo card goes
## into a slot, and its improvement cards (Жар, Дольше, Чаще…) only drop while that type is loaded. Every effect
## works only while its ammo is the active one. A second slot is bought per weapon in the Arsenal; then the
## active ammo is switched with a key (R / a pad button / a tap on the HUD cell). Levels of every type are kept
## until the end of the sortie, so loading a type back restores its upgrades.
const STANDARD="standard"
const TYPES=["burn","stun","shock"]
const NAMES={"standard":"Обычные","burn":"Зажигательные","stun":"Контузящие","shock":"ЭМИ"}
const COLORS={"standard":"cfd3c8","burn":"ff8a3d","stun":"f1cf55","shock":"86daec"}
## Arsenal price of the second slot for a weapon (alloy).
const SLOT_PRICE=600

static func capacity(weapon:String)->int:return 2 if weapon in Game.ammo_slot_weapons else 1
static func ensure(run,weapon:String):
	var size=capacity(weapon)
	while run.ammo_slots.size()<size:run.ammo_slots.append(STANDARD)
	while run.ammo_slots.size()>size:
		if run.ammo_active>=run.ammo_slots.size()-1:run.ammo_active=0
		run.ammo_slots.pop_back()
	run.ammo_active=clampi(run.ammo_active,0,run.ammo_slots.size()-1)
static func active(run)->String:
	if run==null or run.ammo_slots.is_empty():return STANDARD
	return str(run.ammo_slots[clampi(run.ammo_active,0,run.ammo_slots.size()-1)])
static func loaded(run,type:String)->bool:return run!=null and type in run.ammo_slots
static func is_on(run,type:String)->bool:return active(run)==type
## Which ammo a new type would push out: "" when a slot is still standard (nothing is lost).
static func replacing(run,type:String)->String:
	if type in run.ammo_slots:return ""
	if STANDARD in run.ammo_slots:return ""
	return active(run)
## Loads the type: into a standard slot first, otherwise over the active ammo. The loaded type becomes active.
static func load(run,type:String):
	var at=run.ammo_slots.find(type)
	if at<0:
		at=run.ammo_slots.find(STANDARD)
		if at<0:at=clampi(run.ammo_active,0,run.ammo_slots.size()-1)
		run.ammo_slots[at]=type
	run.ammo_active=at
static func switch(arena)->bool:
	var run=arena.run
	if run==null or run.ammo_slots.size()<2:return false
	run.ammo_active=(run.ammo_active+1)%run.ammo_slots.size()
	Game.sound("weapon_equip",arena)
	arena.toast(Texts.render("Патроны")+": "+Texts.render(NAMES.get(active(run),"")))
	return true
## The ammo type an effect card belongs to (base or improvement), or "".
static func type_of(card_id:String)->String:
	if card_id in TYPES:return card_id
	var def=UpgradeRegistry.get_def(card_id)
	if def==null:return ""
	for need in def.requires:
		if need.begins_with("card:") and need.trim_prefix("card:") in TYPES:return need.trim_prefix("card:")
	return ""
