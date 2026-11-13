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
# (POLLEN_RESIDUE_SCRIPT is inherited from Bullet - bullets/bullet.gd.)
# How close a charged shot has to come to the puff's center to burst it.
const BURST_TOUCH_DISTANCE := 12.0
# Radius of the small burst drawn when it pops.
const BURST_VISUAL_RADIUS := 22.0

## Flight: the puff launches fast and steadily slows to a full stop right
## at max_distance, then hangs there for HOLD_TIME seconds before fading
## out. The launch speed is LAUNCH_SPEED_MULT x the "speed" stat - with 2.0
## the trip takes the same total time as the old constant-speed drift
## (it just front-loads it).
const LAUNCH_SPEED_MULT := 2.0
const HOLD_TIME := 2.0
const FADE_TIME := 0.2

var _decel: float = 0.0       # px/s^2, worked out at launch
var _holding := false
var _hold_left: float = 0.0
var _fading := false

## Puff-on-puff: two puffs touching both burst (same burst as a charged
## shot flying through one), and puffs within ATTRACT_RADIUS drift gently
## toward each other to help that happen. ATTRACT_ACCEL is the pull at
## point-blank (px/s^2), fading linearly to 0 at ATTRACT_RADIUS. The drift
## is capped at ATTRACT_MAX_SPEED so it stays subtle.
const PUFF_TOUCH_DISTANCE := 14.0
const ATTRACT_RADIUS := 40.0
const ATTRACT_ACCEL := 40.0
const ATTRACT_MAX_SPEED := 25.0
var _drift := Vector2.ZERO
var _burst_pending := false

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
	add_to_group("pollen_puff")
	speed = 45.0
	damage = 1  # purely a pollination tool - never deals damage
	max_distance = 136.0
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

func custom_start() -> void:
	# Constant deceleration that brings the launch speed to exactly 0 at
	# max_distance: v^2 = 2 * a * d.
	speed = speed * LAUNCH_SPEED_MULT
	_decel = (speed * speed) / (2.0 * maxf(max_distance, 1.0))


func _process(delta: float) -> void:
	"""Replaces Bullet._process(): fast launch -> slows to a stop at
	max_distance -> holds HOLD_TIME seconds -> fades out. Pulses the whole
	time and can still be burst by a charged shot."""
	time_alive += delta
	if _check_charged_shot_burst():
		return
	if _check_puff_collision():
		return
	_apply_puff_attraction(delta)
	_pulse(delta)

	if _holding:
		_hold_left -= delta
		if _hold_left <= 0.0 and not _fading:
			_fading = true
			var tw := create_tween()
			tw.tween_property(self, "modulate:a", 0.0, FADE_TIME)
			tw.tween_callback(queue_free)
		return

	# Average of the start and end speed this frame, so the stop lands on
	# max_distance no matter the frame rate.
	var new_speed: float = maxf(speed - _decel * delta, 0.0)
	var step: float = (speed + new_speed) * 0.5 * delta
	speed = new_speed
	var remaining: float = max_distance - distance_traveled
	if step >= remaining or speed <= 0.0:
		step = maxf(remaining, 0.0)
		_holding = true
		_hold_left = HOLD_TIME
		speed = 0.0
	position += direction * step
	distance_traveled += step


func _other_puffs() -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group("pollen_puff"):
		if n != self and is_instance_valid(n) and not n.is_queued_for_deletion() and not n._fading:
			out.append(n)
	return out


func _check_puff_collision() -> bool:
	"""Two puffs touching -> both burst."""
	if _fading:
		return false
	for other in _other_puffs():
		if global_position.distance_to(other.global_position) <= PUFF_TOUCH_DISTANCE:
			other._burst()
			_burst()
			return true
	return false


func _apply_puff_attraction(delta: float) -> void:
	"""Very slight pull toward nearby puffs, moving or parked."""
	var accel := Vector2.ZERO
	for other in _other_puffs():
		var to_other: Vector2 = other.global_position - global_position
		var d := to_other.length()
		if d > 0.01 and d < ATTRACT_RADIUS:
			accel += to_other / d * ATTRACT_ACCEL * (1.0 - d / ATTRACT_RADIUS)
	if accel == Vector2.ZERO:
		_drift = _drift.move_toward(Vector2.ZERO, ATTRACT_ACCEL * delta)   # settle when alone
	else:
		_drift = (_drift + accel * delta).limit_length(ATTRACT_MAX_SPEED)
	position += _drift * delta


func _pulse(delta: float) -> void:
	"""Pulsate instead of wiggling side to side - swells and shrinks the
	sprite around its base scale."""
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


# --- Already-pollinated enemy runs into the puff -> puff bursts ---
# A fresh (un-pollinated) enemy still gets the normal hit: pollinated, and
# the puff is used up. An enemy that is ALREADY pollinated sets the puff off
# instead, same burst as a charged shot or another puff.

func _on_area_entered(area: Area2D):
	if _is_pollinated_enemy(area):
		_burst_deferred()
		return
	super(area)


func _on_body_entered(body: Node2D):
	if _is_pollinated_enemy(body):
		_burst_deferred()
		return
	super(body)


func _is_pollinated_enemy(n: Node) -> bool:
	return n != null and n.is_in_group("enemies") and n.has_method("has_status_effect") \
			and n.has_status_effect(StatusEffects.POLLINATED)


func _burst_deferred() -> void:
	# Collision callbacks run while physics is busy; spawning the residue
	# (an Area2D) right then isn't allowed, so burst at the end of the frame.
	if _burst_pending or is_queued_for_deletion():
		return
	_burst_pending = true
	call_deferred("_burst")


func _burst() -> void:
	"""Small pollen explosion + a lingering patch of pollen residue."""
	if is_queued_for_deletion():
		return
	var pos := global_position
	var boom := PollenExplosionVisual.new()
	boom.max_radius = BURST_VISUAL_RADIUS
	GameShell.game_root().add_child(boom)
	boom.global_position = pos
	var residue: Node2D = POLLEN_RESIDUE_SCRIPT.new()
	GameShell.game_root().add_child(residue)
	residue.global_position = pos
	queue_free()
