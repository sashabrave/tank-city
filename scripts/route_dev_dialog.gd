extends RefCounted
## Dev map (Game.dev_map): a small jump dialog for nodes without a battle preview — mechanic, HQ depot, captured
## post, challenges and the stops between stages (instructor, merchant). «Перейти» enters the room the same way
## a normal entry does (main.test_jump / test_jump_service); «с прокачкой» replays the earlier rewards first.
static func build(route,title:String,subtitle:String)->Control:
	var modal=Control.new();modal.name="DevJumpDialog";modal.add_to_group("selection_scope");route.root.add_child(modal);modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim=ColorRect.new();modal.add_child(dim);dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);dim.color=Color(0,0,0,.48)
	var screen=route.get_viewport().get_visible_rect().size;var size=Vector2(minf(560,screen.x-32),236)
	var panel=UiKit.glass(modal,((screen-size)*.5).round(),size)
	UiKit.accent(UiKit.label(panel,title,Vector2(24,18),Vector2(size.x-48,34),24))
	UiKit.label(panel,subtitle,Vector2(24,58),Vector2(size.x-48,24),15,UiKit.MUTED)
	var half=(size.x-24*2-12)*.5
	var jump=UiKit.button(panel,"Перейти",Vector2(24,100),Vector2(half,44),func():route.dev_entry(false));jump.name="DevJump"
	var full=UiKit.button(panel,"Перейти с прокачкой",Vector2(36+half,100),Vector2(half,44),func():route.dev_entry(true),true);full.name="DevJumpProgress"
	for b in [jump,full]:b.add_theme_font_size_override("font_size",15)
	UiKit.button(panel,"Отмена",Vector2(24,160),Vector2(size.x-48,44),route.cancel_entry).name="DevCancel"
	return modal
