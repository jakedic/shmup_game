extends Control

## Shown whenever the player collects a power-up from a power bubble (see
## Stats.powerup_collected, emitted from Stats.add_powerup() and picked up
## by BaseLevel._on_powerup_collected()). The level pauses the tree while
## this is visible; this node itself uses process_mode = PROCESS_MODE_ALWAYS
## (set on the scene node, same as PauseMenu) so it keeps working while
## paused.
##
## The popup always stays up for at least MIN_DISPLAY_TIME seconds - only
## after that does it start listening for a key/button press to dismiss
## itself, at which point it emits continue_pressed for BaseLevel to unpause.

signal continue_pressed

const MIN_DISPLAY_TIME := 1.0

# Default accent (border/header/name color) used when no color is passed to
# show_powerup() - matches PlayerPowerUps.DEFAULT_ACCENT_COLOR.
const DEFAULT_ACCENT_COLOR := Color(0.54901961, 0.85098039, 1.0)

@onready var box: PanelContainer = $CenterContainer/Box
@onready var title_bar: PanelContainer = $CenterContainer/Box/Margin/VBoxContainer/TitleBar
@onready var title_label: Label = $CenterContainer/Box/Margin/VBoxContainer/TitleBar/TitleLabel
@onready var name_label: Label = $CenterContainer/Box/Margin/VBoxContainer/NameLabel
@onready var description_label: Label = $CenterContainer/Box/Margin/VBoxContainer/DescriptionLabel
@onready var continue_hint: Label = $CenterContainer/Box/Margin/VBoxContainer/ContinueHint
@onready var min_display_timer: Timer = $MinDisplayTimer

# Per-instance copies of the shared scene styleboxes, so recoloring one
# popup can never bleed into another node using the same on-disk resource.
var box_style: StyleBoxFlat
var title_bar_style: StyleBoxFlat

var can_dismiss: bool = false
var blink_tween: Tween


func _ready() -> void:
	hide()
	continue_hint.hide()
	min_display_timer.one_shot = true
	min_display_timer.wait_time = MIN_DISPLAY_TIME
	min_display_timer.timeout.connect(_on_min_display_timer_timeout)

	box_style = box.get_theme_stylebox("panel").duplicate()
	title_bar_style = title_bar.get_theme_stylebox("panel").duplicate()
	box.add_theme_stylebox_override("panel", box_style)
	title_bar.add_theme_stylebox_override("panel", title_bar_style)


func show_powerup(powerup: Dictionary, accent_color: Color = DEFAULT_ACCENT_COLOR) -> void:
	"""Display the given power-up's name/description (see
	player/player_powerups.gd for the dict shape), tint the popup with
	accent_color (e.g. yellow for a yellow-enemy power-up - see
	PlayerPowerUps.get_accent_color_for_powerup_id()), and start the
	minimum-display countdown before the player can dismiss it."""
	name_label.text = powerup.get("name", "Power-Up!").to_upper()
	description_label.text = powerup.get("description", "")

	_apply_accent_color(accent_color)

	can_dismiss = false
	continue_hint.hide()
	_stop_blink()
	show()
	_play_pop_in()
	min_display_timer.start()


func _apply_accent_color(accent_color: Color) -> void:
	box_style.border_color = accent_color
	title_bar_style.bg_color = accent_color
	title_label.add_theme_color_override("font_color", _readable_text_color_on(accent_color))
	name_label.add_theme_color_override("font_color", accent_color.lightened(0.25))


func _readable_text_color_on(bg: Color) -> Color:
	"""Near-black or near-white text, whichever reads better on top of bg -
	keeps the title bar legible no matter what accent color a future enemy
	type introduces."""
	var luminance := 0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b
	if luminance > 0.6:
		return Color(0.08, 0.08, 0.11)
	return Color(0.95, 0.95, 0.97)


func _play_pop_in() -> void:
	"""Small retro "pop" scale-in for the box when the popup appears."""
	box.pivot_offset = box.size / 2.0
	box.scale = Vector2(0.7, 0.7)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(box, "scale", Vector2.ONE, 0.22)


func _on_min_display_timer_timeout() -> void:
	can_dismiss = true
	continue_hint.show()
	_start_blink()


func _start_blink() -> void:
	"""Classic blinking "press any button" prompt."""
	_stop_blink()
	blink_tween = create_tween()
	blink_tween.set_loops()
	blink_tween.set_trans(Tween.TRANS_SINE)
	blink_tween.tween_property(continue_hint, "modulate:a", 0.15, 0.5)
	blink_tween.tween_property(continue_hint, "modulate:a", 1.0, 0.5)


func _stop_blink() -> void:
	if blink_tween and blink_tween.is_valid():
		blink_tween.kill()
	continue_hint.modulate.a = 1.0


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not can_dismiss:
		return

	# Deliberately generic - "a button" per the design, not one specific
	# mapped action, so any key press or gamepad button press dismisses it.
	if (event is InputEventKey or event is InputEventJoypadButton) and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		continue_pressed.emit()
