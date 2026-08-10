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

@onready var name_label: Label = $CenterContainer/VBoxContainer/NameLabel
@onready var description_label: Label = $CenterContainer/VBoxContainer/DescriptionLabel
@onready var continue_hint: Label = $CenterContainer/VBoxContainer/ContinueHint
@onready var min_display_timer: Timer = $MinDisplayTimer

var can_dismiss: bool = false


func _ready() -> void:
	hide()
	continue_hint.hide()
	min_display_timer.one_shot = true
	min_display_timer.wait_time = MIN_DISPLAY_TIME
	min_display_timer.timeout.connect(_on_min_display_timer_timeout)


func show_powerup(powerup: Dictionary) -> void:
	"""Display the given power-up's name/description (see
	player/player_powerups.gd for the dict shape) and start the
	minimum-display countdown before the player can dismiss it."""
	name_label.text = powerup.get("name", "Power-Up!")
	description_label.text = powerup.get("description", "")

	can_dismiss = false
	continue_hint.hide()
	show()
	min_display_timer.start()


func _on_min_display_timer_timeout() -> void:
	can_dismiss = true
	continue_hint.show()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not can_dismiss:
		return

	# Deliberately generic - "a button" per the design, not one specific
	# mapped action, so any key press or gamepad button press dismisses it.
	if (event is InputEventKey or event is InputEventJoypadButton) and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		continue_pressed.emit()
