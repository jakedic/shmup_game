# jump_indicator.gd
# Side-panel "Jump" clock (built by game_shell.gd, sits in the stats box).
#
# A round dial that sweeps like a clock hand, starting from 12 o'clock:
#   - READY  : full green disc, gently pulsing - pressing L will jump.
#   - in air : the disc sweeps empty over the course of the jump.
#   - landing: empty.
#   - cooling: refills clockwise in orange as the jump cooldown
#              (player.dash_cooldown_timer, stats "dash_cooldown") counts down.
# Finds the player through the "player" group. If a status Label is
# assigned it shows "READY" when a jump is available.
extends Control

const RING_COLOR := Color(0.85, 0.85, 0.92)
const BACK_COLOR := Color(0.12, 0.12, 0.2)
const AIR_COLOR := Color(0.45, 0.75, 1.0)
const COOLING_COLOR := Color(0.95, 0.55, 0.2)
const READY_COLOR := Color(0.3, 0.85, 0.4)
const READY_GLOW_COLOR := Color(0.6, 1.0, 0.7)
# "READY" is written on top of the green disc, so it uses very dark greens.
const READY_TEXT_COLOR := Color(0.02, 0.18, 0.06)
const READY_TEXT_GLOW_COLOR := Color(0.05, 0.28, 0.1)

const RING_WIDTH_FRACTION := 0.08   # outline thickness, relative to the radius
const SEGMENTS := 64

var status_label: Label = null

var _player: Node = null
var _pulse := 0.0
var _fill := 1.0
var _fill_color := READY_COLOR
var _ready_state := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_pulse = fmod(_pulse + delta * 4.0, TAU)
	if not is_instance_valid(_player) or not _player.is_inside_tree():
		_player = get_tree().get_first_node_in_group("player")

	_ready_state = true
	_fill = 1.0
	_fill_color = READY_COLOR.lerp(READY_GLOW_COLOR, 0.25 + 0.25 * sin(_pulse))
	if is_instance_valid(_player) and "can_dash" in _player:
		if _player.is_dashing:
			# Sweep empty over the jump itself.
			_ready_state = false
			_fill_color = AIR_COLOR
			_fill = _timer_left_fraction(_player.dash_timer)
		elif not _player.can_dash:
			# Cooldown: refill clockwise.
			_ready_state = false
			_fill_color = COOLING_COLOR
			var t: Timer = _player.dash_cooldown_timer
			if is_instance_valid(t) and not t.is_stopped():
				_fill = 1.0 - _timer_left_fraction(t)
			else:
				_fill = 0.0

	if status_label:
		status_label.text = "READY" if _ready_state else ""
		status_label.modulate = READY_TEXT_COLOR.lerp(READY_TEXT_GLOW_COLOR, 0.5 + 0.5 * sin(_pulse))
	queue_redraw()


func _timer_left_fraction(t: Timer) -> float:
	if not is_instance_valid(t) or t.is_stopped() or t.wait_time <= 0.0:
		return 0.0
	return clamp(t.time_left / t.wait_time, 0.0, 1.0)


func _draw() -> void:
	var center := size * 0.5
	var radius: float = min(size.x, size.y) * 0.5
	var ring_w: float = max(radius * RING_WIDTH_FRACTION, 1.0)
	var inner_r := radius - ring_w

	draw_circle(center, radius, BACK_COLOR)

	if _fill >= 0.999:
		draw_circle(center, inner_r, _fill_color)
	elif _fill > 0.0:
		# Pie slice from 12 o'clock, clockwise (screen y points down, so a
		# growing angle turns clockwise).
		var start := -PI / 2.0
		var sweep := TAU * _fill
		var steps: int = max(2, int(SEGMENTS * _fill))
		var pts := PackedVector2Array([center])
		for i in steps + 1:
			var a := start + sweep * float(i) / float(steps)
			pts.append(center + Vector2(cos(a), sin(a)) * inner_r)
		draw_colored_polygon(pts, _fill_color)

	draw_arc(center, radius - ring_w * 0.5, 0.0, TAU, SEGMENTS, RING_COLOR, ring_w, true)
