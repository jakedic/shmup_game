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

## If the yellow form's FULLY CHARGED shot flies through a puff, the puff
## bursts in a small pollen explosion and leaves a patch of pollen residue
## (status_effects/pollen_residue.gd) - enemies passing through it have a
## 50% chance to become pollinated. See _check_charged_shot_burst().
const POLLEN_RESIDUE_SCRIPT := preload("res://status_effects/pollen_residue.gd")
# How close a charged shot has to come to the puff's center to burst it.
const BURST_TOUCH_DISTANCE := 12.0
# Radius of the small burst drawn when it pops.
const BURST_VISUAL_RADIUS := 22.0

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
	if _check_charged_shot_burst():
		return
	if not has_node("Sprite2D"):
		return
	_pulse_time += delta
	var pulse = 1.0 + sin(_pulse_time * pulse_frequency + _pulse_phase) * pulse_amplitude
	$Sprite2D.scale = _base_sprite_scale * pulse


func _check_charged_shot_burst() -> bool:
	"""Burst if a fully charged yellow shot (group "yellow_charged_shot",
	added in PlayerChargeShot._fire_charged_shot()) is touching this puff.
	Checked by distance so it doesn't depend on collision layers. The shot
	itself carries on."""
	if is_queued_for_deletion():
		return true
	for shot in get_tree().get_nodes_in_group("yellow_charged_shot"):
		if is_instance_valid(shot) and not shot.is_queued_for_deletion() \
				and global_position.distance_to(shot.global_position) <= BURST_TOUCH_DISTANCE:
			_burst()
			return true
	return false


func _burst() -> void:
	"""Small pollen explosion + a lingering patch of pollen residue."""
	var pos := global_position
	var boom := PollenExplosionVisual.new()
	boom.max_radius = BURST_VISUAL_RADIUS
	GameShell.game_root().add_child(boom)
	boom.global_position = pos
	var residue: Node2D = POLLEN_RESIDUE_SCRIPT.new()
	GameShell.game_root().add_child(residue)
	residue.global_position = pos
	queue_free()
