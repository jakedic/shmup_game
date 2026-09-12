# hive_solo.gd
# Drives a single HiveEnemy (see enemies/enemy_hive.gd) along a hand-authored
# "stop and dance" path - a completely different shape from
# enemies/yellow_solo.gd's BeeSolo (a straight crossing) and from this
# script's own earlier dog-leg version:
#
#   1. Spawns ABOVE the screen (off-screen, like a normal enemy entrance) and
#      flies straight down onto it, spinning spin_full_turns times over that
#      entry (see the "spin" note below) - no jitter during this, or any,
#      travel leg.
#   2. Stops in place once it's on-screen for pause_duration seconds, rocking
#      back and forth a bit, jittering/twitching in a small, quick, buzzy way
#      - like a bee - AND firing a 3-shot honey-glob fan, one shot at a time.
#   3. Travels in a straight line 45 degrees CLOCKWISE of straight down,
#      spinning spin_full_turns times, no jitter.
#   4. Stops in place again and rocks/jitters/fires the same way.
#   5. Travels in a straight line 45 degrees COUNTERCLOCKWISE of straight
#      down, spinning, no jitter.
#   6. Stops in place a third time and rocks/jitters/fires the same way.
#   7. Travels straight down, spinning continuously (no jitter), until it
#      exits the bottom of the screen.
#
# JITTER is PAUSE-ONLY - it fades in and back out smoothly within each pause
# (see the `envelope` in _pause_jitter()) and doesn't run at all during any
# travel/spin phase, so spinning/moving is always jitter-free. It's a
# small, fast, RANDOMIZED buzz (position AND rotation), re-rolled every
# jitter_update_interval seconds rather than smoothly animated, so it reads
# as quick discrete twitches - "like a bee" - rather than a smooth wobble.
#
# HONEY GLOB FAN - fired once every time a pause begins (see
# _start_honey_spread(), called from _enter_phase() for PAUSE1/2/3): three
# HoneyGlobBullet projectiles (see enemy_bullets/honey_glob.gd), one at a
# time (honey_shot_stagger seconds apart, not simultaneously), in a fixed fan
# relative to straight down - NOT relative to this enemy's current direction
# of travel - in this order: honey_spread_angle_deg clockwise of straight
# down, then straight down, then honey_spread_angle_deg counterclockwise of
# straight down. All 3 shots fit comfortably inside one pause_duration at the
# default timings (3 shots * honey_shot_stagger apart).
#
# The deliberate ROCK (tilt_amplitude_deg/tilt_cycles - "just rotate back and
# forth") and the jitter both only happen during the 3 pauses; the
# spin_full_turns-turn spin only happens during travel legs - the two never
# overlap.
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
const HONEY_GLOB_SCENE := preload("res://enemy_bullets/honey_glob.tscn")

@export var enemy_scene: PackedScene
@export var start_x_percent: float = 0.5   # horizontal position, 0.0-1.0 fraction of screen width - held constant through the entry AND used to build the diagonal legs from
@export var pause_y: float = 60.0          # vertical position, px down from the top, where it comes to rest for pause 1 (and where the whole dance is built from) - it SPAWNS above this, off-screen, and flies down onto it first
@export var path_speed: float = 70.0       # px/s during every travel leg (the entry descent and all 3 dance legs)
@export var leg_length: float = 90.0       # how far it travels during the two diagonal legs (the 45-degree ones)
@export var spin_full_turns: float = 2.0   # how many full 360-degree rotations happen over the course of ONE travel leg - 2.0 = spin 720 degrees per leg
@export var start_delay: float = 0.0       # seconds parked off-screen before the entry descent begins, same purpose as BeeSolo's

# ----- stop-and-jitter pause tuning -----
@export var pause_duration: float = 1.2           # how long each of the 3 pauses lasts, in seconds - longer gap between moves, per explicit request
@export var tilt_amplitude_deg: float = 10.0      # degrees - the slow, deliberate side-to-side ROCK during a pause (pauses only)
@export var tilt_cycles: float = 2.0              # how many full rocks happen per pause - kept a WHOLE number so the rock is exactly level at both the start and the end of the pause, with no visual pop

# ----- jitter tuning - PAUSE-ONLY, see header comment -----
@export var jitter_amplitude: float = 2.0         # px - magnitude of the small, quick, randomized buzz (both x and y)
@export var jitter_rotation_amplitude_deg: float = 4.0  # degrees - magnitude of that same buzz's extra rotation twitch
@export var jitter_update_interval: float = 0.05  # seconds between re-rolling the random buzz offset - short, so it reads as a fast twitchy jitter rather than a smooth wobble

# ----- honey glob fan - fired once at the start of every pause, see header comment -----
@export var honey_spread_angle_deg: float = 45.0  # how far the first/last shot angles from straight down
@export var honey_shot_stagger: float = 0.18      # seconds between each of the 3 staggered shots

enum Phase { ENTRY, PAUSE1, TRAVEL1, PAUSE2, TRAVEL2, PAUSE3, TRAVEL3 }

var _enemy: Node = null
var _screensize: Vector2 = Vector2.ZERO
var _wait_time: float = 0.0

var _phase: Phase = Phase.ENTRY
var _phase_time: float = 0.0
var _phase_duration: float = 0.0

# The small buzzy jitter's current random offset, re-rolled every
# jitter_update_interval seconds while a pause is running - see
# _pause_jitter(). Only ever read from within a PAUSE phase, so it has no
# effect on any travel/spin phase.
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

# spin_full_turns worth of rotation (TAU * spin_full_turns radians) per
# travel leg's own duration, applied as a constant angular rate rather than
# interpolated by t - see the "spin while moving" note in _process(), and
# why TRAVEL3 (open-ended, no fixed duration) needs this instead of a
# t-based spin.
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

	_spin_rate = spin_full_turns * TAU / (leg_length / path_speed)  # radians/sec - spin_full_turns worth of angular speed for a leg_length-long leg at path_speed


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
	e.can_shoot = false          # no shooting behavior of the enemy's own - HiveSolo fires the honey globs itself
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
	match phase:
		Phase.ENTRY:
			_phase_duration = _spawn_pos.distance_to(_pause1_pos) / path_speed
		Phase.PAUSE1, Phase.PAUSE2, Phase.PAUSE3:
			_phase_duration = pause_duration
			_jitter_timer = 0.0  # force an immediate re-roll on this pause's first frame
			_start_honey_spread()  # fire-and-forget - see header comment
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

	# Each phase computes its own final position/rotation directly - the 3
	# PAUSE phases fold in both the deliberate rock (_pause_tilt()) and the
	# jitter (_pause_jitter(), envelope-faded so there's no seam at the
	# pause's own start/end) themselves; the 4 travel phases add ONLY the
	# spin_full_turns-turn spin (_spin_rate, radians/sec, constant angular
	# rate) on top of facing the direction of travel, using _phase_time
	# directly rather than t - TRAVEL3 has no fixed duration (t is pinned to
	# 1.0 the whole time it runs), so a t-based spin would never actually
	# turn during it, while a plain time * rate spin works the same way for
	# every leg regardless of whether that leg ever finishes. No jitter is
	# added during any travel phase - see the header comment.
	var pos: Vector2
	var rot: float

	match _phase:
		Phase.ENTRY:
			pos = _spawn_pos.lerp(_pause1_pos, t)
			rot = _facing_rotation_for(_dir3) + _phase_time * _spin_rate
		Phase.PAUSE1:
			var jitter1 := _pause_jitter(t, delta)
			pos = _pause1_pos + jitter1[0]
			rot = _facing_rotation_for(_dir1) + _pause_tilt(t) + jitter1[1]
		Phase.TRAVEL1:
			pos = _pause1_pos.lerp(_travel1_target, t)
			rot = _facing_rotation_for(_dir1) + _phase_time * _spin_rate
		Phase.PAUSE2:
			var jitter2 := _pause_jitter(t, delta)
			pos = _travel1_target + jitter2[0]
			rot = _facing_rotation_for(_dir2) + _pause_tilt(t) + jitter2[1]
		Phase.TRAVEL2:
			pos = _travel1_target.lerp(_travel2_target, t)
			rot = _facing_rotation_for(_dir2) + _phase_time * _spin_rate
		Phase.PAUSE3:
			var jitter3 := _pause_jitter(t, delta)
			pos = _travel2_target + jitter3[0]
			rot = _facing_rotation_for(_dir3) + _pause_tilt(t) + jitter3[1]
		Phase.TRAVEL3:
			# Closed-form on _phase_time (not an incremental += each frame) -
			# same reasoning as the spin above, keeps this a pure function of
			# elapsed time. (Now that jitter never touches a travel phase,
			# this no longer needs to guard against jitter compounding into
			# a random walk the way it did before - it's kept closed-form
			# anyway since it's simpler and costs nothing.)
			pos = _travel2_target + _dir3 * path_speed * _phase_time
			rot = _facing_rotation_for(_dir3) + _phase_time * _spin_rate

	_enemy.position = pos
	_enemy.rotation = rot

	if _phase == Phase.TRAVEL3:
		if _is_past_bottom_edge(pos):
			queue_free()  # reached the bottom edge - single pass, no reuse
		return

	if t >= 1.0:
		_advance_phase()


func _pause_tilt(t: float) -> float:
	"""The slow, deliberate side-to-side ROCK during a pause: a plain sine
	wave over `t` (0.0-1.0, how far through the pause), scaled so a WHOLE
	number of cycles fit the pause (see tilt_cycles) - that's what makes it
	exactly level at both t=0 and t=1, so there's no visual pop between this
	and whatever rotation the phase before/after it uses."""
	return sin(TAU * tilt_cycles * t) * deg_to_rad(tilt_amplitude_deg)


func _pause_jitter(t: float, delta: float) -> Array:
	"""The small, fast, RANDOMIZED buzz (position AND rotation) - like a
	bee - re-rolled every jitter_update_interval seconds via randf_range()
	rather than smoothly animated, so it reads as quick discrete twitches.
	PAUSE-ONLY: scaled by `envelope` (sin(PI*t), 0 at t=0/t=1, peak at
	t=0.5) so the twitching fades in and back out smoothly within the pause
	even though the underlying random values themselves jump around
	discontinuously - no seam into or out of the pause, and nothing to
	smooth at the travel phases on either side since jitter is simply never
	applied there at all. Returns [position offset, rotation offset]."""
	_jitter_timer -= delta
	if _jitter_timer <= 0.0:
		_jitter_offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * jitter_amplitude
		_jitter_rotation = randf_range(-1.0, 1.0) * deg_to_rad(jitter_rotation_amplitude_deg)
		_jitter_timer = jitter_update_interval

	var envelope: float = sin(PI * t)
	return [_jitter_offset * envelope, _jitter_rotation * envelope]


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


# ---------------------------------------------------------------------------
# HONEY GLOB FAN - see the header comment at the top of this file. Fired
# once every time a pause begins (from _enter_phase()), as a fire-and-forget
# coroutine - staggering the 3 shots doesn't need to block or interact with
# the movement state machine at all, since the enemy's position/rotation
# during the pause are entirely handled by _process()/_pause_tilt()/
# _pause_jitter() regardless of how far the shot sequence has gotten.
# ---------------------------------------------------------------------------

func _start_honey_spread() -> void:
	var angle: float = deg_to_rad(honey_spread_angle_deg)

	_fire_honey_glob(Vector2.DOWN.rotated(angle))    # 1st - clockwise of straight down
	await get_tree().create_timer(honey_shot_stagger).timeout

	_fire_honey_glob(Vector2.DOWN)                   # 2nd - straight down
	await get_tree().create_timer(honey_shot_stagger).timeout

	_fire_honey_glob(Vector2.DOWN.rotated(-angle))   # 3rd - counterclockwise of straight down


func _fire_honey_glob(direction: Vector2) -> void:
	if not is_instance_valid(self) or not is_instance_valid(_enemy) or not _enemy.is_alive:
		return
	var bullet := HONEY_GLOB_SCENE.instantiate()
	get_tree().root.add_child(bullet)
	bullet.start(_enemy.global_position, direction)
