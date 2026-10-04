extends Node
var selected:Button
var transition_locked=false
var release_required=false
var input_consumed_frame=-1
func _ready():process_mode=Node.PROCESS_MODE_ALWAYS
func lock_confirmation():
	transition_locked=true;release_required=true;Game.reset_input()
func scope()->Node:
	var scopes=get_tree().get_nodes_in_group("selection_scope").filter(func(n):return is_instance_valid(n) and not n.is_queued_for_deletion() and n.is_visible_in_tree())
	return scopes.back() if not scopes.is_empty() else null
func available()->Array:
	var owner=scope()
	var nodes=owner.find_children("*","Button",true,false) if owner else get_tree().get_nodes_in_group("reward_choice")
	return nodes.filter(func(b):return is_instance_valid(b) and not b.is_queued_for_deletion() and b.is_visible_in_tree() and not b.disabled)
## First pick in a new scope: the button the dialog focused itself, then one marked "default_choice"
## (e.g. «Продолжить» in the hub greeting, T-076), then the first one.
func initial(choices:Array,focused)->Button:
	if focused in choices:return focused
	for b in choices:
		if b.has_meta("default_choice"):return b
	return choices[0]
func choose(button:Button):
	selected=button;button.focus_mode=Control.FOCUS_ALL;button.grab_focus()
func _input(event):
	if get_tree().get_nodes_in_group("guide_confirmation").any(func(d):return d.visible):return
	if get_viewport().gui_get_focus_owner() is LineEdit or get_viewport().gui_get_focus_owner() is TextEdit:return
	if Settings.waiting!="":return
	var active_scope=scope()
	if active_scope!=null and active_scope.get("waiting_key")!=null and active_scope.get("waiting_key")!="":return
	var choices=available()
	# Space is exclusively fire, including when a GUI button owns focus.
	if event.is_action("fire") and (scope()!=null or not choices.is_empty() or transition_locked):
		get_viewport().set_input_as_handled();return
	if event is InputEventKey and event.physical_keycode==KEY_SPACE and not event.is_action("fire"):
		get_viewport().set_input_as_handled();return
	if event.is_action("ui_accept") and not event.is_action("interact"):
		if scope()!=null or not choices.is_empty():get_viewport().set_input_as_handled()
		return
	if event.is_action("interact"):
		if transition_locked or release_required or event.is_echo():
			if not event.is_pressed():release_required=false
			get_viewport().set_input_as_handled();return
	if choices.is_empty() or not event.is_pressed() or event.is_echo():return
	if not is_instance_valid(selected) or selected not in choices:choose(initial(choices,get_viewport().gui_get_focus_owner()))
	var direction=Vector2.ZERO
	if event.is_action("east"):direction=Vector2.RIGHT
	elif event.is_action("west"):direction=Vector2.LEFT
	elif event.is_action("north"):direction=Vector2.UP
	elif event.is_action("south"):direction=Vector2.DOWN
	if direction!=Vector2.ZERO:
		var origin=selected.get_global_rect().get_center();var best:Button;var score=INF
		for candidate in choices:
			var offset=candidate.get_global_rect().get_center()-origin
			if offset.dot(direction)<=2:continue
			var cost=offset.length()+absf(offset.cross(direction))*2
			if cost<score:score=cost;best=candidate
		if best:choose(best)
		get_viewport().set_input_as_handled()
	elif event.is_action("interact"):
		input_consumed_frame=Engine.get_physics_frames()
		get_viewport().set_input_as_handled();release_required=true
		selected.pressed.emit();Game.reset_input()
func _process(_delta):
	if get_viewport().gui_get_focus_owner() is LineEdit or get_viewport().gui_get_focus_owner() is TextEdit:return
	var choices=available()
	# The lock only guards a choice screen that is opening; with nothing on screen to confirm it must not outlive
	# it (T-257: an upgrade screen that never opened left E dead in every room after the field).
	if transition_locked and choices.is_empty() and scope()==null:transition_locked=false
	if not transition_locked and not Input.is_action_pressed("interact"):release_required=false
	if choices.is_empty():selected=null;return
	var focused=get_viewport().gui_get_focus_owner()
	if not is_instance_valid(selected) or selected not in choices:choose(initial(choices,focused))
	if focused in choices:selected=focused
	for button in choices:
		button.focus_mode=Control.FOCUS_ALL
		button.add_theme_color_override("font_focus_color",button.get_theme_color("font_color"))
		if not button.has_meta("navigation_bound"):
			button.set_meta("navigation_bound",true)
			button.mouse_entered.connect(func():
				if not button.disabled:choose(button))
			var focus=UiKit.style(Color.TRANSPARENT,13,UiKit.ORANGE);focus.set_border_width_all(3)
			button.add_theme_stylebox_override("focus",focus)
		var card=button.get_parent()
		if card.has_meta("idle_border"):
			card.add_theme_stylebox_override("panel",card.get_meta("selected_border") if button==selected else card.get_meta("idle_border"))
