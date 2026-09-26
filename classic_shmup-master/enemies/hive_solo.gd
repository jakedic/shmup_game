# hive_solo.gd
# Drives a single HiveEnemy (see enemies/enemy_hive.gd) along its
# "slow march" pattern:
#
#   1. Spawns at start_pos (normally just off one screen edge) and creeps in a
#      straight line toward end_pos, very slowly (path_speed), facing the way
#      it's moving. No spin, no jitter while moving.
#   2. At each of stop_fractions (by default 1/3 and 2/3 of the way across the
#      ON-SCREEN part of that line - see screen_span()) it:
#        a. HOLDs perfectly still for hold_duration seconds,
#        b. JITTERs violently for jitter_duration seconds - a fast, hard,
#           randomized shake (position AND rotation) like a gatling gun
#           spinning up,
#        c. fires a 3-shot volley of WallBullets (enemy_bullets/wall_bullet.gd)
#           all at once in a fan centered on its direction of travel:
#           wall_spread_angle_deg to one side, straight ahead, and
#           wall_spread_angle_deg to the other side,
#      then resumes creeping along the line.
#   3. After the last stop it keeps going in the same direction until it's
#      fully off-screen.
#
# Implemented as a small state machine (MOVE / HOLD / JITTER) walking through
# the list of stop points built in _build_path(). Position is always
# recomputed from fixed points + elapsed time (no per-frame accumulation), so
# jitter never drifts the enemy off its line.
#
# A level spawns one of these per hive enemy via BaseLevel.spawn_hive_solo()
# (or SquadWaveLevel.spawn_hive_wave(), which takes side+percent like every
# other wave pattern) - see levels/hive_level.gd and levels/yellow_level.gd.
extends Node2D
class_name HiveSolo

# Relayed from the enemy's own `died` signal so the level can score this kill
# like any other - BaseLevel.spawn_hive_solo() connects it to _on_enemy_died().
signal enemy_died(value: int)

const DESPAWN_MARGIN := 40.0  # px past the screen edge before it's removed
const WALL_SCENE := preload("res://enemy_bullets/wall_bullet.tscn")

@export var enemy_scene: PackedScene
@export var start_pos: Vector2 = Vector2(120, -40)  # where it spawns (normally off-screen)
@export var end_pos: Vector2 = Vector2(120, 360)    # sets its direction of travel
@export var start_delay: float = 0.0       # seconds parked at start_pos before it starts moving
@export var path_speed: float = 40.0       # px/s - very slow forward creep
@export var stop_fractions: Array[float] = [1.0/4.0, 1.0 / 3.0, 13.0/32.0, 2.0/4.0, 7/12, 2.0/3.0, 3/4, 83/99]  # where it stops, as fractions of the on-screen part of its path

# ----- per-stop timing -----
@export var hold_duration: float = 0.5     # seconds of stillness before the shake starts
@export var jitter_duration: float = 0.9   # seconds of violent shaking; the volley fires the moment this ends

# ----- jitter tuning (gatling-gun shake) -----
@export var jitter_amplitude: float = 3.0              # px
@export var jitter_rotation_amplitude_deg: float = 10.0
@export var jitter_update_interval: float = 0.02       # seconds between re-rolls - very fast
@export var jitter_ramp_up: float = 0.25               # seconds for the shake to reach full strength (spin-up feel)

# ----- wall volley -----
@export var wall_spread_angle_deg: float = 30.0  # how far the outer two walls angle from the direction of travel

enum Phase { MOVE, HOLD, JITTER }

var _enemy: Node = null
var _screensize: Vector2 = Vector2.ZERO
var _wait_time: float = 0.0

var _phase: Phase = Phase.MOVE
var _phase_time: float = 0.0

var _dir: Vector2 = Vector2.DOWN  # direction of travel (start_pos -> end_pos)
var _facing: float = 0.0          # rotation that faces _dir
var _stops: Array[Vector2] = []   # on-screen stop points, in travel order
var _next_stop: int = 0           # index into _stops of the next stop to reach
var _leg_start: Vector2 = Vector2.ZERO  # where the current MOVE leg began

var _jitter_timer: float = 0.0
var _jitter_offset: Vector2 = Vector2.ZERO
var _jitter_rotation: float = 0.0


func _ready() -> void:
	_screensize = get_viewport_rect().size
	_build_path()
	_spawn_enemy()
	_enter_phase(Phase.MOVE)


static func screen_span(a: Vector2, b: Vector2, size: Vector2) -> Vector2:
	"""Returns Vector2(t_in, t_out): the part of the line a->b (t = 0..1)
	that's actually inside the screen rect (0,0)-(size). Used so "a third of
	the way" means a third of the way across the SCREEN, not a third of the
	way between two off-screen points. Falls back to (0, 1) if the line never
	crosses the screen."""
	var d: Vector2 = b - a
	var t_in: float = 0.0
	var t_out: float = 1.0
	for axis in range(2):
		var p: float = a[axis]
		var v: float = d[axis]
		var lo: float = 0.0
		var hi: float = size[axis]
		if absf(v) < 0.0001:
			if p < lo or p > hi:
				return Vector2(0.0, 1.0)
			continue
		var t1: float = (lo - p) / v
		var t2: float = (hi - p) / v
		t_in = maxf(t_in, minf(t1, t2))
		t_out = minf(t_out, maxf(t1, t2))
	if t_in >= t_out:
		return Vector2(0.0, 1.0)
	return Vector2(t_in, t_out)


static func facing_rotation_for(direction: Vector2) -> float:
	"""Rotation that makes hive art (which faces down at rotation 0) face `direction`."""
	return direction.angle() - Vector2.DOWN.angle()


func _build_path() -> void:
	_dir = (end_pos - start_pos).normalized()
	if _dir == Vector2.ZERO:
		_dir = Vector2.DOWN
	_facing = facing_rotation_for(_dir)
	_leg_start = start_pos
	var span := screen_span(start_pos, end_pos, _screensize)
	_stops.clear()
	for f in stop_fractions:
		_stops.append(start_pos.lerp(end_pos, lerpf(span.x, span.y, f)))


func _spawn_enemy() -> void:
	var e = enemy_scene.instantiate()
	add_child(e)
	e.squad_controlled = true    # this script drives position entirely
	e.follow_anchor = false
	e.follow_anchor_enabled = false
	e.can_dive = false
	e.can_shoot = false          # HiveSolo fires the walls itself
	e.position = start_pos
	e.rotation = _facing
	if "last_position" in e:
		e.last_position = e.position
	if e.has_method("_stop_idle_rock"):
		e._stop_idle_rock()
	if e.has_signal("died"):
		e.died.connect(_on_enemy_died)
	_enemy = e


func _on_enemy_died(value: int) -> void:
	enemy_died.emit(value)


func _enter_phase(phase: Phase) -> void:
	_phase = phase
	_phase_time = 0.0
	if phase == Phase.JITTER:
		_jitter_timer = 0.0  # re-roll on the first frame


func _is_off_screen(pos: Vector2) -> bool:
	return pos.x < -DESPAWN_MARGIN or pos.x > _screensize.x + DESPAWN_MARGIN \
		or pos.y < -DESPAWN_MARGIN or pos.y > _screensize.y + DESPAWN_MARGIN


func _process(delta: float) -> void:
	_wait_time += delta
	if _wait_time < start_delay:
		return

	if not is_instance_valid(_enemy) or not _enemy.is_alive:
		queue_free()
		return

	_phase_time += delta

	match _phase:
		Phase.MOVE:
			var traveled: float = path_speed * _phase_time
			var pos: Vector2 = _leg_start + _dir * traveled
			if _next_stop < _stops.size() and traveled >= _leg_start.distance_to(_stops[_next_stop]):
				_enemy.position = _stops[_next_stop]
				_enemy.rotation = _facing
				_enter_phase(Phase.HOLD)
				return
			_enemy.position = pos
			_enemy.rotation = _facing
			# Only despawn once all stops are done, so a start point further
			# off-screen than DESPAWN_MARGIN doesn't remove it before it enters.
			if _next_stop >= _stops.size() and _is_off_screen(pos):
				queue_free()

		Phase.HOLD:
			_enemy.position = _stops[_next_stop]
			_enemy.rotation = _facing
			if _phase_time >= hold_duration:
				_enter_phase(Phase.JITTER)

		Phase.JITTER:
			var stop: Vector2 = _stops[_next_stop]
			if _phase_time >= jitter_duration:
				_enemy.position = stop
				_enemy.rotation = _facing
				_fire_wall_volley()
				_leg_start = stop
				_next_stop += 1
				_enter_phase(Phase.MOVE)
				return
			_jitter_timer -= delta
			if _jitter_timer <= 0.0:
				_jitter_offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * jitter_amplitude
				_jitter_rotation = randf_range(-1.0, 1.0) * deg_to_rad(jitter_rotation_amplitude_deg)
				_jitter_timer = jitter_update_interval
			var strength: float = 1.0 if jitter_ramp_up <= 0.0 else clamp(_phase_time / jitter_ramp_up, 0.0, 1.0)
			_enemy.position = stop + _jitter_offset * strength
			_enemy.rotation = _facing + _jitter_rotation * strength


func _fire_wall_volley() -> void:
	var angle: float = deg_to_rad(wall_spread_angle_deg)
	for dir in [_dir.rotated(angle), _dir, _dir.rotated(-angle)]:
		var wall := WALL_SCENE.instantiate()
		get_tree().root.add_child(wall)
		wall.start(_enemy.global_position, dir)
