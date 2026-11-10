extends Node
const MenuKeys := preload("res://menu_keys.gd")   # shared menu keys: WASD/arrows + J/Space/Enter

## Keyboard controls for the pause menu. BaseLevel adds one of these under
## its PauseMenu in _ready() (see BaseLevel._ready()) - it has to live there
## rather than in BaseLevel itself because the level stops getting input
## while the game is paused; the pause menu (and this) keep running.
##
##   W/S or Up/Down     - move between the buttons (Continue, Quit...)
##   J / Space / Enter  - press the highlighted button
##   A or Left          - jump over to the power-up squares on the left side
##                        panel (see powerup_hud.gd). There, WASD/arrows move
##                        between squares and show each one's info box;
##                        Right off the right-hand end, or J/Space/Enter, goes
##                        back to the buttons.
##   P (pause)          - resume

var _browsing := false
var _opened_msec := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var menu: Control = get_parent()
	menu.visibility_changed.connect(_on_menu_visibility_changed)


func _buttons() -> Array:
	var vbox := get_parent().get_node_or_null("CenterContainer/VBoxContainer")
	if vbox == null:
		return []
	var out: Array = []
	for child in vbox.get_children():
		if child is BaseButton:
			out.append(child)
	return out


func _on_menu_visibility_changed() -> void:
	if get_parent().visible:
		_opened_msec = Time.get_ticks_msec()
		_stop_browsing()
		# Deferred: the buttons aren't focusable until the menu is fully shown.
		MenuKeys.focus_first.call_deferred(_buttons())
	else:
		_stop_browsing()


func _stop_browsing() -> void:
	if _browsing:
		GameShell.powerup_browse_end()
	_browsing = false


func _input(event: InputEvent) -> void:
	var menu: Control = get_parent()
	if not menu.visible or not (event is InputEventKey or event is InputEventJoypadButton):
		return

	if event.is_action_pressed("pause"):
		# Same press that opened the menu? Ignore it.
		if not MenuKeys.too_soon(_opened_msec, 150):
			var level := owner if owner else menu.owner
			if level and level.has_method("resume_game"):
				level.resume_game()
		get_viewport().set_input_as_handled()
		return

	if _browsing:
		var dir := Vector2i.ZERO
		if event.is_action_pressed("left"):
			dir = Vector2i(-1, 0)
		elif event.is_action_pressed("right"):
			dir = Vector2i(1, 0)
		elif event.is_action_pressed("up"):
			dir = Vector2i(0, -1)
		elif event.is_action_pressed("down"):
			dir = Vector2i(0, 1)
		if dir != Vector2i.ZERO:
			if not GameShell.powerup_browse_move(dir):
				_back_to_buttons()
			get_viewport().set_input_as_handled()
		elif MenuKeys.is_confirm(event):
			_back_to_buttons()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("left"):
		if GameShell.powerup_browse_begin():
			_browsing = true
			get_viewport().gui_release_focus()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("right"):
		get_viewport().set_input_as_handled()   # nothing to the right
		return
	if MenuKeys.is_confirm(event) and MenuKeys.too_soon(_opened_msec, 150):
		get_viewport().set_input_as_handled()
		return
	MenuKeys.handle_buttons(event, _buttons())


func _back_to_buttons() -> void:
	_stop_browsing()
	MenuKeys.focus_first(_buttons())
