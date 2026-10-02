extends RefCounted
## End of a sortie. Left: the loot ledger — alloy gathered, what a defeat took away (the bar shrinks, coins
## tumble off the top counter and fall off-screen), the total that reaches the base, documents and blueprints.
## Right: fields, time, kills, and killed enemies by type rising one by one as a staircase. Every step clicks.
## Visual only: no game RNG, the numbers come from the finished run.
const ICON=preload("res://scripts/ui/enemy_type_icon.gd")
const STEP=.2

static func show(hud,arena,won:bool,reason:String):
	var panel:Panel=hud.modal_base("Задание выполнено" if won else "Связь потеряна",reason,"",650)
	panel.name="RunResult"
	var width=panel.size.x;var left=Vector2(30,150);var right=Vector2(width*.5+15,150);var column=width*.5-45
	var earned=int(arena.earned);var lost=int(arena.run.lost_alloy);var kept=maxi(0,earned-lost)
	var docs=maxi(0,Game.cores-int(arena.get_meta("start_documents",Game.cores)))
	var clock=[.15]
	var at=func(step:float=STEP)->float:clock[0]+=step;return clock[0]
	# — Loot —
	UiKit.label(panel,"Добыча",left,Vector2(column,26),UiKit.SECTION_SIZE,UiKit.MUTED)
	var gathered=ledger(panel,left+Vector2(0,36),column,"Собрано за вылазку","+%d" % earned,UiKit.INK,at.call())
	count_up(gathered,earned,"+%d",clock[0])
	var bar_y=left.y+76
	var track=ColorRect.new();panel.add_child(track);track.position=Vector2(left.x,bar_y);track.size=Vector2(column,10);track.color=Color(1,1,1,.08)
	var fill=ColorRect.new();track.add_child(fill);fill.size=Vector2(0,10);fill.color=UiKit.ORANGE;fill.name="AlloyFill"
	var grow=panel.create_tween();grow.tween_interval(clock[0]);grow.tween_property(fill,"size:x",column,.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var y=bar_y+22
	if lost>0:
		var loss_at=at.call(.75)
		var minus=ledger(panel,Vector2(left.x,y),column,"Отнято при выбывании","−%d" % lost,Color("ff6b57"),loss_at)
		minus.name="LossValue"
		var lost_part=ColorRect.new();track.add_child(lost_part);lost_part.color=Color("ff6b57");lost_part.size=Vector2(0,10);lost_part.position.x=column;lost_part.name="LossPart"
		var share=float(lost)/maxf(1.0,float(earned))
		var shrink=panel.create_tween();shrink.tween_interval(loss_at)
		shrink.tween_callback(func():Game.sound("debris",hud);drop_coins(hud,lost))
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
	if docs>0:
		ledger(panel,Vector2(left.x,y),column,"Документы","+%d" % docs,UiKit.INK,at.call());y+=34
	# Blueprints: saved bright, lost greyed with a red mark.
	var saved=arena.pending_recipes if won else arena.get_meta("saved_recipes",[])
	var gone=arena.get_meta("lost_recipes",[])
	UiKit.label(panel,"Чертежи" if not (saved.is_empty() and gone.is_empty()) else "Чертежей нет",Vector2(left.x,y+6),Vector2(column,24),15,UiKit.MUTED)
	var x=left.x
	for entry in saved.map(func(r):return [r,true])+gone.map(func(r):return [r,false]):
		if x+78>left.x+column:break
		var cell=UiKit.panel(panel,Vector2(x,y+34),Vector2(72,72),Color("2f3b33") if entry[1] else Color("262b27"));cell.modulate.a=0
		cell.tooltip_text=Texts.render(Game.recipe_name(entry[0])+("" if entry[1] else " · потерян"))
		var art=UiKit.icon(cell,str(entry[0].get("id","")),Vector2(10,8),Vector2(52,52));UiKit.locked_preview(art,not entry[1])
		if not entry[1]:UiKit.label(cell,"✕",Vector2(52,0),Vector2(20,20),14,Color("ff6b57"))
		reveal(cell,at.call(.12),"ui_confirm" if entry[1] else "debris",hud)
		x+=80
	# — Summary —
	clock[0]=.15
	UiKit.label(panel,"Сводка",right,Vector2(column,26),UiKit.SECTION_SIZE,UiKit.MUTED)
	var fields=mini(arena.room_index+(1 if won else 0),Campaign.SIZES.size())
	var best=int(Game.progression.counters.get("best_kills",0));var record=arena.kills>best and arena.kills>0
	if record:Game.progression.event("best_kills",arena.kills,true)
	ledger(panel,right+Vector2(0,36),column,"Поля","%d / %d" % [fields,Campaign.SIZES.size()],UiKit.INK,at.call())
	ledger(panel,right+Vector2(0,70),column,"Время","%d:%02d" % [int(arena.elapsed/60.0),int(arena.elapsed)%60],UiKit.INK,at.call())
	var kills=ledger(panel,right+Vector2(0,104),column,"Враги",str(arena.kills),UiKit.INK,at.call())
	if record:UiKit.label(kills,"Рекорд",Vector2(column-190,-12),Vector2(100,16),12,UiKit.ORANGE)
	if Campaign.daily:
		var score=DailyRun.score(Campaign.cycle,arena.room_index,arena.kills);var day_best=int(DailyRun.best(Campaign.daily_key).get("score",-1))
		ledger(panel,right+Vector2(0,138),column,"Счёт дня"+(" · рекорд" if score>day_best else ""),str(score),UiKit.ORANGE if score>day_best else UiKit.INK,at.call())
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
static func drop_coins(hud,lost:int):
	var layer:Control=hud.root;var screen=layer.get_viewport_rect().size
	var origin=Vector2(screen.x*.5-60,34)
	var minus=UiKit.label(layer,"−%d" % lost,origin+Vector2(-10,26),Vector2(120,30),22,Color("ff6b57"));minus.name="AlloyLoss";minus.z_index=120
	var fade=minus.create_tween();fade.tween_property(minus,"position:y",minus.position.y+18,.9);fade.parallel().tween_property(minus,"modulate:a",0.0,.9).set_delay(.6);fade.tween_callback(minus.queue_free)
	for i in range(clampi(lost/8+3,3,14)):
		var coin=TextureRect.new();layer.add_child(coin);coin.texture=UiKit.icon_texture("alloy");coin.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;coin.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.size=Vector2(26,26);coin.pivot_offset=coin.size*.5;coin.position=origin+Vector2(i*7%40,0);coin.z_index=119;coin.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var drift=(float(i%5)-2.0)*45.0
		var fall=coin.create_tween().set_parallel(true)
		fall.tween_property(coin,"position",coin.position+Vector2(drift,screen.y+60),1.1+i*.04).set_delay(i*.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fall.tween_property(coin,"rotation",(1.0 if i%2==0 else -1.0)*TAU*1.5,1.1+i*.04).set_delay(i*.05)
		fall.chain().tween_callback(coin.queue_free)
