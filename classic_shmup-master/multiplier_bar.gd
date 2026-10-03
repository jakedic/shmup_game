# multiplier_bar.gd
# Side-panel meter for the score multiplier (built by game_shell.gd).
#
# One bar, two parts:
#   - Top (thick): progress toward the NEXT multiplier. It's split into one
#     segment per multiplier point needed (10). Points can be fractional
#     (damage is worth 0.5), so the segment being worked on fills partway.
#     At the max multiplier the whole top is lit and pulses.
#   - Bottom (thin strip): the decay timer. While the multiplier is above 1x
#     the level's multiplier timer is running, and when it runs out the
#     multiplier drops by one. The strip drains as that timer counts down and
#     turns red near the end. It refills every time a point gain restarts the timer.
#
# Ability mode: while the player has an absorbed ability (current_form isn't
# 'default' and its transformation timer is running), the top part stops
# showing kill progress and instead shows how much time is left on the
# ability, as one bar in the ability's color that drains and blinks near the
# end. As soon as the ability ends (timed out, or the player shot it out as a
# bubble) it goes straight back to the kill-progress segments. The decay strip
# underneath keeps showing the multiplier decay the whole time.
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

var points := 0.0
var points_needed := 10
var at_max := false
var decay_timer: Timer = null

var _pulse := 0.0

# Ability mode state (refreshed every frame in _process from the player).
const ABILITY_DEFAULT_COLOR := Color(0.75, 0.3, 1.0)
# Same palette as bubble.gd's POWER_BUBBLE_COLORS (copied rather than
# referenced so this autoload-owned HUD script doesn't pull in Bubble).
const ABILITY_COLORS := {
	"yellow": Color(1.0, 0.92, 0.15),
	"red": Color(1.0, 0.25, 0.25),
	"hive": Color(1.0, 0.6, 0.15),
	"flower": Color(1.0, 0.45, 0.8),
}
const ABILITY_LOW_FRACTION := 0.3  # starts blinking below this much time left
var ability_active := false
var ability_fraction := 0.0
var ability_color := ABILITY_DEFAULT_COLOR


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Keep animating while paused so the bar doesn't look frozen mid-pulse.
	process_mode = Node.PROCESS_MODE_ALWAYS


func set_progress(p_points: float, p_points_needed: float, p_at_max: bool) -> void:
	points = p_points
	points_needed = max(int(ceil(p_points_needed)), 1)
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
	_update_ability_state()
	queue_redraw()


func _update_ability_state() -> void:
	ability_active = false
	var player = get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player):
		return
	if not ("current_form" in player) or player.current_form == 'default':
		return
	var t: Timer = player.transformation_timer
	if t == null or not is_instance_valid(t) or t.is_stopped() or t.wait_time <= 0.0:
		return
	ability_active = true
	ability_fraction = clamp(t.time_left / t.wait_time, 0.0, 1.0)
	ability_color = ABILITY_COLORS.get(player.current_form, ABILITY_DEFAULT_COLOR)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, BACK_COLOR)

	var inner := r.grow(-1.0)
	var prog_rect := Rect2(inner.position, Vector2(inner.size.x, inner.size.y - DECAY_STRIP_HEIGHT - 1.0))
	var decay_rect := Rect2(
		Vector2(inner.position.x, inner.end.y - DECAY_STRIP_HEIGHT),
		Vector2(inner.size.x, DECAY_STRIP_HEIGHT))

	# --- ability timer (replaces the progress segments while an ability is active) ---
	if ability_active:
		draw_rect(prog_rect, SEGMENT_EMPTY_COLOR)
		var acol := ability_color
		if ability_fraction < ABILITY_LOW_FRACTION:
			# Blink faster as it runs out so the player knows it's about to end.
			acol = ability_color.lerp(Color.WHITE, 0.5 + 0.5 * sin(_pulse * 3.0))
		draw_rect(Rect2(prog_rect.position, Vector2(prog_rect.size.x * ability_fraction, prog_rect.size.y)), acol)
	else:
		_draw_progress_segments(prog_rect)

	# --- decay strip ---
	draw_rect(decay_rect, SEGMENT_EMPTY_COLOR)
	var frac := _decay_fraction()
	if frac > 0.0:
		var col := DECAY_COLOR if frac > DECAY_LOW_FRACTION else DECAY_LOW_COLOR
		draw_rect(Rect2(decay_rect.position, Vector2(decay_rect.size.x * frac, decay_rect.size.y)), col)

	draw_rect(r, BORDER_COLOR, false, 1.0)


func _draw_progress_segments(prog_rect: Rect2) -> void:
	var seg_w := (prog_rect.size.x - SEGMENT_GAP * (points_needed - 1)) / points_needed
	for i in points_needed:
		var seg := Rect2(
			Vector2(prog_rect.position.x + i * (seg_w + SEGMENT_GAP), prog_rect.position.y),
			Vector2(seg_w, prog_rect.size.y))
		draw_rect(seg, SEGMENT_EMPTY_COLOR)
		if at_max:
			draw_rect(seg, MAX_COLOR.lerp(PROGRESS_COLOR, 0.5 + 0.5 * sin(_pulse)))
			continue
		# How much of this segment is filled (0..1) - partial for half points.
		var fill: float = clamp(points - i, 0.0, 1.0)
		if fill > 0.0:
			draw_rect(Rect2(seg.position, Vector2(seg.size.x * fill, seg.size.y)), PROGRESS_COLOR)
