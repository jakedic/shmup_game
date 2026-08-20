# yellow_squad.gd
# Drives a squad of exactly SQUAD_SIZE YellowEnemy instances as one
# choreographed unit instead of each enemy acting independently. It's a
# repeating cycle:
#
#   1. ENTER   - the 4 enemies fall in a straight line down a shared lane,
#                one after another (staggered by stagger_time).
#   2. LOOPING - once the lead (furthest-along) alive member reaches the
#                vertical midpoint of the screen, EVERY still-alive member
#                loops-the-loop at once (from wherever it currently is),
#                going invincible and flashing to signal that. The loop
#                always completes the full 360 degrees (see _process_loop())
#                and travels at the SAME linear speed as the straight-line
#                descent (duration is derived from path_speed/loop_radius),
#                not visibly faster. A short fire_delay_after_loop after the
#                loop finishes, each member fires its fast bullet and
#                immediately loses invincibility, while easing (not
#                snapping) its facing back to straight-down over
#                loop_recovery_time - see _start_facing_recovery().
#   3. EXIT    - survivors resume falling until they leave the bottom of the
#                screen.
#   4. HOME    - survivors re-enter from the top, all sharing a lane aligned
#                with the RIGHTMOST point of the idle circle (not its
#                center), staggered by stagger_time same as phase 1. The
#                instant an individual member reaches that rightmost point
#                (continuous position, no jump), it joins the circle there,
#                permanently fixed at whatever angular offset it entered
#                with (see _join_circle() - no easing/smoothing, same "just
#                physics" character as leaving). Once every survivor has
#                joined, the squad holds the circle formation for a random
#                circle_hold_min-circle_hold_max seconds. It then leaves the
#                same way it joined, in reverse: each member keeps orbiting
#                normally until ITS OWN ongoing rotation next carries it
#                through the rightmost point, at which instant it peels off
#                and starts falling straight down from there - continuous
#                position again, no jump - which naturally staggers the
#                departures in join order (first in, first out) without any
#                extra timer. Once every survivor has departed, the squad
#                re-enters Phase.ENTER and the whole cycle repeats.
#
# Idle spacing: circle_angular_speed is derived from stagger_time (see
# _ready()) so that the circle turns exactly one SQUAD_SIZE-th of a full
# revolution in the time between two members starting their fall. Combined
# with every member entering at the same rightmost point and keeping
# whatever offset it entered with, that makes each successive joiner land
# exactly TAU/SQUAD_SIZE behind the previous one automatically - equidistant
# spacing falls straight out of the timing, the same way departures fall
# straight out of the (now-equidistant) spacing. If a member dies, the
# survivors' offsets are never touched or recalculated, so they simply keep
# their original spacing (leaving a gap) instead of closing ranks.
#
# The same enemy instances are used for the whole sequence, cycle after
# cycle - nothing is ever respawned as a fresh instance, so health, status
# effects, and death all carry over naturally. A member that dies at any
# point is simply excluded from every later step (see _alive_indices()) and
# never reappears.
#
# A level can spawn several independent YellowSquad instances at once (see
# levels/yellow_level.gd) - each one runs entirely on its own, with its own
# lane_x/circle_center. Two knobs make multi-squad waves easy to stage:
#   - start_delay holds a squad motionless (still spawned, just parked at
#     its off-screen entry position) for that many seconds before its very
#     first Phase.ENTER starts moving - lets a level stagger several squads
#     so they descend one after another instead of all at once.
#   - diagonal_vx adds a constant sideways drift during Phase.ENTER (both
#     the initial descent and any later repeat dive) on top of the normal
#     straight-down fall, for a diagonal attack path instead of a vertical
#     one. Zero (the default) keeps the dive perfectly vertical.
extends Node2D
class_name YellowSquad

# Relayed from each member's own `died` signal so the level can still score
# kills the same way it does for grid-spawned enemies - see
# levels/yellow_level.gd, which connects this straight to
# BaseLevel._on_enemy_died().
signal enemy_died(value: int)

const SQUAD_SIZE := 4

@export var enemy_scene: PackedScene
@export var lane_x: float = 120.0              # shared x the squad's attack dive travels down
@export var path_speed: float = 80.0           # px/s while travelling any straight path
@export var stagger_time: float = 0.45         # seconds between each member starting to fall
@export var loop_radius: float = 26.0          # size of the loop, px
@export var loop_speed_multiplier: float = 1.4  # how much faster than plain path_speed the loop itself turns
@export var fire_delay_after_loop: float = 0.15  # seconds after a member's loop ends before it actually fires
@export var loop_recovery_time: float = 0.3    # seconds to ease facing back to normal after a loop
@export var circle_center: Vector2 = Vector2.ZERO  # idle formation point - defaults near lane_x if left zero
@export var circle_radius: float = 28.0        # idle formation radius, px
@export var circle_angular_speed: float = 0.75 # radians/sec while idle-circling - overwritten in _ready(), see there
@export var circle_hold_min: float = 5.0       # seconds the squad holds the circle before diving again
@export var circle_hold_max: float = 10.0
@export var start_delay: float = 0.0           # seconds this squad stays parked before its first descent starts
@export var diagonal_vx: float = 0.0           # px/s of sideways drift during Phase.ENTER - 0 stays vertical

enum Phase { ENTER, LOOPING, EXIT, HOME }

var _members: Array = []          # YellowEnemy instances, fixed slots (index never reused)
var _start_time: Array = []       # per-member: phase-relative time at which it starts falling
var _exited: Array = []           # per-member: true once it has fallen off the bottom this cycle
var _loop_start_pos: Array = []   # per-member: position captured at the moment its loop began
var _circling: Array = []         # per-member: true once it has joined the idle circle this cycle
var _circle_offset: Array = []    # per-member: current angular offset from the shared _circle_theta
var _departed: Array = []         # per-member: true once it's peeled off the circle and is falling again

var _phase: int = Phase.ENTER
var _squad_time: float = 0.0
var _phase_started_at: float = 0.0  # _squad_time at which the current phase's own stagger clock started
var _loop_time: float = 0.0
var _loop_duration: float = 1.0
var _circle_theta: float = 0.0
var _circle_hold_active: bool = false
var _circle_hold_until: float = 0.0
var _departure_requested: bool = false
var _screensize: Vector2
var _wait_time: float = 0.0  # real time since _ready(), independent of _squad_time - see start_delay


func _ready() -> void:
	_screensize = get_viewport_rect().size
	if circle_center == Vector2.ZERO:
		circle_center = Vector2(lane_x, 70.0)
	_spawn_members()

	# Base linear speed through the loop matches the straight-line descent -
	# the loop is a circle of radius loop_radius (see _process_loop()), so
	# its circumference divided by path_speed gives the duration that keeps
	# tangential speed constant - then loop_speed_multiplier nudges it a bit
	# faster than that on top.
	_loop_duration = (TAU * loop_radius / path_speed) / loop_speed_multiplier

	# Derived, not hand-tuned: with every member entering the circle at the
	# same rightmost point and keeping whatever offset it entered with (see
	# _join_circle()), this is the rotation speed that makes the circle turn
	# exactly one quarter-turn (for SQUAD_SIZE=4) in the stagger_time gap
	# between two members starting their fall - so each successive joiner's
	# offset naturally lands one slot behind the last, equidistant, with no
	# separate easing/smoothing step needed.
	circle_angular_speed = (TAU / SQUAD_SIZE) / stagger_time


func _spawn_members() -> void:
	for i in range(SQUAD_SIZE):
		var e = enemy_scene.instantiate()
		add_child(e)
		e.squad_controlled = true    # opt out of base_enemy's own movement/boundary logic
		e.follow_anchor = false
		e.follow_anchor_enabled = false
		e.can_dive = false           # this squad's choreography replaces the random zig-zag/loop dive
		e.can_shoot = false          # squad fires on cue (_end_loop), not on ShootTimer
		e.position = Vector2(lane_x, -16.0)
		e.rotation = 0.0
		if "last_position" in e:
			e.last_position = e.position  # avoid a bogus facing spike on the first movement frame
		if e.has_method("_stop_idle_rock"):
			e._stop_idle_rock()  # keep them visually still until they're actually idle-circling
		if e.has_signal("died"):
			e.died.connect(_on_member_died)
		_members.append(e)
		_start_time.append(i * stagger_time)
		_exited.append(false)
		_loop_start_pos.append(Vector2.ZERO)
		_circling.append(false)
		_circle_offset.append(0.0)
		_departed.append(false)


func _on_member_died(value: int) -> void:
	enemy_died.emit(value)


func _alive_indices() -> Array:
	var result: Array = []
	for i in range(_members.size()):
		if is_instance_valid(_members[i]) and _members[i].is_alive:
			result.append(i)
	return result


func _update_member_facing(index: int, delta: float) -> void:
	"""Point member `index` the way it actually just moved this frame, using
	YellowEnemy's own _update_facing() (same rotation math the old per-enemy
	dive used) so it stays consistent whether the enemy is falling straight
	down, mid-loop, or orbiting the idle-circle point."""
	var e = _members[index]
	if is_instance_valid(e) and e.has_method("_update_facing"):
		e._update_facing(delta)


func _process(delta: float) -> void:
	_wait_time += delta
	if _wait_time < start_delay:
		return  # still parked at the spawn position - see start_delay

	_squad_time += delta
	match _phase:
		Phase.ENTER:
			_process_enter(delta)
		Phase.LOOPING:
			_process_loop(delta)
		Phase.EXIT:
			_process_exit(delta)
		Phase.HOME:
			_process_home(delta)


func _process_enter(delta: float) -> void:
	var halfway_y: float = _screensize.y / 2.0
	var lead_reached_halfway := false

	for i in _alive_indices():
		if _squad_time < _phase_started_at + _start_time[i]:
			continue
		_members[i].position.y += path_speed * delta
		if diagonal_vx != 0.0:
			_members[i].position.x += diagonal_vx * delta
			_members[i].position.x = clamp(_members[i].position.x, 8.0, _screensize.x - 8.0)
		_update_member_facing(i, delta)
		if _members[i].position.y >= halfway_y:
			lead_reached_halfway = true

	# Position-based (not just elapsed-time) so this works identically
	# whether this is the very first descent (starting at the top of the
	# screen) or a repeat dive that peeled off mid-screen from the idle
	# circle - either way, once anyone's gotten this far down, the WHOLE
	# squad loops together, wherever each member currently is.
	if lead_reached_halfway:
		_start_loop()


func _start_loop() -> void:
	_phase = Phase.LOOPING
	_loop_time = 0.0
	for i in _alive_indices():
		_loop_start_pos[i] = _members[i].position
		if _members[i].has_method("set_invincible"):
			_members[i].set_invincible(true)


func _process_loop(delta: float) -> void:
	_loop_time += delta
	var t: float = _loop_time / _loop_duration
	# Clamp to exactly 1.0 for the frame that finishes the loop instead of
	# skipping straight to _end_loop() - without this, the loop always cut
	# off a few degrees short of the full 360 (whatever fraction of a frame
	# was left over never got its position update), which is what made the
	# hand-off into the next phase look like it stopped partway around.
	var clamped_t: float = min(t, 1.0)

	# Circle of radius loop_radius, parameterized so the TANGENT at angle 0
	# (and so also at angle TAU, where it closes back up) points straight
	# down - matching the velocity direction the member had right before the
	# loop started and will have right after it ends. That's what makes the
	# hand-off in and out of the loop read as one continuous, consistently-
	# turning motion instead of a snap: the loop starts and ends already
	# facing/moving the same way as normal flight, not sideways.
	# (The previous shape, (sin, 1-cos), had a rightward tangent at its
	# seam instead - correct math, wrong seam orientation for this use.)
	var angle: float = clamped_t * TAU
	var offset := Vector2(cos(angle) - 1.0, sin(angle)) * loop_radius
	for i in _alive_indices():
		_members[i].position = _loop_start_pos[i] + offset
		_update_member_facing(i, delta)

	if t >= 1.0:
		_end_loop()


func _end_loop() -> void:
	for i in _alive_indices():
		var e = _members[i]
		_start_facing_recovery(e)
		_fire_after_loop(e)
	_phase = Phase.EXIT
	_phase_started_at = _squad_time


func _start_facing_recovery(e) -> void:
	"""Ease back to the default down-facing rotation instead of snapping to
	it. The loop's exit velocity points sideways-ish for an instant (it's
	tangent to the loop, not aligned with the resumed straight fall), which
	would otherwise cause a one-frame facing pop the moment normal
	velocity-based facing (_update_member_facing) took back over in
	_process_exit()."""
	var tw = e.create_tween()
	tw.tween_property(e, "rotation", 0.0, loop_recovery_time)


func _fire_after_loop(e) -> void:
	"""Wait a short beat after the loop's own animation completes before
	actually firing, so the shot clearly reads as happening AFTER the loop
	rather than the instant the loop's math resets back to its start
	position. Invincibility drops at the same moment the shot fires, same as
	before."""
	await get_tree().create_timer(fire_delay_after_loop).timeout
	if not is_instance_valid(e) or not e.is_alive:
		return
	if e.has_method("shoot_single"):
		e.shoot_single()
	if e.has_method("set_invincible"):
		e.set_invincible(false)


func _process_exit(delta: float) -> void:
	var recovering: bool = _squad_time < _phase_started_at + loop_recovery_time
	var any_pending := false
	for i in _alive_indices():
		if _exited[i]:
			continue
		_members[i].position.y += path_speed * delta
		if recovering:
			# The facing recovery tween owns rotation right now - just keep
			# last_position in sync so velocity-based facing resumes cleanly
			# (as a single frame's delta, not several frames' worth at once)
			# the moment the tween's done.
			if "last_position" in _members[i]:
				_members[i].last_position = _members[i].position
		else:
			_update_member_facing(i, delta)
		if _members[i].position.y > _screensize.y + 20.0:
			_exited[i] = true
			_members[i].visible = false
			_members[i].set_deferred("monitorable", false)
			_members[i].set_deferred("monitoring", false)
		else:
			any_pending = true

	if not any_pending:
		_start_home()


func _start_home() -> void:
	_phase = Phase.HOME
	_phase_started_at = _squad_time
	_circle_hold_active = false
	_departure_requested = false
	# The re-entry lane lines up with the circle's RIGHTMOST point, not its
	# center - each member joins the circle exactly there (see
	# _process_home()) instead of at the top.
	var entry_lane_x: float = circle_center.x + circle_radius
	for i in _alive_indices():
		var e = _members[i]
		e.position = Vector2(entry_lane_x, -16.0)
		if "last_position" in e:
			e.last_position = e.position  # avoid a bogus facing spike on the first movement frame
		e.visible = true
		e.set_deferred("monitorable", true)
		e.set_deferred("monitoring", true)
		_exited[i] = false
		_circling[i] = false
		_departed[i] = false


func _process_home(delta: float) -> void:
	_circle_theta += circle_angular_speed * delta
	var entry_y: float = circle_center.y  # same height as the circle's rightmost point
	var alive: Array = _alive_indices()
	var all_circling := true
	var all_departed := true

	for i in alive:
		var e = _members[i]

		if _departed[i]:
			# Already peeled off - just keep falling straight down from
			# wherever it broke off (still the rightmost-point x, untouched).
			e.position.y += path_speed * delta
			_update_member_facing(i, delta)
			continue

		all_departed = false

		if not _circling[i]:
			all_circling = false
			if _squad_time < _phase_started_at + _start_time[i]:
				continue
			e.position.y += path_speed * delta
			_update_member_facing(i, delta)
			if e.position.y >= entry_y:
				_join_circle(i)
			continue

		# Circling - offset was fixed once at join time (see _join_circle())
		# and is never adjusted afterward. Keep orbiting clockwise (positive
		# angle = clockwise on screen).
		var angle: float = _circle_theta + _circle_offset[i]
		e.position = circle_center + Vector2(cos(angle), sin(angle)) * circle_radius
		_update_member_facing(i, delta)

		if _departure_requested:
			# Don't force it off the moment departure is requested - wait
			# until its OWN ongoing rotation next carries it back through
			# the rightmost point (angle 0), same portal it joined through.
			# Members are circle_angular_speed*delta apart in angle every
			# frame, so this band is exactly wide enough to always catch the
			# crossing on some frame, never skip past it.
			var angle_mod: float = fposmod(angle, TAU)
			if angle_mod <= circle_angular_speed * delta * 1.5:
				_departed[i] = true

	if all_departed and alive.size() > 0 and _departure_requested:
		_departure_requested = false
		_phase = Phase.ENTER
		# Every survivor is already independently falling at this point
		# (that's what all_departed means) - stagger was already achieved
		# naturally by the order they crossed the rightmost point, so push
		# _phase_started_at far into the past to disable _process_enter's
		# own start-of-fall stagger gate; re-gating them here would freeze
		# whichever ones departed earliest.
		_phase_started_at = _squad_time - 1000.0
		return

	if all_circling and alive.size() > 0 and not _departure_requested:
		if not _circle_hold_active:
			_circle_hold_active = true
			_circle_hold_until = _squad_time + randf_range(circle_hold_min, circle_hold_max)
		elif _squad_time >= _circle_hold_until:
			_departure_requested = true


func _join_circle(i: int) -> void:
	"""Fold member `i` into the idle circle exactly where it already is
	(continuous position, no jump - it just fell straight down the
	rightmost-point lane, see _start_home()). Its angular offset is fixed
	right here, permanently - no easing or later reassignment, same abrupt-
	but-continuous character as departure. With circle_angular_speed derived
	from stagger_time (see _ready()), this naturally lands one
	TAU/SQUAD_SIZE behind whichever member joined just before it."""
	var e = _members[i]
	var current_angle: float = (e.position - circle_center).angle()
	_circle_offset[i] = current_angle - _circle_theta
	e.position = circle_center + Vector2(cos(current_angle), sin(current_angle)) * circle_radius
	_circling[i] = true
