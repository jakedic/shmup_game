extends Bullet
class_name Bullet_Pollen

## Weak, slow, wiggling secondary-fire projectile granted by the "Pollen
## Shot" yellow power-up (see player/player_pollen_shot.gd). Always spawned
## in pairs from the left/right of the ship - unrelated to the player's
## normal bullet entirely. Values here are just editor-time fallbacks;
## PlayerPollenShot overwrites damage/speed/max_distance/wiggle from
## Stats.get_category("pollen") right after instantiate(), same pattern as
## bullet.gd + configure_bullet().

## How far side-to-side the ball drifts as it travels, in pixels.
@export var wiggle_amplitude: float = 10.0
## How fast it wiggles, in radians/sec.
@export var wiggle_frequency: float = 6.0

var _wiggle_time: float = 0.0
var _prev_wiggle_offset: float = 0.0
# Randomized per-bullet so the left/right pair spawned the same frame don't
# wiggle in perfect mirrored lockstep.
var _wiggle_phase: float = 0.0

func _ready():
	add_to_group("player_bullet")
	speed = 90.0
	damage = 1
	max_distance = 220.0
	bullet_color = Color(1.0, 0.85, 0.2)  # pollen yellow
	# 20% chance per hit to inflict "pollinated" (see
	# status_effects/pollinated_status.gd). Generic Bullet plumbing -
	# handle_enemy_collision() in bullet_base.gd rolls this and calls
	# apply_status_effect() on whatever it hits.
	status_effect_name = StatusEffects.POLLINATED
	status_effect_chance = 0.2
	_wiggle_phase = randf() * TAU
	apply_visuals()
	custom_ready()

func custom_process(delta: float) -> void:
	"""Drift side to side relative to the direction of travel as the ball
	moves forward, instead of flying in a straight line."""
	_wiggle_time += delta
	var wiggle_offset = sin(_wiggle_time * wiggle_frequency + _wiggle_phase) * wiggle_amplitude

	# Only apply the CHANGE in offset each frame (not the absolute offset)
	# since position already includes the forward movement applied earlier
	# this frame in _process().
	var lateral_delta = wiggle_offset - _prev_wiggle_offset
	_prev_wiggle_offset = wiggle_offset

	var perpendicular = Vector2(-direction.y, direction.x)
	position += perpendicular * lateral_delta
