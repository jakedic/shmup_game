# flower_squad.gd
#
# A squad of 3 flower enemies (enemies/flower_enemy.gd) falling together in
# a single-file column, one behind the other. All three pass through the
# middle of the swing at the same moment, but the middle flower swings the
# opposite way to the front and back ones (it's on the right while they're
# on the left, and vice versa), so the column weaves like a zig-zag.
#
# ATTACK (happens once per entry in attack_heights):
#   1. At the far ends of a swing, the back (top) and middle flowers stop
#      right where they are - one on the left, one on the right - and start
#      charging.
#   2. The front (bottom) flower keeps going a little further, until it
#      reaches the middle of its swing, then stops and charges too.
#   3. All three fire together.
#   4. The top and middle flowers carry on along their path while the
#      bottom one holds still. Once they reach the middle of their swing,
#      they're lined up with the bottom one again, and all three carry on
#      falling in sync.
#
# HOW TO SPAWN ONE FROM LEVEL CODE:
#
#     spawn_flower_squad({"scene": FLOWER, "start": Vector2(120, -20)})
#
# (spawn_flower_squad() lives on levels/base_level.gd.) "start" is where the
# front (lowest) flower appears; the other two line up above it. The squad's
# fall speed, sway, charge/laser time, etc. all come from flower_enemy.gd's
# exports and can be overridden in the same config dict, just like
# spawn_flower(). The squad-only settings below can be overridden there too.
#
# The flowers themselves are added to the level as normal enemies (so score,
# wave-clearing and the "enemies" group all work as usual); this node just
# moves them. It removes itself once all three are gone.
extends Node2D
class_name FlowerSquad

const SQUAD_SIZE := 3
const FRONT := 0    # bottom flower
const MIDDLE := 1
const BACK := 2     # top flower

# ===== SQUAD SETTINGS =====
@export var spacing: float = 22.0   # vertical gap between flowers in the falling column, pixels
# When to attack, as fractions of the screen height (0 = top, 1 = bottom),
# measured at the middle flower. Each one is used once, in order. An attack
# also waits until the whole squad is on screen, so 0.0 means "as soon as
# all three are visible".
@export var attack_heights: Array = [0.0, 0.4]
# Seconds the squad waits (hidden, at its start point) before it starts
# falling. The flowers still count as enemies while waiting, so the wave
# won't end early.
@export var start_delay: float = 0.0

enum FlowerSquadState { FLOATING, CLOSING_IN, FIRING, OPENING_OUT }
var _state: FlowerSquadState = FlowerSquadState.FLOATING

# Slot 0 is the front (lowest) flower, slot 2 the back. A slot stays null
# once its flower is gone, so the others keep their places.
var members: Array = []

# Each flower follows the same path, but has its own place along it
# (phase = where it is in the sway, fall_y = how far it has fallen) so one
# can pause while the others keep moving. They're identical except during
# an attack.
var _phase: Array = []
var _fall_y: Array = []
var _moving: Array = []

var _center_x: float = 0.0
var _next_attack: int = 0
var _attack_timer: float = 0.0
var _resync_phase: float = 0.0   # middle of the swing where everyone lines back up after an attack
var _resync_fall_y: float = 0.0
var _screen: Vector2
var _delay_left: float = 0.0

# Movement settings, read from the front flower once it's been configured.
var _fall_speed: float
var _sway_width: float
var _sway_time: float
var _arc_lift: float
var _pace_center: float
var _pace_ends: float
var _charge_time: float
var _fire_min_y: float
var _fire_max_y_ratio: float

func setup(flower_scene: PackedScene, start_pos: Vector2, overrides: Dictionary = {}) -> Array:
	"""Called by BaseLevel.spawn_flower_squad() right after this squad is
	added to the level. Creates the 3 flowers as siblings (level children)
	and returns them so the level can hook up their `died` signals.
	`overrides` can mix squad settings (above) and flower settings."""
	var flower_overrides := {}
	for key in overrides:
		if key in self:
			set(key, overrides[key])
		else:
			flower_overrides[key] = overrides[key]

	_screen = get_viewport_rect().size
	_center_x = start_pos.x

	var level = get_parent()
	var spin_angle = randf() * TAU
	var spin_dir = 1.0 if randf() < 0.5 else -1.0
	for i in range(SQUAD_SIZE):
		var f = flower_scene.instantiate()
		level.add_child(f)
		f.join_squad(flower_overrides, spin_angle, spin_dir)
		members.append(f)
		_phase.append(0.0)
		_fall_y.append(start_pos.y)
		_moving.append(true)

	var lead = members[FRONT]
	_fall_speed = lead.fall_speed
	_sway_width = lead.sway_width
	_sway_time = max(lead.sway_time, 0.1)
	_arc_lift = lead.arc_lift
	_pace_center = lead.swing_pace_center
	_pace_ends = lead.swing_pace_ends
	_charge_time = lead.charge_time
	_fire_min_y = lead.fire_min_y
	_fire_max_y_ratio = lead.fire_max_y_ratio

	_update_poses()
	_delay_left = start_delay
	if _delay_left > 0.0:
		for f in members:
			f.visible = false
	return members.duplicate()

func _process(delta: float) -> void:
	var alive = _alive_members()
	if alive.is_empty():
		queue_free()
		return

	if _delay_left > 0.0:
		_delay_left -= delta
		if _delay_left <= 0.0:
			for f in alive:
				f.visible = true
		return

	match _state:
		FlowerSquadState.FLOATING:
			_process_floating(delta)
		FlowerSquadState.CLOSING_IN:
			_process_closing_in(delta)
		FlowerSquadState.FIRING:
			# Flowers run their own laser; wait until they're all done.
			for f in alive:
				if f.is_attacking():
					return
			_moving[MIDDLE] = true
			_moving[BACK] = true
			_state = FlowerSquadState.OPENING_OUT
		FlowerSquadState.OPENING_OUT:
			_process_opening_out(delta)

	_update_poses()

# ===== STATES =====

func _process_floating(delta: float) -> void:
	var old_phase = _phase[FRONT]
	for slot in range(SQUAD_SIZE):
		_advance(slot, delta)

	# Attack as the column passes through the far ends of a swing (phase =
	# PI/2 + a multiple of PI), where the top and middle flowers are out on
	# opposite sides.
	var new_phase = _phase[FRONT]
	var crossed_end = floor((new_phase - PI / 2.0) / PI) != floor((old_phase - PI / 2.0) / PI)
	if crossed_end and _attack_ready():
		_start_attack(floor((new_phase - PI / 2.0) / PI) * PI + PI / 2.0)

func _attack_ready() -> bool:
	if _next_attack >= attack_heights.size():
		return false
	var back_y = _fall_y[BACK] - BACK * spacing - _arc_lift
	var middle_y = _fall_y[MIDDLE] - MIDDLE * spacing
	var target_y = float(attack_heights[_next_attack]) * _screen.y
	return back_y >= _fire_min_y and middle_y >= target_y and _fall_y[FRONT] <= _screen.y * _fire_max_y_ratio

func _start_attack(end_phase: float) -> void:
	_next_attack += 1
	_attack_timer = 0.0
	# Snap everyone exactly onto the end of the swing.
	for slot in range(SQUAD_SIZE):
		_phase[slot] = end_phase
	# Where they'll all line back up afterwards: the middle of the swing,
	# a quarter of a full swing further along the path.
	_resync_phase = end_phase + PI / 2.0
	_resync_fall_y = _fall_y[FRONT] + _fall_speed * _quarter_swing_time()

	# Top and middle stop here and start charging. Their charge lasts
	# until the bottom flower has caught up and charged too.
	_moving[MIDDLE] = false
	_moving[BACK] = false
	var long_charge = _quarter_swing_time() + _charge_time
	for slot in [MIDDLE, BACK]:
		if _is_alive(members[slot]):
			members[slot].begin_charge(long_charge)
	_state = FlowerSquadState.CLOSING_IN

func _process_closing_in(delta: float) -> void:
	_attack_timer += delta
	# Bottom flower carries on to the middle of its swing, then charges.
	if _moving[FRONT]:
		_advance(FRONT, delta)
		if _phase[FRONT] >= _resync_phase:
			_snap_to_resync(FRONT)
			_moving[FRONT] = false
			if _is_alive(members[FRONT]):
				members[FRONT].begin_charge(_charge_time)

	# Everyone fires together once the bottom flower has had its full charge.
	if not _moving[FRONT] and _attack_timer >= _quarter_swing_time() + _charge_time:
		for f in _alive_members():
			f.fire_now()
		_state = FlowerSquadState.FIRING

func _process_opening_out(delta: float) -> void:
	# Top and middle carry on to the middle of their swing while the bottom
	# flower waits there.
	for slot in [MIDDLE, BACK]:
		if _moving[slot]:
			_advance(slot, delta)
			if _phase[slot] >= _resync_phase:
				_snap_to_resync(slot)
				_moving[slot] = false
	if not _moving[MIDDLE] and not _moving[BACK]:
		# Lined up again - all three carry on together.
		for slot in range(SQUAD_SIZE):
			_moving[slot] = true
		_state = FlowerSquadState.FLOATING

# ===== MOVEMENT =====

func _quarter_swing_time() -> float:
	return _sway_time / 4.0

func _advance(slot: int, delta: float) -> void:
	# Faster through the middle of the swing, slower at the ends - same
	# pendulum pacing as a solo flower (see FlowerEnemy.swing_pace()).
	var pace = FlowerEnemy.swing_pace(_phase[slot], _pace_center, _pace_ends)
	_phase[slot] += TAU / _sway_time * delta * pace
	_fall_y[slot] += _fall_speed * delta * pace

func _snap_to_resync(slot: int) -> void:
	_phase[slot] = _resync_phase
	_fall_y[slot] = _resync_fall_y

func _slot_swing(slot: int) -> float:
	"""-1..1 sway for this slot. The middle flower mirrors the other two,
	so it's right when they're left and left when they're right."""
	var swing = sin(_phase[slot])
	return -swing if slot == MIDDLE else swing

func _slot_pos(slot: int) -> Vector2:
	var swing = _slot_swing(slot)
	return Vector2(_center_x + _sway_width * swing, _fall_y[slot] - slot * spacing - _arc_lift * swing * swing)

func _update_poses() -> void:
	for slot in range(members.size()):
		var f = members[slot]
		if _is_alive(f):
			f.set_squad_pose(_slot_pos(slot), _slot_swing(slot))

# ===== MEMBERS =====

func _is_alive(f) -> bool:
	return is_instance_valid(f) and f.is_alive

func _alive_members() -> Array:
	var result := []
	for i in range(members.size()):
		if _is_alive(members[i]):
			result.append(members[i])
		else:
			members[i] = null
	return result
