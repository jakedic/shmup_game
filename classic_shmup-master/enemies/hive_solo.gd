# hive_solo.gd
# Drives a single HiveEnemy (see enemies/enemy_hive.gd) along its
# "slow march" pattern:
#
#   1. Spawns ABOVE the screen and creeps straight down, very slowly
#      (path_speed), facing down. No spin, no jitter while moving.
#   2. Every third of the way down the screen (stop_fractions - by default
#      1/3 and 2/3 of the screen height) it:
#        a. HOLDs perfectly still for hold_duration seconds,
#        b. JITTERs violently for jitter_duration seconds - a fast, hard,
#           randomized shake (position AND rotation) like a gatling gun
#           spinning up,
#        c. fires a 3-shot volley of WallBullets (enemy_bullets/wall_bullet.gd)
#           all at once in a fan: wall_spread_angle_deg clockwise of straight
#           down, straight down, and wall_spread_angle_deg counterclockwise,
#      then resumes creeping down.
#   3. After the last stop it keeps creeping down until it exits the bottom.
#
# Implemented as a small state machine (MOVE / HOLD / JITTER) walking through
# the list of stop points built in _build_path(). Position is always
# recomputed from fixed points + elapsed time (no per-frame accumulation), so
# jitter never drifts the enemy off its line.
#
# A level spawns one of these per hive enemy via BaseLevel.spawn_hive_solo()
# (or SquadWaveLevel.spawn_hive_wave()) - see levels/hive_level.gd.
extends Node2D
class_name HiveSolo

# Relayed from the enemy's own `died` signal so the level can score this kill
# like any other - BaseLevel.spawn_hive_solo() connects it to _on_enemy_died().
signal enemy_died(value: int)

const SPAWN_MARGIN := 40.0  # px off-screen above (spawn) and below (despawn)
const WALL_SCENE := preload("res://enemy_bullets/wall_bullet.tscn")

@export var enemy_scene: PackedScene
@export var start_x_percent: float = 0.5   # horizontal position, 0.0-1.0 fraction of screen width
@export var start_delay: float = 0.0       # seconds parked off-screen before it starts moving
@export var path_speed: float = 20.0       # px/s - very slow forward creep
@export var stop_fractions: Array[float] = [1.0 / 3.0, 2.0 / 3.0]  # where it stops, as fractions of screen height

# ----- per-stop timing -----
@export var hold_duration: float = 0.5     # seconds of stillness before the shake starts
@export var jitter_duration: float = 0.9   # seconds of violent shaking; the volley fires the moment this ends

# ----- jitter tuning (gatling-gun shake) -----
@export var jitter_amplitude: float = 3.0              # px
@export var jitter_rotation_amplitude_deg: float = 10.0
@export var jitter_update_interval: float = 0.02       # seconds between re-rolls - very fast
@export var jitter_ramp_up: float = 0.25               # seconds for the shake to reach full strength (spin-up feel)

# ----- wall volley -----
@export var wall_spread_angle_deg: float = 30.0  # how far the outer two walls angle from straight down

enum Phase { MOVE, HOLD, JITTER }

var _enemy: Node = null
var _screensize: Vector2 = Vector2.ZERO
var _wait_time: float = 0.0

var _phase: Phase = Phase.MOVE
var _phase_time: float = 0.0

var _stops: Array[Vector2] = []   # on-screen stop points, top to bottom
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


func _build_path() -> void:
	var x: float = _screensize.x * start_x_percent
	_leg_start = Vector2(x, -SPAWN_MARGIN)
	_stops.clear()
	for f in stop_fractions:
		_stops.append(Vector2(x, _screensize.y * f))


func _spawn_enemy() -> void:
	var e = enemy_scene.instantiate()
	add_child(e)
	e.squad_controlled = true    # this script drives position entirely
	e.follow_anchor = false
	e.follow_anchor_enabled = false
	e.can_dive = false
	e.can_shoot = false          # HiveSolo fires the walls itself
	e.position = _leg_start
	e.rotation = 0.0             # art faces down at rotation 0
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
			var pos: Vector2 = _leg_start + Vector2.DOWN * path_speed * _phase_time
			if _next_stop < _stops.size() and pos.y >= _stops[_next_stop].y:
				pos = _stops[_next_stop]
				_enemy.position = pos
				_enemy.rotation = 0.0
				_enter_phase(Phase.HOLD)
				return
			_enemy.position = pos
			_enemy.rotation = 0.0
			if pos.y > _screensize.y + SPAWN_MARGIN:
				queue_free()  # off the bottom - done

		Phase.HOLD:
			_enemy.position = _stops[_next_stop]
			_enemy.rotation = 0.0
			if _phase_time >= hold_duration:
				_enter_phase(Phase.JITTER)

		Phase.JITTER:
			var stop: Vector2 = _stops[_next_stop]
			if _phase_time >= jitter_duration:
				_enemy.position = stop
				_enemy.rotation = 0.0
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
			_enemy.rotation = _jitter_rotation * strength


func _fire_wall_volley() -> void:
	var angle: float = deg_to_rad(wall_spread_angle_deg)
	for dir in [Vector2.DOWN.rotated(angle), Vector2.DOWN, Vector2.DOWN.rotated(-angle)]:
		var wall := WALL_SCENE.instantiate()
		get_tree().root.add_child(wall)
		wall.start(_enemy.global_position, dir)
