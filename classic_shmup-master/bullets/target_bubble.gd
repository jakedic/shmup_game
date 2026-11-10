# target_bubble.gd
#
# Tutorial target bubble (levels/tutorial.gd, wave 3b). A small mint-green
# bubble that floats in place, gently bobbing. Built entirely in code - no
# .tscn needed, just preload("res://bullets/target_bubble.gd").new() and add
# it to the level.
#
#   - Shooting it or flying through it SCATTERS it: it breaks into a cloud of
#     tiny bubbles for a moment (SCATTER_* below), then they drift back
#     together and it reforms. It can't be popped while scattered.
#   - Touching the player's bubble (bullets/bubble.gd) ABSORBS it: it gets
#     sucked into the player's bubble and is gone for good - that's the only
#     way to get rid of one. The player's bubble keeps going exactly as it
#     was (no bounce, no change of course). Emits `popped` the moment it's
#     caught (the signal name is left over from when they popped).
#   - While the player's bubble is near, it drifts slightly toward it
#     (ATTRACT_* below), which makes it easier to catch. Only the target
#     moves - the player's bubble is never pulled. With no bubble around it
#     eases back to where it started.
#
# Collision: layer 0 (nothing else reacts to it - bullets keep going, the
# player's bubble doesn't run its own collision code), mask 1 (it watches the
# player, player bullets and bubbles, which are all on layer 1).
extends Area2D
class_name TargetBubble

signal popped

const OneShotAnim := preload("res://effects/one_shot_anim.gd")
const POP_FRAMES := preload("res://player/anim/bubble_pop_frames.tres")
const BUBBLE_TEXTURE := preload("res://Art assets/Player assets and transformations/Bubble_asset.png")
const BUBBLE_REGION := Rect2(829, 957, 415, 422)
const BUBBLE_ART_DIAMETER := 415.0       # same numbers as bubble.gd's pop sizing
const POP_SHEET_BUBBLE_DIAMETER := 105.5

# ---- Look ----
const DIAMETER := 16.0                    # on screen (the player's bubble is ~24)
const COLLISION_RADIUS := 7.0
const COLOR := Color(0.35, 1.0, 0.6, 1.0) # mint green - not used by any enemy type / power bubble
const RING_PULSE_SPEED := 4.0
const BOB_AMOUNT := 2.0                   # px up/down
const BOB_SPEED := 2.2

# ---- Scatter (shot / flown through) ----
const SCATTER_COUNT := 9                  # tiny bubbles it breaks into
const SCATTER_OUT_TIME := 0.35            # burst outward
const SCATTER_HOLD_TIME := 0.8            # hang there, wobbling
const SCATTER_RETURN_TIME := 0.55         # drift back together
const SCATTER_MIN_DIST := 12.0
const SCATTER_MAX_DIST := 26.0

# ---- Attraction toward the player's bubble ----
const ATTRACT_RADIUS := 70.0              # px - starts drifting when a bubble is this close
const ATTRACT_SPEED := 22.0               # px/s at point-blank, fading to 0 at ATTRACT_RADIUS
const RETURN_SPEED := 8.0                 # px/s back toward its starting spot when no bubble is near

# ---- Absorb (caught by the player's bubble) ----
const ABSORB_TIME := 0.18                 # seconds to get sucked in and shrink away

var home_position: Vector2 = Vector2.ZERO  # bobs around this (local position in the parent); set before add_child
var _origin: Vector2 = Vector2.ZERO        # where home_position started - it drifts back here
var _absorb_into: Node2D = null            # the player's bubble that caught it
var _absorb_t: float = 0.0
var _t: float = 0.0
var _scattered := false
var _popped := false
var _body: Node2D       # the whole bubble (sprite + ring) - hidden while scattered


class Ring extends Node2D:
	## Pulsing outline so the target reads clearly against busy backgrounds.
	var radius := 9.0
	var color := Color.WHITE
	var pulse_speed := 4.0
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var a := 0.55 + 0.45 * sin(_t * pulse_speed)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, Color(color, a), 1.5)


class Mini extends Node2D:
	## One of the tiny bubbles a scattered target breaks into.
	var radius := 2.5
	var color := Color.WHITE

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, Color(color, 0.25))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 12, Color(color, 0.95), 1.0)
		draw_circle(Vector2(-radius * 0.35, -radius * 0.35), radius * 0.25, Color(1, 1, 1, 0.9))


func _ready() -> void:
	add_to_group("target_bubble")
	collision_layer = 0
	collision_mask = 1
	monitorable = false
	if home_position == Vector2.ZERO:
		home_position = position
	_origin = home_position
	_t = randf() * TAU   # so a row of them doesn't bob in lockstep

	var shape := CircleShape2D.new()
	shape.radius = COLLISION_RADIUS
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)

	_body = Node2D.new()
	add_child(_body)
	var spr := Sprite2D.new()
	spr.texture = BUBBLE_TEXTURE
	spr.region_enabled = true
	spr.region_rect = BUBBLE_REGION
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	spr.scale = Vector2.ONE * (DIAMETER / BUBBLE_ART_DIAMETER)
	spr.modulate = COLOR
	_body.add_child(spr)
	var ring := Ring.new()
	ring.radius = DIAMETER * 0.5 + 1.5
	ring.color = COLOR
	ring.pulse_speed = RING_PULSE_SPEED
	_body.add_child(ring)

	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	if _popped:
		_process_absorb(delta)
		return
	_t += delta
	if not _scattered:
		_drift_toward_bubble(delta)
	position = home_position + Vector2(0, sin(_t * BOB_SPEED) * BOB_AMOUNT)


## Slight pull toward the nearest player bubble in range (stronger the closer
## it is). Moves only this target, never the bubble.
func _drift_toward_bubble(delta: float) -> void:
	var nearest: Node2D = null
	var nearest_dist := ATTRACT_RADIUS
	for b in get_tree().get_nodes_in_group("bubble"):
		if not (b is Bubble) or b._is_fusing:
			continue
		var d := global_position.distance_to(b.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = b
	if nearest:
		var strength := 1.0 - nearest_dist / ATTRACT_RADIUS
		var to_bubble: Vector2 = nearest.global_position - global_position
		# home_position is in the parent's space; the level isn't scaled or
		# rotated, so a global direction works as a local one.
		home_position += to_bubble.normalized() * ATTRACT_SPEED * strength * delta
	else:
		home_position = home_position.move_toward(_origin, RETURN_SPEED * delta)


func _on_area_entered(area: Area2D) -> void:
	if _popped:
		return
	if area is Bubble:
		if _scattered or area._is_fusing:
			return
		_absorb(area)
		return
	if area.is_in_group("player_bullet") or area.is_in_group("player_projectile") \
			or area.is_in_group("player") or area.name == "Player":
		_scatter()


# --- Absorb (the player's bubble caught it) ---

func _absorb(bubble: Bubble) -> void:
	_popped = true
	set_deferred("monitoring", false)
	_absorb_into = bubble
	_absorb_t = 0.0
	popped.emit()


## Follows the (still moving) player's bubble, closing in and shrinking until
## it's swallowed. The player's bubble is left completely alone.
func _process_absorb(delta: float) -> void:
	_absorb_t += delta
	var k := clampf(_absorb_t / ABSORB_TIME, 0.0, 1.0)
	if is_instance_valid(_absorb_into):
		global_position = global_position.lerp(_absorb_into.global_position, k)
	scale = Vector2.ONE * (1.0 - k)
	modulate.a = 1.0 - k * 0.5
	if k >= 1.0:
		queue_free()


# --- Scatter (shot / flown through) ---

func _scatter() -> void:
	if _scattered:
		return
	_scattered = true
	set_deferred("monitoring", false)
	_body.visible = false

	var minis: Array[Mini] = []
	var tw := create_tween().set_parallel(true)
	for i in SCATTER_COUNT:
		var m := Mini.new()
		m.color = COLOR
		m.radius = randf_range(1.8, 3.2)
		add_child(m)
		minis.append(m)
		var angle := TAU * i / SCATTER_COUNT + randf_range(-0.3, 0.3)
		var out := Vector2.RIGHT.rotated(angle) * randf_range(SCATTER_MIN_DIST, SCATTER_MAX_DIST)
		tw.tween_property(m, "position", out, SCATTER_OUT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		# A small wobble while they hang in the air.
		var wobble := out + Vector2(randf_range(-3, 3), randf_range(-3, 3))
		tw.tween_property(m, "position", wobble, SCATTER_HOLD_TIME).set_delay(SCATTER_OUT_TIME).set_trans(Tween.TRANS_SINE)
		tw.tween_property(m, "position", Vector2.ZERO, SCATTER_RETURN_TIME) \
			.set_delay(SCATTER_OUT_TIME + SCATTER_HOLD_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	if not is_inside_tree() or _popped:
		return

	for m in minis:
		m.queue_free()
	_body.visible = true
	_body.scale = Vector2.ONE * 0.6
	var grow := create_tween()
	grow.tween_property(_body, "scale", Vector2.ONE * 1.15, 0.1)
	grow.tween_property(_body, "scale", Vector2.ONE, 0.08)
	_scattered = false
	monitoring = true
