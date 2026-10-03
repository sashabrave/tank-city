extends RefCounted
## End of a sortie. Left: the loot ledger — alloy gathered, what a defeat took away (the bar shrinks, coins
## tumble off the top counter and fall off-screen), the total that reaches the base, documents and blueprints.
## Right: fields, time, kills, and killed enemies by type rising one by one as a staircase. Every step clicks.
## Visual only: no game RNG, the numbers come from the finished run.
const ICON=preload("res://scripts/ui/enemy_type_icon.gd")
const GEAR=preload("res://scripts/ui/gear_page.gd")
const STEP=.2

const KILLERS={"soldier":"стрелок","shield":"щитовик","grenadier":"гранатомётчик","sniper":"снайпер","rpg_soldier":"рпгшник","buggy":"багги","apc":"БТР","tank":"танк","boss":"генерал","drone":"дрон-минёр","flyer":"летающий дрон","mortar":"миномёт","zombie":"зомби","blast":"взрыв"}
static func show(hud,arena,won:bool,reason:String):
	var panel:Panel=hud.modal_base("Задание выполнено" if won else "Связь потеряна",reason,"",650)
	if not won:
		# T-086: who finished the base or the soldier.
		var base_lost=arena.base_hp<=0
		var by=str(arena.get_meta("base_hit_by" if base_lost else "hero_hit_by",""))
		if by!="":
			var who=Texts.render(KILLERS.get(by,by))
			if who!=who.to_upper():who=who.left(1).to_lower()+who.substr(1)  # a name mid-sentence; «БТР» stays
			var cause=UiKit.label(panel,(Texts.render("Базу добил") if base_lost else Texts.render("Бойца сразил"))+": "+who,Vector2(30,108),Vector2(panel.size.x-60,26),17,Color("ff9b84"))
			cause.name="DeathCause"
	panel.name="RunResult"
	# Twice the old gap between the two middle columns (T-051).
	var width=panel.size.x;var left=Vector2(30,150);var right=Vector2(width*.5+45,150);var column=width*.5-75
	var earned=int(arena.earned);var lost=int(arena.run.lost_alloy);var kept=maxi(0,earned-lost)
	var clock=[.15]
	var at=func(step:float=STEP)->float:clock[0]+=step;return clock[0]
	# — Loot —
	UiKit.accent(UiKit.label(panel,"Добыча",left,Vector2(column,26),UiKit.SECTION_SIZE,UiKit.MUTED))
	var gathered=ledger(panel,left+Vector2(0,36),column,"Собрано за вылазку","+%d" % earned,UiKit.INK,at.call())
	count_up(gathered,earned,"+%d",clock[0])
	var bar_y=left.y+76
	var track=ColorRect.new();panel.add_child(track);track.position=Vector2(left.x,bar_y);track.size=Vector2(column,10);track.color=Color(1,1,1,.08)
	var fill=ColorRect.new();track.add_child(fill);fill.size=Vector2(0,10);fill.color=UiKit.ORANGE;fill.name="AlloyFill"
	var grow=panel.create_tween();grow.tween_interval(clock[0]);grow.tween_property(fill,"size:x",column,.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var y=bar_y+22
	if not won and lost<=0 and int(arena.run.tokens)>0:
		var token_drop=panel.create_tween();token_drop.tween_interval(.9);token_drop.tween_callback(func():Game.sound("debris",hud);drop_tokens(hud,int(arena.run.tokens)))
	if lost>0:
		var loss_at=at.call(.75)
		var minus=ledger(panel,Vector2(left.x,y),column,"Отнято при выбывании","−%d" % lost,Color("ff6b57"),loss_at)
		minus.name="LossValue"
		var lost_part=ColorRect.new();track.add_child(lost_part);lost_part.color=Color("ff6b57");lost_part.size=Vector2(0,10);lost_part.position.x=column;lost_part.name="LossPart"
		var share=float(lost)/maxf(1.0,float(earned))
		var shrink=panel.create_tween();shrink.tween_interval(loss_at)
		shrink.tween_callback(func():Game.sound("debris",hud);drop_coins(hud,lost);drop_tokens(hud,int(arena.run.tokens)))
		shrink.tween_property(fill,"size:x",column*(1.0-share),.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		shrink.parallel().tween_property(lost_part,"size:x",column*share,.6)
		shrink.parallel().tween_property(lost_part,"position:x",column*(1.0-share),.6)
		shrink.tween_property(lost_part,"modulate:a",0.35,.4)
		y+=34
	var line=ColorRect.new();panel.add_child(line);line.position=Vector2(left.x,y+4);line.size=Vector2(column,1);line.color=Color(1,1,1,.14)
	var total_at=at.call(.6)
	UiKit.label(panel,"Итого в штаб",Vector2(left.x,y+14),Vector2(column*.6,30),18,UiKit.INK)
	var coin=UiKit.icon(panel,"alloy",Vector2(left.x+column-34,y+12),Vector2(34,34))
	var total=UiKit.label(panel,"0",Vector2(left.x+column*.4,y+8),Vector2(column*.6-42,44),34,Color("8fe895") if kept>0 else UiKit.MUTED);total.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;total.name="KeptTotal"
	for node in [total,coin]:node.modulate.a=0
	var show_total=panel.create_tween();show_total.tween_interval(total_at)
	show_total.tween_callback(func():Game.sound("collect_alloy",hud))
	show_total.tween_property(total,"modulate:a",1.0,.12);show_total.parallel().tween_property(coin,"modulate:a",1.0,.12)
	count_up(total,kept,"%d",total_at,.7)
	pop(panel,total,total_at+.7)
	y+=64
	# The equipped cells (2026-10-03): the gun in hand and the loaded ammo stay on the field when the run ends —
	# the next sortie starts with the hub's gun and standard ammo. One line each, its icon falls like a coin.
	var losses=equipped_losses(arena.run)
	if not losses.is_empty():
		UiKit.label(panel,"Потеряно",Vector2(left.x,y+6),Vector2(column,24),15,UiKit.MUTED);y+=32
	for gone_item in losses:
		var line_at=at.call(.2)
		var row=ledger(panel,Vector2(left.x,y),column,gone_item.what,gone_item.name,Color("ff9b84"),line_at)
		row.name="LostEquip_"+gone_item.what
		row.size.x-=36
		var mark=UiKit.icon(row.get_parent(),gone_item.icon,Vector2(column-30,1),Vector2(28,28));mark.name="LostIcon"
		heavy_fall(hud,mark,line_at+.5)
		y+=32
	# The whole backpack (one inventory with the gear screen): blueprints kept bright; lost blueprints char and
	# drop; guns, ammo and aid kits never reach the hub and fall out of their cells, heavier than the coins.
	var saved=arena.pending_recipes if won else arena.get_meta("saved_recipes",[])
	var gone=arena.get_meta("lost_recipes",[])
	var items=[]
	for pair in [["weapon",arena.run.weapon_bag],["ammo",arena.run.ammo_bag],["supply",arena.run.supplies]]:
		for item in pair[1]:items.append([pair[0],item])
	UiKit.label(panel,"Рюкзак · %d / %d" % [saved.size()+gone.size()+items.size(),Backpack.capacity()],Vector2(left.x,y+6),Vector2(column,24),15,UiKit.MUTED)
	var side=minf(72.0,floorf((column-8.0*(MAX_SLOTS-1))/MAX_SLOTS));var pitch=side+8.0
	var shown=saved.size()+gone.size()+items.size()
	for slot in range(mini(shown,MAX_SLOTS),MAX_SLOTS):
		var empty=UiKit.panel(panel,Vector2(left.x+slot*pitch,y+34),Vector2(side,side),Color("262b27"));empty.modulate.a=.45
		if slot>=Backpack.capacity():
			lock_mark(empty,side);empty.tooltip_text=Texts.render("Ячейка закрыта — расширяется в хабе")
	var x=left.x
	for entry in saved.map(func(r):return ["recipe",r,true])+gone.map(func(r):return ["recipe",r,false])+items.map(func(e):return [e[0],e[1],false]):
		if x+side>left.x+column+1:break
		var cell=UiKit.panel(panel,Vector2(x,y+34),Vector2(side,side),Color("2f3b33") if entry[2] else Color("262b27"));cell.modulate.a=0
		var icon_key=GEAR.icon_key(entry[0],entry[1])
		cell.tooltip_text=Texts.render(GEAR.item_name(entry[0],entry[1]))+("" if entry[2] else " · "+Texts.render("потерян"))
		var art=UiKit.icon(cell,icon_key,Vector2(side*.14,side*.11),Vector2(side*.72,side*.72));art.name="Art"
		var appear=at.call(.12)
		reveal(cell,appear,"ui_confirm" if entry[2] else "debris",hud)
		if entry[0]=="recipe":
			UiKit.locked_preview(art,not entry[2])
			if not entry[2]:
				UiKit.label(cell,"✕",Vector2(side-20,0),Vector2(20,20),14,Color("ff6b57"))
				# A lost blueprint chars and drops off the bottom of the screen.
				var burn=cell.create_tween();burn.tween_interval(appear+.6)
				burn.tween_property(cell,"modulate",Color(1,.45,.25,1),.25)
				burn.parallel().tween_property(cell,"rotation",.35,.6)
				burn.tween_property(cell,"position:y",panel.size.y+120,.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		else:
			# Run gear: the picture leaves its cell and falls; the cell stays empty.
			heavy_fall(hud,art,appear+.55)
		x+=pitch
	# — Summary —
	clock[0]=.15
	UiKit.accent(UiKit.label(panel,"Сводка",right,Vector2(column,26),UiKit.SECTION_SIZE,UiKit.MUTED))
	var fields=mini(arena.room_index+(1 if won else 0),Campaign.SIZES.size())
	var best=int(Game.progression.counters.get("best_kills",0));var record=arena.kills>best and arena.kills>0
	if record:Game.progression.event("best_kills",arena.kills,true)
	ledger(panel,right+Vector2(0,36),column,"Поля","%d / %d" % [fields,Campaign.SIZES.size()],UiKit.INK,at.call())
	ledger(panel,right+Vector2(0,70),column,"Время","%d:%02d" % [int(arena.elapsed/60.0),int(arena.elapsed)%60],UiKit.INK,at.call())
	var kills=ledger(panel,right+Vector2(0,104),column,"Враги",str(arena.kills),UiKit.INK,at.call())
	if record:UiKit.label(kills,"Рекорд",Vector2(column-190,-12),Vector2(100,16),12,UiKit.ORANGE)
	if Campaign.daily:
		var score=DailyRun.score(Campaign.cycle,arena.room_index,arena.kills);var day_best=int(DailyRun.best(Campaign.daily_key).get("score",-1))
		var place=DailyBoard.place(Campaign.daily_key,score)
		ledger(panel,right+Vector2(0,138),column,"Счёт дня"+(" · место %d" % place if place<=DailyBoard.TOP else "")+(" · рекорд" if score>day_best else ""),str(score),UiKit.ORANGE if score>day_best else UiKit.INK,at.call())
	# Killed enemies: one tile per type, each a little higher and to the right — a staircase.
	var kinds:Array=arena.run.kills_by.keys()
	kinds.sort_custom(func(a,b):return int(arena.run.kills_by[a])>int(arena.run.kills_by[b]))
	var heading_y=right.y+(184 if Campaign.daily else 150)
	if not kinds.is_empty():UiKit.label(panel,"Уничтожено",Vector2(right.x,heading_y),Vector2(column,24),15,UiKit.MUTED)
	var base=Vector2(right.x,heading_y+60)
	var tile=Vector2(64,74);var per_row=int((column+8)/(tile.x+8))
	for i in range(mini(kinds.size(),per_row*2)):
		var row=i/per_row;var col=i%per_row
		var pos=base+Vector2(col*(tile.x+8),row*(tile.y+16)-col*10)
		var card=UiKit.panel(panel,pos,tile,Color(1,1,1,.05));card.modulate.a=0;card.name="Kill_"+str(kinds[i])
		var icon=ICON.new();icon.kind=str(kinds[i]);card.add_child(icon);icon.position=Vector2(6,2);icon.size=Vector2(52,50);icon.mouse_filter=Control.MOUSE_FILTER_PASS
		var count=UiKit.label(card,"×%d" % int(arena.run.kills_by[kinds[i]]),Vector2(0,50),Vector2(tile.x,22),15,UiKit.ORANGE);count.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		reveal(card,at.call(.14),"countdown_tick",hud,Vector2(0,14))
	UiKit.button(panel,"В хаб",Vector2(width-310,panel.size.y-76),Vector2(280,52),func():arena.leave(),true)

## One "title …… value" line that fades in at `delay`.
const MAX_SLOTS=Backpack.CELLS
## A small padlock drawn from two panels: the shackle ring and the body.
static func lock_mark(cell:Control,side:float):
	var u=side/72.0
	var shackle=Panel.new();cell.add_child(shackle);shackle.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var ring=UiKit.style(Color.TRANSPARENT,int(9*u),Color("9aa39a"));ring.set_border_width_all(maxi(2,int(3*u)));shackle.add_theme_stylebox_override("panel",ring)
	shackle.position=Vector2(side*.5-11*u,side*.5-17*u);shackle.size=Vector2(22*u,22*u)
	var body=Panel.new();cell.add_child(body);body.mouse_filter=Control.MOUSE_FILTER_IGNORE
	body.add_theme_stylebox_override("panel",UiKit.style(Color("9aa39a"),int(4*u),Color("9aa39a")))
	body.position=Vector2(side*.5-15*u,side*.5-5*u);body.size=Vector2(30*u,22*u)
static func ledger(panel:Control,pos:Vector2,width:float,title:String,value:String,color:Color,delay:float)->Label:
	var row=Control.new();panel.add_child(row);row.position=pos;row.size=Vector2(width,30);row.modulate.a=0
	UiKit.label(row,title,Vector2(0,4),Vector2(width*.6,24),16,UiKit.MUTED)
	var number=UiKit.label(row,value,Vector2(width*.4,0),Vector2(width*.6,30),20,color);number.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	reveal(row,delay,"pickup",panel)
	return number
static func reveal(node:Control,delay:float,sound:String,owner:Node,rise:=Vector2(0,6)):
	var target=node.position;node.position+=rise
	var tween=node.create_tween();tween.tween_interval(delay)
	tween.tween_callback(func():Game.sound(sound,owner))
	tween.tween_property(node,"modulate:a",1.0,.16);tween.parallel().tween_property(node,"position",target,.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
static func count_up(label:Label,value:int,template:String,delay:float,duration:=.45):
	var tween=label.create_tween();tween.tween_interval(delay)
	tween.tween_method(func(v:float):label.text=template % int(v),0.0,float(value),duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():Texts.set_text(label,template % value))
static func pop(panel:Control,node:Control,delay:float):
	node.pivot_offset=node.size*Vector2(1,.5)
	var tween=panel.create_tween();tween.tween_interval(delay)
	tween.tween_property(node,"scale",Vector2.ONE*1.15,.08);tween.tween_property(node,"scale",Vector2.ONE,.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Lost alloy: coins drop from the top resource counter, tumble and fall off the bottom of the screen,
## with a red «−N» under the counter.
## Run tokens burn on defeat (T-090): token coins fall out of their counter, which folds away.
## What falls matches what was lost (0.8.0): the amount is split into random pieces of 1, 5 and 10 (no more
## than `cap` pieces), and a bigger piece is a bigger icon. One token lost — one token falls. Visual RNG only.
static func pieces(total:int,cap:int)->Array:
	var rng=RandomNumberGenerator.new();rng.randomize()
	var result=[];var left=total
	while left>0:
		var options=[1]
		if left>=5:options.append(5)
		if left>=10:options.append(10)
		# Prefer big pieces when many are left, so the pile stays under the cap.
		var value=options.back() if left/float(options.back())>cap-result.size()-1 else options[rng.randi_range(0,options.size()-1)]
		result.append(value);left-=value
	result.shuffle()
	return result.slice(0,cap+4)  # a huge loss still falls as a readable handful of big pieces
static func drop_pile(layer:Control,origin:Vector2,icon:String,values:Array,base:float):
	var screen=layer.get_viewport_rect().size
	var rng=RandomNumberGenerator.new();rng.randomize()
	for i in range(values.size()):
		var side=base*(1.0 if values[i]==1 else 1.35 if values[i]==5 else 1.7)
		var coin=TextureRect.new();layer.add_child(coin);coin.texture=UiKit.icon_texture(icon);coin.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;coin.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.size=Vector2(side,side);coin.pivot_offset=coin.size*.5;coin.position=origin+Vector2(rng.randf_range(-14,24),rng.randf_range(-2,6));coin.z_index=119;coin.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var time=rng.randf_range(.95,1.25);var delay=i*.06+rng.randf_range(0,.05)
		var fall=coin.create_tween().set_parallel(true)
		fall.tween_property(coin,"position",coin.position+Vector2(rng.randf_range(-90,90),screen.y+60),time).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fall.tween_property(coin,"rotation",rng.randf_range(-1.6,1.6)*TAU,time).set_delay(delay)
		fall.chain().tween_callback(coin.queue_free)
static func drop_tokens(hud,count:int):
	if count<=0:return
	var layer:Control=hud.root;var screen=layer.get_viewport_rect().size
	var icon=ResourceStrip.token_icon
	var origin=icon.get_global_rect().position if is_instance_valid(icon) and icon.visible else Vector2(screen.x*.5+40,10)
	ResourceStrip.tokens_lost=true
	drop_pile(layer,origin,"token",pieces(count,10),22.0)
static func drop_coins(hud,lost:int):
	var layer:Control=hud.root;var screen=layer.get_viewport_rect().size
	var origin=Vector2(screen.x*.5-60,34)
	var minus=UiKit.label(layer,"−%d" % lost,origin+Vector2(-10,26),Vector2(120,30),22,Color("ff6b57"));minus.name="AlloyLoss";minus.z_index=120
	var fade=minus.create_tween();fade.tween_property(minus,"position:y",minus.position.y+18,.9);fade.parallel().tween_property(minus,"modulate:a",0.0,.9).set_delay(.6);fade.tween_callback(minus.queue_free)
	drop_pile(layer,origin,"alloy_single",pieces(lost,14),24.0)

## What the end of a run takes from the equipped cells: a gun that is not the hub's plain one and loaded special
## ammo. [{what, name, icon}] — «Оружие» / «Боеприпасы».
static func equipped_losses(run)->Array:
	var result=[]
	if run==null:return result
	var gun=str(run.weapon)
	if LootCatalog.is_gun(gun) and (gun!=Game.selected_weapon or int(run.weapon_rarity)>0 or not run.weapon_stats.is_empty()):
		result.append({"what":"Оружие","name":GEAR.item_name("weapon",{"id":gun,"rarity":run.weapon_rarity}),"icon":gun})
	for slot in run.ammo_slots:
		if slot is Dictionary and str(slot.get("type",Ammo.STANDARD))!=Ammo.STANDARD:
			result.append({"what":"Боеприпасы","name":Texts.render(Ammo.NAMES.get(str(slot.type),"")),"icon":GEAR.icon_key("ammo",slot)})
	return result
## A lost item falls like the resource coins, only heavier and smoother: a small lift, then a long eased drop
## with a slow sway and little spin, off the bottom of the screen. Visual RNG only.
static func heavy_fall(hud,node:Control,delay:float):
	if not is_instance_valid(node):return
	var layer:Control=hud.root;var screen=layer.get_viewport_rect().size
	var rng=RandomNumberGenerator.new();rng.randomize()
	var t=node.create_tween();t.tween_interval(delay)
	t.tween_callback(func():
		if not is_instance_valid(node):return
		var start=node.get_global_rect().position;var size=node.size
		node.get_parent().remove_child(node);layer.add_child(node);node.z_index=119;node.position=start;node.size=size;node.pivot_offset=size*.5;node.modulate.a=1.0
		Game.sound("debris",hud)
		var time=rng.randf_range(1.5,1.8);var drift=rng.randf_range(-50,50);var spin=rng.randf_range(-.45,.45)
		var lift=node.create_tween();lift.tween_property(node,"position:y",start.y-16,.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		var fall=lift.chain().set_parallel(true)
		fall.tween_property(node,"position:y",screen.y+size.y+40,time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		fall.tween_property(node,"position:x",start.x+drift,time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		fall.tween_property(node,"rotation",spin,time).set_trans(Tween.TRANS_SINE)
		fall.chain().tween_callback(node.queue_free))
