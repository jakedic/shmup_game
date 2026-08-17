extends Bullet
class_name Bullet_PollenPuff

## Larger, slow "pollen puff" fired when the player releases the yellow
## form's charge shot BEFORE it's fully charged (see
## player/player_charge_shot.gd - _release_charge()/_fire_pollen_puff()).
## Unlike the wiggling secondary-fire pollen balls from the "Pollen Shot"
## power-up (bullets/bullet_pollen.gd), this one gently pulses in place as
## it drifts forward instead of wiggling side to side, never deals damage,
## and always inflicts "pollinated" on whatever it touches - a reliable if
## weak consolation prize for releasing too early. Values here are just
## editor-time fallbacks; PlayerChargeShot overwrites
## damage/speed/max_distance/pulse from Stats.get_category("pollen_puff")
## right after instantiate(), same pattern as bullet_pollen.gd.

## How much the sprite swells/shrinks by, as a fraction of its base scale -
## e.g. 0.25 means it pulses between 75% and 125% of its base size.
@export var pulse_amplitude: float = 0.25
## How fast it pulses, in radians/sec.
@export var pulse_frequency: float = 3.0

var _pulse_time: float = 0.0
# Randomized per-instance so multiple puffs on screen don't pulse in lockstep.
var _pulse_phase: float = 0.0
var _base_sprite_scale: Vector2 = Vector2.ONE

func _ready():
	add_to_group("player_bullet")
	speed = 45.0
	damage = 0  # purely a pollination tool - never deals damage
	max_distance = 260.0
	bullet_color = Color(1.0, 0.85, 0.2)  # pollen yellow, same family as bullet_pollen
	# 100% chance to inflict "pollinated" (see status_effects/pollinated_status.gd) -
	# unlike the 20% chance on the wiggling secondary-fire pollen balls, this
	# is meant to always land as a consolation for an early release.
	status_effect_name = StatusEffects.POLLINATED
	status_effect_chance = 1.0
	_pulse_phase = randf() * TAU
	apply_visuals()
	custom_ready()

func custom_ready() -> void:
	if has_node("Sprite2D"):
		_base_sprite_scale = $Sprite2D.scale

func custom_process(delta: float) -> void:
	"""Pulsate in place instead of wiggling side to side - swells and
	shrinks the sprite around its base scale as it drifts slowly forward."""
	if not has_node("Sprite2D"):
		return
	_pulse_time += delta
	var pulse = 1.0 + sin(_pulse_time * pulse_frequency + _pulse_phase) * pulse_amplitude
	$Sprite2D.scale = _base_sprite_scale * pulse
