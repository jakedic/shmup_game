# yellow_squad.gd
# Drives a squad of exactly squad_size YellowEnemy instances (see the
# `squad_size` export below - the level sets it per-squad, see
# BaseLevel.spawn_squad()) as one choreographed unit instead of each enemy
# acting independently. The squad travels in a straight line from start_pos
# to end_pos (typically just off one edge of the screen to just off another -
# see levels/squad_wave_level.gd's side+percent helper), pausing partway
# along that line to circle for a while before continuing on to end_pos. One
# pass, four steps, all built around a single shared reference point
# (_anchor) and a single shared rotation amount (_rotation_progress) that
# every member's position is computed from:
#
#     member position = _anchor + circle_radius * Vector2(cos(a), sin(a))
#     where a = that member's fixed _circle_offset (its permanent slot,
#           assigned once in _spawn_members()) + _rotation_progress
#           + _direction_rotation_offset (see below)
#
#   1. FALLING IN - the squad spawns together, already arranged in a
#                  regular polygon (a diamond/rhombus for the default
#                  squad_size=4, a triangle for 3, and so on) around
#                  _anchor, which starts at start_pos. _rotation_progress
#                  stays at 0 (the polygon doesn't spin yet) while _anchor
#                  travels straight down the start_pos->end_pos line at
#                  path_speed, wobbling side to side in a sine curve
#                  PERPENDICULAR to that line (see wave_amplitude/
#                  wave_frequency below - the same wobble used during step
#                  4's fall-away) that eases out to zero over the last
#                  wave_settle_distance px before reaching the circle spot
#                  (see circle_progress below). As _anchor gets within
#                  formation_transition_time's worth of travel from the
#                  circle spot, it smoothly hands off from pure translating to
#                  pure circling: its travel speed eases to 0 while
#                  _rotation_progress's rate eases up to circle_angular_speed,
#                  both by the same smooth S-curve, so there's no sudden
#                  jump in speed or direction at any point (see
#                  _advance_squad_transform()) - just one continuous motion
#                  that starts as a translating diamond and ends as a
#                  circling ring, arriving and starting to circle at the same
#                  instant for every surviving member (no arrival order to
#                  stagger).
#   2. IN FORMATION - every member circles the circle spot together at a
#                  constant circle_angular_speed, each permanently offset
#                  from the others by the angle it was assigned back in
#                  _spawn_members() (_circle_offset) - the same offsets that
#                  made up the diamond shape during step 1, just rotating
#                  now instead of translating. Holds for a FIXED
#                  circle_hold_interval seconds (always the same beat, not
#                  randomized - a per-squad export, see
#                  levels/squad_wave_level.gd's WAVES FORMAT comment for how
#                  to set it per squad in a level's wave table) once every
#                  survivor has arrived.
#   3. FALLING AWAY - the reverse of the hand-off in step 1: over the same
#                  formation_transition_time, the circling smoothly eases
#                  down to a stop while _anchor smoothly eases from
#                  motionless back up to full path_speed, continuing straight
#                  on toward end_pos - same S-curve, same continuity
#                  guarantee, just running backwards. Once that hand-off
#                  finishes, _rotation_progress is frozen for good - the
#                  polygon stops spinning and keeps whatever orientation it
#                  happened to have at that instant - and the WHOLE squad
#                  travels away together, still in its rhombus/polygon shape,
#                  wobbling as one shared unit exactly like step 1 (see
#                  _apply_exit_wobble()), instead of peeling off the circle
#                  one member at a time.
#   4. LOOP+EXIT - since the whole squad travels away together now, they all
#                  cross the halfway point of the start_pos->end_pos line at
#                  essentially the same moment, which is when EVERY member
#                  loops-the-loop at once (see _group_loop_triggered), going
#                  invincible and flashing to signal that. After its loop,
#                  each member fires its fast bullet a short beat later (see
#                  fire_delay_after_loop), eases its facing back to pointing
#                  along the line over loop_recovery_time, and - now flying
#                  solo, its own fresh sine wobble no longer tied to the
#                  group (see _process_solo_fall()) - keeps traveling until
#                  it's off the edge of the screen and is removed. Once every
#                  member is gone (killed, or departed and exited), the whole
#                  squad frees itself - no repeat cycle.
#
# DIRECTION: unlike an earlier version of this file (which only ever fell
# straight down a fixed lane_x), a squad can now travel along ANY line from
# start_pos to end_pos - top to bottom, side to side, or diagonally. This
# works the same way enemies/yellow_solo.gd generalized a single enemy's
# straight-line crossing: _direction (start_pos->end_pos, normalized) and
# _perp (_direction rotated 90 degrees, the wobble's axis) are computed once
# in _ready() and used everywhere translation/wobble would otherwise have
# assumed straight down. The formation's fixed polygon shape, the departure
# loop, and the post-loop facing recovery are all rotated by the same
# _direction_rotation_offset (direction's angle minus straight-down's angle)
# so the whole squad reads as one continuous, correctly-oriented motion no
# matter which way it's actually traveling - see enemy_yellow.gd's
# _update_facing() for the rotation convention this lines up with.
#
# Why a rigid formation shape instead of one member at a time (both ways):
# entering (or leaving) one member at a time needed every member's circle
# slot to line up with exactly when it individually arrived (or to peel off
# only once its own rotation happened to cross a specific point), which
# forced a tight mathematical relationship between path_speed, how fast the
# circle turned, and the desired gap between members (see the
# yellow_squad_circle_first_rework project memory for the full history of
# chasing that trade-off, and why it kept coming back). Since the whole
# squad now arrives AND leaves at once, every member's circle slot
# (_circle_offset) is just a plain geometric fact assigned directly up front
# (i * TAU/squad_size), never touched again - not something that depends on
# path_speed or circle_angular_speed at all. That's what makes path_speed
# and circle_angular_speed two completely independent, freely-settable
# exports, with nothing derived from either one. It's also what makes the
# group loop trigger (step 4 above) a single squad-level distance check
# (_traveled past halfway) instead of checking every member's position
# individually - since they're all rigidly locked together until they loop,
# they're already guaranteed to cross halfway within a hair of each other.
#
# The same enemy instances are used for the whole pass - nothing is ever
# respawned as a fresh instance, so health and status effects carry over
# naturally. A member that dies at any point is simply excluded from every
# later step (see _alive_indices()) and never reappears - if it dies before
# the squad enters formation, the survivors' angular slots are NOT
# renumbered, so the formation/circle simply shows a gap where it would have
# been instead of closing ranks.
#
# A level can spawn several independent YellowSquad instances at once (see
# levels/yellow_level.gd) - each one runs entirely on its own, with its own
# start_pos/end_pos/circle_progress. A few knobs make multi-squad waves easy
# to stage:
#   - start_delay holds a squad motionless (still spawned, just parked at
#     start_pos) for that many seconds before it starts traveling toward its
#     formation - lets a level stagger several squads so they settle into
#     formation one after another instead of all at once.
#   - circle_progress (0.0-1.0) is how far along the start_pos->end_pos line
#     the squad stops to circle - 0.0 circles immediately at start_pos, 1.0
#     would circle right at end_pos (never actually departing), 0.5 circles
#     exactly halfway. Defaults to 0.5.
#   - diagonal_vx adds a constant drift (in the _perp direction, i.e.
#     sideways relative to the direction of travel) to the center of the sine
#     weave while a member is traveling solo after its own loop (step 4
#     above), for a curving exit path instead of a straight one. Zero (the
#     default) keeps the weave centered on the line it exited the loop on.
#   - wave_amplitude/wave_frequency shape the side-to-side (perpendicular to
#     the direction of travel) sine wobble the squad does whenever it's
#     translating and NOT circling (both step 1's group entrance and step
#     3's group departure). Set wave_amplitude to 0 to travel in a plain
#     straight line instead.
#     wave_settle_distance is how many px of travel, right next to the
#     circle spot, the wobble eases across instead of switching on/off
#     abruptly - fading OUT over the last wave_settle_distance px before
#     reaching the circle spot in step 1, and fading back IN over the first
#     wave_settle_distance px of leaving it in step 3.
#   - formation_transition_time is how many seconds the hand-off between
#     translating and circling takes, in EITHER direction (step 1's arrival
#     and step 3's departure use the same duration) - the whole point of this
#     export, see "Why a rigid formation shape" above and
#     _advance_squad_transform() below for how it's used to keep both
#     hand-offs jump-free.
extends Node2D
class_name YellowSquad

# Relayed from each member's own `died` signal so the level can still score
# kills the same way it does for grid-spawned enemies - BaseLevel.spawn_squad()
# connects this straight to BaseLevel._on_enemy_died() for every squad it
# creates. Only fires for an actual KILL - an escaped member (see
# member_gone below) never emits this, so it never scores.
signal enemy_died(value: int)

# Fires once for every member that's permanently gone, whether it was
# actually killed OR it escaped off the edge of the screen without being
# killed (see _process_solo_fall()) - unlike enemy_died above, which only
# fires on a kill. Exists for callers that need "is this squad finished"
# regardless of how each member left, without that scoring implication -
# see levels/squad_wave_level.gd's _on_boss_retreat_started(), which wires
# this (not enemy_died) to BaseLevel.resolve_boss_add_death(). Before this
# signal existed, a boss fight would stall forever if the player let an add
# enemy fly off the bottom of the screen instead of killing it, since
# resolve_boss_add_death() was only ever being told about kills.
signal member_gone

@export var enemy_scene: PackedScene
@export var squad_size: int = 4                # how many enemies fly in this squad
@export var start_pos: Vector2 = Vector2.ZERO  # where the squad spawns and begins traveling - typically just off one edge of the screen
@export var end_pos: Vector2 = Vector2.ZERO    # where a departed member is removed once it travels off it - typically just off another edge
@export var circle_progress: float = 0.5       # how far along the start_pos->end_pos line (0.0-1.0) the squad stops to circle - see the header comment
@export var path_speed: float = 160.0          # px/s while the formation is translating (entering, and departing after formation) - independent of circle_angular_speed, see the header comment
@export var circle_angular_speed: float = 3.5  # rad/s while circling - independent of path_speed, see the header comment
@export var formation_transition_time: float = 0.5  # seconds the hand-off between translating and circling takes, in and out - see the header comment
@export var wave_amplitude: float = 24.0       # how far side to side (perpendicular to the line of travel) the formation wobbles while translating (steps 1 and 3), px - 0 travels in a plain straight line
@export var wave_frequency: float = 3.0        # how fast that side-to-side wobble oscillates
@export var wave_settle_distance: float = 24.0 # px of travel, right next to the circle spot, over which the wobble eases out (step 1) or back in (step 3) instead of switching abruptly
@export var loop_radius: float = 26.0          # size of the departure loop, px
@export var loop_speed_multiplier: float = 1.4  # how much faster than plain path_speed the loop itself turns
@export var fire_delay_after_loop: float = 0.15  # seconds after a member's loop ends before it actually fires
@export var loop_recovery_time: float = 0.3    # seconds to ease facing back to normal after a loop
@export var circle_radius: float = 28.0        # radius of the circle formation, px - also the radius of the polygon members fall in during steps 1 and 3
@export var circle_hold_interval: float = 6.0  # fixed seconds THIS squad holds formation before departing - a per-squad setting; see levels/squad_wave_level.gd's WAVES FORMAT comment for the optional per-squad-entry `circle_hold_interval` field that overrides this
@export var start_delay: float = 0.0           # seconds this squad stays parked before traveling toward its formation
@export var diagonal_vx: float = 0.0           # px/s of sideways (perpendicular) drift while traveling solo after a member's own loop - 0 keeps that member on the line it exited the loop on

enum Phase { ENTERING, TRANSITIONING_IN, CIRCLING, TRANSITIONING_OUT, EXITING }

var _members: Array = []          # YellowEnemy instances, fixed slots (index never reused)
var _circle_offset: Array = []    # per-member: fixed angular offset (radians), assigned once in _spawn_members() as i * TAU/squad_size - the polygon's shape while falling, and each member's fixed slot while circling
var _departed: Array = []         # per-member: true once the WHOLE squad has finished traveling away from the circle (set all-at-once, see _advance_squad_transform()) - gates the group loop trigger below
var _looping: Array = []          # per-member: true while mid-loop
var _looped: Array = []           # per-member: true once it has used its one loop
var _loop_time: Array = []        # per-member: seconds into the current loop
var _loop_start_pos: Array = []   # per-member: position captured at the moment its loop began
var _loop_ended_at: Array = []    # per-member: _squad_time at which its loop finished, for loop_recovery_time
var _wave_time: Array = []        # per-member: seconds into its solo post-loop travel (see _process_solo_fall()) - unused before that, since steps 1 and 3 wobble the shared _anchor instead
var _fall_origin: Array = []      # per-member: position at the instant its loop ended - the origin _fall_traveled/_fall_perp_drift are measured from, see _process_solo_fall()
var _fall_traveled: Array = []    # per-member: px traveled along _direction since its loop ended
var _fall_perp_drift: Array = []  # per-member: px drifted along _perp (via diagonal_vx) since its loop ended

var _squad_time: float = 0.0
var _loop_duration: float = 1.0

var _direction: Vector2 = Vector2.DOWN    # start_pos -> end_pos, normalized - fixed for the whole squad's pass
var _perp: Vector2 = Vector2.RIGHT        # _direction rotated 90 degrees - the wobble's axis
var _direction_rotation_offset: float = 0.0  # _direction's angle minus straight-down's angle - see the header comment's DIRECTION section
var _total_length: float = 0.0            # start_pos -> end_pos distance
var _circle_travel: float = 0.0           # px of travel (along _direction, from start_pos) at which the squad circles - _total_length * circle_progress

var _phase: Phase = Phase.ENTERING
var _anchor: Vector2 = Vector2.ZERO       # the shared point every non-solo, non-looping member's position is built from - see the header comment's position formula
var _rotation_progress: float = 0.0       # added to every member's _circle_offset - advances only while circling (fully during CIRCLING, ramping during the two TRANSITIONING_* phases, frozen during ENTERING/EXITING)
var _traveled: float = 0.0                # px translated along _direction so far (does NOT advance while purely circling) - _anchor is derived from this plus wobble, see _apply_entry_wobble()/_apply_exit_wobble()
var _transition_start_travel: float = 0.0 # the _traveled at which ENTERING hands off into TRANSITIONING_IN - set in _ready() so the hand-off finishes exactly at _circle_travel, see _ready()
var _transition_elapsed: float = 0.0      # seconds into the current TRANSITIONING_* phase
var _entry_wave_time: float = 0.0         # shared wobble clock for step 1 (ENTERING + TRANSITIONING_IN)
var _exit_wave_time: float = 0.0          # shared wobble clock for step 3 (TRANSITIONING_OUT + EXITING), reset to 0 when TRANSITIONING_OUT begins
var _circle_hold_active: bool = false
var _circle_hold_until: float = 0.0
var _group_loop_triggered: bool = false   # true once the departed squad has traveled past halfway of the whole start_pos->end_pos line - see _process_formation()
var _screensize: Vector2
var _wait_time: float = 0.0  # real time since _ready(), independent of _squad_time - see start_delay


func _ready() -> void:
	_screensize = get_viewport_rect().size

	var delta_pos: Vector2 = end_pos - start_pos
	_total_length = delta_pos.length()
	if _total_length > 0.0:
		_direction = delta_pos / _total_length
	_perp = Vector2(-_direction.y, _direction.x)
	_direction_rotation_offset = _direction.angle() - Vector2.DOWN.angle()
	_circle_travel = _total_length * clamp(circle_progress, 0.0, 1.0)

	_spawn_members()

	# A smooth S-curve (see _smoothstep01()) blended over formation_transition_time
	# seconds averages exactly half its full rate across that time (same as a
	# plain linear ramp would - smoothstep is symmetric about its midpoint),
	# so ENTERING's constant-speed leg needs to stop exactly
	# path_speed*formation_transition_time/2 px of travel short of
	# _circle_travel to leave TRANSITIONING_IN covering precisely the rest of
	# the distance, arriving dead-on when its own timer runs out - no drift,
	# no separate "close enough" snap needed.
	var transition_travel: float = path_speed * formation_transition_time / 2.0
	_transition_start_travel = max(_circle_travel - transition_travel, 0.0)

	# Base linear speed through the loop matches the straight-line travel -
	# the loop is a circle of radius loop_radius (see _advance_member_loop()),
	# so its circumference divided by path_speed gives the duration that
	# keeps tangential speed constant - then loop_speed_multiplier nudges it a
	# bit faster than that on top.
	_loop_duration = (TAU * loop_radius / path_speed) / loop_speed_multiplier


func _spawn_members() -> void:
	# Every member is placed at its permanent angular slot around a shared
	# anchor that starts at start_pos - spread into a regular polygon (a
	# diamond for the default squad_size=4) from the very first frame,
	# instead of lined up one after another. The polygon's fixed slots
	# (_circle_offset) are rotated by _direction_rotation_offset so the shape
	# reads as facing the actual direction of travel instead of always
	# assuming a straight-down fall - see the header comment's DIRECTION
	# section.
	_anchor = start_pos
	for i in range(squad_size):
		var theta: float = i * TAU / squad_size
		var e = enemy_scene.instantiate()
		add_child(e)
		e.squad_controlled = true    # opt out of base_enemy's own movement/boundary logic
		e.follow_anchor = false
		e.follow_anchor_enabled = false
		e.can_dive = false           # this squad's choreography replaces the random zig-zag/loop dive
		e.can_shoot = false          # squad fires on cue (after its departure loop), not on ShootTimer
		var angle: float = theta + _direction_rotation_offset
		e.position = _anchor + Vector2(cos(angle), sin(angle)) * circle_radius
		e.rotation = _direction_rotation_offset  # face along the line of travel from the very first frame, not straight down
		if "last_position" in e:
			e.last_position = e.position  # avoid a bogus facing spike on the first movement frame
		if e.has_method("_stop_idle_rock"):
			e._stop_idle_rock()  # keep them visually still until they're actually idle-circling
		if e.has_signal("died"):
			e.died.connect(_on_member_died)
		_members.append(e)
		_circle_offset.append(theta)
		_departed.append(false)
		_looping.append(false)
		_looped.append(false)
		_loop_time.append(0.0)
		_loop_start_pos.append(Vector2.ZERO)
		_loop_ended_at.append(0.0)
		_wave_time.append(0.0)
		_fall_origin.append(e.position)
		_fall_traveled.append(0.0)
		_fall_perp_drift.append(0.0)


func _on_member_died(value: int) -> void:
	enemy_died.emit(value)
	member_gone.emit()


func _alive_indices() -> Array:
	var result: Array = []
	for i in range(_members.size()):
		if is_instance_valid(_members[i]) and _members[i].is_alive:
			result.append(i)
	return result


func _update_member_facing(index: int, delta: float) -> void:
	"""Point member `index` the way it actually just moved this frame, using
	YellowEnemy's own _update_facing() (same rotation math the old per-enemy
	dive used) so it stays consistent whether the enemy is translating,
	mid-loop, or circling."""
	var e = _members[index]
	if is_instance_valid(e) and e.has_method("_update_facing"):
		e._update_facing(delta)


func _smoothstep01(t: float) -> float:
	"""Classic smoothstep, clamped to t in [0, 1]: eases in and out with
	zero velocity AND zero acceleration at both ends, so blending anything
	by this factor (instead of just using t directly) never introduces a
	sudden kink in speed or in how quickly that speed is changing - see
	_advance_squad_transform()'s two TRANSITIONING_* phases."""
	t = clamp(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _is_offscreen(pos: Vector2) -> bool:
	"""True once `pos` is far enough outside the viewport that it's safe to
	remove - used for a departed member's post-loop travel (see
	_process_solo_fall()), which can now head off ANY edge of the screen
	rather than only ever falling out the bottom."""
	var margin: float = 20.0
	return pos.x < -margin or pos.x > _screensize.x + margin or pos.y < -margin or pos.y > _screensize.y + margin


func _process(delta: float) -> void:
	_wait_time += delta
	if _wait_time < start_delay:
		return  # still parked at start_pos - see start_delay

	_squad_time += delta
	_process_formation(delta)
	_check_squad_finished()


func _process_formation(delta: float) -> void:
	var alive: Array = _alive_indices()
	_advance_squad_transform(delta)

	# Collective loop trigger - the instant the departed squad has traveled
	# past the halfway point of the whole start_pos->end_pos line, every
	# member loops together, from wherever it currently is (see
	# _start_member_loop() below). Since the whole squad travels away as one
	# rigid shape (step 3), this is a single squad-level distance check
	# rather than checking every member's position - see the header
	# comment's "Why a rigid formation shape" section.
	if not _group_loop_triggered and _phase == Phase.EXITING and _traveled >= _total_length * 0.5:
		_group_loop_triggered = true

	for i in alive:
		var e = _members[i]

		if _looping[i]:
			_advance_member_loop(i, e, delta)
			continue

		if _looped[i]:
			_process_solo_fall(i, e, delta)
			continue

		if _departed[i] and _group_loop_triggered:
			_start_member_loop(i, e)
			continue

		# Still part of the shared rigid formation - entering, circling, or
		# departing, whichever _advance_squad_transform() just updated
		# _anchor/_rotation_progress for.
		var angle: float = _circle_offset[i] + _rotation_progress + _direction_rotation_offset
		e.position = _anchor + Vector2(cos(angle), sin(angle)) * circle_radius
		_update_member_facing(i, delta)


func _advance_squad_transform(delta: float) -> void:
	"""Updates the two values every non-solo, non-looping member's position
	is built from (_anchor, _rotation_progress) according to the current
	phase - see the header comment's steps 1-3 and the position formula at
	the very top of this file. _traveled is the scalar distance translated
	along _direction so far; _anchor itself is derived from it (plus
	perpendicular wobble) in _apply_entry_wobble()/_apply_exit_wobble(). The
	two TRANSITIONING_* phases are the fluid hand-off requested on top of the
	plain translate/circle/translate design: each blends _traveled's rate of
	change and _rotation_progress's spin rate in opposite directions, by the
	same smooth factor, over formation_transition_time seconds - so at every
	instant, the combined motion is a weighted mix of "purely translating"
	and "purely circling" rather than an instant swap between the two, and
	the blend factor itself starts and ends at zero rate of change (see
	_smoothstep01()), so neither the speed nor the direction of motion ever
	jumps or kinks at a phase boundary."""
	match _phase:
		Phase.ENTERING:
			_traveled += path_speed * delta
			_entry_wave_time += delta
			_apply_entry_wobble()
			if _traveled >= _transition_start_travel:
				_phase = Phase.TRANSITIONING_IN
				_transition_elapsed = 0.0

		Phase.TRANSITIONING_IN:
			_transition_elapsed += delta
			var blend: float = _smoothstep01(_transition_elapsed / formation_transition_time)
			_traveled += path_speed * (1.0 - blend) * delta
			_rotation_progress += circle_angular_speed * blend * delta
			_entry_wave_time += delta
			_apply_entry_wobble()
			if _transition_elapsed >= formation_transition_time:
				_phase = Phase.CIRCLING
				_traveled = _circle_travel
				_anchor = start_pos + _direction * _traveled  # snap - erases any tiny residual float drift, matching every earlier pass's "snap cleanly onto the circle" precedent
				_circle_hold_active = false

		Phase.CIRCLING:
			_rotation_progress += circle_angular_speed * delta
			if not _circle_hold_active:
				_circle_hold_active = true
				_circle_hold_until = _squad_time + circle_hold_interval
			elif _squad_time >= _circle_hold_until:
				_phase = Phase.TRANSITIONING_OUT
				_transition_elapsed = 0.0
				_exit_wave_time = 0.0

		Phase.TRANSITIONING_OUT:
			_transition_elapsed += delta
			# Mirrors TRANSITIONING_IN exactly, just running backwards - the
			# blend starts at 1 (fully circling) and eases to 0 (fully
			# translating).
			var blend: float = 1.0 - _smoothstep01(_transition_elapsed / formation_transition_time)
			_traveled += path_speed * (1.0 - blend) * delta
			_rotation_progress += circle_angular_speed * blend * delta
			_exit_wave_time += delta
			_apply_exit_wobble()
			if _transition_elapsed >= formation_transition_time:
				_phase = Phase.EXITING
				# The polygon stops spinning right here, permanently, at
				# whatever orientation it happened to reach - and the whole
				# surviving squad becomes "departed" together, see the
				# header comment's step 3/4 and _process_formation()'s
				# group loop trigger above.
				for i in _alive_indices():
					_departed[i] = true

		Phase.EXITING:
			_traveled += path_speed * delta
			_exit_wave_time += delta
			_apply_exit_wobble()


func _apply_entry_wobble() -> void:
	"""Derives _anchor for step 1 from _traveled plus a perpendicular (_perp)
	wobble, fading OUT to 0 over the last wave_settle_distance px before
	_traveled reaches _circle_travel - see wave_settle_distance's doc
	comment."""
	var remaining: float = _circle_travel - _traveled
	var settle_t: float = 1.0
	if wave_settle_distance > 0.0:
		settle_t = clamp(remaining / wave_settle_distance, 0.0, 1.0)
	var wobble: float = sin(_entry_wave_time * wave_frequency) * wave_amplitude * settle_t
	_anchor = start_pos + _direction * _traveled + _perp * wobble


func _apply_exit_wobble() -> void:
	"""Mirrors _apply_entry_wobble() for step 3 - fading IN from 0 over the
	first wave_settle_distance px of travel past _circle_travel, instead of
	switching the wobble on abruptly the instant the squad starts departing."""
	var traveled_since_circle: float = _traveled - _circle_travel
	var settle_t: float = 1.0
	if wave_settle_distance > 0.0:
		settle_t = clamp(traveled_since_circle / wave_settle_distance, 0.0, 1.0)
	var wobble: float = sin(_exit_wave_time * wave_frequency) * wave_amplitude * settle_t
	_anchor = start_pos + _direction * _traveled + _perp * wobble


func _process_solo_fall(i: int, e, delta: float) -> void:
	"""Step 4's travel, once member `i`'s own loop has finished - travels
	independently from here on, weaving its own fresh sine wobble (own
	_wave_time/_fall_perp_drift, reset the instant the loop ended - see
	_advance_member_loop()) instead of the shared group wobble steps 1 and 3
	use, optionally drifting sideways (perpendicular to _direction) via
	diagonal_vx, until it's off the edge of the screen. Position is built as
	origin + traveled-along-_direction + (drift+wobble)-along-_perp, the same
	"leg origin + scalar traveled distance + perpendicular wobble"
	decomposition _apply_entry_wobble()/_apply_exit_wobble() use for the
	shared _anchor."""
	_fall_traveled[i] += path_speed * delta
	_fall_perp_drift[i] += diagonal_vx * delta
	_wave_time[i] += delta
	var wobble: float = sin(_wave_time[i] * wave_frequency) * wave_amplitude
	e.position = _fall_origin[i] + _direction * _fall_traveled[i] + _perp * (_fall_perp_drift[i] + wobble)

	if _squad_time < _loop_ended_at[i] + loop_recovery_time:
		# The facing-recovery tween (see _start_facing_recovery()) owns
		# rotation right now - just keep last_position in sync so
		# velocity-based facing resumes cleanly (as a single frame's delta,
		# not several frames' worth at once) the moment the tween's done,
		# instead of fighting it every frame in between.
		if "last_position" in e:
			e.last_position = e.position
	else:
		_update_member_facing(i, delta)

	if _is_offscreen(e.position):
		# Single pass - no reuse, so just remove it once it's off-screen.
		# member_gone fires here (unlike enemy_died) because this member was
		# never killed - see member_gone's doc comment above.
		member_gone.emit()
		e.queue_free()


func _start_member_loop(i: int, e) -> void:
	_looping[i] = true
	_loop_time[i] = 0.0
	_loop_start_pos[i] = e.position
	if e.has_method("set_invincible"):
		e.set_invincible(true)


func _advance_member_loop(i: int, e, delta: float) -> void:
	_loop_time[i] += delta
	var t: float = _loop_time[i] / _loop_duration
	# Clamp to exactly 1.0 for the frame that finishes the loop instead of
	# skipping straight to the end-of-loop handling - without this, the loop
	# always cut off a few degrees short of the full 360.
	var clamped_t: float = min(t, 1.0)

	# Circle of radius loop_radius, parameterized so the TANGENT at angle 0
	# (and so also at angle TAU, where it closes back up) points straight
	# down in its own local frame - then rotated by _direction_rotation_offset
	# to match THIS squad's actual direction of travel, since a squad isn't
	# always falling straight down anymore. That keeps the tangent at the
	# seam matching the velocity direction every member actually had right
	# before the loop started (and will have right after it ends), so the
	# hand-off in and out of the loop reads as one continuous turn - same
	# technique as enemies/yellow_solo.gd's _advance_loop().
	var angle: float = clamped_t * TAU
	var base_offset := Vector2(cos(angle) - 1.0, sin(angle)) * loop_radius
	e.position = _loop_start_pos[i] + base_offset.rotated(_direction_rotation_offset)
	_update_member_facing(i, delta)

	if t >= 1.0:
		_looping[i] = false
		_looped[i] = true
		_loop_ended_at[i] = _squad_time
		_wave_time[i] = 0.0           # fresh wobble phase for the post-loop travel, starting at zero offset
		_fall_origin[i] = e.position  # centered on wherever the loop actually ended, no jump
		_fall_traveled[i] = 0.0
		_fall_perp_drift[i] = 0.0
		_start_facing_recovery(e)
		_fire_after_loop(e)


func _start_facing_recovery(e) -> void:
	"""Ease back to facing along the line of travel instead of snapping to
	it. The loop's exit velocity points sideways-ish for an instant (it's
	tangent to the loop, not aligned with the resumed straight travel), which
	would otherwise cause a one-frame facing pop the moment normal
	velocity-based facing (_update_member_facing) took back over."""
	var tw = e.create_tween()
	tw.tween_property(e, "rotation", _direction_rotation_offset, loop_recovery_time)


func _fire_after_loop(e) -> void:
	"""Wait a short beat after the loop's own animation completes before
	actually firing, so the shot clearly reads as happening AFTER the loop
	rather than the instant the loop's math resets back to its start
	position. Invincibility drops at the same moment the shot fires."""
	await get_tree().create_timer(fire_delay_after_loop).timeout
	if not is_instance_valid(e) or not e.is_alive:
		return
	if e.has_method("shoot_single"):
		e.shoot_single()
	if e.has_method("set_invincible"):
		e.set_invincible(false)


func _check_squad_finished() -> void:
	"""Once every member this squad ever spawned is gone - killed, or
	departed and traveled off the edge of the screen (see
	_process_solo_fall()) - there's nothing left for this node to do, so
	free it. No repeat cycle."""
	for e in _members:
		if is_instance_valid(e):
			return
	queue_free()
