# pollen_cone_visual.gd
## One-shot expanding cone/wedge drawn wherever the Cross-Pollination
## power-up's pollen cone just went off (see bullets/bullet.gd ->
## _release_pollen_cone / _spawn_pollen_cone_visual).
##
## Not parented to the enemy that was hit, since that enemy may be about to
## be freed - spawned directly under the scene root instead, and frees
## itself once its short animation finishes. Modeled on
## pollen_explosion_visual.gd's fade-and-expand approach, but drawn as a
## wedge (draw_polygon fan) instead of a circle.
class_name PollenConeVisual
extends Node2D

const COLOR := Color(1.0, 0.85, 0.2, 0.85)
const DURATION := 0.25

# Set by whoever spawns this (see bullet.gd - _spawn_pollen_cone_visual) to
# match the actual direction/range/angle used for that burst.
var cone_direction: Vector2 = Vector2.UP
var cone_range: float = 60.0
var cone_angle_degrees: float = 70.0

var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress: float = clamp(_t / DURATION, 0.0, 1.0)
	var radius: float = lerp(4.0, cone_range, progress)
	var alpha: float = 1.0 - progress
	var half_angle: float = deg_to_rad(cone_angle_degrees) / 2.0
	var base_angle: float = cone_direction.angle()

	var segments := 12
	var points := PackedVector2Array()
	points.append(Vector2.ZERO)
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var angle: float = base_angle - half_angle + t * (half_angle * 2.0)
		points.append(Vector2.RIGHT.rotated(angle) * radius)

	var fill_color := Color(COLOR.r, COLOR.g, COLOR.b, COLOR.a * alpha * 0.35)
	draw_polygon(points, PackedColorArray([fill_color]))

	var outline_color := Color(COLOR.r, COLOR.g, COLOR.b, alpha)
	draw_line(Vector2.ZERO, points[1], outline_color, 1.5)
	draw_line(Vector2.ZERO, points[points.size() - 1], outline_color, 1.5)
	for i in range(1, points.size() - 1):
		draw_line(points[i], points[i + 1], outline_color, 1.5)
