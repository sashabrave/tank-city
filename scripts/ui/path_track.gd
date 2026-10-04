extends RefCounted
## A vertical path (T-124, T-191; class path since 4 Oct 2026): a thin track through numbered circles — done green,
## the next goal with an orange ring, later hollow — and one even card per step in a single column on the right of
## the track. «Развитие заставы» (StationScreen.milestones) and the class path («Все уровни») draw with it.
## An item: {id, title, caption, status: done|goal|later, icon or texture, number, height (default ROW),
##   header (a chapter title drawn above the row), detail (a muted wrapped line under the title), picture (side of
##   the picture), picture_box (width of the picture column),
##   caption_color, pill: {text, icon, tone} (a price or reward on the right), action: {text, icon, name, enabled,
##   primary, pulse, tooltip, callback} (a button on the right), progress (0..1 for the goal ring)}.
## opts: selected (id with the orange frame), on_select (Callable(id); rows are plain cards without it),
##   just (id whose node pops), node (circle size), name (holder name).
const ROW:=104.0
const GAP:=14.0
const HEADER:=36.0
const X:=8.0
static func build(parent:Control,items:Array,width:float,opts:Dictionary={})->Control:
	var node_side=float(opts.get("node",46.0))
	var holder=Control.new();holder.name=str(opts.get("name","Path"));parent.add_child(holder)
	# Row geometry first: every row has its own height, a chapter header adds room above it.
	var tops=[];var y=0.0
	for item in items:
		if item.has("header"):y+=HEADER
		tops.append(y);y+=float(item.get("height",ROW))
	holder.custom_minimum_size=Vector2(width,y+8);holder.size=holder.custom_minimum_size
	var axis=X+node_side*.5
	var mid=func(i:int)->float:return tops[i]+(float(items[i].get("height",ROW))-GAP)*.5
	if items.size()>1:
		var rail=Panel.new();holder.add_child(rail);rail.name="Rail";rail.mouse_filter=Control.MOUSE_FILTER_IGNORE;rail.position=Vector2(axis-3,mid.call(0));rail.size=Vector2(6,mid.call(items.size()-1)-mid.call(0))
		rail.add_theme_stylebox_override("panel",bar_style(Color(1,1,1,.08),3))
		var last=-1
		for i in range(items.size()):
			if str(items[i].get("status",""))=="done":last=i
		if last>0:
			var fill=Panel.new();holder.add_child(fill);fill.name="RailFill";fill.mouse_filter=Control.MOUSE_FILTER_IGNORE;fill.position=Vector2(axis-3,mid.call(0));fill.size=Vector2(6,mid.call(last)-mid.call(0))
			fill.add_theme_stylebox_override("panel",bar_style(Color("8fe895"),3))
	var left=X+node_side+20;var selected=str(opts.get("selected",""));var on_select=opts.get("on_select")
	for i in range(items.size()):
		var item=items[i];var status=str(item.get("status","later"));var id=str(item.id)
		var card_h=float(item.get("height",ROW))-GAP;var top=float(tops[i])
		if item.has("header"):
			var head=UiKit.label(holder,str(item.header),Vector2(left+4,top-HEADER+6),Vector2(width-left-18,24),15,UiKit.MUTED);head.name="Header_"+id
		var row:Control
		if on_select is Callable:
			var b=Button.new();b.focus_mode=Control.FOCUS_NONE;row=b
			b.pressed.connect(func():on_select.call(id))
		else:row=Panel.new();row.mouse_filter=Control.MOUSE_FILTER_PASS
		holder.add_child(row);row.name="Item_"+id;row.position=Vector2(left,top);row.size=Vector2(width-left-14,card_h)
		var chosen=id==selected
		var bg=Color(UiKit.ORANGE,.16) if status=="goal" else Color(1,1,1,.05) if status=="done" else Color(0,0,0,.14)
		var style=UiKit.style(bg,14,UiKit.ORANGE if chosen else Color(1,1,1,.07));style.set_border_width_all(2 if chosen else 1)
		if row is Button:
			for state in ["normal","hover","pressed","focus"]:row.add_theme_stylebox_override(state,style)
		else:row.add_theme_stylebox_override("panel",style)
		var circle=float(item.get("node",node_side))
		var node=preload("res://scripts/ui/track_node.gd").new();node.status=status;node.milestone=true;node.number=str(item.get("number",i+1));node.size=Vector2(circle,circle);node.position=Vector2(axis-circle*.5,mid.call(i)-circle*.5);node.name="Node_"+id
		if status=="goal":node.progress=float(item.get("progress",0.0))
		holder.add_child(node)
		if id==str(opts.get("just","")):node.celebrate.call_deferred()
		# Picture on the left of the card (a drawn step, an ability, a perk); compact rows may go without.
		var text_x=16.0
		var texture=item.get("texture",UiKit.icon_texture(str(item.icon)) if str(item.get("icon",""))!="" else null)
		if texture:
			var pic=minf(card_h-28,float(item.get("picture",card_h-28)))
			# picture_box: a fixed picture column, so the text of short and tall rows starts at one line.
			var box=maxf(pic,float(item.get("picture_box",pic)))
			var art=TextureRect.new();row.add_child(art);art.name="Art";art.mouse_filter=Control.MOUSE_FILTER_IGNORE;art.position=Vector2(14+(box-pic)*.5,(card_h-pic)*.5);art.size=Vector2(pic,pic)
			art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;art.texture=texture
			if status=="later":
				var grey=ShaderMaterial.new();grey.shader=preload("res://scripts/ui/station_screen.gd").GREY;art.material=grey;art.self_modulate=Color(.8,.8,.8,.55);art.set_meta("kit_layer",true)
			text_x=14+box+16
		# Right side: an action button or a pill (price / reward with its icon).
		var right=14.0
		var action:Dictionary=item.get("action",{});var pill:Dictionary=item.get("pill",{})
		if not action.is_empty():
			var aw=float(action.get("width",92.0));right=aw+26
			var callback:Callable=action.get("callback",func():pass)
			var button=UiKit.button(row,str(action.text),Vector2(row.size.x-aw-12,card_h*.5-20),Vector2(aw,40),callback,bool(action.get("primary",true)));button.name=str(action.get("name","Action_"+id))
			button.disabled=not bool(action.get("enabled",true));UiKit.muted_locked_button(button)
			if str(action.get("icon",""))!="":button.icon=UiKit.icon_texture(str(action.icon));button.expand_icon=true;button.add_theme_constant_override("icon_max_width",20)
			if str(action.get("tooltip",""))!="":button.tooltip_text=Texts.render(str(action.tooltip))
			if action.get("pulse",false) and UiKit.motion_enabled():
				button.pivot_offset=button.size*.5;var t=button.create_tween().set_loops();t.tween_property(button,"scale",Vector2.ONE*1.06,.5);t.tween_property(button,"scale",Vector2.ONE,.5)
		elif not pill.is_empty():
			var pw=float(pill.get("width",92.0));right=pw+26
			var tone=str(pill.get("tone",status))
			var box=UiKit.panel(row,Vector2(row.size.x-pw-12,card_h*.5-16),Vector2(pw,32),Color(UiKit.ORANGE,.24) if tone=="goal" else Color(1,1,1,.06));box.name="Pill"
			var amount=UiKit.label(box,str(pill.text),Vector2(6,4),Vector2(pw-36,24),15,Color("8fe895") if tone=="done" else UiKit.INK if tone=="goal" else UiKit.MUTED);amount.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
			if str(pill.get("icon",""))!="":UiKit.icon(box,str(pill.icon),Vector2(pw-26,6),Vector2(20,20)).modulate=Color(1,1,1,1.0 if tone!="later" else .5)
		var text_w=row.size.x-text_x-right
		var title_size=int(item.get("title_size",18))
		var ink=UiKit.INK if status!="later" else Color(UiKit.INK,.62)
		var caption_color=item.get("caption_color",Color("8fe895") if status=="done" else UiKit.ORANGE if status=="goal" else Color(UiKit.MUTED,.85))
		if item.has("detail"):
			var title=UiKit.label(row,str(item.title),Vector2(text_x,10),Vector2(text_w,24),title_size,ink);title.clip_text=true;title.name="Title"
			var detail=UiKit.label(row,str(item.detail),Vector2(text_x,36),Vector2(text_w,card_h-36-28),13,UiKit.MUTED);detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail.clip_text=true;detail.vertical_alignment=VERTICAL_ALIGNMENT_TOP;detail.name="Detail"
			UiKit.label(row,str(item.get("caption","")),Vector2(text_x,card_h-26),Vector2(text_w,20),13,caption_color).clip_text=true
		else:
			var block=title_size+8+20.0;var ty=(card_h-block)*.5
			var title=UiKit.label(row,str(item.title),Vector2(text_x,ty),Vector2(text_w,title_size+8),title_size,ink);title.clip_text=true;title.name="Title"
			UiKit.label(row,str(item.get("caption","")),Vector2(text_x,ty+title_size+8),Vector2(text_w,20),13,caption_color).clip_text=true
	return holder
## Exact-colour rounded bar (UiKit.style maps light colours to theme surfaces).
static func bar_style(color:Color,radius:int)->StyleBoxFlat:
	var b=StyleBoxFlat.new();b.bg_color=color;b.set_corner_radius_all(radius);return b
