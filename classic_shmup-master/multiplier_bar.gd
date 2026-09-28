# multiplier_bar.gd
# Side-panel meter for the score multiplier (built by game_shell.gd).
#
# One bar, two parts:
#   - Top (thick): progress toward the NEXT multiplier. It's split into one
#     segment per kill needed, and each kill lights up a segment. At the max
#     multiplier the whole top is lit and pulses.
#   - Bottom (thin strip): the decay timer. While the multiplier is above 1x
#     the level's multiplier timer is running, and when it runs out the
#     multiplier drops by one. The strip drains as that timer counts down and
#     turns red near the end. It refills every time a kill restarts the timer.
extends Control

const BORDER_COLOR := Color(0.85, 0.85, 0.92)
const BACK_COLOR := Color(0.09, 0.09, 0.16)
const SEGMENT_EMPTY_COLOR := Color(0.18, 0.18, 0.28)
const PROGRESS_COLOR := Color(1.0, 0.78, 0.2)
const MAX_COLOR := Color(1.0, 0.92, 0.45)
const DECAY_COLOR := Color(0.35, 0.8, 1.0)
const DECAY_LOW_COLOR := Color(1.0, 0.3, 0.25)
const DECAY_LOW_FRACTION := 0.3  # strip turns red below this much time left

const DECAY_STRIP_HEIGHT := 4.0
const SEGMENT_GAP := 1.0

var kills := 0
var kills_needed := 5
var at_max := false
var decay_timer: Timer = null

var _pulse := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Keep animating while paused so the bar doesn't look frozen mid-pulse.
	process_mode = Node.PROCESS_MODE_ALWAYS


func set_progress(p_kills: int, p_kills_needed: int, p_at_max: bool) -> void:
	kills = p_kills
	kills_needed = max(p_kills_needed, 1)
	at_max = p_at_max
	queue_redraw()


func set_decay_timer(timer: Timer) -> void:
	decay_timer = timer
	queue_redraw()


func _decay_fraction() -> float:
	# 0..1 of time left before the multiplier drops, or 0 when not decaying.
	if decay_timer == null or not is_instance_valid(decay_timer):
		return 0.0
	if decay_timer.is_stopped() or decay_timer.wait_time <= 0.0:
		return 0.0
	return clamp(decay_timer.time_left / decay_timer.wait_time, 0.0, 1.0)


func _process(delta: float) -> void:
	_pulse = fmod(_pulse + delta * 4.0, TAU)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, BACK_COLOR)

	var inner := r.grow(-1.0)
	var prog_rect := Rect2(inner.position, Vector2(inner.size.x, inner.size.y - DECAY_STRIP_HEIGHT - 1.0))
	var decay_rect := Rect2(
		Vector2(inner.position.x, inner.end.y - DECAY_STRIP_HEIGHT),
		Vector2(inner.size.x, DECAY_STRIP_HEIGHT))

	# --- progress segments ---
	var seg_w := (prog_rect.size.x - SEGMENT_GAP * (kills_needed - 1)) / kills_needed
	for i in kills_needed:
		var seg := Rect2(
			Vector2(prog_rect.position.x + i * (seg_w + SEGMENT_GAP), prog_rect.position.y),
			Vector2(seg_w, prog_rect.size.y))
		var col := SEGMENT_EMPTY_COLOR
		if at_max:
			col = MAX_COLOR.lerp(PROGRESS_COLOR, 0.5 + 0.5 * sin(_pulse))
		elif i < kills:
			col = PROGRESS_COLOR
		draw_rect(seg, col)

	# --- decay strip ---
	draw_rect(decay_rect, SEGMENT_EMPTY_COLOR)
	var frac := _decay_fraction()
	if frac > 0.0:
		var col := DECAY_COLOR if frac > DECAY_LOW_FRACTION else DECAY_LOW_COLOR
		draw_rect(Rect2(decay_rect.position, Vector2(decay_rect.size.x * frac, decay_rect.size.y)), col)

	draw_rect(r, BORDER_COLOR, false, 1.0)
