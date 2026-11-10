# cosmic_storm.gd
#
# Purple cosmic storm over the top of the play area (tutorial wave 5a - see
# levels/tutorial.gd's _start_cosmic_storm()). Purely visual: the level
# decides what the storm does (no shooting while the ship is inside it).
# Built entirely in code - preload("res://effects/cosmic_storm.gd").new(),
# set bottom_y / width, add it to the level.
#
#   - A translucent purple tint from the top of the screen down to bottom_y,
#     with a soft, shimmering lower edge so the safe zone below reads clearly.
#   - Light streaks blowing sideways through it.
#   - jam_at(pos): a little purple fizzle where the ship tried to fire.
extends Node2D

# ---- Look ----
const TINT := Color(0.55, 0.15, 0.85, 0.30)     # main purple wash
const EDGE_HEIGHT := 14.0                        # soft fade at the bottom edge (px)
const EDGE_LINE_COLOR := Color(0.85, 0.55, 1.0, 0.7)
const EDGE_WAVE_AMOUNT := 1.5                    # px the edge line ripples
const STREAK_COUNT := 16
const STREAK_COLOR := Color(0.85, 0.65, 1.0, 0.35)
const STREAK_SPEED_MIN := 40.0
const STREAK_SPEED_MAX := 90.0
const FADE_TIME := 0.6

# ---- Jam fizzle ----
const JAM_SPARK_COUNT := 4
const JAM_SPARK_LIFE := 0.25
const JAM_SPARK_SPEED := 40.0
const JAM_COOLDOWN := 0.12                       # min seconds between fizzles
const JAM_COLOR := Color(0.9, 0.5, 1.0, 1.0)

var bottom_y: float = 240.0   # storm covers y 0..bottom_y (level/local space)
var width: float = 240.0

var _t := 0.0
var _streaks: Array = []      # {pos: Vector2, len: float, speed: float}
var _sparks: Array = []       # {pos: Vector2, vel: Vector2, life: float}
var _jam_cooldown := 0.0


func _ready() -> void:
	z_index = 50   # over enemies, bullets and the ship, so it tints them
	for i in STREAK_COUNT:
		_streaks.append(_new_streak(true))
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_TIME)


func _new_streak(anywhere: bool) -> Dictionary:
	return {
		"pos": Vector2(randf_range(-30.0, width) if anywhere else -30.0,
			randf_range(4.0, bottom_y - EDGE_HEIGHT)),
		"len": randf_range(8.0, 22.0),
		"speed": randf_range(STREAK_SPEED_MIN, STREAK_SPEED_MAX),
	}


## Fade out, then remove itself.
func dissipate() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	tw.tween_callback(queue_free)


## The ship tried to fire inside the storm - a little purple fizzle there.
func jam_at(pos: Vector2) -> void:
	if _jam_cooldown > 0.0:
		return
	_jam_cooldown = JAM_COOLDOWN
	for i in JAM_SPARK_COUNT:
		var dir := Vector2.UP.rotated(randf_range(-1.2, 1.2))
		_sparks.append({"pos": pos, "vel": dir * JAM_SPARK_SPEED * randf_range(0.6, 1.2), "life": JAM_SPARK_LIFE})


func _process(delta: float) -> void:
	_t += delta
	_jam_cooldown = maxf(_jam_cooldown - delta, 0.0)
	for i in _streaks.size():
		var s: Dictionary = _streaks[i]
		s["pos"] += Vector2(s["speed"], s["speed"] * 0.15) * delta
		if s["pos"].x > width + 30.0 or s["pos"].y > bottom_y - EDGE_HEIGHT:
			_streaks[i] = _new_streak(false)
	for s in _sparks:
		s["pos"] += s["vel"] * delta
		s["life"] -= delta
	_sparks = _sparks.filter(func(s): return s["life"] > 0.0)
	queue_redraw()


func _draw() -> void:
	var body_h := maxf(bottom_y - EDGE_HEIGHT, 0.0)
	draw_rect(Rect2(0, 0, width, body_h), TINT)
	# Soft fade at the bottom edge.
	var steps := 7
	for i in steps:
		var y0 := body_h + EDGE_HEIGHT * i / steps
		var a := TINT.a * (1.0 - float(i + 1) / (steps + 1))
		draw_rect(Rect2(0, y0, width, EDGE_HEIGHT / steps + 0.5), Color(TINT, a))
	# Shimmering line marking where the storm ends.
	var pts := PackedVector2Array()
	var x := 0.0
	while x <= width:
		pts.append(Vector2(x, bottom_y - EDGE_HEIGHT * 0.5 + sin(x * 0.08 + _t * 3.0) * EDGE_WAVE_AMOUNT))
		x += 6.0
	var pulse := 0.6 + 0.4 * sin(_t * 2.5)
	draw_polyline(pts, Color(EDGE_LINE_COLOR, EDGE_LINE_COLOR.a * pulse), 1.0)
	# Wind streaks.
	for s in _streaks:
		draw_line(s["pos"], s["pos"] + Vector2(s["len"], s["len"] * 0.15), STREAK_COLOR, 1.0)
	# Jam fizzle.
	for s in _sparks:
		var a2: float = s["life"] / JAM_SPARK_LIFE
		draw_line(s["pos"], s["pos"] - s["vel"].normalized() * 3.0, Color(JAM_COLOR, a2), 1.0)
