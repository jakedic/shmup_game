# hive_squad.gd
# A two-enemy HiveEnemy squad (see enemies/enemy_hive.gd). Choreography:
#
#   1. DESCEND - both hives enter from above the screen side by side
#      (`spacing` px apart, centered on start_x_percent) and creep straight
#      down at path_speed.
#   2. MERGE   - converge_height px before a third of the way down the screen
#      (meet_fraction), each turns diagonally inward so they arrive at the
#      same point at the same moment and overlap.
#   3. HOLD    - both sit perfectly still, facing down, for hold_duration.
#   4. JITTER  - both shake violently like the solo hive, but each on its own
#      random timeline (the second one's re-roll timer is offset by half an
#      interval) AND the one drawn on top swaps every top_swap_interval, so
#      you keep catching glimpses of both hives through the shake.
#   5. The moment the jitter ends, fire ONE combined volley of `volley_count`
#      WallBullets (enemy_bullets/wall_bullet.gd) evenly around a full circle
#      (8 = every 45 degrees).
#   6. SPLIT   - they turn diagonally back outward (mirror of the merge) to
#      side-by-side again,
#   7. EXIT    - and creep straight down until off the bottom of the screen.
#
# If one hive is killed, the other carries on the choreography alone (the
# volley still fires as long as either is alive). Every phase is a straight
# line between fixed points, so positions are pure functions of elapsed time.
#
# Spawned via BaseLevel.spawn_hive_squad() - see levels/hive_level.gd.
extends Node2D
class_name HiveSquad

signal enemy_died(value: int)

const SPAWN_MARGIN := 40.0
const WALL_SCENE := preload("res://enemy_bullets/wall_bullet.tscn")
const SQUAD_SIZE := 2  # the hive squad is always a pair

@export var enemy_scene: PackedScene
@export var start_x_percent: float = 0.5   # center of the pair, 0.0-1.0 of screen width
@export var start_delay: float = 0.0
@export var path_speed: float = 20.0       # px/s - same slow creep as the solo hive
@export var spacing: float = 60.0          # px between the two hives while side by side
@export var meet_fraction: float = 1.0 / 3.0  # where they meet, as a fraction of screen height
@export var converge_height: float = 30.0  # px above the meet point where they turn inward (30 with 60 spacing = a 45-degree diagonal)
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

var _members: Array = []           # HiveEnemy nodes, index 0 = left, 1 = right
var _screensize: Vector2 = Vector2.ZERO
var _wait_time: float = 0.0

var _phase: Phase = Phase.DESCEND
var _phase_time: float = 0.0
var _phase_duration: float = 0.0

# Per-member fixed waypoints (built once in _build_path()).
var _start: Array[Vector2] = []
var _pre_merge: Array[Vector2] = []
var _post_split: Array[Vector2] = []
var _meet: Vector2 = Vector2.ZERO

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
	var cx: float = _screensize.x * start_x_percent
	var half: float = spacing / 2.0
	var meet_y: float = _screensize.y * meet_fraction
	_meet = Vector2(cx, meet_y)
	for i in range(SQUAD_SIZE):
		var side: float = -1.0 if i == 0 else 1.0
		var x: float = cx + side * half
		_start.append(Vector2(x, -SPAWN_MARGIN))
		_pre_merge.append(Vector2(x, meet_y - converge_height))
		_post_split.append(Vector2(x, meet_y + converge_height))
		_jitter_timers.append(0.0)
		_jitter_offsets.append(Vector2.ZERO)
		_jitter_rotations.append(0.0)


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
		e.rotation = 0.0
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


func _facing_rotation_for(direction: Vector2) -> float:
	return direction.angle() - Vector2.DOWN.angle()


func _enter_phase(phase: Phase) -> void:
	_phase = phase
	_phase_time = 0.0
	match phase:
		Phase.DESCEND:
			_phase_duration = _start[0].distance_to(_pre_merge[0]) / path_speed
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
		var target_rot: float = 0.0
		var extra_rot: float = 0.0
		match _phase:
			Phase.DESCEND:
				pos = _start[i].lerp(_pre_merge[i], t)
			Phase.MERGE:
				pos = _pre_merge[i].lerp(_meet, t)
				target_rot = _facing_rotation_for(_meet - _pre_merge[i])
			Phase.HOLD:
				pos = _meet
			Phase.JITTER:
				var jitter := _member_jitter(i, delta)
				pos = _meet + jitter[0]
				extra_rot = jitter[1]
			Phase.SPLIT:
				pos = _meet.lerp(_post_split[i], t)
				target_rot = _facing_rotation_for(_post_split[i] - _meet)
			Phase.EXIT:
				pos = _post_split[i] + Vector2.DOWN * path_speed * _phase_time
		e.position = pos
		if _phase == Phase.JITTER:
			e.rotation = target_rot + extra_rot
		else:
			e.rotation = lerp_angle(e.rotation, target_rot, 1.0 - exp(-turn_speed * delta))
		if pos.y <= _screensize.y + SPAWN_MARGIN:
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
		Phase.SPLIT: _enter_phase(Phase.EXIT)


func _fire_wall_volley() -> void:
	var count: int = maxi(volley_count, 1)
	for k in range(count):
		var dir: Vector2 = Vector2.DOWN.rotated(TAU * float(k) / float(count))
		var wall := WALL_SCENE.instantiate()
		get_tree().root.add_child(wall)
		wall.start(to_global(_meet), dir)
