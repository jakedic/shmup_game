# hive_squad.gd
# A two-enemy HiveEnemy squad (see enemies/enemy_hive.gd). Choreography:
#
#   1. DESCEND - both hives enter side by side (`spacing` px apart, centered
#      on the line from start_pos to end_pos) and creep along that line at
#      path_speed, facing the way they're moving.
#   2. MERGE   - converge_height px before each meet point (meet_fractions -
#      by default a third and two thirds of the way across the on-screen
#      part of the line, see HiveSolo.screen_span()), each turns diagonally
#      inward so they arrive at the same point at the same moment and overlap.
#   3. HOLD    - both sit perfectly still, facing the direction of travel, for
#      hold_duration.
#   4. JITTER  - both shake violently like the solo hive, but each on its own
#      random timeline (the second one's re-roll timer is offset by half an
#      interval) AND the one drawn on top swaps every top_swap_interval, so
#      you keep catching glimpses of both hives through the shake.
#   5. The moment the jitter ends, fire ONE combined volley of `volley_count`
#      WallBullets (enemy_bullets/wall_bullet.gd) evenly around a full circle
#      (8 = every 45 degrees).
#   6. SPLIT   - they turn diagonally back outward (mirror of the merge) to
#      side-by-side again. Steps 1-6 repeat for every meet point.
#   7. EXIT    - after the last meet point, keep creeping in the same
#      direction until fully off-screen.
#
# If one hive is killed, the other carries on the choreography alone (the
# volley still fires as long as either is alive). Every phase is a straight
# line between fixed points, so positions are pure functions of elapsed time.
#
# Spawned via BaseLevel.spawn_hive_squad() (or SquadWaveLevel.
# spawn_hive_squad_wave(), which takes side+percent like every other wave
# pattern) - see levels/hive_level.gd and levels/yellow_level.gd.
extends Node2D
class_name HiveSquad

signal enemy_died(value: int)

const DESPAWN_MARGIN := 40.0  # px past the screen edge before a member is removed
const WALL_SCENE := preload("res://enemy_bullets/wall_bullet.tscn")
const SQUAD_SIZE := 2  # the hive squad is always a pair

@export var enemy_scene: PackedScene
@export var start_pos: Vector2 = Vector2(120, -40)  # center of the pair at spawn (normally off-screen)
@export var end_pos: Vector2 = Vector2(120, 360)    # sets the pair's direction of travel
@export var start_delay: float = 0.0
@export var path_speed: float = 20.0       # px/s - same slow creep as the solo hive
@export var spacing: float = 32.0          # px between the two hives while side by side
@export var meet_fractions: Array[float] = [1.0 / 3.0, 2.0 / 3.0]  # where they merge + fire, as fractions of the on-screen part of the path
@export var converge_height: float = 16.0  # px above/below each meet point where they turn in/out (half of spacing = a 45-degree diagonal)
@export var turn_speed: float = 10.0       # how quickly they rotate to face a new direction (higher = snappier)

# ----- stop timing -----
@export var hold_duration: float = 0.5
@export var jitter_duration: float = 1.0

# ----- jitter tuning -----
@export var jitter_amplitude: float = 4.0
@export var jitter_rotation_amplitude_deg: float = 10.0
@export var jitter_update_interval: float = 0.04
@export var jitter_ramp_up: float = 0.25
@export var top_swap_interval: float = 0.08  # seconds between swapping which hive is drawn on top

# ----- volley -----
@export var volley_count: int = 8  # walls fired evenly around a full circle

enum Phase { DESCEND, MERGE, HOLD, JITTER, SPLIT, EXIT }

var _members: Array = []           # HiveEnemy nodes, index 0 = left, 1 = right (relative to travel direction)
var _screensize: Vector2 = Vector2.ZERO
var _wait_time: float = 0.0

var _phase: Phase = Phase.DESCEND
var _phase_time: float = 0.0
var _phase_duration: float = 0.0

# Fixed waypoints (built once in _build_path()). _start is per member;
# _meets holds one point per stop, and _pre_merge/_post_split hold one
# Array[Vector2] (per member) per stop.
var _start: Array[Vector2] = []
var _meets: Array[Vector2] = []
var _pre_merges: Array = []
var _post_splits: Array = []
var _stop: int = 0                  # which meet point we're currently heading to / at
var _leg_from: Array[Vector2] = []  # per member - where the current DESCEND leg began
var _meet: Vector2 = Vector2.ZERO   # current stop's meet point
var _pre_merge: Array[Vector2] = [] # current stop's per-member points
var _post_split: Array[Vector2] = []
var _dir: Vector2 = Vector2.DOWN    # direction of travel (start_pos -> end_pos)
var _facing: float = 0.0            # rotation that faces _dir

# Per-member jitter state - each member re-rolls on its own timer so they
# never shake in lockstep.
var _jitter_timers: Array[float] = []
var _jitter_offsets: Array[Vector2] = []
var _jitter_rotations: Array[float] = []
var _top_swap_timer: float = 0.0
var _top_member: int = 0


func _ready() -> void:
	_screensize = get_viewport_rect().size
	_build_path()
	_spawn_members()
	_enter_phase(Phase.DESCEND)


func _build_path() -> void:
	_dir = (end_pos - start_pos).normalized()
	if _dir == Vector2.ZERO:
		_dir = Vector2.DOWN
	_facing = HiveSolo.facing_rotation_for(_dir)
	# "Side by side" = offset perpendicular to the direction of travel.
	var across: Vector2 = _dir.orthogonal() * (spacing / 2.0)
	for i in range(SQUAD_SIZE):
		var side: float = -1.0 if i == 0 else 1.0
		_start.append(start_pos + across * side)
		_jitter_timers.append(0.0)
		_jitter_offsets.append(Vector2.ZERO)
		_jitter_rotations.append(0.0)
	var span: Vector2 = HiveSolo.screen_span(start_pos, end_pos, _screensize)
	for f in meet_fractions:
		var meet: Vector2 = start_pos.lerp(end_pos, lerpf(span.x, span.y, f))
		_meets.append(meet)
		var pre: Array[Vector2] = []
		var post: Array[Vector2] = []
		for i in range(SQUAD_SIZE):
			var side: float = -1.0 if i == 0 else 1.0
			pre.append(meet - _dir * converge_height + across * side)
			post.append(meet + _dir * converge_height + across * side)
		_pre_merges.append(pre)
		_post_splits.append(post)
	_leg_from = _start.duplicate()
	_load_stop(0)


func _load_stop(k: int) -> void:
	"""Point _meet/_pre_merge/_post_split at stop `k`'s waypoints."""
	_stop = k
	if k >= _meets.size():
		return
	_meet = _meets[k]
	_pre_merge = _pre_merges[k]
	_post_split = _post_splits[k]


func _spawn_members() -> void:
	for i in range(SQUAD_SIZE):
		var e = enemy_scene.instantiate()
		add_child(e)
		e.squad_controlled = true
		e.follow_anchor = false
		e.follow_anchor_enabled = false
		e.can_dive = false
		e.can_shoot = false
		e.position = _start[i]
		e.rotation = _facing
		if "last_position" in e:
			e.last_position = e.position
		if e.has_method("_stop_idle_rock"):
			e._stop_idle_rock()
		if e.has_signal("died"):
			e.died.connect(_on_member_died)
		_members.append(e)


func _on_member_died(value: int) -> void:
	enemy_died.emit(value)


func _alive(i: int) -> bool:
	var e = _members[i]
	return is_instance_valid(e) and e.is_alive


func _is_off_screen(pos: Vector2) -> bool:
	return pos.x < -DESPAWN_MARGIN or pos.x > _screensize.x + DESPAWN_MARGIN \
		or pos.y < -DESPAWN_MARGIN or pos.y > _screensize.y + DESPAWN_MARGIN


func _enter_phase(phase: Phase) -> void:
	_phase = phase
	_phase_time = 0.0
	match phase:
		Phase.DESCEND:
			if _stop >= _meets.size():
				_enter_phase(Phase.EXIT)  # no meet points configured
				return
			_phase_duration = _leg_from[0].distance_to(_pre_merge[0]) / path_speed
		Phase.MERGE:
			_phase_duration = _pre_merge[0].distance_to(_meet) / path_speed
		Phase.HOLD:
			_phase_duration = hold_duration
		Phase.JITTER:
			_phase_duration = jitter_duration
			# Offset the second hive's re-roll by half an interval so the two
			# never twitch on the same frame.
			for i in range(SQUAD_SIZE):
				_jitter_timers[i] = jitter_update_interval * 0.5 * i
			_top_swap_timer = 0.0
		Phase.SPLIT:
			_phase_duration = _meet.distance_to(_post_split[0]) / path_speed
		Phase.EXIT:
			_phase_duration = -1.0


func _process(delta: float) -> void:
	_wait_time += delta
	if _wait_time < start_delay:
		return

	var any_alive := false
	for i in range(SQUAD_SIZE):
		if _alive(i):
			any_alive = true
	if not any_alive:
		queue_free()
		return

	_phase_time += delta
	var t: float = 1.0 if _phase_duration <= 0.0 else clamp(_phase_time / _phase_duration, 0.0, 1.0)

	if _phase == Phase.JITTER:
		_update_top_swap(delta)

	var all_off_screen := true
	for i in range(SQUAD_SIZE):
		if not _alive(i):
			continue
		var e = _members[i]
		var pos: Vector2
		var target_rot: float = _facing
		var extra_rot: float = 0.0
		match _phase:
			Phase.DESCEND:
				pos = _leg_from[i].lerp(_pre_merge[i], t)
			Phase.MERGE:
				pos = _pre_merge[i].lerp(_meet, t)
				target_rot = HiveSolo.facing_rotation_for(_meet - _pre_merge[i])
			Phase.HOLD:
				pos = _meet
			Phase.JITTER:
				var jitter := _member_jitter(i, delta)
				pos = _meet + jitter[0]
				extra_rot = jitter[1]
			Phase.SPLIT:
				pos = _meet.lerp(_post_split[i], t)
				target_rot = HiveSolo.facing_rotation_for(_post_split[i] - _meet)
			Phase.EXIT:
				pos = _leg_from[i] + _dir * path_speed * _phase_time
		e.position = pos
		if _phase == Phase.JITTER:
			e.rotation = target_rot + extra_rot
		else:
			e.rotation = lerp_angle(e.rotation, target_rot, 1.0 - exp(-turn_speed * delta))
		if not _is_off_screen(pos):
			all_off_screen = false

	if _phase == Phase.EXIT:
		if all_off_screen:
			queue_free()
		return

	if t >= 1.0:
		_advance_phase()


func _member_jitter(i: int, delta: float) -> Array:
	_jitter_timers[i] -= delta
	if _jitter_timers[i] <= 0.0:
		_jitter_offsets[i] = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * jitter_amplitude
		_jitter_rotations[i] = randf_range(-1.0, 1.0) * deg_to_rad(jitter_rotation_amplitude_deg)
		_jitter_timers[i] = jitter_update_interval
	var strength: float = 1.0 if jitter_ramp_up <= 0.0 else clamp(_phase_time / jitter_ramp_up, 0.0, 1.0)
	return [_jitter_offsets[i] * strength, _jitter_rotations[i] * strength]


func _update_top_swap(delta: float) -> void:
	"""Alternate which hive draws on top so both keep flashing into view."""
	_top_swap_timer -= delta
	if _top_swap_timer > 0.0:
		return
	_top_swap_timer = top_swap_interval
	_top_member = 1 - _top_member
	for i in range(SQUAD_SIZE):
		if _alive(i):
			_members[i].z_index = 1 if i == _top_member else 0


func _advance_phase() -> void:
	match _phase:
		Phase.DESCEND: _enter_phase(Phase.MERGE)
		Phase.MERGE: _enter_phase(Phase.HOLD)
		Phase.HOLD: _enter_phase(Phase.JITTER)
		Phase.JITTER:
			for i in range(SQUAD_SIZE):
				if _alive(i):
					_members[i].z_index = 0
			_fire_wall_volley()
			_enter_phase(Phase.SPLIT)
		Phase.SPLIT:
			# Next leg starts from where this split ended.
			_leg_from = _post_split.duplicate()
			_load_stop(_stop + 1)
			if _stop < _meets.size():
				_enter_phase(Phase.DESCEND)
			else:
				_enter_phase(Phase.EXIT)


func _fire_wall_volley() -> void:
	var count: int = maxi(volley_count, 1)
	for k in range(count):
		var dir: Vector2 = Vector2.DOWN.rotated(TAU * float(k) / float(count))
		var wall := WALL_SCENE.instantiate()
		get_tree().root.add_child(wall)
		wall.start(to_global(_meet), dir)
