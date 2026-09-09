# yellow_solo.gd
# Drives a single BeeEnemy (see the `enemy_scene` export below) flying in
# a straight line from start_pos to end_pos - the solo counterpart to
# enemies/yellow_squad.gd's group choreography, for levels that want a lone
# enemy crossing the screen instead of a whole squad. Two steps:
#
#   1. CROSSING - the enemy travels in a straight line from start_pos to
#                 end_pos at a constant path_speed, weaving side to side in
#                 a sine curve PERPENDICULAR to that line (see
#                 wave_amplitude/wave_frequency below) - vertical wobble for
#                 the typical left-to-right/right-to-left crossing,
#                 horizontal wobble for a top-to-bottom one, whatever's
#                 actually perpendicular to the line the level set up.
#                 Halfway along that line (at the midpoint between start_pos
#                 and end_pos, not tied to any fixed screen coordinate, so
#                 this always fires exactly once no matter where
#                 start_pos/end_pos are placed) it loops-the-loop, optionally
#                 going invincible for the duration (see loop_invincible
#                 below - off by default) - the same loop shape
#                 enemies/yellow_squad.gd uses, rotated here to match
#                 THIS enemy's actual direction of travel instead of always
#                 assuming a straight-down fall (see _advance_loop()).
#   2. RECOVER+CONTINUE - after the loop, it fires its fast bullet a short
#                 beat later (see fire_delay_after_loop), eases its facing
#                 back to pointing along the line over loop_recovery_time,
#                 and keeps crossing with the same wobble as step 1 until it
#                 reaches end_pos, at which point it's removed. This leg is
#                 measured from wherever the loop actually closed (see
#                 _fall_origin), NOT re-derived from the idealized
#                 start_pos->end_pos line - the loop closes at whatever point
#                 on step 1's wobble curve it started from, so snapping back
#                 onto that idealized line here would visibly jump by however
#                 far off the line the enemy happened to be. Typically
#                 end_pos is placed just off the opposite edge of the screen
#                 from start_pos, so this reads as "flies in one side, loops
#                 halfway, flies out the other side" - but nothing here
#                 requires that; any two points work, and it disappears once
#                 it's traveled the full start_pos->end_pos distance.
#
# start_delay holds the enemy motionless at start_pos (still spawned, just
# parked) for that many seconds before it starts crossing - lets a level
# stagger several solo enemies (or a solo alongside a squad) instead of
# everything starting at once, same purpose as BeeSquad's start_delay.
#
# A level spawns one of these per lone enemy via BaseLevel.spawn_solo() (see
# levels/squad_wave_level.gd's "solos" wave-entry list) - each instance is
# entirely independent, with its own start_pos/end_pos.
extends Node2D
class_name BeeSolo

# Relayed from the enemy's own `died` signal so the level can still score
# this kill the same way it does for grid-spawned enemies and squads -
# BaseLevel.spawn_solo() connects this straight to BaseLevel._on_enemy_died().
signal enemy_died(value: int)

@export var enemy_scene: PackedScene
@export var start_pos: Vector2 = Vector2.ZERO   # where the enemy spawns and begins its crossing - typically just off one edge of the screen
@export var end_pos: Vector2 = Vector2.ZERO     # where the enemy is removed once it arrives - typically just off the opposite edge
@export var path_speed: float = 140.0           # px/s along the start_pos -> end_pos line
@export var wave_amplitude: float = 24.0        # how far side to side (perpendicular to the line) the enemy wobbles while crossing, px - 0 flies in a plain straight line
@export var wave_frequency: float = 3.0         # how fast that side-to-side wobble oscillates
@export var loop_radius: float = 26.0           # size of the halfway loop, px
@export var loop_speed_multiplier: float = 1.4  # how much faster than plain path_speed the loop itself turns
@export var fire_delay_after_loop: float = 0.15 # seconds after the loop ends before it actually fires
@export var loop_recovery_time: float = 0.3     # seconds to ease facing back to normal after the loop
@export var loop_invincible: bool = false       # whether the enemy is invincible for the duration of the loop - off by default
@export var start_delay: float = 0.0            # seconds this enemy stays parked at start_pos before crossing

var _enemy: Node = null
var _direction: Vector2 = Vector2.RIGHT   # start_pos -> end_pos, normalized - fixed for the whole crossing
var _perp: Vector2 = Vector2.DOWN         # _direction rotated 90 degrees - the wobble's axis
var _travel_length: float = 0.0
var _traveled: float = 0.0
var _wave_time: float = 0.0

var _looping: bool = false
var _looped: bool = false
var _loop_time: float = 0.0
var _loop_duration: float = 1.0
var _loop_start_pos: Vector2 = Vector2.ZERO
var _loop_ended_at: float = 0.0
var _fall_origin: Vector2 = Vector2.ZERO   # position where the loop actually closed - the post-loop crossing is measured from HERE, not from the idealized start_pos->end_pos line, see _process()
var _fall_traveled: float = 0.0            # px traveled along _direction since the loop ended

var _solo_time: float = 0.0
var _wait_time: float = 0.0  # real time since _ready(), independent of _solo_time - see start_delay


func _ready() -> void:
	var delta_pos: Vector2 = end_pos - start_pos
	_travel_length = delta_pos.length()
	if _travel_length > 0.0:
		_direction = delta_pos / _travel_length
	_perp = Vector2(-_direction.y, _direction.x)

	_spawn_enemy()

	# Same reasoning as BeeSquad's _loop_duration - a loop of radius
	# loop_radius sized so its circumference divided by path_speed keeps
	# tangential speed roughly matching the straight-line crossing, then
	# loop_speed_multiplier nudges it a bit faster than that on top.
	_loop_duration = (TAU * loop_radius / path_speed) / loop_speed_multiplier


func _spawn_enemy() -> void:
	var e = enemy_scene.instantiate()
	add_child(e)
	e.squad_controlled = true    # opt out of base_enemy's own movement/boundary logic - this script drives position entirely
	e.follow_anchor = false
	e.follow_anchor_enabled = false
	e.can_dive = false           # this script's choreography replaces the random zig-zag/loop dive
	e.can_shoot = false          # fires on cue (after the halfway loop), not on ShootTimer
	e.position = start_pos
	e.rotation = _direction.angle() - Vector2.DOWN.angle()  # face along the line of travel from the very first frame, not straight down
	if "last_position" in e:
		e.last_position = e.position  # avoid a bogus facing spike on the first movement frame
	if e.has_method("_stop_idle_rock"):
		e._stop_idle_rock()  # keep it visually still until it's actually moving
	if e.has_signal("died"):
		e.died.connect(_on_enemy_died)
	_enemy = e


func _on_enemy_died(value: int) -> void:
	enemy_died.emit(value)


func _update_enemy_facing(delta: float) -> void:
	"""Point the enemy the way it actually just moved this frame, using
	BeeEnemy's own _update_facing() (same rotation math BeeSquad uses)
	so it stays consistent whether it's crossing normally or mid-loop."""
	if is_instance_valid(_enemy) and _enemy.has_method("_update_facing"):
		_enemy._update_facing(delta)


func _process(delta: float) -> void:
	_wait_time += delta
	if _wait_time < start_delay:
		return  # still parked at start_pos - see start_delay

	if not is_instance_valid(_enemy) or not _enemy.is_alive:
		queue_free()  # killed - nothing left for this node to do
		return

	_solo_time += delta

	if _looping:
		_advance_loop(delta)
		return

	_traveled += path_speed * delta
	var t: float = 1.0 if _travel_length <= 0.0 else clamp(_traveled / _travel_length, 0.0, 1.0)
	_wave_time += delta
	var wobble: float = sin(_wave_time * wave_frequency) * wave_amplitude

	if _looped:
		# Post-loop: keep going from wherever the loop actually closed
		# (_fall_origin, captured in _advance_loop() when it ended) instead of
		# snapping back onto the idealized start_pos->end_pos line via
		# start_pos.lerp(end_pos, t) - the loop closes at whatever point on
		# the WOBBLE curve it started from, which is usually off that
		# idealized line by some fraction of wave_amplitude, so re-deriving
		# position from the line instead of from where the enemy actually is
		# produced a visible snap the instant the loop ended. See
		# enemies/yellow_squad.gd's _process_solo_fall() - same fix, same
		# reasoning, applied there already.
		_fall_traveled += path_speed * delta
		_enemy.position = _fall_origin + _direction * _fall_traveled + _perp * wobble
	else:
		var anchor: Vector2 = start_pos.lerp(end_pos, t)
		_enemy.position = anchor + _perp * wobble

	if _looped and _solo_time < _loop_ended_at + loop_recovery_time:
		# The facing-recovery tween (see _start_facing_recovery()) owns
		# rotation right now - just keep last_position in sync so
		# velocity-based facing resumes cleanly the moment the tween's done,
		# instead of fighting it every frame in between.
		if "last_position" in _enemy:
			_enemy.last_position = _enemy.position
	else:
		_update_enemy_facing(delta)

	if not _looped and t >= 0.5:
		_start_loop()
		return

	if t >= 1.0:
		queue_free()  # reached end_pos - single pass, no reuse


func _start_loop() -> void:
	_looping = true
	_loop_time = 0.0
	_loop_start_pos = _enemy.position
	if loop_invincible and _enemy.has_method("set_invincible"):
		_enemy.set_invincible(true)


func _advance_loop(delta: float) -> void:
	_loop_time += delta
	var t: float = _loop_time / _loop_duration
	# Clamp to exactly 1.0 for the frame that finishes the loop instead of
	# skipping straight to the end-of-loop handling - without this, the loop
	# always cut off a few degrees short of the full 360.
	var clamped_t: float = min(t, 1.0)

	# Same loop shape as BeeSquad's _advance_member_loop() - a circle
	# whose tangent at angle 0 (and TAU, where it closes back up) points
	# straight down in its own local frame - but rotated here to match THIS
	# enemy's actual direction of travel, since a solo enemy isn't always
	# falling straight down. Rotating the whole offset by
	# (direction angle - down's angle) realigns it so the tangent at the
	# seam matches the velocity direction this enemy actually had right
	# before the loop started (and will have right after it ends), so the
	# hand-off in and out of the loop reads as one continuous turn.
	var angle: float = clamped_t * TAU
	var base_offset := Vector2(cos(angle) - 1.0, sin(angle)) * loop_radius
	var rotation_offset: float = _direction.angle() - Vector2.DOWN.angle()
	_enemy.position = _loop_start_pos + base_offset.rotated(rotation_offset)
	_update_enemy_facing(delta)

	if t >= 1.0:
		_looping = false
		_looped = true
		_loop_ended_at = _solo_time
		_wave_time = 0.0        # fresh wobble phase for the resumed crossing, starting at zero offset
		_fall_origin = _enemy.position  # centered on wherever the loop actually ended, no jump - see _process()
		_fall_traveled = 0.0
		_start_facing_recovery()
		_fire_after_loop()


func _start_facing_recovery() -> void:
	"""Ease back to facing along the line of travel - the same direction the
	enemy was headed in before the loop started - instead of snapping to it.
	Same reasoning as BeeSquad's _start_facing_recovery(): the loop's exit
	velocity points sideways-ish for an instant (it's tangent to the loop,
	not aligned with the resumed straight crossing), which would otherwise
	cause a one-frame facing pop the moment normal velocity-based facing
	(_update_enemy_facing) took back over.

	IMPORTANT: _enemy.rotation right now is whatever raw principal-value
	angle (-PI, PI] velocity-based facing last landed on, which can be on
	either "side" of the wrap almost at random. Tweening straight to the
	fixed target_rotation would sometimes take the LONG way around (up to
	nearly a full 360-degree spin in loop_recovery_time) if the two happen to
	sit on opposite sides of that wrap - which reads as a fast, glitchy snap,
	easy to mistake for the enemy's position itself jumping. wrapf() finds
	the equivalent target angle closest to the CURRENT rotation instead, so
	the tween always turns the short way."""
	var target_rotation: float = _direction.angle() - Vector2.DOWN.angle()
	var target: float = _enemy.rotation + wrapf(target_rotation - _enemy.rotation, -PI, PI)
	var tw = _enemy.create_tween()
	tw.tween_property(_enemy, "rotation", target, loop_recovery_time)


func _fire_after_loop() -> void:
	"""Wait a short beat after the loop's own animation completes before
	actually firing, so the shot clearly reads as happening AFTER the loop
	rather than the instant the loop's math resets back to its start
	position. Invincibility (when loop_invincible is on) drops at the same
	moment the shot fires."""
	await get_tree().create_timer(fire_delay_after_loop).timeout
	if not is_instance_valid(_enemy) or not _enemy.is_alive:
		return
	if _enemy.has_method("shoot_single"):
		_enemy.shoot_single()
	if loop_invincible and _enemy.has_method("set_invincible"):
		_enemy.set_invincible(false)
