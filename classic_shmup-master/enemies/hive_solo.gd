# hive_solo.gd
# Drives a single HiveEnemy (see enemies/enemy_hive.gd) along a hand-authored
# "stop and dance" path - a completely different shape from
# enemies/yellow_solo.gd's BeeSolo (a straight crossing) and from this
# script's own earlier dog-leg version:
#
#   1. Spawns ABOVE the screen (off-screen, like a normal enemy entrance) and
#      flies straight down onto it, spinning a full 360 degrees over that
#      entry (see the "spin while moving" note below).
#   2. Stops in place once it's on-screen, rocking back and forth a bit AND
#      jittering/twitching in a small, quick, buzzy way - like a bee.
#   3. Travels in a straight line 45 degrees CLOCKWISE of straight down,
#      spinning a full 360 degrees over that leg.
#   4. Stops in place again and rocks/jitters the same way.
#   5. Travels in a straight line 45 degrees COUNTERCLOCKWISE of straight
#      down, spinning again.
#   6. Stops in place a third time and rocks/jitters the same way.
#   7. Travels straight down, spinning continuously, until it exits the
#      bottom of the screen.
#
# This is a first pass specifically to preview this movement shape (per
# explicit request) - the honey-glob spread-shot attack from an earlier
# dog-leg version of this file (and the "pause + smoothly turn to face each
# shot" choreography built for it) is NOT part of this pattern. The 3
# stop-and-jitter pauses below would be a natural place to hang that attack
# back onto later if wanted - see _apply_pause().
#
# Every travel leg is a straight line at a fixed, ABSOLUTE direction (relative
# to straight down, not to any screen edge) - this path isn't generalized
# over an entry side the way BeeSolo is, since "45 degrees clockwise/
# counterclockwise of straight down" and "straight down" are fixed compass
# directions the user specified directly.
#
# A level spawns one of these per hive enemy via
# BaseLevel.spawn_hive_solo() - see levels/hive_level.gd.
extends Node2D
class_name HiveSolo

# Relayed from the enemy's own `died` signal so the level can score this
# kill the same way it does for any other enemy - BaseLevel.spawn_hive_solo()
# connects this straight to BaseLevel._on_enemy_died().
signal enemy_died(value: int)

const SPAWN_MARGIN := 40.0  # how far off-screen (above, at spawn - and below, at despawn) this enemy sits, px

@export var enemy_scene: PackedScene
@export var start_x_percent: float = 0.5   # horizontal position, 0.0-1.0 fraction of screen width - held constant through the entry AND used to build the diagonal legs from
@export var pause_y: float = 60.0          # vertical position, px down from the top, where it comes to rest for pause 1 (and where the whole dance is built from) - it SPAWNS above this, off-screen, and flies down onto it first
@export var path_speed: float = 70.0       # px/s during every travel leg (the entry descent and all 3 dance legs)
@export var leg_length: float = 90.0       # how far it travels during the two diagonal legs (the 45-degree ones)
@export var start_delay: float = 0.0       # seconds parked off-screen before the entry descent begins, same purpose as BeeSolo's

# ----- stop-and-jitter pause tuning -----
@export var pause_duration: float = 0.6           # how long each of the 3 pauses lasts, in seconds
@export var tilt_amplitude_deg: float = 10.0      # degrees - the slow, deliberate side-to-side ROCK during a pause
@export var tilt_cycles: float = 2.0              # how many full rocks happen per pause - kept a WHOLE number so the rock is exactly level at both the start and the end of the pause, with no visual pop
@export var jitter_amplitude: float = 2.0         # px - magnitude of the small, quick, randomized buzz layered on top of the rock (both x and y)
@export var jitter_rotation_amplitude_deg: float = 4.0  # degrees - magnitude of that same buzz's extra rotation twitch
@export var jitter_update_interval: float = 0.05  # seconds between re-rolling the random buzz offset - short, so it reads as a fast twitchy jitter rather than a smooth wobble

enum Phase { ENTRY, PAUSE1, TRAVEL1, PAUSE2, TRAVEL2, PAUSE3, TRAVEL3 }

var _enemy: Node = null
var _screensize: Vector2 = Vector2.ZERO
var _wait_time: float = 0.0

var _phase: Phase = Phase.ENTRY
var _phase_time: float = 0.0
var _phase_duration: float = 0.0

# The small buzzy jitter's current random offset, re-rolled every
# jitter_update_interval seconds while paused - see _apply_pause().
var _jitter_timer: float = 0.0
var _jitter_offset: Vector2 = Vector2.ZERO
var _jitter_rotation: float = 0.0

# Fixed geometry, computed once by _build_path(): the two diagonal
# directions (relative to straight down), the entry point (off-screen,
# above), and the 3 on-screen waypoints the dance connects. Every pause
# happens at one of the 3 on-screen waypoints; every travel leg connects two
# consecutive points (the entry descent counts as a leg too, from _spawn_pos
# to _pause1_pos).
var _dir1: Vector2 = Vector2.DOWN  # 45 degrees CLOCKWISE of straight down
var _dir2: Vector2 = Vector2.DOWN  # 45 degrees COUNTERCLOCKWISE of straight down
var _dir3: Vector2 = Vector2.DOWN  # straight down

var _spawn_pos: Vector2 = Vector2.ZERO       # off-screen, above the top edge - where it actually spawns
var _pause1_pos: Vector2 = Vector2.ZERO      # on-screen - end of the entry descent / where pause 1 happens
var _travel1_target: Vector2 = Vector2.ZERO  # end of leg 1 / where pause 2 happens
var _travel2_target: Vector2 = Vector2.ZERO  # end of leg 2 / where pause 3 happens

# One full rotation (TAU radians) per travel leg's own duration, applied as a
# constant angular rate rather than interpolated by t - see the "spin while
# moving" note in _process(), and why TRAVEL3 (open-ended, no fixed
# duration) needs this instead of a t-based spin.
var _spin_rate: float = 0.0


func _ready() -> void:
	_screensize = get_viewport_rect().size
	_build_path()
	_spawn_enemy()
	_enter_phase(Phase.ENTRY)


# ---------------------------------------------------------------------------
# PATH CONSTRUCTION - done once up front, same philosophy as the old dog-leg
# version: figure out every position/direction ahead of time so _process()
# only ever has to interpolate.
# ---------------------------------------------------------------------------

func _build_path() -> void:
	var angle: float = deg_to_rad(45.0)
	_dir1 = Vector2.DOWN.rotated(angle)    # positive .rotated() angle = visually clockwise in Godot's y-down coordinates
	_dir2 = Vector2.DOWN.rotated(-angle)   # negative = counterclockwise
	_dir3 = Vector2.DOWN

	var x: float = _screensize.x * start_x_percent
	_spawn_pos = Vector2(x, -SPAWN_MARGIN)   # off-screen, above the top edge
	_pause1_pos = Vector2(x, pause_y)        # where the entry descent ends and pause 1 happens

	_travel1_target = _pause1_pos + _dir1 * leg_length
	_travel2_target = _travel1_target + _dir2 * leg_length

	_spin_rate = TAU / (leg_length / path_speed)  # radians/sec - "one full spin" worth of angular speed for a leg_length-long leg at path_speed


func _facing_rotation_for(direction: Vector2) -> float:
	"""The `rotation` value that makes the enemy visually face `direction`,
	given its art faces "down" at rotation 0 (same convention
	enemy_hive.gd's own velocity-based _update_facing() uses)."""
	return direction.angle() - Vector2.DOWN.angle()


# ---------------------------------------------------------------------------
# ENEMY SPAWNING - same technique as enemies/yellow_solo.gd's _spawn_enemy():
# hand the enemy instance over to this controller entirely (squad_controlled)
# instead of letting base_enemy.gd's own fall/dive logic run.
# ---------------------------------------------------------------------------

func _spawn_enemy() -> void:
	var e = enemy_scene.instantiate()
	add_child(e)
	e.squad_controlled = true    # opt out of base_enemy's own movement/boundary logic - this script drives position entirely
	e.follow_anchor = false
	e.follow_anchor_enabled = false
	e.can_dive = false           # this script's choreography replaces the random zig-zag/loop dive
	e.can_shoot = false          # no shooting behavior in this pass - movement only, per this request
	e.position = _spawn_pos
	e.rotation = _facing_rotation_for(_dir3)  # entry descent travels straight down
	if "last_position" in e:
		e.last_position = e.position
	if e.has_method("_stop_idle_rock"):
		e._stop_idle_rock()
	if e.has_signal("died"):
		e.died.connect(_on_enemy_died)
	_enemy = e


func _on_enemy_died(value: int) -> void:
	enemy_died.emit(value)


# ---------------------------------------------------------------------------
# PER-FRAME MOVEMENT - a plain state machine over 7 phases: an off-screen
# entry descent (ENTRY), then 3 stop-and-jitter pauses (PAUSE1-3) alternating
# with 3 straight travel legs (TRAVEL1-3). Every phase but the last
# (TRAVEL3, which just runs until off-screen) has a fixed duration, so a
# phase transition is just "t reached 1.0".
# ---------------------------------------------------------------------------

func _enter_phase(phase: Phase) -> void:
	_phase = phase
	_phase_time = 0.0
	if phase == Phase.PAUSE1 or phase == Phase.PAUSE2 or phase == Phase.PAUSE3:
		_jitter_timer = 0.0  # force an immediate re-roll on this pause's first frame
	match phase:
		Phase.ENTRY:
			_phase_duration = _spawn_pos.distance_to(_pause1_pos) / path_speed
		Phase.PAUSE1, Phase.PAUSE2, Phase.PAUSE3:
			_phase_duration = pause_duration
		Phase.TRAVEL1, Phase.TRAVEL2:
			_phase_duration = leg_length / path_speed
		Phase.TRAVEL3:
			_phase_duration = -1.0  # runs until off-screen - see _is_past_bottom_edge()


func _process(delta: float) -> void:
	_wait_time += delta
	if _wait_time < start_delay:
		return  # still parked off-screen at spawn_pos - see start_delay

	if not is_instance_valid(_enemy) or not _enemy.is_alive:
		queue_free()  # killed - nothing left for this node to do
		return

	_phase_time += delta
	var t: float = 1.0 if _phase_duration <= 0.0 else clamp(_phase_time / _phase_duration, 0.0, 1.0)

	# Every travel phase spins the sprite a full 360 degrees at a constant
	# rate (_spin_rate, radians/sec - one whole turn per leg_length-long leg)
	# ON TOP OF facing the direction of travel, using _phase_time directly
	# rather than t - TRAVEL3 has no fixed duration (t is pinned to 1.0 the
	# whole time it runs), so a t-based spin would never actually turn during
	# it; a plain time * rate spin works the same way for every leg
	# regardless of whether that leg ever finishes.
	match _phase:
		Phase.ENTRY:
			_enemy.position = _spawn_pos.lerp(_pause1_pos, t)
			_enemy.rotation = _facing_rotation_for(_dir3) + _phase_time * _spin_rate
		Phase.PAUSE1:
			_apply_pause(_pause1_pos, _facing_rotation_for(_dir1), t, delta)
		Phase.TRAVEL1:
			_enemy.position = _pause1_pos.lerp(_travel1_target, t)
			_enemy.rotation = _facing_rotation_for(_dir1) + _phase_time * _spin_rate
		Phase.PAUSE2:
			_apply_pause(_travel1_target, _facing_rotation_for(_dir2), t, delta)
		Phase.TRAVEL2:
			_enemy.position = _travel1_target.lerp(_travel2_target, t)
			_enemy.rotation = _facing_rotation_for(_dir2) + _phase_time * _spin_rate
		Phase.PAUSE3:
			_apply_pause(_travel2_target, _facing_rotation_for(_dir3), t, delta)
		Phase.TRAVEL3:
			_enemy.position += _dir3 * path_speed * delta
			_enemy.rotation = _facing_rotation_for(_dir3) + _phase_time * _spin_rate

	if _phase == Phase.TRAVEL3:
		if _is_past_bottom_edge(_enemy.position):
			queue_free()  # reached the bottom edge - single pass, no reuse
		return

	if t >= 1.0:
		_advance_phase()


func _apply_pause(base_pos: Vector2, base_rotation: float, t: float, delta: float) -> void:
	"""The stop-and-jitter pause: `t` (0.0-1.0) is how far through the pause
	we are. Two things are layered on top of `base_pos`/`base_rotation`:
	  - A slow, deliberate side-to-side ROCK (`tilt`) - a plain sine wave
	    over `t`, scaled so a WHOLE number of cycles fit the pause (see
	    tilt_cycles) so it's always exactly level at t=0 and t=1, no pop.
	  - A small, fast, RANDOMIZED jitter (position AND rotation) - like a
	    bee's buzz - re-rolled every jitter_update_interval seconds rather
	    than smoothly animated, so it reads as quick discrete twitches. It's
	    scaled by `envelope` (sin(PI*t), which is 0 at t=0 and t=1 and peaks
	    at t=0.5) so the twitching fades in and back out smoothly too, even
	    though the random values themselves jump around - no seam into or
	    out of the pause either way."""
	var tilt: float = sin(TAU * tilt_cycles * t) * deg_to_rad(tilt_amplitude_deg)
	var envelope: float = sin(PI * t)

	_jitter_timer -= delta
	if _jitter_timer <= 0.0:
		_jitter_offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * jitter_amplitude
		_jitter_rotation = randf_range(-1.0, 1.0) * deg_to_rad(jitter_rotation_amplitude_deg)
		_jitter_timer = jitter_update_interval

	_enemy.position = base_pos + _jitter_offset * envelope
	_enemy.rotation = base_rotation + tilt + _jitter_rotation * envelope


func _is_past_bottom_edge(pos: Vector2) -> bool:
	return pos.y > _screensize.y + SPAWN_MARGIN


func _advance_phase() -> void:
	match _phase:
		Phase.ENTRY: _enter_phase(Phase.PAUSE1)
		Phase.PAUSE1: _enter_phase(Phase.TRAVEL1)
		Phase.TRAVEL1: _enter_phase(Phase.PAUSE2)
		Phase.PAUSE2: _enter_phase(Phase.TRAVEL2)
		Phase.TRAVEL2: _enter_phase(Phase.PAUSE3)
		Phase.PAUSE3: _enter_phase(Phase.TRAVEL3)
