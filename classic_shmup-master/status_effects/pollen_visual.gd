# pollen_visual.gd
## Small "flecks of pollen stuck to the enemy" indicator. Added as a child
## of an enemy Area2D by PollinatedStatus.on_apply() (see
## pollinated_status.gd) and removed by on_remove().
##
## Drawn as its own overlay (rather than tinting the enemy's `modulate`)
## because base_enemy.gd already uses `modulate` for the damage flash and
## heal flash, and enemy_yellow.gd uses it for the shot-charge telegraph -
## tinting the whole sprite for "pollinated" would fight with those and get
## clobbered/hidden the instant the enemy takes damage or charges a shot.
class_name PollenVisual
extends Node2D

const DOT_COLOR := Color(1.0, 0.85, 0.2, 0.95)
const DOT_OUTLINE := Color(0.55, 0.4, 0.0, 0.9)
# Small cluster of dots around the enemy's origin - roughly matches the
# 16x16 enemy sprites this project uses.
const DOT_POSITIONS := [
	Vector2(-5, -4), Vector2(4, -6), Vector2(6, 3),
	Vector2(-6, 4), Vector2(0, 6),
]
const BASE_RADIUS := 1.6
const PULSE_AMOUNT := 0.35
const PULSE_SPEED := 3.0

# Randomized per-instance so multiple pollinated enemies on screen don't
# pulse in perfect lockstep.
var _t: float = randf() * TAU


func _ready() -> void:
	z_index = 1  # draw on top of the enemy sprite
	set_process(true)


func _process(delta: float) -> void:
	_t += delta * PULSE_SPEED
	queue_redraw()


func _draw() -> void:
	var pulse: float = 1.0 + sin(_t) * PULSE_AMOUNT
	for pos in DOT_POSITIONS:
		draw_circle(pos, BASE_RADIUS * pulse + 0.6, DOT_OUTLINE)
		draw_circle(pos, BASE_RADIUS * pulse, DOT_COLOR)
