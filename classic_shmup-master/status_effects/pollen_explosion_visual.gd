# pollen_explosion_visual.gd
## One-shot expanding burst drawn wherever a pollinated enemy's chain
## explosion goes off (see pollinated_status.gd -> _spawn_explosion_visual).
##
## Not parented to the enemy that caused it, since that enemy is about to be
## freed - spawned directly under the scene root instead, and frees itself
## once its short animation finishes.
class_name PollenExplosionVisual
extends Node2D

const COLOR := Color(1.0, 0.85, 0.2, 0.85)
const DURATION := 0.25

# Set by whoever spawns this (see pollinated_status.gd - _spawn_explosion_visual)
# to match the actual radius used for that detonation, since this can now
# vary at runtime (yellow_pollen_blast_radius power-up). Falls back to
# PollinatedStatus.EXPLOSION_RADIUS's default if never set.
var max_radius: float = PollinatedStatus.EXPLOSION_RADIUS

var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress: float = clamp(_t / DURATION, 0.0, 1.0)
	var radius: float = lerp(4.0, max_radius, progress)
	var alpha: float = 1.0 - progress
	draw_circle(Vector2.ZERO, radius, Color(COLOR.r, COLOR.g, COLOR.b, COLOR.a * alpha * 0.5))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color(COLOR.r, COLOR.g, COLOR.b, alpha), 2.0)
