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

# Level display for leveled power-ups (see PlayerPowerUps "POWER-UP LEVELS"),
# built in code so no level scene needs editing: a "LEVEL 2 / 3" line + the
# power-up's square (level-colored border) under the name, and the level's summary ("Speed x1.75") under the
# description. Hidden for power-ups without levels.
const TITLE_NEW := "★ POWER-UP! ★"
const TITLE_LEVEL_UP := "★ LEVEL UP! ★"
const TITLE_MAX := "★ MAX LEVEL! ★"
var level_label: Label
var pip_bar: Control
var summary_label: Label
var _pip_level := 0
var _pip_max := 0
var _accent := DEFAULT_ACCENT_COLOR


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
	_build_level_widgets()


func _build_level_widgets() -> void:
	var vbox := name_label.get_parent()

	level_label = Label.new()
	level_label.name = "LevelLabel"
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(level_label)
	vbox.move_child(level_label, name_label.get_index() + 1)

	pip_bar = Control.new()
	pip_bar.name = "LevelPips"
	pip_bar.custom_minimum_size = Vector2(0, 14)
	pip_bar.draw.connect(_draw_pips)
	vbox.add_child(pip_bar)
	vbox.move_child(pip_bar, level_label.get_index() + 1)

	summary_label = Label.new()
	summary_label.name = "LevelSummary"
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(summary_label)
	vbox.move_child(summary_label, description_label.get_index() + 1)


func _draw_pips() -> void:
	"""The power-up's square, same as in the side panel: filled with its type
	color, bordered with its level color (blue 1 / red 2 / gold 3 - see
	PlayerPowerUps.LEVEL_COLORS)."""
	if _pip_max <= 1:
		return
	var sq := 14.0
	var r := Rect2((pip_bar.size.x - sq) / 2.0, 0, sq, sq)
	pip_bar.draw_rect(r, _accent, true)
	pip_bar.draw_rect(r.grow(-1.0), PlayerPowerUps.level_color(_pip_level), false, 2.0)


func show_powerup(powerup: Dictionary, accent_color: Color = DEFAULT_ACCENT_COLOR) -> void:
	"""Display the given power-up's name/description (see
	player/player_powerups.gd for the dict shape), tint the popup with
	accent_color (e.g. yellow for a yellow-enemy power-up - see
	PlayerPowerUps.get_accent_color_for_powerup_id()), and start the
	minimum-display countdown before the player can dismiss it."""
	name_label.text = powerup.get("name", "Power-Up!").to_upper()
	description_label.text = powerup.get("description", "")

	_apply_accent_color(accent_color)
	_show_level(powerup, accent_color)

	can_dismiss = false
	continue_hint.hide()
	_stop_blink()
	show()
	_play_pop_in()
	min_display_timer.start()


func _show_level(powerup: Dictionary, accent_color: Color) -> void:
	"""powerup may carry display_level / max_level / level_summary (see
	PlayerPowerUps.with_level_info()). display_level 0 = no level shown."""
	var lvl: int = powerup.get("display_level", 0)
	var max_lvl: int = powerup.get("max_level", 1)
	var has_levels := lvl > 0 and max_lvl > 1
	level_label.visible = has_levels
	pip_bar.visible = has_levels
	var summary: String = powerup.get("level_summary", "")
	summary_label.visible = summary != ""
	summary_label.text = summary
	summary_label.add_theme_color_override("font_color", accent_color.lightened(0.35))

	# Title bar keeps the power-up's TYPE color (set by _apply_accent_color());
	# the rest of the box border shows its LEVEL color (blue/red/gold).
	box_style.border_color = PlayerPowerUps.level_color(lvl) if has_levels else accent_color
	if not has_levels:
		title_label.text = TITLE_NEW
		return
	if lvl >= max_lvl:
		title_label.text = TITLE_MAX
		level_label.text = "LEVEL %d / %d - MAX" % [lvl, max_lvl]
	elif lvl > 1:
		title_label.text = TITLE_LEVEL_UP
		level_label.text = "LEVEL %d / %d" % [lvl, max_lvl]
	else:
		title_label.text = TITLE_NEW
		level_label.text = "LEVEL %d / %d" % [lvl, max_lvl]
	level_label.add_theme_color_override("font_color", PlayerPowerUps.level_color(lvl))
	_pip_level = lvl
	_pip_max = max_lvl
	_accent = accent_color
	pip_bar.queue_redraw()


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
