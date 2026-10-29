extends AnimatedSprite2D
class_name BeeSprite

## The bee's animated sprite (enemies/anim/bee_frames.tres): "idle" while
## flying straight or sitting in formation, "left"/"right" while banking
## through a turn. The turn is read from how fast the bee's body is rotating
## (whoever drives it - BeeEnemy's dive facing, BeeSquad, BeeSolo), so it
## works for every movement pattern with no hooks in their scripts. The idle
## rock (AnimationPlayer rotating just this sprite) doesn't count as a turn.

## Turn rate (deg/s) that switches into a turn animation...
@export var turn_on_deg_per_sec: float = 70.0
## ...and the lower rate it has to drop under to go back to idle (stops
## flicker on the edge of a turn).
@export var turn_off_deg_per_sec: float = 35.0
## How quickly the measured turn rate follows the real one (higher = snappier).
@export var turn_smoothing: float = 12.0

var _last_rot: float = 0.0
var _rate: float = 0.0
var _has_last := false

func _ready() -> void:
	if not is_playing():
		play(&"idle")

func _process(delta: float) -> void:
	var body := get_parent() as Node2D
	if body == null or delta <= 0.0:
		return
	var r := body.global_rotation
	if not _has_last:
		_last_rot = r
		_has_last = true
	var raw := wrapf(r - _last_rot, -PI, PI) / delta
	_last_rot = r
	_rate = lerpf(_rate, raw, 1.0 - exp(-turn_smoothing * delta))

	var deg := rad_to_deg(_rate)
	var want: StringName = animation
	if animation == &"idle":
		if deg >= turn_on_deg_per_sec:
			want = &"right"   # clockwise = turning to the bee's own right
		elif deg <= -turn_on_deg_per_sec:
			want = &"left"
	elif absf(deg) < turn_off_deg_per_sec:
		want = &"idle"
	elif deg > 0.0 and animation == &"left":
		want = &"right"
	elif deg < 0.0 and animation == &"right":
		want = &"left"

	if want != animation:
		var f := frame
		var p := frame_progress
		play(want)
		set_frame_and_progress(f, p)
