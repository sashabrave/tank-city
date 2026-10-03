extends Node3D
## Slot machine (RoomLayout «Фортуна» spot): E pulls the lever and opens the reel window at once. Moved out of the
## merchant (2026-10-03) so any upgrade room can host it. Outcomes come from the run's combat RNG; the reels animate
## on their own visual RNG (scripts/ui/slot_window.gd).
const PRICE:=2
## Outcomes and weights: fewer blanks, alloy and an ammo box; a card is at least rare, an epic one is the jackpot.
const TABLE:=[["empty",30],["tokens",18],["heal",8],["alloy",16],["ammo",14],["card1",10],["card2",4]]
var room:Node3D
var arena
var modal:Control
## Outcome id of the latest pull (see TABLE); the reel window lands on its symbol.
var last_slot:="empty"
static func place(parent:Node3D,context,at:Vector3)->Node3D:
	var machine=load("res://scripts/slot_machine.gd").new();machine.room=parent;machine.arena=context;machine.position=at;parent.add_child(machine);return machine
func _ready():
	name="SlotMachine";scale=Vector3.ONE*1.25
	var red=Color("a8352d");var gold=Color("e5b34f")
	Visuals.box(self,Vector3(0,.35,0),Vector3(1.1,.7,.8),red.darkened(.25),"paint")
	Visuals.box(self,Vector3(0,1.15,-.05),Vector3(1.0,.9,.7),red,"paint")
	Visuals.box(self,Vector3(0,1.15,.31),Vector3(.86,.42,.04),Color("1d211f"),"glass")
	for i in range(3):Visuals.box(self,Vector3(-.28+i*.28,1.15,.34),Vector3(.22,.32,.02),Color("f4ecd6"))
	Visuals.box(self,Vector3(0,.74,.3),Vector3(1.04,.06,.32),gold,"brass")
	Visuals.box(self,Vector3(0,1.78,-.05),Vector3(1.1,.36,.74),gold,"brass")
	Visuals.box(self,Vector3(0,1.78,.33),Vector3(.8,.2,.02),Color("fff0ce"))
	Visuals.box(self,Vector3(.6,1.1,0),Vector3(.08,.5,.08),Color("6b6f6a"),"steel")
	Visuals.box(self,Vector3(.6,1.42,0),Vector3(.16,.16,.16),Color("d64a3c"))
	var glow=OmniLight3D.new();add_child(glow);glow.position=Vector3(0,1.4,.8);glow.light_color=Color("ffd27a");glow.light_energy=.7;glow.omni_range=2.4
	if room:preload("res://scripts/interaction_prompt.gd").attach(self,room,"Автомат · %d жетона" % PRICE,Vector3.ZERO,1.9,func():return true)
func near(avatar:Node3D)->bool:return avatar.global_position.distance_to(global_position)<1.9
## Pulls the lever: pays PRICE tokens, rolls the outcome and opens the reel window over ui_root.
## Returns the result line, or "" when there are not enough tokens.
func pull(ui_root:Control,done:Callable)->String:
	if arena.run.tokens<PRICE:
		Game.sound("ui_denied",self);done.call();return ""
	arena.run.tokens-=PRICE
	var line=play()
	Game.progression.event("slot_play")
	if ui_root:
		modal=preload("res://scripts/ui/slot_window.gd").new().setup(last_slot,line);ui_root.add_child(modal)
		modal.finished.connect(func():modal=null;done.call())
	else:done.call()
	return line
func use(ui_root:Control,done:Callable):
	if pull(ui_root,done)=="" and is_instance_valid(arena):arena.toast(Texts.render("Автомату нужно %d жетона") % PRICE)
func heal_full():
	arena.run.soldier_hp=arena.run.soldier_max_hp
	if is_instance_valid(arena.room.player) and arena.room.player.kind=="soldier":arena.room.player.hp=arena.run.soldier_hp;arena.room.player.refresh_health()
## One pull; returns the result line.
func play()->String:
	var total=0
	for outcome in TABLE:total+=outcome[1]
	var pick=arena.run.combat_rng.randi_range(0,total-1);var result="empty"
	for outcome in TABLE:
		pick-=outcome[1]
		if pick<0:result=outcome[0];break
	last_slot=result
	match result:
		"tokens":arena.run.tokens+=PRICE*2;return "Жетоны вернулись вдвойне"
		"heal":heal_full();return "Полное лечение"
		"alloy":
			var amount=EncounterRules.chest_alloy(arena.room_index,1)
			Game.earn(amount);arena.run.earned+=amount;return "Сплав: +%d" % amount
		"ammo":
			var types=Ammo.TYPES.filter(func(t):return Ammo.fits(t,str(arena.weapon)))
			var type=types[arena.run.combat_rng.randi_range(0,types.size()-1)]
			var item=Ammo.roll(type,1 if arena.run.combat_rng.randf()<.3 else 0,arena.run.combat_rng.randi())
			arena.run.ammo_bag.append(item)  # like the ammo machine: one over the backpack limit until the next field
			return Texts.render(Ammo.NAMES[type]+" боеприпасы")+" · "+Texts.render("в рюкзак")
		"card0","card1","card2":
			var ids=RunUpgrades.roll(arena,1)
			if ids.is_empty():last_slot="empty";return "Автомат: пусто"
			var tier=int(result.right(1));RunUpgrades.apply(arena,ids[0],tier)
			if tier==2:
				var tiger=Skins.grant("slot",RandomNumberGenerator.new())
				if tiger!="":return "Джекпот: %s · и форма «%s»" % [UpgradeRegistry.get_def(ids[0]).title,Skins.UNIFORMS[tiger].name]
			return "%s · %s" % [LootCatalog.RARITY_NAMES[tier],UpgradeRegistry.get_def(ids[0]).title]
	return "Пусто. Повезёт в другой раз"
