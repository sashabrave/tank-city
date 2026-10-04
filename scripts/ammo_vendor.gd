extends Node3D
## Ammo vending machine (T-116) at the merchant and in every upgrade room — a loot box (T-159, T-187): two army
## crates with their odds per rarity (better the farther along the map), the ammo types that can drop, then a
## horizontal reel of ammo boxes spins and stops on the prize; after the reveal «Зарядить» puts it in a slot
## (the old one goes to the backpack) or «В рюкзак» keeps it. The prize is rolled first with the run's combat
## RNG; the reel's filler boxes use their own generator (UI never touches game randomness).
const PRICE=4
## Crates: [id, title, price, odds near the start, odds deep in the map] — odds per rarity 0..3.
const CRATES=[
	["army","Армейский ящик",4,[.64,.27,.075,.015],[.46,.34,.15,.05]],
	["officer","Офицерский ящик",7,[.24,.46,.23,.07],[.08,.44,.33,.15]],
]
const CELL=96.0
const GAP=8.0
var room:Node3D
var arena
var modal:Control
static func place(parent:Node3D,context,at:Vector3)->Node3D:
	var vendor=load("res://scripts/ammo_vendor.gd").new();vendor.room=parent;vendor.arena=context;vendor.position=at;parent.add_child(vendor);return vendor
func _ready():
	name="AmmoVendor"
	if not preload("res://scripts/machine_model.gd").attach(self,"res://assets/models/route/machine_ammo.glb",Color("8fe8ff"),1.3):
		var steel=Color("6c777b");var brass=Color("d9a441")
		Visuals.box(self,Vector3(0,.85,0),Vector3(.8,1.7,.6),steel,"gunmetal")
		Visuals.box(self,Vector3(0,1.25,.31),Vector3(.62,.62,.03),Color("1d2326"),"glass")
		# Cartridges standing behind the glass, one per ammo colour.
		var colors=["ff8a3d","86daec","f1cf55","9fe6ff","ff5a4a"]
		for i in range(colors.size()):
			var round=Visuals.box(self,Vector3(-.22+i*.11,1.2,.29),Vector3(.06,.24,.06),brass,"brass");var tip=Visuals.box(self,Vector3(-.22+i*.11,1.36,.29),Vector3(.05,.08,.05),Color(colors[i]))
			tip.material_override=Visuals.material(Color(colors[i]),true)
		Visuals.box(self,Vector3(0,.55,.32),Vector3(.5,.14,.04),Color("2a3033"))
		Visuals.box(self,Vector3(0,1.75,0),Vector3(.86,.12,.66),brass,"brass")
		var glow=OmniLight3D.new();add_child(glow);glow.position=Vector3(0,1.3,.7);glow.light_color=Color("9fe6ff");glow.light_energy=.5;glow.omni_range=2.0
	Visuals.label3d(self,"Боеприпасы · %d жетона · E" % PRICE,Vector3(0,2.1,0),Color("fff0ce"),22)
	preload("res://scripts/interaction_prompt.gd").attach(self,room,"Автомат боеприпасов",Vector3.ZERO,1.4)
func near(avatar:Node3D)->bool:return avatar.global_position.distance_to(global_position)<1.4
## How far along the map the run is, 0..1 (the crates' odds slide toward their deep values).
func depth()->float:
	if Campaign.endless:return 1.0
	var stage=Campaign.progress_index(arena.room_index) if arena.room_index>=0 else 0
	return clampf(stage/6.0,0.0,1.0)
func crate(id:String)->Array:
	for c in CRATES:
		if c[0]==id:return c
	return CRATES[0]
func odds(id:String)->Array:
	var c=crate(id);var t=depth();var result=[]
	for r in range(4):result.append(lerpf(float(c[3][r]),float(c[4][r]),t))
	return result
func types()->Array:return Ammo.TYPES.filter(func(t):return Ammo.fits(t,str(arena.weapon)))
## Rolls one item for the weapon in hand from a crate; empty when the run has too few tokens.
func buy(id:="army")->Dictionary:
	var price=int(crate(id)[2])
	if arena.run.tokens<price:return {}
	# The prize must have a place before it is paid for (audit 2026-10-03): «В рюкзак» or the swapped-out ammo.
	if Backpack.full(arena.run):arena.toast(Texts.render("Рюкзак полон — освободи ячейку в «Снаряжении»"));return {}
	arena.run.tokens-=price
	var pool=types()
	var type=pool[arena.run.combat_rng.randi_range(0,pool.size()-1)]
	var chances=odds(id);var value=arena.run.combat_rng.randf();var tier=0;var sum=0.0
	for r in range(3,-1,-1):
		sum+=float(chances[r])
		if value<sum:tier=r;break
	Game.progression.event("slot_play")
	return Ammo.roll(type,tier,arena.run.combat_rng.randi())

func open(ui_root:Control,done:Callable):
	if arena.run.tokens<int(CRATES[0][2]):
		Game.sound("ui_denied",room);arena.toast(Texts.render("Автомату нужно %d жетона") % int(CRATES[0][2]));done.call();return
	Ammo.ensure(arena.run,str(arena.weapon))
	modal=Control.new();modal.name="AmmoVendorResult";ui_root.add_child(modal);modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);modal.add_to_group("selection_scope")
	modal.set_meta("done",done)
	var shade=ColorRect.new();modal.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,.55)
	choose(ui_root)
func close():
	var done:Callable=modal.get_meta("done") if is_instance_valid(modal) else Callable()
	if is_instance_valid(modal):modal.queue_free()
	modal=null
	if done.is_valid():done.call()
func window(ui_root:Control,size:Vector2)->Panel:
	for child in modal.get_children():
		if child is Panel:child.queue_free()
	var screen=ui_root.get_viewport_rect().size;size=Vector2(minf(size.x,screen.x-32),minf(size.y,screen.y-32))
	var panel=UiKit.glass(modal,((screen-size)*.5).round(),size);panel.name="VendorWindow";return panel
func ammo_texture(type:String)->Texture2D:
	return UiKit.trimmed(UiKit.icon_texture("ammo/"+type if IconKit.has("ammo/"+type) else Ammo.ART.get(type,"stats/damage")))

## Step 1: two crates side by side — odds per rarity, what can drop, the price.
func choose(ui_root:Control):
	var panel=window(ui_root,Vector2(780,470));var w=panel.size.x
	UiKit.accent(UiKit.label(panel,"Армейский припас",Vector2(24,16),Vector2(w-120,36),24))
	UiKit.label(panel,"Жетонов: %d · боеприпасы под %s · чем дальше по карте, тем лучше шансы" % [arena.run.tokens,Texts.render(Game.LOOT.WEAPONS[str(arena.weapon)].name)],Vector2(24,54),Vector2(w-48,22),14,UiKit.MUTED).clip_text=true
	UiKit.button(panel,"×",Vector2(w-62,16),Vector2(44,40),close).name="Close"
	# What can drop: one icon per fitting ammo type.
	var pool=types();var icon=36.0
	for k in range(pool.size()):
		var t=TextureRect.new();panel.add_child(t);t.texture=ammo_texture(pool[k]);t.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;t.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.position=Vector2(24+k*(icon+6),84);t.size=Vector2(icon,icon);t.tooltip_text=Texts.render(Ammo.NAMES[pool[k]]+" боеприпасы")
	var col=(w-48-16)*.5;var top=136.0;var h=panel.size.y-top-20
	for c in range(CRATES.size()):
		var spec=CRATES[c];var x=24+c*(col+16);var chances=odds(spec[0])
		var card=UiKit.panel(panel,Vector2(x,top),Vector2(col,h),Color("2c352e") if c==0 else Color("3b3323"));card.name="Crate_"+str(spec[0])
		UiKit.label(card,spec[1],Vector2(18,14),Vector2(col-36,30),20,UiKit.INK if c==0 else UiKit.ORANGE)
		for r in range(4):
			var y=56+r*34;var color=Color(LootCatalog.RARITY_COLORS[r])
			UiKit.label(card,Texts.render(Ammo.RARITY_NAMES[r]),Vector2(18,y),Vector2(col*.45,22),15,color)
			var track=ColorRect.new();card.add_child(track);track.position=Vector2(col*.45+18,y+8);track.size=Vector2(col*.55-90,8);track.color=Color(1,1,1,.08)
			var fill=ColorRect.new();track.add_child(fill);fill.size=Vector2(track.size.x*clampf(float(chances[r])/.7,0,1),8);fill.color=color
			var pct=UiKit.label(card,"%s%%" % UiKit.number(snappedf(float(chances[r])*100,.1)),Vector2(col-70,y),Vector2(52,22),15,UiKit.INK);pct.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		var price=int(spec[2]);var id=str(spec[0])
		var b=UiKit.button(card,"Открыть · %d жетонов" % price,Vector2(18,h-66),Vector2(col-36,50),func():spin(ui_root,id),c==1 or arena.run.tokens>=price);b.name="Open_"+id
		b.disabled=arena.run.tokens<price;UiKit.muted_locked_button(b)
		if c==0:b.grab_focus.call_deferred()

## Step 2: the reel. The prize is fixed before the spin; the reel lands it under the marker.
func spin(ui_root:Control,id:String):
	var item=buy(id)
	if item.is_empty():return
	Game.sound("collect_token",room)
	var panel=window(ui_root,Vector2(780,330));var w=panel.size.x
	UiKit.accent(UiKit.label(panel,crate(id)[1],Vector2(24,16),Vector2(w-48,34),22))
	var view=Control.new();panel.add_child(view);view.name="Reel";view.position=Vector2(16,70);view.size=Vector2(w-32,CELL+24);view.clip_contents=true
	var strip=Control.new();view.add_child(strip);strip.position.y=12
	var looks=RandomNumberGenerator.new();looks.seed=hash([item.type,item.rarity,arena.run.tokens,Time.get_ticks_usec()])  # visual only
	var pool=types();var chances=odds(id);const COUNT=44;const WIN=38
	for k in range(COUNT):
		var type=str(item.type);var rarity=int(item.rarity)
		if k!=WIN:
			type=pool[looks.randi_range(0,pool.size()-1)];var v=looks.randf();var sum=0.0;rarity=0
			for r in range(3,-1,-1):
				sum+=float(chances[r])
				if v<sum:rarity=r;break
		var box=Panel.new();strip.add_child(box);box.position=Vector2(k*(CELL+GAP),0);box.size=Vector2(CELL,CELL);box.name="Box_%d" % k
		var frame=UiKit.style(Color(LootCatalog.RARITY_COLORS[rarity]).darkened(.7),10,Color(LootCatalog.RARITY_COLORS[rarity]));frame.set_border_width_all(2);box.add_theme_stylebox_override("panel",frame)
		var art=TextureRect.new();box.add_child(art);art.texture=ammo_texture(type);art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;art.position=Vector2(10,8);art.size=Vector2(CELL-20,CELL-24)
		var band=ColorRect.new();box.add_child(band);band.position=Vector2(8,CELL-12);band.size=Vector2(CELL-16,4);band.color=Color(LootCatalog.RARITY_COLORS[rarity])
	# The marker in the middle of the reel.
	var mark=ColorRect.new();view.add_child(mark);mark.color=UiKit.ORANGE;mark.size=Vector2(4,view.size.y);mark.position=Vector2(view.size.x*.5-2,0)
	var tip=UiKit.label(panel,"Крутится…",Vector2(24,view.position.y+view.size.y+14),Vector2(w-48,26),16,UiKit.MUTED);tip.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;tip.name="ReelTip"
	var target=-(WIN*(CELL+GAP))+view.size.x*.5-CELL*.5+looks.randf_range(-CELL*.3,CELL*.3)
	var reveal=func():
		if not is_instance_valid(panel):return
		strip.position.x=target
		var won=strip.get_node("Box_%d" % WIN);won.pivot_offset=won.size*.5
		var color=Color(LootCatalog.RARITY_COLORS[int(item.rarity)])
		if panel.has_node("Skip"):panel.get_node("Skip").hide()
		var lit=UiKit.style(color.darkened(.45),12,color);lit.set_border_width_all(4);lit.shadow_color=Color(color,.7);lit.shadow_size=14;won.add_theme_stylebox_override("panel",lit);won.z_index=2
		Texts.set_text(tip,Texts.render("Выпало!")+" "+Texts.render(Ammo.RARITY_NAMES[int(item.rarity)])+" · "+Texts.render(Ammo.NAMES[item.type]+" боеприпасы"));tip.add_theme_color_override("font_color",color)
		Game.sound("rare_reveal" if int(item.rarity)>=2 else "reroll",room)
		if UiKit.motion_enabled():
			var pop=won.create_tween();pop.tween_property(won,"scale",Vector2.ONE*1.18,.14).set_trans(Tween.TRANS_BACK);pop.tween_property(won,"scale",Vector2.ONE*1.08,.2)
		var go=UiKit.button(panel,"Дальше",Vector2(w*.5-130,panel.size.y-64),Vector2(260,48),func():result(ui_root,item),true);go.name="Next";go.grab_focus.call_deferred()
	if not UiKit.motion_enabled():reveal.call();return
	var last=[0]
	var t=strip.create_tween()
	t.tween_method(func(x:float):
		strip.position.x=x
		var passed=int(-x/(CELL+GAP))
		if passed!=last[0]:last[0]=passed;Game.sound("countdown_tick",room)
	,0.0,target,3.2).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	t.tween_callback(reveal)
	var skip=UiKit.button(panel,"Пропустить",Vector2(w-184,16),Vector2(160,40),func():t.kill();reveal.call());skip.name="Skip"

## Step 3: the prize compared with the loaded ammo; «Зарядить» or «В рюкзак».
func result(ui_root:Control,item:Dictionary):
	var same=arena.run.ammo_slots.filter(func(s):return s is Dictionary and s.type==item.type)
	var old:Dictionary=same[0] if not same.is_empty() else Ammo.replacing(arena.run)
	var rows=Ammo.compare_rows(item,old)
	var panel=window(ui_root,Vector2(560,250+rows.size()*30));var size=panel.size
	var color=Color(LootCatalog.RARITY_COLORS[clampi(int(item.rarity),0,3)])
	UiKit.label(panel,Texts.render(Ammo.RARITY_NAMES[int(item.rarity)]).to_lower(),Vector2(24,16),Vector2(500,22),14,color)
	UiKit.label(panel,Texts.render(Ammo.NAMES[item.type]+" боеприпасы"),Vector2(24,38),Vector2(500,34),24,Color(Ammo.COLORS[item.type]))
	var y=84.0
	for row in rows:
		UiKit.label(panel,str(row[1]).left(1).to_upper()+str(row[1]).substr(1),Vector2(24,y),Vector2(300,26),16)
		var value=UiKit.label(panel,"%s → %s" % [row[2],row[3]],Vector2(300,y),Vector2(236,26),16,UiKit.ORANGE if str(row[0]).begins_with("↑") else Color("ff8a7a") if str(row[0]).begins_with("↓") else UiKit.INK)
		value.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;y+=30
	var extra=[]
	if float(item.damage)>0:extra.append(Texts.render("урон пули")+" +%d%%" % roundi(item.damage*100))
	if item.twist:extra.append(Texts.render(Ammo.TWISTS[item.type]))
	if not extra.is_empty():UiKit.label(panel," · ".join(extra),Vector2(24,y),Vector2(512,26),14,color);y+=30
	var note=(Texts.render("Заменит")+": "+Texts.render(Ammo.NAMES[old.type])) if not old.is_empty() else Texts.render("Свободный слот")
	UiKit.label(panel,note,Vector2(24,y+4),Vector2(512,22),13,UiKit.MUTED)
	var bag_button=UiKit.button(panel,"В рюкзак",Vector2(24,size.y-66),Vector2(250,48),func():
		Backpack.stow(arena,item);close())
	if Backpack.full(arena.run):bag_button.disabled=true;bag_button.tooltip_text=Texts.render("Рюкзак полон")
	var load_button=UiKit.button(panel,"Зарядить",Vector2(size.x-274,size.y-66),Vector2(250,48),func():
		var out=Ammo.load_item(arena.run,item)
		# A cell was checked before paying (buy): the swapped-out ammo always has a place.
		if not out.is_empty():Backpack.stow(arena,out)
		Game.sound("weapon_equip",room);close(),true)
	load_button.grab_focus.call_deferred()
