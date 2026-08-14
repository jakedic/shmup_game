extends Control

## Shown once per level - after the last wave is cleared, when the run is
## being driven by the overworld (see GameProgress) - offering the player a
## choice of up to 3 power-ups they earned THIS level to keep for the rest
## of the run (see Stats.choose_run_powerup() / Stats.run_modifiers).
##
## Selectable with Left/Right (cycle the highlighted card) + the "start"
## action (Enter - confirm), same input scheme as the overworld map, or by
## clicking/tapping a card directly. The highlighted card is made obvious a
## few different ways at once (thicker glowing border, tinted background, a
## slight scale-up, arrows around its name) while the rest are dimmed, so
## it's never ambiguous which one Enter would pick (see
## _update_selection_highlight()).
##
## This node uses process_mode = PROCESS_MODE_ALWAYS (set on the scene node,
## same as PauseMenu/PowerupPopup) so it keeps working while the level pauses
## the tree behind it (see BaseLevel._offer_run_powerup_choice()).

signal powerup_chosen(powerup: Dictionary)

@onready var box: Control = $CenterContainer/Box
@onready var cards: Array = [
	$CenterContainer/Box/Margin/VBoxContainer/CardsRow/Card0,
	$CenterContainer/Box/Margin/VBoxContainer/CardsRow/Card1,
	$CenterContainer/Box/Margin/VBoxContainer/CardsRow/Card2,
]

# Per-card duplicated "panel" styleboxes, so each card can be tinted with
# its own power-up's accent color (and highlighted when keyboard-selected)
# without affecting the others or the on-disk resource (same pattern as
# PowerupPopup's box_style/title_bar_style).
var _card_panel_styles: Array = []

# Base accent color per currently-shown card, index-matched to `cards` (only
# entries < _offered.size() are meaningful).
var _card_accents: Array = []

# Plain (un-decorated) display name per currently-shown card, index-matched
# to `cards` - _update_selection_highlight() wraps the selected one in
# arrows without permanently mutating this.
var _card_names: Array = []

# The unselected-card background color, captured once from the on-disk
# stylebox at _ready() (before any per-card tinting) so
# _update_selection_highlight() can restore it on cards that lose selection.
var _default_bg_color: Color = Color.BLACK

# The power-up dicts currently on display, index-matched to `cards`.
var _offered: Array = []

# Which card is currently highlighted via keyboard Left/Right.
var cursor_index: int = 0


func _ready() -> void:
	hide()
	for card in cards:
		var panel_style: StyleBoxFlat = card.get_theme_stylebox("panel").duplicate()
		card.add_theme_stylebox_override("panel", panel_style)
		_card_panel_styles.append(panel_style)
	if not _card_panel_styles.is_empty():
		_default_bg_color = _card_panel_styles[0].bg_color


func show_choices(powerups: Array) -> void:
	"""powerups: up to 3 power-up dicts (see player_powerups.gd for the
	shape) already chosen by the caller - this just displays them. Any card
	slot beyond powerups.size() is hidden."""
	_offered = powerups
	_card_accents.clear()
	_card_names.clear()
	cursor_index = 0

	for i in range(cards.size()):
		var card: PanelContainer = cards[i]
		if i < powerups.size():
			var powerup: Dictionary = powerups[i]
			var accent: Color = PlayerPowerUps.get_accent_color_for_powerup_id(powerup.get("id", ""))
			_card_accents.append(accent)
			_card_names.append(powerup.get("name", "Power-Up").to_upper())
			var description_label: Label = card.get_node("Margin/VBoxContainer/DescriptionLabel")
			description_label.text = powerup.get("description", "")
			card.show()
		else:
			_card_accents.append(Color.WHITE)
			_card_names.append("")
			card.hide()

	_update_selection_highlight()
	show()
	_play_pop_in()


func _update_selection_highlight() -> void:
	"""Keyboard/mouse-driven equivalent of a hover state. Stacks several cues
	at once so the selected card is never ambiguous: a thicker glowing
	border, a tinted background, the whole card at full brightness while the
	others dim, a small scale-up "pop", and arrows bracketing its name."""
	for i in range(cards.size()):
		if i >= _offered.size():
			continue
		var card: PanelContainer = cards[i]
		var style: StyleBoxFlat = _card_panel_styles[i]
		var accent: Color = _card_accents[i]
		var name_label: Label = card.get_node("Margin/VBoxContainer/NameLabel")
		var is_selected := i == cursor_index

		if is_selected:
			style.border_color = accent.lightened(0.5)
			style.bg_color = accent.darkened(0.6)
			style.border_width_left = 4
			style.border_width_top = 4
			style.border_width_right = 4
			style.border_width_bottom = 4
			card.modulate = Color(1, 1, 1, 1)
			name_label.text = "> %s <" % _card_names[i]
			name_label.add_theme_color_override("font_color", accent.lightened(0.5))
		else:
			style.border_color = accent
			style.bg_color = _default_bg_color
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
			card.modulate = Color(0.55, 0.55, 0.6, 1)
			name_label.text = _card_names[i]
			name_label.add_theme_color_override("font_color", accent.lightened(0.25))

		card.pivot_offset = card.size / 2.0
		var target_scale := Vector2(1.08, 1.08) if is_selected else Vector2.ONE
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "scale", target_scale, 0.12)


func _play_pop_in() -> void:
	box.pivot_offset = box.size / 2.0
	box.scale = Vector2(0.7, 0.7)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(box, "scale", Vector2.ONE, 0.22)


func _input(event: InputEvent) -> void:
	if not visible or _offered.is_empty():
		return

	if _offered.size() > 1:
		if event.is_action_pressed("right"):
			cursor_index = (cursor_index + 1) % _offered.size()
			_update_selection_highlight()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("left"):
			cursor_index = (cursor_index - 1 + _offered.size()) % _offered.size()
			_update_selection_highlight()
			get_viewport().set_input_as_handled()

	if event.is_action_pressed("start"):
		get_viewport().set_input_as_handled()
		_choose(cursor_index)


func _on_card_0_gui_input(event: InputEvent) -> void:
	_handle_card_click(event, 0)


func _on_card_1_gui_input(event: InputEvent) -> void:
	_handle_card_click(event, 1)


func _on_card_2_gui_input(event: InputEvent) -> void:
	_handle_card_click(event, 2)


func _handle_card_click(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		cursor_index = index
		_choose(index)


func _choose(index: int) -> void:
	if index >= _offered.size():
		return
	var powerup: Dictionary = _offered[index]
	hide()
	powerup_chosen.emit(powerup)
