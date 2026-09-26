extends Node2D
class_name LandingShockwave

## Expanding ring spawned where the dash jump lands (see
## PlayerMovement.on_dash_end() -> _spawn_landing_shockwave()).
## Damages each enemy once as the ring reaches it.
##
## It's added to the level (the player's parent), not the player, so it
## stays put where the ship landed instead of following it around.

## Damage dealt to each enemy the ring touches (once per enemy).
var damage: int = 3
## How far the ring reaches, in screen pixels (viewport is 240x320).
var max_radius: float = 30.0
## Seconds for the ring to expand fully and fade out.
var duration: float = 0.35
## Extra reach so the ring counts as touching an enemy's edge, not just its center.
var hit_padding: float = 6.0
var ring_color: Color = Color(0.75, 0.9, 1.0, 0.9)

var _t: float = 0.0
var _radius: float = 0.0
var _hit: Array = []
var _hit_bubbles: Array = []
## Rough radius of a bubble, so the ring bounces it when it reaches its edge.
const BUBBLE_RADIUS := 10.0

func _ready() -> void:
	z_index = 5
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	var p: float = clampf(_t / duration, 0.0, 1.0)
	# Ease out: bursts outward quickly, then slows as it fades.
	_radius = max_radius * (1.0 - pow(1.0 - p, 3.0))
	_hit_enemies_in_range()
	_hit_bubbles_in_range()
	queue_redraw()
	if p >= 1.0:
		queue_free()

func _hit_enemies_in_range() -> void:
	for enemy in _get_enemies():
		if global_position.distance_to(enemy.global_position) <= _radius + hit_padding:
			hit(enemy)

func _hit_bubbles_in_range() -> void:
	"""The player's own bubbles get knocked away by the ring and become
	"shockwave charged" (see Bubble.on_shockwave_hit())."""
	for b in get_tree().get_nodes_in_group("bubble"):
		if not is_instance_valid(b) or b.is_queued_for_deletion() or _hit_bubbles.has(b):
			continue
		if not b.has_method("on_shockwave_hit"):
			continue
		if global_position.distance_to(b.global_position) <= _radius + BUBBLE_RADIUS:
			_hit_bubbles.append(b)
			b.on_shockwave_hit(global_position)

func hit(target: Node) -> void:
	"""Damage one enemy, once. Also called directly for anything the ship
	lands right on top of, so those get hit before the landing check."""
	if not is_instance_valid(target) or _hit.has(target):
		return
	if not (target.is_in_group("enemies") or target.is_in_group("enemy")):
		return
	if "is_alive" in target and not target.is_alive:
		return
	_hit.append(target)
	if target.has_method("take_damage"):
		target.take_damage(damage)
	elif target.has_method("explode"):
		target.explode()

func _get_enemies() -> Array:
	var list: Array = get_tree().get_nodes_in_group("enemies")
	for e in get_tree().get_nodes_in_group("enemy"):
		if not list.has(e):
			list.append(e)
	return list.filter(func(e): return e is Node2D and is_instance_valid(e))

func _draw() -> void:
	var p: float = clampf(_t / duration, 0.0, 1.0)
	var c := ring_color
	c.a *= 1.0 - p
	# Main ring thins as it expands, plus a faint inner echo.
	var width: float = lerpf(3.0, 1.0, p)
	draw_arc(Vector2.ZERO, maxf(_radius, 1.0), 0.0, TAU, 40, c, width)
	var inner := c
	inner.a *= 0.4
	draw_arc(Vector2.ZERO, maxf(_radius * 0.7, 1.0), 0.0, TAU, 32, inner, 1.0)
